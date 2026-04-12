#include "movegen.h"
#include "movegen/movegen_internal.h"
#include <string.h>

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Public API                                                               */
/* ═══════════════════════════════════════════════════════════════════════════ */

void generate_moves(const Board *b, MoveList *ml) {
    movelist_clear(ml);
    board_init_attacks();  /* ensure knight/king/pawn tables are ready */
    /* We need a mutable copy to test legality */
    Board tmp;
    memcpy(&tmp, b, sizeof(Board));

    MoveList pseudo;
    movelist_clear(&pseudo);

    gen_pawn_moves(b, &pseudo, false);
    gen_piece_moves(b, &pseudo, KNIGHT, false);
    gen_piece_moves(b, &pseudo, BISHOP, false);
    gen_piece_moves(b, &pseudo, ROOK,   false);
    gen_piece_moves(b, &pseudo, QUEEN,  false);
    gen_piece_moves(b, &pseudo, KING,   false);
    gen_castling(b, &pseudo);

    /* Filter legal moves */
    for (int i = 0; i < pseudo.count; i++) {
        if (is_legal(&tmp, pseudo.moves[i])) {
            movelist_add(ml, pseudo.moves[i]);
        }
    }
}

void generate_captures(const Board *b, MoveList *ml) {
    movelist_clear(ml);
    /* Truce: no captures allowed during active truce */
    if (b->mod == MOD_TRUCE && b->truce_active) return;
    board_init_attacks();  /* ensure knight/king/pawn tables are ready */
    Board tmp;
    memcpy(&tmp, b, sizeof(Board));

    MoveList pseudo;
    movelist_clear(&pseudo);

    gen_pawn_moves(b, &pseudo, true);
    gen_piece_moves(b, &pseudo, KNIGHT, true);
    gen_piece_moves(b, &pseudo, BISHOP, true);
    gen_piece_moves(b, &pseudo, ROOK,   true);
    gen_piece_moves(b, &pseudo, QUEEN,  true);
    gen_piece_moves(b, &pseudo, KING,   true);

    for (int i = 0; i < pseudo.count; i++) {
        if (is_legal(&tmp, pseudo.moves[i])) {
            movelist_add(ml, pseudo.moves[i]);
        }
    }
}

bool has_legal_moves(const Board *b) {
    MoveList ml;
    generate_moves(b, &ml);
    return ml.count > 0;
}
