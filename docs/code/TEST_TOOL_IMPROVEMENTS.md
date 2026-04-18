# Test & Tool Improvements — Implementation Record

This document records every change made in the P0–P3 improvement pass on the
`frontend/test` and `frontend/tool` directories.  Each section covers one
priority band: the issue found, the root cause, the files changed, what was
done, and the expected outcome.

---

## P0 — Batch audit KPI discarded silently

### Issue
All seven `*_audit_batch.dart` tools collected per-game KPI data inside
`engine_audit` but discarded it at the batch level.  The only output was a
list of individual game summaries; no aggregate signal existed for CI
trend-watching.

### Root cause
`audit_kpi.dart` did not exist.  Each audit batch re-implemented its own
ad-hoc accumulation of only `totalGames` and `totalTime`; the richer KPI
fields (`earlyKingMoves`, `castlingRightLosses`, `castled`, `kingExposureIndex`)
were available per-game in the engine-audit report text but never summed.

### Files changed
| File | Change |
|------|--------|
| `frontend/tool/audit_kpi.dart` | **Created** — shared KPI parser and aggregator |
| `frontend/tool/friendly_fire_audit_batch.dart` | Import + call `AuditKpiAggregate.fromSnapshots` |
| `frontend/tool/kings_battle_audit_batch.dart` | Same |
| `frontend/tool/truce_audit_batch.dart` | Same |
| `frontend/tool/heir_audit_batch.dart` | Same |
| `frontend/tool/mercenary_audit_batch.dart` | Same |
| `frontend/tool/succession_audit_batch.dart` | Same |
| `frontend/tool/save_the_queen_audit_batch.dart` | Same |

### What changed
`audit_kpi.dart` provides:
- `kpiLinePattern` — RegExp matching the `KPI:` line in each engine-audit
  game report.
- `AuditKpiSnapshot.fromReport(String report)` — parses one game report into
  typed fields.
- `AuditKpiAggregate.fromSnapshots(...)` — sums all snapshots.
- `.toSummaryLine()` — produces
  `KPI aggregate: earlyKingMoves=N castlingRightLosses=N castled[w=K/N,b=K/N] kingExposureIndex(avg)=N.NN`

Each batch tool now calls `AuditKpiAggregate.fromSnapshots` over all collected
reports and appends the summary line to its output.

### Expected outcome
Running any `*_audit_batch.dart` for ≥ 1 game emits a KPI aggregate at the
bottom.  King-move and castling behaviour can be trended across engine builds.

---

## P1 — Mercenary engine-audit struct bug, delta formula, replay-state

### Issue (a) — struct mismatch
`mercenary_engine_audit.dart` used `AuditResult` fields introduced for
FriendlyFire (`replayPrefix` / `earlyKingMoves`) that the Mercenary struct did
not declare, causing a compile-time error.

### Issue (b) — inverted delta formula
The delta was computed as `playedScore - referenceScore` (positive = worse),
opposite to every other audit tool.

### Issue (c) — missing replay-state warning
When the replay is truncated for a mid-game board, no note was printed to
distinguish it from a full-replay position.

### Root cause
Mercenary audit was derived from an older version of the FriendlyFire audit
before the struct was stabilised.

### Files changed
| File | Change |
|------|--------|
| `frontend/tool/mercenary_engine_audit.dart` | Struct fields + delta formula + replay warning |

### What changed
- Aligned `AuditResult` construction to match the Mercenary struct definition.
- Flipped delta to `referenceScore - playedScore` (positive = reference is
  better, negative = engine outperformed reference).
- Added `if (truncated) print('[replay truncated at move $n]')` before the
  per-move table.

### Expected outcome
`mercenary_engine_audit.dart` compiles and produces deltas with the same sign
convention as the other six audit tools.

---

## P1 — Regression test score-brittleness

### Issue
Four regression tests (`friendly_fire`, `truce`, `save_the_queen`,
`succession`) compared engine scores with `==` to a hard-coded centipawn value.
A legal but equally good alternative move would fail the test even if the move
quality was identical.

### Root cause
Tests were written to pin exact scores rather than acceptance bands.

### Files changed
| File | Change |
|------|--------|
| `frontend/test/friendly_fire_engine_regression_test.dart` | `expect(score, inInclusiveRange(...))` |
| `frontend/test/truce_engine_regression_test.dart` | Same |
| `frontend/test/save_the_queen_engine_regression_test.dart` | Same |
| `frontend/test/succession_engine_regression_test.dart` | Same |

