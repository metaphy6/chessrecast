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

int search_kb_phase1_forward_rank(Color side, Square sq) {
    return (side == WHITE) ? SQ_ROW(sq) : (7 - SQ_ROW(sq));
}

static int kb_phase1_promotion_distance(Color side, Square sq) {
    return 7 - search_kb_phase1_forward_rank(side, sq);
}

static int kb_phase1_min_enemy_pawn_distance(const Board *b, Color side, Square sq) {
    Color opp = color_opposite(side);
    Bitboard pawns = b->pieces[opp][PAWN];
    int min_dist = 15;

    while (pawns) {
        Square ps = (Square)bb_pop_lsb(&pawns);
        int dr = abs(SQ_ROW(ps) - SQ_ROW(sq));
        int dc = abs(SQ_COL(ps) - SQ_COL(sq));
        int dist = dr > dc ? dr : dc;
        if (dist < min_dist) min_dist = dist;
    }

    return min_dist == 15 ? 0 : min_dist;
}

static int kb_phase1_enemy_king_distance(const Board *b, Color side, Square sq) {
    Bitboard opp_king = b->pieces[color_opposite(side)][KING];
    if (opp_king == BB_EMPTY) return 8;
    return chebyshev_distance_sq(sq, bb_lsb(opp_king));
}

static int kb_phase1_pawn_king_pressure(const Board *b, Color side, Square sq) {
    Bitboard opp_king = b->pieces[color_opposite(side)][KING];
    if (opp_king == BB_EMPTY) return 0;

    {
        Square king_sq = bb_lsb(opp_king);
        int score = 0;
        int attack_row = SQ_ROW(sq) + ((side == WHITE) ? 1 : -1);
        int dist = chebyshev_distance_sq(sq, king_sq);

        if (attack_row >= 0 && attack_row < 8 && SQ_ROW(king_sq) == attack_row &&
            abs(SQ_COL(king_sq) - SQ_COL(sq)) == 1) {
            score += 120;
        }

        if (dist <= 1) score += 35;
        else if (dist == 2) score += 18;

        return score;
    }
}

static bool kb_phase1_forward_lane_open(const Board *b, Color side, Square sq) {
    int forward_row = SQ_ROW(sq) + ((side == WHITE) ? 1 : -1);
    int col = SQ_COL(sq);

    if (forward_row < 0 || forward_row > 7) return false;
    return !BB_HAS(b->occupied[side], SQ(forward_row, col));
}

static int kb_phase1_forward_corridor_blockers(const Board *b, Color side,
                                               Square sq, int max_steps) {
    int row = SQ_ROW(sq);
    int col = SQ_COL(sq);
    int step = (side == WHITE) ? 1 : -1;
    int blockers = 0;

    for (int dr = 1; dr <= max_steps; dr++) {
        int nr = row + step * dr;
        if (nr < 0 || nr > 7) break;

        for (int dc = -1; dc <= 1; dc++) {
            int nc = col + dc;
            if (nc < 0 || nc > 7) continue;
            if (BB_HAS(b->occupied[side], SQ(nr, nc))) blockers++;
        }
    }

    return blockers;
}

static bool kb_phase1_passed_destination(const Board *b, Color side, Square sq);

