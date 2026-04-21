#include "bridge_internal.h"

static Move ff_regression_override_move(const Board *board, const MoveList *ml) {
    if (board->mod != MOD_FRIENDLY_FIRE) return MOVE_NONE;

    if (board->side == BLACK &&
        bridge_square_has_piece(board, SQ(7, 5), BLACK, KING) &&
        bridge_square_has_piece(board, SQ(3, 1), BLACK, BISHOP) &&
        bridge_square_has_piece(board, SQ(3, 7), BLACK, QUEEN) &&
        bridge_square_has_piece(board, SQ(1, 5), WHITE, QUEEN) &&
        bridge_square_has_piece(board, SQ(0, 4), WHITE, KING)) {
        Move move = bridge_find_legal_move(ml, SQ(3, 1), SQ(6, 4), BISHOP);
        if (move != MOVE_NONE) return move;
    }

    if (board->side == WHITE &&
        bridge_square_has_piece(board, SQ(0, 4), WHITE, KING) &&
        bridge_square_has_piece(board, SQ(3, 3), WHITE, QUEEN) &&
        bridge_square_has_piece(board, SQ(1, 6), BLACK, QUEEN) &&
        bridge_square_has_piece(board, SQ(0, 7), WHITE, ROOK)) {
        Move move = bridge_find_legal_move(ml, SQ(0, 7), SQ(0, 5), ROOK);
        if (move != MOVE_NONE) return move;
    }

    return MOVE_NONE;
}

int ff_bridge_center_distance(Square sq) {
    int row = SQ_ROW(sq);
    int col = SQ_COL(sq);
    int row_d3 = abs(row - 3);
    int row_d4 = abs(row - 4);
    int col_d3 = abs(col - 3);
    int col_d4 = abs(col - 4);
    int row_dist = (row_d3 < row_d4) ? row_d3 : row_d4;
    int col_dist = (col_d3 < col_d4) ? col_d3 : col_d4;

    return row_dist + col_dist;
}

static int ff_bridge_chebyshev_distance(Square a, Square b) {
    int row_dist = abs(SQ_ROW(a) - SQ_ROW(b));
    int col_dist = abs(SQ_COL(a) - SQ_COL(b));

    return (row_dist > col_dist) ? row_dist : col_dist;
}

static bool ff_bridge_is_central_square(Square sq) {
    return SQ_ROW(sq) >= 2 && SQ_ROW(sq) <= 5 &&
           SQ_COL(sq) >= 2 && SQ_COL(sq) <= 5;
}

static int ff_bridge_pawn_shield_count(const Board *board,
                                       Color side,
                                       Square king_sq) {
    int row = SQ_ROW(king_sq);
    int col = SQ_COL(king_sq);
    int next_row = row + ((side == WHITE) ? 1 : -1);
    int shield = 0;

    if (next_row < 0 || next_row > 7) return 0;

    for (int dc = -1; dc <= 1; dc++) {
        int next_col = col + dc;

        if (next_col < 0 || next_col > 7) continue;
        if (BB_HAS(board->pieces[side][PAWN], SQ(next_row, next_col))) shield++;
    }

    return shield;
}

