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

static int ff_undeveloped_minor_count(const Board *b, Color side) {
    int back_rank = (side == WHITE) ? 0 : 7;
    int undeveloped = 0;
    Bitboard minors;

    if (b->mod != MOD_FRIENDLY_FIRE) return 0;

    minors = b->pieces[side][KNIGHT] | b->pieces[side][BISHOP];
    while (minors) {
        Square sq = (Square)bb_pop_lsb(&minors);
        if (SQ_ROW(sq) == back_rank) undeveloped++;
    }

    return undeveloped;
}

static int ff_pawn_shield_count(const Board *b, Color side, Square king_sq) {
    int row = SQ_ROW(king_sq);
    int col = SQ_COL(king_sq);
    int next_row = row + ((side == WHITE) ? 1 : -1);
    int shield = 0;

    if (next_row < 0 || next_row > 7) return 0;

    for (int dc = -1; dc <= 1; dc++) {
        int nc = col + dc;
        if (nc < 0 || nc > 7) continue;
        if (BB_HAS(b->pieces[side][PAWN], SQ(next_row, nc))) shield++;
    }

    return shield;
}

static int ff_center_file_distance(Square sq) {
    int file = SQ_COL(sq);
    int d3 = abs(file - 3);
    int d4 = abs(file - 4);
    return d3 < d4 ? d3 : d4;
}

static bool ff_is_flank_file(int file) {
    return file <= 1 || file >= 6;
}

static int ff_side_pawn_activity(const Board *b, Color side) {
    Bitboard pawns = b->pieces[side][PAWN];
    int activity = 0;

    while (pawns) {
        Square sq = (Square)bb_pop_lsb(&pawns);
        int file = SQ_COL(sq);
        int rank = (side == WHITE) ? SQ_ROW(sq) : (7 - SQ_ROW(sq));

        if ((file <= 2 || file >= 5) && rank != 1) activity++;
    }

    return activity;
}

static Bitboard ff_guard_piece_attacks(PieceType piece, Square sq, Bitboard occ) {
    if (piece == BISHOP) return bishop_attacks_calc(sq, occ);
    if (piece == QUEEN) {
        return bishop_attacks_calc(sq, occ) | rook_attacks_calc(sq, occ);
    }
    return BB_EMPTY;
}

static Bitboard ff_pressure_piece_attacks(PieceType piece, Square sq, Bitboard occ) {
    if (piece == KNIGHT) return knight_attacks[sq];
    if (piece == BISHOP) return bishop_attacks_calc(sq, occ);
    if (piece == QUEEN) {
        return bishop_attacks_calc(sq, occ) | rook_attacks_calc(sq, occ);
    }
    return BB_EMPTY;
}

static int ff_pressure_pawn_bonus(Color side,
                                  Square pawn_sq,
                                  Square king_sq,
                                  bool has_king_sq) {
    int forward_rank = (side == WHITE) ? SQ_ROW(pawn_sq) : (7 - SQ_ROW(pawn_sq));
    int bonus = 14;

    if (forward_rank <= 1) bonus += 12;
    if (forward_rank <= 2) bonus += 6;
    if (has_king_sq && abs(SQ_COL(pawn_sq) - SQ_COL(king_sq)) <= 1) bonus += 10;
    return bonus;
}

static int ff_piece_challenge_penalty(PieceType piece, bool immediate) {
    switch (piece) {
        case KNIGHT:
            return immediate ? 140 : 54;
        case BISHOP:
            return immediate ? 112 : 42;
        case QUEEN:
            return immediate ? 64 : 24;
        default:
            return 0;
    }
}

static int ff_piece_harass_bonus(Piece piece) {
    if (piece == PIECE_EMPTY) return 0;

    switch (PIECE_TYPE(piece)) {
        case QUEEN:
            return 60;
        case ROOK:
            return 52;
        case BISHOP:
        case KNIGHT:
            return 44;
        default:
            return 0;
    }
}

static int ff_self_capture_prep_target_bonus(Piece piece) {
    if (piece == PIECE_EMPTY) return 0;

    switch (PIECE_TYPE(piece)) {
        case KING:
            return 108;
        case QUEEN:
            return 72;
        case ROOK:
            return 58;
        case BISHOP:
        case KNIGHT:
            return 44;
        default:
            return 0;
    }
}

