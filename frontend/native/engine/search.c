#include "search.h"
#include "movegen.h"
#include "evaluate.h"
#include <stdlib.h>
#include <string.h>
#include <time.h>

#ifdef _WIN32
  #include <windows.h>
  static int64_t time_ms_now(void) {
      return (int64_t)GetTickCount64();
  }
#else
  /* POSIX: use CLOCK_MONOTONIC for reliable wall-clock timing */
  static int64_t time_ms_now(void) {
      struct timespec ts;
      clock_gettime(CLOCK_MONOTONIC, &ts);
      return (int64_t)ts.tv_sec * 1000 + ts.tv_nsec / 1000000;
  }
#endif

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Constants                                                                */
/* ═══════════════════════════════════════════════════════════════════════════ */

#define INFINITY_SCORE  999999
#define MATE_SCORE      100000
#define MAX_PLY         64
#define MAX_QPLY        32      /* hard limit on quiescence depth */
#define MAX_NODES       20000000 /* safety: abort if exceeded */

static inline bool is_mate(int s) { return s > MATE_SCORE - 500 || s < -MATE_SCORE + 500; }

/* Material values for delta pruning (must match evaluate.c) */
static const int SEE_VAL[7] = { 100, 320, 330, 500, 900, 0, 0 };

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  PRNG (xorshift64) for skill-based randomisation                          */
/* ═══════════════════════════════════════════════════════════════════════════ */

static uint64_t s_rng;

static uint64_t rng_next(void) {
    s_rng ^= s_rng << 13;
    s_rng ^= s_rng >> 7;
    s_rng ^= s_rng << 17;
    return s_rng;
}

/* Random int in [0, max) */
static int rng_range(int max) {
    if (max <= 1) return 0;
    return (int)(rng_next() % (uint64_t)max);
}

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Transposition Table                                                      */
/* ═══════════════════════════════════════════════════════════════════════════ */

void tt_alloc(TTable *tt, int size_mb) {
    tt->count = (size_mb * 1024 * 1024) / (int)sizeof(TTEntry);
    /* Round down to power of 2 */
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
    /* Always-replace strategy (simple, effective for PoC) */
    e->key       = key;
    e->depth     = depth;
    e->score     = score;
    e->flag      = flag;
    e->best_move = best;
}

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Move ordering                                                            */
/* ═══════════════════════════════════════════════════════════════════════════ */

/* MVV-LVA: Most Valuable Victim - Least Valuable Attacker */
static const int MVV_LVA[6][6] = {
    /* victim → P   N    B    R    Q    K   */
    /* P */  { 105, 205, 305, 405, 505, 605 },
    /* N */  { 104, 204, 304, 404, 504, 604 },
    /* B */  { 103, 203, 303, 403, 503, 603 },
    /* R */  { 102, 202, 302, 402, 502, 602 },
    /* Q */  { 101, 201, 301, 401, 501, 601 },
    /* K */  { 100, 200, 300, 400, 500, 600 },
};

/* Killer moves: 2 slots per ply */
static Move killers[MAX_PLY][2];

/* History heuristic: [color][from][to] */
static int history[2][64][64];

static int move_score(Move m, Move tt_move, int ply, Color side) {
    /* TT move always first */
    if (m == tt_move) return 10000000;

    /* Captures: MVV-LVA */
    if (MOVE_IS_CAPTURE(m)) {
        return 1000000 + MVV_LVA[MOVE_PIECE(m)][MOVE_CAPTURED(m)];
    }

    /* Killer moves */
    if (m == killers[ply][0]) return 900000;
    if (m == killers[ply][1]) return 899000;

    /* History heuristic */
    return history[side][MOVE_FROM(m)][MOVE_TO(m)];
}

