#include "movegen_internal.h"

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Legality filter                                                          */
/* ═══════════════════════════════════════════════════════════════════════════ */

bool is_legal(Board *b, Move m) {
    Color mover = b->side;
    board_make_move(b, m);

    /* Kings Battle: when an unlocking move (king×pawn or promotion) sets
       kb_unlocked = 1, keep it so the legality check sees ALL enemy pieces
       as attackers.  The king must be safe in the post-unlock position
       since the capture activates all opponent pieces immediately. */

    /* The mover's king must remain safe even when a Kings Battle move
       grants a bonus turn and the side to move does not change. */
    bool legal = !board_in_check(b, mover);

    /* Truce: moves that give check to the opponent king are illegal.
       board_in_check returns false during truce, so use direct attack check. */
    if (legal && b->mod == MOD_TRUCE && b->truce_active) {
        Bitboard their_king = b->pieces[color_opposite(mover)][KING];
        if (their_king != BB_EMPTY) {
            Square ksq = bb_lsb(their_king);
            if (board_square_attacked(b, ksq, mover)) {
                legal = false;
            }
        }
    }

    board_unmake_move(b);
    return legal;
}