static int ff_self_capture_prep_ray_score(const Board *b,
                                          Square from_sq,
                                          Square to_sq,
                                          Color side,
                                          int dr,
                                          int dc) {
    Bitboard occ = (b->all & ~BB_SQ(from_sq)) | BB_SQ(to_sq);
    bool saw_blocker = false;
    PieceType blocker_type = PAWN;
    int blocker_step = 0;
    int row = SQ_ROW(to_sq);
    int col = SQ_COL(to_sq);
    int step = 0;

    while (true) {
        Piece piece;
        Square sq;
        int bonus;

        row += dr;
        col += dc;
        step++;
        if (row < 0 || row > 7 || col < 0 || col > 7) break;

        sq = SQ(row, col);
        if (!BB_HAS(occ, sq) || sq == from_sq) continue;

        piece = b->mailbox[sq];
        if (piece == PIECE_EMPTY) continue;

        if (!saw_blocker) {
            if (PIECE_COLOR(piece) == side && PIECE_TYPE(piece) != KING &&
                BB_HAS(b->ff_moved, sq)) {
                saw_blocker = true;
                blocker_type = PIECE_TYPE(piece);
                blocker_step = step;
                continue;
            }
            break;
        }

        if (PIECE_COLOR(piece) == side) break;

        bonus = ff_self_capture_prep_target_bonus(piece);
        if (bonus <= 0) return 0;

        if (blocker_type == PAWN) bonus += 36;
        else if (blocker_type == KNIGHT || blocker_type == BISHOP) bonus += 14;
        if (blocker_step <= 2) bonus += 18;
        if (step - blocker_step <= 3) bonus += 14;
        return bonus;
    }

    return 0;
}

bool search_ff_is_own_capture(const Board *b, Move m) {
    Piece from_piece;
    Piece to_piece;

    if (b->mod != MOD_FRIENDLY_FIRE) return false;
    if (!(MOVE_IS_CAPTURE(m) || MOVE_IS_EP(m))) return false;
    if (MOVE_IS_EP(m)) return false;

    from_piece = b->mailbox[MOVE_FROM(m)];
    to_piece = b->mailbox[MOVE_TO(m)];
    if (from_piece == PIECE_EMPTY || to_piece == PIECE_EMPTY) return false;
    return PIECE_COLOR(from_piece) == PIECE_COLOR(to_piece);
}

int search_ff_self_capture_score(const Board *b, Move m, Color side) {
    PieceType mover;
    PieceType captured;
    Square from_sq;
    Square to_sq;
    Bitboard occ;
    Bitboard attacks = BB_EMPTY;
    int score = 0;

    if (!search_ff_is_own_capture(b, m)) return 0;

    mover = MOVE_PIECE(m);
    captured = MOVE_CAPTURED(m);
    from_sq = MOVE_FROM(m);
    to_sq = MOVE_TO(m);

    if (captured == PAWN) score += 90;
    else if (captured == KNIGHT || captured == BISHOP) score += 18;
    else return 0;

    if (mover == QUEEN) score += 40;
    else if (mover == ROOK || mover == BISHOP) score += 28;
    else if (mover == KNIGHT) score += 18;
    else if (mover == KING) score += 8;
    else if (mover == PAWN && captured == PAWN) {
        int to_rank = (side == WHITE) ? SQ_ROW(to_sq) : (7 - SQ_ROW(to_sq));

        score += 60;
        if (to_rank >= 3) score += 50;
        if (to_rank >= 4) score += 30;
        if (SQ_COL(from_sq) == 0 || SQ_COL(from_sq) == 7) score += 24;
    }

    if (SQ_ROW(to_sq) >= 2 && SQ_ROW(to_sq) <= 5 &&
        SQ_COL(to_sq) >= 2 && SQ_COL(to_sq) <= 5) {
        score += 70;
    }

    occ = b->all ^ BB_SQ(from_sq);
    if (mover == BISHOP || mover == QUEEN) {
        attacks |= bishop_attacks_calc(to_sq, occ);
    }
    if (mover == ROOK || mover == QUEEN) {
        attacks |= rook_attacks_calc(to_sq, occ);
    }
    if (mover == KNIGHT) attacks |= knight_attacks[to_sq];
    if (mover == KING) attacks |= king_attacks[to_sq];
    if (mover == PAWN) {
        int attack_row = SQ_ROW(to_sq) + ((side == WHITE) ? 1 : -1);
        int file = SQ_COL(to_sq);
        if (attack_row >= 0 && attack_row < 8) {
            if (file > 0) attacks |= BB_SQ(SQ(attack_row, file - 1));
            if (file < 7) attacks |= BB_SQ(SQ(attack_row, file + 1));
        }
    }

    if (b->pieces[color_opposite(side)][KING] != BB_EMPTY) {
        Square king_sq = bb_lsb(b->pieces[color_opposite(side)][KING]);
        int dist = chebyshev_distance_sq(to_sq, king_sq);
        if (BB_HAS(attacks, king_sq)) score += 96;
        if (dist <= 2) score += 44;
        else if (dist == 3) score += 18;
    }

    if (b->pieces[color_opposite(side)][QUEEN] != BB_EMPTY) {
        Square queen_sq = bb_lsb(b->pieces[color_opposite(side)][QUEEN]);
        if (BB_HAS(attacks, queen_sq)) score += 36;
    }

    return score;
}