static int kb_phase1_retreat_arc_move_score(const Board *b, Color side, Square sq) {
    Color opp = color_opposite(side);
    Bitboard opp_king = b->pieces[opp][KING];
    if (opp_king == BB_EMPTY) return 0;

    {
        Square king_sq = bb_lsb(opp_king);
        int opp_rank = search_kb_phase1_forward_rank(opp, king_sq);
        int retreat_row = SQ_ROW(king_sq) + ((opp == WHITE) ? -1 : 1);
        int attack_row = SQ_ROW(sq) + ((side == WHITE) ? 1 : -1);
        int sealed = 0;
        int newly_attacked = 0;

        if (opp_rank < 3) return 0;
        if (retreat_row < 0 || retreat_row > 7) return 0;

        for (int dc = -1; dc <= 1; dc++) {
            int nc = SQ_COL(king_sq) + dc;
            if (nc < 0 || nc > 7) continue;

            {
                Square rsq = SQ(retreat_row, nc);
                bool attacks = false;
                if (attack_row == retreat_row && abs(SQ_COL(sq) - nc) == 1) {
                    attacks = true;
                    newly_attacked++;
                }

                if (attacks || b->mailbox[rsq] != PIECE_EMPTY) {
                    sealed++;
                }
            }
        }

        if (newly_attacked == 0) return 0;
        if (sealed == 3) return 280 + newly_attacked * 24;
        if (sealed == 2) return 120 + newly_attacked * 18;
        return newly_attacked * 28;
    }
}

static int kb_phase1_wing_drift_move_penalty(const Board *b, Color side, Move m) {
    Square from_sq = MOVE_FROM(m);
    Square to_sq = MOVE_TO(m);
    int file = SQ_COL(to_sq);
    int from_rank = search_kb_phase1_forward_rank(side, from_sq);
    int to_rank = search_kb_phase1_forward_rank(side, to_sq);
    int penalty;

    if (file != 0 && file != 1 && file != 6 && file != 7) return 0;
    if (from_rank != 1 || to_rank < 2 || to_rank > 3) return 0;
    if (kb_phase1_passed_destination(b, side, to_sq)) return 0;
    if (kb_phase1_pawn_king_pressure(b, side, to_sq) >= 70) return 0;

    if (b->pieces[side][KING] != BB_EMPTY) {
        Square king_sq = bb_lsb(b->pieces[side][KING]);
        if (chebyshev_distance_sq(king_sq, to_sq) <= 2) return 0;
    }

    if (b->pieces[color_opposite(side)][KING] != BB_EMPTY) {
        Square enemy_king_sq = bb_lsb(b->pieces[color_opposite(side)][KING]);
        if (chebyshev_distance_sq(enemy_king_sq, to_sq) <= 2) return 0;
    }

    penalty = (to_rank == 2) ? 100 : 170;
    if (search_kb_phase1_any_pawn_capture_available(b, side)) penalty += 30;
    return penalty;
}

static int kb_phase1_connected_wall_move_score(const Board *b, Color side, Square sq) {
    Color opp = color_opposite(side);
    Bitboard opp_king = b->pieces[opp][KING];
    int row = SQ_ROW(sq);
    int col = SQ_COL(sq);
    int rank = search_kb_phase1_forward_rank(side, sq);

    if (opp_king == BB_EMPTY) return 0;
    if (rank < 3) return 0;

    {
        Square king_sq = bb_lsb(opp_king);
        int opp_rank = search_kb_phase1_forward_rank(opp, king_sq);
        int pair_dist = 8;
        bool has_pair = false;

        if (opp_rank < 4) return 0;

        if (col > 0 && BB_HAS(b->pieces[side][PAWN], SQ(row, col - 1))) {
            int left_dist = chebyshev_distance_sq(SQ(row, col - 1), king_sq);
            int self_dist = chebyshev_distance_sq(sq, king_sq);
            pair_dist = (left_dist < self_dist) ? left_dist : self_dist;
            has_pair = true;
        }
        if (col < 7 && BB_HAS(b->pieces[side][PAWN], SQ(row, col + 1))) {
            int right_dist = chebyshev_distance_sq(SQ(row, col + 1), king_sq);
            int self_dist = chebyshev_distance_sq(sq, king_sq);
            int this_pair = (right_dist < self_dist) ? right_dist : self_dist;
            if (!has_pair || this_pair < pair_dist) pair_dist = this_pair;
            has_pair = true;
        }

        if (!has_pair) return 0;
        if (pair_dist <= 2) return 760;
        if (pair_dist == 3) return 280;
    }

    return 0;
}

