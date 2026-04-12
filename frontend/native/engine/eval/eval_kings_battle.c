#include "eval_types.h"

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Kings Battle: Piece-Square Tables                                       */
/* ═══════════════════════════════════════════════════════════════════════════ */

const int PST_KB_KING_P1[64] = {
    -40,-25,-15,  0,  0,-15,-25,-40,   /* rank 1: start, strongly discouraged */
    -20,  0, 12, 22, 22, 12,  0,-20,   /* rank 2 */
     -5, 15, 35, 48, 48, 35, 15, -5,   /* rank 3: approaching center */
      5, 25, 50, 65, 65, 50, 25,  5,   /* rank 4: strong center */
     15, 35, 58, 75, 75, 58, 35, 15,   /* rank 5: enemy territory — best */
     20, 38, 55, 68, 68, 55, 38, 20,   /* rank 6: deep in enemy territory */
     10, 20, 35, 45, 45, 35, 20, 10,   /* rank 7: very deep, some risk */
     -5,  5, 15, 25, 25, 15,  5, -5,   /* rank 8: back rank of opponent */
};

/* King's Battle Phase 1: Pawns — advancement toward promotion is critical
   because promotion triggers the unlock. Central pawns also aid king
   maneuverability. */
const int PST_KB_PAWN_P1[64] = {
     0,  0,  0,  0,  0,  0,  0,  0,   /* rank 1 */
     5,  8, 10, 15, 15, 10,  8,  5,   /* rank 2: slight center */
    10, 15, 22, 30, 30, 22, 15, 10,   /* rank 3 */
    15, 22, 35, 45, 45, 35, 22, 15,   /* rank 4: strong center */
    25, 32, 45, 55, 55, 45, 32, 25,   /* rank 5: deep */
    40, 48, 58, 70, 70, 58, 48, 40,   /* rank 6: near promotion */
    65, 72, 80, 90, 90, 80, 72, 65,   /* rank 7: promotion imminent */
     0,  0,  0,  0,  0,  0,  0,  0,   /* rank 8 */
};


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Kings Battle: Helper functions                                          */
/* ═══════════════════════════════════════════════════════════════════════════ */

static int kb_phase1_forward_rank(Color side, Square sq) {
    return (side == WHITE) ? SQ_ROW(sq) : (7 - SQ_ROW(sq));
}

static int kb_phase1_promotion_distance(Color side, Square sq) {
    return 7 - kb_phase1_forward_rank(side, sq);
}

static bool kb_phase1_passed_pawn(const Board *b, Color side, Square sq) {
    Color opp = color_opposite(side);
    int row = SQ_ROW(sq);
    int col = SQ_COL(sq);
    int start = (side == WHITE) ? row + 1 : 0;
    int end = (side == WHITE) ? 8 : row;

    for (int r = start; r < end; r++) {
        for (int dc = -1; dc <= 1; dc++) {
            int nc = col + dc;
            if (nc < 0 || nc > 7) continue;
            if (BB_HAS(b->pieces[opp][PAWN], SQ(r, nc))) {
                return false;
            }
        }
    }

    return true;
}

static int kb_phase1_clear_promotion_lane(const Board *b, Color side, Square sq) {
    int row = SQ_ROW(sq);
    int col = SQ_COL(sq);
    int clear = 0;

    if (side == WHITE) {
        for (int r = row + 1; r < 8; r++) {
            if (b->mailbox[SQ(r, col)] != PIECE_EMPTY) break;
            clear++;
        }
    } else {
        for (int r = row - 1; r >= 0; r--) {
            if (b->mailbox[SQ(r, col)] != PIECE_EMPTY) break;
            clear++;
        }
    }

    return clear;
}

static bool kb_phase1_square_attacked_by_pawn_side(const Board *b, Color side,
                                                   Square sq) {
    int row = SQ_ROW(sq);
    int col = SQ_COL(sq);
    int attacker_row = (side == WHITE) ? row - 1 : row + 1;

    if (attacker_row < 0 || attacker_row > 7) return false;
    if (col > 0 && BB_HAS(b->pieces[side][PAWN], SQ(attacker_row, col - 1))) {
        return true;
    }
    if (col < 7 && BB_HAS(b->pieces[side][PAWN], SQ(attacker_row, col + 1))) {
        return true;
    }

    return false;
}

