#ifndef CHESS_MOVEGEN_INTERNAL_H
#define CHESS_MOVEGEN_INTERNAL_H

#include "../movegen.h"

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Internal move-generation helpers                                         */
/*  Defined in movegen/*.c; called from the public API in movegen.c.         */
/*  Not part of the public movegen API (not declared in movegen.h).          */
/* ═══════════════════════════════════════════════════════════════════════════ */

void gen_pawn_moves(const Board *b, MoveList *ml, bool captures_only);
void gen_piece_moves(const Board *b, MoveList *ml, PieceType pt, bool captures_only);
void gen_castling(const Board *b, MoveList *ml);
bool is_legal(Board *b, Move m);

#endif /* CHESS_MOVEGEN_INTERNAL_H */
