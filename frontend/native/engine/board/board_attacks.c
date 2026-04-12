#include "../board.h"

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Attack detection  (needed for legality checks)                           */
/* ═══════════════════════════════════════════════════════════════════════════ */

/* Pre-computed attack tables (initialised lazily, non-static for movegen.c) */

Bitboard knight_attacks[64];
Bitboard king_attacks[64];
Bitboard pawn_attacks[2][64]; /* [color][square] */
static bool     attacks_ready = false;

static void init_attacks(void) {
    if (attacks_ready) return;

    for (int sq = 0; sq < 64; sq++) {
        int r = SQ_ROW(sq), c = SQ_COL(sq);
        Bitboard bb;

        /* Knight */
        bb = BB_EMPTY;
        static const int kn[][2] = {
            {-2,-1},{-2,1},{-1,-2},{-1,2},{1,-2},{1,2},{2,-1},{2,1}
        };
        for (int i = 0; i < 8; i++) {
            int nr = r + kn[i][0], nc = c + kn[i][1];
            if (nr >= 0 && nr < 8 && nc >= 0 && nc < 8)
                BB_SET(bb, SQ(nr, nc));
        }
        knight_attacks[sq] = bb;

        /* King */
        bb = BB_EMPTY;
        for (int dr = -1; dr <= 1; dr++) {
            for (int dc = -1; dc <= 1; dc++) {
                if (dr == 0 && dc == 0) continue;
                int nr = r + dr, nc = c + dc;
                if (nr >= 0 && nr < 8 && nc >= 0 && nc < 8)
                    BB_SET(bb, SQ(nr, nc));
            }
        }
        king_attacks[sq] = bb;

        /* Pawn attacks (white attacks up-left/up-right) */
        pawn_attacks[WHITE][sq] = BB_EMPTY;
        if (r < 7 && c > 0) BB_SET(pawn_attacks[WHITE][sq], SQ(r+1, c-1));
        if (r < 7 && c < 7) BB_SET(pawn_attacks[WHITE][sq], SQ(r+1, c+1));

        pawn_attacks[BLACK][sq] = BB_EMPTY;
        if (r > 0 && c > 0) BB_SET(pawn_attacks[BLACK][sq], SQ(r-1, c-1));
        if (r > 0 && c < 7) BB_SET(pawn_attacks[BLACK][sq], SQ(r-1, c+1));
    }

    attacks_ready = true;
}

void board_init_attacks(void) { init_attacks(); }

/* Sliding attacks using classical approach (loop through directions) */

Bitboard bishop_attacks_calc(Square sq, Bitboard occ) {
    Bitboard attacks = BB_EMPTY;
    static const int dirs[][2] = {{1,1},{1,-1},{-1,1},{-1,-1}};
    int r = SQ_ROW(sq), c = SQ_COL(sq);
    for (int d = 0; d < 4; d++) {
        int nr = r + dirs[d][0], nc = c + dirs[d][1];
        while (nr >= 0 && nr < 8 && nc >= 0 && nc < 8) {
            Square s = SQ(nr, nc);
            BB_SET(attacks, s);
            if (BB_HAS(occ, s)) break;
            nr += dirs[d][0]; nc += dirs[d][1];
        }
    }
    return attacks;
}

Bitboard rook_attacks_calc(Square sq, Bitboard occ) {
    Bitboard attacks = BB_EMPTY;
    static const int dirs[][2] = {{1,0},{-1,0},{0,1},{0,-1}};
    int r = SQ_ROW(sq), c = SQ_COL(sq);
    for (int d = 0; d < 4; d++) {
        int nr = r + dirs[d][0], nc = c + dirs[d][1];
        while (nr >= 0 && nr < 8 && nc >= 0 && nc < 8) {
            Square s = SQ(nr, nc);
            BB_SET(attacks, s);
            if (BB_HAS(occ, s)) break;
            nr += dirs[d][0]; nc += dirs[d][1];
        }
    }
    return attacks;
}

/* Is square `sq` attacked by side `by`? */
bool board_square_attacked(const Board *b, Square sq, Color by) {
    init_attacks();

    /* Kings Battle Phase 1 matches the Dart rules: only kings and pawns
       control squares until an unlocking move has been fully committed. */
    bool kb_phase1 = (b->mod == MOD_KINGS_BATTLE && !b->kb_unlocked);

    /* Knights */
    if (!kb_phase1 && (knight_attacks[sq] & b->pieces[by][KNIGHT])) return true;

    /* King */
    if (king_attacks[sq] & b->pieces[by][KING]) return true;

    /* Pawns */
    if (b->mod == MOD_MERCENARY) {
        /* In Mercenary, pawns attack like kings (one square any direction) */
        if (king_attacks[sq] & b->pieces[by][PAWN]) return true;
    } else {
        /* Standard diagonal pawn attacks (from the defender's perspective) */
        Color def = color_opposite(by);
        if (pawn_attacks[def][sq] & b->pieces[by][PAWN]) return true;
    }

    if (kb_phase1) return false;

    /* ── Save the Queen: prisoner queens cannot attack (no captures) ── */
    Bitboard effective_queens = b->pieces[by][QUEEN];
    if (b->mod == MOD_SAVE_QUEEN) {
        Bitboard qq = effective_queens;
        while (qq) {
            Square qsq = (Square)bb_pop_lsb(&qq);
            if (!stq_is_own_half(qsq, by))      /* prisoner */
                effective_queens &= ~BB_SQ(qsq);
        }
    }

    /* Bishops / Queens (diagonal) */
    Bitboard diag = bishop_attacks_calc(sq, b->all);
    if (diag & (b->pieces[by][BISHOP] | effective_queens)) return true;

    /* Rooks / Queens (orthogonal) */
    Bitboard orth = rook_attacks_calc(sq, b->all);
    if (orth & (b->pieces[by][ROOK] | effective_queens)) return true;

    return false;
}

bool board_in_check(const Board *b, Color side) {
    Bitboard kingBB = b->pieces[side][KING];
    if (kingBB == BB_EMPTY) return false;
    /* Heir: check only matters when check rules apply */
    if (b->mod == MOD_HEIR && !heir_check_applies(b, side)) return false;
    /* Truce: no check during active truce */
    if (b->mod == MOD_TRUCE && b->truce_active) return false;
    Square ksq = bb_lsb(kingBB);
    return board_square_attacked(b, ksq, color_opposite(side));
}