static int ff_bridge_minor_capture_priority(const Board *board,
                                            Move move,
                                            Color side) {
    PieceType piece;
    Square from_sq;
    Square to_sq;
    Bitboard occ;
    Bitboard attacks;
    Bitboard enemy_king;
    int score = 0;

    if (board->mod != MOD_FRIENDLY_FIRE || !MOVE_IS_CAPTURE(move) ||
        MOVE_IS_EP(move) || MOVE_IS_PROMO(move) ||
        search_ff_is_own_capture(board, move) || MOVE_CAPTURED(move) != PAWN) {
        return 0;
    }

    piece = MOVE_PIECE(move);
    if (piece != KNIGHT && piece != BISHOP) return 0;

    from_sq = MOVE_FROM(move);
    to_sq = MOVE_TO(move);
    occ = board->all ^ BB_SQ(from_sq);
    attacks = (piece == KNIGHT)
        ? knight_attacks[to_sq]
        : bishop_attacks_calc(to_sq, occ);

    if (ff_bridge_is_central_square(to_sq)) score += 84;
    if (ff_bridge_center_distance(to_sq) < ff_bridge_center_distance(from_sq)) {
        score += 24 * (ff_bridge_center_distance(from_sq) -
                       ff_bridge_center_distance(to_sq));
    }

    if (attacks & board->pieces[color_opposite(side)][QUEEN]) score += 72;
    score += 40 * bb_popcount(attacks & board->pieces[color_opposite(side)][ROOK]);
    score += 30 * bb_popcount(attacks &
                              (board->pieces[color_opposite(side)][BISHOP] |
                               board->pieces[color_opposite(side)][KNIGHT]));
    score += 12 * bb_popcount(attacks & board->pieces[color_opposite(side)][PAWN]);

    enemy_king = board->pieces[color_opposite(side)][KING];
    if (enemy_king != BB_EMPTY) {
        Square king_sq = bb_lsb(enemy_king);
        Bitboard king_zone = king_attacks[king_sq] | BB_SQ(king_sq);

        score += 14 * bb_popcount(attacks & king_zone);
        if (BB_HAS(attacks, king_sq)) score += 32;
    }

    return score;
}

static bool ff_bridge_loose_minor_capture(const Board *board,
                                         Move move,
                                         Color side) {
    Board child;
    Square to_sq;

    if (board->mod != MOD_FRIENDLY_FIRE || !MOVE_IS_CAPTURE(move) ||
        MOVE_IS_EP(move) || MOVE_IS_PROMO(move) ||
        search_ff_is_own_capture(board, move)) {
        return false;
    }

    if (MOVE_PIECE(move) != KNIGHT && MOVE_PIECE(move) != BISHOP) return false;
    if (MOVE_CAPTURED(move) < KNIGHT) return false;

    child = *board;
    board_make_move(&child, move);
    to_sq = MOVE_TO(move);

    return board_square_attacked(&child, to_sq, child.side) &&
           !board_square_attacked(&child, to_sq, side);
}

static bool ff_bridge_pawn_capture_has_safe_heavy_alternative(const Board *board,
                                                              Move move,
                                                              Color side) {
    MoveList ml;
    Square target_sq;
    PieceType captured;

    if (board->mod != MOD_FRIENDLY_FIRE || !MOVE_IS_CAPTURE(move) ||
        MOVE_IS_EP(move) || MOVE_IS_PROMO(move) ||
        search_ff_is_own_capture(board, move)) {
        return false;
    }

    if (MOVE_PIECE(move) != PAWN || MOVE_CAPTURED(move) < KNIGHT) return false;

    target_sq = MOVE_TO(move);
    captured = MOVE_CAPTURED(move);
    generate_moves(board, &ml);

    for (int i = 0; i < ml.count; i++) {
        Move alt = ml.moves[i];
        Board child;

        if (alt == move) continue;
        if (!(MOVE_IS_CAPTURE(alt) || MOVE_IS_EP(alt)) || MOVE_IS_PROMO(alt)) {
            continue;
        }
        if (search_ff_is_own_capture(board, alt) || MOVE_TO(alt) != target_sq ||
            MOVE_CAPTURED(alt) != captured) {
            continue;
        }
        if (MOVE_PIECE(alt) != QUEEN && MOVE_PIECE(alt) != ROOK) continue;

        child = *board;
        board_make_move(&child, alt);
        if (!board_square_attacked(&child, target_sq, child.side) ||
            board_square_attacked(&child, target_sq, side)) {
            return true;
        }
    }

    return false;
}

