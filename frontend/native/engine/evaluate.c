#include "evaluate.h"
#include <stdlib.h>  /* abs() */

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

/* Mercenary pawns: centrality matters most (they act like mini-kings) */
static const int PST_MERC_PAWN[64] = {
     0,  0,  0,  0,  0,  0,  0,  0,
     5,  5,  5,  5,  5,  5,  5,  5,
     5, 10, 15, 20, 20, 15, 10,  5,
    10, 15, 25, 30, 30, 25, 15, 10,
    10, 15, 25, 30, 30, 25, 15, 10,
     5, 10, 15, 20, 20, 15, 10,  5,
     5,  5,  5,  5,  5,  5,  5,  5,
     0,  0,  0,  0,  0,  0,  0,  0,
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
                material[c] += mat;
                mg_score[c] += mat;
                eg_score[c] += mat;

                if (t == PAWN && is_merc) {
                    /* Rank-based advancement bonus (no centrality bias) */
                    int rank = (c == WHITE) ? SQ_ROW(sq) : (7 - SQ_ROW(sq));
                    int adv = (rank >= 1 && rank <= 6) ? rank * 3 : 0;
                    mg_score[c] += adv;
                    eg_score[c] += adv;
                } else if (t == KING) {
                    mg_score[c] += PST_KING_MG[idx];
                    eg_score[c] += PST_KING_EG[idx];
                } else {
                    mg_score[c] += PST_TABLE[t][idx];
                    eg_score[c] += PST_TABLE[t][idx];
                }

                if (t == PAWN)   pawn_count[c]++;
                if (t == BISHOP) bishop_count[c]++;

                /* Mobility: count squares attacked not blocked by own pieces */
                Bitboard own_occ = b->occupied[c];
                if (t == PAWN && is_merc) {
                    /* Mercenary: skip mobility — too uniform, adds noise */
                } else if (t == KNIGHT) {
                    int mob = bb_popcount(knight_attacks[sq] & ~own_occ);
                    mg_score[c] += mob * 4;
                    eg_score[c] += mob * 4;
                } else if (t == BISHOP) {
                    int mob = bb_popcount(bishop_attacks_calc(sq, b->all) & ~own_occ);
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
        score += (pawn_count[WHITE] - pawn_count[BLACK]) * 20;

        /* Pawn proximity to enemy king — THE key positional factor in Mercenary.
           Pawns near the enemy king threaten checkmate; reward this directly. */
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
                if (dist <= 4) {
                    static const int PROX[] = {0, 25, 15, 8, 3};
                    prox += PROX[dist];
                }
            }
            score += (c == WHITE) ? prox : -prox;
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

    /* ── 6. King safety (always active for Mercenary; middlegame for standard) */
    if (mg_weight > 64 || is_merc) {
        for (int c = 0; c < 2; c++) {
            Color opp = (Color)(c ^ 1);
            Bitboard kbb = b->pieces[c][KING];
            if (kbb == BB_EMPTY) continue;
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

    /* Return from side-to-move's perspective */
    return (b->side == WHITE) ? score : -score;
}
