#include "../board.h"

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Zobrist hashing                                                          */
/* ═══════════════════════════════════════════════════════════════════════════ */

static uint64_t zob_piece[2][6][64]; /* [color][type][square] */
uint64_t zob_side;
static uint64_t zob_castle[16];
uint64_t zob_ep[64];
static uint64_t zob_heir_promoted[2]; /* Heir: key for each side's promoted flag */
static uint64_t zob_truce_active;    /* Truce: key for active-truce state */
static uint64_t zob_kb_unlocked;     /* King's Battle: key for unlocked state */
static bool     zob_ready = false;

/* Simple xorshift64 PRNG */
static uint64_t xor_state = 0x12345678ABCDEF01ULL;

static uint64_t xor_next(void) {
    xor_state ^= xor_state << 13;
    xor_state ^= xor_state >> 7;
    xor_state ^= xor_state << 17;
    return xor_state;
}

void zobrist_init(void) {
    if (zob_ready) return;
    for (int c = 0; c < 2; c++)
        for (int t = 0; t < 6; t++)
            for (int sq = 0; sq < 64; sq++)
                zob_piece[c][t][sq] = xor_next();
    zob_side = xor_next();
    for (int i = 0; i < 16; i++) zob_castle[i] = xor_next();
    for (int sq = 0; sq < 64; sq++) zob_ep[sq] = xor_next();
    zob_heir_promoted[0] = xor_next();
    zob_heir_promoted[1] = xor_next();
    zob_truce_active = xor_next();
    zob_kb_unlocked = xor_next();
    zob_ready = true;
}

uint64_t zobrist_compute(const Board *b) {
    uint64_t h = 0;
    for (int c = 0; c < 2; c++) {
        for (int t = 0; t < 6; t++) {
            Bitboard bb = b->pieces[c][t];
            while (bb) {
                Square sq = (Square)bb_pop_lsb(&bb);
                h ^= zob_piece[c][t][sq];
            }
        }
    }
    if (b->side == BLACK) h ^= zob_side;
    h ^= zob_castle[b->castling];
    if (b->ep_square != SQ_NONE) h ^= zob_ep[b->ep_square];
    /* Heir: promoted-king flags change check/eval semantics */
    for (int c = 0; c < 2; c++)
        if (b->heir_promoted[c]) h ^= zob_heir_promoted[c];
    /* Truce: active-truce changes legal moves (no captures, no check) */
    if (b->truce_active) h ^= zob_truce_active;
    /* King's Battle: unlocked state changes legal moves */
    if (b->kb_unlocked) h ^= zob_kb_unlocked;
    return h;
}
