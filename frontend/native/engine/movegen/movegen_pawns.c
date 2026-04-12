#include "movegen_internal.h"

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Succession: add promotion moves for a pawn push/capture                 */
/* ═══════════════════════════════════════════════════════════════════════════ */

static void succ_add_promos(const Board *b, MoveList *ml,
                            Square from, Square to, PieceType capt,
                            Color us) {
    Color them = color_opposite(us);
    bool has_king = (b->pieces[us][KING] != BB_EMPTY);
    /* Count pawns: cost is O(popcount) but only called on promo rank */
    int pawn_count = bb_popcount(b->pieces[us][PAWN]);
    bool is_last_pawn = (pawn_count <= 1);
    bool sq_safe = !board_square_attacked(b, to, them);

    if (is_last_pawn && !has_king) {
        /* Last pawn MUST promote to King (only if square safe) */
        if (sq_safe) {
            movelist_add(ml, move_encode(from, to, PAWN, capt,
                                         false, false, true, KING));
        }
        /* If not safe, no legal promotion → this pawn cannot move here */
        return;
    }

    /* Standard Succession promotions: R, B, N (no Queen — already have 2) */
    PieceType promos[] = {ROOK, BISHOP, KNIGHT};
    for (int i = 0; i < 3; i++)
        movelist_add(ml, move_encode(from, to, PAWN, capt,
                                     false, false, true, promos[i]));

    /* Can also promote to King if no king yet and square is safe */
    if (!has_king && sq_safe) {
        movelist_add(ml, move_encode(from, to, PAWN, capt,
                                     false, false, true, KING));
    }
}

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Pawn move generation                                                     */
/* ═══════════════════════════════════════════════════════════════════════════ */

