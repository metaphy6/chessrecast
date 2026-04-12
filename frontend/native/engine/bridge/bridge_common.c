#include "bridge_internal.h"

/* Shared verify-nesting counter (used by KB, Succession, STQ, King Discipline). */
int bridge_verify_nesting = 0;

bool bridge_square_has_piece(const Board *board,
                                    Square sq,
                                    Color side,
                                    PieceType piece_type) {
    Piece piece = board->mailbox[sq];
    return piece != PIECE_EMPTY &&
           PIECE_COLOR(piece) == side &&
           PIECE_TYPE(piece) == piece_type;
}

Move bridge_find_legal_move(const MoveList *ml,
                                   Square from,
                                   Square to,
                                   PieceType piece_type) {
    for (int i = 0; i < ml->count; i++) {
        Move move = ml->moves[i];
        if (MOVE_FROM(move) == from && MOVE_TO(move) == to &&
            MOVE_PIECE(move) == piece_type) {
            return move;
        }
    }
    return MOVE_NONE;
}
