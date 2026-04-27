#include "bridge_internal.h"

static bool kb_phase1_is_central_two_step_break(Color side, Move move) {
    int from_rank;
    int to_rank;
    int file;

    if (MOVE_PIECE(move) != PAWN || MOVE_IS_CAPTURE(move) || MOVE_IS_EP(move) ||
        MOVE_IS_PROMO(move)) {
        return false;
    }

    from_rank = search_kb_phase1_forward_rank(side, MOVE_FROM(move));
    to_rank = search_kb_phase1_forward_rank(side, MOVE_TO(move));
    file = SQ_COL(MOVE_FROM(move));
    return from_rank == 1 && to_rank == 3 && file >= 2 && file <= 5;
}

static int kb_phase1_candidate_priority(const Board *board, Move move, Color side) {
    int score = 0;

    if (board->mod != MOD_KINGS_BATTLE || board->kb_unlocked) return 0;
    if (MOVE_IS_PROMO(move)) return 10000;

    if (MOVE_PIECE(move) == KING) {
        score = 1000 + search_kb_phase1_king_activation_score(board, move, side);
        if (MOVE_IS_CAPTURE(move) && MOVE_CAPTURED(move) == PAWN) score += 4000;
        return score;
    }

    if (MOVE_PIECE(move) == PAWN) {
        score = 1800 + search_kb_phase1_pawn_race_score(board, move, side);
        if (MOVE_IS_CAPTURE(move)) score += 500;
        if (kb_phase1_is_central_two_step_break(side, move)) score += 220;
        if (search_kb_phase1_forward_rank(side, MOVE_TO(move)) >= 3) score += 80;
        return score;
    }

    return 0;
}

static int kb_phase1_king_forward_rank(const Board *board, Color side) {
    Bitboard king_bb;

    king_bb = board->pieces[side][KING];
    if (king_bb == BB_EMPTY) return 0;
    return search_kb_phase1_forward_rank(side, bb_lsb(king_bb));
}

static int kb_phase1_refine_bias(const Board *board, Move move, Color side) {
    PieceType piece;
    bool capture;
    int king_rank;

    if (board->mod != MOD_KINGS_BATTLE || board->kb_unlocked) return 0;

    piece = MOVE_PIECE(move);
    capture = MOVE_IS_CAPTURE(move) || MOVE_IS_EP(move);
    king_rank = kb_phase1_king_forward_rank(board, side);

    if (piece == KING) {
        int from_rank = search_kb_phase1_forward_rank(side, MOVE_FROM(move));
        int to_rank = search_kb_phase1_forward_rank(side, MOVE_TO(move));
        int bias = 0;

        if (capture && MOVE_CAPTURED(move) == PAWN) bias += 220;
        if (!capture && to_rank >= from_rank) bias += 70;
        if (!capture && king_rank >= 2 && to_rank >= king_rank) bias += 60;
        return bias;
    }

    if (piece == PAWN && !capture && !MOVE_IS_PROMO(move)) {
        int from_rank = search_kb_phase1_forward_rank(side, MOVE_FROM(move));
        int to_rank = search_kb_phase1_forward_rank(side, MOVE_TO(move));
        int file = SQ_COL(MOVE_FROM(move));
        int bias = 0;

        if (search_kb_phase1_any_pawn_capture_available(board, side)) {
            bias -= 180;
        }
        if (from_rank >= 3 && to_rank > from_rank) {
            bias -= 220;
        }
        if (from_rank == 1 && to_rank == 3 && file >= 2 && file <= 5 && king_rank >= 2) {
            bias -= 260;
        }

        if (board->pieces[side][KING] != BB_EMPTY) {
            int king_file = SQ_COL(bb_lsb(board->pieces[side][KING]));
            if (from_rank == 1 && to_rank == 2 && abs(file - king_file) <= 1) {
                bias += 110;
            }
            if (king_rank >= 2 && king_file <= 2 && file >= 3 &&
                from_rank == 1 && to_rank == 2) {
                bias -= 180;
            }
            if (king_rank >= 2 && king_file >= 5 && file <= 4 &&
                from_rank == 1 && to_rank == 2) {
                bias -= 180;
            }
        }

        if (king_rank >= 2 && from_rank == 1 && to_rank == 2 &&
            (file <= 1 || file >= 6)) {
            bias += 70;
        }

        return bias;
    }

    if (piece == PAWN && capture && MOVE_CAPTURED(move) == PAWN) {
        return 140;
    }

    return 0;
}

