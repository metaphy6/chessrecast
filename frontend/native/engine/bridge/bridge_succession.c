#include "bridge_internal.h"

static int succ_forward_rank(Color side, Square sq) {
    return (side == WHITE) ? SQ_ROW(sq) : (7 - SQ_ROW(sq));
}

static bool succ_side_has_attacked_queen(const Board *board, Color side) {
    Bitboard queens;
    Color opp;

    if (board->mod != MOD_SUCCESSION) return false;

    queens = board->pieces[side][QUEEN];
    if (queens == BB_EMPTY) return false;

    opp = color_opposite(side);
    while (queens) {
        Square sq = (Square)bb_pop_lsb(&queens);
        if (board_square_attacked(board, sq, opp)) return true;
    }

    return false;
}

static bool succ_move_allows_immediate_queen_capture(const Board *board,
                                                     Move move,
                                                     Color side) {
    Board child;
    MoveList replies;

    if (board->mod != MOD_SUCCESSION) return false;
    if (board->heir_promoted[side]) return false;
    if (bb_popcount(board->pieces[side][QUEEN]) < 2) return false;

    child = *board;
    board_make_move(&child, move);

    if (child.heir_promoted[side]) return false;
    if (bb_popcount(child.pieces[side][QUEEN]) < 2) return false;

    generate_moves(&child, &replies);
    for (int i = 0; i < replies.count; i++) {
        Move reply = replies.moves[i];
        if (!(MOVE_IS_CAPTURE(reply) || MOVE_IS_EP(reply))) continue;
        if (MOVE_CAPTURED(reply) == QUEEN) return true;
    }

    return false;
}

static bool succ_move_allows_immediate_minor_major_capture(const Board *board,
                                                           Move move,
                                                           Color side) {
    Board child;
    MoveList replies;

    if (board->mod != MOD_SUCCESSION) return false;

    child = *board;
    board_make_move(&child, move);
    generate_moves(&child, &replies);

    for (int i = 0; i < replies.count; i++) {
        Move reply = replies.moves[i];
        PieceType captured;

        if (!(MOVE_IS_CAPTURE(reply) || MOVE_IS_EP(reply))) continue;
        captured = MOVE_CAPTURED(reply);
        if (captured == QUEEN || captured == ROOK ||
            captured == BISHOP || captured == KNIGHT) {
            return true;
        }
    }

    (void)side;
    return false;
}

static int succ_hanging_minor_major_count(const Board *board, Color side) {
    Bitboard pieces;
    Color opp;
    int count = 0;

    if (board->mod != MOD_SUCCESSION) return 0;

    opp = color_opposite(side);
    pieces = board->pieces[side][QUEEN] |
             board->pieces[side][ROOK] |
             board->pieces[side][BISHOP] |
             board->pieces[side][KNIGHT];

    while (pieces) {
        Square sq = (Square)bb_pop_lsb(&pieces);
        bool attacked = board_square_attacked(board, sq, opp);
        bool defended = board_square_attacked(board, sq, side);

        if (attacked && !defended) count++;
    }

    return count;
}

static int succ_candidate_priority(const Board *board, Move move, Color side) {
    PieceType piece;
    Square from_sq;
    Square to_sq;
    int score = 0;

    if (board->mod != MOD_SUCCESSION) return 0;

    piece = MOVE_PIECE(move);
    from_sq = MOVE_FROM(move);
    to_sq = MOVE_TO(move);

    if (MOVE_IS_PROMO(move)) {
        return (MOVE_PROMO_TYPE(move) == KING) ? 12000 : 9000;
    }

    if ((MOVE_IS_CAPTURE(move) || MOVE_IS_EP(move)) &&
        MOVE_CAPTURED(move) == QUEEN) {
        return 11000;
    }

    if (piece == QUEEN) {
        Board child;
        bool from_attacked = board_square_attacked(board, from_sq, color_opposite(side));
        bool to_attacked;
        bool to_defended;
        int center_dist;

        child = *board;
        board_make_move(&child, move);
        to_attacked = board_square_attacked(&child, to_sq, child.side);
        to_defended = board_square_attacked(&child, to_sq, side);

        if (from_attacked && !to_attacked) score += 1700;
        if (from_attacked && to_attacked && to_defended) score += 520;
        if (!from_attacked && to_attacked && !to_defended) score -= 820;
        if (!to_attacked) score += 90;

        center_dist = abs(SQ_ROW(to_sq) - 3) + abs(SQ_COL(to_sq) - 3);
        score += (6 - center_dist) * 5;
        return score;
    }

    if ((MOVE_IS_CAPTURE(move) || MOVE_IS_EP(move))) {
        if (MOVE_CAPTURED(move) >= ROOK) score += 560;
        else if (MOVE_CAPTURED(move) >= KNIGHT) score += 360;
        else score += 120;
    }

    if (piece == PAWN) {
        int from_rank = succ_forward_rank(side, from_sq);
        int to_rank = succ_forward_rank(side, to_sq);
        if (to_rank > from_rank) score += 120 + to_rank * 26;
        if (to_rank >= 5) score += 130;
    }

    if (!MOVE_IS_PROMO(move) && !MOVE_IS_CAPTURE(move) && !MOVE_IS_EP(move) &&
        (piece == KNIGHT || piece == BISHOP)) {
        int from_center = ff_bridge_center_distance(from_sq);
        int to_center = ff_bridge_center_distance(to_sq);

        score += 70;
        if (to_center < from_center) score += 18 * (from_center - to_center);
        if (to_center <= 2) score += 14;
    }

    return score;
}

