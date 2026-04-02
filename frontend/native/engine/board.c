#include "board.h"
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <ctype.h>

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

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Board helpers                                                            */
/* ═══════════════════════════════════════════════════════════════════════════ */

static void board_clear(Board *b) {
    memset(b, 0, sizeof(Board));
    b->ep_square = SQ_NONE;
    b->heir_promoted[0] = 0;
    b->heir_promoted[1] = 0;
    b->truce_active = 0;
    b->truce_frozen = 0;
    b->kb_unlocked = 0;
    for (int sq = 0; sq < 64; sq++) b->mailbox[sq] = PIECE_EMPTY;
}

static void board_place(Board *b, Square sq, Color c, PieceType t) {
    Piece p = PIECE_MAKE(c, t);
    b->mailbox[sq] = p;
    BB_SET(b->pieces[c][t], sq);
    BB_SET(b->occupied[c], sq);
    BB_SET(b->all, sq);
}

static void board_remove(Board *b, Square sq) {
    Piece p = b->mailbox[sq];
    if (p == PIECE_EMPTY) return;
    Color c = PIECE_COLOR(p);
    PieceType t = PIECE_TYPE(p);
    BB_CLR(b->pieces[c][t], sq);
    BB_CLR(b->occupied[c], sq);
    BB_CLR(b->all, sq);
    b->mailbox[sq] = PIECE_EMPTY;
}

void board_refresh(Board *b) {
    b->occupied[WHITE] = BB_EMPTY;
    b->occupied[BLACK] = BB_EMPTY;
    for (int t = 0; t < 6; t++) {
        b->occupied[WHITE] |= b->pieces[WHITE][t];
        b->occupied[BLACK] |= b->pieces[BLACK][t];
    }
    b->all = b->occupied[WHITE] | b->occupied[BLACK];
    b->hash = zobrist_compute(b);
}

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  FEN                                                                      */
/* ═══════════════════════════════════════════════════════════════════════════ */

void board_set_fen(Board *b, const char *fen) {
    board_clear(b);
    int row = 7, col = 0, i = 0;

    /* 1. Piece placement */
    while (fen[i] && fen[i] != ' ') {
        char ch = fen[i++];
        if (ch == '/') {
            row--; col = 0;
        } else if (ch >= '1' && ch <= '8') {
            col += ch - '0';
        } else {
            Color c = isupper(ch) ? WHITE : BLACK;
            PieceType t;
            switch (tolower(ch)) {
                case 'p': t = PAWN;   break;
                case 'n': t = KNIGHT; break;
                case 'b': t = BISHOP; break;
                case 'r': t = ROOK;   break;
                case 'q': t = QUEEN;  break;
                case 'k': t = KING;   break;
                default:  t = PIECE_NONE; break;
            }
            if (t != PIECE_NONE && row >= 0 && col < 8) {
                board_place(b, SQ(row, col), c, t);
            }
            col++;
        }
    }
    if (fen[i] == ' ') i++;

    /* 2. Side to move */
    b->side = (fen[i] == 'b') ? BLACK : WHITE;
    while (fen[i] && fen[i] != ' ') i++;
    if (fen[i] == ' ') i++;

    /* 3. Castling */
    b->castling = 0;
    while (fen[i] && fen[i] != ' ') {
        switch (fen[i]) {
            case 'K': b->castling |= CASTLE_WK; break;
            case 'Q': b->castling |= CASTLE_WQ; break;
            case 'k': b->castling |= CASTLE_BK; break;
            case 'q': b->castling |= CASTLE_BQ; break;
            default: break;
        }
        i++;
    }
    if (fen[i] == ' ') i++;

    /* 4. En passant */
    if (fen[i] == '-') {
        b->ep_square = SQ_NONE;
        i++;
    } else if (fen[i] >= 'a' && fen[i] <= 'h') {
        int epc = fen[i] - 'a'; i++;
        int epr = fen[i] - '1'; i++;
        b->ep_square = SQ(epr, epc);
    }
    if (fen[i] == ' ') i++;

    /* 5. Halfmove clock */
    b->halfmove = 0;
    while (fen[i] && fen[i] != ' ') {
        b->halfmove = b->halfmove * 10 + (fen[i] - '0');
        i++;
    }
    if (fen[i] == ' ') i++;

    /* 6. Fullmove number */
    b->fullmove = 0;
    while (fen[i] && fen[i] >= '0' && fen[i] <= '9') {
        b->fullmove = b->fullmove * 10 + (fen[i] - '0');
        i++;
    }
    if (b->fullmove < 1) b->fullmove = 1;

    board_refresh(b);
}

