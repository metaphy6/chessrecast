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
            /* Captures */
            Bitboard caps = targets & b->occupied[them];
            while (caps) {
                Square to = (Square)bb_pop_lsb(&caps);
                PieceType capt = PIECE_TYPE(b->mailbox[to]);
                if (capt == KING) continue; /* can't capture king directly */
                movelist_add(ml, move_capture(sq, to, PAWN, capt));
            }
            continue; /* next pawn */
        }

        /* ── Standard pawn logic ────────────────────────────────────────── */
        bool on_promo_rank = (r == rank7);

        /* Single push */
        Square one = SQ(r + dir, c);
        if (!captures_only && SQ_VALID(one) && b->mailbox[one] == PIECE_EMPTY) {
            if (on_promo_rank) {
                PieceType promos[] = {QUEEN, ROOK, BISHOP, KNIGHT};
                for (int i = 0; i < 4; i++)
                    movelist_add(ml, move_encode(sq, one, PAWN, PIECE_NONE,
                                                 false, false, true, promos[i]));
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
        for (int dc = -1; dc <= 1; dc += 2) {
            int nc = c + dc;
            if (nc < 0 || nc > 7) continue;
            Square to = SQ(r + dir, nc);
            if (!SQ_VALID(to)) continue;

            Piece target = b->mailbox[to];
            if (target != PIECE_EMPTY && PIECE_COLOR(target) == them) {
                PieceType capt = PIECE_TYPE(target);
                if (capt == KING) continue;
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
    }
}

static void gen_piece_moves(const Board *b, MoveList *ml,
                            PieceType pt, bool captures_only) {
    Color us   = b->side;
    Color them = color_opposite(us);
    Bitboard pcs = b->pieces[us][pt];

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

        /* Remove friendly pieces */
        targets &= ~b->occupied[us];

        if (captures_only) {
            targets &= b->occupied[them];
        }

        while (targets) {
            Square to = (Square)bb_pop_lsb(&targets);
            Piece target = b->mailbox[to];
            if (target != PIECE_EMPTY) {
                PieceType capt = PIECE_TYPE(target);
                if (capt == KING) continue; /* can't capture king */
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

    Color us = b->side;
    if (board_in_check(b, us)) return;

    if (us == WHITE) {
        /* Kingside */
        if ((b->castling & CASTLE_WK) &&
            b->mailbox[SQ(0, 5)] == PIECE_EMPTY &&
            b->mailbox[SQ(0, 6)] == PIECE_EMPTY &&
            !board_square_attacked(b, SQ(0, 5), BLACK) &&
            !board_square_attacked(b, SQ(0, 6), BLACK)) {
            movelist_add(ml, move_encode(SQ(0, 4), SQ(0, 6), KING,
                                         PIECE_NONE, true, false, false, PIECE_NONE));
        }
        /* Queenside */
        if ((b->castling & CASTLE_WQ) &&
            b->mailbox[SQ(0, 1)] == PIECE_EMPTY &&
            b->mailbox[SQ(0, 2)] == PIECE_EMPTY &&
            b->mailbox[SQ(0, 3)] == PIECE_EMPTY &&
            !board_square_attacked(b, SQ(0, 2), BLACK) &&
            !board_square_attacked(b, SQ(0, 3), BLACK)) {
            movelist_add(ml, move_encode(SQ(0, 4), SQ(0, 2), KING,
                                         PIECE_NONE, true, false, false, PIECE_NONE));
        }
    } else {
        /* Black kingside */
        if ((b->castling & CASTLE_BK) &&
            b->mailbox[SQ(7, 5)] == PIECE_EMPTY &&
            b->mailbox[SQ(7, 6)] == PIECE_EMPTY &&
            !board_square_attacked(b, SQ(7, 5), WHITE) &&
            !board_square_attacked(b, SQ(7, 6), WHITE)) {
            movelist_add(ml, move_encode(SQ(7, 4), SQ(7, 6), KING,
                                         PIECE_NONE, true, false, false, PIECE_NONE));
        }
        /* Black queenside */
        if ((b->castling & CASTLE_BQ) &&
            b->mailbox[SQ(7, 1)] == PIECE_EMPTY &&
            b->mailbox[SQ(7, 2)] == PIECE_EMPTY &&
            b->mailbox[SQ(7, 3)] == PIECE_EMPTY &&
            !board_square_attacked(b, SQ(7, 2), WHITE) &&
            !board_square_attacked(b, SQ(7, 3), WHITE)) {
            movelist_add(ml, move_encode(SQ(7, 4), SQ(7, 2), KING,
                                         PIECE_NONE, true, false, false, PIECE_NONE));
        }
    }
}

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Legality filter                                                          */
/* ═══════════════════════════════════════════════════════════════════════════ */

static bool is_legal(Board *b, Move m) {
    board_make_move(b, m);
    /* After making 'm', the side that moved is now the opponent.
       Check if OUR king (the mover's king) is in check. */
    bool legal = !board_in_check(b, color_opposite(b->side));
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
