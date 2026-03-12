#ifndef CHESS_EVALUATE_H
#define CHESS_EVALUATE_H

#include "board.h"

/* Evaluate the position from the side-to-move's perspective.
   Positive = good for side to move.  Values in centipawns. */
int evaluate(const Board *b);

#endif /* CHESS_EVALUATE_H */
