#include "evaluate.h"
#include "eval/eval_types.h"

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Evaluation dispatcher                                                    */
/*                                                                           */
/*  The evaluation is split into three stages:                               */
/*    1. eval_common_init:  material + PST + mobility + phase + bishop pair  */
/*    2. Per-mod evaluation: mod-specific strategic heuristics               */
/*    3. eval_common_finish: pawn structure, king safety, threats, tempo     */
/* ═══════════════════════════════════════════════════════════════════════════ */

int evaluate(const Board *b) {
    EvalContext ctx;

    /* Stage 1: Common material, PST, mobility evaluation */
    eval_common_init(b, &ctx);

    /* Stage 2: Mod-specific strategic evaluation */
    switch (b->mod) {
        case MOD_MERCENARY:
            ctx.score += eval_mercenary(b, &ctx);
            break;
        case MOD_HEIR:
            ctx.score += eval_heir(b, &ctx);
            break;
        case MOD_FRIENDLY_FIRE:
            ctx.score += eval_friendly_fire(b, &ctx);
            break;
        case MOD_TRUCE:
            if (b->truce_active)
                ctx.score += eval_truce(b, &ctx);
            break;
        case MOD_KINGS_BATTLE:
            ctx.score += eval_kings_battle(b, &ctx);
            break;
        case MOD_SAVE_QUEEN:
            ctx.score += eval_save_queen(b, &ctx);
            break;
        case MOD_SUCCESSION:
            ctx.score += eval_succession(b, &ctx);
            break;
        default:
            break;
    }

    /* Stage 3: Common pawn structure, king safety, threats */
    ctx.score += eval_common_finish(b, &ctx);

    /* Return from side-to-move's perspective */
    return (b->side == WHITE) ? ctx.score : -ctx.score;
}
