#include "variant_heuristics.h"
#include <stdlib.h>

static inline int chebyshev_distance_sq(Square a, Square b) {
    int dr = abs(SQ_ROW(a) - SQ_ROW(b));
    int dc = abs(SQ_COL(a) - SQ_COL(b));
    return dr > dc ? dr : dc;
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
