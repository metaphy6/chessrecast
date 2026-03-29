#ifndef CHESS_SEARCH_H
#define CHESS_SEARCH_H

#include "board.h"

/* ── Transposition table ──────────────────────────────────────────────────── */

typedef enum { TT_EXACT, TT_LOWER, TT_UPPER } TTFlag;

typedef struct {
    uint64_t  key;
    int       depth;
    int       score;
    TTFlag    flag;
    Move      best_move;
} TTEntry;

typedef struct {
    TTEntry *entries;
    int      count;     /* number of entries (power of 2) */
    int      mask;      /* count - 1 */
} TTable;

void  tt_alloc(TTable *tt, int size_mb);
void  tt_free(TTable *tt);
void  tt_clear(TTable *tt);
void  search_reset(int clear_tt);

/* ── Search result ────────────────────────────────────────────────────────── */

typedef struct {
    Move best_move;
    int  score;
    int  depth;
    int  nodes;
} SearchResult;

/* ── Search API ───────────────────────────────────────────────────────────── */

/* Run iterative-deepening alpha-beta search.
   time_ms     : hard time limit in milliseconds
   max_depth   : optional maximum depth (0 = no limit)
   skill_level : 0 = easy … 4 = maximum (controls randomisation)
   Returns the best move found. */
SearchResult search_think(Board *b, int time_ms, int max_depth, int skill_level);

#endif /* CHESS_SEARCH_H */