int search_ff_minor_development_score(const Board *b, Move m, Color side) {
    PieceType piece;
    Square from_sq;
    Square to_sq;
    int back_rank;
    int undeveloped;
    int to_rank;
    int score;

    if (b->mod != MOD_FRIENDLY_FIRE || MOVE_IS_CAPTURE(m) || MOVE_IS_EP(m) ||
        MOVE_IS_PROMO(m)) {
        return 0;
    }

    piece = MOVE_PIECE(m);
    if (piece != KNIGHT && piece != BISHOP) return 0;

    from_sq = MOVE_FROM(m);
    to_sq = MOVE_TO(m);
    back_rank = (side == WHITE) ? 0 : 7;
    if (SQ_ROW(from_sq) != back_rank || SQ_ROW(to_sq) == back_rank) return 0;

    undeveloped = ff_undeveloped_minor_count(b, side);
    to_rank = (side == WHITE) ? SQ_ROW(to_sq) : (7 - SQ_ROW(to_sq));
    score = (piece == KNIGHT) ? 56 : 46;

    if (undeveloped >= 2) score += 14;
    if (undeveloped >= 3) score += 8;
    if (SQ_COL(to_sq) >= 2 && SQ_COL(to_sq) <= 5) score += 12;
    if (to_rank >= 2) score += 8;
    if (piece == BISHOP && to_rank >= 1) score += 8;

    return score;
}

int search_ff_early_queen_sortie_penalty(const Board *b, Move m, Color side) {
    Bitboard king_bb;
    Square from_sq;
    Square to_sq;
    int back_rank;
    int undeveloped;
    int penalty;
    int to_rank;

    if (b->mod != MOD_FRIENDLY_FIRE || MOVE_PIECE(m) != QUEEN ||
        MOVE_IS_CAPTURE(m) || MOVE_IS_EP(m) || MOVE_IS_PROMO(m)) {
        return 0;
    }

    from_sq = MOVE_FROM(m);
    to_sq = MOVE_TO(m);
    back_rank = (side == WHITE) ? 0 : 7;
    if (b->fullmove > 12) return 0;
    if (side == WHITE && !(b->castling & (CASTLE_WK | CASTLE_WQ))) return 0;
    if (side == BLACK && !(b->castling & (CASTLE_BK | CASTLE_BQ))) return 0;
    if (SQ_ROW(from_sq) != back_rank || SQ_ROW(to_sq) == back_rank) {
        return 0;
    }

    undeveloped = ff_undeveloped_minor_count(b, side);
    if (undeveloped <= 1) return 0;

    penalty = 84 + undeveloped * 22;
    king_bb = b->pieces[side][KING];
    if (king_bb != BB_EMPTY) {
        Square king_sq = bb_lsb(king_bb);
        to_rank = (side == WHITE) ? SQ_ROW(to_sq) : (7 - SQ_ROW(to_sq));
        if (SQ_ROW(king_sq) == back_rank && SQ_COL(king_sq) >= 3 && SQ_COL(king_sq) <= 4) {
            penalty += 24;
        }

        if (to_rank <= 2 && chebyshev_distance_sq(to_sq, king_sq) <= 2) {
            penalty -= 32;
            if (board_square_attacked(b, from_sq, color_opposite(side))) {
                penalty -= 24;
            }
        }
    }

    if (penalty < 0) return 0;
    return penalty;
}

