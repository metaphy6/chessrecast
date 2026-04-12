#include "variant_heuristics.h"
#include <stdlib.h>

int search_truce_undeveloped_minor_count(const Board *b, Color side) {
    if (b->mod != MOD_TRUCE || !b->truce_active) return 0;

    {
        int back_rank = (side == WHITE) ? 0 : 7;
        int undeveloped = 0;
        Bitboard minors = b->pieces[side][KNIGHT] | b->pieces[side][BISHOP];

        while (minors) {
            Square sq = (Square)bb_pop_lsb(&minors);
            if (SQ_ROW(sq) == back_rank) undeveloped++;
        }

        return undeveloped;
    }
}

int search_truce_minor_development_score(const Board *b, Move m, Color side) {
    if (b->mod != MOD_TRUCE || !b->truce_active || MOVE_IS_CAPTURE(m) ||
        MOVE_IS_EP(m) || MOVE_IS_PROMO(m)) {
        return 0;
    }

    {
        PieceType piece = MOVE_PIECE(m);
        int back_rank = (side == WHITE) ? 0 : 7;
        Square from_sq = MOVE_FROM(m);
        Square to_sq = MOVE_TO(m);
        int to_rank = (side == WHITE) ? SQ_ROW(to_sq) : (7 - SQ_ROW(to_sq));
        int undeveloped = search_truce_undeveloped_minor_count(b, side);
        int score = 0;

        if (piece != KNIGHT && piece != BISHOP) return 0;
        if (SQ_ROW(from_sq) != back_rank || SQ_ROW(to_sq) == back_rank) return 0;

        score += (piece == KNIGHT) ? 54 : 38;
        if (undeveloped >= 2) score += 14;
        if (undeveloped >= 3) score += 8;
        if (SQ_COL(to_sq) >= 2 && SQ_COL(to_sq) <= 5) score += 8;
        if (to_rank >= 2) score += 4;

        if (piece == BISHOP) {
            if (to_rank >= 2) score += 16;
            else score -= 20;
        }

        return score;
    }
}

int search_truce_early_queen_sortie_penalty(const Board *b, Move m, Color side) {
    if (b->mod != MOD_TRUCE || !b->truce_active || MOVE_PIECE(m) != QUEEN ||
        MOVE_IS_CAPTURE(m) || MOVE_IS_EP(m) || MOVE_IS_PROMO(m)) {
        return 0;
    }

    {
        int back_rank = (side == WHITE) ? 0 : 7;
        int undeveloped = search_truce_undeveloped_minor_count(b, side);

        if (b->fullmove > 8) return 0;
        if (SQ_ROW(MOVE_FROM(m)) != back_rank || SQ_ROW(MOVE_TO(m)) == back_rank) return 0;
        if (undeveloped <= 1) return 0;

        return 90 + undeveloped * 22;
    }
}

int search_truce_quiet_pawn_score(const Board *b, Move m, Color side) {
    if (b->mod != MOD_TRUCE || !b->truce_active || MOVE_PIECE(m) != PAWN ||
        MOVE_IS_CAPTURE(m) || MOVE_IS_EP(m) || MOVE_IS_PROMO(m)) {
        return 0;
    }

    {
        Square from_sq = MOVE_FROM(m);
        Square to_sq = MOVE_TO(m);
        int from_rank = (side == WHITE) ? SQ_ROW(from_sq) : (7 - SQ_ROW(from_sq));
        int to_rank = (side == WHITE) ? SQ_ROW(to_sq) : (7 - SQ_ROW(to_sq));
        int file = SQ_COL(to_sq);
        int score = 0;
        int attack_row = SQ_ROW(to_sq) + ((side == WHITE) ? 1 : -1);

        if (from_rank != 1) return 0;

        score += 28;
        score += (to_rank >= 3) ? 18 : 8;
        if (file >= 2 && file <= 5) score += 12;

        if (attack_row >= 0 && attack_row < 8) {
            if (file > 0 && BB_HAS(b->pieces[side ^ 1][BISHOP], SQ(attack_row, file - 1))) {
                score += 36;
            }
            if (file < 7 && BB_HAS(b->pieces[side ^ 1][BISHOP], SQ(attack_row, file + 1))) {
                score += 36;
            }
        }

        return score;
    }
}
