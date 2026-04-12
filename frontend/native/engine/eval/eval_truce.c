#include "eval_types.h"

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Truce: Helper functions                                                 */
/* ═══════════════════════════════════════════════════════════════════════════ */

static int truce_start_pawn_harassers(const Board *b, Color bishop_side, Square sq) {
    Color opp = (Color)(bishop_side ^ 1);
    int target_rank = (opp == WHITE) ? 3 : 4;
    int start_rank = (opp == WHITE) ? 1 : 6;
    int count = 0;
    int file = SQ_COL(sq);

    if (SQ_ROW(sq) != target_rank) return 0;

    if (file > 0 && BB_HAS(b->pieces[opp][PAWN], SQ(start_rank, file - 1))) count++;
    if (file < 7 && BB_HAS(b->pieces[opp][PAWN], SQ(start_rank, file + 1))) count++;

    return count;
}


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Truce: Piece-Square Tables                                              */
/* ═══════════════════════════════════════════════════════════════════════════ */

const int PST_TRUCE_PAWN[64] = {
     0,  0,  0,  0,  0,  0,  0,  0,   /* rank 1 */
     2,  5,  8, 12, 12,  8,  5,  2,   /* rank 2: slight center pull */
     5, 10, 18, 28, 28, 18, 10,  5,   /* rank 3: developing */
     8, 15, 28, 38, 38, 28, 15,  8,   /* rank 4: strong center */
    12, 20, 32, 42, 42, 32, 20, 12,   /* rank 5: deep space */
    18, 25, 35, 45, 45, 35, 25, 18,   /* rank 6: advanced */
    25, 30, 40, 50, 50, 40, 30, 25,   /* rank 7: threatening */
     0,  0,  0,  0,  0,  0,  0,  0,   /* rank 8 */
};

/* Truce knights: outpost-focused.  Central squares and deep positions
   are very strong since they can't be easily exchanged during truce. */
const int PST_TRUCE_KNIGHT[64] = {
    -50,-35,-25,-25,-25,-25,-35,-50,
    -35,-15,  5,  8,  8,  5,-15,-35,
    -20,  8, 18, 25, 25, 18,  8,-20,
    -15, 10, 25, 35, 35, 25, 10,-15,   /* rank 4: strong outpost zone */
    -15, 12, 28, 38, 38, 28, 12,-15,   /* rank 5: deep outpost */
    -20, 10, 22, 30, 30, 22, 10,-20,
    -35,-15,  5, 10, 10,  5,-15,-35,
    -50,-35,-25,-25,-25,-25,-35,-50,
};

/* Truce bishops: long diagonal control is key when captures are banned.
   Bishops that control the center from afar are very strong. */
const int PST_TRUCE_BISHOP[64] = {
    -20,-10,-15,-10,-10,-15,-10,-20,
    -10, 10,  5,  8,  8,  5, 10,-10,
    -10, 12, 15, 18, 18, 15, 12,-10,
     -5, 10, 18, 22, 22, 18, 10, -5,
     -5, 12, 18, 22, 22, 18, 12, -5,
    -10, 12, 15, 18, 18, 15, 12,-10,
    -10, 15, 10,  8,  8, 10, 15,-10,
    -20,-10,-15,-10,-10,-15,-10,-20,
};


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Truce: Strategic evaluation                                             */
/* ═══════════════════════════════════════════════════════════════════════════ */

