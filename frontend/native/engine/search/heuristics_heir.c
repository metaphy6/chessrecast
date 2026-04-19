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

static bool heir_square_attacked_by_enemy_pawn(const Board *b, Square sq, Color side) {
    Color opp = color_opposite(side);

    if (opp == WHITE) {
        return (pawn_attacks[BLACK][sq] & b->pieces[WHITE][PAWN]) != 0;
    }

    return (pawn_attacks[WHITE][sq] & b->pieces[BLACK][PAWN]) != 0;
}

static bool heir_has_quiet_flank_pawn_push(const Board *b, Color side) {
    Bitboard pawns = b->pieces[side][PAWN];
    Bitboard occ = b->occupied[WHITE] | b->occupied[BLACK];
    int step = (side == WHITE) ? 1 : -1;

    while (pawns) {
        Square from = (Square)bb_pop_lsb(&pawns);
        int file = SQ_COL(from);
        int to_rank;
        Square to;

        if (!(file <= 1 || file >= 6)) continue;

        to_rank = SQ_ROW(from) + step;
        if (to_rank < 0 || to_rank > 7) continue;

        to = SQ(to_rank, file);
        if (!BB_HAS(occ, to)) return true;
    }

    return false;
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

int search_heir_risky_bishop_pawn_grab_penalty(const Board *b, Move m) {
    Color side;
    Color opp;
    Square king_home;
    uint8_t castling_mask;
    bool king_on_home;
    bool can_castle;
    Square to;
    bool central;

    if (b->mod != MOD_HEIR) return 0;
    if (MOVE_PIECE(m) != BISHOP) return 0;
    if (!MOVE_IS_CAPTURE(m) || MOVE_CAPTURED(m) != PAWN) return 0;
    if (b->fullmove > 22) return 0;

    side = b->side;
    opp = color_opposite(side);
    king_home = (side == WHITE) ? SQ(0, 4) : SQ(7, 4);
    castling_mask = (side == WHITE) ? (CASTLE_WK | CASTLE_WQ) : (CASTLE_BK | CASTLE_BQ);

    king_on_home = BB_HAS(b->pieces[side][KING], king_home);
    can_castle = (b->castling & castling_mask) != 0;
    if (!king_on_home && !can_castle) return 0;

    to = MOVE_TO(m);
    central = SQ_ROW(to) >= 2 && SQ_ROW(to) <= 5 && SQ_COL(to) >= 2 && SQ_COL(to) <= 5;
    if (!central) return 0;

    if (!board_square_attacked(b, to, opp)) return 0;

    {
        int penalty = 240;
        Square from = MOVE_FROM(m);

        if ((side == WHITE && (from == SQ(1, 1) || from == SQ(1, 6))) ||
            (side == BLACK && (from == SQ(6, 1) || from == SQ(6, 6)))) {
            penalty += 80;
        }

        return penalty;
    }
}

int search_heir_flank_pawn_drift_penalty(const Board *b, Move m) {
    int file;
    int advance;
    Bitboard heavy_minors;

    if (b->mod != MOD_HEIR || MOVE_PIECE(m) != PAWN) return 0;
    if (MOVE_IS_CAPTURE(m) || MOVE_IS_EP(m) || MOVE_IS_PROMO(m)) return 0;

    if (b->pieces[WHITE][KING] != BB_EMPTY || b->pieces[BLACK][KING] != BB_EMPTY) {
        return 0;
    }

    file = SQ_COL(MOVE_TO(m));
    if (file != 0 && file != 7) return 0;

    advance = heir_pawn_advance(b->side, MOVE_TO(m));
    if (advance > 2) return 0;

    heavy_minors = b->pieces[b->side][ROOK] | b->pieces[b->side][BISHOP] | b->pieces[b->side][QUEEN];
    if (heavy_minors == BB_EMPTY) return 0;

    return (b->pieces[b->side][BISHOP] != BB_EMPTY) ? 210 : 170;
}

int search_heir_risky_center_pawn_push_penalty(const Board *b, Move m) {
    Color side;
    Square from;
    Square to;
    Square king_home;
    int file;
    int from_rank;
    int to_rank;
    int penalty;

    if (b->mod != MOD_HEIR || MOVE_PIECE(m) != PAWN) return 0;
    if (MOVE_IS_CAPTURE(m) || MOVE_IS_EP(m) || MOVE_IS_PROMO(m)) return 0;

    side = b->side;
    from = MOVE_FROM(m);
    to = MOVE_TO(m);
    king_home = (side == WHITE) ? SQ(0, 4) : SQ(7, 4);

    if (!BB_HAS(b->pieces[side][KING], king_home)) return 0;

    file = SQ_COL(to);
    if (file < 4 || file > 6) return 0;

    from_rank = (side == WHITE) ? SQ_ROW(from) : (7 - SQ_ROW(from));
    to_rank = (side == WHITE) ? SQ_ROW(to) : (7 - SQ_ROW(to));
    if (to_rank < 2 || to_rank > 4) return 0;
    if (to_rank < from_rank) return 0;

    if (!heir_square_attacked_by_enemy_pawn(b, to, side)) return 0;

    penalty = 240;
    if (file == 5) penalty += 80;
    if (from_rank <= 1) penalty += 30;
    return penalty;
}

int search_heir_simplified_center_pawn_push_penalty(const Board *b, Move m) {
    Color side;
    Color opp;
    Square to;
    int file;
    int penalty;

    if (b->mod != MOD_HEIR || MOVE_PIECE(m) != PAWN) return 0;
    if (MOVE_IS_CAPTURE(m) || MOVE_IS_EP(m) || MOVE_IS_PROMO(m)) return 0;
    if (b->fullmove < 16) return 0;

    to = MOVE_TO(m);
    file = SQ_COL(to);
    if (file < 3 || file > 4) return 0;

    if (bb_popcount(b->occupied[WHITE] | b->occupied[BLACK]) > 16) return 0;
    if (b->pieces[WHITE][ROOK] == BB_EMPTY || b->pieces[BLACK][ROOK] == BB_EMPTY) return 0;

    side = b->side;
    if (!heir_has_quiet_flank_pawn_push(b, side)) return 0;

    opp = color_opposite(side);
    if (!board_square_attacked(b, to, opp)) return 0;

    penalty = 320;
    if (SQ_COL(MOVE_FROM(m)) >= 3 && SQ_COL(MOVE_FROM(m)) <= 4) penalty += 40;
    return penalty;
}

int search_heir_pawn_harass_score(const Board *b, Move m) {
    Color side;
    Color opp;
    Bitboard attacks;
    Bitboard enemy_minors;
    Bitboard hits;
    int score;
    Square king_home;
    uint8_t castling_mask;

    if (b->mod != MOD_HEIR || MOVE_PIECE(m) != PAWN) return 0;
    if (MOVE_IS_CAPTURE(m) || MOVE_IS_EP(m) || MOVE_IS_PROMO(m)) return 0;

    side = b->side;
    opp = color_opposite(side);
    attacks = pawn_attacks[side][MOVE_TO(m)];
    enemy_minors = b->pieces[opp][KNIGHT] | b->pieces[opp][BISHOP];
    hits = attacks & enemy_minors;

    if (hits == BB_EMPTY) return 0;

    score = 160;
    if (b->fullmove <= 20) score += 50;
    if (SQ_COL(MOVE_FROM(m)) >= 4 && SQ_COL(MOVE_FROM(m)) <= 6) score += 40;

    king_home = (side == WHITE) ? SQ(0, 4) : SQ(7, 4);
    castling_mask = (side == WHITE) ? (CASTLE_WK | CASTLE_WQ) : (CASTLE_BK | CASTLE_BQ);
    if (BB_HAS(b->pieces[side][KING], king_home) || (b->castling & castling_mask) != 0) {
        score += 40;
    }

    if ((hits & b->pieces[opp][BISHOP]) != BB_EMPTY) score += 40;
    return score;
}

int search_heir_passive_king_edge_retreat_penalty(const Board *b, Move m) {
    Color side;
    Color opp;
    Square from;
    Square to;
    int from_file;
    int to_file;
    Bitboard alt_steps;

    if (b->mod != MOD_HEIR || MOVE_PIECE(m) != KING) return 0;
    if (MOVE_IS_CAPTURE(m) || MOVE_IS_EP(m) || MOVE_IS_PROMO(m)) return 0;
    if (b->fullmove < 20) return 0;

    side = b->side;
    opp = color_opposite(side);
    if (board_in_check(b, side)) return 0;

    from = MOVE_FROM(m);
    to = MOVE_TO(m);
    from_file = SQ_COL(from);
    to_file = SQ_COL(to);

    if (from_file == 0 || from_file == 7) return 0;
    if (to_file != 0 && to_file != 7) return 0;

    alt_steps = king_attacks[from];
    while (alt_steps) {
        Square alt = (Square)bb_pop_lsb(&alt_steps);

        if (alt == to) continue;
        if (SQ_COL(alt) == 0 || SQ_COL(alt) == 7) continue;
        if (BB_HAS(b->occupied[side], alt)) continue;
        if (board_square_attacked(b, alt, opp)) continue;
        return 180;
    }

    return 0;
}

bool search_heir_is_tactical_capture_candidate(const Board *b, Move m) {
    PieceType captured = MOVE_CAPTURED(m);
    Square to = MOVE_TO(m);
    bool central = SQ_ROW(to) >= 2 && SQ_ROW(to) <= 5 &&
                   SQ_COL(to) >= 2 && SQ_COL(to) <= 5;

    if (b->mod != MOD_HEIR) return false;
    if (!(MOVE_IS_CAPTURE(m) || MOVE_IS_EP(m))) return false;
    if (MOVE_PIECE(m) == ROOK) return true;
    if (MOVE_IS_PROMO(m)) return true;
    if (captured >= KNIGHT) return true;
    if (captured == PAWN && central) return true;
    if (MOVE_PIECE(m) == PAWN && heir_pawn_advance(b->side, MOVE_TO(m)) >= 4) return true;
    return false;
}