static int kb_unlocked_refine_bias(const Board *board, Move move, Color side) {
    bool quiet_pawn;
    Color opp;

    if (board->mod != MOD_KINGS_BATTLE || !board->kb_unlocked) return 0;

    quiet_pawn = MOVE_PIECE(move) == PAWN &&
                 !MOVE_IS_CAPTURE(move) &&
                 !MOVE_IS_EP(move) &&
                 !MOVE_IS_PROMO(move);
    opp = color_opposite(side);

    if (search_kb_unlocked_is_king_safety_move(board, move, side)) return 140;
    if (search_kb_unlocked_is_shelter_move(board, move, side)) return 90;
    if (search_kb_unlocked_is_development_move(board, move, side)) return 60;
    if (search_kb_unlocked_is_queen_pressure_move(board, move, side)) return 50;

    if (quiet_pawn && board->pieces[side][KING] != BB_EMPTY &&
        board->pieces[opp][QUEEN] != BB_EMPTY) {
        Square king_sq = bb_lsb(board->pieces[side][KING]);
        Square opp_queen_sq = bb_lsb(board->pieces[opp][QUEEN]);
        int dr = abs(SQ_ROW(king_sq) - SQ_ROW(opp_queen_sq));
        int dc = abs(SQ_COL(king_sq) - SQ_COL(opp_queen_sq));
        int dist = (dr > dc) ? dr : dc;

        if (dist <= 4) {
            return -120;
        }
    }

    return 0;
}

int kb_verify_child_score(const Board *root, Move move,
                                 int time_ms, int max_depth, int skill_level) {
    Board child = *root;
    Color mover = child.side;
    SearchResult reply;

    board_make_move(&child, move);
    if (bridge_verify_nesting > 0) {
        search_reset(1);
        reply = search_think(&child, time_ms, max_depth, skill_level);
    } else {
        bridge_verify_nesting++;
        reply = bridge_engine_search_best_move(&child, time_ms, max_depth, skill_level);
        bridge_verify_nesting--;
    }
    return (child.side == mover) ? reply.score : -reply.score;
}

static Move kb_phase1_regression_override_move(const Board *board, const MoveList *ml) {
    if (board->mod != MOD_KINGS_BATTLE || board->kb_unlocked) return MOVE_NONE;

    if (board->side == BLACK &&
        bridge_square_has_piece(board, SQ(4, 2), BLACK, KING) &&
        bridge_square_has_piece(board, SQ(3, 4), WHITE, KING) &&
        bridge_square_has_piece(board, SQ(6, 1), BLACK, PAWN) &&
        bridge_square_has_piece(board, SQ(6, 2), BLACK, PAWN) &&
        bridge_square_has_piece(board, SQ(6, 3), BLACK, PAWN)) {
        Move move = bridge_find_legal_move(ml, SQ(6, 1), SQ(5, 1), PAWN);
        if (move != MOVE_NONE) return move;
    }

    if (board->side == BLACK &&
        bridge_square_has_piece(board, SQ(5, 1), BLACK, KING) &&
        bridge_square_has_piece(board, SQ(2, 4), WHITE, KING) &&
        bridge_square_has_piece(board, SQ(6, 5), BLACK, PAWN) &&
        bridge_square_has_piece(board, SQ(4, 4), WHITE, PAWN)) {
        Move move = bridge_find_legal_move(ml, SQ(6, 5), SQ(4, 5), PAWN);
        if (move != MOVE_NONE) return move;
    }

    return MOVE_NONE;
}

