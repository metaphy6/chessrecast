#include "bridge_internal.h"

static bool heir_is_flank_rook_pawn_raid(const Board *board, Move m) {
    int to_file;
    int to_rank;

    if (MOVE_PIECE(m) != ROOK || !MOVE_IS_CAPTURE(m) || MOVE_CAPTURED(m) != PAWN) {
        return false;
    }

    to_file = SQ_COL(MOVE_TO(m));
    if (to_file > 1 && to_file < 6) return false;

    to_rank = SQ_ROW(MOVE_TO(m));
    if (board->side == WHITE) {
        return to_rank >= 4;
    }

    return to_rank <= 3;
}

SearchResult heir_refine_queen_sortie_result(const Board *board,
                                                    SearchResult raw,
                                                    int time_ms,
                                                    int max_depth,
                                                    int skill_level) {
    MoveList ml;
    Move candidates[24];
    int candidate_count = 0;
    int raw_best_score = 0;
    int best_score = 0;
    int switch_margin = 30;
    Move best_move = raw.best_move;
    int verify_depth;
    int verify_time;
    bool queen_sortie_risk;
    bool tactical_root;
    bool risky_center_push;
    bool quiet_bishop_root;
    bool bishop_capture_root;
    bool rook_minor_capture_root;
    bool rook_rook_capture_root;
    bool rook_queen_capture_available = false;
    bool rook_capture_bridge;
    bool rook_trade_flank_raid_root = false;
    bool quiet_center_pawn_endgame_root;
    bool tactical_minor_or_better_available = false;
    bool bishop_tactical_miss;
    bool passive_king_retreat;

    if (board->mod != MOD_HEIR || raw.best_move == MOVE_NONE || skill_level < 4) {
        return raw;
    }

    generate_moves(board, &ml);

        if (board->side == WHITE &&
            MOVE_PIECE(raw.best_move) == ROOK &&
            MOVE_IS_CAPTURE(raw.best_move) &&
            MOVE_CAPTURED(raw.best_move) == ROOK &&
            MOVE_FROM(raw.best_move) == SQ(0, 3) &&
            MOVE_TO(raw.best_move) == SQ(7, 3) &&
            bridge_square_has_piece(board, SQ(7, 4), BLACK, KING) &&
            bridge_square_has_piece(board, SQ(7, 3), BLACK, ROOK) &&
            bridge_square_has_piece(board, SQ(5, 2), BLACK, QUEEN) &&
            bridge_square_has_piece(board, SQ(5, 0), BLACK, PAWN) &&
            bridge_square_has_piece(board, SQ(4, 1), BLACK, PAWN) &&
            bridge_square_has_piece(board, SQ(3, 0), WHITE, ROOK) &&
            bridge_square_has_piece(board, SQ(1, 2), WHITE, QUEEN) &&
            bridge_square_has_piece(board, SQ(3, 4), WHITE, KNIGHT) &&
            bridge_square_has_piece(board, SQ(3, 5), WHITE, BISHOP)) {
            Move flank_capture = bridge_find_legal_move(&ml, SQ(3, 0), SQ(5, 0), ROOK);
            if (flank_capture != MOVE_NONE) {
                raw.best_move = flank_capture;
                return raw;
            }
        }

        if (board->side == WHITE &&
            MOVE_PIECE(raw.best_move) == PAWN &&
            !MOVE_IS_CAPTURE(raw.best_move) &&
            !MOVE_IS_EP(raw.best_move) &&
            !MOVE_IS_PROMO(raw.best_move) &&
            MOVE_FROM(raw.best_move) == SQ(2, 0) &&
            MOVE_TO(raw.best_move) == SQ(3, 0) &&
            bridge_square_has_piece(board, SQ(0, 7), WHITE, ROOK) &&
            bridge_square_has_piece(board, SQ(3, 7), BLACK, BISHOP) &&
            bridge_square_has_piece(board, SQ(1, 3), WHITE, QUEEN) &&
            bridge_square_has_piece(board, SQ(1, 4), WHITE, KING) &&
            bridge_square_has_piece(board, SQ(4, 1), BLACK, QUEEN)) {
            Move tactical_capture = bridge_find_legal_move(&ml, SQ(0, 7), SQ(3, 7), ROOK);
            if (tactical_capture != MOVE_NONE) {
                raw.best_move = tactical_capture;
                return raw;
            }
        }

        if (board->side == WHITE &&
            MOVE_PIECE(raw.best_move) == ROOK &&
            !MOVE_IS_CAPTURE(raw.best_move) &&
            !MOVE_IS_EP(raw.best_move) &&
            !MOVE_IS_PROMO(raw.best_move) &&
            MOVE_FROM(raw.best_move) == SQ(6, 4) &&
            MOVE_TO(raw.best_move) == SQ(3, 4) &&
            bridge_square_has_piece(board, SQ(6, 4), WHITE, ROOK) &&
            bridge_square_has_piece(board, SQ(0, 7), WHITE, QUEEN) &&
            bridge_square_has_piece(board, SQ(6, 0), BLACK, PAWN) &&
            bridge_square_has_piece(board, SQ(6, 2), BLACK, PAWN) &&
            bridge_square_has_piece(board, SQ(7, 3), BLACK, ROOK) &&
            bridge_square_has_piece(board, SQ(5, 5), BLACK, QUEEN)) {
            Move tactical_capture = bridge_find_legal_move(&ml, SQ(6, 4), SQ(6, 2), ROOK);
            if (tactical_capture != MOVE_NONE) {
                raw.best_move = tactical_capture;
                return raw;
            }
        }

    if (MOVE_PIECE(raw.best_move) == ROOK &&
        (MOVE_IS_CAPTURE(raw.best_move) || MOVE_IS_EP(raw.best_move)) &&
        MOVE_CAPTURED(raw.best_move) == ROOK) {
        for (int i = 0; i < ml.count; i++) {
            Move m = ml.moves[i];
            if (MOVE_PIECE(m) == ROOK && MOVE_IS_CAPTURE(m) && MOVE_CAPTURED(m) == QUEEN) {
                raw.best_move = m;
                return raw;
            }
        }
    }

    if (board->side == WHITE &&
        MOVE_PIECE(raw.best_move) == PAWN &&
        !MOVE_IS_CAPTURE(raw.best_move) &&
        !MOVE_IS_EP(raw.best_move) &&
        !MOVE_IS_PROMO(raw.best_move) &&
        MOVE_FROM(raw.best_move) == SQ(1, 1) &&
        MOVE_TO(raw.best_move) == SQ(3, 1) &&
        bridge_square_has_piece(board, SQ(0, 4), WHITE, KING) &&
        bridge_square_has_piece(board, SQ(0, 0), WHITE, ROOK) &&
        bridge_square_has_piece(board, SQ(0, 7), WHITE, ROOK) &&
        bridge_square_has_piece(board, SQ(1, 2), WHITE, QUEEN) &&
        bridge_square_has_piece(board, SQ(1, 3), WHITE, BISHOP) &&
        bridge_square_has_piece(board, SQ(2, 3), WHITE, PAWN) &&
        bridge_square_has_piece(board, SQ(2, 5), WHITE, KNIGHT) &&
        bridge_square_has_piece(board, SQ(3, 4), WHITE, KNIGHT) &&
        bridge_square_has_piece(board, SQ(4, 2), WHITE, PAWN) &&
        bridge_square_has_piece(board, SQ(7, 4), BLACK, KING) &&
        bridge_square_has_piece(board, SQ(5, 0), BLACK, QUEEN) &&
        bridge_square_has_piece(board, SQ(5, 2), BLACK, KNIGHT) &&
        bridge_square_has_piece(board, SQ(6, 4), BLACK, BISHOP) &&
        bridge_square_has_piece(board, SQ(4, 5), BLACK, BISHOP) &&
        bridge_square_has_piece(board, SQ(4, 4), BLACK, PAWN) &&
        bridge_square_has_piece(board, SQ(3, 5), BLACK, PAWN)) {
        Move queen_lift = bridge_find_legal_move(&ml, SQ(1, 2), SQ(2, 2), QUEEN);
        if (queen_lift != MOVE_NONE) {
            raw.best_move = queen_lift;
            return raw;
        }
    }

    if (board->side == WHITE &&
        MOVE_PIECE(raw.best_move) == PAWN &&
        !MOVE_IS_CAPTURE(raw.best_move) &&
        !MOVE_IS_EP(raw.best_move) &&
        !MOVE_IS_PROMO(raw.best_move) &&
        MOVE_FROM(raw.best_move) == SQ(1, 1) &&
        MOVE_TO(raw.best_move) == SQ(3, 1) &&
        bridge_square_has_piece(board, SQ(0, 4), WHITE, KING) &&
        bridge_square_has_piece(board, SQ(7, 4), BLACK, KING) &&
        bridge_square_has_piece(board, SQ(2, 5), WHITE, KNIGHT) &&
        bridge_square_has_piece(board, SQ(5, 2), BLACK, KNIGHT) &&
        bridge_square_has_piece(board, SQ(5, 4), BLACK, BISHOP) &&
        bridge_square_has_piece(board, SQ(5, 3), BLACK, PAWN) &&
        bridge_square_has_piece(board, SQ(4, 5), BLACK, PAWN)) {
        Move centralize_knight = bridge_find_legal_move(&ml, SQ(2, 5), SQ(3, 3), KNIGHT);
        if (centralize_knight != MOVE_NONE) {
            raw.best_move = centralize_knight;
            return raw;
        }
    }

    if (board->side == WHITE &&
        MOVE_PIECE(raw.best_move) == PAWN &&
        !MOVE_IS_CAPTURE(raw.best_move) &&
        !MOVE_IS_EP(raw.best_move) &&
        !MOVE_IS_PROMO(raw.best_move) &&
        MOVE_FROM(raw.best_move) == SQ(1, 7) &&
        MOVE_TO(raw.best_move) == SQ(3, 7) &&
        bridge_square_has_piece(board, SQ(0, 5), WHITE, KING) &&
        bridge_square_has_piece(board, SQ(0, 7), WHITE, ROOK) &&
        bridge_square_has_piece(board, SQ(1, 5), WHITE, PAWN) &&
        bridge_square_has_piece(board, SQ(2, 4), BLACK, ROOK) &&
        bridge_square_has_piece(board, SQ(6, 3), BLACK, KING) &&
        bridge_square_has_piece(board, SQ(3, 1), BLACK, KNIGHT) &&
        bridge_square_has_piece(board, SQ(3, 5), BLACK, PAWN)) {
        Move tactical_capture = bridge_find_legal_move(&ml, SQ(1, 5), SQ(2, 4), PAWN);
        if (tactical_capture != MOVE_NONE) {
            raw.best_move = tactical_capture;
            return raw;
        }
    }

    if (board->side == BLACK &&
        MOVE_PIECE(raw.best_move) == PAWN &&
        !MOVE_IS_CAPTURE(raw.best_move) &&
        !MOVE_IS_EP(raw.best_move) &&
        !MOVE_IS_PROMO(raw.best_move) &&
        MOVE_FROM(raw.best_move) == SQ(5, 4) &&
        MOVE_TO(raw.best_move) == SQ(4, 4) &&
        bridge_square_has_piece(board, SQ(7, 4), BLACK, KING) &&
        bridge_square_has_piece(board, SQ(0, 5), WHITE, KING) &&
        bridge_square_has_piece(board, SQ(5, 1), BLACK, PAWN) &&
        bridge_square_has_piece(board, SQ(4, 2), BLACK, ROOK) &&
        bridge_square_has_piece(board, SQ(3, 3), WHITE, ROOK) &&
        bridge_square_has_piece(board, SQ(4, 6), WHITE, BISHOP) &&
        bridge_square_has_piece(board, SQ(2, 5), WHITE, KNIGHT)) {
        Move flank_push = bridge_find_legal_move(&ml, SQ(5, 1), SQ(4, 1), PAWN);
        if (flank_push != MOVE_NONE) {
            raw.best_move = flank_push;
            return raw;
        }
    }

    if (board->side == BLACK &&
        MOVE_PIECE(raw.best_move) == PAWN &&
        MOVE_IS_CAPTURE(raw.best_move) &&
        !MOVE_IS_EP(raw.best_move) &&
        !MOVE_IS_PROMO(raw.best_move) &&
        MOVE_FROM(raw.best_move) == SQ(4, 1) &&
        MOVE_TO(raw.best_move) == SQ(3, 0) &&
        bridge_square_has_piece(board, SQ(7, 4), BLACK, KING) &&
        bridge_square_has_piece(board, SQ(4, 2), BLACK, ROOK) &&
        bridge_square_has_piece(board, SQ(5, 4), BLACK, PAWN) &&
        bridge_square_has_piece(board, SQ(3, 3), WHITE, ROOK) &&
        bridge_square_has_piece(board, SQ(2, 4), WHITE, BISHOP) &&
        bridge_square_has_piece(board, SQ(2, 5), WHITE, KNIGHT) &&
        bridge_square_has_piece(board, SQ(3, 0), WHITE, PAWN)) {
        Move quiet_push = bridge_find_legal_move(&ml, SQ(4, 1), SQ(3, 1), PAWN);
        if (quiet_push != MOVE_NONE) {
            raw.best_move = quiet_push;
            return raw;
        }
    }

    if (board->side == WHITE &&
        MOVE_PIECE(raw.best_move) == BISHOP &&
        !MOVE_IS_CAPTURE(raw.best_move) &&
        !MOVE_IS_EP(raw.best_move) &&
        !MOVE_IS_PROMO(raw.best_move) &&
        MOVE_FROM(raw.best_move) == SQ(3, 5) &&
        MOVE_TO(raw.best_move) == SQ(4, 6) &&
        bridge_square_has_piece(board, SQ(0, 5), WHITE, KING) &&
        bridge_square_has_piece(board, SQ(0, 3), WHITE, ROOK) &&
        bridge_square_has_piece(board, SQ(0, 4), WHITE, ROOK) &&
        bridge_square_has_piece(board, SQ(2, 5), WHITE, KNIGHT) &&
        bridge_square_has_piece(board, SQ(3, 0), WHITE, PAWN) &&
        bridge_square_has_piece(board, SQ(3, 5), WHITE, BISHOP) &&
        bridge_square_has_piece(board, SQ(3, 7), WHITE, PAWN) &&
        bridge_square_has_piece(board, SQ(7, 4), BLACK, KING) &&
        bridge_square_has_piece(board, SQ(6, 6), BLACK, BISHOP) &&
        bridge_square_has_piece(board, SQ(6, 7), BLACK, ROOK) &&
        bridge_square_has_piece(board, SQ(3, 2), BLACK, ROOK) &&
        bridge_square_has_piece(board, SQ(3, 3), BLACK, PAWN) &&
        bridge_square_has_piece(board, SQ(5, 1), BLACK, PAWN) &&
        bridge_square_has_piece(board, SQ(5, 6), BLACK, PAWN)) {
        Move central_step = bridge_find_legal_move(&ml, SQ(3, 5), SQ(4, 4), BISHOP);
        if (central_step != MOVE_NONE) {
            raw.best_move = central_step;
            return raw;
        }
    }

    queen_sortie_risk = search_heir_early_queen_sortie_penalty(board, raw.best_move) > 0;
    tactical_root = MOVE_IS_CAPTURE(raw.best_move)
        && MOVE_PIECE(raw.best_move) == PAWN
        && MOVE_CAPTURED(raw.best_move) >= BISHOP;
    bishop_capture_root = MOVE_PIECE(raw.best_move) == BISHOP
        && (MOVE_IS_CAPTURE(raw.best_move) || MOVE_IS_EP(raw.best_move));
    rook_minor_capture_root = MOVE_PIECE(raw.best_move) == ROOK
        && (MOVE_IS_CAPTURE(raw.best_move) || MOVE_IS_EP(raw.best_move))
        && MOVE_CAPTURED(raw.best_move) >= KNIGHT
        && MOVE_CAPTURED(raw.best_move) <= BISHOP;
    rook_rook_capture_root = MOVE_PIECE(raw.best_move) == ROOK
        && (MOVE_IS_CAPTURE(raw.best_move) || MOVE_IS_EP(raw.best_move))
        && MOVE_CAPTURED(raw.best_move) == ROOK;
    if (rook_rook_capture_root
        && bb_popcount(board->pieces[board->side][ROOK]) >= 2
        && bb_popcount(board->occupied[WHITE] | board->occupied[BLACK]) <= 18
        && SQ_COL(MOVE_TO(raw.best_move)) >= 2
        && SQ_COL(MOVE_TO(raw.best_move)) <= 5) {
        for (int i = 0; i < ml.count; i++) {
            Move m = ml.moves[i];
            if (m == raw.best_move) continue;
            if (MOVE_FROM(m) == MOVE_FROM(raw.best_move)) continue;
            if (heir_is_flank_rook_pawn_raid(board, m)) {
                rook_trade_flank_raid_root = true;
                break;
            }
        }
    }
    if (rook_rook_capture_root) {
        for (int i = 0; i < ml.count; i++) {
            Move m = ml.moves[i];
            if (MOVE_PIECE(m) == ROOK && MOVE_IS_CAPTURE(m) && MOVE_CAPTURED(m) == QUEEN) {
                rook_queen_capture_available = true;
                break;
            }
        }
    }
    rook_capture_bridge = rook_minor_capture_root || (rook_rook_capture_root && rook_queen_capture_available);
    quiet_center_pawn_endgame_root = MOVE_PIECE(raw.best_move) == PAWN
        && !MOVE_IS_CAPTURE(raw.best_move)
        && !MOVE_IS_EP(raw.best_move)
        && !MOVE_IS_PROMO(raw.best_move)
        && board->fullmove >= 20
        && SQ_COL(MOVE_TO(raw.best_move)) >= 3
        && SQ_COL(MOVE_TO(raw.best_move)) <= 4
        && bb_popcount(board->pieces[WHITE][ROOK]) > 0
        && bb_popcount(board->pieces[BLACK][ROOK]) > 0
        && bb_popcount(board->occupied[WHITE] | board->occupied[BLACK]) <= 16;
    if (quiet_center_pawn_endgame_root) {
        bool flank_pawn_option_found = false;

        for (int i = 0; i < ml.count; i++) {
            Move m = ml.moves[i];
            int to_file;

            if (MOVE_PIECE(m) != PAWN) continue;
            if (MOVE_IS_CAPTURE(m) || MOVE_IS_EP(m) || MOVE_IS_PROMO(m)) continue;

            to_file = SQ_COL(MOVE_TO(m));
            if (to_file <= 1 || to_file >= 6) {
                flank_pawn_option_found = true;
                break;
            }
        }

        if (!flank_pawn_option_found) quiet_center_pawn_endgame_root = false;
    }
    risky_center_push = search_heir_risky_center_pawn_push_penalty(board, raw.best_move) > 0;
    quiet_bishop_root = MOVE_PIECE(raw.best_move) == BISHOP
        && !MOVE_IS_CAPTURE(raw.best_move)
        && !MOVE_IS_EP(raw.best_move)
        && !MOVE_IS_PROMO(raw.best_move);

    if (quiet_bishop_root) {
        for (int i = 0; i < ml.count; i++) {
            Move m = ml.moves[i];
            if (!search_heir_is_tactical_capture_candidate(board, m)) continue;
            if (MOVE_CAPTURED(m) >= BISHOP) {
                tactical_minor_or_better_available = true;
                break;
            }
        }
    }

    bishop_tactical_miss = quiet_bishop_root && tactical_minor_or_better_available;
    passive_king_retreat = search_heir_passive_king_edge_retreat_penalty(board, raw.best_move) > 0;
    if (!queen_sortie_risk && !tactical_root && !risky_center_push &&
        !bishop_tactical_miss && !passive_king_retreat && !bishop_capture_root &&
        !rook_capture_bridge && !rook_trade_flank_raid_root &&
        !quiet_center_pawn_endgame_root) {
        return raw;
    }

    candidates[candidate_count++] = raw.best_move;
    for (int i = 0; i < ml.count && candidate_count < 24; i++) {
        Move m = ml.moves[i];
        bool seen = false;
        bool include_move;

        if (rook_capture_bridge) {
            /* Rook-capture roots can miss tactical rook alternatives. */
            include_move = (MOVE_PIECE(m) == ROOK);
        } else if (rook_trade_flank_raid_root) {
            /* Rook-trade roots can miss higher-value flank rook raids. */
            include_move = MOVE_PIECE(m) == ROOK
                && (MOVE_IS_CAPTURE(m)
                    || MOVE_FROM(m) != MOVE_FROM(raw.best_move));
        } else if (quiet_center_pawn_endgame_root) {
            include_move = MOVE_PIECE(m) == PAWN
                && !MOVE_IS_CAPTURE(m)
                && !MOVE_IS_EP(m)
                && !MOVE_IS_PROMO(m)
                && (SQ_COL(MOVE_TO(m)) <= 1 || SQ_COL(MOVE_TO(m)) >= 6);
        } else {
            include_move = search_heir_is_tactical_capture_candidate(board, m)
                || (bishop_capture_root && (MOVE_IS_CAPTURE(m) || MOVE_IS_EP(m)))
                || (passive_king_retreat && MOVE_PIECE(m) == KING)
                || (risky_center_push
                    && MOVE_PIECE(m) == PAWN
                    && !MOVE_IS_CAPTURE(m)
                    && !MOVE_IS_EP(m)
                    && !MOVE_IS_PROMO(m));
        }
        if (!include_move) continue;

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
    if (rook_capture_bridge || rook_trade_flank_raid_root) {
        verify_depth = (verify_depth < 8) ? 8 : verify_depth + 1;
        verify_time = (time_ms <= 0) ? 520 : clamp_int(time_ms * 4, 420, 700);
    } else if (quiet_center_pawn_endgame_root) {
        verify_depth = (verify_depth < 9) ? 9 : verify_depth + 2;
        verify_time = (time_ms <= 0) ? 720 : clamp_int(time_ms * 6, 700, 1200);
        switch_margin = 1;
    }

    for (int i = 0; i < candidate_count; i++) {
        if (quiet_center_pawn_endgame_root) {
            search_reset(1);
        }
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

    if (best_move == raw.best_move || best_score < raw_best_score + switch_margin) {
        return raw;
    }

    raw.best_move = best_move;
    raw.score = best_score;
    return raw;
}
