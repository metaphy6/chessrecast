#include "eval_types.h"

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Material values (centipawns)                                             */
/* ═══════════════════════════════════════════════════════════════════════════ */

const int MATERIAL[6] = {
    100,   /* PAWN   */
    320,   /* KNIGHT */
    330,   /* BISHOP */
    500,   /* ROOK   */
    900,   /* QUEEN  */
    0      /* KING   */
};


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Piece-Square Tables (from white's perspective, row 0 = rank 1)           */
/* ═══════════════════════════════════════════════════════════════════════════ */

const int PST_PAWN[64] = {
     0,  0,  0,  0,  0,  0,  0,  0,
     5, 10, 10,-20,-20, 10, 10,  5,
     5, -5,-10,  0,  0,-10, -5,  5,
     0,  0,  0, 20, 20,  0,  0,  0,
     5,  5, 10, 25, 25, 10,  5,  5,
    10, 10, 20, 30, 30, 20, 10, 10,
    50, 50, 50, 50, 50, 50, 50, 50,
     0,  0,  0,  0,  0,  0,  0,  0,
};

const int PST_KNIGHT[64] = {
    -50,-40,-30,-30,-30,-30,-40,-50,
    -40,-20,  0,  5,  5,  0,-20,-40,
    -30,  5, 10, 15, 15, 10,  5,-30,
    -30,  0, 15, 20, 20, 15,  0,-30,
    -30,  5, 15, 20, 20, 15,  5,-30,
    -30,  0, 10, 15, 15, 10,  0,-30,
    -40,-20,  0,  0,  0,  0,-20,-40,
    -50,-40,-30,-30,-30,-30,-40,-50,
};

const int PST_BISHOP[64] = {
    -20,-10,-10,-10,-10,-10,-10,-20,
    -10,  5,  0,  0,  0,  0,  5,-10,
    -10, 10, 10, 10, 10, 10, 10,-10,
    -10,  0, 10, 10, 10, 10,  0,-10,
    -10,  5,  5, 10, 10,  5,  5,-10,
    -10,  0,  5, 10, 10,  5,  0,-10,
    -10,  0,  0,  0,  0,  0,  0,-10,
    -20,-10,-10,-10,-10,-10,-10,-20,
};

const int PST_ROOK[64] = {
      0,  0,  0,  5,  5,  0,  0,  0,
     -5,  0,  0,  0,  0,  0,  0, -5,
     -5,  0,  0,  0,  0,  0,  0, -5,
     -5,  0,  0,  0,  0,  0,  0, -5,
     -5,  0,  0,  0,  0,  0,  0, -5,
     -5,  0,  0,  0,  0,  0,  0, -5,
      5, 10, 10, 10, 10, 10, 10,  5,
      0,  0,  0,  0,  0,  0,  0,  0,
};

const int PST_QUEEN[64] = {
    -20,-10,-10, -5, -5,-10,-10,-20,
    -10,  0,  5,  0,  0,  0,  0,-10,
    -10,  5,  5,  5,  5,  5,  0,-10,
      0,  0,  5,  5,  5,  5,  0, -5,
     -5,  0,  5,  5,  5,  5,  0, -5,
    -10,  0,  5,  5,  5,  5,  0,-10,
    -10,  0,  0,  0,  0,  0,  0,-10,
    -20,-10,-10, -5, -5,-10,-10,-20,
};

const int PST_KING_MG[64] = {
     20, 30, 10,  0,  0, 10, 30, 20,
     20, 20,  0,  0,  0,  0, 20, 20,
    -10,-20,-20,-20,-20,-20,-20,-10,
    -20,-30,-30,-40,-40,-30,-30,-20,
    -30,-40,-40,-50,-50,-40,-40,-30,
    -30,-40,-40,-50,-50,-40,-40,-30,
    -30,-40,-40,-50,-50,-40,-40,-30,
    -30,-40,-40,-50,-50,-40,-40,-30,
};

const int PST_KING_EG[64] = {
    -50,-30,-30,-30,-30,-30,-30,-50,
    -30,-30,  0,  0,  0,  0,-30,-30,
    -30,-10, 20, 30, 30, 20,-10,-30,
    -30,-10, 30, 40, 40, 30,-10,-30,
    -30,-10, 30, 40, 40, 30,-10,-30,
    -30,-10, 20, 30, 30, 20,-10,-30,
    -30,-20,-10,  0,  0,-10,-20,-30,
    -50,-40,-30,-20,-20,-30,-40,-50,
};


const int *PST_TABLE[6] = {
    PST_PAWN, PST_KNIGHT, PST_BISHOP, PST_ROOK, PST_QUEEN, PST_KING_MG
};


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Common evaluation init: material, PST, mobility, phase, bishop pair       */
/* ═══════════════════════════════════════════════════════════════════════════ */

void eval_common_init(const Board *b, EvalContext *ctx) {
    int mg_score[2] = {0, 0};
    int eg_score[2] = {0, 0};
    int material[2] = {0, 0};
    int non_pawn_material[2] = {0, 0};
    int pawn_count[2] = {0, 0};
    int bishop_count[2] = {0, 0};
    int king_sq[2] = {-1, -1};
    int queen_sq[2] = {-1, -1};

    bool is_merc = (b->mod == MOD_MERCENARY);
    bool is_heir = (b->mod == MOD_HEIR);
    bool is_truce_active = (b->mod == MOD_TRUCE && b->truce_active);

    /* Pre-compute pawn attack bitboards (Stockfish: used for safe mobility
       and threat evaluation — pieces on pawn-attacked squares are vulnerable) */
    Bitboard pawn_atk[2] = {BB_EMPTY, BB_EMPTY};
    if (is_merc) {
        for (int c = 0; c < 2; c++) {
            Bitboard p = b->pieces[c][PAWN];
            while (p) {
                Square s = (Square)bb_pop_lsb(&p);
                pawn_atk[c] |= king_attacks[s];
            }
        }
    } else {
        /* Standard diagonal pawn attacks (for classic and heir) */
        Bitboard wp = b->pieces[WHITE][PAWN];
        pawn_atk[WHITE] = ((wp & ~((Bitboard)0x0101010101010101ULL)) << 7) |
                           ((wp & ~((Bitboard)0x8080808080808080ULL)) << 9);
        Bitboard bp = b->pieces[BLACK][PAWN];
        pawn_atk[BLACK] = ((bp & ~((Bitboard)0x8080808080808080ULL)) >> 7) |
                           ((bp & ~((Bitboard)0x0101010101010101ULL)) >> 9);
    }

    /* ── 1. Material, PST, Mobility ──────────────────────────────────────── */

    for (int c = 0; c < 2; c++) {
        for (int t = 0; t < 6; t++) {
            Bitboard bb = b->pieces[c][t];
            while (bb) {
                Square sq = (Square)bb_pop_lsb(&bb);
                int idx = (c == WHITE) ? sq : mirror(sq);

                int mat = MATERIAL[t];
                /* Mercenary pawns move like kings — worth more */
                if (t == PAWN && is_merc) mat = 180;
                /* Heir: pawns are king replacements — worth more */
                if (t == PAWN && is_heir) mat = 140;
                /* Heir: expendable king (check rules don't apply) has material value */
                if (t == KING && is_heir) {
                    if (!heir_check_applies(b, (Color)c))
                        mat = 250; /* expendable: valuable but sacrificeable */
                    else
                        mat = 0;   /* critical: infinite value (via checkmate) */
                }
                /* Save the Queen: prisoner queen limited; escaped queen critical */
                if (t == QUEEN && b->mod == MOD_SAVE_QUEEN) {
                    mat = stq_is_own_half(sq, (Color)c) ? 1100 : 150;
                }
                /* Succession: queens are invaluable (losing one = may lose game) */
                if (b->mod == MOD_SUCCESSION) {
                    if (t == QUEEN) mat = 1300;
                    if (t == PAWN) mat =  160;  /* pawns are path to King promotion */
                    if (t == KING) mat =  700;  /* promoted King: big but not infinite */
                }
                material[c] += mat;
                if (t != PAWN && t != KING) non_pawn_material[c] += mat;
                mg_score[c] += mat;
                eg_score[c] += mat;
                if (t == KING) king_sq[c] = sq;
                if (t == QUEEN) queen_sq[c] = sq;

                if (t == PAWN && is_merc) {
                    /* Mercenary pawns use their own PST for positional play */
                    mg_score[c] += PST_MERC_PAWN[idx];
                    eg_score[c] += PST_MERC_PAWN[idx];

                    /* Quadratic advancement bonus: makes retreating very costly.
                       rank 1=3, 2=12, 3=27, 4=48, 5=75, 6=108 */
                    int rank = (c == WHITE) ? SQ_ROW(sq) : (7 - SQ_ROW(sq));
                    if (rank >= 1 && rank <= 6) {
                        int adv = rank * rank * 3;
                        mg_score[c] += adv;
                        eg_score[c] += adv * 2;
                    }
                } else if (t == PAWN && is_heir) {
                    /* Heir pawns: advancement PST + promotion-potential bonus */
                    mg_score[c] += PST_HEIR_PAWN[idx];
                    eg_score[c] += PST_HEIR_PAWN[idx];

                    /* Advancement bonus scaled quadratically: closer to promo = bigger */
                    int rank = (c == WHITE) ? SQ_ROW(sq) : (7 - SQ_ROW(sq));
                    if (rank >= 3) {
                        int adv = (rank - 2) * (rank - 2) * 8;
                        mg_score[c] += adv;
                        eg_score[c] += adv * 2;
                    }
                } else if (t == PAWN && is_truce_active) {
                    /* Truce pawns: center control + space for post-truce */
                    mg_score[c] += PST_TRUCE_PAWN[idx];
                    eg_score[c] += PST_TRUCE_PAWN[idx];
                } else if (t == KNIGHT && is_truce_active) {
                    /* Truce knights: outpost-focused PST */
                    mg_score[c] += PST_TRUCE_KNIGHT[idx];
                    eg_score[c] += PST_TRUCE_KNIGHT[idx];
                } else if (t == BISHOP && is_truce_active) {
                    /* Truce bishops: diagonal control emphasis */
                    mg_score[c] += PST_TRUCE_BISHOP[idx];
                    eg_score[c] += PST_TRUCE_BISHOP[idx];
                } else if (t == PAWN && b->mod == MOD_KINGS_BATTLE && !b->kb_unlocked) {
                    /* KB Phase 1 pawns: advancement toward promotion */
                    mg_score[c] += PST_KB_PAWN_P1[idx];
                    eg_score[c] += PST_KB_PAWN_P1[idx];
                    /* Extra quadratic advancement bonus: promotion is the key */
                    int rank = (c == WHITE) ? SQ_ROW(sq) : (7 - SQ_ROW(sq));
                    if (rank >= 3) {
                        int adv = (rank - 2) * (rank - 2) * 10;
                        mg_score[c] += adv;
                        eg_score[c] += adv * 2;
                    }
                } else if (t == KING && b->mod == MOD_KINGS_BATTLE && !b->kb_unlocked) {
                    /* KB Phase 1 king: active centralized king */
                    mg_score[c] += PST_KB_KING_P1[idx];
                    eg_score[c] += PST_KB_KING_P1[idx];
                } else if (t == KING) {
                    mg_score[c] += PST_KING_MG[idx];
                    eg_score[c] += PST_KING_EG[idx];
                } else {
                    mg_score[c] += PST_TABLE[t][idx];
                    eg_score[c] += PST_TABLE[t][idx];
                }

                if (t == PAWN)   pawn_count[c]++;
                if (t == BISHOP) bishop_count[c]++;

                /* Mobility: count safe squares not blocked by own pieces.
                   Stockfish-inspired: exclude enemy pawn attacks for minor
                   pieces (knights/bishops/merc pawns) — vulnerable there.
                   Rooks/queens keep full mobility (they outrange pawns).
                   Truce: mobility is more valuable since pieces can't be
                   traded — a well-placed piece stays strong longer. */
                Bitboard own_occ = b->occupied[c];
                /* Friendly Fire: own capturable pieces don't block mobility */
                if (b->mod == MOD_FRIENDLY_FIRE) {
                    Bitboard ff_cap = own_occ & b->ff_moved & ~b->pieces[c][KING];
                    own_occ &= ~ff_cap;
                }
                Bitboard safe_sq = ~own_occ & ~pawn_atk[c ^ 1];
                /* Truce mobility multiplier: pieces that control more squares
                   exert more pressure once the truce breaks */
                int truce_mob_extra = is_truce_active ? 2 : 0;
                if (t == PAWN && is_merc) {
                    int mob = bb_popcount(king_attacks[sq] & safe_sq);
                    mg_score[c] += mob * 5;
                    eg_score[c] += mob * 5;
                } else if (t == KNIGHT) {
                    int mob = bb_popcount(knight_attacks[sq] & safe_sq);
                    mg_score[c] += mob * (4 + truce_mob_extra);
                    eg_score[c] += mob * (4 + truce_mob_extra);
                } else if (t == BISHOP) {
                    int mob = bb_popcount(bishop_attacks_calc(sq, b->all) & safe_sq);
                    mg_score[c] += mob * (5 + truce_mob_extra);
                    eg_score[c] += mob * (5 + truce_mob_extra);
                } else if (t == ROOK) {
                    Bitboard rook_targets = rook_attacks_calc(sq, b->all) & ~own_occ;
                    if (is_merc) rook_targets &= ~pawn_atk[c ^ 1];
                    int mob = bb_popcount(rook_targets);
                    mg_score[c] += mob * (2 + truce_mob_extra);
                    eg_score[c] += mob * (3 + truce_mob_extra);
                } else if (t == QUEEN) {
                    Bitboard q_atk = bishop_attacks_calc(sq, b->all)
                                   | rook_attacks_calc(sq, b->all);
                    Bitboard queen_targets = q_atk & ~own_occ;
                    if (is_merc) queen_targets &= ~pawn_atk[c ^ 1];
                    int mob = bb_popcount(queen_targets);
                    mg_score[c] += mob * (1 + (is_truce_active ? 1 : 0));
                    eg_score[c] += mob * (2 + (is_truce_active ? 1 : 0));
                }
            }
        }
    }

    /* ── Game phase (0 = endgame, 256 = opening) ─────────────────────────── */
    int total_mat = material[WHITE] + material[BLACK];
    int phase = (total_mat * 256) / 8000;
    if (phase > 256) phase = 256;
    int mg_weight = phase;
    int eg_weight = 256 - phase;

    /* ── Interpolated score ──────────────────────────────────────────────── */
    int mg = mg_score[WHITE] - mg_score[BLACK];
    int eg = eg_score[WHITE] - eg_score[BLACK];
    int score = (mg * mg_weight + eg * eg_weight) / 256;

    /* ── 2. Bishop pair ──────────────────────────────────────────────────── */
    if (bishop_count[WHITE] >= 2) score += 30;
    if (bishop_count[BLACK] >= 2) score -= 30;


    /* Copy computed state to context */
    ctx->score = score;
    ctx->phase = phase;
    ctx->mg_weight = mg_weight;
    ctx->eg_weight = eg_weight;
    for (int c = 0; c < 2; c++) {
        ctx->material[c] = material[c];
        ctx->non_pawn_material[c] = non_pawn_material[c];
        ctx->pawn_count[c] = pawn_count[c];
        ctx->bishop_count[c] = bishop_count[c];
        ctx->king_sq[c] = king_sq[c];
        ctx->queen_sq[c] = queen_sq[c];
        ctx->pawn_atk[c] = pawn_atk[c];
    }
}

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Common evaluation finish: pawn structure, king safety, threats, tempo      */
/* ═══════════════════════════════════════════════════════════════════════════ */

int eval_common_finish(const Board *b, const EvalContext *ctx) {
    int score = 0;
    bool is_merc = (b->mod == MOD_MERCENARY);
    bool is_heir = (b->mod == MOD_HEIR);
    bool is_truce_active = (b->mod == MOD_TRUCE && b->truce_active);
    int mg_weight = ctx->mg_weight;
    int eg_weight = ctx->eg_weight;
    Bitboard pawn_atk[2];
    pawn_atk[0] = ctx->pawn_atk[0];
    pawn_atk[1] = ctx->pawn_atk[1];
    int bishop_count[2];
    bishop_count[0] = ctx->bishop_count[0];
    bishop_count[1] = ctx->bishop_count[1];
    int king_sq[2];
    king_sq[0] = ctx->king_sq[0];
    king_sq[1] = ctx->king_sq[1];
    (void)bishop_count; (void)king_sq;

    /* ── 3. Pawn structure (doubled, isolated) — skip for Mercenary ──── */
    if (!is_merc) {
        /* During truce, pawn structure defects can't be fixed (no captures),
           so penalties are amplified */
        int doubled_pen = is_truce_active ? 22 : 15;
        int isolated_pen = is_truce_active ? 18 : 12;
        for (int col = 0; col < 8; col++) {
            Bitboard file_mask = (Bitboard)0x0101010101010101ULL << col;
            int wp = bb_popcount(b->pieces[WHITE][PAWN] & file_mask);
            int bp = bb_popcount(b->pieces[BLACK][PAWN] & file_mask);

            if (wp > 1) score -= (wp - 1) * doubled_pen;
            if (bp > 1) score += (bp - 1) * doubled_pen;

            /* Isolated: no own pawns on adjacent files */
            Bitboard adj = BB_EMPTY;
            if (col > 0) adj |= (Bitboard)0x0101010101010101ULL << (col - 1);
            if (col < 7) adj |= (Bitboard)0x0101010101010101ULL << (col + 1);
            if (wp > 0 && !(b->pieces[WHITE][PAWN] & adj)) score -= isolated_pen;
            if (bp > 0 && !(b->pieces[BLACK][PAWN] & adj)) score += isolated_pen;
        }
    }

    /* ── 4. Passed pawns (standard chess only) ───────────────────────────── */
    if (!is_merc) {
    static const int PASSED_BONUS[8] = { 0, 5, 10, 20, 40, 60, 100, 0 };
    for (int c = 0; c < 2; c++) {
        Color opp = (Color)(c ^ 1);
        Bitboard bb = b->pieces[c][PAWN];
        while (bb) {
            Square sq = (Square)bb_pop_lsb(&bb);
            int row = SQ_ROW(sq), col = SQ_COL(sq);
            int rank = (c == WHITE) ? row : (7 - row);

            /* A pawn is passed if no enemy pawns ahead on same or adjacent files */
            bool passed = true;
            int r_start = (c == WHITE) ? row + 1 : 0;
            int r_end   = (c == WHITE) ? 8 : row;
            for (int r = r_start; r < r_end && passed; r++) {
                for (int dc = -1; dc <= 1; dc++) {
                    int nc = col + dc;
                    if (nc < 0 || nc > 7) continue;
                    if (BB_HAS(b->pieces[opp][PAWN], SQ(r, nc))) {
                        passed = false;
                        break;
                    }
                }
            }
            if (passed) {
                int mg_b = PASSED_BONUS[rank];
                int eg_b = mg_b * 3 / 2;
                int pp = (mg_b * mg_weight + eg_b * eg_weight) / 256;
                score += (c == WHITE) ? pp : -pp;
            }
        }
    }
    } /* end if (!is_merc) for passed pawns */

    /* ── 5. Rook on open / semi-open files (skip for Mercenary) ────────── */
    if (!is_merc) {
    for (int c = 0; c < 2; c++) {
        Color opp = (Color)(c ^ 1);
        Bitboard bb = b->pieces[c][ROOK];
        while (bb) {
            Square sq = (Square)bb_pop_lsb(&bb);
            Bitboard file = (Bitboard)0x0101010101010101ULL << SQ_COL(sq);
            bool own_p = (b->pieces[c][PAWN] & file) != 0;
            bool opp_p = (b->pieces[opp][PAWN] & file) != 0;
            int bonus = 0;
            if (!own_p && !opp_p) bonus = 25;      /* open file */
            else if (!own_p)       bonus = 15;      /* semi-open */
            score += (c == WHITE) ? bonus : -bonus;
        }
    }
    }

    /* ── 6. King safety (always active for Mercenary; middlegame for standard;
              Heir: only when check rules apply) ──────────────────────────── */
    if (mg_weight > 64 || is_merc) {
        for (int c = 0; c < 2; c++) {
            Color opp = (Color)(c ^ 1);
            Bitboard kbb = b->pieces[c][KING];
            if (kbb == BB_EMPTY) continue;
            /* Heir: skip king safety when check rules don't apply (king is expendable) */
            if (is_heir && !heir_check_applies(b, (Color)c)) continue;
            Square ksq = bb_lsb(kbb);

            /* 6a. Pawn shield */
            int kr = SQ_ROW(ksq), kc = SQ_COL(ksq);
            int shield = 0;
            if (is_merc) {
                /* Mercenary: count ALL adjacent friendly pawns as shield */
                shield = bb_popcount(b->pieces[c][PAWN] & king_attacks[ksq]);
            } else {
                int fwd = (c == WHITE) ? 1 : -1;
                for (int dc = -1; dc <= 1; dc++) {
                    int nc = kc + dc, nr = kr + fwd;
                    if (nc < 0 || nc > 7 || nr < 0 || nr > 7) continue;
                    if (BB_HAS(b->pieces[c][PAWN], SQ(nr, nc))) shield++;
                }
            }
                int shield_weight = is_merc ? 26 : 10;
                /* Mercenary: keep king safety highly relevant even in simplified
                    positions because king-like pawns create persistent mating nets. */
                int kw = is_merc ? (mg_weight > 140 ? mg_weight : 140) : mg_weight;
            int s_bonus = shield * shield_weight * kw / 256;
            score += (c == WHITE) ? s_bonus : -s_bonus;

            /* 6b. Attacker count in king zone */
            Bitboard king_zone = king_attacks[ksq] | BB_SQ(ksq);
            int attack_weight = 0;

            Bitboard oq = b->pieces[opp][QUEEN];
            while (oq) {
                Square s = (Square)bb_pop_lsb(&oq);
                if ((bishop_attacks_calc(s, b->all) | rook_attacks_calc(s, b->all)) & king_zone)
                    attack_weight += 5;
            }
            Bitboard or_ = b->pieces[opp][ROOK];
            while (or_) {
                Square s = (Square)bb_pop_lsb(&or_);
                if (rook_attacks_calc(s, b->all) & king_zone) attack_weight += 3;
            }
            Bitboard ob = b->pieces[opp][BISHOP];
            while (ob) {
                Square s = (Square)bb_pop_lsb(&ob);
                if (bishop_attacks_calc(s, b->all) & king_zone) attack_weight += 2;
            }
            Bitboard on = b->pieces[opp][KNIGHT];
            while (on) {
                Square s = (Square)bb_pop_lsb(&on);
                if (knight_attacks[s] & king_zone) attack_weight += 2;
            }

            /* Mercenary pawns attack like kings — include in king danger */
            if (is_merc) {
                Bitboard op = b->pieces[opp][PAWN];
                while (op) {
                    Square s = (Square)bb_pop_lsb(&op);
                    if (king_attacks[s] & king_zone) attack_weight += 5;
                }
            }

            /* Mercenary: use min phase weight 100 so danger never fully disappears;
               Standard: scale by game phase */
            int danger = (attack_weight * attack_weight * kw) >> 8;
            score += (c == WHITE) ? -danger : danger;
        }
    }

    /* ── 7. Threat evaluation (Stockfish-inspired) ───────────────────────── */
    /*  Bonus for pawns attacking enemy non-pawn pieces.  One of Stockfish's */
    /*  strongest non-material eval terms — makes the engine target enemy    */
    /*  pieces with cheap attackers and avoid leaving pieces en prise.       */
    if (is_merc) {
        /* In Mercenary, pieces sitting next to enemy pawns are much less
           stable than in classic chess because those pawns move and capture
           like kings. Penalize exposed heavy/minor pieces directly. */
        static const int MERC_EXPOSED_BY_PAWN[] = { 0, 35, 35, 60, 110, 0 };
        for (int c = 0; c < 2; c++) {
            Bitboard exposed = pawn_atk[c ^ 1] & b->occupied[c]
                             & ~(b->pieces[c][PAWN] | b->pieces[c][KING]);
            int penalty = 0;
            while (exposed) {
                Square s = (Square)bb_pop_lsb(&exposed);
                PieceType pt = PIECE_TYPE(b->mailbox[s]);
                if (pt < 6) penalty += MERC_EXPOSED_BY_PAWN[pt];
            }
            score += (c == WHITE) ? -penalty : penalty;
        }
    }

    for (int c = 0; c < 2; c++) {
        Bitboard threatened = pawn_atk[c] & b->occupied[c ^ 1]
                            & ~b->pieces[c ^ 1][PAWN];
        int tb = 0;
        while (threatened) {
            Square s = (Square)bb_pop_lsb(&threatened);
            PieceType pt = PIECE_TYPE(b->mailbox[s]);
            /* Bonus by victim value: N=30, B=30, R=50, Q=70, K=0 */
            static const int THREAT_BY_PAWN[]      = { 0, 30, 30, 50,  70, 0 };
            static const int THREAT_BY_MERC_PAWN[] = { 0, 45, 45, 75, 130, 0 };
            const int *threat_table = is_merc ? THREAT_BY_MERC_PAWN : THREAT_BY_PAWN;
            if (pt < 6) tb += threat_table[pt];
        }
        score += (c == WHITE) ? tb : -tb;
    }

    /* Tempo bonus: side to move gets a small bonus (helps the side with
       initiative, and crucially breaks the "all moves score 0" problem in
       Mercenary where massive transpositions equalize everything). */
    if (is_merc) score += (b->side == WHITE) ? 15 : -15;
    if (is_heir) score += (b->side == WHITE) ? 10 : -10;

    /* Return from side-to-move's perspective */

    return score;
}