static bool kb_phase1_king_target_safe(const Board *b, Color side, Square sq) {
    Color opp = color_opposite(side);

    if (BB_HAS(b->occupied[side], sq)) return false;
    if (kb_phase1_square_attacked_by_pawn_side(b, opp, sq)) return false;

    if (b->pieces[opp][KING] != BB_EMPTY) {
        Square opp_king_sq = bb_lsb(b->pieces[opp][KING]);
        if (chebyshev_distance_sq(opp_king_sq, sq) <= 1) return false;
    }

    return true;
}

static bool kb_phase1_king_can_capture_pawn(const Board *b, Color side,
                                            Square king_sq, Square pawn_sq) {
    Color opp = color_opposite(side);

    if (chebyshev_distance_sq(king_sq, pawn_sq) != 1) return false;
    if (!BB_HAS(b->pieces[opp][PAWN], pawn_sq)) return false;

    return kb_phase1_king_target_safe(b, side, pawn_sq);
}

static bool kb_phase1_any_pawn_capture_available(const Board *b, Color side) {
    Bitboard pawns = b->pieces[side][PAWN];
    int step = (side == WHITE) ? 1 : -1;

    while (pawns) {
        Square sq = (Square)bb_pop_lsb(&pawns);
        int row = SQ_ROW(sq) + step;
        int col = SQ_COL(sq);

        if (row < 0 || row > 7) continue;

        if (col > 0) {
            Piece target = b->mailbox[SQ(row, col - 1)];
            if (target != PIECE_EMPTY && PIECE_COLOR(target) != side &&
                PIECE_TYPE(target) == PAWN) {
                return true;
            }
        }
        if (col < 7) {
            Piece target = b->mailbox[SQ(row, col + 1)];
            if (target != PIECE_EMPTY && PIECE_COLOR(target) != side &&
                PIECE_TYPE(target) == PAWN) {
                return true;
            }
        }
    }

    return false;
}

static int kb_phase1_forward_corridor_blockers(const Board *b, Color side,
                                               Square sq, int max_steps) {
    int row = SQ_ROW(sq);
    int col = SQ_COL(sq);
    int step = (side == WHITE) ? 1 : -1;
    int blockers = 0;

    for (int dr = 1; dr <= max_steps; dr++) {
        int nr = row + step * dr;
        if (nr < 0 || nr > 7) break;

        for (int dc = -1; dc <= 1; dc++) {
            int nc = col + dc;
            if (nc < 0 || nc > 7) continue;
            if (BB_HAS(b->occupied[side], SQ(nr, nc))) blockers++;
        }
    }

    return blockers;
}

static bool kb_phase1_forward_lane_open(const Board *b, Color side, Square sq) {
    int forward_row = SQ_ROW(sq) + ((side == WHITE) ? 1 : -1);
    int col = SQ_COL(sq);

    if (forward_row < 0 || forward_row > 7) return false;
    return !BB_HAS(b->occupied[side], SQ(forward_row, col));
}

static int kb_phase1_retreat_arc_seal_count(const Board *b, Color side) {
    Color opp = color_opposite(side);
    Bitboard opp_king = b->pieces[opp][KING];
    if (opp_king == BB_EMPTY) return 0;

    Square king_sq = bb_lsb(opp_king);
    int opp_rank = kb_phase1_forward_rank(opp, king_sq);
    int retreat_row = SQ_ROW(king_sq) + ((opp == WHITE) ? -1 : 1);
    int sealed = 0;

    if (opp_rank < 3) return 0;
    if (retreat_row < 0 || retreat_row > 7) return 0;

    for (int dc = -1; dc <= 1; dc++) {
        int nc = SQ_COL(king_sq) + dc;
        if (nc < 0 || nc > 7) continue;

        Square rsq = SQ(retreat_row, nc);
        if (b->mailbox[rsq] != PIECE_EMPTY ||
            kb_phase1_square_attacked_by_pawn_side(b, side, rsq)) {
            sealed++;
        }
    }

    return sealed;
}

