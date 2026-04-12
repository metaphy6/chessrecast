#include "eval_types.h"

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Friendly Fire: Strategic evaluation                                      */
/* ═══════════════════════════════════════════════════════════════════════════ */

int eval_friendly_fire(const Board *b, const EvalContext *ctx) {
    int score = 0;
    Bitboard pawn_atk[2];
    pawn_atk[0] = ctx->pawn_atk[0];
    pawn_atk[1] = ctx->pawn_atk[1];

        for (int c = 0; c < 2; c++) {
            int opp = c ^ 1;
            int bonus = 0;

            /* ─ Piece count preservation: losing pieces to self-capture
               means fewer attackers/defenders overall ──────────────── */
            int piece_count = 0;
            for (int t = KNIGHT; t <= QUEEN; t++)
                piece_count += bb_popcount(b->pieces[c][t]);
            bonus += piece_count * 8;

            /* ─ Piece cohesion: defended pieces are safer since they can't
               be cheaply removed by discovered attacks.  Pieces that
               defend each other form resilient structures. ──────────── */
            Bitboard own_def = pawn_atk[c];
            {
                Bitboard kn = b->pieces[c][KNIGHT];
                while (kn) {
                    Square s = (Square)bb_pop_lsb(&kn);
                    own_def |= knight_attacks[s];
                }
                Bitboard bi = b->pieces[c][BISHOP] | b->pieces[c][QUEEN];
                while (bi) {
                    Square s = (Square)bb_pop_lsb(&bi);
                    own_def |= bishop_attacks_calc(s, b->all);
                }
                Bitboard ro = b->pieces[c][ROOK] | b->pieces[c][QUEEN];
                while (ro) {
                    Square s = (Square)bb_pop_lsb(&ro);
                    own_def |= rook_attacks_calc(s, b->all);
                }
            }

            /* Bonus for defended non-pawn pieces */
            for (int t = KNIGHT; t <= QUEEN; t++) {
                Bitboard bb = b->pieces[c][t];
                while (bb) {
                    Square sq = (Square)bb_pop_lsb(&bb);
                    if (BB_HAS(own_def, sq)) bonus += 6;
                }
            }

            /* Pieces that sit on attacked squares are less reliable in FF,
               especially advanced minor pieces that just grabbed material. */
            {
                static const int FF_VULN_PENALTY[6] = {
                    0, 48, 46, 64, 96, 0
                };
                static const int FF_VULN_DEFENDED[6] = {
                    0, 18, 18, 26, 42, 0
                };

                for (int t = KNIGHT; t <= QUEEN; t++) {
                    Bitboard bb = b->pieces[c][t];
                    while (bb) {
                        Square sq = (Square)bb_pop_lsb(&bb);
                        bool attacked = board_square_attacked(b, sq, (Color)opp);
                        bool defended = BB_HAS(own_def, sq);
                        bool pawn_attacked = BB_HAS(pawn_atk[opp], sq);
                        int pen;

                        if (!attacked) continue;

                        pen = defended ? FF_VULN_DEFENDED[t] : FF_VULN_PENALTY[t];
                        if (pawn_attacked && t <= BISHOP) pen += 18;

                        if (t <= BISHOP) {
                            int advance = (c == WHITE) ? SQ_ROW(sq) : (7 - SQ_ROW(sq));
                            bool central = SQ_COL(sq) >= 2 && SQ_COL(sq) <= 5;

                            if (!defended && advance >= 3) pen += 10 + (advance - 3) * 10;
                            if (central && advance >= 3) pen += 8;
                        }

                        bonus -= pen;
                    }
                }
            }

            /* ─ Open line potential: pieces that could open lines by
               self-capturing blockers get a small positional bonus.
               Rooks/queens on files with own pawns that have moved: the
               pawn could be self-captured to open the file. ─────────── */
            {
                Bitboard rq = b->pieces[c][ROOK] | b->pieces[c][QUEEN];
                while (rq) {
                    Square sq = (Square)bb_pop_lsb(&rq);
                    Bitboard file = (Bitboard)0x0101010101010101ULL << SQ_COL(sq);
                    /* Own pawns on this file that have moved = potential openers */
                    Bitboard blockers = b->pieces[c][PAWN] & file & b->ff_moved;
                    if (blockers) bonus += 5;
                }
            }

            /* ─ King safety emphasis: in FF the king is more vulnerable
               because enemy pieces can also remove defenders via self-capture
               tactics.  Amplify pawn shield value. ──────────────────── */
            {
                Bitboard kbb = b->pieces[c][KING];
                if (kbb) {
                    Square ksq = bb_lsb(kbb);
                    int kc = SQ_COL(ksq);
                    int fwd = (c == WHITE) ? 1 : -1;
                    int shield = 0;
                    for (int dc = -1; dc <= 1; dc++) {
                        int nc = kc + dc, nr = SQ_ROW(ksq) + fwd;
                        if (nc < 0 || nc > 7 || nr < 0 || nr > 7) continue;
                        if (BB_HAS(b->pieces[c][PAWN], SQ(nr, nc))) shield++;
                    }
                    bonus += shield * 8;
                    /* Penalty for king in center */
                    if (kc >= 3 && kc <= 4) bonus -= 10;
                }
            }

            score += (c == WHITE) ? bonus : -bonus;
        }

        /* Tempo bonus */
        score += (b->side == WHITE) ? 10 : -10;

    return score;
}
