#include "bridge.h"
#include "board.h"
#include "search.h"
#include "search/variant_heuristics.h"
#include "movegen.h"
#include <string.h>
#include <stdio.h>

#ifdef __ANDROID__
#include <android/log.h>
#define LOGD(...) __android_log_print(ANDROID_LOG_DEBUG, "CHESS_ENGINE", __VA_ARGS__)
#else
#define LOGD(...) fprintf(stderr, __VA_ARGS__)
#endif

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Engine lifecycle                                                         */
/* ═══════════════════════════════════════════════════════════════════════════ */

static int s_initialized = 0;

static int clamp_int(int value, int lower, int upper) {
    if (value < lower) return lower;
    if (value > upper) return upper;
    return value;
}

static int kb_verify_child_score(const Board *root, Move move,
                                 int time_ms, int max_depth, int skill_level) {
    Board child = *root;
    Color mover = child.side;
    SearchResult reply;

    board_make_move(&child, move);
    search_reset(1);
    reply = search_think(&child, time_ms, max_depth, skill_level);
    return (child.side == mover) ? reply.score : -reply.score;
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

static SearchResult engine_search_best_move(Board *board,
                                            int time_ms,
                                            int max_depth,
                                            int skill_level) {
    SearchResult raw = search_think(board, time_ms, max_depth, skill_level);
    raw = kb_refine_unlocked_result(board, raw, time_ms, max_depth, skill_level);
    raw = heir_refine_queen_sortie_result(board, raw, time_ms, max_depth, skill_level);
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
