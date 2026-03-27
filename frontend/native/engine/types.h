#ifndef CHESS_TYPES_H
#define CHESS_TYPES_H

#include <stdint.h>
#include <stdbool.h>

/* ── Piece colors ─────────────────────────────────────────────────────────── */

typedef enum { WHITE = 0, BLACK = 1, COLOR_NONE = 2 } Color;

static inline Color color_opposite(Color c) { return c ^ 1; }

/* ── Piece types ──────────────────────────────────────────────────────────── */

typedef enum {
    PAWN   = 0,
    KNIGHT = 1,
    BISHOP = 2,
    ROOK   = 3,
    QUEEN  = 4,
    KING   = 5,
    PIECE_NONE = 6
} PieceType;

/* ── Piece (color + type packed into one byte) ────────────────────────────── */

typedef uint8_t Piece;

#define PIECE_MAKE(color, type)  ((Piece)(((color) << 3) | (type)))
#define PIECE_COLOR(p)           ((Color)((p) >> 3))
#define PIECE_TYPE(p)            ((PieceType)((p) & 7))
#define PIECE_EMPTY              PIECE_MAKE(COLOR_NONE, PIECE_NONE)

/* ── Square index (0..63, a1=0, h8=63) ────────────────────────────────────── */

typedef int8_t Square;

#define SQ_NONE        (-1)
#define SQ(row, col)   ((Square)((row) * 8 + (col)))
#define SQ_ROW(sq)     ((sq) >> 3)
#define SQ_COL(sq)     ((sq) & 7)
#define SQ_VALID(sq)   ((sq) >= 0 && (sq) < 64)

/* ── Bitboard ─────────────────────────────────────────────────────────────── */

typedef uint64_t Bitboard;

#define BB_EMPTY        ((Bitboard)0)
#define BB_FULL         ((Bitboard)0xFFFFFFFFFFFFFFFFULL)
#define BB_SQ(sq)       ((Bitboard)1 << (sq))
#define BB_SET(bb, sq)  ((bb) |=  BB_SQ(sq))
#define BB_CLR(bb, sq)  ((bb) &= ~BB_SQ(sq))
#define BB_HAS(bb, sq)  (((bb) >> (sq)) & 1)

static inline int bb_popcount(Bitboard bb) {
#if defined(__GNUC__) || defined(__clang__)
    return __builtin_popcountll(bb);
#elif defined(_MSC_VER)
    return (int)__popcnt64(bb);
#else
    int count = 0;
    while (bb) { count++; bb &= bb - 1; }
    return count;
#endif
}

static inline Square bb_lsb(Bitboard bb) {
#if defined(__GNUC__) || defined(__clang__)
    return (Square)__builtin_ctzll(bb);
#else
    Square i = 0;
    while (!((bb >> i) & 1)) i++;
    return i;
#endif
}

static inline Bitboard bb_pop_lsb(Bitboard *bb) {
    Square sq = bb_lsb(*bb);
    *bb &= *bb - 1;
    return sq;
}

/* ── Move encoding (32 bits) ──────────────────────────────────────────────── */
/*  bits  0-5:  from square                                                   */
/*  bits  6-11: to square                                                     */
/*  bits 12-14: piece type moved                                              */
/*  bits 15-17: captured piece type (PIECE_NONE if quiet)                     */
/*  bit  18:    is castling                                                   */
/*  bit  19:    is en passant                                                 */
/*  bit  20:    is promotion                                                  */
/*  bits 21-23: promotion piece type                                          */

typedef uint32_t Move;

#define MOVE_NONE 0

#define MOVE_FROM(m)       ((Square)((m) & 0x3F))
#define MOVE_TO(m)         ((Square)(((m) >> 6) & 0x3F))
#define MOVE_PIECE(m)      ((PieceType)(((m) >> 12) & 7))
#define MOVE_CAPTURED(m)   ((PieceType)(((m) >> 15) & 7))
#define MOVE_IS_CASTLE(m)  (((m) >> 18) & 1)
#define MOVE_IS_EP(m)      (((m) >> 19) & 1)
#define MOVE_IS_PROMO(m)   (((m) >> 20) & 1)
#define MOVE_PROMO_TYPE(m) ((PieceType)(((m) >> 21) & 7))
#define MOVE_IS_CAPTURE(m) (MOVE_CAPTURED(m) != PIECE_NONE)

static inline Move move_encode(Square from, Square to, PieceType piece,
                               PieceType captured, bool castle,
                               bool ep, bool promo, PieceType promoType) {
    return (Move)(
        ((uint32_t)from)         |
        ((uint32_t)to   << 6)    |
        ((uint32_t)piece << 12)  |
        ((uint32_t)captured << 15) |
        ((uint32_t)castle << 18) |
        ((uint32_t)ep << 19)     |
        ((uint32_t)promo << 20)  |
        ((uint32_t)promoType << 21)
    );
}

static inline Move move_simple(Square from, Square to, PieceType piece) {
    return move_encode(from, to, piece, PIECE_NONE, false, false, false, PIECE_NONE);
}

static inline Move move_capture(Square from, Square to,
                                PieceType piece, PieceType captured) {
    return move_encode(from, to, piece, captured, false, false, false, PIECE_NONE);
}

/* ── Move list ────────────────────────────────────────────────────────────── */

#define MAX_MOVES 256

typedef struct {
    Move moves[MAX_MOVES];
    int  count;
} MoveList;

static inline void movelist_clear(MoveList *ml) { ml->count = 0; }
static inline void movelist_add(MoveList *ml, Move m) {
    if (ml->count < MAX_MOVES) ml->moves[ml->count++] = m;
}

/* ── Castling rights (4 bits) ─────────────────────────────────────────────── */

#define CASTLE_WK  1  /* White kingside  */
#define CASTLE_WQ  2  /* White queenside */
#define CASTLE_BK  4  /* Black kingside  */
#define CASTLE_BQ  8  /* Black queenside */

/* ── Game mod ─────────────────────────────────────────────────────────────── */

typedef enum {
    MOD_CLASSIC       = 0,
    MOD_MERCENARY     = 1,
    MOD_HEIR          = 2,
    MOD_TRUCE         = 3,
    MOD_FRIENDLY_FIRE = 4,
    MOD_KINGS_BATTLE  = 5,
    MOD_SAVE_QUEEN    = 6,
    MOD_SUCCESSION    = 7
} GameMod;

/* ── Save the Queen helpers ───────────────────────────────────────────────── */

#define STQ_WHITE_PRISON   SQ(7, 3)  /* d8 – white queen starts here */
#define STQ_BLACK_PRISON   SQ(0, 3)  /* d1 – black queen starts here */

/* White's own half: rows 0-3 (ranks 1-4).  Black's own half: rows 4-7. */
static inline bool stq_is_own_half(Square sq, Color c) {
    return (c == WHITE) ? (SQ_ROW(sq) <= 3) : (SQ_ROW(sq) >= 4);
}

/* Is the queen at its designated prison square? */
static inline bool stq_on_prison(Square sq, Color c) {
    return (c == WHITE) ? (sq == STQ_WHITE_PRISON) : (sq == STQ_BLACK_PRISON);
}

#endif /* CHESS_TYPES_H */