static int kb_phase1_wing_drift_penalty(const Board *b, Color side, Square sq) {
    int file = SQ_COL(sq);
    int rank = kb_phase1_forward_rank(side, sq);
    int penalty;

    if (file != 0 && file != 1 && file != 6 && file != 7) return 0;
    if (rank < 2 || rank > 3) return 0;
    if (kb_phase1_passed_pawn(b, side, sq)) return 0;

    if (b->pieces[side][KING] != BB_EMPTY) {
        Square king_sq = bb_lsb(b->pieces[side][KING]);
        if (chebyshev_distance_sq(king_sq, sq) <= 2) return 0;
    }

    if (b->pieces[color_opposite(side)][KING] != BB_EMPTY) {
        Square enemy_king_sq = bb_lsb(b->pieces[color_opposite(side)][KING]);
        if (chebyshev_distance_sq(enemy_king_sq, sq) <= 2) return 0;
    }

    penalty = (rank == 2) ? 90 : 160;
    if (kb_phase1_any_pawn_capture_available(b, side)) penalty += 30;
    return penalty;
}

static int kb_phase1_connected_wall_bonus(const Board *b, Color side) {
    Color opp = color_opposite(side);
    Bitboard opp_king = b->pieces[opp][KING];
    Bitboard pawns = b->pieces[side][PAWN];
    int bonus = 0;

    if (opp_king == BB_EMPTY) return 0;

    Square king_sq = bb_lsb(opp_king);
    int opp_rank = kb_phase1_forward_rank(opp, king_sq);
    if (opp_rank < 4) return 0;

    while (pawns) {
        Square sq = (Square)bb_pop_lsb(&pawns);
        int row = SQ_ROW(sq);
        int col = SQ_COL(sq);
        int rank = kb_phase1_forward_rank(side, sq);
        int pair_dist;

        if (rank < 3 || col >= 7) continue;
        if (!BB_HAS(b->pieces[side][PAWN], SQ(row, col + 1))) continue;

        pair_dist = chebyshev_distance_sq(sq, king_sq);
        {
            int right_dist = chebyshev_distance_sq(SQ(row, col + 1), king_sq);
            if (right_dist < pair_dist) pair_dist = right_dist;
        }

        if (pair_dist <= 2) bonus += 1000;
        else if (pair_dist == 3) bonus += 320;
    }

    return bonus;
}

static int kb_phase1_forward_file_clearance(const Board *b, Color side, Square sq,
                                            int max_steps) {
    int row = SQ_ROW(sq);
    int col = SQ_COL(sq);
    int step = (side == WHITE) ? 1 : -1;
    int clear = 0;

    for (int i = 1; i <= max_steps; i++) {
        int nr = row + step * i;
        if (nr < 0 || nr > 7) break;
        if (b->mailbox[SQ(nr, col)] != PIECE_EMPTY) break;
        clear++;
    }

    return clear;
}

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Evaluation                                                               */
/* ═══════════════════════════════════════════════════════════════════════════ */


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Kings Battle: Strategic evaluation                                      */
/* ═══════════════════════════════════════════════════════════════════════════ */

