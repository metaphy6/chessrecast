# Test and Tool Algorithm Improvement Map (Frontend)

## Scope and Goal
This report analyzes all improvements represented in frontend/test and frontend/tool, maps the current algorithm-quality workflow by mod, identifies gaps, and proposes prioritized improvements.

Primary user concern addressed here:
- In most mods, kings appear to move too early/often and castling is forfeited too frequently unless the mod explicitly centers king behavior (for example Truce or Kings Battle).

## Method
I analyzed:
- Regression and rule tests in frontend/test.
- Manual audit/probe wrappers in frontend/test/manual_*.
- Audit/probe/calibration implementation in frontend/tool.

Representative evidence anchors are included with file:line references.

## Inventory Summary
Current structure is mature and systematic:
- 9 always-on regression/rule suites across variants.
- 24 manual harness tests (batch audits, engine audits, probes, calibration) that run with --run-skipped.
- Per-mod tooling for baseline-vs-reference quality deltas:
  - engine_audit
  - audit_batch
  - position_probe
- Additional special tools:
  - Friendly Fire root probe (frontend/test/manual_friendly_fire_root_probe_test.dart)
  - Kings Battle probe bundle (frontend/test/manual_kings_battle_probe_cases_test.dart:19)
  - Truce preset calibration (frontend/tool/truce_preset_calibration.dart:204)

## Cross-Mod Algorithm Improvement Map
The core improvement pipeline implemented in tools is:

1. Baseline vs reference decision quality
- A faster/weaker baseline search is compared against deeper reference search.
- Delta = reference-move score - played-move score.
- Used in audits for all mods.

2. Worst-miss surfacing
- Every audit emits "Worst N misses" with replay/FEN context.
- Batch audits aggregate worst misses over opening suites.

3. Position-level move ranking and candidate probing
- Position probes rank top moves and evaluate explicit candidate moves.
- Good for debugging targeted strategic mistakes.

4. Replay-aware reconstruction (stateful variants)
- Several tools explicitly warn that exact reproduction may require move history, not only FEN:
  - frontend/tool/friendly_fire_engine_audit.dart:77
  - frontend/tool/friendly_fire_position_probe.dart:47
  - frontend/tool/kings_battle_engine_audit.dart:77
  - frontend/tool/truce_engine_audit.dart:73
  - frontend/tool/save_the_queen_engine_audit.dart:74
  - frontend/tool/succession_engine_audit.dart:77

5. Suite-based breadth testing
- Most mods test opening matrices in batch mode.
- Truce has the most advanced suite generation:
  - default, expanded, and expanded-2ply suite construction
  - legality filtering for generated replays
  - frontend/tool/truce_audit_batch.dart:311

6. Search isolation support in state-heavy variants
- Save the Queen and Succession support isolate-searches and isolate-openings:
  - frontend/tool/save_the_queen_engine_audit.dart:383
  - frontend/tool/succession_engine_audit.dart:383
  - frontend/tool/save_the_queen_audit_batch.dart:196
  - frontend/tool/succession_audit_batch.dart:204

## Mod-by-Mod Improvement Map

### Friendly Fire
What improved (captured in tests/tools):
- Anti-king-walk and anti-loose-piece tactical sanity at root.
- Strong explicit move-choice regressions for tactical discipline.
- Representative regression anchor:
  - frontend/test/friendly_fire_engine_regression_test.dart:10

Tooling strengths:
- Full engine audit + batch + position probe.
- Additional root probe for targeted replay diagnostics:
  - frontend/test/manual_friendly_fire_root_probe_test.dart

Current gap:
- No direct castling-retention regression intent (only indirect king-safety patterns).

### Heir
What improved:
- Tactical move ordering and queen-drift suppression.
- Has at least one king-retreat safety preference case:
  - frontend/test/heir_engine_regression_test.dart:11

Tooling strengths:
- Mature audit/batch/probe stack.
- Shared Heir/Succession tool path for some logic.