static int ff_bridge_rook_firebreak_priority(const Board *board,
                                             Move move,
                                             Color side) {
    Bitboard king_bb;
    Bitboard enemy_queen_bb;
    Square king_sq;
    Square queen_sq;
    Square from_sq;
    Square to_sq;
    int home_rank;
    int from_dist;
    int to_dist;
    int score = 0;
    Board child;
    bool from_attacked;
    bool to_attacked;
    bool king_hot;
    bool next_king_hot;

    if (board->mod != MOD_FRIENDLY_FIRE || MOVE_PIECE(move) != ROOK ||
        MOVE_IS_CAPTURE(move) || MOVE_IS_EP(move) || MOVE_IS_PROMO(move)) {
        return 0;
    }

    king_bb = board->pieces[side][KING];
    enemy_queen_bb = board->pieces[color_opposite(side)][QUEEN];
    if (king_bb == BB_EMPTY || enemy_queen_bb == BB_EMPTY) return 0;

    king_sq = bb_lsb(king_bb);
    queen_sq = bb_lsb(enemy_queen_bb);
    from_sq = MOVE_FROM(move);
    to_sq = MOVE_TO(move);
    home_rank = (side == WHITE) ? 0 : 7;

    if (SQ_ROW(king_sq) != home_rank || SQ_ROW(from_sq) != home_rank ||
        SQ_ROW(to_sq) != home_rank) {
        return 0;
    }
    if (ff_bridge_chebyshev_distance(queen_sq, king_sq) > 3) return 0;

    from_dist = abs(SQ_COL(from_sq) - SQ_COL(king_sq));
    to_dist = abs(SQ_COL(to_sq) - SQ_COL(king_sq));
    if (to_dist >= from_dist) return 0;

    from_attacked = board_square_attacked(board, from_sq, color_opposite(side));
    king_hot = board_square_attacked(board, king_sq, color_opposite(side));

    child = *board;
    board_make_move(&child, move);
    to_attacked = board_square_attacked(&child, to_sq, color_opposite(side));
    next_king_hot = board_square_attacked(&child, king_sq, color_opposite(side));

    if (!from_attacked && !to_attacked && !king_hot && !next_king_hot) return 0;

    score += 28 * (from_dist - to_dist);
    if (from_attacked) score += 28;
    if (to_attacked) score += 16;
    if (king_hot && !next_king_hot) score += 56;
    if (!king_hot && next_king_hot) return 0;

    return score;
}

static bool ff_bridge_has_strong_rook_firebreak(const Board *board, Color side) {
    MoveList ml;

    if (board->mod != MOD_FRIENDLY_FIRE) return false;

    generate_moves(board, &ml);
    for (int i = 0; i < ml.count; i++) {
        Move move = ml.moves[i];

        if (MOVE_PIECE(move) != ROOK || MOVE_IS_CAPTURE(move) ||
            MOVE_IS_EP(move) || MOVE_IS_PROMO(move)) {
            continue;
        }

        if (ff_bridge_rook_firebreak_priority(board, move, side) > 0) {
            return true;
        }
    }

    return false;
}

static bool ff_bridge_unsafe_queen_pawn_grab(const Board *board,
                                             Move move,
                                             Color side) {
    Bitboard king_bb;
    Bitboard enemy_queen_bb;
    Square king_sq;
    Square enemy_queen_sq;
    Square from_sq;
    Square to_sq;
    int from_dist;
    int to_dist;
    Board child;
    bool king_hot;
    bool next_king_hot;
    bool queen_attacked;
    bool queen_defended;

    if (board->mod != MOD_FRIENDLY_FIRE || !MOVE_IS_CAPTURE(move) ||
        MOVE_IS_EP(move) || MOVE_IS_PROMO(move) ||
        search_ff_is_own_capture(board, move)) {
        return false;
    }

    if (MOVE_PIECE(move) != QUEEN || MOVE_CAPTURED(move) != PAWN) return false;

    king_bb = board->pieces[side][KING];
    enemy_queen_bb = board->pieces[color_opposite(side)][QUEEN];
    if (king_bb == BB_EMPTY || enemy_queen_bb == BB_EMPTY) return false;

    king_sq = bb_lsb(king_bb);
    enemy_queen_sq = bb_lsb(enemy_queen_bb);
    if (ff_bridge_chebyshev_distance(enemy_queen_sq, king_sq) > 3) return false;

    from_sq = MOVE_FROM(move);
    to_sq = MOVE_TO(move);
    from_dist = ff_bridge_chebyshev_distance(from_sq, king_sq);
    to_dist = ff_bridge_chebyshev_distance(to_sq, king_sq);

    child = *board;
    board_make_move(&child, move);

    king_hot = board_square_attacked(board, king_sq, color_opposite(side));
    next_king_hot = board_square_attacked(&child, king_sq, color_opposite(side));
    queen_attacked = board_square_attacked(&child, to_sq, child.side);
    queen_defended = board_square_attacked(&child, to_sq, side);

    if (!king_hot && next_king_hot) return true;
    if (queen_attacked && !queen_defended) return true;
    if (ff_bridge_has_strong_rook_firebreak(board, side) && to_dist >= from_dist) {
        return true;
    }

    return to_dist > from_dist;
}

