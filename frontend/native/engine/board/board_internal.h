#ifndef CHESS_BOARD_INTERNAL_H
#define CHESS_BOARD_INTERNAL_H

#include "../board.h"

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Internal board mutation primitives                                       */
/*  Defined in board.c; used by board/*.c implementation files.              */
/*  Not part of the public board API (not declared in board.h).              */
/* ═══════════════════════════════════════════════════════════════════════════ */

void board_clear(Board *b);
void board_place(Board *b, Square sq, Color c, PieceType t);
void board_remove(Board *b, Square sq);

#endif /* CHESS_BOARD_INTERNAL_H */
