#include "board.h"
#include <string.h>

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Low-level board mutation primitives                                      */
/*  (shared with board/*.c files via board/board_internal.h)                 */
/* ═══════════════════════════════════════════════════════════════════════════ */

void board_clear(Board *b) {
    memset(b, 0, sizeof(Board));
    b->ep_square = SQ_NONE;
    b->heir_promoted[0] = 0;
    b->heir_promoted[1] = 0;
    b->truce_active = 0;
    b->truce_frozen = 0;
    b->kb_unlocked = 0;
    for (int sq = 0; sq < 64; sq++) b->mailbox[sq] = PIECE_EMPTY;
}

void board_place(Board *b, Square sq, Color c, PieceType t) {
    Piece p = PIECE_MAKE(c, t);
    b->mailbox[sq] = p;
    BB_SET(b->pieces[c][t], sq);
    BB_SET(b->occupied[c], sq);
    BB_SET(b->all, sq);
}

void board_remove(Board *b, Square sq) {
    Piece p = b->mailbox[sq];
    if (p == PIECE_EMPTY) return;
    Color c = PIECE_COLOR(p);
    PieceType t = PIECE_TYPE(p);
    BB_CLR(b->pieces[c][t], sq);
    BB_CLR(b->occupied[c], sq);
    BB_CLR(b->all, sq);
    b->mailbox[sq] = PIECE_EMPTY;
}

void board_refresh(Board *b) {
    b->occupied[WHITE] = BB_EMPTY;
    b->occupied[BLACK] = BB_EMPTY;
    for (int t = 0; t < 6; t++) {
        b->occupied[WHITE] |= b->pieces[WHITE][t];
        b->occupied[BLACK] |= b->pieces[BLACK][t];
    }
    b->all = b->occupied[WHITE] | b->occupied[BLACK];
    b->hash = zobrist_compute(b);
}