### What changed
Each `expect(score, equals(X))` replaced by
`expect(score, inInclusiveRange(X - margin, X + margin))` where `margin` is
25 cp (one quarter-pawn), covering legal transpositions without masking real
regressions.

### Expected outcome
Regression tests tolerate transpositions and internal search instability while
still catching meaningful quality drops.

---

## P1 — Missing asymmetric castling-policy scenarios

### Issue
`king_castling_policy_regression_test.dart` only tested symmetric positions
(both kings castled or both failed to castle).  The asymmetric case—one side
castles, the other forfeits castling rights through king movement—was not
covered.

### Root cause
Initial test set focused on the happy path; edge cases were deferred.

### Files changed
| File | Change |
|------|--------|
| `frontend/test/king_castling_policy_regression_test.dart` | 3 new test scenarios |

### What changed
Added:
1. White castles kingside while black moves king early (forfeits both sides).
2. Black castles queenside while white never castles (rights expired).
3. Both sides castle but to opposite flanks.

### Expected outcome
A castling-policy regression affecting only one colour is caught.

---

## P2 — Missing rule-mechanics tests for Mercenary, Succession, SaveTheQueen

### Issue
FriendlyFire, Kings Battle, Truce, and Heir all had dedicated
`*_rule_mechanics_test.dart` files.  Mercenary, Succession, and Save-the-Queen
relied solely on regression tests and did not verify individual rules in
isolation.

### Root cause
These three variants were added later; the rule-mechanics pattern was not
back-filled.

### Files changed
| File | Change |
|------|--------|
| `frontend/test/mercenary_rule_mechanics_test.dart` | **Created** |
| `frontend/test/succession_rule_mechanics_test.dart` | **Created** |
| `frontend/test/save_the_queen_rule_mechanics_test.dart` | **Created** |

### What changed
Each file contains always-on unit tests (no engine, no `skip:` guard) that
verify:
- Legal move generation for variant-specific pawn rules.
- Terminal conditions (checkmate, stalemate, goal-state win).
- Capture legality.
- Piece-type promotion or conversion rules where applicable.

### Expected outcome
Rule regressions in those three variants surface immediately in CI without
needing the engine build artifact.

---

## P2 — Missing probe-bundle tests for FriendlyFire, Heir, Mercenary

### Issue
Kings Battle and Truce had `manual_*_probe_cases_test.dart` bundles with
fixed starting positions (auto-skipped, runnable with `--run-skipped`).
FriendlyFire, Heir, and Mercenary had position-probe *tools* but no
pre-wired case bundles.

### Root cause
Probe bundles were created incrementally; the later-added mods were not
back-filled.

### Files changed
| File | Change |
|------|--------|
| `frontend/test/manual_friendly_fire_probe_cases_test.dart` | **Created** |
| `frontend/test/manual_heir_probe_cases_test.dart` | **Created** |
| `frontend/test/manual_mercenary_probe_cases_test.dart` | **Created** |

### What changed
Each file mirrors the Kings Battle bundle pattern:
- Test group marked `skip: true` by default.
- 4–6 named probe cases, each specifying FEN + expected-best-move candidates.
- Uses `NativeEngine.isAvailable` guard so the suite is skippable without the
  native library.

### Expected outcome
Developers can run `flutter test test/manual_*_probe_cases_test.dart
--run-skipped` to quickly exercise known tactical positions for those three
variants without writing ad-hoc FENs.

---

## P3 — Position-probe code duplication (≈ 150 lines × 7 files)

### Issue
All seven `*_position_probe.dart` tools independently defined the same nine
private functions: `_ScoredMove / _analyzeMove / _scorePlayedMove / _sameMove /
_moveLabel / _cp / _readArg / _readIntArg / _parseCoordinateMove`.  Any fix to
one had to be copied to the other six.

### Root cause
The probe tools were cloned from a single prototype and diverged; no shared
library existed.

### Files changed
| File | Change |
|------|--------|
| `frontend/tool/position_probe_runner.dart` | **Created** — shared utilities |
| `frontend/tool/friendly_fire_position_probe.dart` | Import + removed 9 private definitions |
| `frontend/tool/kings_battle_position_probe.dart` | Same |
| `frontend/tool/truce_position_probe.dart` | Same (omits `skillLevel` — uses default 4) |
| `frontend/tool/heir_position_probe.dart` | Same |
| `frontend/tool/mercenary_position_probe.dart` | Same |
| `frontend/tool/succession_position_probe.dart` | Same |
| `frontend/tool/save_the_queen_position_probe.dart` | Same |

