/*
 * search.c — Stockfish-inspired alpha-beta search engine
 *
 * Key features (inspired by Stockfish):
 *  - Static Exchange Evaluation (SEE) for capture quality assessment
 *  - Staged move ordering: TT > good captures > killers > countermoves > quiets > bad captures
 *  - Aspiration windows at root for faster convergence
 *  - Null-move pruning with adaptive reduction
 *  - Late Move Reductions (LMR) with improving flag
 *  - Late Move Pruning (LMP)
 *  - Razoring at shallow depths
 *  - Reverse futility pruning (static null-move)
 *  - Futility pruning for quiet moves
 *  - Check extensions
 *  - Countermove heuristic
 *  - History heuristic with gravity
 *  - Depth-only difficulty levels (no random noise that causes blunders)
 */

#include "search.h"
#include "movegen.h"
#include "evaluate.h"
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <stdio.h>

#ifdef __ANDROID__
#include <android/log.h>
#define LOGD(...) __android_log_print(ANDROID_LOG_DEBUG, "CHESS_ENGINE", __VA_ARGS__)
#else
#define LOGD(...) do { fprintf(stderr, __VA_ARGS__); fflush(stderr); } while(0)
#endif

#ifdef _WIN32
  #include <windows.h>
  static int64_t time_ms_now(void) {
      return (int64_t)GetTickCount64();
  }
#else
  static int64_t time_ms_now(void) {
      struct timespec ts;
      clock_gettime(CLOCK_MONOTONIC, &ts);
      return (int64_t)ts.tv_sec * 1000 + ts.tv_nsec / 1000000;
  }
#endif

/* ======================================================================== */
/*  Constants                                                               */
/* ======================================================================== */

#define INFINITY_SCORE  999999
#define MATE_SCORE      100000
#define MAX_PLY         64
#define MAX_QPLY        8
#define MAX_NODES       20000000

static inline int maxi(int a, int b) { return a > b ? a : b; }
static inline int mini(int a, int b) { return a < b ? a : b; }
static inline int chebyshev_distance_sq(int a, int b) {
    int dr = abs(SQ_ROW(a) - SQ_ROW(b));
    int dc = abs(SQ_COL(a) - SQ_COL(b));
    return dr > dc ? dr : dc;
}
static inline bool is_mate(int s) {
    return s > MATE_SCORE - 500 || s < -MATE_SCORE + 500;
}

static bool kb_phase1_any_pawn_capture_available(const Board *b, Color side);

static const char *sq_name(Square sq) {
    static char buf[4][4];
    static int idx = 0;
    idx = (idx + 1) & 3;
    buf[idx][0] = 'a' + SQ_COL(sq);
    buf[idx][1] = '1' + SQ_ROW(sq);
    buf[idx][2] = '\0';
    return buf[idx];
}
static const char *pt_char = "PNBRQKx";

/* Piece values for SEE (index by PieceType enum) */
static const int SEE_PIECE_VAL[7] = { 100, 320, 330, 500, 900, 20000, 0 };

/* ======================================================================== */
/*  PRNG (xorshift64) — minimal opening variety only                        */
/* ======================================================================== */

static uint64_t s_rng;

static uint64_t rng_next(void) {
    s_rng ^= s_rng << 13;
    s_rng ^= s_rng >> 7;
    s_rng ^= s_rng << 17;
    return s_rng;
}

static int rng_range(int max) {
    if (max <= 1) return 0;
    return (int)(rng_next() % (uint64_t)max);
}

/* ======================================================================== */
/*  Transposition Table                                                     */
/* ======================================================================== */

void tt_alloc(TTable *tt, int size_mb) {
    tt->count = (size_mb * 1024 * 1024) / (int)sizeof(TTEntry);
    int n = 1;
    while (n * 2 <= tt->count) n *= 2;
    tt->count = n;
    tt->mask  = n - 1;
    tt->entries = (TTEntry *)calloc(n, sizeof(TTEntry));
}

void tt_free(TTable *tt) {
    free(tt->entries);
    tt->entries = NULL;
    tt->count = 0;
}

void tt_clear(TTable *tt) {
    if (tt->entries)
        memset(tt->entries, 0, tt->count * sizeof(TTEntry));
}

static TTEntry *tt_probe(const TTable *tt, uint64_t key) {
    TTEntry *e = &tt->entries[key & tt->mask];
    if (e->key == key) return e;
    return NULL;
}

static void tt_store(TTable *tt, uint64_t key, int depth, int score,
                     TTFlag flag, Move best) {
    TTEntry *e = &tt->entries[key & tt->mask];
    /* Depth-preferred replacement: replace if deeper search, same position,
       or the old entry had no useful best-move */
    if (e->key == key || depth >= e->depth || e->best_move == MOVE_NONE) {
        e->key       = key;
        e->depth     = depth;
        e->score     = score;
        e->flag      = flag;
        e->best_move = best;
    }
}

/* ======================================================================== */
/*  Static Exchange Evaluation (SEE)                                        */
/*                                                                          */
/*  Determines the material gain/loss from a series of captures on one      */
/*  square.  Inspired by Stockfish's SEE.  Critical for:                    */
/*    1) Move ordering: good captures (SEE >= 0) before bad (SEE < 0)       */
/*    2) Quiescence pruning: skip obviously losing captures                 */
/*    3) Search pruning decisions                                           */
/* ======================================================================== */

/* Get bitboard of ALL pieces attacking 'sq' through 'occ' */
static Bitboard attackers_to(const Board *b, Square sq, Bitboard occ) {
    Bitboard att = BB_EMPTY;

    att |= knight_attacks[sq] &
           (b->pieces[WHITE][KNIGHT] | b->pieces[BLACK][KNIGHT]);

    att |= king_attacks[sq] &
           (b->pieces[WHITE][KING] | b->pieces[BLACK][KING]);

    Bitboard diag = bishop_attacks_calc(sq, occ);
    att |= diag & (b->pieces[WHITE][BISHOP] | b->pieces[BLACK][BISHOP] |
                   b->pieces[WHITE][QUEEN]  | b->pieces[BLACK][QUEEN]);

    Bitboard orth = rook_attacks_calc(sq, occ);
    att |= orth & (b->pieces[WHITE][ROOK] | b->pieces[BLACK][ROOK] |
                   b->pieces[WHITE][QUEEN] | b->pieces[BLACK][QUEEN]);

    if (b->mod == MOD_MERCENARY) {
        att |= king_attacks[sq] &
               (b->pieces[WHITE][PAWN] | b->pieces[BLACK][PAWN]);
    } else {
        att |= pawn_attacks[BLACK][sq] & b->pieces[WHITE][PAWN];
        att |= pawn_attacks[WHITE][sq] & b->pieces[BLACK][PAWN];
    }

    return att & occ;
}

/* Get SEE piece value, accounting for variant piece values */
static inline int see_pv(PieceType pt, bool is_merc, bool is_heir, bool is_stq, bool is_succ) {
    if (pt == PAWN && is_merc) return 180;
    if (pt == PAWN && is_heir) return 140;
    if (pt == KING && is_heir) return 250; /* expendable king material */
    if (pt == QUEEN && is_stq)  return 1200; /* escaped queen capture is decisive */
    if (pt == QUEEN && is_succ) return 1300; /* losing a queen is near-fatal */
    if (pt == PAWN  && is_succ) return 160;  /* pawns = promotion path */
    if (pt == KING  && is_succ) return 700;  /* promoted king */
    return SEE_PIECE_VAL[pt];
}

