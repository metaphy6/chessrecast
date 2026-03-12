#ifndef CHESS_MOVEGEN_H
#define CHESS_MOVEGEN_H

#include "board.h"

/* Generate all legal moves for the current side to move. */
void generate_moves(const Board *b, MoveList *ml);

/* Generate only capture moves (for quiescence search). */
void generate_captures(const Board *b, MoveList *ml);

/* Check if the current side has any legal moves. */
bool has_legal_moves(const Board *b);

#endif /* CHESS_MOVEGEN_H */