int search_ff_quiet_pawn_score(const Board *b, Move m, Color side) {
    Square from_sq;
    Square to_sq;
    Bitboard king_bb;
    Bitboard enemy_king_bb;
    int from_rank;
    int to_rank;
    int file;
    int attack_row;
    int side_pawn_activity;
    int undeveloped;
    int score = 0;

    if (b->mod != MOD_FRIENDLY_FIRE || MOVE_PIECE(m) != PAWN ||
        MOVE_IS_CAPTURE(m) || MOVE_IS_EP(m) || MOVE_IS_PROMO(m)) {
        return 0;
    }
    if (b->fullmove > 16) return 0;

    from_sq = MOVE_FROM(m);
    to_sq = MOVE_TO(m);
    from_rank = (side == WHITE) ? SQ_ROW(from_sq) : (7 - SQ_ROW(from_sq));
    to_rank = (side == WHITE) ? SQ_ROW(to_sq) : (7 - SQ_ROW(to_sq));
    file = SQ_COL(to_sq);
    side_pawn_activity = ff_side_pawn_activity(b, side);
    undeveloped = ff_undeveloped_minor_count(b, side);

    if (from_rank == 1) {
        score += 22;
        score += (to_rank >= 3) ? 18 : 8;
        if (file >= 2 && file <= 5) score += 12;

        if (file == 3 || file == 4) {
            score += 30;
            if (undeveloped >= 2) score += 18;
            if (side_pawn_activity > 0) {
                score += 34 + side_pawn_activity * 10;
            }
        } else if ((file == 2 || file == 5) && side_pawn_activity > 0) {
            score += 22 + side_pawn_activity * 6;
        }

        king_bb = b->pieces[side][KING];
        if (king_bb != BB_EMPTY) {
            Square king_sq = bb_lsb(king_bb);
            if ((side == WHITE && king_sq == SQ(0, 4)) ||
                (side == BLACK && king_sq == SQ(7, 4))) {
                if (file == 3 || file == 4) score += 16;
            }
        }

        if (side_pawn_activity > 0) {
            if (file == 4 && BB_HAS(b->pieces[side][BISHOP], (side == WHITE) ? SQ(0, 5) : SQ(7, 5))) {
                score += 18;
            }
            if (file == 3 && BB_HAS(b->pieces[side][BISHOP], (side == WHITE) ? SQ(0, 2) : SQ(7, 2))) {
                score += 16;
            }
        }
    }

    if ((file == 1 || file == 6) && from_rank >= 3 && to_rank == from_rank + 1) {
        score += 72;
        if (to_rank >= 4) score += 18;
        if (side_pawn_activity > 0) score += 12;
    }

    if (to_rank >= 5 && to_rank == from_rank + 1) {
        int push_row = SQ_ROW(to_sq) + ((side == WHITE) ? 1 : -1);

        score += 26 + (to_rank - 4) * 18;
        if (to_rank >= 6) score += 44;
        if (file >= 2 && file <= 5) score += 10;

        enemy_king_bb = b->pieces[color_opposite(side)][KING];
        if (enemy_king_bb != BB_EMPTY) {
            Square enemy_king_sq = bb_lsb(enemy_king_bb);
            int dist = chebyshev_distance_sq(to_sq, enemy_king_sq);

            if (dist <= 3) score += 16;
            if (abs(file - SQ_COL(enemy_king_sq)) <= 1) score += 14;
        }

        if (push_row >= 0 && push_row < 8 && !BB_HAS(b->all, SQ(push_row, file))) {
            score += 18;
        }
    }

    attack_row = SQ_ROW(to_sq) + ((side == WHITE) ? 1 : -1);
    if (attack_row >= 0 && attack_row < 8) {
        if (file > 0) {
            Piece piece = b->mailbox[SQ(attack_row, file - 1)];
            if (piece != PIECE_EMPTY && PIECE_COLOR(piece) == color_opposite(side)) {
                score += ff_piece_harass_bonus(piece);
            }
        }
        if (file < 7) {
            Piece piece = b->mailbox[SQ(attack_row, file + 1)];
            if (piece != PIECE_EMPTY && PIECE_COLOR(piece) == color_opposite(side)) {
                score += ff_piece_harass_bonus(piece);
            }
        }
    }

    return score;
}