Current gaps:
- No explicit castling-governance test cases.
- Probe currently requires --fen only (no replay input), limiting stateful reconstruction paths:
  - frontend/tool/heir_position_probe.dart

### Kings Battle
What improved:
- Rich king-activity strategy checks (expected for this mod).
- Explicit king-route/tucking tests:
  - frontend/test/kings_battle_engine_regression_test.dart:217
  - frontend/test/kings_battle_engine_regression_test.dart:252

Tooling strengths:
- Robust audit/batch/probe.
- Dedicated bundle of known hard probe scenarios:
  - frontend/test/manual_kings_battle_probe_cases_test.dart:19

Current gaps:
- Candidate lookup robustness issue (see prioritized issues below).

### Mercenary
What improved:
- Catastrophic king-safety blunder prevention and safe recapture preferences:
  - frontend/test/mercenary_engine_regression_test.dart:13

Tooling strengths:
- Audit/batch/probe coverage exists.
- Variant-specific default opening set is present in batch tool.

Current gaps:
- No explicit castling-retention test intent.
- Engine audit is simpler than other mods (no reference-move-score branch).

### Save the Queen
What improved:
- Variant terminal objective logic (queen capture/escape) asserted in regression.
- Checked-king defensive branch test present:
  - frontend/test/save_the_queen_engine_regression_test.dart:109

Tooling strengths:
- Replay-sensitive audit messaging.
- isolate-searches/isolate-openings controls.
- Probe includes structural move matching fallback (more robust than identity-only):
  - frontend/tool/save_the_queen_position_probe.dart:101
  - frontend/tool/save_the_queen_position_probe.dart:202

Current gaps:
- Castling and king-safety guardrails are not explicitly benchmarked as policy metrics.

### Succession
What improved:
- Variant win-condition handling around king promotion and safety:
  - frontend/test/succession_engine_regression_test.dart:33
  - frontend/test/succession_engine_regression_test.dart:56

Tooling strengths:
- Replay-sensitive audit messaging.
- isolate-searches/isolate-openings controls.
- Robust candidate equality fallback in probe:
  - frontend/tool/succession_position_probe.dart:101
  - frontend/tool/succession_position_probe.dart:202

Current gaps:
- Castling-governance behavior is not directly asserted by regression.

### Truce
What improved:
- Deep rule semantics beyond move choice:
  - truce activation/break logic
  - moved-piece freezing
  - no-check filtering
  - side-to-move truce-break behavior
- Explicit castling interaction is tested:
  - frontend/test/truce_test.dart:497

Tooling strengths:
- Most sophisticated batch suite generation and calibration.
- Preset calibration by engine levels with regression+cluster case banks:
  - frontend/tool/truce_preset_calibration.dart:10
  - frontend/tool/truce_preset_calibration.dart:119
  - frontend/tool/truce_preset_calibration.dart:204

Current gaps:
- Position probe candidate lookup has same equality fragility as several other mods.

## Focused Diagnosis: King Movement and Castling Forfeiture

### What the current evidence says
1. King behavior is explicitly tested heavily only where variant design expects it
- Kings Battle and Truce encode king-centric behavior deeply.

2. Non-king-centric mods mostly lack direct castling-policy assertions
- Only Truce has explicit castling test semantics:
  - frontend/test/truce_test.dart:497
- Search in frontend/test shows castling-specific assertions are essentially absent outside Truce.

3. Existing non-king-centric checks are mostly tactical snapshots, not longitudinal king-policy checks
- Example patterns: avoid one blunder move, pick one tactical continuation.
- Missing pattern: "do not voluntarily lose castling rights before threshold conditions." 

### Why this creates the user-observed behavior
Current test/tool infrastructure optimizes tactical correctness and immediate score deltas, but does not consistently encode early-game king-policy constraints (castling timing, king exposure penalties, voluntary king-move restrictions) for non-king-centric mods.

