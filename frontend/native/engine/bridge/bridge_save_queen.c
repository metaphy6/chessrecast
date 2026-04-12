#include "bridge_internal.h"

static int stq_undeveloped_minor_count(const Board *board, Color side) {
    int back_rank;
    int undeveloped;
    Bitboard minors;

    if (board->mod != MOD_SAVE_QUEEN) return 0;

    back_rank = (side == WHITE) ? 0 : 7;
    undeveloped = 0;
    minors = board->pieces[side][KNIGHT] | board->pieces[side][BISHOP];

    while (minors) {
        Square sq = (Square)bb_pop_lsb(&minors);
        if (SQ_ROW(sq) == back_rank) undeveloped++;
    }

    return undeveloped;
}

static int stq_forward_rank(Color side, Square sq) {
    return (side == WHITE) ? SQ_ROW(sq) : (7 - SQ_ROW(sq));
}

static int stq_prisoner_escape_distance(Color side, Square sq) {
    return (side == WHITE) ? (SQ_ROW(sq) - 3) : (4 - SQ_ROW(sq));
}

static int stq_candidate_priority(const Board *board, Move move, Color side) {
    PieceType piece;
    bool is_capture;
    Square from_sq;
    Square to_sq;

    if (board->mod != MOD_SAVE_QUEEN) return 0;

    piece = MOVE_PIECE(move);
    is_capture = MOVE_IS_CAPTURE(move) || MOVE_IS_EP(move);
    from_sq = MOVE_FROM(move);
    to_sq = MOVE_TO(move);

    if (MOVE_IS_PROMO(move)) return 7000;

    if (is_capture) {
        int score = 1400;
        if (MOVE_CAPTURED(move) >= KNIGHT) score += 1200;
        if (piece == PAWN && MOVE_CAPTURED(move) != PAWN) score += 500;
        if (piece == KNIGHT && board->fullmove <= 10) {
            int file = SQ_COL(to_sq);
            int rank = stq_forward_rank(side, to_sq);
            if ((file <= 1 || file >= 6) && rank <= 2) score -= 700;
        }
        return score;
    }

    if (piece == KING) {
        bool in_check = board_square_attacked(board, from_sq, color_opposite(side));
        Board child = *board;
        bool to_attacked;
        int score;

        board_make_move(&child, move);
        to_attacked = board_square_attacked(&child, to_sq, child.side);

        score = in_check ? 80 : -200;
        if (SQ_COL(to_sq) == SQ_COL(from_sq)) score += 28;
        if (SQ_COL(to_sq) != SQ_COL(from_sq)) score -= 52;
        if ((side == WHITE && SQ_ROW(to_sq) == 0) ||
            (side == BLACK && SQ_ROW(to_sq) == 7)) {
            score -= 40;
        }
        if (to_attacked) {
            score -= 280;
        } else {
            score += 24;
        }

        return score;
    }

    if (piece == KNIGHT || piece == BISHOP) {
        int back_rank = (side == WHITE) ? 0 : 7;
        if (SQ_ROW(from_sq) != back_rank || SQ_ROW(to_sq) == back_rank) return 0;

        int score = (piece == KNIGHT) ? 900 : 700;

        if (piece == KNIGHT &&
            ((side == WHITE && to_sq == SQ(2, 5)) ||
             (side == BLACK && to_sq == SQ(5, 5)))) {
            score += 250;
        }

        if (board->fullmove <= 10 && piece == KNIGHT) {
            if ((side == WHITE && from_sq == SQ(0, 1) &&
                 (to_sq == SQ(2, 2) || to_sq == SQ(1, 3))) ||
                (side == BLACK && from_sq == SQ(7, 1) &&
                 (to_sq == SQ(5, 2) || to_sq == SQ(6, 3)))) {
                score -= 450;
            }
        }

        return score;
    }

    if (piece == PAWN) {
        int from_rank = stq_forward_rank(side, from_sq);
        int file = SQ_COL(from_sq);

        if (from_rank != 1) return 0;
        if (file >= 2 && file <= 5) return 520;
        if (file <= 1 || file >= 6) return -260;
        return 0;
    }

    if (piece == QUEEN) {
        bool from_own_half = stq_is_own_half(from_sq, side);
        int undeveloped = stq_undeveloped_minor_count(board, side);
        Board child = *board;
        bool queen_attacked;
        bool queen_defended;

        board_make_move(&child, move);
        queen_attacked = board_square_attacked(&child, to_sq, child.side);
        queen_defended = board_square_attacked(&child, to_sq, side);

        if (!from_own_half) {
            int before_dist = stq_prisoner_escape_distance(side, from_sq);
            int after_dist = stq_prisoner_escape_distance(side, to_sq);
            int score = 0;

            if (after_dist < before_dist) score += 450;
            if (before_dist <= 2) score += 160;
            if (after_dist >= before_dist && board->fullmove <= 10) score -= 360;
            if (queen_attacked && !queen_defended) {
                score -= 980;
            } else if (queen_attacked) {
                score -= 280;
            }
            return score;
        }

        {
            int score = 0;

            if (board->fullmove <= 10 && undeveloped >= 2) score -= 180;
            if (queen_attacked && !queen_defended) {
                score -= 820;
            } else if (queen_attacked) {
                score -= 220;
            }
            return score;
        }
    }

    return 0;
}