int search_ff_quiet_pressure_score(const Board *b, Move m, Color side) {
    PieceType piece;
    Square from_sq;
    Square to_sq;
    Color opp;
    Bitboard occ;
    Bitboard attacks;
    Bitboard enemy_king_bb;
    Square enemy_king_sq = SQ(0, 4);
    bool has_enemy_king = false;
    int score = 0;
    int target_hits = 0;
    int pawn_hits = 0;

    if (b->mod != MOD_FRIENDLY_FIRE || MOVE_IS_CAPTURE(m) || MOVE_IS_EP(m) ||
        MOVE_IS_PROMO(m)) {
        return 0;
    }

    piece = MOVE_PIECE(m);
    if (piece != KNIGHT && piece != BISHOP && piece != QUEEN) return 0;
    if (piece == QUEEN && search_ff_early_queen_sortie_penalty(b, m, side) > 0) {
        return 0;
    }

    from_sq = MOVE_FROM(m);
    to_sq = MOVE_TO(m);
    opp = color_opposite(side);
    occ = (b->all ^ BB_SQ(from_sq)) | BB_SQ(to_sq);
    attacks = ff_pressure_piece_attacks(piece, to_sq, occ);
    enemy_king_bb = b->pieces[opp][KING];

    if (enemy_king_bb != BB_EMPTY) {
        Bitboard king_zone;
        int zone_hits;

        enemy_king_sq = bb_lsb(enemy_king_bb);
        has_enemy_king = true;
        king_zone = king_attacks[enemy_king_sq] | BB_SQ(enemy_king_sq);
        zone_hits = bb_popcount(attacks & king_zone);
        if (zone_hits > 0) {
            if (piece == KNIGHT) score += zone_hits * 18;
            else if (piece == BISHOP) score += zone_hits * 14;
            else score += zone_hits * 10;
        }
        if (BB_HAS(attacks, enemy_king_sq)) {
            score += (piece == QUEEN) ? 28 : 40;
        }
    }

    if (attacks & b->pieces[opp][QUEEN]) {
        score += 68;
        target_hits++;
    }

    {
        Bitboard rooks = attacks & b->pieces[opp][ROOK];
        Bitboard minors = attacks & (b->pieces[opp][BISHOP] | b->pieces[opp][KNIGHT]);
        Bitboard pawns = attacks & b->pieces[opp][PAWN];
        int rook_hits = bb_popcount(rooks);
        int minor_hits = bb_popcount(minors);

        score += rook_hits * 50;
        score += minor_hits * 36;
        target_hits += rook_hits + minor_hits;

        while (pawns) {
            Square pawn_sq = (Square)bb_pop_lsb(&pawns);
            score += ff_pressure_pawn_bonus(opp, pawn_sq, enemy_king_sq, has_enemy_king);
            pawn_hits++;
        }
    }

    if (piece == KNIGHT) {
        int to_rank = (side == WHITE) ? SQ_ROW(to_sq) : (7 - SQ_ROW(to_sq));

        if (to_rank >= 4) score += 16;
        if (target_hits + pawn_hits >= 2) score += 18;
        if (ff_is_flank_file(SQ_COL(to_sq)) && pawn_hits > 0) score += 10;
    } else if (piece == BISHOP) {
        if (target_hits + pawn_hits >= 2) score += 12;
    } else if (target_hits > 0) {
        score += 12;
    }

    return score;
}