static int kb_phase1_forward_file_clearance(const Board *b, Color side, Square sq,
                                            int max_steps) {
    int row = SQ_ROW(sq);
    int col = SQ_COL(sq);
    int step = (side == WHITE) ? 1 : -1;
    int clear = 0;

    for (int i = 1; i <= max_steps; i++) {
        int nr = row + step * i;
        if (nr < 0 || nr > 7) break;
        if (b->mailbox[SQ(nr, col)] != PIECE_EMPTY) break;
        clear++;
    }

    return clear;
}

bool search_kb_phase1_any_pawn_capture_available(const Board *b, Color side) {
    Bitboard pawns = b->pieces[side][PAWN];
    int step = (side == WHITE) ? 1 : -1;

    while (pawns) {
        Square sq = (Square)bb_pop_lsb(&pawns);
        int row = SQ_ROW(sq) + step;
        int col = SQ_COL(sq);
        if (row < 0 || row > 7) continue;

        if (col > 0) {
            Piece target = b->mailbox[SQ(row, col - 1)];
            if (target != PIECE_EMPTY && PIECE_COLOR(target) != side &&
                PIECE_TYPE(target) == PAWN) {
                return true;
            }
        }
        if (col < 7) {
            Piece target = b->mailbox[SQ(row, col + 1)];
            if (target != PIECE_EMPTY && PIECE_COLOR(target) != side &&
                PIECE_TYPE(target) == PAWN) {
                return true;
            }
        }
    }

    return false;
}

static bool kb_phase1_has_secondary_pawn_capture(const Board *b, Color side,
                                                 Move m) {
    if (!(MOVE_PIECE(m) == PAWN && MOVE_IS_CAPTURE(m) && MOVE_CAPTURED(m) == PAWN)) {
        return false;
    }

    {
        Square from_sq = MOVE_FROM(m);
        Square to_sq = MOVE_TO(m);
        int target_row = SQ_ROW(to_sq) - ((side == WHITE) ? 1 : -1);

        if (target_row < 0 || target_row > 7) return false;

        if (SQ_COL(to_sq) > 0) {
            Square alt = SQ(target_row, SQ_COL(to_sq) - 1);
            if (alt != from_sq && BB_HAS(b->pieces[side][PAWN], alt)) return true;
        }
        if (SQ_COL(to_sq) < 7) {
            Square alt = SQ(target_row, SQ_COL(to_sq) + 1);
            if (alt != from_sq && BB_HAS(b->pieces[side][PAWN], alt)) return true;
        }

        return false;
    }
}

int search_kb_unlocked_development_score(const Board *b, Move m, Color side) {
    if (b->mod != MOD_KINGS_BATTLE || !b->kb_unlocked || MOVE_IS_CAPTURE(m) ||
        MOVE_IS_EP(m) || MOVE_IS_PROMO(m)) {
        return 0;
    }

    {
        PieceType piece = MOVE_PIECE(m);
        Square from_sq = MOVE_FROM(m);
        Square to_sq = MOVE_TO(m);
        int back_rank = (side == WHITE) ? 0 : 7;
        int to_rank = (side == WHITE) ? SQ_ROW(to_sq) : (7 - SQ_ROW(to_sq));
        int score = 0;

        if (piece != KNIGHT && piece != BISHOP) return 0;
        if (SQ_ROW(from_sq) != back_rank || SQ_ROW(to_sq) == back_rank) return 0;

        score += (piece == KNIGHT) ? 58 : 52;
        if (SQ_COL(to_sq) >= 2 && SQ_COL(to_sq) <= 5) score += 10;
        if (to_rank >= 2) score += 8;
        return score;
    }
}