static void order_moves(MoveList *ml, Move tt_move, int ply, Color side) {
    int scores[MAX_MOVES];
    for (int i = 0; i < ml->count; i++) {
        scores[i] = move_score(ml->moves[i], tt_move, ply, side);
    }
    /* Insertion sort (fast for small arrays) */
    for (int i = 1; i < ml->count; i++) {
        Move  m = ml->moves[i];
        int   s = scores[i];
        int   j = i - 1;
        while (j >= 0 && scores[j] < s) {
            ml->moves[j + 1] = ml->moves[j];
            scores[j + 1]    = scores[j];
            j--;
        }
        ml->moves[j + 1] = m;
        scores[j + 1]    = s;
    }
}

static void record_killer(Move m, int ply) {
    if (ply >= MAX_PLY) return;
    if (m != killers[ply][0]) {
        killers[ply][1] = killers[ply][0];
        killers[ply][0] = m;
    }
}

static void record_history(Move m, Color side, int depth) {
    history[side][MOVE_FROM(m)][MOVE_TO(m)] += depth * depth;
}

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Search state                                                             */
/* ═══════════════════════════════════════════════════════════════════════════ */

static TTable  s_tt;
static int     s_nodes;
static bool    s_stopped;
static int64_t s_deadline_ms;  /* wall-clock deadline in ms */
static int     s_skill_level;  /* 0 = easy … 4 = max */

/* Root move scores (for post-search randomisation) */
static Move    s_root_moves[MAX_MOVES];
static int     s_root_scores[MAX_MOVES];
static int     s_root_count;

static void check_time(void) {
    if ((s_nodes & 4095) == 0) {
        if (s_nodes > MAX_NODES || time_ms_now() >= s_deadline_ms)
            s_stopped = true;
    }
}

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Quiescence search                                                        */
/* ═══════════════════════════════════════════════════════════════════════════ */

static int quiescence(Board *b, int alpha, int beta, int ply, int qply) {
    s_nodes++;
    check_time();
    if (s_stopped) return 0;

    /* Hard ply limit — prevents stack overflow from long check sequences */
    if (ply >= MAX_PLY + MAX_QPLY) return evaluate(b);
    /* Mercenary: scale q-depth by skill level for difficulty differentiation.
       Easy gets shallow tactics (3), higher levels cap at 8 so main search
       can go deeper where it matters most for strategic play. */
    if (b->mod == MOD_MERCENARY) {
        static const int Q_LIMITS[] = {3, 4, 6, 8, 8};
        if (qply >= Q_LIMITS[s_skill_level]) return evaluate(b);
    }

    bool in_check = board_in_check(b, b->side);

    /* If in check, we must search all evasions */
    if (in_check) {
        MoveList ml;
        generate_moves(b, &ml);
        if (ml.count == 0) return -(MATE_SCORE - ply);

        order_moves(&ml, MOVE_NONE, ply < MAX_PLY ? ply : MAX_PLY - 1, b->side);
        for (int i = 0; i < ml.count; i++) {
            board_make_move(b, ml.moves[i]);
            int score = -quiescence(b, -beta, -alpha, ply + 1, qply + 1);
            board_unmake_move(b);
            if (s_stopped) return 0;
            if (score >= beta) return beta;
            if (score > alpha) alpha = score;
        }
        return alpha;
    }

    /* Stand pat */
    int stand_pat = evaluate(b);
    if (stand_pat >= beta) return beta;
    if (stand_pat > alpha) alpha = stand_pat;

    /* Search only captures */
    MoveList ml;
    generate_captures(b, &ml);
    order_moves(&ml, MOVE_NONE, ply < MAX_PLY ? ply : MAX_PLY - 1, b->side);

    for (int i = 0; i < ml.count; i++) {
        /* Delta pruning: skip captures that can't raise alpha */
        int see_val = SEE_VAL[MOVE_CAPTURED(ml.moves[i])];
        if (b->mod == MOD_MERCENARY && MOVE_CAPTURED(ml.moves[i]) == PAWN)
            see_val = 180; /* Mercenary pawns are worth more */
        if (stand_pat + see_val + 200 < alpha)
            continue;

        board_make_move(b, ml.moves[i]);
        int score = -quiescence(b, -beta, -alpha, ply + 1, qply + 1);
        board_unmake_move(b);
        if (s_stopped) return 0;
        if (score >= beta) return beta;
        if (score > alpha) alpha = score;
    }
    return alpha;
}

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Alpha-Beta (interior nodes)                                              */
/* ═══════════════════════════════════════════════════════════════════════════ */