int eval_truce(const Board *b, const EvalContext *ctx) {
    int score = 0;
    Bitboard pawn_atk[2];
    pawn_atk[0] = ctx->pawn_atk[0];
    pawn_atk[1] = ctx->pawn_atk[1];
    int bishop_count[2];
    bishop_count[0] = ctx->bishop_count[0];
    bishop_count[1] = ctx->bishop_count[1];

        /* During truce: no captures allowed, so the engine must focus on
           development, center/space control, piece coordination, outposts,
           open files, king safety preparation, and pawn structure — all
           preparing for the post-truce combat phase. */
        for (int c = 0; c < 2; c++) {
            int opp = c ^ 1;
            int bonus = 0;

            /* ─ Development: differentiated by piece type ────────────── */
            int back_rank = (c == WHITE) ? 0 : 7;
            int second_rank = (c == WHITE) ? 1 : 6;
            int developed_count = 0;
            bool early_truce = (b->fullmove <= 6);
            for (int t = KNIGHT; t <= QUEEN; t++) {
                Bitboard bb = b->pieces[c][t];
                while (bb) {
                    Square sq = (Square)bb_pop_lsb(&bb);
                    int row = SQ_ROW(sq);
                    if (row != back_rank) {
                        developed_count++;
                        /* Knights and bishops: bigger dev bonus (develop first) */
                        if (t == KNIGHT || t == BISHOP) bonus += 15;
                        /* Rooks: modest bonus for leaving back rank early */
                        else if (t == ROOK) bonus += 8;
                        /* Queen: penalize early development (develop minors first;
                           queen must move eventually but shouldn't move first) */
                        else if (early_truce) bonus -= 10;
                        else bonus += 5;
                    } else {
                        /* Penalty for undeveloped minor pieces */
                        if (t == KNIGHT || t == BISHOP) bonus -= 10;
                    }
                }
            }
            /* Synergy bonus: developing multiple pieces is better than one */
            if (developed_count >= 3) bonus += 12;
            if (developed_count >= 5) bonus += 8;

            /* ─ Center control: pieces on central squares ────────────── */
            static const Bitboard center4 =
                ((Bitboard)1 << SQ(3,3)) | ((Bitboard)1 << SQ(3,4)) |
                ((Bitboard)1 << SQ(4,3)) | ((Bitboard)1 << SQ(4,4));
            int cent = bb_popcount(b->occupied[c] & center4);
            bonus += cent * 20;

            /* Extended center (c3-f6 region) */
            static const Bitboard ext_center =
                ((Bitboard)1 << SQ(2,2)) | ((Bitboard)1 << SQ(2,3)) |
                ((Bitboard)1 << SQ(2,4)) | ((Bitboard)1 << SQ(2,5)) |
                ((Bitboard)1 << SQ(3,2)) | ((Bitboard)1 << SQ(3,5)) |
                ((Bitboard)1 << SQ(4,2)) | ((Bitboard)1 << SQ(4,5)) |
                ((Bitboard)1 << SQ(5,2)) | ((Bitboard)1 << SQ(5,3)) |
                ((Bitboard)1 << SQ(5,4)) | ((Bitboard)1 << SQ(5,5));
            int ext = bb_popcount(b->occupied[c] & ext_center);
            bonus += ext * 8;

            /* ─ Knight outposts: knights on rank 4-5 in center ───────── */
            /* Outpost = knight on rank 4/5, supported by own pawn,
               not attackable by enemy pawns on adjacent files */
            {
                Bitboard knights = b->pieces[c][KNIGHT];
                while (knights) {
                    Square sq = (Square)bb_pop_lsb(&knights);
                    int rank = (c == WHITE) ? SQ_ROW(sq) : (7 - SQ_ROW(sq));
                    int col = SQ_COL(sq);
                    if (rank >= 3 && rank <= 5) {
                        /* Check if supported by own pawn */
                        bool supported = false;
                        int pawn_row = (c == WHITE) ? SQ_ROW(sq) - 1 : SQ_ROW(sq) + 1;
                        if (pawn_row >= 0 && pawn_row < 8) {
                            if (col > 0 && BB_HAS(b->pieces[c][PAWN], SQ(pawn_row, col - 1)))
                                supported = true;
                            if (col < 7 && BB_HAS(b->pieces[c][PAWN], SQ(pawn_row, col + 1)))
                                supported = true;
                        }
                        /* Check if enemy pawns can attack this square */
                        bool no_enemy_pawn_attack = true;
                        Bitboard adj_files = BB_EMPTY;
                        if (col > 0) adj_files |= (Bitboard)0x0101010101010101ULL << (col - 1);
                        if (col < 7) adj_files |= (Bitboard)0x0101010101010101ULL << (col + 1);
                        /* Ahead of the knight (from the perspective of
                           the opponent whose pawns would advance toward it) */
                        Bitboard ahead_mask = BB_EMPTY;
                        if (c == WHITE) {
                            for (int r = SQ_ROW(sq) + 1; r < 8; r++)
                                ahead_mask |= (Bitboard)1 << SQ(r, 0);
                            /* shift to fill rank bits — build row mask */
                            ahead_mask = BB_EMPTY;
                            for (int r = SQ_ROW(sq) + 1; r < 8; r++)
                                for (int fc = 0; fc < 8; fc++)
                                    ahead_mask |= (Bitboard)1 << SQ(r, fc);
                        } else {
                            ahead_mask = BB_EMPTY;
                            for (int r = 0; r < SQ_ROW(sq); r++)
                                for (int fc = 0; fc < 8; fc++)
                                    ahead_mask |= (Bitboard)1 << SQ(r, fc);
                        }
                        if (b->pieces[opp][PAWN] & adj_files & ahead_mask)
                            no_enemy_pawn_attack = false;

                        int outpost_bonus = 15;
                        if (supported) outpost_bonus += 12;
                        if (no_enemy_pawn_attack) outpost_bonus += 10;
                        /* Central outposts are stronger */
                        if (col >= 2 && col <= 5) outpost_bonus += 8;
                        bonus += outpost_bonus;
                    }
                }
            }

            /* ─ Bishop pair bonus during truce: very strong since you
               can't exchange them during the truce phase ─────────────── */
            if (bishop_count[c] >= 2) bonus += 25;

            /* ─ Bishop long diagonal control ─────────────────────────── */
            {
                static const Bitboard long_diag_1 =
                    ((Bitboard)1 << SQ(0,0)) | ((Bitboard)1 << SQ(1,1)) |
                    ((Bitboard)1 << SQ(2,2)) | ((Bitboard)1 << SQ(3,3)) |
                    ((Bitboard)1 << SQ(4,4)) | ((Bitboard)1 << SQ(5,5)) |
                    ((Bitboard)1 << SQ(6,6)) | ((Bitboard)1 << SQ(7,7));
                static const Bitboard long_diag_2 =
                    ((Bitboard)1 << SQ(0,7)) | ((Bitboard)1 << SQ(1,6)) |
                    ((Bitboard)1 << SQ(2,5)) | ((Bitboard)1 << SQ(3,4)) |
                    ((Bitboard)1 << SQ(4,3)) | ((Bitboard)1 << SQ(5,2)) |
                    ((Bitboard)1 << SQ(6,1)) | ((Bitboard)1 << SQ(7,0));
                Bitboard bishops = b->pieces[c][BISHOP];
                while (bishops) {
                    Square sq = (Square)bb_pop_lsb(&bishops);
                    Bitboard diag_atk = bishop_attacks_calc(sq, b->all);
                    /* Bonus for controlling central part of long diagonals */
                    int diag_center = bb_popcount(diag_atk & (center4 | ext_center));
                    bonus += diag_center * 4;
                    /* Extra bonus for being on the long diagonals */
                    if (BB_HAS(long_diag_1, sq) || BB_HAS(long_diag_2, sq))
                        bonus += 8;

                    /* A bishop that can be chased immediately by a fresh pawn
                       push is less durable in Truce than its raw mobility suggests. */
                    {
                        int harassers = truce_start_pawn_harassers(b, (Color)c, sq);
                        if (harassers > 0) {
                            bonus -= harassers * 10;
                            if (harassers >= 2) bonus -= 4;
                        }
                    }
                }
            }

            /* ─ Rook: open/semi-open file preparation ────────────────── */
            {
                Bitboard rooks = b->pieces[c][ROOK];
                while (rooks) {
                    Square sq = (Square)bb_pop_lsb(&rooks);
                    Bitboard file = (Bitboard)0x0101010101010101ULL << SQ_COL(sq);
                    bool own_p = (b->pieces[c][PAWN] & file) != 0;
                    bool opp_p = (b->pieces[opp][PAWN] & file) != 0;
                    if (!own_p && !opp_p) bonus += 20;      /* open file */
                    else if (!own_p)       bonus += 12;      /* semi-open */
                    /* Rook on 7th rank (opponent's 2nd) */
                    int sev_rank = (c == WHITE) ? 6 : 1;
                    if (SQ_ROW(sq) == sev_rank) bonus += 15;
                }
            }

            /* ─ Rook connectivity: doubled rooks on same file/rank ───── */
            {
                Bitboard rooks = b->pieces[c][ROOK];
                int rook_count = bb_popcount(rooks);
                if (rook_count >= 2) {
                    /* Check if two rooks share the same file or rank */
                    Bitboard rtmp = rooks;
                    Square r1 = (Square)bb_pop_lsb(&rtmp);
                    Square r2 = (Square)bb_pop_lsb(&rtmp);
                    if (SQ_COL(r1) == SQ_COL(r2) || SQ_ROW(r1) == SQ_ROW(r2))
                        bonus += 15;
                }
            }

            /* ─ Space: pieces advanced into opponent's half ──────────── */
            /* Only count space for pieces NOT on enemy-pawn-attacked
               squares — overextended pieces are liabilities, not assets */
            for (int t = KNIGHT; t <= QUEEN; t++) {
                Bitboard bb = b->pieces[c][t];
                while (bb) {
                    Square sq = (Square)bb_pop_lsb(&bb);
                    int rank = (c == WHITE) ? SQ_ROW(sq) : (7 - SQ_ROW(sq));
                    if (rank >= 4) {
                        if (BB_HAS(pawn_atk[opp], sq)) {
                            /* Overextended: on a square attacked by enemy pawn */
                            bonus -= 5;
                        } else {
                            bonus += 12;
                            if (rank >= 5) bonus += 8;
                        }
                    }
                }
            }

            /* ─ Pawn connectivity: connected pawns form strong chains ── */
            {
                Bitboard pawns = b->pieces[c][PAWN];
                Bitboard tmp = pawns;
                int connected = 0;
                int isolated_cnt = 0;
                while (tmp) {
                    Square sq = (Square)bb_pop_lsb(&tmp);
                    int col = SQ_COL(sq);
                    Bitboard adj = BB_EMPTY;
                    if (col > 0) adj |= (Bitboard)0x0101010101010101ULL << (col - 1);
                    if (col < 7) adj |= (Bitboard)0x0101010101010101ULL << (col + 1);
                    if (pawns & adj) {
                        connected++;
                    } else {
                        isolated_cnt++;
                    }
                }
                bonus += connected * 5 - isolated_cnt * 10;
            }

            /* ─ Pawn space: fourth-rank pawns claim durable territory ─ */
            /* A pawn that reaches the 4th rank (or beyond) during truce
               secures space that cannot be challenged immediately by
               captures, so the eval should prefer the more ambitious push
               over a passive one-step shuffle when it is safe enough. */
            {
                Bitboard pawns = b->pieces[c][PAWN];
                bool advanced_file[8] = {false};
                while (pawns) {
                    Square sq = (Square)bb_pop_lsb(&pawns);
                    int rank = (c == WHITE) ? SQ_ROW(sq) : (7 - SQ_ROW(sq));
                    int file = SQ_COL(sq);
                    if (rank >= 3) {
                        int pawn_space = 8;
                        if (!BB_HAS(pawn_atk[opp], sq)) pawn_space += 4;
                        if (rank >= 4) pawn_space += 4;
                        bonus += pawn_space;
                        if (file >= 2 && file <= 5) advanced_file[file] = true;
                    }
                }

                /* Central pawn fronts are especially strong in Truce because
                   captures are suppressed, so the opponent cannot immediately
                   challenge a d/e duo or a broad d/e/f wedge. */
                if (advanced_file[3] && advanced_file[4]) bonus += 22;
                if (advanced_file[2] && advanced_file[3]) bonus += 10;
                if (advanced_file[4] && advanced_file[5]) bonus += 10;
                if (advanced_file[3] && advanced_file[4] &&
                    (advanced_file[2] || advanced_file[5]))
                    bonus += 10;
            }

            /* ─ King safety preparation: king should castle early ────── */
            {
                Bitboard kbb = b->pieces[c][KING];
                if (kbb) {
                    Square ksq = bb_lsb(kbb);
                    int kc = SQ_COL(ksq);
                    /* Bonus if king is castled (on the wing) */
                    if (kc <= 2 || kc >= 6) bonus += 18;
                    /* Penalty for king stuck in center during truce */
                    if (kc >= 3 && kc <= 4) bonus -= 12;
                    /* Pawn shield in front of king */
                    int fwd = (c == WHITE) ? 1 : -1;
                    int shield = 0;
                    for (int dc = -1; dc <= 1; dc++) {
                        int nc = kc + dc, nr = SQ_ROW(ksq) + fwd;
                        if (nc < 0 || nc > 7 || nr < 0 || nr > 7) continue;
                        if (BB_HAS(b->pieces[c][PAWN], SQ(nr, nc))) shield++;
                    }
                    bonus += shield * 10;
                }
            }

            /* ─ Piece harmony: having a variety of developed pieces ──── */
            {
                int piece_types_developed = 0;
                for (int t = KNIGHT; t <= QUEEN; t++) {
                    Bitboard bb = b->pieces[c][t];
                    while (bb) {
                        Square sq = (Square)bb_pop_lsb(&bb);
                        if (SQ_ROW(sq) != back_rank) {
                            piece_types_developed |= (1 << t);
                            break;
                        }
                    }
                }
                int variety = bb_popcount((Bitboard)piece_types_developed);
                bonus += variety * 8;
            }

            /* ─ CRITICAL: Piece vulnerability / safety during truce ──── */
            /* During truce, captures are disabled in the move generator,
               so the search literally cannot see that pieces on attacked
               squares WILL be captured once the truce breaks.  The eval
               must penalize pieces sitting on squares where the opponent
               can attack them, proportional to the danger level.
               This prevents the engine from placing a rook on g6 when
               f7-pawn can capture it the moment truce ends. */
            {
                /* Build attack maps for the opponent */
                Bitboard opp_pawn_atk = pawn_atk[opp];
                /* Knight attacks */
                Bitboard opp_knight_atk = BB_EMPTY;
                {
                    Bitboard kn = b->pieces[opp][KNIGHT];
                    while (kn) {
                        Square s = (Square)bb_pop_lsb(&kn);
                        opp_knight_atk |= knight_attacks[s];
                    }
                }
                /* Bishop/queen diagonal attacks */
                Bitboard opp_bishop_atk = BB_EMPTY;
                {
                    Bitboard bi = b->pieces[opp][BISHOP] | b->pieces[opp][QUEEN];
                    while (bi) {
                        Square s = (Square)bb_pop_lsb(&bi);
                        opp_bishop_atk |= bishop_attacks_calc(s, b->all);
                    }
                }
                /* Rook/queen straight attacks */
                Bitboard opp_rook_atk = BB_EMPTY;
                {
                    Bitboard ro = b->pieces[opp][ROOK] | b->pieces[opp][QUEEN];
                    while (ro) {
                        Square s = (Square)bb_pop_lsb(&ro);
                        opp_rook_atk |= rook_attacks_calc(s, b->all);
                    }
                }

                Bitboard opp_all_atk = opp_pawn_atk | opp_knight_atk
                                     | opp_bishop_atk | opp_rook_atk;

                /* Build own defense map to detect defended pieces */
                Bitboard own_pawn_def = pawn_atk[c];
                Bitboard own_knight_def = BB_EMPTY;
                {
                    Bitboard kn = b->pieces[c][KNIGHT];
                    while (kn) {
                        Square s = (Square)bb_pop_lsb(&kn);
                        own_knight_def |= knight_attacks[s];
                    }
                }
                Bitboard own_bishop_def = BB_EMPTY;
                {
                    Bitboard bi = b->pieces[c][BISHOP] | b->pieces[c][QUEEN];
                    while (bi) {
                        Square s = (Square)bb_pop_lsb(&bi);
                        own_bishop_def |= bishop_attacks_calc(s, b->all);
                    }
                }
                Bitboard own_rook_def = BB_EMPTY;
                {
                    Bitboard ro = b->pieces[c][ROOK] | b->pieces[c][QUEEN];
                    while (ro) {
                        Square s = (Square)bb_pop_lsb(&ro);
                        own_rook_def |= rook_attacks_calc(s, b->all);
                    }
                }
                Bitboard own_all_def = own_pawn_def | own_knight_def
                                     | own_bishop_def | own_rook_def;

                /* Penalty table: material value fraction for undefended
                   pieces on attacked squares (losing the exchange). */
                static const int VULN_PENALTY[6] = {
                    /* PAWN=15, KNIGHT=55, BISHOP=55, ROOK=85, QUEEN=150, KING=0 */
                    15, 55, 55, 85, 150, 0
                };
                /* Reduced penalty when piece IS defended (still bad: opponent
                   can force the trade, but at least we get material back) */
                static const int VULN_DEFENDED[6] = {
                    5, 20, 20, 30, 50, 0
                };

                for (int t = PAWN; t <= QUEEN; t++) {
                    Bitboard bb = b->pieces[c][t];
                    while (bb) {
                        Square sq = (Square)bb_pop_lsb(&bb);
                        if (!BB_HAS(opp_all_atk, sq)) continue;

                        bool defended = BB_HAS(own_all_def, sq);
                        /* Extra danger: attacked by pawn (cheapest attacker) */
                        bool pawn_attacked = BB_HAS(opp_pawn_atk, sq);
                        int pen = defended ? VULN_DEFENDED[t] : VULN_PENALTY[t];
                        /* Pawn attacks on non-pawn pieces: even worse since
                           the attacker is worth less than any target */
                        if (pawn_attacked && t >= KNIGHT) pen += 20;
                        bonus -= pen;
                    }
                }
            }

            score += (c == WHITE) ? bonus : -bonus;
        }

        /* Tempo bonus during truce (initiative matters for development) */
        score += (b->side == WHITE) ? 15 : -15;

    return score;
}
