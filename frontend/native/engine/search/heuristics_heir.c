#include "variant_heuristics.h"
#include <stdlib.h>

static inline int chebyshev_distance_sq(Square a, Square b) {
    int dr = abs(SQ_ROW(a) - SQ_ROW(b));
    int dc = abs(SQ_COL(a) - SQ_COL(b));
    return dr > dc ? dr : dc;
}

static int heir_pawn_advance(Color side, Square sq) {
    int advance = (side == WHITE) ? (SQ_ROW(sq) - 1) : (6 - SQ_ROW(sq));
    if (advance < 0) return 0;
    if (advance > 5) return 5;
    return advance;
}

static int heir_developed_minor_count(const Board *b, Color side) {
    int back_rank = (side == WHITE) ? 0 : 7;
    int developed = 0;
    Bitboard minors = b->pieces[side][KNIGHT] | b->pieces[side][BISHOP];

    while (minors) {
        Square sq = (Square)bb_pop_lsb(&minors);
        if (SQ_ROW(sq) != back_rank) developed++;
    }

    return developed;
}

int search_heir_f_pawn_block_move_penalty(const Board *b, Move m) {
    if (b->mod != MOD_HEIR || MOVE_PIECE(m) != KNIGHT) return 0;

    Color side = b->side;
    Square from = MOVE_FROM(m);
    Square to = MOVE_TO(m);
    Square home_from = (side == WHITE) ? SQ(0, 6) : SQ(7, 6);
    Square block_sq = (side == WHITE) ? SQ(2, 5) : SQ(5, 5);
    Square home_f = (side == WHITE) ? SQ(1, 5) : SQ(6, 5);
    Square spear_sq = (side == WHITE) ? SQ(4, 4) : SQ(3, 4);
    Square anchor_sq = (side == WHITE) ? SQ(3, 3) : SQ(4, 3);

    if (b->fullmove > 12) return 0;
    if (from != home_from || to != block_sq) return 0;
    if (!BB_HAS(b->pieces[side][PAWN], home_f)) return 0;
    if (!BB_HAS(b->pieces[side][PAWN], spear_sq)) return 0;

    {
        int penalty = 70;
        if (BB_HAS(b->pieces[side][PAWN], anchor_sq)) penalty += 30;
        return penalty;
    }
}

bool search_heir_position_volatile(const Board *b) {
    for (int c = 0; c < 2; c++) {
        if (b->pieces[c][KING] == BB_EMPTY) return true;
        if (bb_popcount(b->pieces[c][PAWN]) <= 2) return true;

        {
            Bitboard pawns = b->pieces[c][PAWN];
            while (pawns) {
                Square sq = (Square)bb_pop_lsb(&pawns);
                if (heir_pawn_advance((Color)c, sq) >= 4) return true;
            }
        }
    }

    return false;
}

bool search_heir_critical_move(const Board *b, Move m) {
    if (b->mod != MOD_HEIR) return false;
    if (MOVE_IS_PROMO(m) || MOVE_CAPTURED(m) == KING) return true;
    if (MOVE_PIECE(m) == KING) return true;

    if (MOVE_PIECE(m) == PAWN && heir_pawn_advance(b->side, MOVE_TO(m)) >= 4) {
        return true;
    }

    return false;
}

bool search_heir_king_under_direct_fire(const Board *b) {
    if (b->mod != MOD_HEIR) return false;
    if (b->pieces[b->side][KING] == BB_EMPTY) return false;
    return board_square_attacked(
        b,
        bb_lsb(b->pieces[b->side][KING]),
        color_opposite(b->side)
    );
}

bool search_heir_tactical_capture(const Board *b, Move m, int see) {
    if (b->mod != MOD_HEIR) return false;
    if (!(MOVE_IS_CAPTURE(m) || MOVE_IS_EP(m))) return false;
    if (see < 0) return false;

    {
        PieceType captured = MOVE_CAPTURED(m);
        Square to = MOVE_TO(m);
        bool central = SQ_ROW(to) >= 2 && SQ_ROW(to) <= 5 &&
                       SQ_COL(to) >= 2 && SQ_COL(to) <= 5;

        if (captured >= KNIGHT) return true;
        if (captured == PAWN && central) return true;
    }

    return false;
}

int search_heir_early_queen_sortie_penalty(const Board *b, Move m) {
    if (b->mod != MOD_HEIR || MOVE_PIECE(m) != QUEEN) return 0;

    {
        Color side = b->side;
        Color opp = color_opposite(side);
        int back_rank = (side == WHITE) ? 0 : 7;
        int minor_total = bb_popcount(b->pieces[side][KNIGHT] | b->pieces[side][BISHOP]);
        int minor_developed = heir_developed_minor_count(b, side);
        int undeveloped = minor_total - minor_developed;
        int penalty;

        if (b->fullmove > 12) return 0;
        if (SQ_ROW(MOVE_FROM(m)) != back_rank || SQ_ROW(MOVE_TO(m)) == back_rank) return 0;
        if (bb_popcount(b->pieces[side][PAWN]) < 4 || bb_popcount(b->pieces[opp][PAWN]) < 4) return 0;
        if (undeveloped <= 0) return 0;

        penalty = 120 + undeveloped * 30;
        if (minor_developed == 0) penalty += 40;
        else if (minor_developed == 1) penalty += 20;
        return penalty;
    }
}

bool search_heir_is_tactical_capture_candidate(const Board *b, Move m) {
    PieceType captured = MOVE_CAPTURED(m);
    Square to = MOVE_TO(m);
    bool central = SQ_ROW(to) >= 2 && SQ_ROW(to) <= 5 &&
                   SQ_COL(to) >= 2 && SQ_COL(to) <= 5;

    if (b->mod != MOD_HEIR) return false;
    if (!(MOVE_IS_CAPTURE(m) || MOVE_IS_EP(m))) return false;
    if (MOVE_IS_PROMO(m)) return true;
    if (captured >= KNIGHT) return true;
    if (captured == PAWN && central) return true;
    if (MOVE_PIECE(m) == PAWN && heir_pawn_advance(b->side, MOVE_TO(m)) >= 4) return true;
    return false;
}