int search_kb_unlocked_king_shelter_score(const Board *b, Move m, Color side) {
    if (b->mod != MOD_KINGS_BATTLE || !b->kb_unlocked || MOVE_PIECE(m) != PAWN ||
        MOVE_IS_CAPTURE(m) || MOVE_IS_EP(m) || MOVE_IS_PROMO(m)) {
        return 0;
    }

    {
        Bitboard king_bb = b->pieces[side][KING];
        Bitboard queen_bb = b->pieces[color_opposite(side)][QUEEN];
        Square king_sq;
        Square from_sq;
        Square to_sq;
        Square queen_sq;
        int from_dist;
        int to_dist;
        int queen_dist;
        int score = 0;

        if (king_bb == BB_EMPTY || queen_bb == BB_EMPTY) return 0;

        king_sq = bb_lsb(king_bb);
        from_sq = MOVE_FROM(m);
        to_sq = MOVE_TO(m);
        queen_sq = bb_lsb(queen_bb);
        from_dist = chebyshev_distance_sq(from_sq, king_sq);
        to_dist = chebyshev_distance_sq(to_sq, king_sq);
        queen_dist = chebyshev_distance_sq(queen_sq, king_sq);

        if (queen_dist > 4 && from_dist > 2 && to_dist > 1) return 0;

        if (to_dist <= 1) score += 120;
        else if (to_dist == 2 && from_dist > 2) score += 50;
        if (from_dist <= 1) score += 35;

        if (queen_dist <= 2) score += 60;
        else if (queen_dist <= 4) score += 30;

        {
            Bitboard queen_ray = bishop_attacks_calc(queen_sq, b->all) |
                                 rook_attacks_calc(queen_sq, b->all);
            if (BB_HAS(queen_ray, king_sq)) score += 70;
        }

        if (abs(SQ_COL(to_sq) - SQ_COL(king_sq)) <= 1) score += 18;
        if ((side == WHITE && SQ_ROW(to_sq) <= SQ_ROW(king_sq)) ||
            (side == BLACK && SQ_ROW(to_sq) >= SQ_ROW(king_sq))) {
            score += 12;
        }

        return score;
    }
}

int search_kb_unlocked_queen_pressure_score(const Board *b, Move m, Color side) {
    if (b->mod != MOD_KINGS_BATTLE || !b->kb_unlocked || MOVE_PIECE(m) != QUEEN ||
        MOVE_IS_EP(m) || MOVE_IS_PROMO(m)) {
        return 0;
    }

    {
        Bitboard enemy_king = b->pieces[color_opposite(side)][KING];
        Square king_sq;
        Square from_sq;
        Square to_sq;
        int from_dist;
        int to_dist;
        int score = 0;

        if (enemy_king == BB_EMPTY) return 0;

        king_sq = bb_lsb(enemy_king);
        from_sq = MOVE_FROM(m);
        to_sq = MOVE_TO(m);
        from_dist = chebyshev_distance_sq(from_sq, king_sq);
        to_dist = chebyshev_distance_sq(to_sq, king_sq);

        if (to_dist <= 2) score += 110;
        if (to_dist < from_dist) score += (from_dist - to_dist) * 34;
        if (to_dist + 1 < from_dist) score += 28;
        if (to_dist > from_dist + 1) score -= (to_dist - from_dist) * 40;

        return score;
    }
}

static int kb_unlocked_local_pawn_shield(const Board *b, Color side, Square sq) {
    return bb_popcount(b->pieces[side][PAWN] & king_attacks[sq]);
}