int eval_kings_battle(const Board *b, const EvalContext *ctx) {
    int score = 0;
    int pawn_count[2];
    pawn_count[0] = ctx->pawn_count[0];
    pawn_count[1] = ctx->pawn_count[1];

        bool kb_phase1 = !b->kb_unlocked;

        for (int c = 0; c < 2; c++) {
            Color opp = (Color)(c ^ 1);
            int bonus = 0;

            if (kb_phase1) {
                /* ── Phase 1: King must aggressively hunt enemy pawns ─────── */
                /* The ONLY way to unlock pieces is King's Kill (king captures
                   an enemy pawn) or pawn promotion.  The evaluation must
                   STRONGLY incentivize the king to approach and capture
                   enemy pawns, lest the game stall into repetition draws. */

                Bitboard kbb = b->pieces[c][KING];
                if (kbb != BB_EMPTY) {
                    Square ksq = bb_lsb(kbb);
                    int kr = SQ_ROW(ksq), kcol = SQ_COL(ksq);
                    int king_rank = kb_phase1_forward_rank((Color)c, ksq);
                    int enemy_king_rank = -1;
                    int corridor_open = 0;
                    int king_mobility = 0;

                    if (!BB_HAS(b->pieces[c][PAWN], (c == WHITE) ? SQ(1, 3) : SQ(6, 3))) corridor_open++;
                    if (!BB_HAS(b->pieces[c][PAWN], (c == WHITE) ? SQ(1, 4) : SQ(6, 4))) corridor_open++;
                    if (!BB_HAS(b->pieces[c][PAWN], (c == WHITE) ? SQ(1, 5) : SQ(6, 5))) corridor_open++;

                    if (b->pieces[opp][KING] != BB_EMPTY) {
                        enemy_king_rank = kb_phase1_forward_rank(
                            opp,
                            bb_lsb(b->pieces[opp][KING])
                        );
                    }

                    if (king_rank == 0) {
                        bonus -= (b->fullmove <= 4) ? 80 : 120;
                        bonus -= corridor_open * 30;
                    } else {
                        bonus += king_rank * 24;
                        bonus += corridor_open * 10;
                        if (kcol >= 2 && kcol <= 5) bonus += 18;
                    }

                    /* ─ King proximity to enemy pawns (Chebyshev distance) ── */
                    /* Chebyshev = max(|dr|,|dc|) matches king movement — a
                       diagonal step is distance 1, not 2 like Manhattan.     */
                    Bitboard ep = b->pieces[opp][PAWN];
                    int min_dist = 15;
                    int total_prox = 0;
                    int capturable = 0;   /* pawns at Chebyshev distance 1 */
                    while (ep) {
                        Square ps = (Square)bb_pop_lsb(&ep);
                        int dr = abs(SQ_ROW(ps) - kr);
                        int dc = abs(SQ_COL(ps) - kcol);
                        int dist = dr > dc ? dr : dc;  /* Chebyshev */
                        if (dist < min_dist) min_dist = dist;
                        if (dist <= 7) total_prox += (7 - dist);
                        if (dist == 1 &&
                            kb_phase1_king_can_capture_pawn(
                                b,
                                (Color)c,
                                ksq,
                                ps
                            )) {
                            capturable++;
                        }
                    }
                    /* Strong approach bonus: each step closer is worth ~25cp */
                    if (min_dist < 15) bonus += (7 - min_dist) * 25;
                    bonus += total_prox * 5;
                    if (min_dist >= 4 && king_rank <= 1) bonus -= 40;

                    if (enemy_king_rank >= 0) {
                        if (king_rank + 1 < enemy_king_rank) {
                            bonus -= (enemy_king_rank - king_rank - 1) * 24;
                        } else if (king_rank > enemy_king_rank) {
                            bonus += (king_rank - enemy_king_rank) * 10;
                        }
                    }

                    /* CRITICAL: "Imminent King's Kill" — king is 1 step from
                       enemy pawns.  King's Kill unlocks ALL pieces (worth ~15
                       pawns of latent material) plus a bonus move.  Give a
                       huge incentive so the engine actually captures. */
                    bonus += capturable * 350;

                    /* Graduated approach bonus for dist 2–3: king is closing in */
                    {
                        Bitboard ep2 = b->pieces[opp][PAWN];
                        while (ep2) {
                            Square ps = (Square)bb_pop_lsb(&ep2);
                            int dr = abs(SQ_ROW(ps) - kr);
                            int dc = abs(SQ_COL(ps) - kcol);
                            int dist = dr > dc ? dr : dc;
                            if (dist == 2) bonus += 50;
                            else if (dist == 3) bonus += 15;
                        }
                    }

                    /* ─ King mobility ────────────────────────────────────────── */
                    {
                        Bitboard k_moves = king_attacks[ksq];

                        while (k_moves) {
                            Square to = (Square)bb_pop_lsb(&k_moves);
                            if (kb_phase1_king_target_safe(b, (Color)c, to)) {
                                king_mobility++;
                            }
                        }

                        bonus += king_mobility * 6;
                    }

                    if (kb_phase1_forward_lane_open(b, (Color)c, ksq)) {
                        bonus += 18;
                    } else {
                        bonus -= 10;
                    }
                    bonus += kb_phase1_forward_file_clearance(
                        b,
                        (Color)c,
                        ksq,
                        2
                    ) * 12;
                    bonus -= kb_phase1_forward_corridor_blockers(
                        b,
                        (Color)c,
                        ksq,
                        2
                    ) * 10;

                    {
                        int retreat_seal = kb_phase1_retreat_arc_seal_count(
                            b,
                            (Color)c
                        );
                        bonus += kb_phase1_connected_wall_bonus(b, (Color)c);

                        if (retreat_seal == 3) {
                            bonus += 220;
                        } else if (retreat_seal == 2) {
                            bonus += 60;
                        }

                        if (retreat_seal == 3 && enemy_king_rank >= 4 &&
                            b->pieces[opp][KING] != BB_EMPTY) {
                            Square enemy_king_sq = bb_lsb(b->pieces[opp][KING]);
                            Bitboard enemy_moves = king_attacks[enemy_king_sq];
                            Bitboard own_pawns = b->pieces[c][PAWN];
                            int enemy_safe_moves = 0;
                            int enemy_capturable = 0;

                            while (enemy_moves) {
                                Square to = (Square)bb_pop_lsb(&enemy_moves);
                                if (kb_phase1_king_target_safe(b, opp, to)) {
                                    enemy_safe_moves++;
                                }
                            }

                            while (own_pawns) {
                                Square ps = (Square)bb_pop_lsb(&own_pawns);
                                if (kb_phase1_king_can_capture_pawn(
                                        b,
                                        opp,
                                        enemy_king_sq,
                                        ps
                                    )) {
                                    enemy_capturable++;
                                }
                            }

                            if (enemy_capturable == 0) {
                                bonus += 240;
                                if (enemy_safe_moves <= 2) {
                                    bonus += 180 - enemy_safe_moves * 40;
                                }
                            }
                        }
                    }


                }

                /* ─ Vulnerable enemy pawns: isolated / undefended targets ── */
                /* Pawns not defended by other pawns or by the enemy king are
                   easy King's Kill targets — give our side a bonus for each. */
                {
                    Bitboard ep = b->pieces[opp][PAWN];
                    Bitboard opp_kbb = b->pieces[opp][KING];
                    Square oksq = (opp_kbb != BB_EMPTY) ? bb_lsb(opp_kbb) : (Square)64;
                    Bitboard own_kbb = b->pieces[c][KING];
                    Square own_ksq = (own_kbb != BB_EMPTY) ? bb_lsb(own_kbb) : (Square)64;

                    while (ep) {
                        Square ps = (Square)bb_pop_lsb(&ep);
                        int pcol = SQ_COL(ps);
                        int enemy_rank = kb_phase1_forward_rank(opp, ps);

                        /* Is this pawn defended by an adjacent friendly pawn? */
                        bool pawn_defended = false;
                        int def_row = (opp == WHITE) ? SQ_ROW(ps) - 1 : SQ_ROW(ps) + 1;
                        if (def_row >= 0 && def_row < 8) {
                            if (pcol > 0 && BB_HAS(b->pieces[opp][PAWN], SQ(def_row, pcol - 1)))
                                pawn_defended = true;
                            if (pcol < 7 && BB_HAS(b->pieces[opp][PAWN], SQ(def_row, pcol + 1)))
                                pawn_defended = true;
                        }

                        /* Is this pawn defended by enemy king (Chebyshev 1)? */
                        bool king_defended = false;
                        if (oksq < 64) {
                            int kdr = abs(SQ_ROW(ps) - SQ_ROW(oksq));
                            int kdc = abs(SQ_COL(ps) - SQ_COL(oksq));
                            king_defended = ((kdr > kdc ? kdr : kdc) <= 1);
                        }

                        if (!pawn_defended && !king_defended) {
                            /* Fully undefended pawn: prime target */
                            bonus += 40;
                            /* Extra bonus if our king is close to this weak pawn */
                            if (own_ksq < 64) {
                                int dr = abs(SQ_ROW(ps) - SQ_ROW(own_ksq));
                                int dc = abs(SQ_COL(ps) - SQ_COL(own_ksq));
                                int d = dr > dc ? dr : dc;
                                bonus += (7 - d) * 12;
                                if (enemy_rank >= 4 && d <= 2) {
                                    bonus += 40 + (enemy_rank - 4) * 20;
                                }
                            }
                        } else if (!pawn_defended) {
                            /* Only king-defended: can still be outmaneuvered */
                            bonus += 15;
                            if (enemy_rank >= 5) bonus += 12;
                        }
                    }
                }

                /* ─ Own pawn preservation ────────────────────────────────── */
                bonus += pawn_count[c] * 15;

                /* ─ Passed pawns: promotion triggers unlock ─────────────── */
                {
                    Bitboard pawns = b->pieces[c][PAWN];
                    while (pawns) {
                        Square sq = (Square)bb_pop_lsb(&pawns);
                        int row = SQ_ROW(sq), col = SQ_COL(sq);
                        int rank = (c == WHITE) ? row : (7 - row);
                        int enemy_king_dist = 8;
                        int promo_dist = kb_phase1_promotion_distance((Color)c, sq);
                        int clear_lane = kb_phase1_clear_promotion_lane(b, (Color)c, sq);

                        if (b->pieces[opp][KING] != BB_EMPTY) {
                            enemy_king_dist = chebyshev_distance_sq(
                                sq,
                                bb_lsb(b->pieces[opp][KING])
                            );
                        }

                        bool passed = kb_phase1_passed_pawn(b, (Color)c, sq);
                        if (passed) {
                            static const int KB_PASSED[8] = { 0, 10, 22, 40, 70, 110, 165, 0 };
                            bonus += KB_PASSED[rank];
                            bonus += clear_lane * 14;
                            if (clear_lane >= promo_dist) bonus += 50;
                            if (enemy_king_dist > promo_dist + 1) {
                                bonus += 40 + (enemy_king_dist - promo_dist) * 12;
                            }

                            /* Escort bonus: own king near passed pawn */
                            if (b->pieces[c][KING] != BB_EMPTY) {
                                Square ksq = bb_lsb(b->pieces[c][KING]);
                                int dr = abs(SQ_ROW(ksq) - row);
                                int dc_esc = abs(SQ_COL(ksq) - col);
                                int d = dr > dc_esc ? dr : dc_esc;
                                if (d <= 2) bonus += 30;
                                else if (d <= 3) bonus += 12;
                            }
                        }

                        /* Penalty if enemy king threatens our pawn */
                        if (b->pieces[opp][KING] != BB_EMPTY) {
                            Square oksq = bb_lsb(b->pieces[opp][KING]);
                            int dr = abs(SQ_ROW(oksq) - row);
                            int dc_thr = abs(SQ_COL(oksq) - col);
                            int d = dr > dc_thr ? dr : dc_thr;
                            if (d <= 1) bonus -= 40;
                            else if (d == 2) bonus -= 15;
                        }

                        bonus -= kb_phase1_wing_drift_penalty(
                            b,
                            (Color)c,
                            sq
                        );
                    }
                }
            } else {
                /* ── Phase 2: All pieces unlocked ────────────────────────── */
                /* Just-unlocked pieces have enormous latent value — don't
                   penalize them harshly for being on the back rank since
                   they literally just became available. */
                for (int t = KNIGHT; t <= QUEEN; t++) {
                    bonus += bb_popcount(b->pieces[c][t]) * 18;
                }

                /* Mild development incentive (not harsh back-rank penalty) */
                int back = (c == WHITE) ? 0 : 7;

                for (int t = KNIGHT; t <= QUEEN; t++) {
                    Bitboard bb = b->pieces[c][t];
                    while (bb) {
                        Square sq = (Square)bb_pop_lsb(&bb);
                        if (SQ_ROW(sq) == back) bonus -= 2;
                        else bonus += 8;
                    }
                }

                if (b->pieces[c][KING] != BB_EMPTY) {
                    Square ksq = bb_lsb(b->pieces[c][KING]);
                    int shield = bb_popcount(b->pieces[c][PAWN] & king_attacks[ksq]);

                    bonus += shield * 18;

                    if (b->pieces[opp][QUEEN] != BB_EMPTY) {
                        Square qsq = bb_lsb(b->pieces[opp][QUEEN]);
                        int queen_dist = chebyshev_distance_sq(ksq, qsq);

                        if (queen_dist <= 4) bonus -= (5 - queen_dist) * 36;
                        if (shield == 0) bonus -= 42;
                        else if (shield == 1) bonus -= 16;

                        if (abs(SQ_COL(ksq) - SQ_COL(qsq)) <= 2) bonus -= 18;
                    }
                }
            }

            score += (c == WHITE) ? bonus : -bonus;
        }

        /* Tempo bonus */
        score += (b->side == WHITE) ? 12 : -12;

    return score;
}
