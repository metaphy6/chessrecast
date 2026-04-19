---
mode: ask
description: Parse a single audit report into structured findings without editing any code. Phases findings by opening / midgame / endgame / tactics / strategy.
---

# Triage audit report

Read the report at `${input:report_path}` for mod `${input:mod}`.

Extract every occurrence of:
- illegal move attempts,
- engine crashes / aborts,
- draw-rule misapplications (50-move, repetition, K+P vs K Mercenary 100-half-move rule, Save-the-Queen queen-vs-queen short-range rule, Succession last-pawn-must-promote-to-king rule, Truce no-capture-no-check rule),
- blunders with worst-miss ≥ `${input:threshold_cp:200}` centipawns,
- KPI regressions vs `agent/baselines/${input:mod}.json` (`earlyKingMoves`, `castlingRightLosses`, `castledByPly_avg`, `kingExposureIndex_avg`, `avgWorstMiss_cp`, `maxWorstMiss_cp`, `blundersGte200cp`, `blundersGte300cp`, `ruleViolations`, `engineCrashes`),
- opening-principle breaches (queen out before two minor pieces developed, king move before castling while castling is legal, rook lift past rank 4 before castling, pawn moves on the king's flank before castling),
- endgame-conversion failures (failure to mate in K+Q vs K, K+R vs K, K+P vs K within the mod's draw-clock budget; mod-specific finales).

Classify each finding by **phase**:
- `opening` — plies 1..16 or while either king still has castling rights,
- `midgame` — between castling and the first endgame trigger (≤ 12 non-pawn pieces total, or one side ≤ 1 minor + 1 major),
- `endgame` — both sides past the midgame trigger above,
- `tactics` — any phase, but the report flags it as `worst_miss ≥ ${input:threshold_cp:200}` cp,
- `strategy` — long-horizon / mod-specific rule misapplications that don't fit the above (e.g. Succession bot ignoring last-pawn-must-promote-king).

For each finding, output a YAML block ready to append to `agent/queue.yaml`:

```yaml
- id: ${input:mod}-<phase>-<short-slug>
  mod: ${input:mod}
  status: pending
  kind: blunder | rule_violation | crash | kpi_regression | strategy | endgame_conversion | opening_principle
  phase: opening | midgame | endgame | tactics | strategy
  severity: low | med | high | critical
  evidence:
    report: ${input:report_path}
    line: <line number in report>
    fen: "<FEN if applicable>"
    move: "<UCI if applicable>"
  blunder_threshold_cp: 200
  notes: "<one sentence>"
```

Severity guide:
- `critical` — rule violation, crash, illegal move, lost K+Q vs K conversion.
- `high` — blunder ≥ 400 cp, opening-principle breach in plies 1..6, KPI regression > 10%.
- `med` — blunder 200..399 cp, opening-principle breach in plies 7..16, KPI regression 5..10%.
- `low` — KPI regression < 5%, strategic taste issue, slow conversion that still wins.

Do not edit any code. Do not run tests. Output only the YAML.
---
mode: ask
description: Parse a single audit report into structured findings without editing any code.
---

# Triage audit report

Read the report at `${input:report_path}` for mod `${input:mod}`.

Extract every occurrence of:
- illegal move attempts,
- engine crashes / aborts,
- draw-rule misapplications (50-move, repetition, K+P vs K mercenary rule, etc.),
- blunders with worst-miss ≥ `${input:threshold_cp:200}` centipawns,
- KPI regressions vs `agent/baselines/${input:mod}.json` (earlyKingMoves, castlingRightLosses, kingExposureIndex, avgWorstMiss, maxWorstMiss).

For each finding, output a YAML block ready to append to `agent/queue.yaml`:

```yaml
- id: <mod>-<short-hash>
  mod: <mod>
  status: pending
  kind: blunder | rule_violation | crash | kpi_regression
  severity: low | med | high | critical
  evidence:
    report: <report_path>
    line: <line number in report>
    fen: <fen if applicable>
    move: <uci if applicable>
  blunder_threshold_cp: 200
  notes: <one sentence>
```

Do not edit any code. Do not run tests. Output only the YAML.
