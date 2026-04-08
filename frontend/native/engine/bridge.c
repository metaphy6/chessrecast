#include "bridge.h"
#include "board.h"
#include "search.h"
#include "search/variant_heuristics.h"
#include "movegen.h"
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

#ifdef __ANDROID__
#include <android/log.h>
#define LOGD(...) __android_log_print(ANDROID_LOG_DEBUG, "CHESS_ENGINE", __VA_ARGS__)
#else
static int bridge_logging_enabled(void) {
    static int initialized = 0;
    static int enabled = 0;

    if (!initialized) {
        const char *env = getenv("CHESSRECAST_ENGINE_VERBOSE");
        enabled = (env != NULL && env[0] != '\0' && strcmp(env, "0") != 0);
        initialized = 1;
    }

    return enabled;
}

#define LOGD(...) do { \
    if (bridge_logging_enabled()) { \
        fprintf(stderr, __VA_ARGS__); \
    } \
} while(0)
#endif

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Engine lifecycle                                                         */
/* ═══════════════════════════════════════════════════════════════════════════ */

static int s_initialized = 0;
static int s_verify_nesting = 0;

static SearchResult engine_search_best_move(Board *board,
                                            int time_ms,
                                            int max_depth,
                                            int skill_level);

static int clamp_int(int value, int lower, int upper) {
    if (value < lower) return lower;
    if (value > upper) return upper;
    return value;
}

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

static int kb_verify_child_score(const Board *root, Move move,
                                 int time_ms, int max_depth, int skill_level) {
    Board child = *root;
    Color mover = child.side;
    SearchResult reply;

    board_make_move(&child, move);
    if (s_verify_nesting > 0) {
        search_reset(1);
        reply = search_think(&child, time_ms, max_depth, skill_level);
    } else {
        s_verify_nesting++;
        reply = engine_search_best_move(&child, time_ms, max_depth, skill_level);
        s_verify_nesting--;
    }
    return (child.side == mover) ? reply.score : -reply.score;
}

static int ff_bridge_center_distance(Square sq) {
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

    return ff_candidate_priority(board, move, side) <= 0;
}

static SearchResult ff_refine_result(const Board *board,
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
    raw_unsafe_queen_pawn_grab = ff_bridge_unsafe_queen_pawn_grab(
        board,
        raw.best_move,
        board->side
    );

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

        priority = ff_candidate_priority(board, move, board->side);
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

    if (best_move == raw.best_move || best_score < raw_best_score + 4) {
        return raw;
    }

    raw.best_move = best_move;
    raw.score = best_score;
    return raw;
}

static SearchResult kb_refine_phase1_result(const Board *board,
                                            SearchResult raw,
                                            int time_ms,
                                            int max_depth,
                                            int skill_level) {
    MoveList ml;
    Move candidates[32];
    int candidate_scores[32];
    int candidate_count = 0;
    int candidate_capacity = 16;
    int raw_best_score = 0;
    int best_score = 0;
    Move best_move = raw.best_move;
    int verify_depth;
    int verify_time;
    bool suspicious_root;

    if (board->mod != MOD_KINGS_BATTLE || board->kb_unlocked ||
        skill_level < 4 || raw.best_move == MOVE_NONE) {
        return raw;
    }

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
                       search_kb_phase1_forward_rank(board->side, MOVE_TO(raw.best_move)) <= 2);
    if (suspicious_root) candidate_capacity = 32;
    if (!suspicious_root) {
        return raw;
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

        priority = kb_phase1_candidate_priority(board, move, board->side);
        if (priority <= 0) continue;
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

    verify_depth = (max_depth < 6) ? 6 : max_depth + 2;
    verify_time = suspicious_root
        ? ((time_ms <= 0) ? 420 : clamp_int(time_ms * 4, 320, 560))
        : ((time_ms <= 0) ? 320 : clamp_int(time_ms * 3, 240, 420));

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

    if (best_move == raw.best_move || best_score < raw_best_score + 4) {
        return raw;
    }

    raw.best_move = best_move;
    raw.score = best_score;
    return raw;
}