void board_get_fen(const Board *b, char *buf, int bufsize) {
    int pos = 0;
    for (int row = 7; row >= 0; row--) {
        int empty = 0;
        for (int col = 0; col < 8; col++) {
            Piece p = b->mailbox[SQ(row, col)];
            if (p == PIECE_EMPTY) {
                empty++;
            } else {
                if (empty > 0) { buf[pos++] = '0' + empty; empty = 0; }
                const char syms[] = "pnbrqk";
                char ch = syms[PIECE_TYPE(p)];
                if (PIECE_COLOR(p) == WHITE) ch = toupper(ch);
                buf[pos++] = ch;
            }
        }
        if (empty > 0) buf[pos++] = '0' + empty;
        if (row > 0) buf[pos++] = '/';
    }

    buf[pos++] = ' ';
    buf[pos++] = b->side == WHITE ? 'w' : 'b';
    buf[pos++] = ' ';

    if (b->castling == 0) {
        buf[pos++] = '-';
    } else {
        if (b->castling & CASTLE_WK) buf[pos++] = 'K';
        if (b->castling & CASTLE_WQ) buf[pos++] = 'Q';
        if (b->castling & CASTLE_BK) buf[pos++] = 'k';
        if (b->castling & CASTLE_BQ) buf[pos++] = 'q';
    }

    buf[pos++] = ' ';
    if (b->ep_square == SQ_NONE) {
        buf[pos++] = '-';
    } else {
        buf[pos++] = 'a' + SQ_COL(b->ep_square);
        buf[pos++] = '1' + SQ_ROW(b->ep_square);
    }

    pos += snprintf(buf + pos, bufsize - pos, " %d %d",
                    b->halfmove, b->fullmove);
    buf[pos] = '\0';
}

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Board initialization                                                     */
/* ═══════════════════════════════════════════════════════════════════════════ */

void board_init(Board *b, GameMod mod) {
    const char *startpos =
        "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1";
    board_set_fen(b, startpos);
    b->mod = mod;
}

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

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Make / Unmake move                                                       */
/* ═══════════════════════════════════════════════════════════════════════════ */

