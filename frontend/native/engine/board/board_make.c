#include "board_internal.h"

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Make / Unmake move                                                       */
/* ═══════════════════════════════════════════════════════════════════════════ */

void board_make_move(Board *b, Move m) {
    /* Save state to undo stack */
    int idx = b->ply;
    b->history[idx].move       = m;
    b->history[idx].castling   = b->castling;
    b->history[idx].ep_square  = b->ep_square;
    b->history[idx].halfmove   = b->halfmove;
    b->history[idx].hash       = b->hash;
    b->history[idx].captured   = PIECE_EMPTY;
    b->history[idx].captured_sq = SQ_NONE;
    b->history[idx].heir_promoted[0] = b->heir_promoted[0];
    b->history[idx].heir_promoted[1] = b->heir_promoted[1];
    b->history[idx].truce_active = b->truce_active;
    b->history[idx].truce_frozen = b->truce_frozen;
    b->history[idx].ff_moved = b->ff_moved;
    b->history[idx].kb_unlocked = b->kb_unlocked;
    b->history[idx].kb_bonus = 0;
    b->history[idx].stq_reprisoned = 0;
    b->history[idx].stq_reprison_sq = SQ_NONE;

    Square from = MOVE_FROM(m);
    Square to   = MOVE_TO(m);
    Color  us   = b->side;
    Color  them = color_opposite(us);
    PieceType pt = MOVE_PIECE(m);

    /* Handle captures */
    if (MOVE_IS_EP(m)) {
        /* En passant: captured pawn is on the same rank as 'from', same col as 'to' */
        Square cap_sq = SQ(SQ_ROW(from), SQ_COL(to));
        b->history[idx].captured    = b->mailbox[cap_sq];
        b->history[idx].captured_sq = cap_sq;
        board_remove(b, cap_sq);
    } else if (MOVE_IS_CAPTURE(m)) {
        Piece captured_piece = b->mailbox[to];

        b->history[idx].captured    = captured_piece;
        b->history[idx].captured_sq = to;

        /* Save the Queen: capturing a prisoner queen sends it back to prison
           when the prison square is empty at capture time. */
        if (b->mod == MOD_SAVE_QUEEN && captured_piece != PIECE_EMPTY &&
            PIECE_TYPE(captured_piece) == QUEEN && !stq_is_own_half(to, them)) {
            Square prison_sq = (them == WHITE) ? STQ_WHITE_PRISON : STQ_BLACK_PRISON;
            if (b->mailbox[prison_sq] == PIECE_EMPTY) {
                b->history[idx].stq_reprisoned = 1;
                b->history[idx].stq_reprison_sq = prison_sq;
            }
        }

        board_remove(b, to);

        if (b->history[idx].stq_reprisoned) {
            board_place(b, b->history[idx].stq_reprison_sq, them, QUEEN);
        }
    }

    /* Move the piece */
    board_remove(b, from);

    if (MOVE_IS_PROMO(m)) {
        PieceType promo_pt = MOVE_PROMO_TYPE(m);
        board_place(b, to, us, promo_pt);
        /* Heir: track pawn-to-king promotion */
        if (b->mod == MOD_HEIR && promo_pt == KING) {
            b->heir_promoted[us] = 1;
        }
        /* Succession: track pawn-to-king promotion (reuse heir_promoted) */
        if (b->mod == MOD_SUCCESSION && promo_pt == KING) {
            b->heir_promoted[us] = 1;
        }
    } else {
        board_place(b, to, us, pt);
    }

    /* Castling: also move the rook */
    if (MOVE_IS_CASTLE(m)) {
        if (to == SQ(0, 6)) {          /* White kingside */
            board_remove(b, SQ(0, 7));
            board_place(b, SQ(0, 5), WHITE, ROOK);
        } else if (to == SQ(0, 2)) {   /* White queenside */
            board_remove(b, SQ(0, 0));
            board_place(b, SQ(0, 3), WHITE, ROOK);
        } else if (to == SQ(7, 6)) {   /* Black kingside */
            board_remove(b, SQ(7, 7));
            board_place(b, SQ(7, 5), BLACK, ROOK);
        } else if (to == SQ(7, 2)) {   /* Black queenside */
            board_remove(b, SQ(7, 0));
            board_place(b, SQ(7, 3), BLACK, ROOK);
        }
    }

    /* Truce: track which current squares now hold pieces that have moved. */
    if (b->mod == MOD_TRUCE && b->truce_active) {
        b->truce_frozen &= ~BB_SQ(from);
        b->truce_frozen |= BB_SQ(to);
        if (MOVE_IS_EP(m)) {
            Square cap_sq = SQ(SQ_ROW(from), SQ_COL(to));
            b->truce_frozen &= ~BB_SQ(cap_sq);
        } else if (MOVE_IS_CAPTURE(m)) {
            b->truce_frozen &= ~BB_SQ(to);
            b->truce_frozen |= BB_SQ(to);
        }
        if (MOVE_IS_CASTLE(m)) {
            if (to == SQ(0, 6))      { b->truce_frozen &= ~BB_SQ(SQ(0,7)); b->truce_frozen |= BB_SQ(SQ(0,5)); }
            else if (to == SQ(0, 2)) { b->truce_frozen &= ~BB_SQ(SQ(0,0)); b->truce_frozen |= BB_SQ(SQ(0,3)); }
            else if (to == SQ(7, 6)) { b->truce_frozen &= ~BB_SQ(SQ(7,7)); b->truce_frozen |= BB_SQ(SQ(7,5)); }
            else if (to == SQ(7, 2)) { b->truce_frozen &= ~BB_SQ(SQ(7,0)); b->truce_frozen |= BB_SQ(SQ(7,3)); }
        }
    }

    /* Friendly Fire: track which squares have pieces that moved */
    if (b->mod == MOD_FRIENDLY_FIRE) {
        b->ff_moved &= ~BB_SQ(from);       /* source square now empty */
        b->ff_moved |= BB_SQ(to);          /* piece at dest has moved */
        if (MOVE_IS_EP(m)) {
            Square cap_sq = SQ(SQ_ROW(from), SQ_COL(to));
            b->ff_moved &= ~BB_SQ(cap_sq); /* captured pawn gone */
        }
        if (MOVE_IS_CASTLE(m)) {
            /* Also mark rook as moved */
            if (to == SQ(0, 6))      { b->ff_moved &= ~BB_SQ(SQ(0,7)); b->ff_moved |= BB_SQ(SQ(0,5)); }
            else if (to == SQ(0, 2)) { b->ff_moved &= ~BB_SQ(SQ(0,0)); b->ff_moved |= BB_SQ(SQ(0,3)); }
            else if (to == SQ(7, 6)) { b->ff_moved &= ~BB_SQ(SQ(7,7)); b->ff_moved |= BB_SQ(SQ(7,5)); }
            else if (to == SQ(7, 2)) { b->ff_moved &= ~BB_SQ(SQ(7,0)); b->ff_moved |= BB_SQ(SQ(7,3)); }
        }
    }

    /* Update castling rights */
    if (pt == KING) {
        if (us == WHITE) b->castling &= ~(CASTLE_WK | CASTLE_WQ);
        else             b->castling &= ~(CASTLE_BK | CASTLE_BQ);
    }
    if (pt == ROOK) {
        if (from == SQ(0, 0)) b->castling &= ~CASTLE_WQ;
        if (from == SQ(0, 7)) b->castling &= ~CASTLE_WK;
        if (from == SQ(7, 0)) b->castling &= ~CASTLE_BQ;
        if (from == SQ(7, 7)) b->castling &= ~CASTLE_BK;
    }
    /* If a rook was captured on its starting square */
    if (to == SQ(0, 0)) b->castling &= ~CASTLE_WQ;
    if (to == SQ(0, 7)) b->castling &= ~CASTLE_WK;
    if (to == SQ(7, 0)) b->castling &= ~CASTLE_BQ;
    if (to == SQ(7, 7)) b->castling &= ~CASTLE_BK;

    /* En passant square */
    b->ep_square = SQ_NONE;
    if (b->mod != MOD_MERCENARY && pt == PAWN) {
        int diff = to - from;
        if (diff == 16 || diff == -16) {
            b->ep_square = SQ((SQ_ROW(from) + SQ_ROW(to)) / 2, SQ_COL(from));
        }
    }

    /* Halfmove clock */
    if (pt == PAWN || MOVE_IS_CAPTURE(m)) {
        b->halfmove = 0;
    } else {
        b->halfmove++;
    }

    /* Full move number */
    if (us == BLACK) b->fullmove++;

    /* King's Battle: detect unlock trigger (King's Kill or promotion in Phase 1) */
    if (b->mod == MOD_KINGS_BATTLE && !b->kb_unlocked) {
        /* King captures a pawn = King's Kill */
        if (pt == KING && MOVE_IS_CAPTURE(m) &&
            PIECE_TYPE(b->history[idx].captured) == PAWN) {
            b->kb_unlocked = 1;
            b->history[idx].kb_bonus = 1;
        }
        /* Pawn promotion also unlocks all pieces */
        if (MOVE_IS_PROMO(m)) {
            b->kb_unlocked = 1;
            b->history[idx].kb_bonus = 1;
        }
    }

    /* Switch side */
    b->side = b->history[idx].kb_bonus ? us : them;
    b->ply++;

    /* Recompute hash */
    b->hash = zobrist_compute(b);
}