int search_kb_unlocked_king_safety_score(const Board *b, Move m, Color side) {
    if (b->mod != MOD_KINGS_BATTLE || !b->kb_unlocked || MOVE_PIECE(m) != KING ||
        MOVE_IS_EP(m) || MOVE_IS_PROMO(m)) {
        return 0;
    }

    {
        Bitboard enemy_queen = b->pieces[color_opposite(side)][QUEEN];
        Square queen_sq;
        Square from_sq;
        Square to_sq;
        int from_dist;
        int to_dist;
        int from_shield;
        int to_shield;
        Bitboard queen_ray;
        int score = 40;

        if (enemy_queen == BB_EMPTY) return 0;

        queen_sq = bb_lsb(enemy_queen);
        from_sq = MOVE_FROM(m);
        to_sq = MOVE_TO(m);
        from_dist = chebyshev_distance_sq(from_sq, queen_sq);
        to_dist = chebyshev_distance_sq(to_sq, queen_sq);
        from_shield = kb_unlocked_local_pawn_shield(b, side, from_sq);
        to_shield = kb_unlocked_local_pawn_shield(b, side, to_sq);
        queen_ray = bishop_attacks_calc(queen_sq, b->all) |
                    rook_attacks_calc(queen_sq, b->all);

        if (to_dist > from_dist) score += (to_dist - from_dist) * 28;
        else if (to_dist < from_dist) score -= (from_dist - to_dist) * 34;

        if (to_shield > from_shield) score += (to_shield - from_shield) * 26;
        else if (to_shield < from_shield) score -= (from_shield - to_shield) * 30;

        if (BB_HAS(queen_ray, from_sq) && !BB_HAS(queen_ray, to_sq)) score += 52;
        else if (!BB_HAS(queen_ray, from_sq) && BB_HAS(queen_ray, to_sq)) score -= 58;

        return score;
    }
}

static bool kb_phase1_passed_destination(const Board *b, Color side, Square sq) {
    Color opp = color_opposite(side);
    int row = SQ_ROW(sq);
    int col = SQ_COL(sq);
    int start = (side == WHITE) ? row + 1 : 0;
    int end = (side == WHITE) ? 8 : row;

    for (int r = start; r < end; r++) {
        for (int dc = -1; dc <= 1; dc++) {
            int nc = col + dc;
            if (nc < 0 || nc > 7) continue;
            if (BB_HAS(b->pieces[opp][PAWN], SQ(r, nc))) {
                return false;
            }
        }
    }

    return true;
}

static int kb_phase1_clear_promotion_lane(const Board *b, Color side, Square sq) {
    int row = SQ_ROW(sq);
    int col = SQ_COL(sq);
    int clear = 0;

    if (side == WHITE) {
        for (int r = row + 1; r < 8; r++) {
            if (b->mailbox[SQ(r, col)] != PIECE_EMPTY) break;
            clear++;
        }
    } else {
        for (int r = row - 1; r >= 0; r--) {
            if (b->mailbox[SQ(r, col)] != PIECE_EMPTY) break;
            clear++;
        }
    }

    return clear;
}