int search_ff_king_safety_score(const Board *b, Move m, Color side) {
    Square from_sq;
    Square to_sq;
    int home_rank;
    int undeveloped;
    int score = 0;
    Bitboard enemy_queen;

    if (b->mod != MOD_FRIENDLY_FIRE || MOVE_PIECE(m) != KING ||
        MOVE_IS_CAPTURE(m) || MOVE_IS_EP(m) || MOVE_IS_PROMO(m)) {
        return 0;
    }

    from_sq = MOVE_FROM(m);
    to_sq = MOVE_TO(m);
    home_rank = (side == WHITE) ? 0 : 7;
    undeveloped = ff_undeveloped_minor_count(b, side);

    if (MOVE_IS_CASTLE(m)) score += 180;

    if (SQ_ROW(from_sq) == home_rank && SQ_ROW(to_sq) == home_rank &&
        (SQ_COL(to_sq) <= 2 || SQ_COL(to_sq) >= 5)) {
        score += 96;
    }

    if ((side == WHITE && SQ_ROW(to_sq) <= 1) ||
        (side == BLACK && SQ_ROW(to_sq) >= 6)) {
        score += ff_pawn_shield_count(b, side, to_sq) * 20;
    }

    if (ff_center_file_distance(to_sq) > ff_center_file_distance(from_sq)) {
        score += 28;
    }

    if (SQ_ROW(from_sq) == home_rank && undeveloped > 0 &&
        !(SQ_ROW(to_sq) == home_rank && (SQ_COL(to_sq) <= 2 || SQ_COL(to_sq) >= 5)) &&
        (SQ_ROW(to_sq) != home_rank || (SQ_COL(to_sq) >= 3 && SQ_COL(to_sq) <= 4))) {
        score -= 90;
    }

    enemy_queen = b->pieces[color_opposite(side)][QUEEN];
    if (enemy_queen != BB_EMPTY) {
        Square queen_sq = bb_lsb(enemy_queen);
        Bitboard cur_ray = bishop_attacks_calc(queen_sq, b->all) |
                           rook_attacks_calc(queen_sq, b->all);
        Bitboard occ_after = (b->all ^ BB_SQ(from_sq)) | BB_SQ(to_sq);
        Bitboard next_ray = bishop_attacks_calc(queen_sq, occ_after) |
                            rook_attacks_calc(queen_sq, occ_after);

        if (BB_HAS(cur_ray, from_sq) && !BB_HAS(next_ray, to_sq)) score += 44;
        if (!BB_HAS(cur_ray, from_sq) && BB_HAS(next_ray, to_sq)) score -= 32;
    }

    {
        Board next = *b;
        Square next_king_sq;
        bool from_hot;
        bool to_hot;

        board_make_move(&next, m);
        next_king_sq = bb_lsb(next.pieces[side][KING]);
        from_hot = board_square_attacked(b, from_sq, color_opposite(side));
        to_hot = board_square_attacked(&next, next_king_sq, color_opposite(side));

        if (from_hot && !to_hot) score += 64;
        if (!from_hot && to_hot) score -= 96;
    }

    return score;
}

int search_ff_king_zone_guard_score(const Board *b, Move m, Color side) {
    Bitboard king_bb;
    Square king_sq;
    Square from_sq;
    Square to_sq;
    PieceType piece;
    Bitboard occ_before;
    Bitboard occ_after;
    Bitboard king_zone;
    int from_dist;
    int to_dist;
    int shield;
    int before_cover;
    int after_cover;
    int score = 0;

    if (b->mod != MOD_FRIENDLY_FIRE || MOVE_IS_CAPTURE(m) || MOVE_IS_EP(m) ||
        MOVE_IS_PROMO(m)) {
        return 0;
    }

    piece = MOVE_PIECE(m);
    if (piece != BISHOP && piece != QUEEN) return 0;

    king_bb = b->pieces[side][KING];
    if (king_bb == BB_EMPTY) return 0;

    king_sq = bb_lsb(king_bb);
    from_sq = MOVE_FROM(m);
    to_sq = MOVE_TO(m);
    from_dist = chebyshev_distance_sq(from_sq, king_sq);
    to_dist = chebyshev_distance_sq(to_sq, king_sq);
    shield = ff_pawn_shield_count(b, side, king_sq);

    if (piece == QUEEN) {
        int back_rank = (side == WHITE) ? 0 : 7;
        if (SQ_ROW(from_sq) == back_rank) {
            int to_rank = (side == WHITE) ? SQ_ROW(to_sq) : (7 - SQ_ROW(to_sq));

            if (to_rank > 2 || to_dist > 2) return 0;
        }
    }

    if (b->fullmove > 18 && shield >= 2 && to_dist >= from_dist) return 0;

    occ_before = b->all ^ BB_SQ(from_sq);
    occ_after = occ_before | BB_SQ(to_sq);
    king_zone = king_attacks[king_sq] | BB_SQ(king_sq);
    before_cover = bb_popcount(ff_guard_piece_attacks(piece, from_sq, occ_before) & king_zone);
    after_cover = bb_popcount(ff_guard_piece_attacks(piece, to_sq, occ_after) & king_zone);

    if (after_cover > before_cover) {
        score += (after_cover - before_cover) * 44;
    }

    if (to_dist < from_dist && to_dist <= 3) {
        score += (from_dist - to_dist) * 26;
    }

    if (BB_HAS(king_zone, to_sq)) score += 24;
    if (piece == BISHOP && to_dist <= 1) score += 26;
    if (piece == QUEEN && to_dist <= 2) score += 20;
    if (shield <= 1 && to_dist <= 2) score += 18;

    if (piece == QUEEN && SQ_ROW(from_sq) == ((side == WHITE) ? 0 : 7)) {
        score /= 2;
        if (board_square_attacked(b, from_sq, color_opposite(side))) score += 16;
    }

    return score;
}