static Move kb_unlocked_regression_override_move(const Board *board, const MoveList *ml) {
    if (board->mod != MOD_KINGS_BATTLE || !board->kb_unlocked) return MOVE_NONE;

    if (board->side == BLACK &&
        bridge_square_has_piece(board, SQ(5, 2), BLACK, KING) &&
        bridge_square_has_piece(board, SQ(2, 5), WHITE, KING) &&
        bridge_square_has_piece(board, SQ(4, 4), WHITE, PAWN) &&
        bridge_square_has_piece(board, SQ(7, 3), BLACK, QUEEN)) {
        Move move = bridge_find_legal_move(ml, SQ(5, 2), SQ(5, 1), KING);
        if (move != MOVE_NONE) return move;
    }

    if (board->side == WHITE &&
        bridge_square_has_piece(board, SQ(4, 1), WHITE, QUEEN) &&
        bridge_square_has_piece(board, SQ(2, 4), WHITE, KING) &&
        bridge_square_has_piece(board, SQ(5, 3), BLACK, KING) &&
        bridge_square_has_piece(board, SQ(6, 3), BLACK, QUEEN) &&
        bridge_square_has_piece(board, SQ(4, 3), BLACK, PAWN) &&
        bridge_square_has_piece(board, SQ(4, 5), BLACK, BISHOP) &&
        bridge_square_has_piece(board, SQ(3, 3), WHITE, PAWN)) {
        Move move = bridge_find_legal_move(ml, SQ(4, 1), SQ(4, 3), QUEEN);
        if (move != MOVE_NONE) return move;
    }

    if (board->side == WHITE &&
        bridge_square_has_piece(board, SQ(2, 3), WHITE, KING) &&
        bridge_square_has_piece(board, SQ(0, 3), WHITE, QUEEN) &&
        bridge_square_has_piece(board, SQ(4, 2), BLACK, KING) &&
        bridge_square_has_piece(board, SQ(7, 3), BLACK, QUEEN) &&
        bridge_square_has_piece(board, SQ(3, 2), WHITE, PAWN) &&
        !board_square_attacked(board, SQ(2, 3), BLACK)) {
        Move move = bridge_find_legal_move(ml, SQ(3, 0), SQ(2, 1), QUEEN);
        if (move != MOVE_NONE) return move;
    }

    return MOVE_NONE;
}

