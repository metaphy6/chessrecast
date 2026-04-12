#include "eval_types.h"

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Succession: Strategic evaluation                                        */
/* ═══════════════════════════════════════════════════════════════════════════ */

int eval_succession(const Board *b, const EvalContext *ctx) {
    int score = 0;
    (void)ctx;

        for (int c = 0; c < 2; c++) {
            Color opp = (Color)(c ^ 1);
            int bonus = 0;

            /* ── Queen safety: each queen is critical (2 must survive) ── */
            int qcount = bb_popcount(b->pieces[c][QUEEN]);
            /* Reward having both queens */
            bonus += qcount * 250;
            /* Extra penalty for a queen being attacked */
            Bitboard qq = b->pieces[c][QUEEN];
            while (qq) {
                Square qsq = (Square)bb_pop_lsb(&qq);
                if (board_square_attacked(b, qsq, opp))
                    bonus -= 120;
                /* Queens centralized get a mobility bonus */
                int qr = SQ_ROW(qsq), qc_col = SQ_COL(qsq);
                int cr = qr > 3 ? (qr - 3) : (3 - qr);
                int cc = qc_col > 3 ? (qc_col - 3) : (3 - qc_col);
                bonus += (6 - cr - cc) * 4;
            }

            /* ── Pawn advancement: the key strategic goal ─────────────── */
            int pawn_count = bb_popcount(b->pieces[c][PAWN]);
            Bitboard pawns = b->pieces[c][PAWN];
            int promo_row = (c == WHITE) ? 7 : 0;
            int start_row = (c == WHITE) ? 1 : 6;
            int dir_mul = (c == WHITE) ? 1 : -1;
            int best_advance = 0;

            while (pawns) {
                Square psq = (Square)bb_pop_lsb(&pawns);
                int pr = SQ_ROW(psq);
                int advance = (pr - start_row) * dir_mul;
                if (advance > best_advance) best_advance = advance;

                /* Per-pawn advancement reward (escalating) */
                static const int ADV_BONUS[] = {0, 5, 12, 25, 55, 120, 300};
                if (advance >= 0 && advance <= 6) bonus += ADV_BONUS[advance];

                /* Passed pawn detection: no enemy pawns on same or adjacent files ahead */
                {
                    int pc = SQ_COL(psq);
                    bool passed = true;
                    for (int fc = pc - 1; fc <= pc + 1; fc++) {
                        if (fc < 0 || fc > 7) continue;
                        Bitboard file = (Bitboard)0x0101010101010101ULL << fc;
                        Bitboard opp_pawns = b->pieces[opp][PAWN] & file;
                        /* Check only rows ahead */
                        while (opp_pawns) {
                            Square ops = (Square)bb_pop_lsb(&opp_pawns);
                            int opr = SQ_ROW(ops);
                            if (c == WHITE ? (opr > pr) : (opr < pr)) {
                                passed = false;
                                break;
                            }
                        }
                        if (!passed) break;
                    }
                    if (passed) {
                        /* Passed pawn: escalating bonus */
                        static const int PASS_BONUS[] = {0, 10, 20, 40, 80, 160, 400};
                        if (advance >= 0 && advance <= 6)
                            bonus += PASS_BONUS[advance];
                    }
                }
            }

            /* ── Pawn count: losing pawns is dangerous ────────────────── */
            bonus += pawn_count * 15;
            /* Last-pawn vulnerability: if only 1 pawn left, huge urgency */
            if (pawn_count == 1) bonus -= 80;

            /* ── Have a King already? Massive bonus (opponent must capture it to win) */
            if (b->heir_promoted[c]) {
                bonus += 900;
                /* King safety: bonus if supported, penalty if attacked */
                Bitboard kbb = b->pieces[c][KING];
                if (kbb) {
                    Square ksq = (Square)bb_lsb(kbb);
                    if (board_square_attacked(b, ksq, opp))
                        bonus -= 300;
                    /* Friendly pieces nearby protect the king */
                    Bitboard support = king_attacks[ksq] & b->occupied[c];
                    bonus += bb_popcount(support) * 20;
                }
            }

            /* ── Opponent's pawn advancement threat ───────────────── */
            {
                Bitboard op = b->pieces[opp][PAWN];
                int opp_start = (opp == WHITE) ? 1 : 6;
                int opp_dir = (opp == WHITE) ? 1 : -1;
                int opp_best = 0;
                while (op) {
                    Square ops = (Square)bb_pop_lsb(&op);
                    int adv = (SQ_ROW(ops) - opp_start) * opp_dir;
                    if (adv > opp_best) opp_best = adv;
                }
                /* Penalty when opponent has advanced pawns threatening promotion */
                if (opp_best >= 5) bonus -= 100;
                else if (opp_best >= 4) bonus -= 40;
            }

            /* ── Piece activity: minor pieces support pawn advance ──── */
            {
                Bitboard knights = b->pieces[c][KNIGHT];
                Bitboard bishops = b->pieces[c][BISHOP];
                /* Knights on advanced squares (rows 4-6 for White, 1-3 for Black) */
                while (knights) {
                    Square ns = (Square)bb_pop_lsb(&knights);
                    int nr = SQ_ROW(ns);
                    int n_adv = (nr - start_row) * dir_mul;
                    if (n_adv >= 3) bonus += 10;
                }
                /* Bishop pair */
                if (bb_popcount(bishops) >= 2) bonus += 25;
            }

            score += (c == WHITE) ? bonus : -bonus;
        }

        /* Tempo */
        score += (b->side == WHITE) ? 12 : -12;

    return score;
}
