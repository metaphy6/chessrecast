#ifndef EVAL_TYPES_H
#define EVAL_TYPES_H

#include "../board.h"
#include <stdlib.h>  /* abs() */

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Evaluation context: shared state passed between eval stages              */
/* ═══════════════════════════════════════════════════════════════════════════ */

typedef struct {
    int       score;                /* accumulated evaluation (white POV) */
    int       material[2];
    int       non_pawn_material[2];
    int       pawn_count[2];
    int       bishop_count[2];
    int       king_sq[2];
    int       queen_sq[2];
    Bitboard  pawn_atk[2];
    int       phase;
    int       mg_weight;
    int       eg_weight;
} EvalContext;

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Common inline helpers (shared by all eval modules)                       */
/* ═══════════════════════════════════════════════════════════════════════════ */

static inline int mirror(int sq) { return sq ^ 56; }

static inline int chebyshev_distance_sq(int a, int b) {
    int dr = abs(SQ_ROW(a) - SQ_ROW(b));
    int dc = abs(SQ_COL(a) - SQ_COL(b));
    return dr > dc ? dr : dc;
}

static inline int distance_from_center_sq(int sq) {
    int row = SQ_ROW(sq);
    int col = SQ_COL(sq);
    int row_dist = (row < 4) ? (3 - row) : (row - 4);
    int col_dist = (col < 4) ? (3 - col) : (col - 4);
    return row_dist + col_dist;
}

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Common data (defined in eval_common.c)                                   */
/* ═══════════════════════════════════════════════════════════════════════════ */

extern const int MATERIAL[6];
extern const int PST_PAWN[64];
extern const int PST_KNIGHT[64];
extern const int PST_BISHOP[64];
extern const int PST_ROOK[64];
extern const int PST_QUEEN[64];
extern const int PST_KING_MG[64];
extern const int PST_KING_EG[64];
extern const int *PST_TABLE[6];

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Mod-specific PSTs (defined in per-mod eval files)                        */
/* ═══════════════════════════════════════════════════════════════════════════ */

extern const int PST_MERC_PAWN[64];       /* eval_mercenary.c */
extern const int PST_HEIR_PAWN[64];       /* eval_heir.c */
extern const int PST_TRUCE_PAWN[64];      /* eval_truce.c */
extern const int PST_TRUCE_KNIGHT[64];    /* eval_truce.c */
extern const int PST_TRUCE_BISHOP[64];    /* eval_truce.c */
extern const int PST_KB_KING_P1[64];      /* eval_kings_battle.c */
extern const int PST_KB_PAWN_P1[64];      /* eval_kings_battle.c */

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Common eval stage functions (eval_common.c)                              */
/* ═══════════════════════════════════════════════════════════════════════════ */

void eval_common_init(const Board *b, EvalContext *ctx);
int  eval_common_finish(const Board *b, const EvalContext *ctx);

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Per-mod eval functions (return mod-specific score contribution)           */
/* ═══════════════════════════════════════════════════════════════════════════ */

int eval_mercenary(const Board *b, const EvalContext *ctx);
int eval_heir(const Board *b, const EvalContext *ctx);
int eval_friendly_fire(const Board *b, const EvalContext *ctx);
int eval_truce(const Board *b, const EvalContext *ctx);
int eval_kings_battle(const Board *b, const EvalContext *ctx);
int eval_save_queen(const Board *b, const EvalContext *ctx);
int eval_succession(const Board *b, const EvalContext *ctx);

#endif /* EVAL_TYPES_H */