static int alpha_beta(Board *b, int depth, int alpha, int beta,
                      int ply, bool do_null) {
    check_time();
    if (s_stopped) return 0;
    s_nodes++;

    /* Hard ply limit — fall into quiescence evaluation */
    if (ply >= MAX_PLY) return evaluate(b);

    /* Leaf → quiescence */
    if (depth <= 0) return quiescence(b, alpha, beta, ply, 0);

    /* TT probe */
    uint64_t hash = b->hash;
    TTEntry *tte = tt_probe(&s_tt, hash);
    Move tt_move = MOVE_NONE;
    if (tte && tte->depth >= depth) {
        if (tte->flag == TT_EXACT)                         return tte->score;
        if (tte->flag == TT_LOWER && tte->score >= beta)   return tte->score;
        if (tte->flag == TT_UPPER && tte->score <= alpha)  return tte->score;
    }
    if (tte) tt_move = tte->best_move;

    bool in_check = board_in_check(b, b->side);

    /* Null-move pruning (skip for Mercenary: too tactical with all-directional pawns,
       skip when in check, few pieces, or after a null) */
    if (do_null && !in_check && depth >= 3 && ply > 0
        && b->mod != MOD_MERCENARY) {
        Color us = b->side;
        if (b->pieces[us][QUEEN] || b->pieces[us][ROOK]) {
            b->side = color_opposite(b->side);
            Square old_ep = b->ep_square;
            b->ep_square = SQ_NONE;

            /* do_null = false → no consecutive null moves */
            int null_score = -alpha_beta(b, depth - 3, -beta, -beta + 1,
                                         ply + 1, false);

            b->side = color_opposite(b->side);
            b->ep_square = old_ep;

            if (s_stopped) return 0;
            if (null_score >= beta && !is_mate(null_score)) return beta;
        }
    }

    /* ── Mate distance pruning ────────────────────────────────────────── */
    {
        int mate_alpha = -(MATE_SCORE - ply);
        int mate_beta  =  (MATE_SCORE - ply - 1);
        if (alpha < mate_alpha) alpha = mate_alpha;
        if (beta  > mate_beta)  beta  = mate_beta;
        if (alpha >= beta) return alpha;
    }

    /* Static eval for pruning decisions */
    int static_eval = 0;
    bool do_futility = false;
    if (!in_check && depth <= 3 && !is_mate(alpha) && !is_mate(beta)) {
        static_eval = evaluate(b);
        /* Reverse futility pruning (static null move) — only with safe margin
           Skip for Mercenary: positions change too rapidly with king-like pawns */
        if (depth <= 2 && b->mod != MOD_MERCENARY
            && static_eval - 120 * depth >= beta)
            return static_eval;
        /* Futility: also skip for Mercenary */
        do_futility = (b->mod != MOD_MERCENARY
                       && depth <= 2 && static_eval + 150 * depth <= alpha);
    }

    /* Generate all legal moves */
    MoveList ml;
    generate_moves(b, &ml);

    if (ml.count == 0) {
        return in_check ? -(MATE_SCORE - ply) : 0;
    }

    order_moves(&ml, tt_move, ply, b->side);

    int original_alpha = alpha;
    int best_score = -INFINITY_SCORE;
    Move best_move = MOVE_NONE;

    for (int i = 0; i < ml.count; i++) {
        Move m = ml.moves[i];

        board_make_move(b, m);

        /* Check extension: +1 depth when this move gives check */
        int ext = board_in_check(b, b->side) ? 1 : 0;
        int new_depth = depth - 1 + ext;

        /* Futility pruning: skip late quiet moves at shallow depths,
           but NEVER prune moves that give check (ext > 0). */
        if (do_futility && i > 0 && ext == 0 &&
            !MOVE_IS_CAPTURE(m) && !MOVE_IS_PROMO(m)) {
            board_unmake_move(b);
            continue;
        }
        int score;

        if (i == 0) {
            /* PV node: full window */
            score = -alpha_beta(b, new_depth, -beta, -alpha, ply + 1, true);
        } else {
            /* Late Move Reductions */
            int reduction = 0;
            if (i >= 4 && depth >= 3 && ext == 0 &&
                !MOVE_IS_CAPTURE(m) && !MOVE_IS_PROMO(m) && !in_check) {
                reduction = 1;
                /* Less aggressive in Mercenary (many pawn moves are tactical) */
                if (i >= 8 && b->mod != MOD_MERCENARY) reduction = 2;
            }

            /* PVS: null-window search with possible reduction */
            score = -alpha_beta(b, new_depth - reduction,
                                -(alpha + 1), -alpha, ply + 1, true);

            /* Re-search at full depth if reduced search looks promising */
            if (score > alpha && reduction > 0)
                score = -alpha_beta(b, new_depth,
                                    -(alpha + 1), -alpha, ply + 1, true);

            /* Re-search with full window if within bounds */
            if (score > alpha && score < beta)
                score = -alpha_beta(b, new_depth, -beta, -alpha, ply + 1, true);
        }

        board_unmake_move(b);

        if (s_stopped) return 0;

        if (score > best_score) {
            best_score = score;
            best_move = m;
        }
        if (score > alpha) alpha = score;
        if (alpha >= beta) {
            if (!MOVE_IS_CAPTURE(m)) {
                record_killer(m, ply);
                record_history(m, b->side, depth);
            }
            break;
        }
    }

    /* Store in TT */
    TTFlag flag;
    if (best_score <= original_alpha)  flag = TT_UPPER;
    else if (best_score >= beta)       flag = TT_LOWER;
    else                               flag = TT_EXACT;
    tt_store(&s_tt, hash, depth, best_score, flag, best_move);

    return best_score;
}

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Root search (iterative deepening)                                        */
/* ═══════════════════════════════════════════════════════════════════════════ */