As a result, an engine can pass many tactical regressions while still drifting into strategically odd king trajectories.

## Prioritized Issues and Improvements

### P0: Castling and king-safety policy is under-specified in non-king-centric mods
Evidence:
- Castling-specific regression appears in Truce only: frontend/test/truce_test.dart:497.
- Heir/Mercenary/SaveTheQueen/Succession regression suites do not contain explicit castling-retention expectations.

Impact:
- Overactive king movement can remain regression-green.

Action:
- Add a cross-mod king-policy regression set (except mods where king activity is intended by rules).

### P1: Candidate lookup in several probes may be identity-fragile
Evidence:
- Identity-based lookup with firstWhere((s) => s.move == move):
  - frontend/tool/friendly_fire_position_probe.dart:101
  - frontend/tool/kings_battle_position_probe.dart:105
  - frontend/tool/truce_position_probe.dart:89
  - frontend/tool/heir_position_probe.dart:88
  - frontend/tool/mercenary_position_probe.dart:76
- SaveTheQueen/Succession already implemented structural fallback (_sameMove), indicating the robust pattern:
  - frontend/tool/save_the_queen_position_probe.dart:202
  - frontend/tool/succession_position_probe.dart:202

Impact:
- Candidate probe can throw or mismatch if object identity differs.

Action:
- Standardize structural move matching across all probes.

### P1: Replay-state dependence is documented but not uniformly enforced by interfaces
Evidence:
- Multiple tools warn that replay history matters (see replay anchors above).
- Some probes are FEN-only by design (example: Heir probe), limiting exact reproduction workflows.

Impact:
- Diagnosis can become inconsistent between FEN-only and replay-based reproductions.

Action:
- Normalize all probes to accept both --fen and --moves, and print a statefulness warning whenever the mod has replay-sensitive mechanics.

### P2: Tool defaults are not normalized across mods
Evidence:
- Mercenary defaults are much deeper/slower than many other mods (for example batch 5/250 vs 7/900).
- Heir tool path omits skill parameterization in user-facing args unlike other variants.

Impact:
- Cross-mod quality deltas are less comparable.

Action:
- Define a shared baseline/reference profile matrix by mod and use explicit profile names.

### P2: Naming confusion in Heir batch tool
Evidence:
- frontend/tool/heir_audit_batch.dart:37 defines runSuccessionAuditBatch as alias into Heir path.

Impact:
- Maintainer confusion and easier accidental misuse.

Action:
- Move succession naming to succession-specific file only, or document alias purpose clearly.

### P2: Batch orchestration stability for chunked parallel runs
Evidence:
- Parallel chunk script exists: .vscode/friendly_fire_batch_chunked.sh.
- Current workflow can contend on Flutter test startup/locking in practice when parallelized aggressively.

Impact:
- Operational friction and flaky audit throughput.

Action:
- Keep controlled parallelism low and add lock-aware retries or serialized fallback mode.

## Recommended King/Castling Roadmap

### Phase 1: Add explicit king-policy KPIs to reports (no engine logic change yet)
Add to all engine_audit and batch outputs:
- earlyKingMoveCount (plies <= N)
- castlingRightLossByVoluntaryKingMove
- castledByPly (or neverCastled)
- kingExposureIndex (simple heuristic proxy)

Status (2026-04-09):
- Implemented for all engine_audit tools via shared helper frontend/tool/king_policy_metrics.dart.
- Wired into Friendly Fire, Kings Battle, Truce, Heir, Mercenary, Save the Queen, and Succession engine audits.
- Batch summaries remain pending for the same KPI set.

Expected outcome:
- Immediate visibility of the issue as a measurable signal.

### Phase 2: Add regression guardrails per mod
For Heir, Mercenary, SaveTheQueen, Succession, FriendlyFire:
- cases where best move should preserve castling rights unless tactical refutation exists.
- cases where early king walk must lose by score margin against castling/development plan.