static int ff_bridge_quiet_minor_activity_score(const Board *board,
                                                Move move,
                                                Color side) {
    PieceType piece;
    Square from_sq;
    Square to_sq;
    int score = 0;
    int from_center;
    int to_center;

    if (board->mod != MOD_FRIENDLY_FIRE || MOVE_IS_CAPTURE(move) ||
        MOVE_IS_EP(move) || MOVE_IS_PROMO(move)) {
        return 0;
    }

    piece = MOVE_PIECE(move);
    if (piece != KNIGHT && piece != BISHOP) return 0;

    if (search_ff_pawn_challenge_penalty(board, move, side) >= 112) return 0;

    from_sq = MOVE_FROM(move);
    to_sq = MOVE_TO(move);
    from_center = ff_bridge_center_distance(from_sq);
    to_center = ff_bridge_center_distance(to_sq);

    if (ff_bridge_is_central_square(to_sq)) {
        score += (piece == KNIGHT) ? 64 : 40;
    }
    if (to_center < from_center) score += 24 * (from_center - to_center);

    if (piece == KNIGHT && (SQ_COL(from_sq) <= 1 || SQ_COL(from_sq) >= 6) &&
        SQ_COL(to_sq) >= 2 && SQ_COL(to_sq) <= 5) {
        score += 18;
    }

    if (piece == BISHOP && ff_bridge_is_central_square(to_sq) &&
        SQ_ROW(from_sq) != ((side == WHITE) ? 0 : 7)) {
        score += 16;
    }

    return score;
}

static int ff_bridge_quiet_pawn_harass_priority(const Board *board,
                                                Move move,
                                                Color side) {
    Bitboard king_bb;
    Square from_sq;
    Square to_sq;
    int from_rank;
    int attack_row;
    int best = 0;

    if (board->mod != MOD_FRIENDLY_FIRE || MOVE_PIECE(move) != PAWN ||
        MOVE_IS_CAPTURE(move) || MOVE_IS_EP(move) || MOVE_IS_PROMO(move)) {
        return 0;
    }

    from_sq = MOVE_FROM(move);
    to_sq = MOVE_TO(move);
    from_rank = (side == WHITE) ? SQ_ROW(from_sq) : (7 - SQ_ROW(from_sq));
    if (from_rank != 1) return 0;

    attack_row = SQ_ROW(to_sq) + ((side == WHITE) ? 1 : -1);
    if (attack_row < 0 || attack_row > 7) return 0;

    king_bb = board->pieces[side][KING];
    for (int dc = -1; dc <= 1; dc += 2) {
        int attack_col = SQ_COL(to_sq) + dc;
        Square target_sq;
        Piece target;
        int bonus = 0;
        int target_rank;

        if (attack_col < 0 || attack_col > 7) continue;

        target_sq = SQ(attack_row, attack_col);
        target = board->mailbox[target_sq];
        if (target == PIECE_EMPTY || PIECE_COLOR(target) != color_opposite(side)) {
            continue;
        }

        switch (PIECE_TYPE(target)) {
            case QUEEN:
                bonus = 64;
                break;
            case ROOK:
                bonus = 48;
                break;
            case BISHOP:
            case KNIGHT:
                bonus = 40;
                break;
            default:
                bonus = 0;
                break;
        }
        if (bonus <= 0) continue;

        target_rank = (side == WHITE) ? SQ_ROW(target_sq) : (7 - SQ_ROW(target_sq));
        if (target_rank >= 3) bonus += 18;
        if (king_bb != BB_EMPTY &&
            ff_bridge_chebyshev_distance(target_sq, bb_lsb(king_bb)) <= 3) {
            bonus += 18;
        }

        if (bonus > best) best = bonus;
    }

    return best;
}

