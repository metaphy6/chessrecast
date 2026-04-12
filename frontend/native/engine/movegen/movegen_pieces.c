#include "movegen_internal.h"

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Non-pawn piece move generation                                           */
/* ═══════════════════════════════════════════════════════════════════════════ */

void gen_piece_moves(const Board *b, MoveList *ml,
                     PieceType pt, bool captures_only) {
    Color us   = b->side;
    Color them = color_opposite(us);

    /* King's Battle Phase 1: only kings can move (not N/B/R/Q) */
    if (b->mod == MOD_KINGS_BATTLE && !b->kb_unlocked && pt != KING)
        return;

    Bitboard pcs = b->pieces[us][pt];
    /* Remove pieces that have already moved during truce (1 move each) */
    if (b->mod == MOD_TRUCE && b->truce_active) pcs &= ~b->truce_frozen;

    while (pcs) {
        Square sq = (Square)bb_pop_lsb(&pcs);
        Bitboard targets = BB_EMPTY;

        switch (pt) {
            case KNIGHT:
                targets = knight_attacks[sq];
                break;
            case BISHOP:
                targets = bishop_attacks_calc(sq, b->all);
                break;
            case ROOK:
                targets = rook_attacks_calc(sq, b->all);
                break;
            case QUEEN:
                targets = bishop_attacks_calc(sq, b->all) |
                          rook_attacks_calc(sq, b->all);
                break;
            case KING:
                targets = king_attacks[sq];
                break;
            default:
                break;
        }

        /* ── Save the Queen: special queen movement rules ──────────────── */
        if (b->mod == MOD_SAVE_QUEEN && pt == QUEEN) {
            bool own_half = stq_is_own_half(sq, us);

            if (!own_half) {
                /* PRISONER: king-like moves to empty squares only */
                if (!captures_only) {
                    Bitboard quiet = king_attacks[sq] & ~b->all;
                    while (quiet) {
                        Square to = (Square)bb_pop_lsb(&quiet);
                        movelist_add(ml, move_simple(sq, to, QUEEN));
                    }
                }
                continue;   /* prisoners never capture */
            }

            /* ESCAPED: full sliding within own half; king-like (quiet) to
               cross back into opponent's half.  Queen-on-queen capture only
               allowed from an adjacent square onto the opponent's prison square. */
            Bitboard half = (us == WHITE) ? 0x00000000FFFFFFFFULL
                                          : 0xFFFFFFFF00000000ULL;
            Bitboard sliding = (bishop_attacks_calc(sq, b->all) |
                                rook_attacks_calc(sq, b->all));
            sliding &= ~b->occupied[us];         /* no self-captures          */
            sliding &= ~b->pieces[them][QUEEN];  /* exclude opp queen via sliding */
            Bitboard own_targets = sliding & half;

            if (captures_only)
                own_targets &= b->occupied[them];

            /* Special: capture opponent's prison queen only if adjacent */
            {
                Bitboard them_pq = b->pieces[them][QUEEN] & half;
                if (them_pq) {
                    Square psq = bb_lsb(them_pq);
                    if (stq_on_prison(psq, them) && (king_attacks[sq] & BB_SQ(psq)))
                        own_targets |= BB_SQ(psq);
                }
            }

            while (own_targets) {
                Square to = (Square)bb_pop_lsb(&own_targets);
                Piece target = b->mailbox[to];
                if (target != PIECE_EMPTY) {
                    PieceType capt = PIECE_TYPE(target);
                    if (capt == KING) continue;
                    movelist_add(ml, move_capture(sq, to, QUEEN, capt));
                } else {
                    movelist_add(ml, move_simple(sq, to, QUEEN));
                }
            }

            /* King-like quiet moves into opponent's half (no captures) */
            if (!captures_only) {
                Bitboard opp_half = ~half;
                Bitboard cross = king_attacks[sq] & ~b->all & opp_half;
                while (cross) {
                    Square to = (Square)bb_pop_lsb(&cross);
                    movelist_add(ml, move_simple(sq, to, QUEEN));
                }
            }

            continue;   /* skip normal target handling */
        }

        /* Remove friendly pieces (Friendly Fire: allow capturing own moved pieces except king) */
        if (b->mod == MOD_FRIENDLY_FIRE) {
            Bitboard uncapturable = (b->occupied[us] & ~b->ff_moved) | b->pieces[us][KING];
            targets &= ~uncapturable;
        } else {
            targets &= ~b->occupied[us];
        }

        /* Heir: king can't move adjacent to or capture opponent king */
        if (pt == KING && b->mod == MOD_HEIR) {
            Bitboard opp_king = b->pieces[them][KING];
            if (opp_king) {
                Square opp_ksq = bb_lsb(opp_king);
                targets &= ~king_attacks[opp_ksq]; /* no adjacent squares */
                targets &= ~BB_SQ(opp_ksq);        /* can't capture king  */
            }
        }

        /* King's Battle Phase 1: king can't capture the opponent king */
        if (pt == KING && b->mod == MOD_KINGS_BATTLE && !b->kb_unlocked) {
            targets &= ~b->pieces[them][KING];
        }

        /* Truce: remove opponent pieces from targets (no captures during truce) */
        if (b->mod == MOD_TRUCE && b->truce_active) {
            targets &= ~b->occupied[them];
        }

        if (captures_only) {
            if (b->mod == MOD_FRIENDLY_FIRE) {
                /* Include both enemy captures and friendly captures */
                Bitboard ff_cap = b->occupied[us] & b->ff_moved & ~b->pieces[us][KING];
                targets &= (b->occupied[them] | ff_cap);
            } else {
                targets &= b->occupied[them];
            }
        }

        while (targets) {
            Square to = (Square)bb_pop_lsb(&targets);
            Piece target = b->mailbox[to];
            if (target != PIECE_EMPTY) {
                PieceType capt = PIECE_TYPE(target);
                /* Heir: non-king pieces CAN capture kings; standard: never */
                if (capt == KING) {
                    if (b->mod != MOD_HEIR || pt == KING) continue;
                }
                /* Save the Queen: prisoner queen capture is legal only when
                   the prison square is empty (otherwise prisoner stays protected). */
                if (b->mod == MOD_SAVE_QUEEN && capt == QUEEN &&
                    !stq_is_own_half(to, them)) {
                    Square prison_sq = (them == WHITE) ? STQ_WHITE_PRISON : STQ_BLACK_PRISON;
                    if (b->mailbox[prison_sq] != PIECE_EMPTY) continue;
                }
                movelist_add(ml, move_capture(sq, to, pt, capt));
            } else {
                movelist_add(ml, move_simple(sq, to, pt));
            }
        }
    }
}

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Castling move generation                                                 */
/* ═══════════════════════════════════════════════════════════════════════════ */