void board_unmake_move(Board *b) {
    b->ply--;
    int idx = b->ply;
    Move m = b->history[idx].move;

    Square from = MOVE_FROM(m);
    Square to   = MOVE_TO(m);
    Color  us   = b->history[idx].kb_bonus ? b->side : color_opposite(b->side);
    PieceType pt = MOVE_PIECE(m);

    /* Switch side back */
    b->side = us;

    /* Remove piece from destination */
    board_remove(b, to);

    /* Place original piece back on source */
    board_place(b, from, us, pt);

    /* Save the Queen: remove any prisoner queen that was re-placed at prison. */
    if (b->history[idx].stq_reprisoned &&
        b->history[idx].stq_reprison_sq != SQ_NONE) {
        board_remove(b, b->history[idx].stq_reprison_sq);
    }

    /* Restore captured piece */
    if (b->history[idx].captured != PIECE_EMPTY) {
        Square cap_sq = b->history[idx].captured_sq;
        Piece  cap    = b->history[idx].captured;
        board_place(b, cap_sq, PIECE_COLOR(cap), PIECE_TYPE(cap));
    }

    /* Undo castling rook move */
    if (MOVE_IS_CASTLE(m)) {
        if (to == SQ(0, 6)) {
            board_remove(b, SQ(0, 5));
            board_place(b, SQ(0, 7), WHITE, ROOK);
        } else if (to == SQ(0, 2)) {
            board_remove(b, SQ(0, 3));
            board_place(b, SQ(0, 0), WHITE, ROOK);
        } else if (to == SQ(7, 6)) {
            board_remove(b, SQ(7, 5));
            board_place(b, SQ(7, 7), BLACK, ROOK);
        } else if (to == SQ(7, 2)) {
            board_remove(b, SQ(7, 3));
            board_place(b, SQ(7, 0), BLACK, ROOK);
        }
    }

    /* Restore state */
    b->castling  = b->history[idx].castling;
    b->ep_square = b->history[idx].ep_square;
    b->halfmove  = b->history[idx].halfmove;
    b->hash      = b->history[idx].hash;
    b->heir_promoted[0] = b->history[idx].heir_promoted[0];
    b->heir_promoted[1] = b->history[idx].heir_promoted[1];
    b->truce_active = b->history[idx].truce_active;
    b->truce_frozen = b->history[idx].truce_frozen;
    b->ff_moved = b->history[idx].ff_moved;
    b->kb_unlocked = b->history[idx].kb_unlocked;

    if (us == BLACK) b->fullmove--;
}
