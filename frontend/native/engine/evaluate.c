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

/* Truce pawns: center control and space preparation are paramount.
   Advanced central pawns control key squares for the post-truce fight.
   Edge pawns are less useful since they control fewer squares. */
static const int PST_TRUCE_PAWN[64] = {
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
static const int PST_TRUCE_KNIGHT[64] = {
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
static const int PST_TRUCE_BISHOP[64] = {
    -20,-10,-15,-10,-10,-15,-10,-20,
    -10, 10,  5,  8,  8,  5, 10,-10,
    -10, 12, 15, 18, 18, 15, 12,-10,
     -5, 10, 18, 22, 22, 18, 10, -5,
     -5, 12, 18, 22, 22, 18, 12, -5,
    -10, 12, 15, 18, 18, 15, 12,-10,
    -10, 15, 10,  8,  8, 10, 15,-10,
    -20,-10,-15,-10,-10,-15,-10,-20,
};

/* King's Battle Phase 1: King must be active and advance FORWARD to hunt
   enemy pawns.  Forward bias is critical — the king must cross the board.
   Row 0 = rank 1 (white start), row 7 = rank 8 (black start).  Black
   uses mirror(), so the forward bias flips correctly. */
static const int PST_KB_KING_P1[64] = {
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
static const int PST_KB_PAWN_P1[64] = {
     0,  0,  0,  0,  0,  0,  0,  0,   /* rank 1 */
     5,  8, 10, 15, 15, 10,  8,  5,   /* rank 2: slight center */
    10, 15, 22, 30, 30, 22, 15, 10,   /* rank 3 */
    15, 22, 35, 45, 45, 35, 22, 15,   /* rank 4: strong center */
    25, 32, 45, 55, 55, 45, 32, 25,   /* rank 5: deep */
    40, 48, 58, 70, 70, 58, 48, 40,   /* rank 6: near promotion */
    65, 72, 80, 90, 90, 80, 72, 65,   /* rank 7: promotion imminent */
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
    bool is_truce_active = (b->mod == MOD_TRUCE && b->truce_active);

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
                /* Save the Queen: prisoner queen limited; escaped queen critical */
                if (t == QUEEN && b->mod == MOD_SAVE_QUEEN) {
                    mat = stq_is_own_half(sq, (Color)c) ? 1100 : 150;
                }
                /* Succession: queens are invaluable (losing one = may lose game) */
                if (b->mod == MOD_SUCCESSION) {
                    if (t == QUEEN) mat = 1300;
                    if (t == PAWN) mat =  160;  /* pawns are path to King promotion */
                    if (t == KING) mat =  700;  /* promoted King: big but not infinite */
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
                } else if (t == PAWN && is_truce_active) {
                    /* Truce pawns: center control + space for post-truce */
                    mg_score[c] += PST_TRUCE_PAWN[idx];
                    eg_score[c] += PST_TRUCE_PAWN[idx];
                } else if (t == KNIGHT && is_truce_active) {
                    /* Truce knights: outpost-focused PST */
                    mg_score[c] += PST_TRUCE_KNIGHT[idx];
                    eg_score[c] += PST_TRUCE_KNIGHT[idx];
                } else if (t == BISHOP && is_truce_active) {
                    /* Truce bishops: diagonal control emphasis */
                    mg_score[c] += PST_TRUCE_BISHOP[idx];
                    eg_score[c] += PST_TRUCE_BISHOP[idx];
                } else if (t == PAWN && b->mod == MOD_KINGS_BATTLE && !b->kb_unlocked) {
                    /* KB Phase 1 pawns: advancement toward promotion */
                    mg_score[c] += PST_KB_PAWN_P1[idx];
                    eg_score[c] += PST_KB_PAWN_P1[idx];
                    /* Extra quadratic advancement bonus: promotion is the key */
                    int rank = (c == WHITE) ? SQ_ROW(sq) : (7 - SQ_ROW(sq));
                    if (rank >= 3) {
                        int adv = (rank - 2) * (rank - 2) * 10;
                        mg_score[c] += adv;
                        eg_score[c] += adv * 2;
                    }
                } else if (t == KING && b->mod == MOD_KINGS_BATTLE && !b->kb_unlocked) {
                    /* KB Phase 1 king: active centralized king */
                    mg_score[c] += PST_KB_KING_P1[idx];
                    eg_score[c] += PST_KB_KING_P1[idx];
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
                   Rooks/queens keep full mobility (they outrange pawns).
                   Truce: mobility is more valuable since pieces can't be
                   traded — a well-placed piece stays strong longer. */
                Bitboard own_occ = b->occupied[c];
                /* Friendly Fire: own capturable pieces don't block mobility */
                if (b->mod == MOD_FRIENDLY_FIRE) {
                    Bitboard ff_cap = own_occ & b->ff_moved & ~b->pieces[c][KING];
                    own_occ &= ~ff_cap;
                }
                Bitboard safe_sq = ~own_occ & ~pawn_atk[c ^ 1];
                /* Truce mobility multiplier: pieces that control more squares
                   exert more pressure once the truce breaks */
                int truce_mob_extra = is_truce_active ? 2 : 0;
                if (t == PAWN && is_merc) {
                    int mob = bb_popcount(king_attacks[sq] & safe_sq);
                    mg_score[c] += mob * 5;
                    eg_score[c] += mob * 5;
                } else if (t == KNIGHT) {
                    int mob = bb_popcount(knight_attacks[sq] & safe_sq);
                    mg_score[c] += mob * (4 + truce_mob_extra);
                    eg_score[c] += mob * (4 + truce_mob_extra);
                } else if (t == BISHOP) {
                    int mob = bb_popcount(bishop_attacks_calc(sq, b->all) & safe_sq);
                    mg_score[c] += mob * (5 + truce_mob_extra);
                    eg_score[c] += mob * (5 + truce_mob_extra);
                } else if (t == ROOK) {
                    int mob = bb_popcount(rook_attacks_calc(sq, b->all) & ~own_occ);
                    mg_score[c] += mob * (2 + truce_mob_extra);
                    eg_score[c] += mob * (3 + truce_mob_extra);
                } else if (t == QUEEN) {
                    Bitboard q_atk = bishop_attacks_calc(sq, b->all)
                                   | rook_attacks_calc(sq, b->all);
                    int mob = bb_popcount(q_atk & ~own_occ);
                    mg_score[c] += mob * (1 + (is_truce_active ? 1 : 0));
                    eg_score[c] += mob * (2 + (is_truce_active ? 1 : 0));
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

    /* ── Friendly Fire strategic evaluation ───────────────────────────────── */
    if (b->mod == MOD_FRIENDLY_FIRE) {
        for (int c = 0; c < 2; c++) {
            int opp = c ^ 1;
            int bonus = 0;

            /* ─ Piece count preservation: losing pieces to self-capture
               means fewer attackers/defenders overall ──────────────── */
            int piece_count = 0;
            for (int t = KNIGHT; t <= QUEEN; t++)
                piece_count += bb_popcount(b->pieces[c][t]);
            bonus += piece_count * 8;

            /* ─ Piece cohesion: defended pieces are safer since they can't
               be cheaply removed by discovered attacks.  Pieces that
               defend each other form resilient structures. ──────────── */
            Bitboard own_def = pawn_atk[c];
            {
                Bitboard kn = b->pieces[c][KNIGHT];
                while (kn) {
                    Square s = (Square)bb_pop_lsb(&kn);
                    own_def |= knight_attacks[s];
                }
                Bitboard bi = b->pieces[c][BISHOP] | b->pieces[c][QUEEN];
                while (bi) {
                    Square s = (Square)bb_pop_lsb(&bi);
                    own_def |= bishop_attacks_calc(s, b->all);
                }
                Bitboard ro = b->pieces[c][ROOK] | b->pieces[c][QUEEN];
                while (ro) {
                    Square s = (Square)bb_pop_lsb(&ro);
                    own_def |= rook_attacks_calc(s, b->all);
                }
            }

            /* Bonus for defended non-pawn pieces */
            for (int t = KNIGHT; t <= QUEEN; t++) {
                Bitboard bb = b->pieces[c][t];
                while (bb) {
                    Square sq = (Square)bb_pop_lsb(&bb);
                    if (BB_HAS(own_def, sq)) bonus += 6;
                }
            }

            /* ─ Open line potential: pieces that could open lines by
               self-capturing blockers get a small positional bonus.
               Rooks/queens on files with own pawns that have moved: the
               pawn could be self-captured to open the file. ─────────── */
            {
                Bitboard rq = b->pieces[c][ROOK] | b->pieces[c][QUEEN];
                while (rq) {
                    Square sq = (Square)bb_pop_lsb(&rq);
                    Bitboard file = (Bitboard)0x0101010101010101ULL << SQ_COL(sq);
                    /* Own pawns on this file that have moved = potential openers */
                    Bitboard blockers = b->pieces[c][PAWN] & file & b->ff_moved;
                    if (blockers) bonus += 5;
                }
            }

            /* ─ King safety emphasis: in FF the king is more vulnerable
               because enemy pieces can also remove defenders via self-capture
               tactics.  Amplify pawn shield value. ──────────────────── */
            {
                Bitboard kbb = b->pieces[c][KING];
                if (kbb) {
                    Square ksq = bb_lsb(kbb);
                    int kc = SQ_COL(ksq);
                    int fwd = (c == WHITE) ? 1 : -1;
                    int shield = 0;
                    for (int dc = -1; dc <= 1; dc++) {
                        int nc = kc + dc, nr = SQ_ROW(ksq) + fwd;
                        if (nc < 0 || nc > 7 || nr < 0 || nr > 7) continue;
                        if (BB_HAS(b->pieces[c][PAWN], SQ(nr, nc))) shield++;
                    }
                    bonus += shield * 8;
                    /* Penalty for king in center */
                    if (kc >= 3 && kc <= 4) bonus -= 10;
                }
            }

            score += (c == WHITE) ? bonus : -bonus;
        }

        /* Tempo bonus */
        score += (b->side == WHITE) ? 10 : -10;
    }

    /* ── Truce-specific strategic evaluation ─────────────────────────────── */
    if (is_truce_active) {
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
    }

    /* ── 2f. King's Battle strategic evaluation ──────────────────────────── */
    if (b->mod == MOD_KINGS_BATTLE) {
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
                        if (dist == 1) capturable++;
                    }
                    /* Strong approach bonus: each step closer is worth ~25cp */
                    if (min_dist < 15) bonus += (7 - min_dist) * 25;
                    bonus += total_prox * 5;

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
                    Bitboard k_moves = king_attacks[ksq] & ~b->occupied[c];
                    Bitboard opp_kbb = b->pieces[opp][KING];
                    if (opp_kbb != BB_EMPTY) {
                        k_moves &= ~king_attacks[bb_lsb(opp_kbb)];
                    }
                    bonus += bb_popcount(k_moves) * 6;
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
                            }
                        } else if (!pawn_defended) {
                            /* Only king-defended: can still be outmaneuvered */
                            bonus += 15;
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
                            static const int KB_PASSED[8] = { 0, 10, 22, 40, 70, 110, 165, 0 };
                            bonus += KB_PASSED[rank];

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
            }

            score += (c == WHITE) ? bonus : -bonus;
        }

        /* Tempo bonus */
        score += (b->side == WHITE) ? 12 : -12;
    }

    /* ── 2g. Save the Queen strategic evaluation ────────────────────── */
    if (b->mod == MOD_SAVE_QUEEN) {
        for (int c = 0; c < 2; c++) {
            Color opp = (Color)(c ^ 1);
            int bonus = 0;

            Bitboard qbb = b->pieces[c][QUEEN];
            if (qbb != BB_EMPTY) {
                Square qsq = (Square)bb_lsb(qbb);
                int qrow = SQ_ROW(qsq);
                int qcol = SQ_COL(qsq);
                bool own_half = stq_is_own_half(qsq, (Color)c);

                if (!own_half) {
                    /* ─ PRISONER: reward approaching the escape boundary ─ */
                    int dist = (c == WHITE) ? (qrow - 3) : (4 - qrow);
                    /* dist 1 = one step from freedom, 4 = starting prison */
                    static const int ESCAPE_BONUS[5] = {0, 450, 250, 120, 30};
                    if (dist >= 1 && dist <= 4) bonus += ESCAPE_BONUS[dist];

                    /* Center files offer more escape routes */
                    int center_dist = qcol > 3 ? (qcol - 3) : (3 - qcol);
                    bonus += (3 - center_dist) * 8;

                    /* Mobility: king-like quiet squares available */
                    Bitboard quiet = king_attacks[qsq] & ~b->all;
                    bonus += bb_popcount(quiet) * 12;

                    /* Clear escape path: forward squares toward boundary */
                    {
                        int fwd[3];
                        if (c == WHITE) { fwd[0] = -8; fwd[1] = -7; fwd[2] = -9; }
                        else            { fwd[0] =  8; fwd[1] =  7; fwd[2] =  9; }
                        int clear = 0;
                        for (int i = 0; i < 3; i++) {
                            int tsq = (int)qsq + fwd[i];
                            if (tsq >= 0 && tsq < 64 &&
                                abs(SQ_COL(tsq) - qcol) <= 1 &&
                                b->mailbox[tsq] == PIECE_EMPTY)
                                clear++;
                        }
                        bonus += clear * 25;
                    }
                } else {
                    /* ─ ESCAPED: reward approaching opponent's prison ─── */
                    bonus += 500;   /* base escape bonus */

                    int prison_row = (c == WHITE) ? 0 : 7;
                    int dr = qrow > prison_row ? (qrow - prison_row)
                                               : (prison_row - qrow);
                    int dc = qcol > 3 ? (qcol - 3) : (3 - qcol);
                    int dist = (dr > dc) ? dr : dc;  /* Chebyshev */

                    static const int WIN_BONUS[] =
                        {1500, 800, 350, 150, 70, 30, 10, 0};
                    if (dist < 8) bonus += WIN_BONUS[dist];

                    /* Central activity within own half */
                    bonus += (3 - dc) * 10;

                    /* Penalty when escaped queen is under attack (mild) */
                    if (board_square_attacked(b, qsq, opp))
                        bonus -= 150;

                    /* King proximity: escaped queen near opponent king */
                    {
                        Bitboard opp_king = b->pieces[opp][KING];
                        if (opp_king) {
                            Square ksq = (Square)bb_lsb(opp_king);
                            int kr = SQ_ROW(ksq), kc = SQ_COL(ksq);
                            int kdr = qrow > kr ? (qrow - kr) : (kr - qrow);
                            int kdc = qcol > kc ? (qcol - kc) : (kc - qcol);
                            int kdist = kdr > kdc ? kdr : kdc;
                            if (kdist <= 3) bonus += (4 - kdist) * 50;
                        }
                    }

                    /* Support: friendly pieces near escaped queen */
                    {
                        Bitboard support = king_attacks[qsq] & b->occupied[c];
                        bonus += bb_popcount(support) * 15;
                    }
                }
            } else {
                /* Queen completely absent — severe handicap */
                bonus -= 400;
            }

            /* Blocking opponent's prisoner from escaping */
            Bitboard opp_q = b->pieces[opp][QUEEN];
            if (opp_q != BB_EMPTY) {
                Square opp_qsq = (Square)bb_lsb(opp_q);
                if (!stq_is_own_half(opp_qsq, opp)) {
                    /* Opponent prisoner: reward having pieces near boundary */
                    int boundary = (opp == WHITE) ? 3 : 4;
                    Bitboard row_mask = (Bitboard)0xFFULL << (boundary * 8);
                    int blockers = bb_popcount(b->occupied[c] & row_mask);
                    bonus += blockers * 30;

                    /* Extra reward for pieces adjacent to the prisoner */
                    Bitboard around = king_attacks[opp_qsq] & b->occupied[c];
                    bonus += bb_popcount(around) * 22;

                    /* Urgency: opponent close to escaping */
                    int opp_dist = (opp == WHITE) ? (SQ_ROW(opp_qsq) - 3)
                                                  : (4 - SQ_ROW(opp_qsq));
                    if (opp_dist == 1) {
                        /* Critical: one step from escape! */
                        bonus += blockers * 35;
                        bonus += bb_popcount(around) * 25;
                    } else if (opp_dist == 2) {
                        bonus += blockers * 15;
                        bonus += bb_popcount(around) * 10;
                    }

                    /* Pawn blockade: pawns on boundary are permanent obstacles */
                    int pawn_blockers = bb_popcount(b->pieces[c][PAWN] & row_mask);
                    bonus += pawn_blockers * 15;
                }
            }

            score += (c == WHITE) ? bonus : -bonus;
        }

        /* Tempo bonus */
        score += (b->side == WHITE) ? 15 : -15;
    }

    /* ── 2h. Succession strategic evaluation ────────────────────────── */
    if (b->mod == MOD_SUCCESSION) {
        for (int c = 0; c < 2; c++) {
            Color opp = (Color)(c ^ 1);
            int bonus = 0;

            /* ── Queen safety: each queen is critical (2 must survive) ── */
            int qcount = bb_popcount(b->pieces[c][QUEEN]);
            /* Reward having both queens */
            bonus += qcount * 250;
            /* Extra penalty for a queen being attacked */
            Bitboard qq = b->pieces[c][QUEEN];
            while (qq) {
                Square qsq = (Square)bb_pop_lsb(&qq);
                if (board_square_attacked(b, qsq, opp))
                    bonus -= 120;
                /* Queens centralized get a mobility bonus */
                int qr = SQ_ROW(qsq), qc_col = SQ_COL(qsq);
                int cr = qr > 3 ? (qr - 3) : (3 - qr);
                int cc = qc_col > 3 ? (qc_col - 3) : (3 - qc_col);
                bonus += (6 - cr - cc) * 4;
            }

            /* ── Pawn advancement: the key strategic goal ─────────────── */
            int pawn_count = bb_popcount(b->pieces[c][PAWN]);
            Bitboard pawns = b->pieces[c][PAWN];
            int promo_row = (c == WHITE) ? 7 : 0;
            int start_row = (c == WHITE) ? 1 : 6;
            int dir_mul = (c == WHITE) ? 1 : -1;
            int best_advance = 0;

            while (pawns) {
                Square psq = (Square)bb_pop_lsb(&pawns);
                int pr = SQ_ROW(psq);
                int advance = (pr - start_row) * dir_mul;
                if (advance > best_advance) best_advance = advance;

                /* Per-pawn advancement reward (escalating) */
                static const int ADV_BONUS[] = {0, 5, 12, 25, 55, 120, 300};
                if (advance >= 0 && advance <= 6) bonus += ADV_BONUS[advance];

                /* Passed pawn detection: no enemy pawns on same or adjacent files ahead */
                {
                    int pc = SQ_COL(psq);
                    bool passed = true;
                    for (int fc = pc - 1; fc <= pc + 1; fc++) {
                        if (fc < 0 || fc > 7) continue;
                        Bitboard file = (Bitboard)0x0101010101010101ULL << fc;
                        Bitboard opp_pawns = b->pieces[opp][PAWN] & file;
                        /* Check only rows ahead */
                        while (opp_pawns) {
                            Square ops = (Square)bb_pop_lsb(&opp_pawns);
                            int opr = SQ_ROW(ops);
                            if (c == WHITE ? (opr > pr) : (opr < pr)) {
                                passed = false;
                                break;
                            }
                        }
                        if (!passed) break;
                    }
                    if (passed) {
                        /* Passed pawn: escalating bonus */
                        static const int PASS_BONUS[] = {0, 10, 20, 40, 80, 160, 400};
                        if (advance >= 0 && advance <= 6)
                            bonus += PASS_BONUS[advance];
                    }
                }
            }

            /* ── Pawn count: losing pawns is dangerous ────────────────── */
            bonus += pawn_count * 15;
            /* Last-pawn vulnerability: if only 1 pawn left, huge urgency */
            if (pawn_count == 1) bonus -= 80;

            /* ── Have a King already? Massive bonus (opponent must capture it to win) */
            if (b->heir_promoted[c]) {
                bonus += 900;
                /* King safety: bonus if supported, penalty if attacked */
                Bitboard kbb = b->pieces[c][KING];
                if (kbb) {
                    Square ksq = (Square)bb_lsb(kbb);
                    if (board_square_attacked(b, ksq, opp))
                        bonus -= 300;
                    /* Friendly pieces nearby protect the king */
                    Bitboard support = king_attacks[ksq] & b->occupied[c];
                    bonus += bb_popcount(support) * 20;
                }
            }

            /* ── Opponent's pawn advancement threat ───────────────── */
            {
                Bitboard op = b->pieces[opp][PAWN];
                int opp_start = (opp == WHITE) ? 1 : 6;
                int opp_dir = (opp == WHITE) ? 1 : -1;
                int opp_best = 0;
                while (op) {
                    Square ops = (Square)bb_pop_lsb(&op);
                    int adv = (SQ_ROW(ops) - opp_start) * opp_dir;
                    if (adv > opp_best) opp_best = adv;
                }
                /* Penalty when opponent has advanced pawns threatening promotion */
                if (opp_best >= 5) bonus -= 100;
                else if (opp_best >= 4) bonus -= 40;
            }

            /* ── Piece activity: minor pieces support pawn advance ──── */
            {
                Bitboard knights = b->pieces[c][KNIGHT];
                Bitboard bishops = b->pieces[c][BISHOP];
                /* Knights on advanced squares (rows 4-6 for White, 1-3 for Black) */
                while (knights) {
                    Square ns = (Square)bb_pop_lsb(&knights);
                    int nr = SQ_ROW(ns);
                    int n_adv = (nr - start_row) * dir_mul;
                    if (n_adv >= 3) bonus += 10;
                }
                /* Bishop pair */
                if (bb_popcount(bishops) >= 2) bonus += 25;
            }

            score += (c == WHITE) ? bonus : -bonus;
        }

        /* Tempo */
        score += (b->side == WHITE) ? 12 : -12;
    }

    /* ── 3. Pawn structure (doubled, isolated) — skip for Mercenary ──── */
    if (!is_merc) {
        /* During truce, pawn structure defects can't be fixed (no captures),
           so penalties are amplified */
        int doubled_pen = is_truce_active ? 22 : 15;
        int isolated_pen = is_truce_active ? 18 : 12;
        for (int col = 0; col < 8; col++) {
            Bitboard file_mask = (Bitboard)0x0101010101010101ULL << col;
            int wp = bb_popcount(b->pieces[WHITE][PAWN] & file_mask);
            int bp = bb_popcount(b->pieces[BLACK][PAWN] & file_mask);

            if (wp > 1) score -= (wp - 1) * doubled_pen;
            if (bp > 1) score += (bp - 1) * doubled_pen;

            /* Isolated: no own pawns on adjacent files */
            Bitboard adj = BB_EMPTY;
            if (col > 0) adj |= (Bitboard)0x0101010101010101ULL << (col - 1);
            if (col < 7) adj |= (Bitboard)0x0101010101010101ULL << (col + 1);
            if (wp > 0 && !(b->pieces[WHITE][PAWN] & adj)) score -= isolated_pen;
            if (bp > 0 && !(b->pieces[BLACK][PAWN] & adj)) score += isolated_pen;
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