void board_make_move(Board *b, Move m) {
    /* Save state to undo stack */
    int idx = b->ply;
    b->history[idx].move       = m;
    b->history[idx].castling   = b->castling;
    b->history[idx].ep_square  = b->ep_square;
    b->history[idx].halfmove   = b->halfmove;
    b->history[idx].hash       = b->hash;
    b->history[idx].captured   = PIECE_EMPTY;
    b->history[idx].captured_sq = SQ_NONE;
    b->history[idx].heir_promoted[0] = b->heir_promoted[0];
    b->history[idx].heir_promoted[1] = b->heir_promoted[1];
    b->history[idx].truce_active = b->truce_active;
    b->history[idx].truce_frozen = b->truce_frozen;
    b->history[idx].ff_moved = b->ff_moved;
    b->history[idx].kb_unlocked = b->kb_unlocked;
    b->history[idx].kb_bonus = 0;

    Square from = MOVE_FROM(m);
    Square to   = MOVE_TO(m);
    Color  us   = b->side;
    Color  them = color_opposite(us);
    PieceType pt = MOVE_PIECE(m);

    /* Handle captures */
    if (MOVE_IS_EP(m)) {
        /* En passant: captured pawn is on the same rank as 'from', same col as 'to' */
        Square cap_sq = SQ(SQ_ROW(from), SQ_COL(to));
        b->history[idx].captured    = b->mailbox[cap_sq];
        b->history[idx].captured_sq = cap_sq;
        board_remove(b, cap_sq);
    } else if (MOVE_IS_CAPTURE(m)) {
        b->history[idx].captured    = b->mailbox[to];
        b->history[idx].captured_sq = to;
        board_remove(b, to);
    }

    /* Move the piece */
    board_remove(b, from);

    if (MOVE_IS_PROMO(m)) {
        PieceType promo_pt = MOVE_PROMO_TYPE(m);
        board_place(b, to, us, promo_pt);
        /* Heir: track pawn-to-king promotion */
        if (b->mod == MOD_HEIR && promo_pt == KING) {
            b->heir_promoted[us] = 1;
        }
        /* Succession: track pawn-to-king promotion (reuse heir_promoted) */
        if (b->mod == MOD_SUCCESSION && promo_pt == KING) {
            b->heir_promoted[us] = 1;
        }
    } else {
        board_place(b, to, us, pt);
    }

    /* Castling: also move the rook */
    if (MOVE_IS_CASTLE(m)) {
        if (to == SQ(0, 6)) {          /* White kingside */
            board_remove(b, SQ(0, 7));
            board_place(b, SQ(0, 5), WHITE, ROOK);
        } else if (to == SQ(0, 2)) {   /* White queenside */
            board_remove(b, SQ(0, 0));
            board_place(b, SQ(0, 3), WHITE, ROOK);
        } else if (to == SQ(7, 6)) {   /* Black kingside */
            board_remove(b, SQ(7, 7));
            board_place(b, SQ(7, 5), BLACK, ROOK);
        } else if (to == SQ(7, 2)) {   /* Black queenside */
            board_remove(b, SQ(7, 0));
            board_place(b, SQ(7, 3), BLACK, ROOK);
        }
    }

    /* Truce: track which current squares now hold pieces that have moved. */
    if (b->mod == MOD_TRUCE && b->truce_active) {
        b->truce_frozen &= ~BB_SQ(from);
        b->truce_frozen |= BB_SQ(to);
        if (MOVE_IS_EP(m)) {
            Square cap_sq = SQ(SQ_ROW(from), SQ_COL(to));
            b->truce_frozen &= ~BB_SQ(cap_sq);
        } else if (MOVE_IS_CAPTURE(m)) {
            b->truce_frozen &= ~BB_SQ(to);
            b->truce_frozen |= BB_SQ(to);
        }
        if (MOVE_IS_CASTLE(m)) {
            if (to == SQ(0, 6))      { b->truce_frozen &= ~BB_SQ(SQ(0,7)); b->truce_frozen |= BB_SQ(SQ(0,5)); }
            else if (to == SQ(0, 2)) { b->truce_frozen &= ~BB_SQ(SQ(0,0)); b->truce_frozen |= BB_SQ(SQ(0,3)); }
            else if (to == SQ(7, 6)) { b->truce_frozen &= ~BB_SQ(SQ(7,7)); b->truce_frozen |= BB_SQ(SQ(7,5)); }
            else if (to == SQ(7, 2)) { b->truce_frozen &= ~BB_SQ(SQ(7,0)); b->truce_frozen |= BB_SQ(SQ(7,3)); }
        }
    }

    /* Friendly Fire: track which squares have pieces that moved */
    if (b->mod == MOD_FRIENDLY_FIRE) {
        b->ff_moved &= ~BB_SQ(from);       /* source square now empty */
        b->ff_moved |= BB_SQ(to);          /* piece at dest has moved */
        if (MOVE_IS_EP(m)) {
            Square cap_sq = SQ(SQ_ROW(from), SQ_COL(to));
            b->ff_moved &= ~BB_SQ(cap_sq); /* captured pawn gone */
        }
        if (MOVE_IS_CASTLE(m)) {
            /* Also mark rook as moved */
            if (to == SQ(0, 6))      { b->ff_moved &= ~BB_SQ(SQ(0,7)); b->ff_moved |= BB_SQ(SQ(0,5)); }
            else if (to == SQ(0, 2)) { b->ff_moved &= ~BB_SQ(SQ(0,0)); b->ff_moved |= BB_SQ(SQ(0,3)); }
            else if (to == SQ(7, 6)) { b->ff_moved &= ~BB_SQ(SQ(7,7)); b->ff_moved |= BB_SQ(SQ(7,5)); }
            else if (to == SQ(7, 2)) { b->ff_moved &= ~BB_SQ(SQ(7,0)); b->ff_moved |= BB_SQ(SQ(7,3)); }
        }
    }

    /* Update castling rights */
    if (pt == KING) {
        if (us == WHITE) b->castling &= ~(CASTLE_WK | CASTLE_WQ);
        else             b->castling &= ~(CASTLE_BK | CASTLE_BQ);
    }
    if (pt == ROOK) {
        if (from == SQ(0, 0)) b->castling &= ~CASTLE_WQ;
        if (from == SQ(0, 7)) b->castling &= ~CASTLE_WK;
        if (from == SQ(7, 0)) b->castling &= ~CASTLE_BQ;
        if (from == SQ(7, 7)) b->castling &= ~CASTLE_BK;
    }
    /* If a rook was captured on its starting square */
    if (to == SQ(0, 0)) b->castling &= ~CASTLE_WQ;
    if (to == SQ(0, 7)) b->castling &= ~CASTLE_WK;
    if (to == SQ(7, 0)) b->castling &= ~CASTLE_BQ;
    if (to == SQ(7, 7)) b->castling &= ~CASTLE_BK;

    /* En passant square */
    b->ep_square = SQ_NONE;
    if (b->mod != MOD_MERCENARY && pt == PAWN) {
        int diff = to - from;
        if (diff == 16 || diff == -16) {
            b->ep_square = SQ((SQ_ROW(from) + SQ_ROW(to)) / 2, SQ_COL(from));
        }
    }

    /* Halfmove clock */
    if (pt == PAWN || MOVE_IS_CAPTURE(m)) {
        b->halfmove = 0;
    } else {
        b->halfmove++;
    }

    /* Full move number */
    if (us == BLACK) b->fullmove++;

    /* King's Battle: detect unlock trigger (King's Kill or promotion in Phase 1) */
    if (b->mod == MOD_KINGS_BATTLE && !b->kb_unlocked) {
        /* King captures a pawn = King's Kill */
        if (pt == KING && MOVE_IS_CAPTURE(m) &&
            PIECE_TYPE(b->history[idx].captured) == PAWN) {
            b->kb_unlocked = 1;
            b->history[idx].kb_bonus = 1;
        }
        /* Pawn promotion also unlocks all pieces */
        if (MOVE_IS_PROMO(m)) {
            b->kb_unlocked = 1;
            b->history[idx].kb_bonus = 1;
        }
    }

    /* Switch side */
    b->side = b->history[idx].kb_bonus ? us : them;
    b->ply++;

    /* Recompute hash */
    b->hash = zobrist_compute(b);
}

