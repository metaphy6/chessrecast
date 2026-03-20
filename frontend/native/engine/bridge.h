#ifndef CHESS_BRIDGE_H
#define CHESS_BRIDGE_H

#include <stdint.h>

/* Platform export macro */
#if defined(_WIN32) || defined(_WIN64)
  #define EXPORT __declspec(dllexport)
#else
  #define EXPORT __attribute__((visibility("default")))
#endif

/* ── Result struct returned to Dart ───────────────────────────────────────── */

typedef struct {
    int32_t from_row;
    int32_t from_col;
    int32_t to_row;
    int32_t to_col;
    int32_t score;
    int32_t depth;
    int32_t nodes;
    int32_t is_castling;
    int32_t is_en_passant;
    int32_t is_promotion;
    int32_t promo_type;   /* 0=Q, 1=R, 2=B, 3=N (maps to PieceType) */
} EngineResult;

/* ── Public FFI functions ─────────────────────────────────────────────────── */

#ifdef __cplusplus
extern "C" {
#endif

/* Initialize the engine (call once at app startup). */
EXPORT void engine_init(void);

/* Find the best move for the given FEN position.
   mod          : 0 = classic, 1 = mercenary, 2 = heir, 3 = truce
   time_ms      : thinking time in milliseconds
   max_depth    : maximum search depth (0 = unlimited)
   skill_level  : 0 = easy … 4 = maximum
   heir_wp      : heir mod: 1 if white has promoted a pawn to king, 0 otherwise
   heir_bp      : heir mod: 1 if black has promoted a pawn to king, 0 otherwise
   truce_active : truce mod: 1 if truce phase is still active, 0 otherwise
   truce_frozen : bitboard of squares whose pieces have exhausted the 3-move limit
   result       : pointer to EngineResult struct — filled by the function */
EXPORT void engine_find_move(const char *fen, int mod,
                             int time_ms, int max_depth,
                             int skill_level,
                             int heir_wp, int heir_bp,
                             int truce_active, int64_t truce_frozen,
                             EngineResult *result);

/* Get the resulting FEN after the engine's best move is applied.
   Returns the number of chars written (excluding null terminator).
   buf must be at least 128 bytes. */
EXPORT int engine_apply_move(const char *fen, int mod,
                             int time_ms, int max_depth,
                             int skill_level,
                             int heir_wp, int heir_bp,
                             int truce_active, int64_t truce_frozen,
                             char *result_fen, int bufsize,
                             EngineResult *result);

#ifdef __cplusplus
}
#endif

#endif /* CHESS_BRIDGE_H */