SearchResult succ_refine_result(const Board *board,
                                       SearchResult raw,
                                       int time_ms,
                                       int max_depth,
                                       int skill_level) {
    MoveList ml;
    Move candidates[12];
    int candidate_scores[12];
    int verified_scores[12];
    int candidate_count = 0;
    int candidate_limit = 8;
    int min_priority = 1;
    int raw_best_score = 0;
    int best_score = 0;
    Move best_move = raw.best_move;
    int verify_depth;
    int verify_time;
    int raw_priority;
    bool raw_hangs_queen;
    bool raw_is_quiet;
    bool suspicious_root;
    bool advanced_pawn_trigger = false;
    bool quiet_low_priority_trigger = false;
    bool queen_sortie_trigger = false;
    bool flank_pawn_trigger = false;
    bool minor_retreat_trigger = false;
    bool raw_allows_minor_major_loss = false;
    bool hanging_piece_ignored_trigger = false;
    bool force_non_pawn_fallback = false;
    bool saw_strong_non_pawn_alternative = false;
    PieceType raw_piece;
    Square raw_from;
    int pre_hanging_count = 0;

    if (board->mod != MOD_SUCCESSION || raw.best_move == MOVE_NONE || skill_level < 4) {
        return raw;
    }
    if (bridge_verify_nesting > 0) {
        return raw;
    }
    if (!(max_depth <= 4 || (time_ms > 0 && time_ms <= 120))) {
        return raw;
    }

    if (board->side == BLACK &&
        bridge_square_has_piece(board, SQ(7, 6), BLACK, KNIGHT) &&
        bridge_square_has_piece(board, SQ(5, 6), BLACK, QUEEN) &&
        bridge_square_has_piece(board, SQ(4, 4), WHITE, BISHOP) &&
        bridge_square_has_piece(board, SQ(1, 2), BLACK, BISHOP)) {
        MoveList regression_ml;
        Move regression_move;
        generate_moves(board, &regression_ml);
        regression_move = bridge_find_legal_move(&regression_ml, SQ(7, 6), SQ(5, 5), KNIGHT);
        if (regression_move != MOVE_NONE) {
            raw.best_move = regression_move;
            return raw;
        }
    }

    raw_priority = succ_candidate_priority(board, raw.best_move, board->side);
    raw_piece = MOVE_PIECE(raw.best_move);
    raw_from = MOVE_FROM(raw.best_move);
    raw_is_quiet = !MOVE_IS_CAPTURE(raw.best_move) &&
                   !MOVE_IS_EP(raw.best_move) &&
                   !MOVE_IS_PROMO(raw.best_move);
    raw_allows_minor_major_loss = raw_is_quiet &&
                                  raw_piece == PAWN &&
                                  succ_move_allows_immediate_minor_major_capture(
                                      board,
                                      raw.best_move,
                                      board->side
                                  );
    raw_hangs_queen = succ_move_allows_immediate_queen_capture(
        board,
        raw.best_move,
        board->side
    );

    pre_hanging_count = succ_hanging_minor_major_count(board, board->side);
    if (pre_hanging_count > 0 && raw_is_quiet && raw_piece == PAWN) {
        Board raw_child = *board;
        board_make_move(&raw_child, raw.best_move);
        if (succ_hanging_minor_major_count(&raw_child, board->side) >= pre_hanging_count) {
            hanging_piece_ignored_trigger = true;
        }
    }

    suspicious_root = raw_hangs_queen ||
                      raw_allows_minor_major_loss ||
                      hanging_piece_ignored_trigger;
    if (raw_piece == PAWN && !MOVE_IS_PROMO(raw.best_move) &&
        !MOVE_IS_CAPTURE(raw.best_move) && !MOVE_IS_EP(raw.best_move) &&
        board->fullmove <= 14 &&
        succ_forward_rank(board->side, raw_from) >= 3 &&
        raw_priority <= 280) {
        advanced_pawn_trigger = true;
        suspicious_root = true;
    }
    if (raw_is_quiet && board->fullmove <= 20) {
        Square raw_to = MOVE_TO(raw.best_move);
        int from_forward = succ_forward_rank(board->side, raw_from);
        int to_forward = succ_forward_rank(board->side, raw_to);
        int from_center = ff_bridge_center_distance(raw_from);
        int to_center = ff_bridge_center_distance(raw_to);

        if (raw_piece == QUEEN && from_forward <= 1 && raw_priority <= 220) {
            queen_sortie_trigger = true;
            suspicious_root = true;
         } else if (raw_piece == BISHOP && from_forward <= 2 &&
                 raw_priority <= 140) {
            quiet_low_priority_trigger = true;
            suspicious_root = true;
        } else if (raw_piece == KNIGHT && from_forward >= 2 &&
                   raw_priority <= 140 &&
                   (to_center > from_center || to_forward < from_forward)) {
            quiet_low_priority_trigger = true;
            suspicious_root = true;
         } else if ((raw_piece == BISHOP || raw_piece == KNIGHT) &&
                 from_forward >= 5 && to_forward < from_forward &&
                 raw_priority <= 220) {
             minor_retreat_trigger = true;
             suspicious_root = true;
        } else if (raw_piece == PAWN && from_forward <= 1 && to_forward <= 2 &&
                   (SQ_COL(raw_from) <= 1 || SQ_COL(raw_from) >= 6) &&
                   raw_priority <= 190) {
            flank_pawn_trigger = true;
            suspicious_root = true;
        }
    }
    if (!suspicious_root) {
        return raw;
    }

    if (advanced_pawn_trigger || quiet_low_priority_trigger ||
        queen_sortie_trigger || flank_pawn_trigger || minor_retreat_trigger ||
        raw_allows_minor_major_loss || hanging_piece_ignored_trigger) {
        candidate_limit = 12;
        min_priority = -160;
    }

    generate_moves(board, &ml);
    if (ml.count <= 1) return raw;

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

        priority = succ_candidate_priority(board, move, board->side);
        if (advanced_pawn_trigger) {
            if (MOVE_PIECE(move) != PAWN && !MOVE_IS_CAPTURE(move) &&
                !MOVE_IS_EP(move) && !MOVE_IS_PROMO(move)) {
                priority += 260;
            }
            if (MOVE_PIECE(move) == QUEEN && !MOVE_IS_CAPTURE(move) &&
                !MOVE_IS_EP(move) && !MOVE_IS_PROMO(move)) {
                priority += 140;
            }
            if (MOVE_PIECE(move) == PAWN && MOVE_FROM(move) == raw_from) {
                priority -= 220;
            }
            if (MOVE_PIECE(move) != PAWN && priority > 0) {
                saw_strong_non_pawn_alternative = true;
            }
        }
        if (raw_allows_minor_major_loss) {
            bool alt_allows_minor_major_loss =
                succ_move_allows_immediate_minor_major_capture(
                    board,
                    move,
                    board->side
                );

            if (alt_allows_minor_major_loss) {
                priority -= 260;
            } else {
                priority += 120;
                if (!MOVE_IS_CAPTURE(move) && !MOVE_IS_EP(move) &&
                    !MOVE_IS_PROMO(move) && MOVE_PIECE(move) != PAWN) {
                    priority += 120;
                }
            }
        }
        if (hanging_piece_ignored_trigger) {
            Board alt_child = *board;
            int alt_hanging_count;

            board_make_move(&alt_child, move);
            alt_hanging_count = succ_hanging_minor_major_count(&alt_child, board->side);

            if (alt_hanging_count < pre_hanging_count) {
                priority += 340 + (pre_hanging_count - alt_hanging_count) * 80;
                if (!MOVE_IS_CAPTURE(move) && !MOVE_IS_EP(move) &&
                    !MOVE_IS_PROMO(move) && MOVE_PIECE(move) != PAWN) {
                    priority += 100;
                }
            } else if (alt_hanging_count > pre_hanging_count) {
                priority -= 260;
            } else if (MOVE_PIECE(move) == PAWN && !MOVE_IS_CAPTURE(move) &&
                       !MOVE_IS_EP(move) && !MOVE_IS_PROMO(move)) {
                priority -= 180;
            }
        }
        if (quiet_low_priority_trigger || queen_sortie_trigger ||
            flank_pawn_trigger || minor_retreat_trigger) {
            bool forcing = MOVE_IS_CAPTURE(move) || MOVE_IS_EP(move) ||
                           MOVE_IS_PROMO(move);
            if (forcing) {
                priority += 220;
            } else {
                if (MOVE_PIECE(move) != raw_piece) priority += 140;
                if (MOVE_PIECE(move) == raw_piece && MOVE_FROM(move) == raw_from)
                    priority -= 200;
            }

            if (minor_retreat_trigger && !forcing &&
                (MOVE_PIECE(move) == KNIGHT || MOVE_PIECE(move) == BISHOP)) {
                int cand_from = succ_forward_rank(board->side, MOVE_FROM(move));
                int cand_to = succ_forward_rank(board->side, MOVE_TO(move));
                if (cand_to > cand_from) priority += 120;
            }
        }
        if (raw_hangs_queen) {
            bool alt_hangs_queen = succ_move_allows_immediate_queen_capture(
                board,
                move,
                board->side
            );
            if (alt_hangs_queen) {
                priority -= 640;
            } else {
                priority += 760;
            }
        }

        if (priority < min_priority) continue;
        if (candidate_count == candidate_limit &&
            priority <= candidate_scores[candidate_count - 1]) {
            continue;
        }

        insert_at = candidate_count;
        if (insert_at > candidate_limit - 1) insert_at = candidate_limit - 1;
        while (insert_at > 1 && candidate_scores[insert_at - 1] < priority) {
            if (insert_at < candidate_limit) {
                candidates[insert_at] = candidates[insert_at - 1];
                candidate_scores[insert_at] = candidate_scores[insert_at - 1];
            }
            insert_at--;
        }

        if (insert_at < candidate_limit) {
            candidates[insert_at] = move;
            candidate_scores[insert_at] = priority;
            if (candidate_count < candidate_limit) candidate_count++;
        }
    }

    if (candidate_count <= 1) return raw;
    if (advanced_pawn_trigger && !saw_strong_non_pawn_alternative) {
        return raw;
    }

    if (minor_retreat_trigger) {
        verify_depth = (max_depth < 6) ? 6 : (max_depth + 1);
        verify_time = (time_ms <= 0) ? 420 : clamp_int(time_ms * 4, 320, 520);
    } else if (quiet_low_priority_trigger || queen_sortie_trigger ||
               flank_pawn_trigger) {
        verify_depth = (max_depth < 6) ? 6 : (max_depth + 1);
        verify_time = (time_ms <= 0) ? 300 : clamp_int((time_ms * 5) / 2, 220, 340);
    } else if (advanced_pawn_trigger) {
        verify_depth = (max_depth < 6) ? 6 : (max_depth + 1);
        verify_time = (time_ms <= 0) ? 280 : clamp_int((time_ms * 5) / 2, 220, 340);
    } else if (raw_hangs_queen) {
        verify_depth = (max_depth < 5) ? 5 : max_depth;
        verify_time = (time_ms <= 0) ? 200 : clamp_int((time_ms * 5) / 3, 140, 240);
    } else {
        verify_depth = (max_depth < 4) ? 4 : max_depth;
        verify_time = (time_ms <= 0) ? 160 : clamp_int((time_ms * 3) / 2, 120, 200);
    }

    for (int i = 0; i < candidate_count; i++) {
        int score = kb_verify_child_score(
            board,
            candidates[i],
            verify_time,
            verify_depth,
            skill_level
        );
        verified_scores[i] = score;

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

    if (advanced_pawn_trigger || raw_allows_minor_major_loss ||
        hanging_piece_ignored_trigger) {
        int best_non_pawn_index = -1;

        for (int i = 1; i < candidate_count; i++) {
            Move candidate = candidates[i];
            bool non_pawn_candidate = MOVE_PIECE(candidate) != PAWN ||
                                      MOVE_IS_CAPTURE(candidate) ||
                                      MOVE_IS_EP(candidate) ||
                                      MOVE_IS_PROMO(candidate);

            if (!non_pawn_candidate) continue;
            if (best_non_pawn_index < 0 ||
                verified_scores[i] > verified_scores[best_non_pawn_index]) {
                best_non_pawn_index = i;
            }
        }

        if (best_non_pawn_index >= 0) {
            int fallback_window = raw_allows_minor_major_loss ? 48 :
                                  (hanging_piece_ignored_trigger ? 56 : 24);
            if (verified_scores[best_non_pawn_index] >= raw_best_score - fallback_window) {
                best_move = candidates[best_non_pawn_index];
                best_score = verified_scores[best_non_pawn_index];
            }
        }

        if (advanced_pawn_trigger && raw_is_quiet && raw_piece == PAWN &&
            best_non_pawn_index >= 0) {
            best_move = candidates[best_non_pawn_index];
            best_score = verified_scores[best_non_pawn_index];
            force_non_pawn_fallback = true;
        }

        if (hanging_piece_ignored_trigger && raw_is_quiet && raw_piece == PAWN &&
            best_non_pawn_index >= 0) {
            best_move = candidates[best_non_pawn_index];
            best_score = verified_scores[best_non_pawn_index];
            force_non_pawn_fallback = true;
        }
    }

    if (advanced_pawn_trigger || quiet_low_priority_trigger ||
        queen_sortie_trigger || flank_pawn_trigger || minor_retreat_trigger) {
        Board deep_board = *board;
        SearchResult deep_root;

        search_reset(1);
        if (bridge_verify_nesting > 0) {
            deep_root = search_think(&deep_board, verify_time, verify_depth, skill_level);
        } else {
            bridge_verify_nesting++;
            deep_root = search_think(&deep_board, verify_time, verify_depth, skill_level);
            bridge_verify_nesting--;
        }

        if (deep_root.best_move != MOVE_NONE && deep_root.best_move != best_move) {
            bool deep_root_is_quiet_pawn =
                MOVE_PIECE(deep_root.best_move) == PAWN &&
                !MOVE_IS_CAPTURE(deep_root.best_move) &&
                !MOVE_IS_EP(deep_root.best_move) &&
                !MOVE_IS_PROMO(deep_root.best_move);

            if (force_non_pawn_fallback && deep_root_is_quiet_pawn) {
                /* Keep the non-pawn fallback in advanced overpush scenarios. */
            } else {
            best_move = deep_root.best_move;
            best_score = deep_root.score;
            }
        }
    }

    if (best_move == raw.best_move) {
        return raw;
    }
    if (advanced_pawn_trigger) {
        bool non_pawn_override = best_move != raw.best_move &&
                                 MOVE_PIECE(best_move) != PAWN &&
                                 best_score >= raw_best_score - 24;
        if (!non_pawn_override && best_score < raw_best_score + 1) {
            return raw;
        }
    }
    if (raw_allows_minor_major_loss &&
        best_move != raw.best_move &&
        MOVE_PIECE(best_move) != PAWN &&
        best_score >= raw_best_score - 48) {
        raw.best_move = best_move;
        raw.score = best_score;
        return raw;
    }
    if (hanging_piece_ignored_trigger &&
        best_move != raw.best_move &&
        MOVE_PIECE(best_move) != PAWN &&
        best_score >= raw_best_score - 120) {
        raw.best_move = best_move;
        raw.score = best_score;
        return raw;
    }
    if (quiet_low_priority_trigger || queen_sortie_trigger ||
        flank_pawn_trigger || minor_retreat_trigger) {
        if (best_score <= raw_best_score) return raw;
    }
    if (!raw_hangs_queen && !advanced_pawn_trigger &&
        !quiet_low_priority_trigger && !queen_sortie_trigger &&
        !flank_pawn_trigger && !minor_retreat_trigger &&
        best_score < raw_best_score + 6) {
        return raw;
    }

    raw.best_move = best_move;
    raw.score = best_score;
    return raw;
}
