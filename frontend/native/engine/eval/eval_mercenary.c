#include "eval_types.h"

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Mercenary: Piece-Square Table                                            */
/* ═══════════════════════════════════════════════════════════════════════════ */

const int PST_MERC_PAWN[64] = {
     0,  0,  0,  0,  0,  0,  0,  0,   /* rank 1: back rank, no bonus */
     5, 10, 12, 15, 15, 12, 10,  5,   /* rank 2 */
    12, 22, 35, 45, 45, 35, 22, 12,   /* rank 3 */
    18, 32, 50, 65, 65, 50, 32, 18,   /* rank 4: center is king */
    18, 32, 50, 65, 65, 50, 32, 18,   /* rank 5 */
    12, 22, 35, 45, 45, 35, 22, 12,   /* rank 6 */
     5, 10, 12, 15, 15, 12, 10,  5,   /* rank 7 */
     0,  0,  0,  0,  0,  0,  0,  0,   /* rank 8: back rank */
};


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Mercenary: Helper functions                                              */
/* ═══════════════════════════════════════════════════════════════════════════ */

static inline int merc_lane_pressure_sq(int a, int b) {
    int file_gap = abs(SQ_COL(a) - SQ_COL(b));
    int rank_gap = abs(SQ_ROW(a) - SQ_ROW(b));
    int pressure = 0;

    if (file_gap == 0) pressure += 4;
    if (rank_gap == 0) pressure += 4;
    if (file_gap == rank_gap) pressure += 3;
    if (file_gap <= 2) pressure += 2 - file_gap;
    if (rank_gap <= 2) pressure += 2 - rank_gap;

    return pressure;
}

static inline int merc_adjacent_pawn_shield(const Board *b, Color side,
                                            Square king) {
    return bb_popcount(b->pieces[side][PAWN] & king_attacks[king]);
}

static inline int merc_king_route_bonus(Square king, Square enemy_king,
                                        int eg_weight, int lead) {
    int file_gap = abs(SQ_COL(king) - SQ_COL(enemy_king));
    int file_alignment = 4 - file_gap;
    if (file_alignment < 0) file_alignment = 0;

    int lane_pressure = merc_lane_pressure_sq(king, enemy_king);

    int king_center = 6 - distance_from_center_sq(king);
    if (king_center < 0) king_center = 0;

    int pressure = lead > 0 ? lead : 0;
    if (pressure > 700) pressure = 700;

    int bonus = file_alignment * (10 + eg_weight / 6);
    bonus += king_center * (4 + eg_weight / 24);
    bonus += lane_pressure * (5 + eg_weight / 24);
    bonus += (file_alignment * pressure) / 80;
    return bonus;
}

static inline int merc_queen_infiltration_bonus(const Board *b, Color side,
                                                Square queen, Square enemy_king,
                                                int eg_weight, int lead) {
    (void)side;

    int queen_dist = chebyshev_distance_sq(queen, enemy_king);
    int queen_approach = 7 - queen_dist;
    if (queen_approach < 0) queen_approach = 0;

    int lane_pressure = merc_lane_pressure_sq(queen, enemy_king);

    Bitboard attack_ring = king_attacks[enemy_king] | BB_SQ(enemy_king);
    Bitboard q_attacks = bishop_attacks_calc(queen, b->all)
                       | rook_attacks_calc(queen, b->all);
    int ring_hits = bb_popcount(q_attacks & attack_ring);

    int pressure = lead > 0 ? lead : 0;
    if (pressure > 700) pressure = 700;

    int bonus = queen_approach * (8 + eg_weight / 16);
    bonus += lane_pressure * (10 + eg_weight / 24);
    bonus += ring_hits * (16 + eg_weight / 32);
    bonus += (queen_approach * pressure) / 60;
    return bonus;
}

