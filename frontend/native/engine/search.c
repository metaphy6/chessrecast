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
static inline bool is_mate(int s) {
    return s > MATE_SCORE - 500 || s < -MATE_SCORE + 500;
}

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

/* Get SEE piece value, accounting for Mercenary pawn value */
static inline int see_pv(PieceType pt, bool is_merc) {
    if (pt == PAWN && is_merc) return 180;
    return SEE_PIECE_VAL[pt];
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

    int gain[32];
    int d = 0;

    /* Initial gain: value of captured piece */
    gain[0] = see_pv(MOVE_CAPTURED(m), is_merc);

    /* The moving piece becomes the target */
    PieceType next_victim = MOVE_PIECE(m);

    if (MOVE_IS_PROMO(m)) {
        gain[0] += see_pv(MOVE_PROMO_TYPE(m), is_merc)
                 - see_pv(PAWN, is_merc);
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
        gain[d] = see_pv(next_victim, is_merc) - gain[d - 1];

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

static int move_score(const Board *b, Move m, Move tt_move,
                      int ply, Color side, Move countermove) {
    if (m == tt_move && tt_move != MOVE_NONE) return 10000000;

    if (MOVE_IS_PROMO(m)) {
        if (MOVE_PROMO_TYPE(m) == QUEEN) return 8000000;
        return -500000;
    }

    if (MOVE_IS_CAPTURE(m) || MOVE_IS_EP(m)) {
        int see = see_value(b, m);
        if (see >= 0) {
            return 5000000 + MVV_LVA[MOVE_PIECE(m)][MOVE_CAPTURED(m)];
        } else {
            return -1000000 + see;
        }
    }

    if (ply < MAX_PLY) {
        if (m == s_killers[ply][0]) return 900000;
        if (m == s_killers[ply][1]) return 899000;
    }
    if (m == countermove && countermove != MOVE_NONE) return 800000;

    return s_history[side][MOVE_FROM(m)][MOVE_TO(m)];
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
            board_make_move(b, ml.moves[i]);
            int score = -quiescence(b, -beta, -alpha, ply + 1, qply + 1);
            board_unmake_move(b);
            if (s_stopped) return 0;
            if (score > best) best = score;
            if (score > alpha) alpha = score;
            if (alpha >= beta) return beta;
        }
        return best > -INFINITY_SCORE ? best : alpha;
    }

    /* Stand pat */
    int stand_pat = evaluate(b);
    if (stand_pat >= beta) return beta;
    if (stand_pat > alpha) alpha = stand_pat;

    /* Generate captures, order by SEE */
    MoveList ml;
    generate_captures(b, &ml);
    order_captures_see(b, &ml);

    bool is_merc = (b->mod == MOD_MERCENARY);

    for (int i = 0; i < ml.count; i++) {
        Move m = ml.moves[i];

        /* SEE pruning: skip captures with SEE < 0.
           In Mercenary, also skip SEE == 0 (equal exchanges) to prevent
           quiescence explosion from 16 king-like pawns trading endlessly.
           This is the KEY fix — stops the engine from making
           losing captures (like QxP when pawn is defended). */
        int see = see_value(b, m);
        if (is_merc ? (see <= 0) : (see < 0)) continue;

        /* Delta pruning: if captured value can't raise alpha */
        int cap_val = see_pv(MOVE_CAPTURED(m), is_merc);
        if (stand_pat + cap_val + 200 < alpha) continue;

        board_make_move(b, m);
        int score = -quiescence(b, -beta, -alpha, ply + 1, qply + 1);
        board_unmake_move(b);

        if (s_stopped) return 0;
        if (score > alpha) alpha = score;
        if (alpha >= beta) return beta;
    }

    return alpha;
}

/* ======================================================================== */
/*  Alpha-beta search                                                       */
/* ======================================================================== */