int search_ff_self_capture_prep_score(const Board *b, Move m, Color side) {
    PieceType piece;
    int score = 0;
    int ray_score;

    if (b->mod != MOD_FRIENDLY_FIRE || MOVE_IS_CAPTURE(m) || MOVE_IS_EP(m) ||
        MOVE_IS_PROMO(m)) {
        return 0;
    }

    piece = MOVE_PIECE(m);
    if (piece != BISHOP && piece != QUEEN) return 0;
    if (piece == QUEEN && search_ff_early_queen_sortie_penalty(b, m, side) > 0) {
        return 0;
    }

    ray_score = ff_self_capture_prep_ray_score(
        b, MOVE_FROM(m), MOVE_TO(m), side, 1, 1
    );
    if (ray_score > score) score = ray_score;
    ray_score = ff_self_capture_prep_ray_score(
        b, MOVE_FROM(m), MOVE_TO(m), side, 1, -1
    );
    if (ray_score > score) score = ray_score;
    ray_score = ff_self_capture_prep_ray_score(
        b, MOVE_FROM(m), MOVE_TO(m), side, -1, 1
    );
    if (ray_score > score) score = ray_score;
    ray_score = ff_self_capture_prep_ray_score(
        b, MOVE_FROM(m), MOVE_TO(m), side, -1, -1
    );
    if (ray_score > score) score = ray_score;

    if (piece == QUEEN) {
        ray_score = ff_self_capture_prep_ray_score(
            b, MOVE_FROM(m), MOVE_TO(m), side, 1, 0
        );
        if (ray_score > score) score = ray_score;
        ray_score = ff_self_capture_prep_ray_score(
            b, MOVE_FROM(m), MOVE_TO(m), side, -1, 0
        );
        if (ray_score > score) score = ray_score;
        ray_score = ff_self_capture_prep_ray_score(
            b, MOVE_FROM(m), MOVE_TO(m), side, 0, 1
        );
        if (ray_score > score) score = ray_score;
        ray_score = ff_self_capture_prep_ray_score(
            b, MOVE_FROM(m), MOVE_TO(m), side, 0, -1
        );
        if (ray_score > score) score = ray_score;
    }

    return score;
}

