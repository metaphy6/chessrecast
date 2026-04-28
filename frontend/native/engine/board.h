#ifndef CHESS_BOARD_H
#define CHESS_BOARD_H

#include "types.h"

/* ── Board state ──────────────────────────────────────────────────────────── */

#define MAX_HISTORY 512

typedef struct {
    /* Bitboards per piece-type per color: pieces[WHITE][PAWN] etc. */
    Bitboard pieces[2][6];

    /* Aggregate occupancy */
    Bitboard occupied[2]; /* occupied[WHITE], occupied[BLACK] */
    Bitboard all;         /* occupied[WHITE] | occupied[BLACK] */

    /* Mailbox: which Piece sits on each square (fast lookup) */
    Piece    mailbox[64];

    Color    side;           /* side to move */
    uint8_t  castling;       /* CASTLE_WK | CASTLE_WQ | ... */
    Square   ep_square;      /* en-passant target square or SQ_NONE */
    int      halfmove;       /* 50-move rule counter */
    int      fullmove;       /* full move number */

    GameMod  mod;            /* game mod */

    /* Heir mod state: whether each side has promoted a pawn to king */
    uint8_t  heir_promoted[2]; /* [WHITE]=0/1, [BLACK]=0/1 */

    /* Truce mod state: whether truce is currently active (no captures, no check) */
    uint8_t  truce_active;

    /* Truce mod: bitboard of squares whose pieces have already moved (1 move each) */
    uint64_t truce_frozen;

    /* Friendly Fire mod: bitboard of squares whose pieces have moved (capturable by own side) */
    uint64_t ff_moved;

    /* King's Battle mod: whether pieces are unlocked (0=Phase 1: kings+pawns only, 1=Phase 2: all) */
    uint8_t  kb_unlocked;

    /* King's Battle mod: count of trailing consecutive non-capturing king
     * moves (across both colors). When this reaches 6 in Phase 1, Phase 2
     * unlocks automatically (deadlock rule). Reset by any pawn move or
     * any capture. */
    uint8_t  kb_idle_kings;

    /* Zobrist hash */
    uint64_t hash;

    /* Undo stack */
    struct {
        Move     move;
        Piece    captured;      /* the actual Piece removed (may differ from sq) */
        Square   captured_sq;   /* where the capture happened (differs for EP) */
        uint8_t  castling;
        Square   ep_square;
        int      halfmove;
        uint64_t hash;
        uint8_t  heir_promoted[2]; /* saved heir state for undo */
        uint8_t  truce_active;     /* saved truce state for undo */
        uint64_t truce_frozen;     /* saved truce frozen bitboard for undo */
        uint64_t ff_moved;         /* saved friendly fire state for undo */
        uint8_t  kb_unlocked;      /* saved king's battle state for undo */
        uint8_t  kb_idle_kings;    /* saved trailing idle-king count for undo */
        uint8_t  kb_bonus;         /* did this move grant a bonus (no side switch)? */
        uint8_t  stq_reprisoned;   /* save-the-queen: captured prisoner returned to prison */
        Square   stq_reprison_sq;  /* where that prisoner queen was re-placed */
    } history[MAX_HISTORY];
    int ply;
} Board;

/* ── Zobrist ──────────────────────────────────────────────────────────────── */

void     zobrist_init(void);
uint64_t zobrist_compute(const Board *b);

/* ── Board operations ─────────────────────────────────────────────────────── */

void board_init(Board *b, GameMod mod);
void board_set_fen(Board *b, const char *fen);
void board_get_fen(const Board *b, char *buf, int bufsize);

void board_make_move(Board *b, Move m);
void board_unmake_move(Board *b);

/* Query helpers */
bool board_square_attacked(const Board *b, Square sq, Color by);
bool board_in_check(const Board *b, Color side);

/* Refresh aggregate bitboards + hash (call after manual edits) */
void board_refresh(Board *b);

/* Ensure pre-computed attack tables are ready (idempotent) */
void board_init_attacks(void);

/* ── Attack tables & sliding-attack generators (defined in board.c) ────── */

extern Bitboard knight_attacks[64];
extern Bitboard king_attacks[64];
extern Bitboard pawn_attacks[2][64];

Bitboard bishop_attacks_calc(Square sq, Bitboard occ);
Bitboard rook_attacks_calc(Square sq, Bitboard occ);

/* ── Heir mod helper (shared across board/movegen/evaluate) ────────────── */

/* Heir: check rules apply when a side has promoted a pawn to king or has no pawns */
static inline bool heir_check_applies(const Board *b, Color side) {
    return b->heir_promoted[side] || b->pieces[side][PAWN] == BB_EMPTY;
}

/* ── Zobrist incremental update helpers ───────────────────────────────────── */

extern uint64_t zob_side;
extern uint64_t zob_ep[64];

#endif /* CHESS_BOARD_H */