static inline int merc_king_queen_coordination_bonus(Square king, Square queen,
                                                     Square enemy_king,
                                                     int eg_weight, int lead) {
    int king_to_queen = chebyshev_distance_sq(king, queen);
    int king_to_enemy = chebyshev_distance_sq(king, enemy_king);
    int queen_to_enemy = chebyshev_distance_sq(queen, enemy_king);
    int escort = 0;
    int pressure = lead > 0 ? lead : 0;
    if (pressure > 700) pressure = 700;

    if (king_to_queen <= 4) {
        escort += (5 - king_to_queen) * (6 + eg_weight / 32);
    }

    if (king_to_enemy <= 4 && queen_to_enemy <= 4) {
        escort += (9 - king_to_enemy - queen_to_enemy) * (6 + eg_weight / 28);
    }

    if (king_to_queen <= 4 || king_to_enemy <= 4) {
        escort += merc_lane_pressure_sq(queen, enemy_king) * (4 + eg_weight / 32);
    }

    if (pressure > 0 && escort > 0) {
        escort += (escort * pressure) / 320;
    }

    return escort;
}

static inline int merc_enemy_queen_infiltration_penalty(const Board *b,
                                                        Square king,
                                                        Square enemy_queen,
                                                        int eg_weight,
                                                        int shield) {
    int queen_dist = chebyshev_distance_sq(enemy_queen, king);
    int queen_approach = 7 - queen_dist;
    if (queen_approach < 0) queen_approach = 0;

    int lane_pressure = merc_lane_pressure_sq(enemy_queen, king);
    Bitboard attack_ring = king_attacks[king] | BB_SQ(king);
    Bitboard q_attacks = bishop_attacks_calc(enemy_queen, b->all)
                       | rook_attacks_calc(enemy_queen, b->all);
    int ring_hits = bb_popcount(q_attacks & attack_ring);

    int shelter_crack = 3 - shield;
    if (shelter_crack < 0) shelter_crack = 0;

    int penalty = queen_approach * (8 + eg_weight / 20);
    penalty += lane_pressure * (10 + eg_weight / 24);
    penalty += ring_hits * (18 + eg_weight / 24);
    penalty += shelter_crack * (12 + eg_weight / 20);
    return penalty;
}


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Mercenary: Strategic evaluation                                          */
/* ═══════════════════════════════════════════════════════════════════════════ */

