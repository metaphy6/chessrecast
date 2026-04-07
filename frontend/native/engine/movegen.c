#include "movegen.h"
#include <string.h>

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Attack tables (declared in board.c, shared here via extern)              */
/* ═══════════════════════════════════════════════════════════════════════════ */

extern Bitboard knight_attacks[64];
extern Bitboard king_attacks[64];
extern Bitboard pawn_attacks[2][64];

/* Sliding attacks (defined in board.c) */
extern Bitboard bishop_attacks_calc(Square sq, Bitboard occ);
extern Bitboard rook_attacks_calc(Square sq, Bitboard occ);

/* Forward declaration (defined in board.c) */
extern bool board_square_attacked(const Board *b, Square sq, Color by);

/* ── Succession: add promotion moves for a pawn push/capture ────────────── */
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
/*  Internal: pseudo-legal move generation                                   */
/* ═══════════════════════════════════════════════════════════════════════════ */

static void gen_pawn_moves(const Board *b, MoveList *ml, bool captures_only) {
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

static void gen_piece_moves(const Board *b, MoveList *ml,
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

static void gen_castling(const Board *b, MoveList *ml) {
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

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Legality filter                                                          */
/* ═══════════════════════════════════════════════════════════════════════════ */

static bool is_legal(Board *b, Move m) {
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

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Public API                                                               */
/* ═══════════════════════════════════════════════════════════════════════════ */

void generate_moves(const Board *b, MoveList *ml) {
    movelist_clear(ml);
    board_init_attacks();  /* ensure knight/king/pawn tables are ready */
    /* We need a mutable copy to test legality */
    Board tmp;
    memcpy(&tmp, b, sizeof(Board));

    MoveList pseudo;
    movelist_clear(&pseudo);

    gen_pawn_moves(b, &pseudo, false);
    gen_piece_moves(b, &pseudo, KNIGHT, false);
    gen_piece_moves(b, &pseudo, BISHOP, false);
    gen_piece_moves(b, &pseudo, ROOK,   false);
    gen_piece_moves(b, &pseudo, QUEEN,  false);
    gen_piece_moves(b, &pseudo, KING,   false);
    gen_castling(b, &pseudo);

    /* Filter legal moves */
    for (int i = 0; i < pseudo.count; i++) {
        if (is_legal(&tmp, pseudo.moves[i])) {
            movelist_add(ml, pseudo.moves[i]);
        }
    }
}

void generate_captures(const Board *b, MoveList *ml) {
    movelist_clear(ml);
    /* Truce: no captures allowed during active truce */
    if (b->mod == MOD_TRUCE && b->truce_active) return;
    board_init_attacks();  /* ensure knight/king/pawn tables are ready */
    Board tmp;
    memcpy(&tmp, b, sizeof(Board));

    MoveList pseudo;
    movelist_clear(&pseudo);

    gen_pawn_moves(b, &pseudo, true);
    gen_piece_moves(b, &pseudo, KNIGHT, true);
    gen_piece_moves(b, &pseudo, BISHOP, true);
    gen_piece_moves(b, &pseudo, ROOK,   true);
    gen_piece_moves(b, &pseudo, QUEEN,  true);
    gen_piece_moves(b, &pseudo, KING,   true);

    for (int i = 0; i < pseudo.count; i++) {
        if (is_legal(&tmp, pseudo.moves[i])) {
            movelist_add(ml, pseudo.moves[i]);
        }
    }
}

bool has_legal_moves(const Board *b) {
    MoveList ml;
    generate_moves(b, &ml);
    return ml.count > 0;
}