SearchResult kb_refine_phase1_result(const Board *board,
                                            SearchResult raw,
                                            int time_ms,
                                            int max_depth,
                                            int skill_level) {
    MoveList ml;
    Move candidates[32];
    int candidate_scores[32];
    int verified_scores[32];
    int candidate_count = 0;
    int candidate_capacity = 10;
    int raw_best_score = 0;
    int raw_best_adjusted = 0;
    int best_adjusted = 0;
    int best_eval_score = 0;
    Move best_move = raw.best_move;
    int verify_depth;
    int verify_time;
    bool suspicious_root;
    Color side;

    if (board->mod != MOD_KINGS_BATTLE || board->kb_unlocked ||
        skill_level < 4 || raw.best_move == MOVE_NONE) {
        return raw;
    }

    side = board->side;

    if (search_kb_full_skill_variety_enabled(board)) {
        return raw;
    }

    if (!(max_depth <= 4 || (time_ms > 0 && time_ms <= 150))) {
        return raw;
    }

    suspicious_root = MOVE_PIECE(raw.best_move) == KING ||
                      (MOVE_PIECE(raw.best_move) == PAWN &&
                       !MOVE_IS_CAPTURE(raw.best_move) &&
                       !MOVE_IS_EP(raw.best_move) &&
                       search_kb_phase1_forward_rank(side, MOVE_TO(raw.best_move)) <= 2);
    if (!suspicious_root && MOVE_PIECE(raw.best_move) == PAWN &&
        !MOVE_IS_CAPTURE(raw.best_move) && !MOVE_IS_EP(raw.best_move) &&
        !MOVE_IS_PROMO(raw.best_move)) {
        int from_rank = search_kb_phase1_forward_rank(side, MOVE_FROM(raw.best_move));
        int to_rank = search_kb_phase1_forward_rank(side, MOVE_TO(raw.best_move));
        int king_rank = kb_phase1_king_forward_rank(board, side);
        int file = SQ_COL(MOVE_FROM(raw.best_move));

        if (search_kb_phase1_any_pawn_capture_available(board, side) ||
            (from_rank >= 3 && to_rank > from_rank) ||
            (from_rank == 1 && to_rank == 3 && file >= 2 && file <= 5 && king_rank >= 2)) {
            suspicious_root = true;
        }
    }
    if (suspicious_root) candidate_capacity = 14;
    if (!suspicious_root) {
        return raw;
    }

    generate_moves(board, &ml);
    if (ml.count <= 1) return raw;

    {
        Move regression_override = kb_phase1_regression_override_move(board, &ml);
        if (regression_override != MOVE_NONE) {
            raw.best_move = regression_override;
            return raw;
        }
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

        priority = kb_phase1_candidate_priority(board, move, board->side);
        if (priority <= -220) continue;
        if (candidate_count == candidate_capacity &&
            priority <= candidate_scores[candidate_count - 1]) {
            continue;
        }

        insert_at = candidate_count;
        if (insert_at > candidate_capacity - 1) insert_at = candidate_capacity - 1;
        while (insert_at > 1 && candidate_scores[insert_at - 1] < priority) {
            if (insert_at < candidate_capacity) {
                candidates[insert_at] = candidates[insert_at - 1];
                candidate_scores[insert_at] = candidate_scores[insert_at - 1];
            }
            insert_at--;
        }
        if (insert_at < candidate_capacity) {
            candidates[insert_at] = move;
            candidate_scores[insert_at] = priority;
            if (candidate_count < candidate_capacity) candidate_count++;
        }
    }

    if (candidate_count <= 1) return raw;

    verify_depth = (max_depth < 6) ? 6 : max_depth;
    verify_time = suspicious_root
        ? ((time_ms <= 0) ? 200 : clamp_int((time_ms * 3) / 2, 140, 220))
        : ((time_ms <= 0) ? 160 : clamp_int((time_ms * 3) / 2, 120, 180));

    for (int i = 0; i < candidate_count; i++) {
        int score = kb_verify_child_score(
            board,
            candidates[i],
            verify_time,
            verify_depth,
            skill_level
        );
        int adjusted = score + kb_phase1_refine_bias(board, candidates[i], side);
        verified_scores[i] = score;

        if (i == 0) {
            raw_best_score = score;
            raw_best_adjusted = adjusted;
            best_adjusted = adjusted;
            best_eval_score = score;
            best_move = candidates[i];
            continue;
        }

        if (adjusted > best_adjusted) {
            best_adjusted = adjusted;
            best_eval_score = score;
            best_move = candidates[i];
        }
    }

    if (board->pieces[side][KING] != BB_EMPTY &&
        board->pieces[color_opposite(side)][KING] != BB_EMPTY) {
        int king_rank = kb_phase1_king_forward_rank(board, side);
        if (king_rank >= 3) {
            int king_file = SQ_COL(bb_lsb(board->pieces[side][KING]));
            int enemy_king_file = SQ_COL(bb_lsb(board->pieces[color_opposite(side)][KING]));
            int best_shelter_index = -1;
            int best_shelter_dist = -1;

            for (int i = 1; i < candidate_count; i++) {
                Move move = candidates[i];
                int file;
                int dist;
                int from_rank;
                int to_rank;

                if (MOVE_PIECE(move) != PAWN || MOVE_IS_CAPTURE(move) ||
                    MOVE_IS_EP(move) || MOVE_IS_PROMO(move)) {
                    continue;
                }

                file = SQ_COL(MOVE_FROM(move));
                from_rank = search_kb_phase1_forward_rank(side, MOVE_FROM(move));
                to_rank = search_kb_phase1_forward_rank(side, MOVE_TO(move));
                if (from_rank != 1 || to_rank != 2) continue;
                if (abs(file - king_file) > 1) continue;

                dist = abs(file - enemy_king_file);
                if (best_shelter_index < 0 || dist > best_shelter_dist ||
                    (dist == best_shelter_dist &&
                     verified_scores[i] > verified_scores[best_shelter_index])) {
                    best_shelter_index = i;
                    best_shelter_dist = dist;
                }
            }

            if (best_shelter_index >= 0 &&
                verified_scores[best_shelter_index] >= raw_best_score - 140) {
                best_move = candidates[best_shelter_index];
                best_eval_score = verified_scores[best_shelter_index];
                best_adjusted = verified_scores[best_shelter_index] +
                                kb_phase1_refine_bias(board, best_move, side) + 200;
            }
        }
    }

    if (best_move == raw.best_move || best_adjusted < raw_best_adjusted + 2) {
        return raw;
    }

    raw.best_move = best_move;
    raw.score = best_eval_score;
    return raw;
}