Status (2026-04-09):
- Implemented expanded cross-mod guardrails in frontend/test/king_castling_policy_regression_test.dart.
- Coverage now includes Friendly Fire, Heir, Mercenary, Save the Queen, and Succession.
- Added center-pressure scenarios for both sides and assertions that reject voluntary quiet non-castling king moves when castling rights and alternatives exist.

Keep exceptions explicit:
- Kings Battle: king activity expected.
- Truce: one-move-per-piece and freeze semantics dominate.

### Phase 3: Introduce policy terms in evaluation/search (mod-aware)
Suggested policy gates:
- Penalize voluntary king moves pre-development threshold in non-king-centric mods.
- Bonus for legal castling completion if center is semi-open.
- Penalty for losing castling rights without tactical gain.
- Relaxation trigger when forced-check/tactical urgency exists.

Safer replacement strategy for hard-coded native overrides:
1. Replace board-shape exact-match overrides with feature-triggered policy packs
- Current exact-match overrides in frontend/native/engine/bridge.c (Friendly Fire and Kings Battle) should be migrated to feature checks such as king-zone pressure, exposed-queen risk, shelter delta, and tactical urgency.
- Keep behavior variant-scoped, but avoid square-by-square signatures.

2. Introduce ranked policy candidates, not forced move picks
- Instead of returning a single forced override move, add policy-favored candidates into refinement pools with additive bias scores.
- Preserve tactical freedom by allowing verification scoring to overrule policy bias when tactical gain is clear.

3. Add bounded verification windows per policy class
- Use wider acceptance windows for king-safety recovery moves and tighter windows for quiet pawn/queen drift suppression.
- Require tactical non-regression checks (mate, hanging major/minor, immediate king exposure spike) before policy replacement is accepted.

4. Run policy shadow mode before deleting old overrides
- For each legacy override site, log both legacy pick and policy pick in audits for a burn-in period.
- Promote policy path only when it matches or improves worst-miss and king-policy KPI trends.

5. Decommission legacy overrides incrementally with rollback toggles
- Remove one override class at a time (Friendly Fire first, then Kings Battle phase1, then Kings Battle unlocked).
- Keep per-class runtime flags for fast rollback while retaining the new policy code path.

Acceptance criteria for replacement:
- No regression in existing always-on engine regression suites.
- No increase in >=2.00 and >=3.00 batch worst-miss counts for affected mods.
- King-policy KPI trend non-degradation (earlyKingMoveCount, castlingRightLossByVoluntaryKingMove, kingExposureIndex).

### Phase 4: Expand probe bundles
- Replicate Kings Battle probe-bundle style for other mods with king/castling anti-pattern sets.
- Add candidate pairs like:
  - king move vs castling
  - queen sortie vs king-safety consolidation
  - pawn grab vs king shelter integrity

## Concrete Test Additions (Proposed)

1. New regression suites (per non-king-centric mod)
- *_king_castling_regression_test.dart

2. New assertions
- Avoid voluntary king move when castling is legal and tactical score margin is small.
- Prefer castling or shelter-preserving development over speculative pawn/queen grabs.

3. New manual bundles
- manual_*_king_policy_probe_cases_test.dart
- Candidate pairs should include one king-safe move and one king-exposing move.

## Implementation Order (Practical)
1. Standardize candidate matching in all probes to structural equality.
2. Add king/castling telemetry fields to engine audits and batch summaries.
3. Add 3-5 high-value king-policy regressions per non-king-centric mod.
4. Tune evaluation/search gates with those tests as acceptance criteria.
5. Expand opening suites where king-policy failures are frequent.

## Final Assessment
The current test/tool architecture is strong for tactical validation and variant-rule correctness, but it under-encodes king/castling strategic policy outside king-centric variants. This explains why strategy can still look unnatural to humans despite many passing regressions.

The fastest path is to add explicit king-policy metrics + regressions first, then tune heuristics against those hard guards.