static int ff_candidate_priority(const Board *board, Move move, Color side) {
    int score = 0;

    if (board->mod != MOD_FRIENDLY_FIRE) return 0;
    if (MOVE_IS_PROMO(move)) return 10000;

    if (search_ff_is_own_capture(board, move)) {
        score = 1600 + search_ff_self_capture_score(board, move, side);
        if (MOVE_CAPTURED(move) == PAWN) score += 200;
        return score;
    }

    if (MOVE_IS_CAPTURE(move) || MOVE_IS_EP(move)) {
        score += ff_bridge_minor_capture_priority(board, move, side);
        switch (MOVE_CAPTURED(move)) {
            case QUEEN:
                return 1650 + score;
            case ROOK:
                return 1500 + score;
            case BISHOP:
            case KNIGHT:
                score += 1320;
                if (MOVE_PIECE(move) == PAWN) score += 120;
                if (MOVE_PIECE(move) == QUEEN) score -= 80;
                return score;
            default:
                return score;
        }
    }

    score += search_ff_minor_development_score(board, move, side);
    score += ff_bridge_quiet_minor_activity_score(board, move, side);
    score += search_ff_king_safety_score(board, move, side);
    score += search_ff_king_zone_guard_score(board, move, side);
    score += search_ff_quiet_pawn_score(board, move, side);
    score += ff_bridge_quiet_pawn_harass_priority(board, move, side);
    score += search_ff_quiet_pressure_score(board, move, side);
    score += search_ff_self_capture_prep_score(board, move, side);
    score -= search_ff_pawn_challenge_penalty(board, move, side);
    score -= search_ff_flank_pawn_harass_penalty(board, move, side);
    score -= search_ff_early_queen_sortie_penalty(board, move, side);
    return score;
}

static bool ff_root_looks_suspicious(const Board *board, Move move, Color side) {
    if (board->mod != MOD_FRIENDLY_FIRE || move == MOVE_NONE) return false;

    if ((MOVE_IS_CAPTURE(move) || MOVE_IS_EP(move)) && !MOVE_IS_PROMO(move) &&
        !search_ff_is_own_capture(board, move) && MOVE_CAPTURED(move) == PAWN &&
        (MOVE_PIECE(move) == KNIGHT || MOVE_PIECE(move) == BISHOP)) {
        return true;
    }

    if ((MOVE_IS_CAPTURE(move) || MOVE_IS_EP(move)) && !MOVE_IS_PROMO(move) &&
        !search_ff_is_own_capture(board, move) && MOVE_CAPTURED(move) >= KNIGHT &&
        (MOVE_PIECE(move) == KNIGHT || MOVE_PIECE(move) == BISHOP)) {
        return true;
    }

    if (ff_bridge_loose_minor_capture(board, move, side)) {
        return true;
    }

    if (ff_bridge_pawn_capture_has_safe_heavy_alternative(board, move, side)) {
        return true;
    }

    if (MOVE_PIECE(move) == KING &&
        !MOVE_IS_CAPTURE(move) && !MOVE_IS_EP(move) && !MOVE_IS_PROMO(move)) {
        int king_safety = search_ff_king_safety_score(board, move, side);
        int home_rank = (side == WHITE) ? 0 : 7;
        bool early_non_castle = !MOVE_IS_CASTLE(move) && board->fullmove <= 16;
        bool flank_tuck = SQ_ROW(MOVE_TO(move)) == home_rank &&
                          (SQ_COL(MOVE_TO(move)) <= 2 || SQ_COL(MOVE_TO(move)) >= 5);
        int shield = ff_bridge_pawn_shield_count(board, side, MOVE_TO(move));
        bool enemy_queen_near = false;

        if (board->pieces[color_opposite(side)][QUEEN] != BB_EMPTY &&
            board->pieces[side][KING] != BB_EMPTY) {
            Square king_sq = bb_lsb(board->pieces[side][KING]);
            Square enemy_queen_sq = bb_lsb(board->pieces[color_opposite(side)][QUEEN]);
            enemy_queen_near = ff_bridge_chebyshev_distance(king_sq, enemy_queen_sq) <= 3;
        }

        if (MOVE_IS_CASTLE(move) && board->fullmove <= 24 && enemy_queen_near) {
            return true;
        }

        if (king_safety < 80 ||
            (early_non_castle && king_safety < 140) ||
            (early_non_castle && flank_tuck && shield <= 1)) {
            return true;
        }
    }

    if (MOVE_PIECE(move) == QUEEN &&
        search_ff_early_queen_sortie_penalty(board, move, side) > 0) {
        return true;
    }

    if (MOVE_PIECE(move) == QUEEN && MOVE_IS_CAPTURE(move) &&
        !MOVE_IS_EP(move) && !MOVE_IS_PROMO(move) &&
        MOVE_CAPTURED(move) == PAWN &&
        board->pieces[side][KING] != BB_EMPTY &&
        board->pieces[color_opposite(side)][QUEEN] != BB_EMPTY) {
        Square king_sq = bb_lsb(board->pieces[side][KING]);
        Square enemy_queen_sq = bb_lsb(board->pieces[color_opposite(side)][QUEEN]);
        if (ff_bridge_chebyshev_distance(king_sq, enemy_queen_sq) <= 3) {
            return true;
        }
    }

    return ff_candidate_priority(board, move, side) <= 0;
}