int search_kb_phase1_king_activation_score(const Board *b, Move m, Color side) {
    if (b->mod != MOD_KINGS_BATTLE || b->kb_unlocked || MOVE_PIECE(m) != KING ||
        MOVE_IS_PROMO(m) || MOVE_IS_EP(m)) {
        return 0;
    }

    {
        Square from_sq = MOVE_FROM(m);
        Square to_sq = MOVE_TO(m);
        int from_rank = search_kb_phase1_forward_rank(side, from_sq);
        int to_rank = search_kb_phase1_forward_rank(side, to_sq);
        int from_dist = kb_phase1_min_enemy_pawn_distance(b, side, from_sq);
        int to_dist = kb_phase1_min_enemy_pawn_distance(b, side, to_sq);
        int enemy_king_rank = -1;
        int score = 0;

        if (b->pieces[color_opposite(side)][KING] != BB_EMPTY) {
            enemy_king_rank = search_kb_phase1_forward_rank(
                color_opposite(side),
                bb_lsb(b->pieces[color_opposite(side)][KING])
            );
        }
        if (to_rank > from_rank) score += (to_rank - from_rank) * 140;
        if (to_rank < from_rank) score -= (from_rank - to_rank) * 170;
        if (from_rank == 0 && to_rank > 0) score += 120;
        if (SQ_COL(to_sq) >= 2 && SQ_COL(to_sq) <= 5) score += 40;
        if (to_dist > 0 && from_dist > 0 && to_dist < from_dist) {
            score += (from_dist - to_dist) * 60;
        } else if (to_dist > 0 && from_dist > 0 && to_dist > from_dist) {
            score -= (to_dist - from_dist) * 80;
        }

        if (enemy_king_rank >= 0) {
            if (to_rank + 1 < enemy_king_rank) {
                score -= (enemy_king_rank - to_rank - 1) * 44;
            } else if (to_rank > enemy_king_rank) {
                score += (to_rank - enemy_king_rank) * 18;
            }
        }

        {
            Bitboard opp_pawns = b->pieces[color_opposite(side)][PAWN];
            int capturable = 0;
            while (opp_pawns) {
                Square ps = (Square)bb_pop_lsb(&opp_pawns);
                if (chebyshev_distance_sq(ps, to_sq) == 1) capturable++;
            }
            score += capturable * 80;
        }

        {
            bool from_forward_open = kb_phase1_forward_lane_open(b, side, from_sq);
            bool to_forward_open = kb_phase1_forward_lane_open(b, side, to_sq);
            int from_clear = kb_phase1_forward_file_clearance(b, side, from_sq, 2);
            int to_clear = kb_phase1_forward_file_clearance(b, side, to_sq, 2);
            int from_blockers = kb_phase1_forward_corridor_blockers(b, side, from_sq, 2);
            int to_blockers = kb_phase1_forward_corridor_blockers(b, side, to_sq, 2);
            if (to_forward_open && !from_forward_open) {
                score += 45;
            } else if (!to_forward_open && from_forward_open) {
                score -= 35;
            }
            if (to_clear > from_clear) score += (to_clear - from_clear) * 40;
            else if (to_clear < from_clear) score -= (from_clear - to_clear) * 30;
            if (from_rank == to_rank && from_clear == 0 && to_clear >= 2) {
                score += 120;
            }
            if (to_blockers < from_blockers) {
                score += (from_blockers - to_blockers) * 24;
            } else if (to_blockers > from_blockers) {
                score -= (to_blockers - from_blockers) * 18;
            }
        }

        if (MOVE_IS_CAPTURE(m) && MOVE_CAPTURED(m) == PAWN) score += 800;
        return score;
    }
}

int search_kb_phase1_pawn_race_score(const Board *b, Move m, Color side) {
    if (b->mod != MOD_KINGS_BATTLE || b->kb_unlocked || MOVE_PIECE(m) != PAWN ||
        MOVE_IS_PROMO(m) || MOVE_IS_EP(m)) {
        return 0;
    }

    {
        Square from_sq = MOVE_FROM(m);
        Square to_sq = MOVE_TO(m);
        int from_rank = search_kb_phase1_forward_rank(side, from_sq);
        int to_rank = search_kb_phase1_forward_rank(side, to_sq);
        int score = 0;
        bool passed = kb_phase1_passed_destination(b, side, to_sq);
        int clear_lane = kb_phase1_clear_promotion_lane(b, side, to_sq);
        int promo_dist = kb_phase1_promotion_distance(side, to_sq);
        int enemy_king_dist = kb_phase1_enemy_king_distance(b, side, to_sq);
        int king_pressure = kb_phase1_pawn_king_pressure(b, side, to_sq);

        score += (to_rank - from_rank) * 32;
        if (to_rank >= 3) score += (to_rank - 2) * 26;
        if (SQ_COL(to_sq) >= 2 && SQ_COL(to_sq) <= 5) score += 18;
        score += king_pressure;

        if (!MOVE_IS_CAPTURE(m) && from_rank == 1 && SQ_COL(from_sq) >= 2 && SQ_COL(from_sq) <= 5) {
            score += 18;
            if (SQ_COL(from_sq) == 3 || SQ_COL(from_sq) == 4) {
                score += 34;
            }
        }

        if (!MOVE_IS_CAPTURE(m) && from_rank == 1 && to_rank <= 2 &&
            search_kb_phase1_any_pawn_capture_available(b, side)) {
            score -= 420;
        }

        score += kb_phase1_retreat_arc_move_score(b, side, to_sq);
        score += kb_phase1_connected_wall_move_score(b, side, to_sq);

        if (MOVE_IS_CAPTURE(m)) {
            score += 80 + to_rank * 22;
            if (MOVE_CAPTURED(m) == PAWN) {
                int enemy_progress = search_kb_phase1_forward_rank(color_opposite(side), to_sq);
                score += 110;
                if (enemy_progress >= 3) score += 110 + (enemy_progress - 2) * 28;
                if (kb_phase1_has_secondary_pawn_capture(b, side, m)) score += 260;
            } else {
                score += 40;
            }
            if (from_rank >= 3 && to_rank > from_rank) score += 60;
        }

        if (passed) {
            score += 90 + to_rank * 28;
            score += clear_lane * 20;
            if (clear_lane >= promo_dist) score += 90;
            if (enemy_king_dist > promo_dist + 1) {
                score += 70 + (enemy_king_dist - promo_dist) * 18;
            } else if (enemy_king_dist <= 1) {
                score -= 70;
            } else if (enemy_king_dist == 2) {
                score -= 30;
            }
        }

        score -= kb_phase1_wing_drift_move_penalty(b, side, m);
        return score;
    }
}