### What changed
`position_probe_runner.dart` exports:

| Symbol | Purpose |
|--------|---------|
| `class ProbeMove` | `{ChessMove move; int score; ChessMove? bestReply}` |
| `analyzeProbeMove(...)` | Full engine search for one move, returns `ProbeMove` |
| `scoreProbeMove(...)` | Mover-aware child-board evaluation (`-reply.score` when child's turn = mover's opponent) |
| `sameProbeMove(a, b)` | Coordinate equality (from+to+promotion) |
| `probeMoveLabel(move)` | Piece-prefix + from + capture-flag + to + promotion |
| `probeCp(score)` | `+1.23` or `M5` format |
| `readProbeArg(args, name)` | `--name=value` parser, empty → null |
| `readProbeIntArg(args, name, fallback)` | Same with int parse + fallback |
| `parseCoordinateMove(orch, board, notation)` | UCI notation → `ChessMove?` via `getAllValidMoves` |

`skillLevel` defaults to 4 in both `analyzeProbeMove` and `scoreProbeMove` so
Truce (which hardcodes skill 4) can omit the parameter.

Each probe file now contains only its mod-specific `_buildBoard` and `main`;
everything else is imported from the shared runner.

### Expected outcome
A bug fix or new field in probe logic requires a single edit in
`position_probe_runner.dart`; all seven tools pick it up automatically.

---

## P3 — Missing preset calibration tools for Heir and Mercenary

### Issue
Only Truce (`truce_preset_calibration.dart`) had a preset calibration tool.
Heir and Mercenary had no way to sweep all engine levels against a reference
over a fixed set of opening positions, making per-build quality tracking
impossible for those variants.

### Root cause
Calibration tools were introduced for Truce; the pattern was not extended to
the other variants.

### Files changed
| File | Change |
|------|--------|
| `frontend/tool/heir_preset_calibration.dart` | **Created** |
| `frontend/tool/mercenary_preset_calibration.dart` | **Created** |

### What changed
Both files mirror `truce_preset_calibration.dart` exactly in structure:

- `_regressionCases` (8–9 named opening positions as UCI replay lists).
- `_clusterCases` (6 additional cluster positions).
- `_buildCases(suiteName)` — `'smoke'` (5 cases), `'regression'` (core set),
  `'production'`/`'offline'` (both sets combined).
- `_CalibrationOptions.fromArgs` — parses `--suite`, `--levels`,
  `--reference-depth`, `--reference-ms`, `--reference-skill`, `--top-count`.
- Main loop: for each `EngineLevel` × each case, computes
  `delta = referenceMoveScore - playedScore`, aggregates avg/max/exact.
- Output: per-level summary line + worst-N table with `Replay:` rows +
  `Summary:` section (aggregate lines repeated for easy grepping).

Heir cases use standard chess openings (French, Ruy Lopez, Scotch Gambit, etc.)
since Heir rules are close to standard chess.

Mercenary cases use single-step pawn advances (`e2e3`, `d2d3`) and early piece
development, which are universally legal in the Mercenary 8-direction pawn
model.

Both tools are runnable as:

```
dart tool/heir_preset_calibration.dart --suite=smoke --levels=easy,medium
dart tool/mercenary_preset_calibration.dart --suite=production
```

### Expected outcome
Quality trends for Heir and Mercenary can be tracked across engine builds using
the same workflow as Truce calibration.

---

## Summary table

| Priority | Item | Files created | Files modified |
|----------|------|--------------|----------------|
| P0 | Batch KPI aggregation | `audit_kpi.dart` | 7 `*_audit_batch.dart` |
| P1 | Mercenary audit struct/delta/replay | — | `mercenary_engine_audit.dart` |
| P1 | Regression score guards | — | 4 `*_engine_regression_test.dart` |
| P1 | Asymmetric castle scenarios | — | `king_castling_policy_regression_test.dart` |
| P2 | Rule-mechanics tests | 3 `*_rule_mechanics_test.dart` | — |
| P2 | Probe-bundle tests | 3 `manual_*_probe_cases_test.dart` | — |
| P3 | Shared probe runner | `position_probe_runner.dart` | 7 `*_position_probe.dart` |
| P3 | Heir calibration tool | `heir_preset_calibration.dart` | — |
| P3 | Mercenary calibration tool | `mercenary_preset_calibration.dart` | — |

**Total new files:** 9  
**Total modified files:** 19
