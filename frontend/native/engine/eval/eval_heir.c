#include "eval_types.h"

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Heir: Piece-Square Table                                                 */
/* ═══════════════════════════════════════════════════════════════════════════ */

const int PST_HEIR_PAWN[64] = {
     0,  0,  0,  0,  0,  0,  0,  0,   /* rank 1 */
     5, 10, 10,  5,  5, 10, 10,  5,   /* rank 2: modest center preference */
    10, 15, 20, 25, 25, 20, 15, 10,   /* rank 3 */
    15, 20, 30, 35, 35, 30, 20, 15,   /* rank 4: center control + advance */
    25, 30, 40, 50, 50, 40, 30, 25,   /* rank 5: deep territory */
    40, 45, 55, 65, 65, 55, 45, 40,   /* rank 6: near promotion */
    70, 75, 80, 90, 90, 80, 75, 70,   /* rank 7: promotion imminent */
     0,  0,  0,  0,  0,  0,  0,  0,   /* rank 8 */
};


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Heir: Helper functions                                                   */
/* ═══════════════════════════════════════════════════════════════════════════ */

static inline int heir_pawn_advance_sq(Color side, Square sq) {
    int advance = (side == WHITE) ? (SQ_ROW(sq) - 1) : (6 - SQ_ROW(sq));
    if (advance < 0) return 0;
    if (advance > 5) return 5;
    return advance;
}

static inline int heir_pawn_steps_to_promo(Color side, Square sq) {
    int steps = (side == WHITE) ? (7 - SQ_ROW(sq)) : SQ_ROW(sq);
    if (steps < 0) return 0;
    if (steps > 6) return 6;
    return steps;
}

static bool heir_is_passed_pawn(const Board *b, Color side, Square sq) {
    Color opp = color_opposite(side);
    int row = SQ_ROW(sq);
    int col = SQ_COL(sq);
    Bitboard pawns = b->pieces[opp][PAWN];

    while (pawns) {
        Square opsq = (Square)bb_pop_lsb(&pawns);
        int ocol = SQ_COL(opsq);
        int orow = SQ_ROW(opsq);

        if (abs(ocol - col) > 1) continue;
        if (side == WHITE ? (orow > row) : (orow < row)) {
            return false;
        }
    }

    return true;
}

static bool heir_promotion_square_safe(const Board *b, Color side, Square sq) {
    Square promo_sq = SQ(side == WHITE ? 7 : 0, SQ_COL(sq));
    return !board_square_attacked(b, promo_sq, color_opposite(side));
}

static int heir_king_hot_squares(const Board *b, Color by, Square king) {
    Bitboard ring = king_attacks[king] | BB_SQ(king);
    int hot = 0;

    while (ring) {
        Square sq = (Square)bb_pop_lsb(&ring);
        if (board_square_attacked(b, sq, by)) hot++;
    }

    return hot;
}

static inline int heir_file_centrality(Square sq) {
    int col = SQ_COL(sq);
    int left = abs(col - 3);
    int right = abs(col - 4);
    int dist = left < right ? left : right;
    int bonus = 3 - dist;
    return bonus > 0 ? bonus : 0;
}

static int heir_developed_minor_count(const Board *b, Color side) {
    int back_rank = (side == WHITE) ? 0 : 7;
    int developed = 0;
    Bitboard minors = b->pieces[side][KNIGHT] | b->pieces[side][BISHOP];

    while (minors) {
        Square sq = (Square)bb_pop_lsb(&minors);
        if (SQ_ROW(sq) != back_rank) developed++;
    }

    return developed;
}

static int heir_f_pawn_block_penalty(const Board *b, Color side) {
    Square block_sq = (side == WHITE) ? SQ(2, 5) : SQ(5, 5);
    Square home_f = (side == WHITE) ? SQ(1, 5) : SQ(6, 5);
    Square spear_sq = (side == WHITE) ? SQ(4, 4) : SQ(3, 4);
    Square anchor_sq = (side == WHITE) ? SQ(3, 3) : SQ(4, 3);
    Color opp = color_opposite(side);
    int penalty = 0;

    if (!BB_HAS(b->pieces[side][KNIGHT], block_sq)) return 0;
    if (!BB_HAS(b->pieces[side][PAWN], home_f)) return 0;
    if (!BB_HAS(b->pieces[side][PAWN], spear_sq)) return 0;

    penalty += 14;
    if (BB_HAS(b->pieces[side][PAWN], anchor_sq)) penalty += 18;
    if (b->fullmove <= 10) penalty += 6;
    if (board_square_attacked(b, spear_sq, opp) &&
        !board_square_attacked(b, spear_sq, side)) {
        penalty += 10;
    }

    return penalty;
}


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Heir: Strategic evaluation                                               */
/* ═══════════════════════════════════════════════════════════════════════════ */