static SearchResult kb_refine_unlocked_result(const Board *board,
                                              SearchResult raw,
                                              int time_ms,
                                              int max_depth,
                                              int skill_level) {
    MoveList ml;
    Move candidates[32];
    int candidate_count = 0;
    int raw_best_score = 0;
    int best_score = 0;
    Move best_move = raw.best_move;
    int verify_depth;
    int verify_time;

    if (board->mod != MOD_KINGS_BATTLE || !board->kb_unlocked ||
        skill_level < 4 || max_depth <= 1 || raw.best_move == MOVE_NONE) {
        return raw;
    }

    if (!(max_depth <= 4 || (time_ms > 0 && time_ms <= 150))) {
        return raw;
    }

    generate_moves(board, &ml);
    if (ml.count <= 1) return raw;

    candidates[candidate_count++] = raw.best_move;
    for (int i = 0; i < ml.count && candidate_count < 32; i++) {
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
            search_kb_unlocked_is_queen_pressure_move(board, m, board->side) ||
            search_kb_unlocked_is_king_safety_move(board, m, board->side) ||
            search_kb_unlocked_is_shelter_move(board, m, board->side) ||
            search_kb_unlocked_is_development_move(board, m, board->side)) {
            candidates[candidate_count++] = m;
        }
    }

    if (candidate_count <= 1) return raw;

    verify_depth = (max_depth <= 4) ? 6 : max_depth;
    verify_time = (time_ms <= 0) ? 280 : clamp_int(time_ms * 3, 220, 420);

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

    if (best_move == raw.best_move || best_score < raw_best_score + 40) {
        return raw;
    }

    raw.best_move = best_move;
    raw.score = best_score;
    return raw;
}