int eval_mercenary(const Board *b, const EvalContext *ctx) {
    int score = 0;
    int pawn_count[2];
    pawn_count[0] = ctx->pawn_count[0];
    pawn_count[1] = ctx->pawn_count[1];
    int material[2];
    material[0] = ctx->material[0];
    material[1] = ctx->material[1];
    int non_pawn_material[2];
    non_pawn_material[0] = ctx->non_pawn_material[0];
    non_pawn_material[1] = ctx->non_pawn_material[1];
    int king_sq[2];
    king_sq[0] = ctx->king_sq[0];
    king_sq[1] = ctx->king_sq[1];
    int queen_sq[2];
    queen_sq[0] = ctx->queen_sq[0];
    queen_sq[1] = ctx->queen_sq[1];
    int eg_weight = ctx->eg_weight;

          /* Extra incentive to keep pawns */
          score += (pawn_count[WHITE] - pawn_count[BLACK]) * 25;

        /* Pawn proximity to enemy king — scaled by game phase.
           Midgame: modest bonus.  Late-game: stronger (king-hunt). */
        for (int c = 0; c < 2; c++) {
            Bitboard kbb = b->pieces[c ^ 1][KING];
            if (!kbb) continue;
            Square ksq = bb_lsb(kbb);
            int kr = SQ_ROW(ksq), kc = SQ_COL(ksq);
            Bitboard pawns = b->pieces[c][PAWN];
            int prox = 0;
            while (pawns) {
                Square sq = (Square)bb_pop_lsb(&pawns);
                int dr = abs(SQ_ROW(sq) - kr);
                int dc = abs(SQ_COL(sq) - kc);
                int dist = dr > dc ? dr : dc; /* Chebyshev distance */
                if (dist <= 3) {
                    /* Base proximity + phase-scaled bonus */
                    static const int PROX_MG[] = {0, 10, 5, 2};
                    static const int PROX_EG[] = {0, 16, 8, 3};
                    prox += PROX_MG[dist] + (PROX_EG[dist] * eg_weight) / 128;
                }
            }
            score += (c == WHITE) ? prox : -prox;
        }

        /* Mercenary pawn connectivity: pawns adjacent to friendly pawns
           form stronger clusters.  Isolated pawns are vulnerable. */
        for (int c = 0; c < 2; c++) {
            Bitboard pawns = b->pieces[c][PAWN];
            Bitboard tmp = pawns;
            int connected = 0;
            int isolated = 0;
            while (tmp) {
                Square sq = (Square)bb_pop_lsb(&tmp);
                Bitboard neighbors = king_attacks[sq] & pawns;
                if (neighbors) {
                    connected += bb_popcount(neighbors);
                } else {
                    isolated++;
                }
            }
            int bonus = connected * 6 - isolated * 12;
            score += (c == WHITE) ? bonus : -bonus;
        }

        /* Space advantage: pawns in opponent's half of the board.
           Reduced weight: no promotion in Mercenary, so space is
           useful mainly for king-attack staging, not pawn queening. */
        {
            int w_space = 0, b_space = 0;
            Bitboard wp = b->pieces[WHITE][PAWN];
            while (wp) {
                Square sq = (Square)bb_pop_lsb(&wp);
                int row = SQ_ROW(sq);
                if (row >= 4) w_space++;
            }
            Bitboard bp = b->pieces[BLACK][PAWN];
            while (bp) {
                Square sq = (Square)bb_pop_lsb(&bp);
                int row = SQ_ROW(sq);
                if (row <= 3) b_space++;
            }
            score += (w_space - b_space) * 10;
        }

        /* Piece development: minor pieces off back rank. */
        for (int c = 0; c < 2; c++) {
            int back_rank = (c == WHITE) ? 0 : 7;
            Bitboard minors = b->pieces[c][KNIGHT] | b->pieces[c][BISHOP];
            int developed = 0;
            while (minors) {
                Square sq = (Square)bb_pop_lsb(&minors);
                if (SQ_ROW(sq) != back_rank) developed++;
            }
            score += (c == WHITE) ? developed * 8 : -(developed * 8);
        }

        /* Midgame king safety: pawn shield around own king.
           Applies at any phase; scaled by mg_weight. */
        if (ctx->mg_weight > 0) {
            for (int c = 0; c < 2; c++) {
                if (king_sq[c] < 0) continue;
                int shield = bb_popcount(
                    king_attacks[king_sq[c]] & b->pieces[c][PAWN]);
                /* 0-3 pawns adjacent to king → bonus up to ~18 */
                int safety = shield * (6 + ctx->mg_weight / 24);
                score += (c == WHITE) ? safety : -safety;
            }
        }

        if (eg_weight >= 48) {
            for (int c = 0; c < 2; c++) {
                int opp = c ^ 1;
                if (king_sq[c] < 0 || king_sq[opp] < 0) continue;

                int lead = material[c] - material[opp];
                int bonus = merc_king_route_bonus(king_sq[c], king_sq[opp],
                                                  eg_weight, lead);

                if (queen_sq[c] >= 0) {
                    bonus += merc_queen_infiltration_bonus(
                        b, (Color)c, queen_sq[c], king_sq[opp], eg_weight, lead);
                    bonus += merc_king_queen_coordination_bonus(
                        king_sq[c], queen_sq[c], king_sq[opp], eg_weight, lead);
                }

                if (queen_sq[opp] >= 0) {
                    int shield = merc_adjacent_pawn_shield(
                        b, (Color)c, king_sq[c]);
                    bonus -= merc_enemy_queen_infiltration_penalty(
                        b, king_sq[c], queen_sq[opp], eg_weight, shield);
                }

                if (lead > 0) {
                    if (lead > 700) lead = 700;

                    int simplify_budget = 2400 - non_pawn_material[opp];
                    if (simplify_budget < 0) simplify_budget = 0;

                    int cleanup_window = 1600 - non_pawn_material[opp];
                    if (cleanup_window < 0) cleanup_window = 0;

                    int king_dist = chebyshev_distance_sq(king_sq[c], king_sq[opp]);
                    int edge_dist = distance_from_center_sq(king_sq[opp]);

                    int simplify = (simplify_budget * lead * eg_weight) / 1310720;
                    int cleanup = (cleanup_window * lead * eg_weight) / 983040;
                    int king_approach = ((8 - king_dist) * lead * eg_weight) / 30720;
                    int king_drive = (edge_dist * lead * eg_weight) / 51200;
                    bonus += simplify + cleanup + king_approach + king_drive;
                }

                score += (c == WHITE) ? bonus : -bonus;
            }
        }

    /* Tempo bonus */
    score += (b->side == WHITE) ? 15 : -15;

    return score;
}