void gen_pawn_moves(const Board *b, MoveList *ml, bool captures_only) {
    Color us   = b->side;
    Color them = color_opposite(us);
    int   dir  = (us == WHITE) ? 1 : -1;
    int   rank2 = (us == WHITE) ? 1 : 6;
    int   rank7 = (us == WHITE) ? 6 : 1;
    Bitboard pawns = b->pieces[us][PAWN];
    bool truce_no_cap = (b->mod == MOD_TRUCE && b->truce_active);
    bool is_stq = (b->mod == MOD_SAVE_QUEEN);
    bool is_succ = (b->mod == MOD_SUCCESSION);
    /* Remove pawns that have already moved during truce (1 move each) */
    if (truce_no_cap) pawns &= ~b->truce_frozen;

    while (pawns) {
        Square sq = (Square)bb_pop_lsb(&pawns);
        int r = SQ_ROW(sq), c = SQ_COL(sq);

        if (b->mod == MOD_MERCENARY) {
            /* Mercenary: pawns move like kings (one square any direction).
               No promotion, no two-square push, no en passant. */
            Bitboard targets = king_attacks[sq];
            /* Quiet moves */
            if (!captures_only) {
                Bitboard quiet = targets & ~b->all;
                while (quiet) {
                    Square to = (Square)bb_pop_lsb(&quiet);
                    movelist_add(ml, move_simple(sq, to, PAWN));
                }
            }
            /* Captures (suppressed during truce) */
            if (!truce_no_cap) {
            Bitboard caps = targets & b->occupied[them];
            while (caps) {
                Square to = (Square)bb_pop_lsb(&caps);
                PieceType capt = PIECE_TYPE(b->mailbox[to]);
                if (capt == KING) continue; /* can't capture king directly */
                movelist_add(ml, move_capture(sq, to, PAWN, capt));
            }
            } /* end truce_no_cap guard */
            continue; /* next pawn */
        }

        /* ── Standard pawn logic ────────────────────────────────────────── */
        bool on_promo_rank = (r == rank7);
        bool is_heir = (b->mod == MOD_HEIR);

        /* Single push */
        Square one = SQ(r + dir, c);
        if (!captures_only && SQ_VALID(one) && b->mailbox[one] == PIECE_EMPTY) {
            if (on_promo_rank) {
                if (is_heir) {
                    /* Heir: mandatory king promotion when no king and not yet promoted */
                    bool has_king = b->pieces[us][KING] != BB_EMPTY;
                    bool can_promo_king = !b->heir_promoted[us];
                    if (!has_king && can_promo_king) {
                        movelist_add(ml, move_encode(sq, one, PAWN, PIECE_NONE,
                                                     false, false, true, KING));
                    } else {
                        PieceType promos[] = {QUEEN, ROOK, BISHOP, KNIGHT};
                        for (int i = 0; i < 4; i++)
                            movelist_add(ml, move_encode(sq, one, PAWN, PIECE_NONE,
                                                         false, false, true, promos[i]));
                        if (can_promo_king)
                            movelist_add(ml, move_encode(sq, one, PAWN, PIECE_NONE,
                                                         false, false, true, KING));
                    }
                } else if (is_succ) {
                    succ_add_promos(b, ml, sq, one, PIECE_NONE, us);
                } else {
                    PieceType promos[] = {QUEEN, ROOK, BISHOP, KNIGHT};
                    for (int i = (is_stq ? 1 : 0); i < 4; i++)
                        movelist_add(ml, move_encode(sq, one, PAWN, PIECE_NONE,
                                                     false, false, true, promos[i]));
                }
            } else {
                movelist_add(ml, move_simple(sq, one, PAWN));
                /* Double push */
                if (r == rank2) {
                    Square two = SQ(r + 2 * dir, c);
                    if (b->mailbox[two] == PIECE_EMPTY)
                        movelist_add(ml, move_simple(sq, two, PAWN));
                }
            }
        }

        /* Captures */
        /* Captures (suppressed during truce) */
        if (!truce_no_cap) {
        for (int dc = -1; dc <= 1; dc += 2) {
            int nc = c + dc;
            if (nc < 0 || nc > 7) continue;
            Square to = SQ(r + dir, nc);
            if (!SQ_VALID(to)) continue;

            Piece target = b->mailbox[to];
            if (target != PIECE_EMPTY && PIECE_COLOR(target) == them) {
                PieceType capt = PIECE_TYPE(target);
                /* In Heir, pawns CAN capture kings; in other mods they can't */
                if (capt == KING && !is_heir) continue;
                /* Save the Queen: prisoner queen capture is legal only when
                   the prison square is empty (otherwise prisoner stays protected). */
                if (is_stq && capt == QUEEN && !stq_is_own_half(to, them)) {
                    Square prison_sq = (them == WHITE) ? STQ_WHITE_PRISON : STQ_BLACK_PRISON;
                    if (b->mailbox[prison_sq] != PIECE_EMPTY) continue;
                }
                if (on_promo_rank) {
                    if (is_heir) {
                        bool has_king = b->pieces[us][KING] != BB_EMPTY;
                        bool can_promo_king = !b->heir_promoted[us];
                        if (!has_king && can_promo_king) {
                            movelist_add(ml, move_encode(sq, to, PAWN, capt,
                                                         false, false, true, KING));
                        } else {
                            PieceType promos[] = {QUEEN, ROOK, BISHOP, KNIGHT};
                            for (int i = 0; i < 4; i++)
                                movelist_add(ml, move_encode(sq, to, PAWN, capt,
                                                             false, false, true, promos[i]));
                            if (can_promo_king)
                                movelist_add(ml, move_encode(sq, to, PAWN, capt,
                                                             false, false, true, KING));
                        }
                    } else if (is_succ) {
                        succ_add_promos(b, ml, sq, to, capt, us);
                    } else {
                        PieceType promos[] = {QUEEN, ROOK, BISHOP, KNIGHT};
                        for (int i = (is_stq ? 1 : 0); i < 4; i++)
                            movelist_add(ml, move_encode(sq, to, PAWN, capt,
                                                         false, false, true, promos[i]));
                    }
                } else {
                    movelist_add(ml, move_capture(sq, to, PAWN, capt));
                }
            }

            /* Friendly Fire: pawn can capture own moved pieces (except king) diagonally */
            if (b->mod == MOD_FRIENDLY_FIRE &&
                target != PIECE_EMPTY && PIECE_COLOR(target) == us &&
                PIECE_TYPE(target) != KING && BB_HAS(b->ff_moved, to)) {
                PieceType capt = PIECE_TYPE(target);
                if (on_promo_rank) {
                    PieceType promos[] = {QUEEN, ROOK, BISHOP, KNIGHT};
                    for (int i = 0; i < 4; i++)
                        movelist_add(ml, move_encode(sq, to, PAWN, capt,
                                                     false, false, true, promos[i]));
                } else {
                    movelist_add(ml, move_capture(sq, to, PAWN, capt));
                }
            }

            /* En passant */
            if (to == b->ep_square && b->ep_square != SQ_NONE) {
                Square cap_sq = SQ(r, nc);
                if (b->mailbox[cap_sq] != PIECE_EMPTY &&
                    PIECE_COLOR(b->mailbox[cap_sq]) == them) {
                    movelist_add(ml, move_encode(sq, to, PAWN,
                                                 PIECE_TYPE(b->mailbox[cap_sq]),
                                                 false, true, false, PIECE_NONE));
                }
            }
        }
        } /* end truce_no_cap guard for pawn captures */
    }
}