void gen_castling(const Board *b, MoveList *ml) {
    if (b->mod == MOD_MERCENARY) {
        /* Castling is still allowed in Mercenary mod */
    }

    /* King's Battle Phase 1: no castling (rooks are locked) */
    if (b->mod == MOD_KINGS_BATTLE && !b->kb_unlocked) return;

    Color us = b->side;
    /* Truce: king frozen = can't castle */
    if (b->mod == MOD_TRUCE && b->truce_active) {
        Square ksq = bb_lsb(b->pieces[us][KING]);
        if (b->truce_frozen & BB_SQ(ksq)) return;
    }
    /* Heir: can castle even while in "check" when check rules don't apply */
    bool need_check_safe = true;
    if (b->mod == MOD_HEIR && !heir_check_applies(b, us))
        need_check_safe = false;
    /* Truce: no check during truce, so castling doesn't need check safety */
    if (b->mod == MOD_TRUCE && b->truce_active)
        need_check_safe = false;

    if (need_check_safe && board_in_check(b, us)) return;

    if (us == WHITE) {
        /* Kingside */
        if ((b->castling & CASTLE_WK) &&
            b->mailbox[SQ(0, 5)] == PIECE_EMPTY &&
            b->mailbox[SQ(0, 6)] == PIECE_EMPTY &&
            (!need_check_safe || (
                !board_square_attacked(b, SQ(0, 5), BLACK) &&
                !board_square_attacked(b, SQ(0, 6), BLACK)))) {
            movelist_add(ml, move_encode(SQ(0, 4), SQ(0, 6), KING,
                                         PIECE_NONE, true, false, false, PIECE_NONE));
        }
        /* Queenside */
        if ((b->castling & CASTLE_WQ) &&
            b->mailbox[SQ(0, 1)] == PIECE_EMPTY &&
            b->mailbox[SQ(0, 2)] == PIECE_EMPTY &&
            b->mailbox[SQ(0, 3)] == PIECE_EMPTY &&
            (!need_check_safe || (
                !board_square_attacked(b, SQ(0, 2), BLACK) &&
                !board_square_attacked(b, SQ(0, 3), BLACK)))) {
            movelist_add(ml, move_encode(SQ(0, 4), SQ(0, 2), KING,
                                         PIECE_NONE, true, false, false, PIECE_NONE));
        }
    } else {
        /* Black kingside */
        if ((b->castling & CASTLE_BK) &&
            b->mailbox[SQ(7, 5)] == PIECE_EMPTY &&
            b->mailbox[SQ(7, 6)] == PIECE_EMPTY &&
            (!need_check_safe || (
                !board_square_attacked(b, SQ(7, 5), WHITE) &&
                !board_square_attacked(b, SQ(7, 6), WHITE)))) {
            movelist_add(ml, move_encode(SQ(7, 4), SQ(7, 6), KING,
                                         PIECE_NONE, true, false, false, PIECE_NONE));
        }
        /* Black queenside */
        if ((b->castling & CASTLE_BQ) &&
            b->mailbox[SQ(7, 1)] == PIECE_EMPTY &&
            b->mailbox[SQ(7, 2)] == PIECE_EMPTY &&
            b->mailbox[SQ(7, 3)] == PIECE_EMPTY &&
            (!need_check_safe || (
                !board_square_attacked(b, SQ(7, 2), WHITE) &&
                !board_square_attacked(b, SQ(7, 3), WHITE)))) {
            movelist_add(ml, move_encode(SQ(7, 4), SQ(7, 2), KING,
                                         PIECE_NONE, true, false, false, PIECE_NONE));
        }
    }
}
