#ifndef CHESS_BRIDGE_INTERNAL_H
#define CHESS_BRIDGE_INTERNAL_H

#include "../bridge.h"
#include "../board.h"
#include "../search.h"
#include "../search/variant_heuristics.h"
#include "../movegen.h"
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

#ifdef __ANDROID__
#include <android/log.h>
#define LOGD(...) __android_log_print(ANDROID_LOG_DEBUG, "CHESS_ENGINE", __VA_ARGS__)
#else
static inline int bridge_logging_enabled(void) {
    static int initialized = 0;
    static int enabled = 0;
    if (!initialized) {
        const char *env = getenv("CHESSRECAST_ENGINE_VERBOSE");
        enabled = (env != NULL && env[0] != '\0' && strcmp(env, "0") != 0);
        initialized = 1;
    }
    return enabled;
}
#define LOGD(...) do { \
    if (bridge_logging_enabled()) { \
        fprintf(stderr, __VA_ARGS__); \
    } \
} while(0)
#endif

/* ── Shared globals ──────────────────────────────────────────────────────── */

extern int bridge_verify_nesting;

/* ── Common helpers ──────────────────────────────────────────────────────── */

static inline int clamp_int(int value, int lower, int upper) {
    if (value < lower) return lower;
    if (value > upper) return upper;
    return value;
}

bool bridge_square_has_piece(const Board *board,
                             Square sq, Color side, PieceType piece_type);

Move bridge_find_legal_move(const MoveList *ml,
                            Square from, Square to, PieceType piece_type);

/* ── Engine search (for verify-child calls) ──────────────────────────────── */

SearchResult bridge_engine_search_best_move(Board *board,
                                            int time_ms,
                                            int max_depth,
                                            int skill_level);

/* ── Cross-mod helpers ────────────────────────────────────────────────────── */

int kb_verify_child_score(const Board *root, Move move,
                          int time_ms, int max_depth, int skill_level);

int ff_bridge_center_distance(Square sq);

/* ── Per-mod refine functions ────────────────────────────────────────────── */

SearchResult ff_refine_result(const Board *board,
                              SearchResult raw,
                              int time_ms, int max_depth, int skill_level);

SearchResult kb_refine_phase1_result(const Board *board,
                                     SearchResult raw,
                                     int time_ms, int max_depth, int skill_level);

SearchResult kb_refine_unlocked_result(const Board *board,
                                       SearchResult raw,
                                       int time_ms, int max_depth, int skill_level);

SearchResult heir_refine_queen_sortie_result(const Board *board,
                                             SearchResult raw,
                                             int time_ms, int max_depth, int skill_level);

SearchResult succ_refine_result(const Board *board,
                                SearchResult raw,
                                int time_ms, int max_depth, int skill_level);

SearchResult stq_refine_result(const Board *board,
                               SearchResult raw,
                               int time_ms, int max_depth, int skill_level);

SearchResult mercenary_minor_trade_refine_result(const Board *board,
                                                 SearchResult raw,
                                                 int time_ms,
                                                 int max_depth,
                                                 int skill_level);

SearchResult king_discipline_refine_result(const Board *board,
                                           SearchResult raw,
                                           int time_ms, int max_depth, int skill_level);

#endif /* CHESS_BRIDGE_INTERNAL_H */