static bool stq_root_looks_suspicious(const Board *board, Move move, Color side) {
    PieceType piece;

    if (board->mod != MOD_SAVE_QUEEN || move == MOVE_NONE) return false;
    if (board->fullmove > 14) return false;

    piece = MOVE_PIECE(move);

    if (piece == KING && !MOVE_IS_CAPTURE(move) && !MOVE_IS_EP(move) &&
        !board_square_attacked(board, MOVE_FROM(move), color_opposite(side))) {
        return true;
    }

    if (piece == KING && board_square_attacked(board, MOVE_FROM(move), color_opposite(side))) {
        return true;
    }

    if (piece == PAWN && !MOVE_IS_CAPTURE(move) && !MOVE_IS_EP(move) &&
        !MOVE_IS_PROMO(move) && stq_forward_rank(side, MOVE_FROM(move)) == 1 &&
        (SQ_COL(MOVE_FROM(move)) <= 1 || SQ_COL(MOVE_FROM(move)) >= 6) &&
        stq_undeveloped_minor_count(board, side) >= 2) {
        return true;
    }

    if (piece == KNIGHT && board->fullmove <= 10) {
        Square from_sq = MOVE_FROM(move);
        Square to_sq = MOVE_TO(move);

        if ((side == WHITE && from_sq == SQ(0, 1) &&
             (to_sq == SQ(2, 2) || to_sq == SQ(1, 3))) ||
            (side == BLACK && from_sq == SQ(7, 1) &&
             (to_sq == SQ(5, 2) || to_sq == SQ(6, 3)))) {
            return true;
        }

        if (MOVE_IS_CAPTURE(move) &&
            (SQ_COL(to_sq) <= 1 || SQ_COL(to_sq) >= 6) &&
            stq_forward_rank(side, to_sq) <= 2 &&
            stq_undeveloped_minor_count(board, side) >= 2) {
            return true;
        }
    }

    return stq_candidate_priority(board, move, side) < 0;
}

SearchResult stq_refine_result(const Board *board,
                                      SearchResult raw,
                                      int time_ms,
                                      int max_depth,
                                      int skill_level) {
    MoveList ml;
    Move candidates[8];
    int candidate_scores[8];
    int candidate_count = 0;
    int raw_best_score = 0;
    int best_score = 0;
    Move best_move = raw.best_move;
    int verify_depth;
    int verify_time;
    int raw_priority;
    int min_priority;
    bool raw_is_king;

    if (board->mod != MOD_SAVE_QUEEN || raw.best_move == MOVE_NONE || skill_level < 4) {
        return raw;
    }
    if (bridge_verify_nesting > 0) {
        return raw;
    }
    if (!stq_root_looks_suspicious(board, raw.best_move, board->side)) {
        return raw;
    }

    raw_priority = stq_candidate_priority(board, raw.best_move, board->side);
    raw_is_king = (MOVE_PIECE(raw.best_move) == KING);
    min_priority = 1;
    if (raw_priority < 0) {
        min_priority = raw_priority + 40;
    }

    generate_moves(board, &ml);
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

        priority = stq_candidate_priority(board, move, board->side);
        if (raw_is_king && MOVE_PIECE(move) == KING) {
            if (priority < raw_priority + 60) continue;
        } else {
            if (priority < min_priority) continue;
        }

        if (candidate_count == 8 && priority <= candidate_scores[candidate_count - 1]) {
            continue;
        }

        insert_at = candidate_count;
        if (insert_at > 7) insert_at = 7;
        while (insert_at > 1 && candidate_scores[insert_at - 1] < priority) {
            if (insert_at < 8) {
                candidates[insert_at] = candidates[insert_at - 1];
                candidate_scores[insert_at] = candidate_scores[insert_at - 1];
            }
            insert_at--;
        }

        if (insert_at < 8) {
            candidates[insert_at] = move;
            candidate_scores[insert_at] = priority;
            if (candidate_count < 8) candidate_count++;
        }
    }

    if (candidate_count <= 1) return raw;

    verify_depth = (max_depth < 5) ? 5 : max_depth;
    verify_time = (time_ms <= 0) ? 220 : clamp_int((time_ms * 3) / 2, 140, 240);

    if (raw_is_king) {
        verify_depth = (verify_depth < 6) ? 6 : (verify_depth + 1);
        verify_time = (time_ms <= 0) ? 300 : clamp_int(time_ms * 2, 220, 360);
    }

    for (int i = 0; i < candidate_count; i++) {
        int score = kb_verify_child_score(
            board,
            candidates[i],
            verify_time,
            verify_depth,
            skill_level
        );

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

    if (best_move == raw.best_move || best_score < raw_best_score + 30) {
        return raw;
    }

    raw.best_move = best_move;
    raw.score = best_score;
    return raw;
}