static SearchResult heir_refine_queen_sortie_result(const Board *board,
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

static SearchResult succ_refine_result(const Board *board,
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
    bool raw_hangs_queen;
    bool suspicious_root;
    bool advanced_pawn_trigger = false;
    bool saw_strong_non_pawn_alternative = false;
    PieceType raw_piece;
    Square raw_from;

    if (board->mod != MOD_SUCCESSION || raw.best_move == MOVE_NONE || skill_level < 4) {
        return raw;
    }
    if (s_verify_nesting > 0) {
        return raw;
    }
    if (!(max_depth <= 4 || (time_ms > 0 && time_ms <= 120))) {
        return raw;
    }

    raw_priority = succ_candidate_priority(board, raw.best_move, board->side);
    raw_piece = MOVE_PIECE(raw.best_move);
    raw_from = MOVE_FROM(raw.best_move);
    raw_hangs_queen = succ_move_allows_immediate_queen_capture(
        board,
        raw.best_move,
        board->side
    );

    suspicious_root = raw_hangs_queen;
    if (!suspicious_root && raw_piece == PAWN && !MOVE_IS_PROMO(raw.best_move) &&
        !MOVE_IS_CAPTURE(raw.best_move) && !MOVE_IS_EP(raw.best_move) &&
        board->fullmove <= 14 &&
        succ_forward_rank(board->side, raw_from) >= 3 &&
        raw_priority <= 280) {
        advanced_pawn_trigger = true;
        suspicious_root = true;
    }
    if (!suspicious_root) {
        return raw;
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

        if (priority <= 0) continue;
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
    if (advanced_pawn_trigger && !saw_strong_non_pawn_alternative) {
        return raw;
    }

    if (raw_hangs_queen) {
        verify_depth = (max_depth < 5) ? 5 : max_depth;
        verify_time = (time_ms <= 0) ? 200 : clamp_int((time_ms * 5) / 3, 140, 240);
    } else if (advanced_pawn_trigger) {
        verify_depth = (max_depth < 5) ? 5 : max_depth;
        verify_time = (time_ms <= 0) ? 220 : clamp_int(time_ms * 2, 160, 260);
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

    if (best_move == raw.best_move) {
        return raw;
    }
    if (!raw_hangs_queen && !advanced_pawn_trigger &&
        best_score < raw_best_score + 6) {
        return raw;
    }
    if (advanced_pawn_trigger && best_score < raw_best_score + 2) {
        return raw;
    }

    raw.best_move = best_move;
    raw.score = best_score;
    return raw;
}

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

static SearchResult stq_refine_result(const Board *board,
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
    if (s_verify_nesting > 0) {
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

static SearchResult engine_search_best_move(Board *board,
                                            int time_ms,
                                            int max_depth,
                                            int skill_level) {
    SearchResult raw = search_think(board, time_ms, max_depth, skill_level);
    raw = ff_refine_result(board, raw, time_ms, max_depth, skill_level);
    raw = kb_refine_phase1_result(board, raw, time_ms, max_depth, skill_level);
    raw = kb_refine_unlocked_result(board, raw, time_ms, max_depth, skill_level);
    raw = heir_refine_queen_sortie_result(board, raw, time_ms, max_depth, skill_level);
    raw = succ_refine_result(board, raw, time_ms, max_depth, skill_level);
    raw = stq_refine_result(board, raw, time_ms, max_depth, skill_level);
    return raw;
}

EXPORT void engine_init(void) {
    if (s_initialized) return;
    zobrist_init();
    s_initialized = 1;
}

EXPORT void engine_reset(int clear_tt) {
    engine_init();
    search_reset(clear_tt);
}

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Find best move                                                             */
/* ═══════════════════════════════════════════════════════════════════════════ */

EXPORT void engine_find_move(const char *fen, int mod,
                             int time_ms, int max_depth,
                             int skill_level,
                             int heir_wp, int heir_bp,
                             int truce_active, int64_t truce_frozen,
                             EngineResult *result) {
    engine_init();

    Board board;
    board_set_fen(&board, fen);
    board.mod = (GameMod)mod;
    board.heir_promoted[WHITE] = (uint8_t)(heir_wp ? 1 : 0);
    board.heir_promoted[BLACK] = (uint8_t)(heir_bp ? 1 : 0);
    board.truce_active = (uint8_t)(truce_active ? 1 : 0);
    board.truce_frozen = (uint64_t)truce_frozen;
    /* Friendly Fire: reuse truce_frozen param to carry ff_moved bitboard */
    board.ff_moved = (board.mod == MOD_FRIENDLY_FIRE) ? (uint64_t)truce_frozen : 0;
    if (board.mod == MOD_FRIENDLY_FIRE) board.truce_frozen = 0;
    /* King's Battle: reuse truce_active param to carry kb_unlocked state */
    board.kb_unlocked = (board.mod == MOD_KINGS_BATTLE) ? (uint8_t)(truce_active ? 1 : 0) : 0;
    if (board.mod == MOD_KINGS_BATTLE) board.truce_active = 0;

    SearchResult sr = engine_search_best_move(&board, time_ms, max_depth, skill_level);

    LOGD("Engine find_move: mod=%d kb_unlocked=%d skill=%d depth=%d score=%d nodes=%d move=%d->%d",
         board.mod, board.kb_unlocked, skill_level,
         sr.depth, sr.score, sr.nodes,
         MOVE_FROM(sr.best_move), MOVE_TO(sr.best_move));

    result->from_row     = SQ_ROW(MOVE_FROM(sr.best_move));
    result->from_col     = SQ_COL(MOVE_FROM(sr.best_move));
    result->to_row       = SQ_ROW(MOVE_TO(sr.best_move));
    result->to_col       = SQ_COL(MOVE_TO(sr.best_move));
    result->score        = sr.score;
    result->depth        = sr.depth;
    result->nodes        = sr.nodes;
    result->is_castling  = MOVE_IS_CASTLE(sr.best_move) ? 1 : 0;
    result->is_en_passant = MOVE_IS_EP(sr.best_move) ? 1 : 0;
    result->is_promotion = MOVE_IS_PROMO(sr.best_move) ? 1 : 0;
    result->promo_type   = MOVE_IS_PROMO(sr.best_move) ? (int)MOVE_PROMO_TYPE(sr.best_move) : 0;
}

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Find best move + apply it, return resulting FEN                          */
/* ═══════════════════════════════════════════════════════════════════════════ */

EXPORT int engine_apply_move(const char *fen, int mod,
                             int time_ms, int max_depth,
                             int skill_level,
                             int heir_wp, int heir_bp,
                             int truce_active, int64_t truce_frozen,
                             char *result_fen, int bufsize,
                             EngineResult *result) {
    engine_init();

    Board board;
    board_set_fen(&board, fen);
    board.mod = (GameMod)mod;
    board.heir_promoted[WHITE] = (uint8_t)(heir_wp ? 1 : 0);
    board.heir_promoted[BLACK] = (uint8_t)(heir_bp ? 1 : 0);
    board.truce_active = (uint8_t)(truce_active ? 1 : 0);
    board.truce_frozen = (uint64_t)truce_frozen;
    board.ff_moved = (board.mod == MOD_FRIENDLY_FIRE) ? (uint64_t)truce_frozen : 0;
    if (board.mod == MOD_FRIENDLY_FIRE) board.truce_frozen = 0;
    /* King's Battle: reuse truce_active param to carry kb_unlocked state */
    board.kb_unlocked = (board.mod == MOD_KINGS_BATTLE) ? (uint8_t)(truce_active ? 1 : 0) : 0;
    if (board.mod == MOD_KINGS_BATTLE) board.truce_active = 0;

    SearchResult sr = engine_search_best_move(&board, time_ms, max_depth, skill_level);

    result->from_row     = SQ_ROW(MOVE_FROM(sr.best_move));
    result->from_col     = SQ_COL(MOVE_FROM(sr.best_move));
    result->to_row       = SQ_ROW(MOVE_TO(sr.best_move));
    result->to_col       = SQ_COL(MOVE_TO(sr.best_move));
    result->score        = sr.score;
    result->depth        = sr.depth;
    result->nodes        = sr.nodes;
    result->is_castling  = MOVE_IS_CASTLE(sr.best_move) ? 1 : 0;
    result->is_en_passant = MOVE_IS_EP(sr.best_move) ? 1 : 0;
    result->is_promotion = MOVE_IS_PROMO(sr.best_move) ? 1 : 0;
    result->promo_type   = MOVE_IS_PROMO(sr.best_move) ? (int)MOVE_PROMO_TYPE(sr.best_move) : 0;

    /* Apply the move and generate the resulting FEN */
    if (sr.best_move != MOVE_NONE) {
        board_make_move(&board, sr.best_move);
    }
    board_get_fen(&board, result_fen, bufsize);

    return (int)strlen(result_fen);
}
