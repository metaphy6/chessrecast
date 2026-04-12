#include "board_internal.h"
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <ctype.h>

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