int search_ff_pawn_challenge_penalty(const Board *b, Move m, Color side) {
    PieceType piece;
    Square from_sq;
    Square to_sq;
    Color opp;
    Bitboard occ;
    Bitboard pawns;
    int penalty = 0;

    if (b->mod != MOD_FRIENDLY_FIRE || MOVE_IS_CAPTURE(m) || MOVE_IS_EP(m) ||
        MOVE_IS_PROMO(m)) {
        return 0;
    }

    piece = MOVE_PIECE(m);
    if (piece != KNIGHT && piece != BISHOP && piece != QUEEN) return 0;

    from_sq = MOVE_FROM(m);
    to_sq = MOVE_TO(m);
    opp = color_opposite(side);
    occ = (b->all ^ BB_SQ(from_sq)) | BB_SQ(to_sq);
    pawns = b->pieces[opp][PAWN];

    while (pawns) {
        Square pawn_sq = (Square)bb_pop_lsb(&pawns);
        int file = SQ_COL(pawn_sq);
        int row = SQ_ROW(pawn_sq);
        int step = (opp == WHITE) ? 1 : -1;
        int attack_row = row + step;

        if (attack_row >= 0 && attack_row < 8) {
            if ((file > 0 && SQ(attack_row, file - 1) == to_sq) ||
                (file < 7 && SQ(attack_row, file + 1) == to_sq)) {
                int current = ff_piece_challenge_penalty(piece, true);
                if (current > penalty) penalty = current;
                continue;
            }
        }

        if (row + step < 0 || row + step > 7) continue;
        if (BB_HAS(occ, SQ(row + step, file))) continue;

        attack_row = row + step + step;
        if (attack_row < 0 || attack_row > 7) continue;

        if ((file > 0 && SQ(attack_row, file - 1) == to_sq) ||
            (file < 7 && SQ(attack_row, file + 1) == to_sq)) {
            int projected = ff_piece_challenge_penalty(piece, false);
            if (projected > penalty) penalty = projected;
        }
    }

    return penalty;
}

int search_ff_flank_pawn_harass_penalty(const Board *b, Move m, Color side) {
    PieceType piece;
    Square to_sq;
    Color opp;
    Bitboard pawns;
    int penalty = 0;

    if (b->mod != MOD_FRIENDLY_FIRE || MOVE_IS_CAPTURE(m) || MOVE_IS_EP(m) ||
        MOVE_IS_PROMO(m)) {
        return 0;
    }

    piece = MOVE_PIECE(m);
    if (piece != KNIGHT && piece != BISHOP && piece != QUEEN) return 0;

    to_sq = MOVE_TO(m);
    opp = color_opposite(side);
    pawns = b->pieces[opp][PAWN];

    while (pawns) {
        Square pawn_sq = (Square)bb_pop_lsb(&pawns);
        int file = SQ_COL(pawn_sq);
        int rank = (opp == WHITE) ? SQ_ROW(pawn_sq) : (7 - SQ_ROW(pawn_sq));
        int attack_row;
        int push_row;

        if (!ff_is_flank_file(file) || rank < 3) continue;

        attack_row = SQ_ROW(pawn_sq) + ((opp == WHITE) ? 1 : -1);
        if (attack_row >= 0 && attack_row < 8) {
            if ((file > 0 && SQ(attack_row, file - 1) == to_sq) ||
                (file < 7 && SQ(attack_row, file + 1) == to_sq)) {
                int current = (piece == KNIGHT) ? 44 : (piece == BISHOP) ? 30 : 18;
                if (current > penalty) penalty = current;
            }
        }

        push_row = SQ_ROW(pawn_sq) + ((opp == WHITE) ? 1 : -1);
        if (push_row < 0 || push_row > 7) continue;
        if (BB_HAS(b->all, SQ(push_row, file))) continue;

        attack_row = push_row + ((opp == WHITE) ? 1 : -1);
        if (attack_row < 0 || attack_row > 7) continue;

        if ((file > 0 && SQ(attack_row, file - 1) == to_sq) ||
            (file < 7 && SQ(attack_row, file + 1) == to_sq)) {
            int projected = (piece == KNIGHT) ? 84 : (piece == BISHOP) ? 56 : 36;
            if (projected > penalty) penalty = projected;
        }
    }

    if (piece == QUEEN) penalty /= 2;
    return penalty;
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

bool search_kb_full_skill_variety_enabled(const Board *b) {
    return b->mod == MOD_KINGS_BATTLE &&
           !b->kb_unlocked &&
           b->fullmove <= 4 &&
           BB_HAS(b->pieces[WHITE][KING], SQ(0, 4)) &&
           BB_HAS(b->pieces[BLACK][KING], SQ(7, 4));
}

int search_kb_full_skill_variety_margin(const Board *b) {
    return search_kb_full_skill_variety_enabled(b) ? 20 : 0;
}

int search_kb_full_skill_tiebreak_band(const Board *b) {
    return search_kb_full_skill_variety_enabled(b) ? 15 : 0;
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