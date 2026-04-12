#include "eval_types.h"

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Save the Queen: Strategic evaluation                                    */
/* ═══════════════════════════════════════════════════════════════════════════ */

int eval_save_queen(const Board *b, const EvalContext *ctx) {
    int score = 0;
    (void)ctx;

        for (int c = 0; c < 2; c++) {
            Color opp = (Color)(c ^ 1);
            int bonus = 0;

            Bitboard qbb = b->pieces[c][QUEEN];
            if (qbb != BB_EMPTY) {
                Square qsq = (Square)bb_lsb(qbb);
                int qrow = SQ_ROW(qsq);
                int qcol = SQ_COL(qsq);
                bool own_half = stq_is_own_half(qsq, (Color)c);

                if (!own_half) {
                    /* ─ PRISONER: reward approaching the escape boundary ─ */
                    int dist = (c == WHITE) ? (qrow - 3) : (4 - qrow);
                    /* dist 1 = one step from freedom, 4 = starting prison */
                    static const int ESCAPE_BONUS[5] = {0, 450, 250, 120, 30};
                    if (dist >= 1 && dist <= 4) bonus += ESCAPE_BONUS[dist];

                    /* Center files offer more escape routes */
                    int center_dist = qcol > 3 ? (qcol - 3) : (3 - qcol);
                    bonus += (3 - center_dist) * 8;

                    /* Mobility: king-like quiet squares available */
                    Bitboard quiet = king_attacks[qsq] & ~b->all;
                    bonus += bb_popcount(quiet) * 12;

                    /* Clear escape path: forward squares toward boundary */
                    {
                        int fwd[3];
                        if (c == WHITE) { fwd[0] = -8; fwd[1] = -7; fwd[2] = -9; }
                        else            { fwd[0] =  8; fwd[1] =  7; fwd[2] =  9; }
                        int clear = 0;
                        for (int i = 0; i < 3; i++) {
                            int tsq = (int)qsq + fwd[i];
                            if (tsq >= 0 && tsq < 64 &&
                                abs(SQ_COL(tsq) - qcol) <= 1 &&
                                b->mailbox[tsq] == PIECE_EMPTY)
                                clear++;
                        }
                        bonus += clear * 25;
                    }
                } else {
                    /* ─ ESCAPED: reward approaching opponent's prison ─── */
                    bonus += 500;   /* base escape bonus */

                    int prison_row = (c == WHITE) ? 0 : 7;
                    int dr = qrow > prison_row ? (qrow - prison_row)
                                               : (prison_row - qrow);
                    int dc = qcol > 3 ? (qcol - 3) : (3 - qcol);
                    int dist = (dr > dc) ? dr : dc;  /* Chebyshev */

                    static const int WIN_BONUS[] =
                        {1500, 800, 350, 150, 70, 30, 10, 0};
                    if (dist < 8) bonus += WIN_BONUS[dist];

                    /* Central activity within own half */
                    bonus += (3 - dc) * 10;

                    /* Penalty when escaped queen is under attack (mild) */
                    if (board_square_attacked(b, qsq, opp))
                        bonus -= 150;

                    /* King proximity: escaped queen near opponent king */
                    {
                        Bitboard opp_king = b->pieces[opp][KING];
                        if (opp_king) {
                            Square ksq = (Square)bb_lsb(opp_king);
                            int kr = SQ_ROW(ksq), kc = SQ_COL(ksq);
                            int kdr = qrow > kr ? (qrow - kr) : (kr - qrow);
                            int kdc = qcol > kc ? (qcol - kc) : (kc - qcol);
                            int kdist = kdr > kdc ? kdr : kdc;
                            if (kdist <= 3) bonus += (4 - kdist) * 50;
                        }
                    }

                    /* Support: friendly pieces near escaped queen */
                    {
                        Bitboard support = king_attacks[qsq] & b->occupied[c];
                        bonus += bb_popcount(support) * 15;
                    }
                }
            } else {
                /* Queen completely absent — severe handicap */
                bonus -= 400;
            }

            /* Blocking opponent's prisoner from escaping */
            Bitboard opp_q = b->pieces[opp][QUEEN];
            if (opp_q != BB_EMPTY) {
                Square opp_qsq = (Square)bb_lsb(opp_q);
                if (!stq_is_own_half(opp_qsq, opp)) {
                    /* Opponent prisoner: reward having pieces near boundary */
                    int boundary = (opp == WHITE) ? 3 : 4;
                    Bitboard row_mask = (Bitboard)0xFFULL << (boundary * 8);
                    int blockers = bb_popcount(b->occupied[c] & row_mask);
                    bonus += blockers * 30;

                    /* Extra reward for pieces adjacent to the prisoner */
                    Bitboard around = king_attacks[opp_qsq] & b->occupied[c];
                    bonus += bb_popcount(around) * 22;

                    /* Urgency: opponent close to escaping */
                    int opp_dist = (opp == WHITE) ? (SQ_ROW(opp_qsq) - 3)
                                                  : (4 - SQ_ROW(opp_qsq));
                    if (opp_dist == 1) {
                        /* Critical: one step from escape! */
                        bonus += blockers * 35;
                        bonus += bb_popcount(around) * 25;
                    } else if (opp_dist == 2) {
                        bonus += blockers * 15;
                        bonus += bb_popcount(around) * 10;
                    }

                    /* Pawn blockade: pawns on boundary are permanent obstacles */
                    int pawn_blockers = bb_popcount(b->pieces[c][PAWN] & row_mask);
                    bonus += pawn_blockers * 15;
                }
            }

            score += (c == WHITE) ? bonus : -bonus;
        }

        /* Tempo bonus */
        score += (b->side == WHITE) ? 15 : -15;

    return score;
}
