#include "bridge.h"
#include "board.h"
#include "search.h"
#include "movegen.h"
#include <string.h>

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Engine lifecycle                                                         */
/* ═══════════════════════════════════════════════════════════════════════════ */

static int s_initialized = 0;

EXPORT void engine_init(void) {
    if (s_initialized) return;
    zobrist_init();
    s_initialized = 1;
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

    SearchResult sr = search_think(&board, time_ms, max_depth, skill_level);

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

    SearchResult sr = search_think(&board, time_ms, max_depth, skill_level);

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
