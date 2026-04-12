#include "bridge_internal.h"

static bool king_discipline_mod_enabled(const Board *board) {
    switch (board->mod) {
        case MOD_HEIR:
        case MOD_MERCENARY:
        case MOD_SAVE_QUEEN:
        case MOD_SUCCESSION:
            return true;
        default:
            return false;
    }
}

static bool king_discipline_has_castling_rights(const Board *board, Color side) {
    uint8_t mask = (side == WHITE)
        ? (CASTLE_WK | CASTLE_WQ)
        : (CASTLE_BK | CASTLE_BQ);
    return (board->castling & mask) != 0;
}

static int king_discipline_candidate_priority(const Board *board,
                                              Move move,
                                              Color side) {
    PieceType piece = MOVE_PIECE(move);
    int score = 0;

    if (move == MOVE_NONE) return -100000;
    if (piece == KING && !MOVE_IS_CASTLE(move)) return -100000;

    if (MOVE_IS_CASTLE(move)) {
        score += 8000;
    }

    if (MOVE_IS_CAPTURE(move) || MOVE_IS_EP(move)) {
        score += 2200;
        if (MOVE_CAPTURED(move) >= KNIGHT) score += 1200;
    }

    if (piece == KNIGHT || piece == BISHOP) {
        int back_rank = (side == WHITE) ? 0 : 7;
        score += 1800;
        if (SQ_ROW(MOVE_FROM(move)) == back_rank && SQ_ROW(MOVE_TO(move)) != back_rank) {
            score += 900;
        }
    }

    if (piece == PAWN && !MOVE_IS_CAPTURE(move) && !MOVE_IS_EP(move) && !MOVE_IS_PROMO(move)) {
        int from_rank = (side == WHITE) ? SQ_ROW(MOVE_FROM(move)) : (7 - SQ_ROW(MOVE_FROM(move)));
        int to_rank = (side == WHITE) ? SQ_ROW(MOVE_TO(move)) : (7 - SQ_ROW(MOVE_TO(move)));
        int file = SQ_COL(MOVE_FROM(move));

        if (from_rank == 1 && file >= 2 && file <= 5) {
            score += 1000;
            if (to_rank == 3) score += 220;
        }
    }

    if (piece == ROOK || piece == QUEEN) {
        score += 120;
    }

    if (!king_discipline_mod_enabled(board)) {
        return 0;
    }

    return score;
}

SearchResult king_discipline_refine_result(const Board *board,
                                                  SearchResult raw,
                                                  int time_ms,
                                                  int max_depth,
                                                  int skill_level) {
    MoveList ml;
    Move candidates[20];
    int candidate_scores[20];
    int candidate_count = 0;
    int verify_depth;
    int verify_time;
    int raw_best_score = 0;
    int best_score = 0;
    Move best_move = raw.best_move;
    Color side;
    Bitboard king_bb;
    Square king_sq;
    bool in_check;

    if (!king_discipline_mod_enabled(board) || raw.best_move == MOVE_NONE || skill_level < 4) {
        return raw;
    }
    if (board->fullmove > 16) return raw;
    if (MOVE_PIECE(raw.best_move) != KING || MOVE_IS_CASTLE(raw.best_move) ||
        MOVE_IS_CAPTURE(raw.best_move) || MOVE_IS_EP(raw.best_move) ||
        MOVE_IS_PROMO(raw.best_move)) {
        return raw;
    }

    side = board->side;
    if (!king_discipline_has_castling_rights(board, side)) return raw;

    king_bb = board->pieces[side][KING];
    if (king_bb == BB_EMPTY) return raw;
    king_sq = bb_lsb(king_bb);
    in_check = board_square_attacked(board, king_sq, color_opposite(side));
    if (in_check) return raw;
    if (bridge_verify_nesting > 0) return raw;

    generate_moves(board, &ml);

    candidates[candidate_count] = raw.best_move;
    candidate_scores[candidate_count] = 2000000000;
    candidate_count++;

    for (int i = 0; i < ml.count; i++) {
        Move move = ml.moves[i];
        int priority;
        int insert_at;
        bool seen = false;

        if (move == raw.best_move) continue;

        priority = king_discipline_candidate_priority(board, move, side);
        if (priority < 900) continue;

        for (int j = 0; j < candidate_count; j++) {
            if (candidates[j] == move) {
                seen = true;
                break;
            }
        }
        if (seen) continue;

        if (candidate_count == 20 && priority <= candidate_scores[candidate_count - 1]) {
            continue;
        }

        insert_at = candidate_count;
        if (insert_at > 19) insert_at = 19;
        while (insert_at > 1 && candidate_scores[insert_at - 1] < priority) {
            if (insert_at < 20) {
                candidates[insert_at] = candidates[insert_at - 1];
                candidate_scores[insert_at] = candidate_scores[insert_at - 1];
            }
            insert_at--;
        }

        if (insert_at < 20) {
            candidates[insert_at] = move;
            candidate_scores[insert_at] = priority;
            if (candidate_count < 20) candidate_count++;
        }
    }

    if (candidate_count <= 1) return raw;

    verify_depth = (max_depth < 5) ? 5 : max_depth;
    verify_time = (time_ms <= 0) ? 220 : clamp_int((time_ms * 3) / 2, 140, 280);

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

    if (best_move == raw.best_move) return raw;

    if (MOVE_IS_CASTLE(best_move)) {
        if (best_score < raw_best_score + 8) return raw;
    } else {
        if (best_score < raw_best_score + 24) return raw;
    }

    raw.best_move = best_move;
    raw.score = best_score;
    return raw;
}