int eval_heir(const Board *b, const EvalContext *ctx) {
    int score = 0;
    int pawn_count[2];
    pawn_count[0] = ctx->pawn_count[0];
    pawn_count[1] = ctx->pawn_count[1];
    int king_sq[2];
    king_sq[0] = ctx->king_sq[0];
    king_sq[1] = ctx->king_sq[1];
    int queen_sq[2];
    queen_sq[0] = ctx->queen_sq[0];
    queen_sq[1] = ctx->queen_sq[1];
    int eg_weight = ctx->eg_weight;
    (void)eg_weight;

        static const int HEIR_ADV_BONUS[] = {0, 8, 20, 40, 80, 160};
        static const int HEIR_PASS_BONUS[] = {0, 14, 32, 62, 125, 230};
        static const int HEIR_RECOVERY_BONUS[] = {6, 10, 22, 58, 140, 300};
        static const int HEIR_RACE_THREAT[] = {0, 0, 18, 48, 105, 235};

        for (int c = 0; c < 2; c++) {
            Color side = (Color)c;
            Color opp = color_opposite(side);
            bool has_king = b->pieces[side][KING] != BB_EMPTY;
            bool promoted = b->heir_promoted[side] != 0;
            bool check_mode = heir_check_applies(b, side);
            int bonus = 0;
            int best_advance = 0;
            int best_passed = -1;
            int safe_recovery = 0;
            int strategic_scale = (!has_king || promoted ||
                                   pawn_count[side] <= 3 || pawn_count[opp] <= 3)
                                ? 256 : (112 + eg_weight);
            int soft_king_scale = (!check_mode && !promoted && pawn_count[side] >= 4)
                                ? (144 + eg_weight / 2) : 256;

            if (strategic_scale > 256) strategic_scale = 256;
            if (soft_king_scale > 256) soft_king_scale = 256;

            Bitboard pawns = b->pieces[side][PAWN];
            while (pawns) {
                Square sq = (Square)bb_pop_lsb(&pawns);
                int advance = heir_pawn_advance_sq(side, sq);
                int steps = heir_pawn_steps_to_promo(side, sq);
                bool passed = heir_is_passed_pawn(b, side, sq);
                bool promo_safe = heir_promotion_square_safe(b, side, sq);
                bool attacked = board_square_attacked(b, sq, opp);
                int escorts = bb_popcount(b->pieces[side][PAWN] & king_attacks[sq]);

                if (advance > best_advance) best_advance = advance;

                bonus += (HEIR_ADV_BONUS[advance] * strategic_scale) / 256;
                bonus += (heir_file_centrality(sq) * (advance >= 2 ? 5 : 2) * strategic_scale) / 256;
                bonus += (escorts * 8 * strategic_scale) / 256;

                if (passed) {
                    bonus += (HEIR_PASS_BONUS[advance] * strategic_scale) / 256;
                    if (advance > best_passed) best_passed = advance;
                    if (!attacked) bonus += ((10 + advance * 4) * strategic_scale) / 256;
                }

                if (advance >= 4) {
                    if (promo_safe) {
                        bonus += ((30 + (5 - steps) * 12) * strategic_scale) / 256;
                    } else {
                        bonus -= 12;
                    }
                }
                if (attacked && advance >= 4) bonus -= 12;

                if (!has_king && promo_safe) {
                    safe_recovery += 10 + advance * 18 + (passed ? 24 : 0);
                }
            }

            bonus += pawn_count[side] * 18;
            if (pawn_count[side] <= 2) bonus -= (3 - pawn_count[side]) * 35;
            if (pawn_count[side] == 1) bonus -= 40;
            if (best_advance >= 4) bonus += (20 * strategic_scale) / 256;
            if (best_passed >= 4) bonus += (40 * strategic_scale) / 256;

            if (!has_king) {
                if (promoted) {
                    bonus -= 1400;
                } else {
                    bonus -= 180;
                    bonus += safe_recovery;
                    bonus += HEIR_RECOVERY_BONUS[best_advance];
                    if (best_passed >= 0)
                        bonus += HEIR_RECOVERY_BONUS[best_passed] / 2;
                    if (pawn_count[side] == 0) bonus -= 1200;
                    if (best_advance <= 1) bonus -= 80;
                }
            } else {
                Square ksq = king_sq[side];
                int support = bb_popcount(king_attacks[ksq] & b->occupied[side]);
                int shield = bb_popcount(king_attacks[ksq] & b->pieces[side][PAWN]);
                int hot = heir_king_hot_squares(b, opp, ksq);
                int scarcity = pawn_count[side] <= 2 ? (3 - pawn_count[side]) : 0;

                if (promoted) bonus += 720;

                if (check_mode) {
                    bonus += support * 18;
                    bonus += shield * 14;
                    if (board_square_attacked(b, ksq, opp)) bonus -= 240;
                    bonus -= hot * (18 + scarcity * 6);
                } else {
                    bonus += support * 10;
                    bonus += shield * 8;
                    if (board_square_attacked(b, ksq, opp))
                        bonus -= ((100 + scarcity * 45) * soft_king_scale) / 256;
                    bonus -= (hot * (8 + scarcity * 4) * soft_king_scale) / 256;
                }
            }

            if (king_sq[opp] >= 0) {
                int opp_hot = heir_king_hot_squares(b, side, king_sq[opp]);
                bonus += opp_hot * (check_mode ? 10 : 8);
                if (board_square_attacked(b, king_sq[opp], side)) bonus += 35;
            } else {
                bonus += 140;
                if (pawn_count[opp] <= 2) bonus += 70;

                Bitboard opp_pawns = b->pieces[opp][PAWN];
                while (opp_pawns) {
                    Square sq = (Square)bb_pop_lsb(&opp_pawns);
                    if (!heir_promotion_square_safe(b, opp, sq)) bonus += 18;
                }
            }

            {
                int opp_best_advance = 0;
                int opp_best_passed = -1;
                Bitboard opp_pawns = b->pieces[opp][PAWN];

                while (opp_pawns) {
                    Square sq = (Square)bb_pop_lsb(&opp_pawns);
                    int advance = heir_pawn_advance_sq(opp, sq);

                    if (advance > opp_best_advance) opp_best_advance = advance;
                    if (heir_is_passed_pawn(b, opp, sq) && advance > opp_best_passed) {
                        opp_best_passed = advance;
                    }
                }

                bonus -= (HEIR_RACE_THREAT[opp_best_advance] * strategic_scale) / 256;
                if (opp_best_passed >= 3)
                    bonus -= (HEIR_RACE_THREAT[opp_best_passed] * strategic_scale) / 512;
                if (!has_king) {
                    bonus -= HEIR_RACE_THREAT[opp_best_advance] / 2;
                    if (opp_best_passed >= 4) bonus -= 80;
                }
            }

            {
                int developed = 0;
                int minor_developed = 0;
                int back_rank = (side == WHITE) ? 0 : 7;
                Bitboard target_pawns = b->pieces[opp][PAWN];

                for (int t = KNIGHT; t <= QUEEN; t++) {
                    Bitboard pieces = b->pieces[side][t];
                    while (pieces) {
                        Square sq = (Square)bb_pop_lsb(&pieces);
                        Bitboard attacks = BB_EMPTY;

                        if (SQ_ROW(sq) != back_rank) {
                            developed++;
                            if (t == KNIGHT || t == BISHOP) minor_developed++;
                        }

                        if (t == KNIGHT) {
                            attacks = knight_attacks[sq];
                        } else if (t == BISHOP) {
                            attacks = bishop_attacks_calc(sq, b->all);
                        } else if (t == ROOK) {
                            attacks = rook_attacks_calc(sq, b->all);
                        } else if (t == QUEEN) {
                            attacks = bishop_attacks_calc(sq, b->all)
                                    | rook_attacks_calc(sq, b->all);
                        }

                        if (board_square_attacked(b, sq, opp) &&
                            !board_square_attacked(b, sq, side)) {
                            int pen = (t == KNIGHT || t == BISHOP) ? 30
                                    : (t == ROOK) ? 45 : 70;
                            if (SQ_COL(sq) == 0 || SQ_COL(sq) == 7) pen += 10;
                            bonus -= pen;
                        }

                        if (t == KNIGHT) {
                            int rel_rank = (side == WHITE) ? SQ_ROW(sq) : (7 - SQ_ROW(sq));
                            bool central = SQ_COL(sq) >= 2 && SQ_COL(sq) <= 5 &&
                                           rel_rank >= 2 && rel_rank <= 4;
                            if (central) {
                                int knight_bonus = 14;
                                if (board_square_attacked(b, sq, side)) knight_bonus += 10;
                                if (!board_square_attacked(b, sq, opp)) knight_bonus += 8;
                                if (rel_rank >= 4) knight_bonus += 6;
                                bonus += knight_bonus;
                            }
                        }

                        /* Rook on 7th rank (2nd from opponent's perspective) */
                        if (t == ROOK) {
                            int rel_rank = (side == WHITE) ? SQ_ROW(sq) : (7 - SQ_ROW(sq));
                            if (rel_rank == 6) {
                                bonus += 25;
                                /* Extra bonus if opponent king on 8th rank */
                                if (king_sq[opp] >= 0) {
                                    int opp_king_rel = (side == WHITE) ? SQ_ROW(king_sq[opp]) : (7 - SQ_ROW(king_sq[opp]));
                                    if (opp_king_rel == 7) bonus += 15;
                                }
                            }
                            /* Connected rooks bonus */
                            Bitboard rook_atk = rook_attacks_calc(sq, b->all);
                            if (rook_atk & b->pieces[side][ROOK]) bonus += 12;
                        }

                        /* Bishop: central diagonal control bonus */
                        if (t == BISHOP) {
                            int rel_rank = (side == WHITE) ? SQ_ROW(sq) : (7 - SQ_ROW(sq));
                            if (SQ_COL(sq) >= 1 && SQ_COL(sq) <= 6 &&
                                rel_rank >= 1 && rel_rank <= 5) {
                                Bitboard diag_atk = bishop_attacks_calc(sq, b->all);
                                int center_control = bb_popcount(diag_atk & (Bitboard)0x00003C3C3C3C0000ULL);
                                bonus += center_control * 4;
                            }
                        }

                        if (king_sq[opp] >= 0) {
                            Bitboard ring = king_attacks[king_sq[opp]] | BB_SQ(king_sq[opp]);
                            if (attacks & ring) {
                                bonus += (t == QUEEN) ? 18 : 10;
                            }
                        } else if (attacks & target_pawns) {
                            bonus += 8;
                        }
                    }
                }

                if (developed > 6) developed = 6;
                bonus += developed * 8;
                if (developed >= 3 && b->fullmove <= 14) bonus += 10;

                if (!promoted && b->fullmove <= 12 && pawn_count[side] >= 4 &&
                    pawn_count[opp] >= 4) {
                    bonus -= heir_f_pawn_block_penalty(b, side);
                }

                if (queen_sq[side] >= 0 && king_sq[side] >= 0 && !promoted &&
                    b->fullmove <= 12 && pawn_count[side] >= 4 && pawn_count[opp] >= 4) {
                    Square qsq = queen_sq[side];

                    if (SQ_ROW(qsq) != back_rank) {
                        int minor_total = bb_popcount(
                            b->pieces[side][KNIGHT] | b->pieces[side][BISHOP]);
                        int undeveloped_minors = minor_total - minor_developed;

                        if (undeveloped_minors > 0) {
                            int advance = (side == WHITE) ? SQ_ROW(qsq) : (7 - SQ_ROW(qsq));
                            int king_gap = chebyshev_distance_sq(qsq, king_sq[side]);
                            int pen = 10 + undeveloped_minors * 14;

                            if (minor_developed == 0) pen += 16;
                            else if (minor_developed == 1) pen += 8;
                            if (advance >= 1) pen += 4 + advance * 4;
                            if (king_gap > 1) pen += (king_gap - 1) * 6;
                            if (!board_square_attacked(b, qsq, side)) pen += 16;
                            if (board_square_attacked(b, qsq, opp)) pen += 14;

                            bonus -= pen;
                        }
                    }
                }
            }

            score += (c == WHITE) ? bonus : -bonus;
        }

    /* Tempo bonus (eval_common_finish also adds +10 for Heir, so keep
       only this one lighter to avoid double-counting) */
    score += (b->side == WHITE) ? 6 : -6;

    return score;
}
