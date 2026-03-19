#include "evaluate.h"
#include <stdlib.h>  /* abs() */

/* Heir: check rules apply when player has promoted a king or has no pawns */
static inline bool heir_check_applies(const Board *b, Color side) {
    return b->heir_promoted[side] || b->pieces[side][PAWN] == BB_EMPTY;
}

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Material values (centipawns)                                             */
/* ═══════════════════════════════════════════════════════════════════════════ */

static const int MATERIAL[6] = {
    100,   /* PAWN   */
    320,   /* KNIGHT */
    330,   /* BISHOP */
    500,   /* ROOK   */
    900,   /* QUEEN  */
    0      /* KING   */
};

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Piece-Square Tables (from white's perspective, row 0 = rank 1)           */
/* ═══════════════════════════════════════════════════════════════════════════ */

static const int PST_PAWN[64] = {
     0,  0,  0,  0,  0,  0,  0,  0,
     5, 10, 10,-20,-20, 10, 10,  5,
     5, -5,-10,  0,  0,-10, -5,  5,
     0,  0,  0, 20, 20,  0,  0,  0,
     5,  5, 10, 25, 25, 10,  5,  5,
    10, 10, 20, 30, 30, 20, 10, 10,
    50, 50, 50, 50, 50, 50, 50, 50,
     0,  0,  0,  0,  0,  0,  0,  0,
};

static const int PST_KNIGHT[64] = {
    -50,-40,-30,-30,-30,-30,-40,-50,
    -40,-20,  0,  5,  5,  0,-20,-40,
    -30,  5, 10, 15, 15, 10,  5,-30,
    -30,  0, 15, 20, 20, 15,  0,-30,
    -30,  5, 15, 20, 20, 15,  5,-30,
    -30,  0, 10, 15, 15, 10,  0,-30,
    -40,-20,  0,  0,  0,  0,-20,-40,
    -50,-40,-30,-30,-30,-30,-40,-50,
};

static const int PST_BISHOP[64] = {
    -20,-10,-10,-10,-10,-10,-10,-20,
    -10,  5,  0,  0,  0,  0,  5,-10,
    -10, 10, 10, 10, 10, 10, 10,-10,
    -10,  0, 10, 10, 10, 10,  0,-10,
    -10,  5,  5, 10, 10,  5,  5,-10,
    -10,  0,  5, 10, 10,  5,  0,-10,
    -10,  0,  0,  0,  0,  0,  0,-10,
    -20,-10,-10,-10,-10,-10,-10,-20,
};

static const int PST_ROOK[64] = {
      0,  0,  0,  5,  5,  0,  0,  0,
     -5,  0,  0,  0,  0,  0,  0, -5,
     -5,  0,  0,  0,  0,  0,  0, -5,
     -5,  0,  0,  0,  0,  0,  0, -5,
     -5,  0,  0,  0,  0,  0,  0, -5,
     -5,  0,  0,  0,  0,  0,  0, -5,
      5, 10, 10, 10, 10, 10, 10,  5,
      0,  0,  0,  0,  0,  0,  0,  0,
};

static const int PST_QUEEN[64] = {
    -20,-10,-10, -5, -5,-10,-10,-20,
    -10,  0,  5,  0,  0,  0,  0,-10,
    -10,  5,  5,  5,  5,  5,  0,-10,
      0,  0,  5,  5,  5,  5,  0, -5,
     -5,  0,  5,  5,  5,  5,  0, -5,
    -10,  0,  5,  5,  5,  5,  0,-10,
    -10,  0,  0,  0,  0,  0,  0,-10,
    -20,-10,-10, -5, -5,-10,-10,-20,
};

static const int PST_KING_MG[64] = {
     20, 30, 10,  0,  0, 10, 30, 20,
     20, 20,  0,  0,  0,  0, 20, 20,
    -10,-20,-20,-20,-20,-20,-20,-10,
    -20,-30,-30,-40,-40,-30,-30,-20,
    -30,-40,-40,-50,-50,-40,-40,-30,
    -30,-40,-40,-50,-50,-40,-40,-30,
    -30,-40,-40,-50,-50,-40,-40,-30,
    -30,-40,-40,-50,-50,-40,-40,-30,
};

static const int PST_KING_EG[64] = {
    -50,-30,-30,-30,-30,-30,-30,-50,
    -30,-30,  0,  0,  0,  0,-30,-30,
    -30,-10, 20, 30, 30, 20,-10,-30,
    -30,-10, 30, 40, 40, 30,-10,-30,
    -30,-10, 30, 40, 40, 30,-10,-30,
    -30,-10, 20, 30, 30, 20,-10,-30,
    -30,-20,-10,  0,  0,-10,-20,-30,
    -50,-40,-30,-20,-20,-30,-40,-50,
};

/* Mercenary pawns: centrality matters most (they act like mini-kings).
   Values are aggressive to break the "all moves score equal" problem
   caused by massive transposition space with 16 king-like pawns. */
static const int PST_MERC_PAWN[64] = {
     0,  0,  0,  0,  0,  0,  0,  0,   /* rank 1: back rank, no bonus */
     5, 10, 12, 15, 15, 12, 10,  5,   /* rank 2 */
    12, 22, 35, 45, 45, 35, 22, 12,   /* rank 3 */
    18, 32, 50, 65, 65, 50, 32, 18,   /* rank 4: center is king */
    18, 32, 50, 65, 65, 50, 32, 18,   /* rank 5 */
    12, 22, 35, 45, 45, 35, 22, 12,   /* rank 6 */
     5, 10, 12, 15, 15, 12, 10,  5,   /* rank 7 */
     0,  0,  0,  0,  0,  0,  0,  0,   /* rank 8: back rank */
};

/* Heir pawns: advancement toward promotion is key (they become kings).
   Higher ranks get aggressive bonuses — pawns are the lifeblood. */
static const int PST_HEIR_PAWN[64] = {
     0,  0,  0,  0,  0,  0,  0,  0,   /* rank 1 */
     5, 10, 10,  5,  5, 10, 10,  5,   /* rank 2: modest center preference */
    10, 15, 20, 25, 25, 20, 15, 10,   /* rank 3 */
    15, 20, 30, 35, 35, 30, 20, 15,   /* rank 4: center control + advance */
    25, 30, 40, 50, 50, 40, 30, 25,   /* rank 5: deep territory */
    40, 45, 55, 65, 65, 55, 45, 40,   /* rank 6: near promotion */
    70, 75, 80, 90, 90, 80, 75, 70,   /* rank 7: promotion imminent */
     0,  0,  0,  0,  0,  0,  0,  0,   /* rank 8 */
};

static const int *PST_TABLE[6] = {
    PST_PAWN, PST_KNIGHT, PST_BISHOP, PST_ROOK, PST_QUEEN, PST_KING_MG
};

/* Mirror square for black: row 0↔7, 1↔6, etc. */
static inline int mirror(int sq) { return sq ^ 56; }

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Evaluation                                                               */
/* ═══════════════════════════════════════════════════════════════════════════ */

int evaluate(const Board *b) {
    int mg_score[2] = {0, 0};
    int eg_score[2] = {0, 0};
    int material[2] = {0, 0};
    int pawn_count[2] = {0, 0};
    int bishop_count[2] = {0, 0};

    bool is_merc = (b->mod == MOD_MERCENARY);
    bool is_heir = (b->mod == MOD_HEIR);

    /* Pre-compute pawn attack bitboards (Stockfish: used for safe mobility
       and threat evaluation — pieces on pawn-attacked squares are vulnerable) */
    Bitboard pawn_atk[2] = {BB_EMPTY, BB_EMPTY};
    if (is_merc) {
        for (int c = 0; c < 2; c++) {
            Bitboard p = b->pieces[c][PAWN];
            while (p) {
                Square s = (Square)bb_pop_lsb(&p);
                pawn_atk[c] |= king_attacks[s];
            }
        }
    } else {
        /* Standard diagonal pawn attacks (for classic and heir) */
        Bitboard wp = b->pieces[WHITE][PAWN];
        pawn_atk[WHITE] = ((wp & ~((Bitboard)0x0101010101010101ULL)) << 7) |
                           ((wp & ~((Bitboard)0x8080808080808080ULL)) << 9);
        Bitboard bp = b->pieces[BLACK][PAWN];
        pawn_atk[BLACK] = ((bp & ~((Bitboard)0x8080808080808080ULL)) >> 7) |
                           ((bp & ~((Bitboard)0x0101010101010101ULL)) >> 9);
    }

    /* ── 1. Material, PST, Mobility ──────────────────────────────────────── */

    for (int c = 0; c < 2; c++) {
        for (int t = 0; t < 6; t++) {
            Bitboard bb = b->pieces[c][t];
            while (bb) {
                Square sq = (Square)bb_pop_lsb(&bb);
                int idx = (c == WHITE) ? sq : mirror(sq);

                int mat = MATERIAL[t];
                /* Mercenary pawns move like kings — worth more */
                if (t == PAWN && is_merc) mat = 180;
                /* Heir: pawns are king replacements — worth more */
                if (t == PAWN && is_heir) mat = 140;
                /* Heir: expendable king (check rules don't apply) has material value */
                if (t == KING && is_heir) {
                    if (!heir_check_applies(b, (Color)c))
                        mat = 250; /* expendable: valuable but sacrificeable */
                    else
                        mat = 0;   /* critical: infinite value (via checkmate) */
                }
                material[c] += mat;
                mg_score[c] += mat;
                eg_score[c] += mat;

                if (t == PAWN && is_merc) {
                    /* Mercenary pawns use their own PST for positional play */
                    mg_score[c] += PST_MERC_PAWN[idx];
                    eg_score[c] += PST_MERC_PAWN[idx];

                    /* Quadratic advancement bonus: makes retreating very costly.
                       rank 1=3, 2=12, 3=27, 4=48, 5=75, 6=108 */
                    int rank = (c == WHITE) ? SQ_ROW(sq) : (7 - SQ_ROW(sq));
                    if (rank >= 1 && rank <= 6) {
                        int adv = rank * rank * 3;
                        mg_score[c] += adv;
                        eg_score[c] += adv * 2;
                    }
                } else if (t == PAWN && is_heir) {
                    /* Heir pawns: advancement PST + promotion-potential bonus */
                    mg_score[c] += PST_HEIR_PAWN[idx];
                    eg_score[c] += PST_HEIR_PAWN[idx];

                    /* Advancement bonus scaled quadratically: closer to promo = bigger */
                    int rank = (c == WHITE) ? SQ_ROW(sq) : (7 - SQ_ROW(sq));
                    if (rank >= 3) {
                        int adv = (rank - 2) * (rank - 2) * 8;
                        mg_score[c] += adv;
                        eg_score[c] += adv * 2;
                    }
                } else if (t == KING) {
                    mg_score[c] += PST_KING_MG[idx];
                    eg_score[c] += PST_KING_EG[idx];
                } else {
                    mg_score[c] += PST_TABLE[t][idx];
                    eg_score[c] += PST_TABLE[t][idx];
                }

                if (t == PAWN)   pawn_count[c]++;
                if (t == BISHOP) bishop_count[c]++;

                /* Mobility: count safe squares not blocked by own pieces.
                   Stockfish-inspired: exclude enemy pawn attacks for minor
                   pieces (knights/bishops/merc pawns) — vulnerable there.
                   Rooks/queens keep full mobility (they outrange pawns). */
                Bitboard own_occ = b->occupied[c];
                Bitboard safe_sq = ~own_occ & ~pawn_atk[c ^ 1];
                if (t == PAWN && is_merc) {
                    int mob = bb_popcount(king_attacks[sq] & safe_sq);
                    mg_score[c] += mob * 5;
                    eg_score[c] += mob * 5;
                } else if (t == KNIGHT) {
                    int mob = bb_popcount(knight_attacks[sq] & safe_sq);
                    mg_score[c] += mob * 4;
                    eg_score[c] += mob * 4;
                } else if (t == BISHOP) {
                    int mob = bb_popcount(bishop_attacks_calc(sq, b->all) & safe_sq);
                    mg_score[c] += mob * 5;
                    eg_score[c] += mob * 5;
                } else if (t == ROOK) {
                    int mob = bb_popcount(rook_attacks_calc(sq, b->all) & ~own_occ);
                    mg_score[c] += mob * 2;
                    eg_score[c] += mob * 3;
                } else if (t == QUEEN) {
                    Bitboard q_atk = bishop_attacks_calc(sq, b->all)
                                   | rook_attacks_calc(sq, b->all);
                    int mob = bb_popcount(q_atk & ~own_occ);
                    mg_score[c] += mob * 1;
                    eg_score[c] += mob * 2;
                }
            }
        }
    }

    /* ── Game phase (0 = endgame, 256 = opening) ─────────────────────────── */
    int total_mat = material[WHITE] + material[BLACK];
    int phase = (total_mat * 256) / 8000;
    if (phase > 256) phase = 256;
    int mg_weight = phase;
    int eg_weight = 256 - phase;

    /* ── Interpolated score ──────────────────────────────────────────────── */
    int mg = mg_score[WHITE] - mg_score[BLACK];
    int eg = eg_score[WHITE] - eg_score[BLACK];
    int score = (mg * mg_weight + eg * eg_weight) / 256;

    /* ── 2. Bishop pair ──────────────────────────────────────────────────── */
    if (bishop_count[WHITE] >= 2) score += 30;
    if (bishop_count[BLACK] >= 2) score -= 30;

    if (is_merc) {
        /* Extra incentive to keep pawns */
        score += (pawn_count[WHITE] - pawn_count[BLACK]) * 25;

        /* Pawn proximity to enemy king — modest bonus to avoid overvaluing
           pawn pushes toward the king at the expense of material safety. */
        for (int c = 0; c < 2; c++) {
            Bitboard kbb = b->pieces[c ^ 1][KING];
            if (!kbb) continue;
            Square ksq = bb_lsb(kbb);
            int kr = SQ_ROW(ksq), kc = SQ_COL(ksq);
            Bitboard pawns = b->pieces[c][PAWN];
            int prox = 0;
            while (pawns) {
                Square sq = (Square)bb_pop_lsb(&pawns);
                int dr = abs(SQ_ROW(sq) - kr);
                int dc = abs(SQ_COL(sq) - kc);
                int dist = dr > dc ? dr : dc; /* Chebyshev distance */
                if (dist <= 3) {
                    static const int PROX[] = {0, 12, 6, 2};
                    prox += PROX[dist];
                }
            }
            score += (c == WHITE) ? prox : -prox;
        }

        /* Mercenary pawn connectivity: pawns adjacent to friendly pawns
           form stronger clusters.  Isolated pawns are vulnerable. */
        for (int c = 0; c < 2; c++) {
            Bitboard pawns = b->pieces[c][PAWN];
            Bitboard tmp = pawns;
            int connected = 0;
            int isolated = 0;
            while (tmp) {
                Square sq = (Square)bb_pop_lsb(&tmp);
                Bitboard neighbors = king_attacks[sq] & pawns;
                if (neighbors) {
                    connected += bb_popcount(neighbors);
                } else {
                    isolated++;
                }
            }
            int bonus = connected * 6 - isolated * 12;
            score += (c == WHITE) ? bonus : -bonus;
        }

        /* Space advantage: pawns in opponent's half of the board.
           White pawns on rank >= 5 (rows 4-6), Black on rank <= 2 (rows 1-3). */
        {
            int w_space = 0, b_space = 0;
            Bitboard wp = b->pieces[WHITE][PAWN];
            while (wp) {
                Square sq = (Square)bb_pop_lsb(&wp);
                int row = SQ_ROW(sq);
                if (row >= 4) w_space++; /* rank 5+ for White */
            }
            Bitboard bp = b->pieces[BLACK][PAWN];
            while (bp) {
                Square sq = (Square)bb_pop_lsb(&bp);
                int row = SQ_ROW(sq);
                if (row <= 3) b_space++; /* rank 5+ for Black (mirrored) */
            }
            score += (w_space - b_space) * 18;
        }
    }

    /* ── Heir-specific strategic evaluation ──────────────────────────────── */
    if (is_heir) {
        for (int c = 0; c < 2; c++) {
            int opp = c ^ 1;
            bool has_king = b->pieces[c][KING] != BB_EMPTY;
            int pawns = bb_popcount(b->pieces[c][PAWN]);
            int bonus = 0;

            /* Pawn count safety net: more pawns = more insurance */
            bonus += pawns * 30;

            /* No-king penalty: vulnerable state, need to promote ASAP */
            if (!has_king) {
                bonus -= 350;
                if (pawns <= 2) bonus -= 150;
                if (pawns <= 1) bonus -= 200;
            }

            /* Opponent has no king: bonus for attacking their pawns */
            if (b->pieces[opp][KING] == BB_EMPTY) {
                bonus += 100;
                int opp_pawns = bb_popcount(b->pieces[opp][PAWN]);
                if (opp_pawns <= 2) bonus += 150;
                if (opp_pawns <= 1) bonus += 200;
            }

            /* Promoted king safety: when check rules apply, king safety
               is paramount — add extra weight (standard king safety already
               runs below, but give Heir an extra multiplier) */
            if (has_king && heir_check_applies(b, (Color)c)) {
                bonus += 50; /* bonus for having a stable protected king */
            }

            score += (c == WHITE) ? bonus : -bonus;
        }
    }

    /* ── 3. Pawn structure (doubled, isolated) — skip for Mercenary ──── */
    if (!is_merc) {
        for (int col = 0; col < 8; col++) {
            Bitboard file_mask = (Bitboard)0x0101010101010101ULL << col;
            int wp = bb_popcount(b->pieces[WHITE][PAWN] & file_mask);
            int bp = bb_popcount(b->pieces[BLACK][PAWN] & file_mask);

            if (wp > 1) score -= (wp - 1) * 15;
            if (bp > 1) score += (bp - 1) * 15;

            /* Isolated: no own pawns on adjacent files */
            Bitboard adj = BB_EMPTY;
            if (col > 0) adj |= (Bitboard)0x0101010101010101ULL << (col - 1);
            if (col < 7) adj |= (Bitboard)0x0101010101010101ULL << (col + 1);
            if (wp > 0 && !(b->pieces[WHITE][PAWN] & adj)) score -= 12;
            if (bp > 0 && !(b->pieces[BLACK][PAWN] & adj)) score += 12;
        }
    }

    /* ── 4. Passed pawns (standard chess only) ───────────────────────────── */
    if (!is_merc) {
    static const int PASSED_BONUS[8] = { 0, 5, 10, 20, 40, 60, 100, 0 };
    for (int c = 0; c < 2; c++) {
        Color opp = (Color)(c ^ 1);
        Bitboard bb = b->pieces[c][PAWN];
        while (bb) {
            Square sq = (Square)bb_pop_lsb(&bb);
            int row = SQ_ROW(sq), col = SQ_COL(sq);
            int rank = (c == WHITE) ? row : (7 - row);

            /* A pawn is passed if no enemy pawns ahead on same or adjacent files */
            bool passed = true;
            int r_start = (c == WHITE) ? row + 1 : 0;
            int r_end   = (c == WHITE) ? 8 : row;
            for (int r = r_start; r < r_end && passed; r++) {
                for (int dc = -1; dc <= 1; dc++) {
                    int nc = col + dc;
                    if (nc < 0 || nc > 7) continue;
                    if (BB_HAS(b->pieces[opp][PAWN], SQ(r, nc))) {
                        passed = false;
                        break;
                    }
                }
            }
            if (passed) {
                int mg_b = PASSED_BONUS[rank];
                int eg_b = mg_b * 3 / 2;
                int pp = (mg_b * mg_weight + eg_b * eg_weight) / 256;
                score += (c == WHITE) ? pp : -pp;
            }
        }
    }
    } /* end if (!is_merc) for passed pawns */

    /* ── 5. Rook on open / semi-open files (skip for Mercenary) ────────── */
    if (!is_merc) {
    for (int c = 0; c < 2; c++) {
        Color opp = (Color)(c ^ 1);
        Bitboard bb = b->pieces[c][ROOK];
        while (bb) {
            Square sq = (Square)bb_pop_lsb(&bb);
            Bitboard file = (Bitboard)0x0101010101010101ULL << SQ_COL(sq);
            bool own_p = (b->pieces[c][PAWN] & file) != 0;
            bool opp_p = (b->pieces[opp][PAWN] & file) != 0;
            int bonus = 0;
            if (!own_p && !opp_p) bonus = 25;      /* open file */
            else if (!own_p)       bonus = 15;      /* semi-open */
            score += (c == WHITE) ? bonus : -bonus;
        }
    }
    }

    /* ── 6. King safety (always active for Mercenary; middlegame for standard;
              Heir: only when check rules apply) ──────────────────────────── */
    if (mg_weight > 64 || is_merc) {
        for (int c = 0; c < 2; c++) {
            Color opp = (Color)(c ^ 1);
            Bitboard kbb = b->pieces[c][KING];
            if (kbb == BB_EMPTY) continue;
            /* Heir: skip king safety when check rules don't apply (king is expendable) */
            if (is_heir && !heir_check_applies(b, (Color)c)) continue;
            Square ksq = bb_lsb(kbb);

            /* 6a. Pawn shield */
            int kr = SQ_ROW(ksq), kc = SQ_COL(ksq);
            int shield = 0;
            if (is_merc) {
                /* Mercenary: count ALL adjacent friendly pawns as shield */
                shield = bb_popcount(b->pieces[c][PAWN] & king_attacks[ksq]);
            } else {
                int fwd = (c == WHITE) ? 1 : -1;
                for (int dc = -1; dc <= 1; dc++) {
                    int nc = kc + dc, nr = kr + fwd;
                    if (nc < 0 || nc > 7 || nr < 0 || nr > 7) continue;
                    if (BB_HAS(b->pieces[c][PAWN], SQ(nr, nc))) shield++;
                }
            }
            int shield_weight = is_merc ? 20 : 10;
            /* Mercenary: use min 100/256 phase weight so safety never fully disappears */
            int kw = is_merc ? (mg_weight > 100 ? mg_weight : 100) : mg_weight;
            int s_bonus = shield * shield_weight * kw / 256;
            score += (c == WHITE) ? s_bonus : -s_bonus;

            /* 6b. Attacker count in king zone */
            Bitboard king_zone = king_attacks[ksq] | BB_SQ(ksq);
            int attack_weight = 0;

            Bitboard oq = b->pieces[opp][QUEEN];
            while (oq) {
                Square s = (Square)bb_pop_lsb(&oq);
                if ((bishop_attacks_calc(s, b->all) | rook_attacks_calc(s, b->all)) & king_zone)
                    attack_weight += 5;
            }
            Bitboard or_ = b->pieces[opp][ROOK];
            while (or_) {
                Square s = (Square)bb_pop_lsb(&or_);
                if (rook_attacks_calc(s, b->all) & king_zone) attack_weight += 3;
            }
            Bitboard ob = b->pieces[opp][BISHOP];
            while (ob) {
                Square s = (Square)bb_pop_lsb(&ob);
                if (bishop_attacks_calc(s, b->all) & king_zone) attack_weight += 2;
            }
            Bitboard on = b->pieces[opp][KNIGHT];
            while (on) {
                Square s = (Square)bb_pop_lsb(&on);
                if (knight_attacks[s] & king_zone) attack_weight += 2;
            }

            /* Mercenary pawns attack like kings — include in king danger */
            if (is_merc) {
                Bitboard op = b->pieces[opp][PAWN];
                while (op) {
                    Square s = (Square)bb_pop_lsb(&op);
                    if (king_attacks[s] & king_zone) attack_weight += 4;
                }
            }

            /* Mercenary: use min phase weight 100 so danger never fully disappears;
               Standard: scale by game phase */
            int danger = (attack_weight * attack_weight * kw) >> 8;
            score += (c == WHITE) ? -danger : danger;
        }
    }

    /* ── 7. Threat evaluation (Stockfish-inspired) ───────────────────────── */
    /*  Bonus for pawns attacking enemy non-pawn pieces.  One of Stockfish's */
    /*  strongest non-material eval terms — makes the engine target enemy    */
    /*  pieces with cheap attackers and avoid leaving pieces en prise.       */
    for (int c = 0; c < 2; c++) {
        Bitboard threatened = pawn_atk[c] & b->occupied[c ^ 1]
                            & ~b->pieces[c ^ 1][PAWN];
        int tb = 0;
        while (threatened) {
            Square s = (Square)bb_pop_lsb(&threatened);
            PieceType pt = PIECE_TYPE(b->mailbox[s]);
            /* Bonus by victim value: N=30, B=30, R=50, Q=70, K=0 */
            static const int THREAT_BY_PAWN[] = { 0, 30, 30, 50, 70, 0 };
            if (pt < 6) tb += THREAT_BY_PAWN[pt];
        }
        score += (c == WHITE) ? tb : -tb;
    }

    /* Tempo bonus: side to move gets a small bonus (helps the side with
       initiative, and crucially breaks the "all moves score 0" problem in
       Mercenary where massive transpositions equalize everything). */
    if (is_merc) score += (b->side == WHITE) ? 15 : -15;
    if (is_heir) score += (b->side == WHITE) ? 10 : -10;

    /* Return from side-to-move's perspective */
    return (b->side == WHITE) ? score : -score;
}