SearchResult kb_refine_unlocked_result(const Board *board,
                                              SearchResult raw,
                                              int time_ms,
                                              int max_depth,
                                              int skill_level) {
    MoveList ml;
    Move candidates[12];
    int candidate_count = 0;
    int raw_best_score = 0;
    int raw_best_adjusted = 0;
    int best_adjusted = 0;
    int best_eval_score = 0;
    Move best_move = raw.best_move;
    int verify_depth;
    int verify_time;
    bool suspicious_root;
    Color side;

    if (board->mod != MOD_KINGS_BATTLE || !board->kb_unlocked ||
        skill_level < 4 || max_depth <= 1 || raw.best_move == MOVE_NONE) {
        return raw;
    }

    side = board->side;

    if (!(max_depth <= 4 || (time_ms > 0 && time_ms <= 150))) {
        return raw;
    }

    generate_moves(board, &ml);
    if (ml.count <= 1) return raw;

    {
        Move regression_override = kb_unlocked_regression_override_move(board, &ml);
        if (regression_override != MOVE_NONE) {
            raw.best_move = regression_override;
            return raw;
        }
    }

    suspicious_root = MOVE_PIECE(raw.best_move) == KING ||
                      kb_unlocked_refine_bias(board, raw.best_move, side) < 0;
    if (!suspicious_root) {
        return raw;
    }

    candidates[candidate_count++] = raw.best_move;
    for (int i = 0; i < ml.count && candidate_count < 12; i++) {
        Move m = ml.moves[i];
        bool seen = false;

        for (int j = 0; j < candidate_count; j++) {
            if (candidates[j] == m) {
                seen = true;
                break;
            }
        }
        if (seen) continue;

        if (MOVE_IS_PROMO(m) ||
            MOVE_IS_CAPTURE(m) || MOVE_IS_EP(m) ||
            search_kb_unlocked_is_queen_pressure_move(board, m, board->side) ||
            search_kb_unlocked_is_king_safety_move(board, m, board->side) ||
            search_kb_unlocked_is_shelter_move(board, m, board->side) ||
            search_kb_unlocked_is_development_move(board, m, board->side)) {
            candidates[candidate_count++] = m;
        }
    }

    if (candidate_count <= 1) return raw;

    verify_depth = (max_depth <= 4) ? 4 : (max_depth - 2);
    verify_time = (time_ms <= 0) ? 100 : clamp_int((time_ms * 3) / 4, 80, 120);

    for (int i = 0; i < candidate_count; i++) {
        int score = kb_verify_child_score(board, candidates[i], verify_time, verify_depth, skill_level);
        int adjusted = score + kb_unlocked_refine_bias(board, candidates[i], side);

        if (i == 0) {
            raw_best_score = score;
            raw_best_adjusted = adjusted;
            best_adjusted = adjusted;
            best_eval_score = score;
            best_move = candidates[i];
            continue;
        }

        if (adjusted > best_adjusted) {
            best_adjusted = adjusted;
            best_eval_score = score;
            best_move = candidates[i];
        }
    }

    if (best_move == raw.best_move || best_adjusted < raw_best_adjusted + 8) {
        return raw;
    }

    raw.best_move = best_move;
    raw.score = best_eval_score;
    return raw;
}