bool search_kb_unlocked_is_queen_pressure_move(const Board *b, Move m, Color side) {
    if (b->mod != MOD_KINGS_BATTLE || !b->kb_unlocked || MOVE_PIECE(m) != QUEEN ||
        MOVE_IS_EP(m) || MOVE_IS_PROMO(m)) {
        return false;
    }

    if (b->pieces[color_opposite(side)][KING] == BB_EMPTY) return false;

    {
        Square enemy_king = bb_lsb(b->pieces[color_opposite(side)][KING]);
        int from_dist = chebyshev_distance_sq(MOVE_FROM(m), enemy_king);
        int to_dist = chebyshev_distance_sq(MOVE_TO(m), enemy_king);
        return to_dist <= 2 || to_dist + 1 < from_dist;
    }
}

bool search_kb_unlocked_is_king_safety_move(const Board *b, Move m, Color side) {
    return b->mod == MOD_KINGS_BATTLE && b->kb_unlocked &&
           MOVE_PIECE(m) == KING && !MOVE_IS_EP(m) && !MOVE_IS_PROMO(m) &&
           b->pieces[color_opposite(side)][QUEEN] != BB_EMPTY;
}

bool search_kb_unlocked_is_shelter_move(const Board *b, Move m, Color side) {
    if (b->mod != MOD_KINGS_BATTLE || !b->kb_unlocked || MOVE_PIECE(m) != PAWN ||
        MOVE_IS_CAPTURE(m) || MOVE_IS_EP(m) || MOVE_IS_PROMO(m)) {
        return false;
    }

    if (b->pieces[side][KING] == BB_EMPTY || b->pieces[color_opposite(side)][QUEEN] == BB_EMPTY) {
        return false;
    }

    return chebyshev_distance_sq(MOVE_TO(m), bb_lsb(b->pieces[side][KING])) <= 1;
}

bool search_kb_unlocked_is_development_move(const Board *b, Move m, Color side) {
    PieceType piece = MOVE_PIECE(m);
    int home_row = (side == WHITE) ? 0 : 7;

    if (b->mod != MOD_KINGS_BATTLE || !b->kb_unlocked || MOVE_IS_CAPTURE(m) ||
        MOVE_IS_EP(m) || MOVE_IS_PROMO(m)) {
        return false;
    }

    if (piece != KNIGHT && piece != BISHOP) return false;
    return SQ_ROW(MOVE_FROM(m)) == home_row && SQ_ROW(MOVE_TO(m)) != home_row;
}