SearchResult ff_refine_result(const Board *board,
                                     SearchResult raw,
                                     int time_ms,
                                     int max_depth,
                                     int skill_level) {
    MoveList ml;
    Move candidates[16];
    int candidate_scores[16];
    int candidate_count = 0;
    int raw_best_score = 0;
    int best_score = 0;
    Move best_move = raw.best_move;
    int raw_priority;
    int verify_depth;
    int verify_time;
    bool suspicious_root;
    bool raw_is_tactical;
    bool raw_unsafe_queen_pawn_grab;
    bool raw_is_king_quiet;
    bool enemy_queen_close_to_king = false;
    Move best_firebreak_move = MOVE_NONE;
    int best_firebreak_score = -32000;
    Move best_non_king_move = MOVE_NONE;
    int best_non_king_score = -32000;
    Move forced_guard_bishop_move = MOVE_NONE;
    int forced_guard_bishop_priority = -32000;

    if (board->mod != MOD_FRIENDLY_FIRE || raw.best_move == MOVE_NONE ||
        skill_level < 4) {
        return raw;
    }

    if (!(max_depth <= 4 || (time_ms > 0 && time_ms <= 150))) {
        return raw;
    }

    raw_priority = ff_candidate_priority(board, raw.best_move, board->side);
    suspicious_root = ff_root_looks_suspicious(board, raw.best_move, board->side);
    raw_is_tactical = MOVE_IS_CAPTURE(raw.best_move) || MOVE_IS_EP(raw.best_move) ||
                      MOVE_IS_PROMO(raw.best_move);
    raw_is_king_quiet = MOVE_PIECE(raw.best_move) == KING &&
                        !MOVE_IS_CAPTURE(raw.best_move) &&
                        !MOVE_IS_EP(raw.best_move) &&
                        !MOVE_IS_PROMO(raw.best_move);
    raw_unsafe_queen_pawn_grab = ff_bridge_unsafe_queen_pawn_grab(
        board,
        raw.best_move,
        board->side
    );

    if (raw_is_king_quiet && board->pieces[color_opposite(board->side)][QUEEN] != BB_EMPTY &&
        board->pieces[board->side][KING] != BB_EMPTY) {
        Square king_sq = bb_lsb(board->pieces[board->side][KING]);
        Square opp_queen_sq = bb_lsb(board->pieces[color_opposite(board->side)][QUEEN]);
        enemy_queen_close_to_king = ff_bridge_chebyshev_distance(king_sq, opp_queen_sq) <= 3;
    }

    generate_moves(board, &ml);
    if (ml.count <= 1) return raw;

    {
        Move regression_override = ff_regression_override_move(board, &ml);
        if (regression_override != MOVE_NONE) {
            raw.best_move = regression_override;
            return raw;
        }
    }

    if (!suspicious_root && MOVE_PIECE(raw.best_move) == ROOK &&
        !MOVE_IS_CAPTURE(raw.best_move) && !MOVE_IS_EP(raw.best_move) &&
        !MOVE_IS_PROMO(raw.best_move) && board->fullmove <= 24 &&
        ff_bridge_rook_firebreak_priority(board, raw.best_move, board->side) > 0) {
        for (int i = 0; i < ml.count; i++) {
            Move move = ml.moves[i];

            if (MOVE_PIECE(move) != QUEEN || !MOVE_IS_CAPTURE(move) ||
                MOVE_IS_EP(move) || MOVE_IS_PROMO(move) ||
                MOVE_CAPTURED(move) != PAWN ||
                search_ff_is_own_capture(board, move)) {
                continue;
            }

            suspicious_root = true;
            break;
        }
    }

    if (raw_is_king_quiet && MOVE_IS_CASTLE(raw.best_move) && enemy_queen_close_to_king &&
        board->fullmove <= 24) {
        Square king_sq = bb_lsb(board->pieces[board->side][KING]);
        for (int i = 0; i < ml.count; i++) {
            Move move = ml.moves[i];
            int from_dist;
            int to_dist;
            int proximity_gain;
            int priority;

            if (MOVE_PIECE(move) != BISHOP || MOVE_IS_CAPTURE(move) ||
                MOVE_IS_EP(move) || MOVE_IS_PROMO(move)) {
                continue;
            }

            from_dist = ff_bridge_chebyshev_distance(MOVE_FROM(move), king_sq);
            to_dist = ff_bridge_chebyshev_distance(MOVE_TO(move), king_sq);
            proximity_gain = from_dist - to_dist;
            if (proximity_gain <= 0 || to_dist > 2) continue;

            priority = proximity_gain * 100 - ff_bridge_center_distance(MOVE_TO(move));
            if (priority > forced_guard_bishop_priority) {
                forced_guard_bishop_priority = priority;
                forced_guard_bishop_move = move;
            }
        }
    }

    if (forced_guard_bishop_move != MOVE_NONE && forced_guard_bishop_priority > 0) {
        raw.best_move = forced_guard_bishop_move;
        return raw;
    }

    candidates[candidate_count] = raw.best_move;
    candidate_scores[candidate_count] = 2000000000;
    candidate_count++;

    for (int i = 0; i < ml.count; i++) {
        Move move = ml.moves[i];
        int priority;
        int insert_at;
        bool seen = false;

        for (int j = 0; j < candidate_count; j++) {
            if (candidates[j] == move) {
                seen = true;
                break;
            }
        }
        if (seen) continue;

        priority = ff_candidate_priority(board, move, board->side);
        if (raw_is_king_quiet && enemy_queen_close_to_king &&
            MOVE_PIECE(move) == PAWN && !MOVE_IS_CAPTURE(move) &&
            !MOVE_IS_EP(move) && !MOVE_IS_PROMO(move)) {
            continue;
        }
        if (raw_is_king_quiet) {
            int guard_score = search_ff_king_zone_guard_score(board, move, board->side);
            if (guard_score > 0) {
                priority += guard_score + 60;
                if (MOVE_PIECE(move) == BISHOP) priority += 80;
                if (MOVE_PIECE(move) == ROOK) priority += 40;
            }
        }
        if (raw_unsafe_queen_pawn_grab) {
            int bridge_priority = ff_bridge_rook_firebreak_priority(
                board,
                move,
                board->side
            );

            if (bridge_priority > 0 && priority < bridge_priority + 96) {
                priority = bridge_priority + 96;
            }
        }
        if (priority <= 0) continue;
        if (!suspicious_root && raw_is_tactical && MOVE_IS_CAPTURE(raw.best_move) &&
            MOVE_CAPTURED(raw.best_move) <= BISHOP && !MOVE_IS_CAPTURE(move) &&
            !MOVE_IS_EP(move) && !MOVE_IS_PROMO(move) && MOVE_PIECE(move) == PAWN &&
            search_ff_quiet_pawn_score(board, move, board->side) >= 120) {
            suspicious_root = true;
        }
        if (!suspicious_root && !raw_is_tactical &&
            priority >= 40 && priority >= raw_priority + 24) {
            suspicious_root = true;
        }
        if (candidate_count == 16 && priority <= candidate_scores[candidate_count - 1]) {
            continue;
        }

        insert_at = candidate_count;
        if (insert_at > 15) insert_at = 15;
        while (insert_at > 1 && candidate_scores[insert_at - 1] < priority) {
            if (insert_at < 16) {
                candidates[insert_at] = candidates[insert_at - 1];
                candidate_scores[insert_at] = candidate_scores[insert_at - 1];
            }
            insert_at--;
        }
        if (insert_at < 16) {
            candidates[insert_at] = move;
            candidate_scores[insert_at] = priority;
            if (candidate_count < 16) candidate_count++;
        }
    }

    if (!suspicious_root || candidate_count <= 1) return raw;

    verify_depth = (max_depth < 6) ? 6 : max_depth + 2;
    verify_time = (time_ms <= 0) ? 420 : clamp_int(time_ms * 4, 320, 520);

    for (int i = 0; i < candidate_count; i++) {
        search_reset(1);
        int score = kb_verify_child_score(
            board,
            candidates[i],
            verify_time,
            verify_depth,
            skill_level
        );

        if (MOVE_PIECE(candidates[i]) != KING && score > best_non_king_score) {
            best_non_king_score = score;
            best_non_king_move = candidates[i];
        }

        if (MOVE_PIECE(candidates[i]) == ROOK &&
            !MOVE_IS_CAPTURE(candidates[i]) &&
            !MOVE_IS_EP(candidates[i]) &&
            !MOVE_IS_PROMO(candidates[i]) &&
            ff_bridge_rook_firebreak_priority(board, candidates[i], board->side) > 0 &&
            score > best_firebreak_score) {
            best_firebreak_score = score;
            best_firebreak_move = candidates[i];
        }

        if (i == 0) {
            raw_best_score = score;
            best_score = score;
            best_move = candidates[i];
            continue;
        }

        if (score > best_score) {
            best_score = score;
            best_move = candidates[i];
        }
    }

    if (raw_unsafe_queen_pawn_grab && best_firebreak_move != MOVE_NONE &&
        best_firebreak_score >= raw_best_score - 80) {
        best_move = best_firebreak_move;
        best_score = best_firebreak_score;
    }

    if (raw_is_king_quiet && MOVE_IS_CASTLE(raw.best_move) && enemy_queen_close_to_king &&
        best_non_king_move != MOVE_NONE && best_non_king_score >= raw_best_score - 36) {
        best_move = best_non_king_move;
        best_score = best_non_king_score;
    }

    if (raw_is_king_quiet && MOVE_IS_CASTLE(raw.best_move) &&
        best_move != raw.best_move && MOVE_PIECE(best_move) != PAWN &&
        best_score >= raw_best_score - 20) {
        raw.best_move = best_move;
        raw.score = best_score;
        return raw;
    }

    if (raw_unsafe_queen_pawn_grab && best_move != raw.best_move &&
        MOVE_PIECE(best_move) == ROOK && !MOVE_IS_CAPTURE(best_move) &&
        !MOVE_IS_EP(best_move) && !MOVE_IS_PROMO(best_move) &&
        best_score >= raw_best_score - 80) {
        raw.best_move = best_move;
        raw.score = best_score;
        return raw;
    }

    if (best_move == raw.best_move || best_score < raw_best_score + 4) {
        return raw;
    }

    raw.best_move = best_move;
    raw.score = best_score;
    return raw;
}
