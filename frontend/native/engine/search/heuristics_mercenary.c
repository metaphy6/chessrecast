#include "variant_heuristics.h"
#include <stdlib.h>

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Mercenary search heuristics                                              */
/*                                                                           */
/*  Pawns in Mercenary move like kings (one square, any direction).           */
/*  Pawns cannot promote.  No en passant, no two-square push.                */
/*  Key strategic themes:                                                    */
/*    – Minor piece development (knights/bishops off back rank)              */
/*    – Pawn clustering near enemy king                                      */
/*    – King safety (pawn shield, avoid early wandering)                     */
/*    – Queen deployment timing (avoid early sortie)                         */
/* ═══════════════════════════════════════════════════════════════════════════ */

/* Count minor pieces still on back rank */
static int merc_undeveloped_minor_count(const Board *b, Color side) {
    int back_rank = (side == WHITE) ? 0 : 7;
    int undeveloped = 0;
    Bitboard minors = b->pieces[side][KNIGHT] | b->pieces[side][BISHOP];

    while (minors) {
        Square sq = (Square)bb_pop_lsb(&minors);
        if (SQ_ROW(sq) == back_rank) undeveloped++;
    }
    return undeveloped;
}

/* Bonus for developing minor pieces off the back rank. */
int search_merc_minor_development_score(const Board *b, Move m, Color side) {
    if (b->mod != MOD_MERCENARY || MOVE_IS_CAPTURE(m) ||
        MOVE_IS_EP(m) || MOVE_IS_PROMO(m)) {
        return 0;
    }

    PieceType piece = MOVE_PIECE(m);
    if (piece != KNIGHT && piece != BISHOP) return 0;

    int back_rank = (side == WHITE) ? 0 : 7;
    Square from_sq = MOVE_FROM(m);
    Square to_sq = MOVE_TO(m);

    /* Only reward leaving the back rank */
    if (SQ_ROW(from_sq) != back_rank || SQ_ROW(to_sq) == back_rank) return 0;

    int to_rank = (side == WHITE) ? SQ_ROW(to_sq) : (7 - SQ_ROW(to_sq));
    int undeveloped = merc_undeveloped_minor_count(b, side);
    int score = 0;

    score += (piece == KNIGHT) ? 52 : 36;
    if (undeveloped >= 2) score += 16;
    if (undeveloped >= 3) score += 10;
    /* Central placement bonus */
    if (SQ_COL(to_sq) >= 2 && SQ_COL(to_sq) <= 5) score += 10;
    if (to_rank >= 2 && to_rank <= 4) score += 6;

    /* Knight on good outpost squares */
    if (piece == KNIGHT && to_rank >= 2 && to_rank <= 4 &&
        SQ_COL(to_sq) >= 2 && SQ_COL(to_sq) <= 5) {
        score += 14;
    }

    /* Bishop: prefer long diagonals */
    if (piece == BISHOP && to_rank >= 2) score += 12;

    return score;
}

/* Penalty for moving the queen before developing minor pieces. */
int search_merc_early_queen_sortie_penalty(const Board *b, Move m, Color side) {
    if (b->mod != MOD_MERCENARY || MOVE_PIECE(m) != QUEEN ||
        MOVE_IS_CAPTURE(m) || MOVE_IS_EP(m) || MOVE_IS_PROMO(m)) {
        return 0;
    }

    int back_rank = (side == WHITE) ? 0 : 7;

    /* Only penalize leaving back rank */
    if (SQ_ROW(MOVE_FROM(m)) != back_rank || SQ_ROW(MOVE_TO(m)) == back_rank) {
        return 0;
    }

    if (b->fullmove > 10) return 0;

    int undeveloped = merc_undeveloped_minor_count(b, side);
    if (undeveloped <= 1) return 0;

    return 80 + undeveloped * 24;
}

/* Score for quiet pawn moves.
 *
 * In Mercenary pawns are mini-kings: they can move one square in any
 * direction but cannot promote.  We reward:
 *   – Moving toward the enemy king (pawn pressure / mating net)
 *   – Central positioning
 *   – Maintaining connectivity with nearby friendly pawns
 *   – Advancing into opponent territory
 */
int search_merc_quiet_pawn_score(const Board *b, Move m, Color side) {
    if (b->mod != MOD_MERCENARY || MOVE_PIECE(m) != PAWN ||
        MOVE_IS_CAPTURE(m) || MOVE_IS_EP(m) || MOVE_IS_PROMO(m)) {
        return 0;
    }

    Square to_sq = MOVE_TO(m);
    int to_rank = (side == WHITE) ? SQ_ROW(to_sq) : (7 - SQ_ROW(to_sq));
    int to_file = SQ_COL(to_sq);
    int score = 0;

    /* Proximity to enemy king (Chebyshev) */
    Bitboard enemy_king_bb = b->pieces[side ^ 1][KING];
    if (enemy_king_bb) {
        Square ek = (Square)bb_lsb(enemy_king_bb);
        int dist = abs(SQ_ROW(to_sq) - SQ_ROW(ek));
        int dc   = abs(SQ_COL(to_sq) - SQ_COL(ek));
        if (dc > dist) dist = dc;
        if (dist <= 3) {
            static const int APPROACH[] = {0, 16, 8, 3};
            score += APPROACH[dist];
        }
    }

    /* Central positioning */
    if (to_file >= 2 && to_file <= 5 && to_rank >= 2 && to_rank <= 5) {
        score += 6;
    }

    /* Connectivity: bonus if destination has friendly pawn neighbors */
    Bitboard neighbors = king_attacks[to_sq] & b->pieces[side][PAWN];
    int neighbor_count = bb_popcount(neighbors);
    if (neighbor_count >= 1) score += 4;
    if (neighbor_count >= 2) score += 4;

    /* Advance bonus (getting into opponent territory) */
    if (to_rank >= 4) score += 4;

    return score;
}

/* Score for moves that improve king safety.
 *
 *   – Penalize king moves away from pawn shelter in first 12 moves
 *   – Bonus for rook moves that protect the king
 *   – Small penalty for unnecessary king wandering early
 */
int search_merc_king_safety_score(const Board *b, Move m, Color side) {
    if (b->mod != MOD_MERCENARY) return 0;

    PieceType piece = MOVE_PIECE(m);
    if (piece != KING) return 0;
    if (MOVE_IS_CAPTURE(m) || MOVE_IS_EP(m)) return 0;

    /* In the opening/midgame, penalize aimless king moves */
    if (b->fullmove <= 12) {
        Square from_sq = MOVE_FROM(m);
        Square to_sq = MOVE_TO(m);

        /* Count pawn shield around source and destination */
        int from_shield = bb_popcount(king_attacks[from_sq] & b->pieces[side][PAWN]);
        int to_shield   = bb_popcount(king_attacks[to_sq]   & b->pieces[side][PAWN]);

        int score = 0;

        /* Penalize moves that reduce pawn shelter */
        if (to_shield < from_shield) {
            score -= (from_shield - to_shield) * 18;
        }

        /* Penalize leaving back ranks 1-2 early */
        int from_rank = (side == WHITE) ? SQ_ROW(from_sq) : (7 - SQ_ROW(from_sq));
        int to_rank   = (side == WHITE) ? SQ_ROW(to_sq)   : (7 - SQ_ROW(to_sq));
        if (from_rank <= 1 && to_rank >= 2 && b->fullmove <= 8) {
            score -= 30;
        }

        /* Bonus for moving toward a sheltered position */
        if (to_shield > from_shield) {
            score += (to_shield - from_shield) * 8;
        }

        return score;
    }

    return 0;
}