static int alpha_beta(Board *b, int depth, int alpha, int beta,
                      int ply, bool do_null) {
    check_time();
    if (s_stopped) return 0;
    s_nodes++;

    if (ply >= MAX_PLY) return evaluate(b);
    if (depth <= 0) return quiescence(b, alpha, beta, ply, 0);

    bool is_pv   = (beta - alpha > 1);
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

        if (!is_pv && tte->depth >= depth) {
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
    if (!is_pv && !in_check && depth <= 2 && !is_mate(alpha)) {
        int razor_margin = (depth == 1) ? 300 : 500;
        if (static_eval + razor_margin < alpha) {
            int razor = quiescence(b, alpha, beta, ply, 0);
            if (razor < alpha) return razor;
        }
    }

    /* ── Reverse futility pruning ─────────────────────────────────── */
    if (!is_pv && !in_check && depth <= 6 &&
        !is_mate(alpha) && !is_mate(beta)) {
        int rfp_margin = depth * (improving ? 70 : 100);
        if (static_eval - rfp_margin >= beta)
            return static_eval;
    }

    /* ── Null-move pruning ────────────────────────────────────────── */
    if (do_null && !in_check && !is_pv && depth >= 3 && ply > 0 &&
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
            b->ep_square = SQ_NONE;
            b->hash = zobrist_compute(b); /* CRITICAL: update hash for TT correctness */

            int null_s = -alpha_beta(b, depth - R, -beta, -beta + 1,
                                     ply + 1, false);
            b->side = sv_side;
            b->ep_square = sv_ep;
            b->hash = sv_hash;

            if (s_stopped) return 0;
            if (null_s >= beta && !is_mate(null_s)) return beta;
        }
    }

    /* ── Move generation and ordering ─────────────────────────────── */
    MoveList ml;
    generate_moves(b, &ml);
    if (ml.count == 0)
        return in_check ? -(MATE_SCORE - ply) : 0;

    Move countermove = MOVE_NONE;
    if (b->ply > 0) {
        Move prev = b->history[b->ply - 1].move;
        if (prev != MOVE_NONE) {
            Color ps = color_opposite(b->side);
            countermove = s_countermoves[ps][MOVE_PIECE(prev)][MOVE_TO(prev)];
        }
    }

    order_moves(b, &ml, tt_move, ply, b->side, countermove);

    /* Futility flag */
    bool do_futility = false;
    if (!is_pv && !in_check && depth <= 3 && !is_mate(alpha)) {
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

        /* Compute SEE BEFORE making the move (SEE reads board state) */
        int see_val = 0;
        if (is_cap) see_val = see_value(b, m);

        board_make_move(b, m);
        bool gives_check = board_in_check(b, b->side);

        /* ── Pre-search pruning (non-PV, non-root, not first move) ─ */
        if (!is_pv && !in_check && moves_done > 0) {

            /* LMP: skip late quiet moves at shallow depths */
            if (!is_cap && !is_promo && !gives_check &&
                depth <= 5 && moves_done >= LMP_LIMIT[depth]) {
                board_unmake_move(b);
                continue;
            }

            /* Futility: skip late quiets when eval+margin < alpha */
            if (do_futility && !is_cap && !is_promo && !gives_check) {
                board_unmake_move(b);
                continue;
            }

            /* SEE pruning for captures at low depth */
            if (is_cap && depth <= 3 && !gives_check) {
                if (see_val < -80 * depth) {
                    board_unmake_move(b);
                    continue;
                }
            }
        }

        /* ── Extensions ───────────────────────────────────────────── */
        int ext = gives_check ? 1 : 0;
        int new_depth = depth - 1 + ext;

        /* ── PVS + LMR ───────────────────────────────────────────── */
        int score;

        if (moves_done == 0) {
            score = -alpha_beta(b, new_depth, -beta, -alpha, ply + 1, true);
        } else {
            int reduction = 0;

            /* LMR */
            if (moves_done >= 3 && depth >= 3 && ext == 0 &&
                !is_cap && !is_promo) {
                reduction = 1;
                if (moves_done >= 6)  reduction++;
                if (moves_done >= 12) reduction++;
                if (!improving) reduction++;
                if (is_pv && reduction > 0) reduction--;
                reduction = mini(reduction, new_depth - 1);
                if (reduction < 0) reduction = 0;
            }

            score = -alpha_beta(b, new_depth - reduction,
                                -(alpha + 1), -alpha, ply + 1, true);

            if (score > alpha && reduction > 0)
                score = -alpha_beta(b, new_depth,
                                    -(alpha + 1), -alpha, ply + 1, true);

            if (score > alpha && score < beta)
                score = -alpha_beta(b, new_depth, -beta, -alpha, ply + 1, true);
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

    s_nodes       = 0;
    s_stopped     = false;
    s_deadline_ms = time_ms_now() + (int64_t)time_ms;
    s_skill_level = (skill_level < 0) ? 0 : (skill_level > 4 ? 4 : skill_level);
    s_rng         = b->hash ^ (uint64_t)time_ms_now();
    s_root_count  = 0;

    memset(s_killers, 0, sizeof(s_killers));
    memset(s_history, 0, sizeof(s_history));
    memset(s_countermoves, 0, sizeof(s_countermoves));
    memset(s_eval_stack, 0, sizeof(s_eval_stack));

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
            int root_alpha = al;

            for (int i = 0; i < ml.count; i++) {
                board_make_move(b, ml.moves[i]);
                int ext = board_in_check(b, b->side) ? 1 : 0;
                int score;

                /* For Mercenary: always full-window search at root.
                   PVS null-window + TT causes all moves to score equal
                   because 16 king-like pawns create massive transpositions.
                   Full window ensures each root move gets its true score. */
                if (b->mod == MOD_MERCENARY || i == 0) {
                    score = -alpha_beta(b, depth - 1 + ext,
                                        -be, -root_alpha, 1, true);
                } else {
                    score = -alpha_beta(b, depth - 1 + ext,
                                        -(root_alpha + 1), -root_alpha, 1, true);
                    if (score > root_alpha && score < be)
                        score = -alpha_beta(b, depth - 1 + ext,
                                            -be, -root_alpha, 1, true);
                }
                board_unmake_move(b);
                if (s_stopped) goto done;

                tmp_moves[i]  = ml.moves[i];
                tmp_scores[i] = score;

                if (score > best_rs) {
                    best_rs = score;
                    best_rm = ml.moves[i];
                }
                if (score > root_alpha) root_alpha = score;
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
#if 0
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
            int doff = snprintf(dbg, sizeof(dbg), "d=%d best=%c%s%s s=%d n=%d top:",
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
#endif

        if (is_mate(best_rs)) break;
    }

done:
    /* ── Opening variety / Mercenary tiebreaking ──────────────────── */
    if (s_root_count > 1 && !is_mate(result.score)) {
        int best_root = -INFINITY_SCORE;
        for (int i = 0; i < s_root_count; i++)
            if (s_root_scores[i] > best_root) best_root = s_root_scores[i];

        if (b->mod == MOD_MERCENARY && b->fullmove <= 6) {
            /* Mercenary opening: when top moves score within margin, use
               static evaluation of resulting position as tiebreaker.
               Only applies in the first 6 moves before contact/tactics.
               IMPORTANT: skip captures — their search scores are already
               accurate, and static eval after a capture is misleading. */
            int margin = 5;
            Move cands[MAX_MOVES];
            int  cand_evals[MAX_MOVES];
            int  cand_n = 0;

            for (int i = 0; i < s_root_count; i++) {
                if (best_root - s_root_scores[i] <= margin) {
                    Move m = s_root_moves[i];
                    PieceType pt = MOVE_PIECE(m);
                    /* Skip captures and queen moves (tactically sensitive) */
                    if (MOVE_IS_CAPTURE(m)) continue;
                    if (pt == QUEEN) continue;

                    board_make_move(b, m);
                    int ev = -evaluate(b);  /* eval from our perspective */
                    board_unmake_move(b);

                    cands[cand_n] = m;
                    cand_evals[cand_n] = ev;
                    cand_n++;
                }
            }

            if (cand_n > 1) {
                /* Pick the move with best static eval */
                int best_ev = -INFINITY_SCORE;
                int best_idx = 0;
                for (int i = 0; i < cand_n; i++) {
                    if (cand_evals[i] > best_ev) {
                        best_ev = cand_evals[i];
                        best_idx = i;
                    }
                }
                /* Among moves with equal best eval (within 3cp), add small
                   random tie-break for variety */
                Move top_cands[MAX_MOVES];
                int  top_n = 0;
                for (int i = 0; i < cand_n; i++) {
                    if (best_ev - cand_evals[i] <= 3)
                        top_cands[top_n++] = cands[i];
                }
                if (top_n > 0) {
                    int pick = rng_range(top_n);
                    result.best_move = top_cands[pick];
                } else {
                    result.best_move = cands[best_idx];
                }
            }
        } else if (b->fullmove <= 4) {
            /* Standard: random pick among equal candidates */
            int margin = 8;
            Move cands[MAX_MOVES];
            int  cand_n = 0;
            for (int i = 0; i < s_root_count; i++) {
                if (best_root - s_root_scores[i] <= margin)
                    cands[cand_n++] = s_root_moves[i];
            }
            if (cand_n > 1) {
                int pick = rng_range(cand_n);
                result.best_move = cands[pick];
            }
        }
    }

    return result;
}