static inline int heir_pawn_advance(Color side, Square sq) {
    int advance = (side == WHITE) ? (SQ_ROW(sq) - 1) : (6 - SQ_ROW(sq));
    if (advance < 0) return 0;
    if (advance > 5) return 5;
    return advance;
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

static int heir_f_pawn_block_move_penalty(const Board *b, Move m) {
    if (b->mod != MOD_HEIR || MOVE_PIECE(m) != KNIGHT) return 0;

    Color side = b->side;
    Square from = MOVE_FROM(m);
    Square to = MOVE_TO(m);
    Square home_from = (side == WHITE) ? SQ(0, 6) : SQ(7, 6);
    Square block_sq = (side == WHITE) ? SQ(2, 5) : SQ(5, 5);
    Square home_f = (side == WHITE) ? SQ(1, 5) : SQ(6, 5);
    Square spear_sq = (side == WHITE) ? SQ(4, 4) : SQ(3, 4);
    Square anchor_sq = (side == WHITE) ? SQ(3, 3) : SQ(4, 3);

    if (b->fullmove > 12) return 0;
    if (from != home_from || to != block_sq) return 0;
    if (!BB_HAS(b->pieces[side][PAWN], home_f)) return 0;
    if (!BB_HAS(b->pieces[side][PAWN], spear_sq)) return 0;

    int penalty = 70;
    if (BB_HAS(b->pieces[side][PAWN], anchor_sq)) penalty += 30;
    return penalty;
}

static bool heir_position_volatile(const Board *b) {
    for (int c = 0; c < 2; c++) {
        if (b->pieces[c][KING] == BB_EMPTY) return true;
        if (bb_popcount(b->pieces[c][PAWN]) <= 2) return true;

        Bitboard pawns = b->pieces[c][PAWN];
        while (pawns) {
            Square sq = (Square)bb_pop_lsb(&pawns);
            if (heir_pawn_advance((Color)c, sq) >= 4) return true;
        }
    }

    return false;
}

static bool heir_critical_move(const Board *b, Move m) {
    if (b->mod != MOD_HEIR) return false;
    if (MOVE_IS_PROMO(m) || MOVE_CAPTURED(m) == KING) return true;
    if (MOVE_PIECE(m) == KING) return true;

    if (MOVE_PIECE(m) == PAWN) {
        if (heir_pawn_advance(b->side, MOVE_TO(m)) >= 4) return true;
    }

    return false;
}

static bool heir_king_under_direct_fire(const Board *b) {
    if (b->mod != MOD_HEIR) return false;
    if (b->pieces[b->side][KING] == BB_EMPTY) return false;
    return board_square_attacked(b, bb_lsb(b->pieces[b->side][KING]),
                                 color_opposite(b->side));
}

static bool heir_tactical_capture(const Board *b, Move m, int see) {
    if (b->mod != MOD_HEIR) return false;
    if (!(MOVE_IS_CAPTURE(m) || MOVE_IS_EP(m))) return false;
    if (see < 0) return false;

    PieceType captured = MOVE_CAPTURED(m);
    Square to = MOVE_TO(m);
    bool central = SQ_ROW(to) >= 2 && SQ_ROW(to) <= 5 &&
                   SQ_COL(to) >= 2 && SQ_COL(to) <= 5;

    if (captured >= KNIGHT) return true;
    if (captured == PAWN && central) return true;
    return false;
}

static int heir_early_queen_sortie_penalty(const Board *b, Move m) {
    if (b->mod != MOD_HEIR || MOVE_PIECE(m) != QUEEN) return 0;

    Color side = b->side;
    Color opp = color_opposite(side);
    int back_rank = (side == WHITE) ? 0 : 7;
    int minor_total = bb_popcount(b->pieces[side][KNIGHT] | b->pieces[side][BISHOP]);
    int minor_developed = heir_developed_minor_count(b, side);
    int undeveloped = minor_total - minor_developed;

    if (b->fullmove > 12) return 0;
    if (SQ_ROW(MOVE_FROM(m)) != back_rank || SQ_ROW(MOVE_TO(m)) == back_rank) return 0;
    if (bb_popcount(b->pieces[side][PAWN]) < 4 || bb_popcount(b->pieces[opp][PAWN]) < 4) return 0;
    if (undeveloped <= 0) return 0;

    int penalty = 120 + undeveloped * 30;
    if (minor_developed == 0) penalty += 40;
    else if (minor_developed == 1) penalty += 20;
    return penalty;
}

/*
 * Compute SEE for capture move m.
 * Returns expected material gain (positive = winning exchange).
 *
 * Algorithm: simulate captures on target square using the least
 * valuable attacker each time.  Then negamax the gain array.
 */
static int see_value(const Board *b, Move m) {
    if (!MOVE_IS_CAPTURE(m) && !MOVE_IS_EP(m)) return 0;

    Square from = MOVE_FROM(m);
    Square to   = MOVE_TO(m);
    bool is_merc = (b->mod == MOD_MERCENARY);
    bool is_heir = (b->mod == MOD_HEIR);
    bool is_stq  = (b->mod == MOD_SAVE_QUEEN);
    bool is_succ = (b->mod == MOD_SUCCESSION);

    int gain[32];
    int d = 0;

    /* Initial gain: value of captured piece */
    gain[0] = see_pv(MOVE_CAPTURED(m), is_merc, is_heir, is_stq, is_succ);

    /* Friendly Fire: capturing own piece is a material loss, not gain */
    if (b->mod == MOD_FRIENDLY_FIRE && !MOVE_IS_EP(m) &&
        PIECE_COLOR(b->mailbox[from]) == PIECE_COLOR(b->mailbox[to])) {
        gain[0] = -gain[0];
    }

    /* The moving piece becomes the target */
    PieceType next_victim = MOVE_PIECE(m);

    if (MOVE_IS_PROMO(m)) {
        gain[0] += see_pv(MOVE_PROMO_TYPE(m), is_merc, is_heir, is_stq, is_succ)
                 - see_pv(PAWN, is_merc, is_heir, is_stq, is_succ);
        next_victim = MOVE_PROMO_TYPE(m);
    }

    Bitboard occ = b->all ^ BB_SQ(from);

    if (MOVE_IS_EP(m)) {
        Square ep_cap = SQ(SQ_ROW(from), SQ_COL(to));
        occ ^= BB_SQ(ep_cap);
    }

    Bitboard all_atk = attackers_to(b, to, occ);
    Color stm = color_opposite(PIECE_COLOR(b->mailbox[from]));

    while (d < 31) {
        d++;
        gain[d] = see_pv(next_victim, is_merc, is_heir, is_stq, is_succ) - gain[d - 1];

        /* If best case for both sides is negative, stop */
        if (maxi(-gain[d - 1], gain[d]) < 0) break;

        /* Find least valuable attacker for stm */
        Bitboard stm_atk = all_atk & b->occupied[stm] & occ;
        if (!stm_atk) break;

        PieceType pt = PIECE_NONE;
        Bitboard pt_bb = BB_EMPTY;
        for (PieceType p = PAWN; p <= KING; p++) {
            Bitboard overlap = stm_atk & b->pieces[stm][p];
            if (overlap) {
                pt = p;
                pt_bb = overlap & (~overlap + 1);
                break;
            }
        }
        if (pt == PIECE_NONE) break;

        /* King can't recapture if opponent still has attackers */
        if (pt == KING) {
            if (all_atk & b->occupied[color_opposite(stm)] & occ) break;
        }

        next_victim = pt;
        occ ^= pt_bb;

        /* Reveal x-ray attackers behind removed piece */
        if (pt == PAWN || pt == BISHOP || pt == QUEEN) {
            all_atk |= bishop_attacks_calc(to, occ) &
                (b->pieces[WHITE][BISHOP] | b->pieces[BLACK][BISHOP] |
                 b->pieces[WHITE][QUEEN]  | b->pieces[BLACK][QUEEN]);
        }
        if (pt == ROOK || pt == QUEEN) {
            all_atk |= rook_attacks_calc(to, occ) &
                (b->pieces[WHITE][ROOK] | b->pieces[BLACK][ROOK] |
                 b->pieces[WHITE][QUEEN] | b->pieces[BLACK][QUEEN]);
        }

        all_atk &= occ;
        stm = color_opposite(stm);
    }

    /* Negamax: gain[d-1] = -max(-gain[d-1], gain[d]) */
    while (--d > 0) {
        gain[d - 1] = -maxi(-gain[d - 1], gain[d]);
    }

    return gain[0];
}

/* ======================================================================== */
/*  Move ordering (Stockfish-style priority)                                */
/*                                                                          */
/*  1. TT move                    (10,000,000)                              */
/*  2. Queen promotions           ( 8,000,000)                              */
/*  3. Good captures (SEE >= 0)   ( 5,000,000 + MVV-LVA)                   */
/*  4. Killer moves               (   900,000)                              */
/*  5. Countermove                 (   800,000)                              */
/*  6. Quiet moves (history)      (   -16384 .. 16384)                      */
/*  7. Under-promotions           (  -500,000)                              */
/*  8. Bad captures (SEE < 0)     (-1,000,000 + SEE)                        */
/* ======================================================================== */

static const int MVV_LVA[6][6] = {
    /*        P     N     B     R     Q     K   <- victim  */
    /* P */ { 105,  205,  305,  405,  505,  605 },
    /* N */ { 104,  204,  304,  404,  504,  604 },
    /* B */ { 103,  203,  303,  403,  503,  603 },
    /* R */ { 102,  202,  302,  402,  502,  602 },
    /* Q */ { 101,  201,  301,  401,  501,  601 },
    /* K */ { 100,  200,  300,  400,  500,  600 },
};

static Move s_killers[MAX_PLY][2];
static int  s_history[2][64][64];
static Move s_countermoves[2][6][64];

static void record_killer(Move m, int ply) {
    if (ply >= MAX_PLY) return;
    if (m != s_killers[ply][0]) {
        s_killers[ply][1] = s_killers[ply][0];
        s_killers[ply][0] = m;
    }
}

/* Stockfish-style gravity: score approaches +/-16384 asymptotically */
static void update_history(Color side, Move m, int bonus) {
    int *entry = &s_history[side][MOVE_FROM(m)][MOVE_TO(m)];
    *entry += bonus - (*entry) * abs(bonus) / 16384;
}

static void record_history(Color side, Move m, int depth) {
    update_history(side, m, depth * depth);
}

static void penalize_quiets(Color side, Move *quiets, int count, int depth) {
    int pen = -(depth * depth);
    for (int i = 0; i < count; i++) {
        update_history(side, quiets[i], pen);
    }
}

static int truce_undeveloped_minor_count(const Board *b, Color side) {
    if (b->mod != MOD_TRUCE || !b->truce_active) return 0;

    int back_rank = (side == WHITE) ? 0 : 7;
    int undeveloped = 0;
    Bitboard minors = b->pieces[side][KNIGHT] | b->pieces[side][BISHOP];

    while (minors) {
        Square sq = (Square)bb_pop_lsb(&minors);
        if (SQ_ROW(sq) == back_rank) undeveloped++;
    }

    return undeveloped;
}

static int truce_minor_development_score(const Board *b, Move m, Color side) {
    if (b->mod != MOD_TRUCE || !b->truce_active || MOVE_IS_CAPTURE(m) ||
        MOVE_IS_EP(m) || MOVE_IS_PROMO(m)) {
        return 0;
    }

    PieceType piece = MOVE_PIECE(m);
    if (piece != KNIGHT && piece != BISHOP) return 0;

    int back_rank = (side == WHITE) ? 0 : 7;
    Square from_sq = MOVE_FROM(m);
    Square to_sq = MOVE_TO(m);
    int to_rank = (side == WHITE) ? SQ_ROW(to_sq) : (7 - SQ_ROW(to_sq));
    int undeveloped = truce_undeveloped_minor_count(b, side);
    int score = 0;

    if (SQ_ROW(from_sq) != back_rank || SQ_ROW(to_sq) == back_rank) return 0;

    score += (piece == KNIGHT) ? 54 : 38;
    if (undeveloped >= 2) score += 14;
    if (undeveloped >= 3) score += 8;
    if (SQ_COL(to_sq) >= 2 && SQ_COL(to_sq) <= 5) score += 8;
    if (to_rank >= 2) score += 4;

    if (piece == BISHOP) {
        if (to_rank >= 2) score += 16;
        else score -= 20;
    }

    return score;
}

static int truce_early_queen_sortie_penalty(const Board *b, Move m, Color side) {
    if (b->mod != MOD_TRUCE || !b->truce_active || MOVE_PIECE(m) != QUEEN ||
        MOVE_IS_CAPTURE(m) || MOVE_IS_EP(m) || MOVE_IS_PROMO(m)) {
        return 0;
    }

    int back_rank = (side == WHITE) ? 0 : 7;
    int undeveloped = truce_undeveloped_minor_count(b, side);

    if (b->fullmove > 8) return 0;
    if (SQ_ROW(MOVE_FROM(m)) != back_rank || SQ_ROW(MOVE_TO(m)) == back_rank) return 0;
    if (undeveloped <= 1) return 0;

    return 90 + undeveloped * 22;
}

static int truce_quiet_pawn_score(const Board *b, Move m, Color side) {
    if (b->mod != MOD_TRUCE || !b->truce_active || MOVE_PIECE(m) != PAWN ||
        MOVE_IS_CAPTURE(m) || MOVE_IS_EP(m) || MOVE_IS_PROMO(m)) {
        return 0;
    }

    Square from_sq = MOVE_FROM(m);
    Square to_sq = MOVE_TO(m);
    int from_rank = (side == WHITE) ? SQ_ROW(from_sq) : (7 - SQ_ROW(from_sq));
    int to_rank = (side == WHITE) ? SQ_ROW(to_sq) : (7 - SQ_ROW(to_sq));
    int file = SQ_COL(to_sq);
    int score = 0;
    int attack_row = SQ_ROW(to_sq) + ((side == WHITE) ? 1 : -1);

    if (from_rank != 1) return 0;

    score += 28;
    score += (to_rank >= 3) ? 18 : 8;
    if (file >= 2 && file <= 5) score += 12;

    if (attack_row >= 0 && attack_row < 8) {
        if (file > 0 && BB_HAS(b->pieces[side ^ 1][BISHOP], SQ(attack_row, file - 1)))
            score += 36;
        if (file < 7 && BB_HAS(b->pieces[side ^ 1][BISHOP], SQ(attack_row, file + 1)))
            score += 36;
    }

    return score;
}

static int kb_phase1_forward_rank(Color side, Square sq) {
    return (side == WHITE) ? SQ_ROW(sq) : (7 - SQ_ROW(sq));
}

static int kb_phase1_promotion_distance(Color side, Square sq) {
    return 7 - kb_phase1_forward_rank(side, sq);
}

static int kb_phase1_min_enemy_pawn_distance(const Board *b, Color side, Square sq) {
    Color opp = color_opposite(side);
    Bitboard pawns = b->pieces[opp][PAWN];
    int min_dist = 15;

    while (pawns) {
        Square ps = (Square)bb_pop_lsb(&pawns);
        int dr = abs(SQ_ROW(ps) - SQ_ROW(sq));
        int dc = abs(SQ_COL(ps) - SQ_COL(sq));
        int dist = dr > dc ? dr : dc;
        if (dist < min_dist) min_dist = dist;
    }

    return min_dist == 15 ? 0 : min_dist;
}

static int kb_phase1_enemy_king_distance(const Board *b, Color side, Square sq) {
    Bitboard opp_king = b->pieces[color_opposite(side)][KING];
    if (opp_king == BB_EMPTY) return 8;
    return chebyshev_distance_sq(sq, bb_lsb(opp_king));
}

static int kb_phase1_pawn_king_pressure(const Board *b, Color side, Square sq) {
    Bitboard opp_king = b->pieces[color_opposite(side)][KING];
    if (opp_king == BB_EMPTY) return 0;

    Square king_sq = bb_lsb(opp_king);
    int score = 0;
    int attack_row = SQ_ROW(sq) + ((side == WHITE) ? 1 : -1);
    int dist = chebyshev_distance_sq(sq, king_sq);

    if (attack_row >= 0 && attack_row < 8 && SQ_ROW(king_sq) == attack_row &&
        abs(SQ_COL(king_sq) - SQ_COL(sq)) == 1) {
        score += 120;
    }

    if (dist <= 1) score += 35;
    else if (dist == 2) score += 18;

    return score;
}

static bool kb_phase1_forward_lane_open(const Board *b, Color side, Square sq) {
    int forward_row = SQ_ROW(sq) + ((side == WHITE) ? 1 : -1);
    int col = SQ_COL(sq);

    if (forward_row < 0 || forward_row > 7) return false;
    return !BB_HAS(b->occupied[side], SQ(forward_row, col));
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

static bool kb_phase1_passed_destination(const Board *b, Color side, Square sq);

static int kb_phase1_retreat_arc_move_score(const Board *b, Color side, Square sq) {
    Color opp = color_opposite(side);
    Bitboard opp_king = b->pieces[opp][KING];
    if (opp_king == BB_EMPTY) return 0;

    Square king_sq = bb_lsb(opp_king);
    int opp_rank = kb_phase1_forward_rank(opp, king_sq);
    int retreat_row = SQ_ROW(king_sq) + ((opp == WHITE) ? -1 : 1);
    int attack_row = SQ_ROW(sq) + ((side == WHITE) ? 1 : -1);
    int sealed = 0;
    int newly_attacked = 0;

    if (opp_rank < 3) return 0;
    if (retreat_row < 0 || retreat_row > 7) return 0;

    for (int dc = -1; dc <= 1; dc++) {
        int nc = SQ_COL(king_sq) + dc;
        if (nc < 0 || nc > 7) continue;

        Square rsq = SQ(retreat_row, nc);
        bool attacks = false;
        if (attack_row == retreat_row && abs(SQ_COL(sq) - nc) == 1) {
            attacks = true;
            newly_attacked++;
        }

        if (attacks || b->mailbox[rsq] != PIECE_EMPTY) {
            sealed++;
        }
    }

    if (newly_attacked == 0) return 0;

    if (sealed == 3) return 280 + newly_attacked * 24;
    if (sealed == 2) return 120 + newly_attacked * 18;
    return newly_attacked * 28;
}

static int kb_phase1_wing_drift_move_penalty(const Board *b, Color side, Move m) {
    Square from_sq = MOVE_FROM(m);
    Square to_sq = MOVE_TO(m);
    int file = SQ_COL(to_sq);
    int from_rank = kb_phase1_forward_rank(side, from_sq);
    int to_rank = kb_phase1_forward_rank(side, to_sq);
    int penalty;

    if (file != 0 && file != 1 && file != 6 && file != 7) return 0;
    if (from_rank != 1 || to_rank < 2 || to_rank > 3) return 0;
    if (kb_phase1_passed_destination(b, side, to_sq)) return 0;
    if (kb_phase1_pawn_king_pressure(b, side, to_sq) >= 70) return 0;

    if (b->pieces[side][KING] != BB_EMPTY) {
        Square king_sq = bb_lsb(b->pieces[side][KING]);
        if (chebyshev_distance_sq(king_sq, to_sq) <= 2) return 0;
    }

    if (b->pieces[color_opposite(side)][KING] != BB_EMPTY) {
        Square enemy_king_sq = bb_lsb(b->pieces[color_opposite(side)][KING]);
        if (chebyshev_distance_sq(enemy_king_sq, to_sq) <= 2) return 0;
    }

    penalty = (to_rank == 2) ? 100 : 170;
    if (kb_phase1_any_pawn_capture_available(b, side)) penalty += 30;
    return penalty;
}

static int kb_phase1_connected_wall_move_score(const Board *b, Color side, Square sq) {
    Color opp = color_opposite(side);
    Bitboard opp_king = b->pieces[opp][KING];
    int row = SQ_ROW(sq);
    int col = SQ_COL(sq);
    int rank = kb_phase1_forward_rank(side, sq);

    if (opp_king == BB_EMPTY) return 0;
    if (rank < 3) return 0;

    {
        Square king_sq = bb_lsb(opp_king);
        int opp_rank = kb_phase1_forward_rank(opp, king_sq);
        int pair_dist = 8;
        bool has_pair = false;

        if (opp_rank < 4) return 0;

        if (col > 0 && BB_HAS(b->pieces[side][PAWN], SQ(row, col - 1))) {
            int left_dist = chebyshev_distance_sq(SQ(row, col - 1), king_sq);
            int self_dist = chebyshev_distance_sq(sq, king_sq);
            pair_dist = (left_dist < self_dist) ? left_dist : self_dist;
            has_pair = true;
        }
        if (col < 7 && BB_HAS(b->pieces[side][PAWN], SQ(row, col + 1))) {
            int right_dist = chebyshev_distance_sq(SQ(row, col + 1), king_sq);
            int self_dist = chebyshev_distance_sq(sq, king_sq);
            int this_pair = (right_dist < self_dist) ? right_dist : self_dist;
            if (!has_pair || this_pair < pair_dist) pair_dist = this_pair;
            has_pair = true;
        }

        if (!has_pair) return 0;
        if (pair_dist <= 2) return 760;
        if (pair_dist == 3) return 280;
    }

    return 0;
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

static bool kb_phase1_has_secondary_pawn_capture(const Board *b, Color side,
                                                 Move m) {
    if (!(MOVE_PIECE(m) == PAWN && MOVE_IS_CAPTURE(m) && MOVE_CAPTURED(m) == PAWN)) {
        return false;
    }

    Square from_sq = MOVE_FROM(m);
    Square to_sq = MOVE_TO(m);
    int target_row = SQ_ROW(to_sq) - ((side == WHITE) ? 1 : -1);

    if (target_row < 0 || target_row > 7) return false;

    if (SQ_COL(to_sq) > 0) {
        Square alt = SQ(target_row, SQ_COL(to_sq) - 1);
        if (alt != from_sq && BB_HAS(b->pieces[side][PAWN], alt)) return true;
    }
    if (SQ_COL(to_sq) < 7) {
        Square alt = SQ(target_row, SQ_COL(to_sq) + 1);
        if (alt != from_sq && BB_HAS(b->pieces[side][PAWN], alt)) return true;
    }

    return false;
}

static int kb_unlocked_development_score(const Board *b, Move m, Color side) {
    if (b->mod != MOD_KINGS_BATTLE || !b->kb_unlocked || MOVE_IS_CAPTURE(m) ||
        MOVE_IS_EP(m) || MOVE_IS_PROMO(m)) {
        return 0;
    }

    PieceType piece = MOVE_PIECE(m);
    if (piece != KNIGHT && piece != BISHOP) return 0;

    Square from_sq = MOVE_FROM(m);
    Square to_sq = MOVE_TO(m);
    int back_rank = (side == WHITE) ? 0 : 7;
    int to_rank = (side == WHITE) ? SQ_ROW(to_sq) : (7 - SQ_ROW(to_sq));
    int score = 0;

    if (SQ_ROW(from_sq) != back_rank || SQ_ROW(to_sq) == back_rank) return 0;

    score += (piece == KNIGHT) ? 58 : 52;
    if (SQ_COL(to_sq) >= 2 && SQ_COL(to_sq) <= 5) score += 10;
    if (to_rank >= 2) score += 8;
    return score;
}

static int kb_unlocked_king_shelter_score(const Board *b, Move m, Color side) {
    if (b->mod != MOD_KINGS_BATTLE || !b->kb_unlocked || MOVE_PIECE(m) != PAWN ||
        MOVE_IS_CAPTURE(m) || MOVE_IS_EP(m) || MOVE_IS_PROMO(m)) {
        return 0;
    }

    Bitboard king_bb = b->pieces[side][KING];
    Bitboard queen_bb = b->pieces[color_opposite(side)][QUEEN];
    if (king_bb == BB_EMPTY || queen_bb == BB_EMPTY) return 0;

    Square king_sq = bb_lsb(king_bb);
    Square from_sq = MOVE_FROM(m);
    Square to_sq = MOVE_TO(m);
    Square queen_sq = bb_lsb(queen_bb);
    int from_dist = chebyshev_distance_sq(from_sq, king_sq);
    int to_dist = chebyshev_distance_sq(to_sq, king_sq);
    int queen_dist = chebyshev_distance_sq(queen_sq, king_sq);
    int score = 0;

    if (queen_dist > 4 && from_dist > 2 && to_dist > 1) return 0;

    if (to_dist <= 1) score += 120;
    else if (to_dist == 2 && from_dist > 2) score += 50;
    if (from_dist <= 1) score += 35;

    if (queen_dist <= 2) score += 60;
    else if (queen_dist <= 4) score += 30;

    {
        Bitboard queen_ray = bishop_attacks_calc(queen_sq, b->all) |
                             rook_attacks_calc(queen_sq, b->all);
        if (BB_HAS(queen_ray, king_sq)) score += 70;
    }

    if (abs(SQ_COL(to_sq) - SQ_COL(king_sq)) <= 1) score += 18;
    if ((side == WHITE && SQ_ROW(to_sq) <= SQ_ROW(king_sq)) ||
        (side == BLACK && SQ_ROW(to_sq) >= SQ_ROW(king_sq))) {
        score += 12;
    }

    return score;
}

static bool kb_phase1_passed_destination(const Board *b, Color side, Square sq) {
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

static int kb_phase1_king_activation_score(const Board *b, Move m, Color side) {
    if (b->mod != MOD_KINGS_BATTLE || b->kb_unlocked || MOVE_PIECE(m) != KING ||
        MOVE_IS_PROMO(m) || MOVE_IS_EP(m)) {
        return 0;
    }

    Square from_sq = MOVE_FROM(m);
    Square to_sq = MOVE_TO(m);
    int from_rank = kb_phase1_forward_rank(side, from_sq);
    int to_rank = kb_phase1_forward_rank(side, to_sq);
    int from_dist = kb_phase1_min_enemy_pawn_distance(b, side, from_sq);
    int to_dist = kb_phase1_min_enemy_pawn_distance(b, side, to_sq);
    int enemy_king_rank = -1;
    int score = 0;

    if (b->pieces[color_opposite(side)][KING] != BB_EMPTY) {
        enemy_king_rank = kb_phase1_forward_rank(
            color_opposite(side),
            bb_lsb(b->pieces[color_opposite(side)][KING])
        );
    }
    if (to_rank > from_rank) score += (to_rank - from_rank) * 140;
    if (to_rank < from_rank) score -= (from_rank - to_rank) * 170;
    if (from_rank == 0 && to_rank > 0) score += 120;
    if (SQ_COL(to_sq) >= 2 && SQ_COL(to_sq) <= 5) score += 40;
    if (to_dist > 0 && from_dist > 0 && to_dist < from_dist) {
        score += (from_dist - to_dist) * 60;
    } else if (to_dist > 0 && from_dist > 0 && to_dist > from_dist) {
        score -= (to_dist - from_dist) * 80;
    }

    if (enemy_king_rank >= 0) {
        if (to_rank + 1 < enemy_king_rank) {
            score -= (enemy_king_rank - to_rank - 1) * 44;
        } else if (to_rank > enemy_king_rank) {
            score += (to_rank - enemy_king_rank) * 18;
        }
    }

    {
        Bitboard opp_pawns = b->pieces[color_opposite(side)][PAWN];
        int capturable = 0;
        while (opp_pawns) {
            Square ps = (Square)bb_pop_lsb(&opp_pawns);
            if (chebyshev_distance_sq(ps, to_sq) == 1) capturable++;
        }
        score += capturable * 80;
    }

    {
        bool from_forward_open = kb_phase1_forward_lane_open(b, side, from_sq);
        bool to_forward_open = kb_phase1_forward_lane_open(b, side, to_sq);
        int from_clear = kb_phase1_forward_file_clearance(b, side, from_sq, 2);
        int to_clear = kb_phase1_forward_file_clearance(b, side, to_sq, 2);
        int from_blockers = kb_phase1_forward_corridor_blockers(b, side, from_sq, 2);
        int to_blockers = kb_phase1_forward_corridor_blockers(b, side, to_sq, 2);
        if (to_forward_open && !from_forward_open) {
            score += 45;
        } else if (!to_forward_open && from_forward_open) {
            score -= 35;
        }
        if (to_clear > from_clear) score += (to_clear - from_clear) * 40;
        else if (to_clear < from_clear) score -= (from_clear - to_clear) * 30;
        if (from_rank == to_rank && from_clear == 0 && to_clear >= 2) {
            score += 120;
        }
        if (to_blockers < from_blockers) {
            score += (from_blockers - to_blockers) * 24;
        } else if (to_blockers > from_blockers) {
            score -= (to_blockers - from_blockers) * 18;
        }
    }

    if (MOVE_IS_CAPTURE(m) && MOVE_CAPTURED(m) == PAWN) score += 800;
    return score;
}

static int kb_phase1_pawn_race_score(const Board *b, Move m, Color side) {
    if (b->mod != MOD_KINGS_BATTLE || b->kb_unlocked || MOVE_PIECE(m) != PAWN ||
        MOVE_IS_PROMO(m) || MOVE_IS_EP(m)) {
        return 0;
    }

    Square from_sq = MOVE_FROM(m);
    Square to_sq = MOVE_TO(m);
    int from_rank = kb_phase1_forward_rank(side, from_sq);
    int to_rank = kb_phase1_forward_rank(side, to_sq);
    int score = 0;
    bool passed = kb_phase1_passed_destination(b, side, to_sq);
    int clear_lane = kb_phase1_clear_promotion_lane(b, side, to_sq);
    int promo_dist = kb_phase1_promotion_distance(side, to_sq);
    int enemy_king_dist = kb_phase1_enemy_king_distance(b, side, to_sq);
    int king_pressure = kb_phase1_pawn_king_pressure(b, side, to_sq);

    score += (to_rank - from_rank) * 32;
    if (to_rank >= 3) score += (to_rank - 2) * 26;
    if (SQ_COL(to_sq) >= 2 && SQ_COL(to_sq) <= 5) score += 18;
    score += king_pressure;

    if (!MOVE_IS_CAPTURE(m) && from_rank == 1 && SQ_COL(from_sq) >= 2 && SQ_COL(from_sq) <= 5) {
        score += 18;
        if (SQ_COL(from_sq) == 3 || SQ_COL(from_sq) == 4) {
            score += 34;
        }
    }

    if (!MOVE_IS_CAPTURE(m) && from_rank == 1 && to_rank <= 2 &&
        kb_phase1_any_pawn_capture_available(b, side)) {
        score -= 420;
    }

    score += kb_phase1_retreat_arc_move_score(b, side, to_sq);
    score += kb_phase1_connected_wall_move_score(b, side, to_sq);

    if (MOVE_IS_CAPTURE(m)) {
        score += 80 + to_rank * 22;
        if (MOVE_CAPTURED(m) == PAWN) {
            int enemy_progress = kb_phase1_forward_rank(color_opposite(side), to_sq);
            score += 110;
            if (enemy_progress >= 3) score += 110 + (enemy_progress - 2) * 28;
            if (kb_phase1_has_secondary_pawn_capture(b, side, m)) score += 260;
        } else {
            score += 40;
        }
        if (from_rank >= 3 && to_rank > from_rank) score += 60;
    }

    if (passed) {
        score += 90 + to_rank * 28;
        score += clear_lane * 20;
        if (clear_lane >= promo_dist) score += 90;
        if (enemy_king_dist > promo_dist + 1) {
            score += 70 + (enemy_king_dist - promo_dist) * 18;
        } else if (enemy_king_dist <= 1) {
            score -= 70;
        } else if (enemy_king_dist == 2) {
            score -= 30;
        }
    }

    score -= kb_phase1_wing_drift_move_penalty(b, side, m);

    return score;
}

static int move_score(const Board *b, Move m, Move tt_move,
                      int ply, Color side, Move countermove) {
    if (m == tt_move && tt_move != MOVE_NONE) return 10000000;

    if (MOVE_IS_PROMO(m)) {
        if (MOVE_PROMO_TYPE(m) == QUEEN) return 8000000;
        return -500000;
    }

    if (MOVE_IS_CAPTURE(m) || MOVE_IS_EP(m)) {
        int see = see_value(b, m);
        int score;
        if (see >= 0) {
            score = 5000000 + MVV_LVA[MOVE_PIECE(m)][MOVE_CAPTURED(m)];
        } else {
            score = -1000000 + see;
        }

        if (b->mod == MOD_HEIR && see >= 0) {
            PieceType captured = MOVE_CAPTURED(m);
            Square to = MOVE_TO(m);
            bool central = SQ_ROW(to) >= 2 && SQ_ROW(to) <= 5 &&
                           SQ_COL(to) >= 2 && SQ_COL(to) <= 5;

            if (captured >= KNIGHT) score += 240;
            if (captured == PAWN && central) score += 140;
        }

        if (b->mod == MOD_KINGS_BATTLE && !b->kb_unlocked) {
            if (MOVE_PIECE(m) == KING && MOVE_CAPTURED(m) == PAWN) {
                score += 1600;
            }
            if (MOVE_PIECE(m) == PAWN) {
                score += kb_phase1_pawn_race_score(b, m, side);
            }
        }

        return score;
    }

    if (b->mod == MOD_KINGS_BATTLE && !b->kb_unlocked && MOVE_PIECE(m) == PAWN) {
        int kb_pawn_score = kb_phase1_pawn_race_score(b, m, side);
        if (kb_pawn_score >= 260) return 5200000 + kb_pawn_score;
    }

    if (ply < MAX_PLY) {
        if (m == s_killers[ply][0]) return 900000;
        if (m == s_killers[ply][1]) return 899000;
    }
    if (m == countermove && countermove != MOVE_NONE) return 800000;

    int score = s_history[side][MOVE_FROM(m)][MOVE_TO(m)];
    if (b->mod == MOD_HEIR) {
        int back_rank = (side == WHITE) ? 0 : 7;
        if ((MOVE_PIECE(m) == KNIGHT || MOVE_PIECE(m) == BISHOP) &&
            SQ_ROW(MOVE_FROM(m)) == back_rank && SQ_ROW(MOVE_TO(m)) != back_rank) {
            score += 120;
        }
        if (MOVE_PIECE(m) == KING && heir_king_under_direct_fire(b)) {
            score += 220;
        }
        {
            int queen_sortie_penalty = heir_early_queen_sortie_penalty(b, m);
            if (queen_sortie_penalty > 0) score -= queen_sortie_penalty;
        }
        {
            int f_pawn_block_penalty = heir_f_pawn_block_move_penalty(b, m);
            if (f_pawn_block_penalty > 0) score -= f_pawn_block_penalty;
        }
    }

    score += truce_minor_development_score(b, m, side);
    score -= truce_early_queen_sortie_penalty(b, m, side);
    score += truce_quiet_pawn_score(b, m, side);
    score += kb_phase1_king_activation_score(b, m, side);
    score += kb_phase1_pawn_race_score(b, m, side);
    score += kb_unlocked_development_score(b, m, side);
    score += kb_unlocked_king_shelter_score(b, m, side);

    return score;
}

static void order_moves(const Board *b, MoveList *ml, Move tt_move,
                        int ply, Color side, Move countermove) {
    int scores[MAX_MOVES];
    for (int i = 0; i < ml->count; i++)
        scores[i] = move_score(b, ml->moves[i], tt_move, ply, side, countermove);

    for (int i = 1; i < ml->count; i++) {
        Move m = ml->moves[i];
        int  s = scores[i];
        int  j = i - 1;
        while (j >= 0 && scores[j] < s) {
            ml->moves[j + 1] = ml->moves[j];
            scores[j + 1]    = scores[j];
            j--;
        }
        ml->moves[j + 1] = m;
        scores[j + 1]    = s;
    }
}

static void order_captures_see(const Board *b, MoveList *ml) {
    int scores[MAX_MOVES];
    for (int i = 0; i < ml->count; i++)
        scores[i] = see_value(b, ml->moves[i]);

    for (int i = 1; i < ml->count; i++) {
        Move m = ml->moves[i];
        int  s = scores[i];
        int  j = i - 1;
        while (j >= 0 && scores[j] < s) {
            ml->moves[j + 1] = ml->moves[j];
            scores[j + 1]    = scores[j];
            j--;
        }
        ml->moves[j + 1] = m;
        scores[j + 1]    = s;
    }
}

/* ======================================================================== */
/*  Search state                                                            */
/* ======================================================================== */

static TTable  s_tt;
static int     s_nodes;
static bool    s_stopped;
static int64_t s_deadline_ms;
static int     s_skill_level;
static int     s_prev_skill = -1;   /* track skill changes to clear TT */
static int     s_root_refine_guard;

static int  s_eval_stack[MAX_PLY + MAX_QPLY];
static Move s_root_moves[MAX_MOVES];
static int  s_root_scores[MAX_MOVES];
static int  s_root_count;

static void check_time(void) {
    if ((s_nodes & 4095) == 0) {
        if (s_nodes > MAX_NODES || time_ms_now() >= s_deadline_ms)
            s_stopped = true;
    }
}

void search_reset(int clear_tt) {
    if (clear_tt && s_tt.entries != NULL) tt_clear(&s_tt);

    s_nodes = 0;
    s_stopped = false;
    s_deadline_ms = 0;
    s_root_count = 0;

    memset(s_killers, 0, sizeof(s_killers));
    memset(s_history, 0, sizeof(s_history));
    memset(s_countermoves, 0, sizeof(s_countermoves));
    memset(s_eval_stack, 0, sizeof(s_eval_stack));
    memset(s_root_moves, 0, sizeof(s_root_moves));
    memset(s_root_scores, 0, sizeof(s_root_scores));
}

/* ======================================================================== */
/*  Quiescence search                                                       */
/*                                                                          */
/*  Searches only captures (+ check evasions).  Uses SEE to skip            */
/*  losing captures — the single biggest improvement for tactical play.     */
/* ======================================================================== */

static int quiescence(Board *b, int alpha, int beta, int ply, int qply) {
    s_nodes++;
    check_time();
    if (s_stopped) return 0;

    if (ply >= MAX_PLY + MAX_QPLY) return evaluate(b);
    if (qply >= MAX_QPLY) return evaluate(b);

    /* Heir: terminal state — no king + no recovery */
    if (b->mod == MOD_HEIR) {
        Color us = b->side;
        if (b->pieces[us][KING] == BB_EMPTY) {
            if (b->heir_promoted[us] || b->pieces[us][PAWN] == BB_EMPTY)
                return -(MATE_SCORE - ply);
        }
    }

    /* Succession: terminal states — queen lost or no pawns left */
    if (b->mod == MOD_SUCCESSION) {
        Color us = b->side;
        Color them = color_opposite(us);
        /* If we promoted to King, we already won (handled by caller) */
        /* Opponent promoted to King → we lost */
        if (b->heir_promoted[them]) return -(MATE_SCORE - ply);
        /* Lost a queen? (started with 2 — if fewer, instant loss) */
        int our_queens = bb_popcount(b->pieces[us][QUEEN]);
        if (our_queens < 2 && !b->heir_promoted[us])
            return -(MATE_SCORE - ply);
        /* No pawns → can't promote to King → loss */
        if (b->pieces[us][PAWN] == BB_EMPTY && !b->heir_promoted[us])
            return -(MATE_SCORE - ply);
        /* Check opponent too (they may have lost on their turn) */
        int opp_queens = bb_popcount(b->pieces[them][QUEEN]);
        if (opp_queens < 2 && !b->heir_promoted[them])
            return (MATE_SCORE - ply);
        if (b->pieces[them][PAWN] == BB_EMPTY && !b->heir_promoted[them])
            return (MATE_SCORE - ply);
    }

    bool in_check = board_in_check(b, b->side);

    /* In check: search ALL evasions (not just captures) */
    if (in_check) {
        /* Deep in quiescence, stop expanding check evasions to avoid
           explosion in Mercenary (many pawns can give check).
           After qply 4, just search capture evasions. */
        MoveList ml;
        if (qply >= 4) {
            generate_captures(b, &ml);
            if (ml.count == 0) {
                /* No captures; check if it's mate by trying all moves */
                generate_moves(b, &ml);
                if (ml.count == 0) return -(MATE_SCORE - ply);
                return evaluate(b); /* not mate, return eval */
            }
        } else {
            generate_moves(b, &ml);
            if (ml.count == 0) return -(MATE_SCORE - ply);
        }

        order_moves(b, &ml, MOVE_NONE, mini(ply, MAX_PLY - 1),
                    b->side, MOVE_NONE);

        int best = -INFINITY_SCORE;
        for (int i = 0; i < ml.count; i++) {
            Color mover = b->side;
            board_make_move(b, ml.moves[i]);
            int score = (b->side == mover)
                ? quiescence(b, alpha, beta, ply + 1, qply + 1)
                : -quiescence(b, -beta, -alpha, ply + 1, qply + 1);
            board_unmake_move(b);
            if (s_stopped) return 0;
            if (score > best) best = score;
            if (best > alpha) alpha = best;
            if (alpha >= beta) break;
        }
        return best;
    }

    /* Stand pat (fail-soft: return actual score, not beta, so PVS
       null-window searches at root get properly differentiated scores) */
    int stand_pat = evaluate(b);
    if (stand_pat >= beta) return stand_pat;
    if (stand_pat > alpha) alpha = stand_pat;

    /* Generate captures, order by SEE */
    MoveList ml;
    generate_captures(b, &ml);
    order_captures_see(b, &ml);

    bool is_merc = (b->mod == MOD_MERCENARY);
    bool is_heir = (b->mod == MOD_HEIR);
    bool is_stq  = (b->mod == MOD_SAVE_QUEEN);
    bool is_succ = (b->mod == MOD_SUCCESSION);
    int best = stand_pat;

    for (int i = 0; i < ml.count; i++) {
        Move m = ml.moves[i];

        /* SEE pruning (Stockfish-inspired graduated approach):
           Standard: skip losing captures (SEE < 0).
           Mercenary: at shallow qply, allow slight losers for better
           tactical accuracy; tighten deeper to prevent explosion. */
        int see = see_value(b, m);
        if (is_merc) {
            if (qply < 4 ? (see < -50) : (see <= 0)) continue;
        } else {
            if (see < 0) continue;
        }

        /* Delta pruning: if captured value can't raise alpha */
        int cap_val = see_pv(MOVE_CAPTURED(m), is_merc, is_heir, is_stq, is_succ);
        if (stand_pat + cap_val + 200 < alpha) continue;

        Color mover = b->side;
        board_make_move(b, m);
        int score = (b->side == mover)
            ? quiescence(b, alpha, beta, ply + 1, qply + 1)
            : -quiescence(b, -beta, -alpha, ply + 1, qply + 1);
        board_unmake_move(b);

        if (s_stopped) return 0;
        if (score > best) best = score;
        if (best > alpha) alpha = best;
        if (alpha >= beta) break;
    }

    return best;
}

/* ======================================================================== */
/*  Alpha-beta search                                                       */
/* ======================================================================== */

static int alpha_beta(Board *b, int depth, int alpha, int beta,
                      int ply, bool do_null, bool is_pv) {
    check_time();
    if (s_stopped) return 0;
    s_nodes++;

    if (ply >= MAX_PLY) return evaluate(b);
    if (depth <= 0) return quiescence(b, alpha, beta, ply, 0);

    bool is_merc = (b->mod == MOD_MERCENARY);
    bool is_heir = (b->mod == MOD_HEIR);
    bool heir_volatile = is_heir && heir_position_volatile(b);
    bool kb_phase1 = (b->mod == MOD_KINGS_BATTLE && !b->kb_unlocked);

    /* Heir: terminal state detection — no king + no hope of recovery */
    if (is_heir) {
        Color us = b->side;
        if (b->pieces[us][KING] == BB_EMPTY) {
            /* Promoted king was captured → game over */
            if (b->heir_promoted[us]) return -(MATE_SCORE - ply);
            /* No king + no pawns → can't promote, game over */
            if (b->pieces[us][PAWN] == BB_EMPTY) return -(MATE_SCORE - ply);
        }
    }

    /* Succession: terminal states */
    if (b->mod == MOD_SUCCESSION) {
        Color us = b->side;
        Color them = color_opposite(us);
        if (b->heir_promoted[them]) return -(MATE_SCORE - ply);
        int our_queens = bb_popcount(b->pieces[us][QUEEN]);
        if (our_queens < 2 && !b->heir_promoted[us])
            return -(MATE_SCORE - ply);
        if (b->pieces[us][PAWN] == BB_EMPTY && !b->heir_promoted[us])
            return -(MATE_SCORE - ply);
        int opp_queens = bb_popcount(b->pieces[them][QUEEN]);
        if (opp_queens < 2 && !b->heir_promoted[them])
            return (MATE_SCORE - ply);
        if (b->pieces[them][PAWN] == BB_EMPTY && !b->heir_promoted[them])
            return (MATE_SCORE - ply);
    }

    /* is_pv is now passed as parameter (Stockfish approach), NOT inferred
       from window width.  This prevents TT cutoffs in PV nodes — the key
       fix for Mercenary where transpositions caused all moves to score equal. */
    bool in_check = board_in_check(b, b->side);

    /* ── Mate distance pruning ────────────────────────────────────── */
    {
        int ma = -(MATE_SCORE - ply);
        int mb =  (MATE_SCORE - ply - 1);
        if (alpha < ma) alpha = ma;
        if (beta  > mb) beta  = mb;
        if (alpha >= beta) return alpha;
    }

    /* ── TT probe ─────────────────────────────────────────────────── */
    uint64_t hash = b->hash;
    TTEntry *tte  = tt_probe(&s_tt, hash);
    Move tt_move  = MOVE_NONE;
    int  tt_score = 0;
    bool tt_hit   = false;

    if (tte) {
        tt_move  = tte->best_move;
        tt_score = tte->score;
        tt_hit   = true;

        /* TT cutoff: at lower skill levels, require much deeper entries
           before allowing a cutoff.  This prevents shallower engines
           from playing at full strength via accumulated TT entries.
           The margin must be large enough that we do NOT need to clear
           TT on skill changes (which cripples the stronger engine in
           Watch Engine alternating-skill mode).
           Skill 4: depth >= depth     (use everything)
           Skill 3: depth >= depth+2
           Skill 2: depth >= depth+3
           Skill 0-1: depth >= depth+5  (Easy at d3 only uses d8+ entries) */
        int tt_depth_margin = (s_skill_level >= 4) ? 0
                            : (s_skill_level >= 3) ? 2
                            : (s_skill_level >= 2) ? 3 : 5;
        if (!is_pv && tte->depth >= depth + tt_depth_margin) {
            if (tte->flag == TT_EXACT)                       return tt_score;
            if (tte->flag == TT_LOWER && tt_score >= beta)   return tt_score;
            if (tte->flag == TT_UPPER && tt_score <= alpha)  return tt_score;
        }
    }

    /* ── Static evaluation ────────────────────────────────────────── */
    int static_eval;
    if (in_check) {
        static_eval = -INFINITY_SCORE;
        s_eval_stack[ply] = static_eval;
    } else {
        static_eval = evaluate(b);
        s_eval_stack[ply] = static_eval;

        /* TT score can be a better eval estimate */
        if (tt_hit) {
            if ((tte->flag == TT_EXACT) ||
                (tte->flag == TT_LOWER && tt_score > static_eval) ||
                (tte->flag == TT_UPPER && tt_score < static_eval))
                static_eval = tt_score;
        }
    }

    /* "Improving" flag — less aggressive pruning when eval is getting better */
    bool improving = !in_check && ply >= 2 &&
                     s_eval_stack[ply] > s_eval_stack[ply - 2];

    /* ── Razoring ─────────────────────────────────────────────────── */
    if (!is_merc && !heir_volatile && !kb_phase1 && !is_pv && !in_check && depth <= 2 && !is_mate(alpha)) {
        int razor_margin = (depth == 1) ? 300 : 500;
        if (static_eval + razor_margin < alpha) {
            int razor = quiescence(b, alpha, beta, ply, 0);
            if (razor < alpha) return razor;
        }
    }

    /* ── Reverse futility pruning ─────────────────────────────────── */
    if (!is_merc && !heir_volatile && !kb_phase1 && !is_pv && !in_check && depth <= 6 &&
        !is_mate(alpha) && !is_mate(beta)) {
        int rfp_margin = depth * (improving ? 70 : 100);
        if (static_eval - rfp_margin >= beta)
            return static_eval;
    }

    /* ── Null-move pruning ────────────────────────────────────────── */
    if (!is_merc && !heir_volatile && !kb_phase1 && do_null && !in_check && !is_pv && depth >= 3 && ply > 0 &&
        static_eval >= beta) {
        Color us = b->side;
        bool has_pieces = b->pieces[us][KNIGHT] || b->pieces[us][BISHOP] ||
                          b->pieces[us][ROOK]   || b->pieces[us][QUEEN];
        if (has_pieces) {
            int R = 3 + depth / 4;

            Color sv_side = b->side;
            Square sv_ep  = b->ep_square;
            uint64_t sv_hash = b->hash;
            b->side = color_opposite(b->side);
            b->hash ^= zob_side; /* O(1) side-toggle */
            if (sv_ep != SQ_NONE) b->hash ^= zob_ep[sv_ep]; /* remove old EP */
            b->ep_square = SQ_NONE;

            int null_s = -alpha_beta(b, depth - R, -beta, -beta + 1,
                                     ply + 1, false, false);
            b->side = sv_side;
            b->ep_square = sv_ep;
            b->hash = sv_hash;

            if (s_stopped) return 0;
            if (null_s >= beta && !is_mate(null_s)) return null_s;
        }
    }

    /* ── Move generation and ordering ─────────────────────────────── */
    MoveList ml;
    generate_moves(b, &ml);
    if (ml.count == 0) {
        if (in_check) return -(MATE_SCORE - ply);
        /* Heir: no legal moves + no king is a loss, not stalemate */
        if (b->mod == MOD_HEIR && b->pieces[b->side][KING] == BB_EMPTY)
            return -(MATE_SCORE - ply);
        return 0; /* stalemate */
    }

    Move countermove = MOVE_NONE;
    if (b->ply > 0) {
        Move prev = b->history[b->ply - 1].move;
        if (prev != MOVE_NONE) {
            Color ps = color_opposite(b->side);
            countermove = s_countermoves[ps][MOVE_PIECE(prev)][MOVE_TO(prev)];
        }
    }

    /* IID: when PV node has no TT move, do a shallow search to find one.
       This is a key Stockfish technique — dramatically improves move ordering
       at PV nodes, which reduces tree size and prevents random-looking play. */
    if (is_pv && depth >= 4 && tt_move == MOVE_NONE && !in_check) {
        alpha_beta(b, depth - 2, alpha, beta, ply, false, true);
        tte = tt_probe(&s_tt, hash);
        if (tte) tt_move = tte->best_move;
    }

    order_moves(b, &ml, tt_move, ply, b->side, countermove);

    /* Futility flag */
    bool do_futility = false;
    if (!is_merc && !heir_volatile && !kb_phase1 && !is_pv && !in_check && depth <= 3 && !is_mate(alpha)) {
        int fut_margin = depth * (improving ? 120 : 180);
        do_futility = (static_eval + fut_margin <= alpha);
    }

    /* LMP limits by depth */
    static const int LMP_LIMIT[] = {0, 5, 10, 18, 28, 40};

    int orig_alpha    = alpha;
    int best_score    = -INFINITY_SCORE;
    Move best_move    = MOVE_NONE;
    int moves_done    = 0;

    Move searched_quiets[MAX_MOVES];
    int  quiet_count = 0;

    for (int i = 0; i < ml.count; i++) {
        Move m = ml.moves[i];
        bool is_cap   = MOVE_IS_CAPTURE(m) || MOVE_IS_EP(m);
        bool is_promo = MOVE_IS_PROMO(m);
        bool heir_critical = is_heir && heir_critical_move(b, m);
        Color mover = b->side;
        int kb_pawn_score = (kb_phase1 && MOVE_PIECE(m) == PAWN)
            ? kb_phase1_pawn_race_score(b, m, mover)
            : 0;

        /* Compute SEE BEFORE making the move (SEE reads board state) */
        int see_val = 0;
        if (is_cap) see_val = see_value(b, m);
        bool heir_tactical = is_heir && heir_tactical_capture(b, m, see_val);

        /* Detect recapture BEFORE making the move */
        bool is_recapture = false;
        if (is_cap && b->ply > 0) {
            Move prev = b->history[b->ply - 1].move;
            if (prev != MOVE_NONE && MOVE_IS_CAPTURE(prev)
                && MOVE_TO(prev) == MOVE_TO(m))
                is_recapture = true;
        }

        board_make_move(b, m);
        bool same_turn = (b->side == mover);
        bool gives_check = board_in_check(
            b,
            same_turn ? color_opposite(mover) : b->side
        );

        /* ── Pre-search pruning (non-PV, non-root, not first move) ─ */
        if (!is_pv && !in_check && moves_done > 0) {

            /* LMP: skip late quiet moves at shallow depths */
            if (!kb_phase1 && !is_merc && !heir_volatile && !is_cap && !is_promo && !gives_check &&
                depth <= 5 && moves_done >= LMP_LIMIT[depth]) {
                board_unmake_move(b);
                continue;
            }

            /* Futility: skip late quiets when eval+margin < alpha */
            if (!kb_phase1 && !is_merc && !heir_volatile && do_futility && !is_cap && !is_promo && !gives_check) {
                board_unmake_move(b);
                continue;
            }

            /* SEE pruning for captures at low depth */
            if (is_cap && depth <= 3 && !gives_check) {
                if (!heir_critical && see_val < -80 * depth) {
                    board_unmake_move(b);
                    continue;
                }
            }
        }

        /* ── Extensions ───────────────────────────────────────────── */
        bool merc_endgame = is_merc && bb_popcount(b->all) <= 16;
        int ext = gives_check ? 1 : 0;
        if (kb_phase1 && depth >= 3 && (is_cap || is_promo)) {
            ext = maxi(ext, 1);
        }
        if (kb_phase1 && depth >= 4 && is_cap && MOVE_PIECE(m) == PAWN &&
            MOVE_CAPTURED(m) == PAWN) {
            ext = maxi(ext, 2);
        }
        if (kb_phase1 && depth >= 4 && MOVE_PIECE(m) == PAWN &&
            kb_pawn_score >= 320) {
            ext = maxi(ext, 2);
        } else if (kb_phase1 && depth >= 3 && MOVE_PIECE(m) == PAWN &&
                   !is_cap && !is_promo && kb_pawn_score >= 220) {
            ext = maxi(ext, 1);
        }
        /* Recapture extension: search deeper when recapturing on the
           same square to avoid horizon-effect blunders in exchanges */
        if (!ext && is_recapture && depth >= 4) ext = 1;
                if (!ext && merc_endgame && is_cap && depth >= 4) ext = 1;
          if (!ext && heir_tactical && depth >= 4) ext = 1;
                if (!ext && is_heir && depth >= 4 && heir_critical) ext = 1;
        int new_depth = depth - 1 + ext;

        /* ── PVS + LMR ───────────────────────────────────────────── */
        int score;
        bool kb_force_full_window = (b->mod == MOD_KINGS_BATTLE && is_pv && depth <= 4);

        if (moves_done == 0 || kb_force_full_window) {
            if (same_turn) {
                score = alpha_beta(b, new_depth, alpha, beta, ply + 1, true, is_pv);
            } else {
                score = -alpha_beta(b, new_depth, -beta, -alpha, ply + 1, true, is_pv);
            }
        } else {
            int reduction = 0;
            bool merc_quiet = is_merc && !is_cap && !is_promo;
            bool heir_quiet = is_heir && heir_volatile && heir_critical && !is_cap && !is_promo;

            /* LMR */
            if (!merc_quiet && !heir_quiet && moves_done >= 3 && depth >= 3 && ext == 0 &&
                !is_cap && !is_promo) {
                reduction = 1;
                if (moves_done >= 6)  reduction++;
                if (moves_done >= 12) reduction++;
                if (!improving) reduction++;
                if (is_pv && reduction > 0) reduction--;
                if (is_heir && heir_critical && reduction > 0) reduction--;
                /* Truce: developing moves (minor piece leaves back rank)
                   are strategic — reduce less for proper positional play */
                if (b->mod == MOD_TRUCE && b->truce_active && reduction > 0) {
                    int piece = MOVE_PIECE(m);
                    if (piece == KNIGHT || piece == BISHOP) {
                        Square from_sq = MOVE_FROM(m);
                        int from_rank = (mover == WHITE) ? SQ_ROW(from_sq)
                                                         : (7 - SQ_ROW(from_sq));
                        if (from_rank <= 1) reduction--;
                        if (piece == KNIGHT && truce_undeveloped_minor_count(b, mover) >= 2 && reduction > 0)
                            reduction--;
                    } else if (piece == PAWN) {
                        Square from_sq = MOVE_FROM(m);
                        Square to_sq = MOVE_TO(m);
                        int from_rank = (mover == WHITE) ? SQ_ROW(from_sq)
                                                         : (7 - SQ_ROW(from_sq));
                        int to_rank = (mover == WHITE) ? SQ_ROW(to_sq)
                                                       : (7 - SQ_ROW(to_sq));
                        int file = SQ_COL(to_sq);
                        int attack_row = SQ_ROW(to_sq) + ((mover == WHITE) ? 1 : -1);
                        bool harasses_bishop = false;

                        if (attack_row >= 0 && attack_row < 8) {
                            if (file > 0 && BB_HAS(b->pieces[color_opposite(mover)][BISHOP], SQ(attack_row, file - 1)))
                                harasses_bishop = true;
                            if (file < 7 && BB_HAS(b->pieces[color_opposite(mover)][BISHOP], SQ(attack_row, file + 1)))
                                harasses_bishop = true;
                        }

                        /* Truce: fresh pawn nudges are often structurally critical
                           because they either build lasting space or chase bishops
                           that cannot justify an immediate pin/capture. */
                        if (from_rank == 1) {
                            reduction--;
                            if ((to_rank >= 3 || harasses_bishop) && reduction > 0)
                                reduction--;
                        }
                    }
                }
                /* King's Battle Phase 1: king moves are tactical (hunting
                   pawns) — reduce less to see captures deeper */
                if (b->mod == MOD_KINGS_BATTLE && !b->kb_unlocked
                    && MOVE_PIECE(m) == KING && reduction > 0) {
                    reduction = 0;
                }
                if (kb_phase1 && MOVE_PIECE(m) == PAWN) {
                    Square from_sq = MOVE_FROM(m);
                    Square to_sq = MOVE_TO(m);
                    int from_rank = kb_phase1_forward_rank(mover, from_sq);
                    int to_rank = kb_phase1_forward_rank(mover, to_sq);

                    if (kb_pawn_score >= 120 && reduction > 0)
                        reduction--;
                    if (kb_pawn_score >= 220 && reduction > 0)
                        reduction--;
                    if (!is_cap && !is_promo && from_rank == 1 && to_rank <= 2 &&
                        kb_phase1_any_pawn_capture_available(b, mover)) {
                        reduction++;
                    }
                }
                if (b->mod == MOD_KINGS_BATTLE && b->kb_unlocked && reduction > 0) {
                    int kb_dev_score = kb_unlocked_development_score(b, m, mover);
                    int kb_shelter_score = kb_unlocked_king_shelter_score(b, m, mover);
                    if (kb_dev_score >= 50 || kb_shelter_score >= 80) reduction--;
                }
                reduction = mini(reduction, new_depth - 1);
                if (reduction < 0) reduction = 0;
            }

            if (same_turn) {
                score = alpha_beta(b, new_depth - reduction,
                                   alpha, alpha + 1, ply + 1, true, false);
            } else {
                score = -alpha_beta(b, new_depth - reduction,
                                    -(alpha + 1), -alpha, ply + 1, true, false);
            }

            if (score > alpha && reduction > 0) {
                if (same_turn) {
                    score = alpha_beta(b, new_depth,
                                       alpha, alpha + 1, ply + 1, true, false);
                } else {
                    score = -alpha_beta(b, new_depth,
                                        -(alpha + 1), -alpha, ply + 1, true, false);
                }
            }

            if (score > alpha && score < beta) {
                if (same_turn) {
                    score = alpha_beta(b, new_depth, alpha, beta, ply + 1, true, true);
                } else {
                    score = -alpha_beta(b, new_depth, -beta, -alpha, ply + 1, true, true);
                }
            }
        }

        board_unmake_move(b);
        if (s_stopped) return 0;

        if (!is_cap && !is_promo && quiet_count < MAX_MOVES)
            searched_quiets[quiet_count++] = m;

        moves_done++;

        if (score > best_score) {
            best_score = score;
            best_move  = m;
        }
        if (score > alpha) alpha = score;
        if (alpha >= beta) {
            if (!is_cap && !is_promo) {
                record_killer(m, ply);
                record_history(b->side, m, depth);
                penalize_quiets(b->side, searched_quiets, quiet_count - 1, depth);
                if (b->ply > 0) {
                    Move prev = b->history[b->ply - 1].move;
                    if (prev != MOVE_NONE) {
                        Color ps = color_opposite(b->side);
                        s_countermoves[ps][MOVE_PIECE(prev)][MOVE_TO(prev)] = m;
                    }
                }
            }
            break;
        }
    }

    /* ── TT store ─────────────────────────────────────────────────── */
    TTFlag flag;
    if (best_score <= orig_alpha) flag = TT_UPPER;
    else if (best_score >= beta)  flag = TT_LOWER;
    else                          flag = TT_EXACT;
    tt_store(&s_tt, hash, depth, best_score, flag, best_move);

    return best_score;
}

/* ======================================================================== */
/*  Root search with aspiration windows + iterative deepening               */
/* ======================================================================== */

SearchResult search_think(Board *b, int time_ms, int max_depth, int skill_level) {
    zobrist_init();
    if (s_tt.entries == NULL) tt_alloc(&s_tt, 16);

    search_reset(0);
    s_deadline_ms = time_ms_now() + (int64_t)time_ms;
    s_skill_level = (skill_level < 0) ? 0 : (skill_level > 4 ? 4 : skill_level);
    s_rng         = b->hash ^ (uint64_t)time_ms_now() ^ ((uint64_t)b->fullmove << 32);

    /* Track skill changes (no TT clear — the depth margins in
       alpha_beta prevent lower skills from getting free cutoffs). */
    s_prev_skill = s_skill_level;

    int depth_limit = (max_depth > 0 && max_depth < MAX_PLY) ? max_depth : MAX_PLY;

    SearchResult result;
    result.best_move = MOVE_NONE;
    result.score     = 0;
    result.depth     = 0;
    result.nodes     = 0;

    Move tmp_moves[MAX_MOVES];
    int  tmp_scores[MAX_MOVES];

    for (int depth = 1; depth <= depth_limit; depth++) {
        MoveList ml;
        generate_moves(b, &ml);
        if (ml.count == 0) break;

        /* ── Aspiration windows ───────────────────────────────────── */
        int asp = 25;
        int al, be;

        if (depth >= 4 && !is_mate(result.score)) {
            al = result.score - asp;
            be = result.score + asp;
        } else {
            al = -INFINITY_SCORE;
            be =  INFINITY_SCORE;
        }

        int  best_rs = -INFINITY_SCORE;
        Move best_rm = MOVE_NONE;

        for (;;) {
            order_moves(b, &ml, result.best_move, 0, b->side, MOVE_NONE);

            best_rs = -INFINITY_SCORE;
            best_rm = MOVE_NONE;

            for (int i = 0; i < ml.count; i++) {
                Color mover = b->side;
                board_make_move(b, ml.moves[i]);
                bool same_turn = (b->side == mover);
                int ext = board_in_check(
                    b,
                    same_turn ? color_opposite(mover) : b->side
                ) ? 1 : 0;
                int score;

                /* Full-window root: search every move with the full
                   aspiration window so each gets an accurate score.
                   In Mercenary, PVS null-window + fail-hard pruning
                   deep in the tree clamps all fail-low scores to
                   root_alpha, making moves indistinguishable.
                   Deeper levels still use PVS for efficiency. */
                score = same_turn
                    ? alpha_beta(b, depth - 1 + ext, al, be, 1, true, true)
                    : -alpha_beta(b, depth - 1 + ext, -be, -al, 1, true, true);

                if ((score <= al || score >= be) &&
                    (al > -INFINITY_SCORE || be < INFINITY_SCORE)) {
                    score = same_turn
                        ? alpha_beta(b, depth - 1 + ext,
                                     -INFINITY_SCORE, INFINITY_SCORE,
                                     1, true, true)
                        : -alpha_beta(b, depth - 1 + ext,
                                      -INFINITY_SCORE, INFINITY_SCORE,
                                      1, true, true);
                }

                board_unmake_move(b);
                if (s_stopped) goto done;

                tmp_moves[i]  = ml.moves[i];
                tmp_scores[i] = score;

                if (score > best_rs) {
                    best_rs = score;
                    best_rm = ml.moves[i];
                }
            }

            /* Check aspiration window */
            if (best_rs <= al && al > -INFINITY_SCORE) {
                asp *= 2;
                al = best_rs - asp;
                if (asp > 500) al = -INFINITY_SCORE;
                continue;
            }
            if (best_rs >= be && be < INFINITY_SCORE) {
                asp *= 2;
                be = best_rs + asp;
                if (asp > 500) be = INFINITY_SCORE;
                continue;
            }
            break;
        }

        /* Commit completed iteration */
        for (int i = 0; i < ml.count; i++) {
            s_root_moves[i]  = tmp_moves[i];
            s_root_scores[i] = tmp_scores[i];
        }
        s_root_count = ml.count;

        result.best_move = best_rm;
        result.score     = best_rs;
        result.depth     = depth;
        result.nodes     = s_nodes;

        /* Debug: print iteration summary with top moves (enable for debugging) */
        {
            /* Sort temps by score for display */
            for (int a = 0; a < mini(5, ml.count); a++) {
                int best_idx = a;
                for (int c = a + 1; c < ml.count; c++)
                    if (tmp_scores[c] > tmp_scores[best_idx]) best_idx = c;
                if (best_idx != a) {
                    Move tm = tmp_moves[a]; tmp_moves[a] = tmp_moves[best_idx]; tmp_moves[best_idx] = tm;
                    int ts = tmp_scores[a]; tmp_scores[a] = tmp_scores[best_idx]; tmp_scores[best_idx] = ts;
                }
            }
            char dbg[512];
            int doff = snprintf(dbg, sizeof(dbg), "sk=%d d=%d best=%c%s%s s=%d n=%d top:",
                    s_skill_level,
                    depth, pt_char[MOVE_PIECE(best_rm)],
                    sq_name(MOVE_FROM(best_rm)), sq_name(MOVE_TO(best_rm)),
                    best_rs, s_nodes);
            for (int a = 0; a < mini(5, ml.count) && doff < 480; a++) {
                doff += snprintf(dbg + doff, sizeof(dbg) - doff, " %c%s%s=%d",
                        pt_char[MOVE_PIECE(tmp_moves[a])],
                        sq_name(MOVE_FROM(tmp_moves[a])),
                        sq_name(MOVE_TO(tmp_moves[a])),
                        tmp_scores[a]);
            }
            LOGD("%s", dbg);
        }

        if (is_mate(best_rs)) break;
    }

done:
    /* ── Skill-based move selection (Stockfish's approach) ─────────── */
    /*  At full skill (4), return the best move.
        At lower skill, allow random selection from moves within a margin
        that scales with skill deficit.  This creates genuine difficulty
        differentiation without making lower levels play nonsensically. */
    if (s_root_count > 1 && !is_mate(result.score)) {
        int best_root = -INFINITY_SCORE;
        for (int i = 0; i < s_root_count; i++)
            if (s_root_scores[i] > best_root) best_root = s_root_scores[i];

        /* Skill-based margin: skill 0 = 80cp, 1 = 50cp, 2 = 30cp, 3 = 15cp, 4 = 0 */
        static const int SKILL_MARGIN[] = { 80, 50, 30, 15, 0 };
        int s_margin = SKILL_MARGIN[s_skill_level];

          /* Opening variety is only for sub-max skills. At full skill, keep
              move selection deterministic so engine strength and audits are
              measuring the actual best line rather than random opening drift. */
        bool is_opening = (b->mod == MOD_MERCENARY)
                        ? (b->fullmove <= 6)
                        : (b->mod == MOD_HEIR)
                        ? (b->fullmove <= 5)
                        : (b->mod == MOD_TRUCE)
                        ? (b->fullmove <= 8)
                        : (b->mod == MOD_KINGS_BATTLE)
                        ? (b->fullmove <= 6)
                        : (b->mod == MOD_SAVE_QUEEN)
                        ? (b->fullmove <= 5)
                        : (b->mod == MOD_SUCCESSION)
                        ? (b->fullmove <= 5)
                        : (b->fullmove <= 4);
                if (is_opening && s_skill_level < 4) s_margin = maxi(s_margin, 10);

        if (s_margin > 0) {
            Move cands[MAX_MOVES];
            int  cand_scores[MAX_MOVES];
            int  cand_n = 0;

            for (int i = 0; i < s_root_count; i++) {
                if (best_root - s_root_scores[i] <= s_margin) {
                    cands[cand_n] = s_root_moves[i];
                    cand_scores[cand_n] = s_root_scores[i];
                    cand_n++;
                }
            }

            if (cand_n > 1) {
                if (s_skill_level >= 3) {
                    /* Skill 3-4: pick best, with random tiebreak among
                       moves within 3cp of best for variety */
                    int top_score = -INFINITY_SCORE;
                    for (int i = 0; i < cand_n; i++)
                        if (cand_scores[i] > top_score) top_score = cand_scores[i];
                    Move top[MAX_MOVES];
                    int top_n = 0;
                    for (int i = 0; i < cand_n; i++)
                        if (top_score - cand_scores[i] <= 3)
                            top[top_n++] = cands[i];
                    if (top_n > 0) {
                        result.best_move = top[rng_range(top_n)];
                    }
                } else {
                    /* Skill 0-2: weighted random — better moves are more
                       likely but worse moves can be picked, creating
                       realistic weaker play (Stockfish approach). */
                    int weights[MAX_MOVES];
                    int total_w = 0;
                    for (int i = 0; i < cand_n; i++) {
                        /* Weight: higher score = higher weight.
                           shift so worst candidate gets weight 1 */
                        int w = cand_scores[i] - (best_root - s_margin) + 1;
                        if (w < 1) w = 1;
                        weights[i] = w;
                        total_w += w;
                    }
                    int pick = rng_range(total_w);
                    int cum = 0;
                    for (int i = 0; i < cand_n; i++) {
                        cum += weights[i];
                        if (pick < cum) {
                            result.best_move = cands[i];
                            break;
                        }
                    }
                }
            }
        }
    }

    LOGD("FINAL sk=%d d=%d move=%c%s%s score=%d nodes=%d",
         s_skill_level, result.depth,
         pt_char[MOVE_PIECE(result.best_move)],
         sq_name(MOVE_FROM(result.best_move)),
         sq_name(MOVE_TO(result.best_move)),
         result.score, result.nodes);

    return result;
}