void board_unmake_move(Board *b) {
    b->ply--;
    int idx = b->ply;
    Move m = b->history[idx].move;

    Square from = MOVE_FROM(m);
    Square to   = MOVE_TO(m);
    Color  us   = b->history[idx].kb_bonus ? b->side : color_opposite(b->side);
    PieceType pt = MOVE_PIECE(m);

    /* Switch side back */
    b->side = us;

    /* Remove piece from destination */
    board_remove(b, to);

    /* Place original piece back on source */
    board_place(b, from, us, pt);

    /* Restore captured piece */
    if (b->history[idx].captured != PIECE_EMPTY) {
        Square cap_sq = b->history[idx].captured_sq;
        Piece  cap    = b->history[idx].captured;
        board_place(b, cap_sq, PIECE_COLOR(cap), PIECE_TYPE(cap));
    }

    /* Undo castling rook move */
    if (MOVE_IS_CASTLE(m)) {
        if (to == SQ(0, 6)) {
            board_remove(b, SQ(0, 5));
            board_place(b, SQ(0, 7), WHITE, ROOK);
        } else if (to == SQ(0, 2)) {
            board_remove(b, SQ(0, 3));
            board_place(b, SQ(0, 0), WHITE, ROOK);
        } else if (to == SQ(7, 6)) {
            board_remove(b, SQ(7, 5));
            board_place(b, SQ(7, 7), BLACK, ROOK);
        } else if (to == SQ(7, 2)) {
            board_remove(b, SQ(7, 3));
            board_place(b, SQ(7, 0), BLACK, ROOK);
        }
    }

    /* Restore state */
    b->castling  = b->history[idx].castling;
    b->ep_square = b->history[idx].ep_square;
    b->halfmove  = b->history[idx].halfmove;
    b->hash      = b->history[idx].hash;
    b->heir_promoted[0] = b->history[idx].heir_promoted[0];
    b->heir_promoted[1] = b->history[idx].heir_promoted[1];
    b->truce_active = b->history[idx].truce_active;
    b->truce_frozen = b->history[idx].truce_frozen;
    b->ff_moved = b->history[idx].ff_moved;
    b->kb_unlocked = b->history[idx].kb_unlocked;

    if (us == BLACK) b->fullmove--;
}