SearchResult search_think(Board *b, int time_ms, int max_depth, int skill_level) {
    /* Initialize */
    zobrist_init();
    if (s_tt.entries == NULL) tt_alloc(&s_tt, 16); /* 16 MB TT */

    s_nodes = 0;
    s_stopped = false;
    s_deadline_ms = time_ms_now() + (int64_t)time_ms;
    s_skill_level = (skill_level < 0) ? 0 : (skill_level > 4 ? 4 : skill_level);
    s_rng = b->hash ^ (uint64_t)time_ms_now(); /* seed PRNG */
    s_root_count = 0;

    memset(killers, 0, sizeof(killers));
    memset(history, 0, sizeof(history));

    int depth_limit = (max_depth > 0 && max_depth < MAX_PLY) ? max_depth : MAX_PLY;

    SearchResult result;
    result.best_move = MOVE_NONE;
    result.score     = 0;
    result.depth     = 0;
    result.nodes     = 0;

    /* Temp arrays for root move scores during current iteration.
       Only committed to the global s_root_* arrays after a COMPLETE
       iteration, preventing contamination when time aborts mid-depth. */
    Move tmp_root_moves[MAX_MOVES];
    int  tmp_root_scores[MAX_MOVES];

    for (int depth = 1; depth <= depth_limit; depth++) {
        /* Root alpha-beta */
        MoveList ml;
        generate_moves(b, &ml);
        if (ml.count == 0) break;

        /* Order root moves */
        order_moves(&ml, result.best_move, 0, b->side);

        int alpha = -INFINITY_SCORE;
        int beta  =  INFINITY_SCORE;
        Move best = MOVE_NONE;
        int best_score = -INFINITY_SCORE;

        for (int i = 0; i < ml.count; i++) {
            board_make_move(b, ml.moves[i]);
            int ext = board_in_check(b, b->side) ? 1 : 0;
            int score;

            if (i == 0) {
                score = -alpha_beta(b, depth - 1 + ext, -beta, -alpha, 1, true);
            } else {
                /* PVS at root */
                score = -alpha_beta(b, depth - 1 + ext,
                                    -(alpha + 1), -alpha, 1, true);
                if (score > alpha && score < beta)
                    score = -alpha_beta(b, depth - 1 + ext,
                                        -beta, -alpha, 1, true);
            }
            board_unmake_move(b);

            if (s_stopped) goto done;

            /* Store in temp arrays (NOT global yet) */
            tmp_root_moves[i] = ml.moves[i];
            tmp_root_scores[i] = score;

            if (score > best_score) {
                best_score = score;
                best = ml.moves[i];
            }
            if (score > alpha) alpha = score;
        }

        /* ── This depth completed successfully ── */
        /* Commit temp root scores to globals */
        for (int i = 0; i < ml.count; i++) {
            s_root_moves[i]  = tmp_root_moves[i];
            s_root_scores[i] = tmp_root_scores[i];
        }
        s_root_count = ml.count;

        /* Completed this depth */
        result.best_move = best;
        result.score     = best_score;
        result.depth     = depth;
        result.nodes     = s_nodes;

        /* Stop early on forced mate */
        if (is_mate(best_score)) break;
    }

done:
    /* ── Skill-based + opening randomisation ──────────────────────────── */
    if (s_root_count > 1 && !is_mate(result.score)) {
        /* Noise width based on skill level — Maximum has ZERO noise.
           Mercenary uses scaled noise: pawns are 180cp vs 100cp. */
        static const int SKILL_NOISE[]      = { 200, 100, 40, 10, 0 };
        static const int SKILL_NOISE_MERC[] = { 350, 150, 50, 10, 0 };
        int noise = (b->mod == MOD_MERCENARY) ? SKILL_NOISE_MERC[s_skill_level]
                                              : SKILL_NOISE[s_skill_level];

        /* Opening variety: wider margin in the first ~6 full moves
           Maximum still gets a tiny margin for opening variety only */
        static const int OPEN_MARGIN[]      = { 300, 150, 50, 15, 10 };
        static const int OPEN_MARGIN_MERC[] = { 400, 180, 60, 15, 10 };
        int open_margin = 0;
        if (b->fullmove <= 6) {
            open_margin = (b->mod == MOD_MERCENARY) ? OPEN_MARGIN_MERC[s_skill_level]
                                                    : OPEN_MARGIN[s_skill_level];
            /* Taper: more variety in very early moves */
            if (b->fullmove > 3)
                open_margin = open_margin * (7 - b->fullmove) / 4;
        }

        int width = noise > open_margin ? noise : open_margin;

        if (width > 0) {
            /* Collect candidates within 'width' centipawns of the best */
            int best_root = -INFINITY_SCORE;
            for (int i = 0; i < s_root_count; i++)
                if (s_root_scores[i] > best_root) best_root = s_root_scores[i];

            Move cands[MAX_MOVES];
            int  cand_scores[MAX_MOVES];
            int  cand_n = 0;
            for (int i = 0; i < s_root_count; i++) {
                if (best_root - s_root_scores[i] <= width) {
                    cands[cand_n] = s_root_moves[i];
                    cand_scores[cand_n] = s_root_scores[i];
                    cand_n++;
                }
            }
            if (cand_n > 0) {
                int pick = rng_range(cand_n);
                result.best_move = cands[pick];
                result.score     = cand_scores[pick];
            }
        }
    }

    return result;
}
