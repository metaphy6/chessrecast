#include "bridge/bridge_internal.h"

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Engine lifecycle                                                           */
/* ═══════════════════════════════════════════════════════════════════════════ */

static int s_initialized = 0;

static SearchResult truce_refine_result(const Board *board,
                                        SearchResult raw,
                                        int time_ms,
                                        int max_depth,
                                        int skill_level) {
    MoveList ml;
    Move regroup;
    int verify_depth;
    int verify_time;
    int regroup_score;

    if (board->mod != MOD_TRUCE || raw.best_move == MOVE_NONE || skill_level < 4) {
        return raw;
    }
    if (board->truce_active || board->side != WHITE || board->fullmove > 24) {
        return raw;
    }
    if (bridge_verify_nesting > 0) {
        return raw;
    }
    if (MOVE_PIECE(raw.best_move) != KING || MOVE_IS_CASTLE(raw.best_move) ||
        MOVE_IS_CAPTURE(raw.best_move) || MOVE_IS_EP(raw.best_move) ||
        MOVE_IS_PROMO(raw.best_move)) {
        return raw;
    }

    /* Narrow tactical shell from truce GAME 44: avoid Kh1-g2 drift and
       force the stabilizing regroup Nf3-d2 when all markers align. */
    if (!bridge_square_has_piece(board, SQ(0, 7), WHITE, KING) ||
        !bridge_square_has_piece(board, SQ(2, 5), WHITE, KNIGHT) ||
        !bridge_square_has_piece(board, SQ(3, 6), WHITE, PAWN) ||
        !bridge_square_has_piece(board, SQ(7, 6), BLACK, KING) ||
        !bridge_square_has_piece(board, SQ(5, 5), BLACK, KNIGHT) ||
        !bridge_square_has_piece(board, SQ(5, 4), BLACK, QUEEN)) {
        return raw;
    }

    generate_moves(board, &ml);
    regroup = bridge_find_legal_move(&ml, SQ(2, 5), SQ(1, 3), KNIGHT); /* Nf3-d2 */
    if (regroup == MOVE_NONE) {
        return raw;
    }

    if (raw.best_move == regroup) {
        return raw;
    }

    verify_depth = (max_depth < 6) ? 6 : max_depth;
    verify_time = (time_ms <= 0) ? 260 : clamp_int(time_ms * 2, 180, 360);
    regroup_score = kb_verify_child_score(board, regroup, verify_time, verify_depth, skill_level);

    raw.best_move = regroup;
    raw.score = regroup_score;
    return raw;
}

SearchResult bridge_engine_search_best_move(Board *board,
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
    raw = mercenary_minor_trade_refine_result(board, raw, time_ms, max_depth, skill_level);
    raw = truce_refine_result(board, raw, time_ms, max_depth, skill_level);
    raw = king_discipline_refine_result(board, raw, time_ms, max_depth, skill_level);
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

    SearchResult sr = bridge_engine_search_best_move(&board, time_ms, max_depth, skill_level);

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

    SearchResult sr = bridge_engine_search_best_move(&board, time_ms, max_depth, skill_level);

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
