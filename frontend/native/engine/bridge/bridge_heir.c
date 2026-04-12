#include "bridge_internal.h"

SearchResult heir_refine_queen_sortie_result(const Board *board,
                                                    SearchResult raw,
                                                    int time_ms,
                                                    int max_depth,
                                                    int skill_level) {
    MoveList ml;
    Move candidates[16];
    int candidate_count = 0;
    int raw_best_score = 0;
    int best_score = 0;
    Move best_move = raw.best_move;
    int verify_depth;
    int verify_time;

    if (board->mod != MOD_HEIR || raw.best_move == MOVE_NONE || skill_level < 4) {
        return raw;
    }
    if (search_heir_early_queen_sortie_penalty(board, raw.best_move) <= 0) {
        return raw;
    }

    generate_moves(board, &ml);
    candidates[candidate_count++] = raw.best_move;
    for (int i = 0; i < ml.count && candidate_count < 16; i++) {
        Move m = ml.moves[i];
        bool seen = false;

        if (!search_heir_is_tactical_capture_candidate(board, m)) continue;

        for (int j = 0; j < candidate_count; j++) {
            if (candidates[j] == m) {
                seen = true;
                break;
            }
        }
        if (!seen) candidates[candidate_count++] = m;
    }

    if (candidate_count <= 1) return raw;

    verify_depth = (max_depth < 8) ? max_depth + 3 : max_depth;
    verify_time = (time_ms <= 0) ? 450 : clamp_int(time_ms * 3, 300, 600);

    for (int i = 0; i < candidate_count; i++) {
        int score = kb_verify_child_score(board, candidates[i], verify_time, verify_depth, skill_level);

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
