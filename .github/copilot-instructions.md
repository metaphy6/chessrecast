<!--
NOTE: this file is read by every Copilot Chat / agent interaction in this
repo. Keep it focused, scannable, and machine-friendly. The chess-mod-improver
chat mode and the improve-mod / triage-audit-report prompts cite this file
section by section — do not rename headings without updating those.
-->

# Copilot repo instructions — chessrecast

These rules apply to **every** Copilot Chat / agent interaction in this repo.

## Project shape

- `frontend/` — Flutter app + Dart test harness (`frontend/test/`) + Dart audit tools (`frontend/tool/`).
- `frontend/native/engine/` — C engine (`bridge.c`, per-mod heuristics, eval, search) used by the Flutter app via FFI.
- `backend/` — Go services (out of scope for engine-strength work).
- `agent/` — autonomous-loop state, queue, baselines, reports (see `agent/README.md`).
- `scripts/power/` — start/stop scripts that keep the workstation awake during long agent sessions.
- Seven chess mods under active improvement: **heir, friendly_fire, kings_battle, mercenary, save_the_queen, succession, truce**.

## Game-quality charter (the bar every mod must meet)

Users open Chess Recast expecting a **classical chess bot**, not a toy. Every patch the agent ships must keep all four phases of play strong:

1. **Openings.** Develop minor pieces before the queen, contest the centre (e/d files), castle by ply ~16, do not move the king or rook before castling unless forced. Per-mod opening prefs live in `frontend/native/engine/eval/eval_<mod>.c` and `frontend/native/engine/search/heuristics_<mod>.c`.
2. **Middlegame.** Find tactics down to the audit-batch reference depth (depth 6 / 500 ms / skill 4) without the worst-miss exceeding **2.00 cp** on any opening line in a 50-game batch. Coordinate pieces; avoid one-move queen sorties, premature exchanges, and rook lifts that abandon the king zone.
3. **Endgame.** Convert obvious technical wins. Specifically:
   - K+Q vs K, K+R vs K, K+P vs K (Mercenary uses the 100-half-move rule, see `docs/game/DRAW_RULES.md`),
   - opposite-side castled pawn endgames where one side is up a healthy pawn,
   - mod-specific finales (Save the Queen escape race, Succession last-pawn-promotes-to-king, Heir double-king mating nets, Truce post-truce piece activity).
4. **Strategy & tactics — mod-aware.** Each mod has a unique meta layer (see `docs/game/GAME_MODS_DOCUMENTATION.md`). Per-mod `*_refine_result` blocks in `frontend/native/engine/bridge.c` are the **only** place where a mod is allowed to deviate from the shared engine; deviations must be defended by an evidence-backed audit report.

A change is acceptable only when it improves at least one of those four buckets **and regresses none** of the KPIs in `agent/baselines/<mod>.json` by more than 5%.

## Hard rules (do not violate)

1. **Main branch is allowed.** The agent may commit and push directly to `main` *only after* all gates in rule 4 pass. Still forbidden: `git push --force`, `git push --force-with-lease`, `git reset --hard` on already-pushed commits, `--no-verify`, rewriting published history, deleting `main`. On any gate failure the agent must `git restore .` (or `git reset --hard HEAD` if nothing has been committed yet) and never push the failing change.
2. **Per-mod isolation.** When fixing a single mod, only edit:
   - `frontend/lib/mods/<mod>.dart` (and any `frontend/lib/mods/<mod>/**` subtree),
   - `frontend/lib/engine/<mod>_*.dart` (if present),
   - mod-scoped overrides inside `frontend/native/engine/bridge.c` (the `*_refine_result` blocks),
   - mod-scoped C files: `frontend/native/engine/eval/eval_<mod>.c`, `frontend/native/engine/search/heuristics_<mod>.c`,
   - the mod's own tests under `frontend/test/manual_<mod>_*` and `frontend/test/<mod>_*`.

   Touching shared search/eval code (`frontend/native/engine/search/search.c`, `eval/eval.c`, `bridge.c` outside the `*_refine_result` blocks, `frontend/lib/engine/engine.dart`, `frontend/lib/engine/native.dart`) requires an explicit `kind: shared_edit` task in the queue with severity ≥ high and a written rationale.
3. **Same algorithm across mods.** Strength gains must come from per-mod evaluation/heuristic tuning, **not** from divergent search algorithms. If you find yourself rewriting alpha-beta / quiescence / move-ordering for one mod only, stop and flag it as `kind: shared_edit`.
4. **Audit gating before commit.** Every code change must be followed, in order:
   1. mod regression test (`<mod>_engine_regression_test.dart`) — must stay green,
   2. `king_castling_policy_regression_test.dart` — must stay green,
   3. mod's rule-mechanics test if it exists (e.g. `mercenary_rule_mechanics_test.dart`, `save_the_queen_rule_mechanics_test.dart`, `succession_rule_mechanics_test.dart`, `truce_test.dart`) — must stay green,
   4. a fresh **≥50-game** audit batch via `manual_<mod>_audit_batch_test.dart` (50 lines in `<MOD>_BATCH_OPENINGS`),
   5. KPI delta vs the baseline at `agent/baselines/<mod>.json` — see thresholds in that file.

   If any gate fails, **revert the change**, record the finding in `agent/queue.yaml`, append a `gate_fail` line to `agent/state/log.jsonl`, and do not commit.
5. **Rate-limit hygiene.** If a tool call returns 429 / "rate limit" / "quota": stop the current task, write progress to `agent/state/checkpoint.json`, and pause for the cooldown the response specifies (or 5 minutes if unspecified) before resuming. Never retry tighter than exponential backoff.
6. **Findings must be evidence-backed.** A "blunder" or "rule violation" is only a finding if it appears in a generated audit report file under `/tmp/` or `agent/reports/`. No edits based on guessed positions.
7. **Never edit the `_audit_batch_test.dart` / `_position_probe_test.dart` skip flags or thresholds to make a run pass.** Those tests are the gate.

## Take-initiative directive

The agent is expected to act, not ask. When investigating a mod:

- If a probe / batch run surfaces **new** evidence (a fresh blunder, a rule misapplication, a KPI regression) that is not already tracked, **append a new entry to `agent/queue.yaml`** using the schema below before continuing. Do not silently ignore findings — even ones outside the current task's scope.
- If the user-visible UI test (`info_panel_overflow_test.dart`, `widget_test.dart`) breaks as a side effect of an engine change, fix it inside the same task and re-gate.
- If a `_rule_mechanics_test.dart` is missing for a behavior the agent just fixed, add a focused regression test in the **same** mod's test file (per-mod allow-list rule still applies).
- If the build is broken (native lib missing / `flutter test` fails to load), run `flutter pub get` then rebuild the native lib via the VS Code task **`Frontend: Rebuild Native Engine`** (or the equivalent `cmake --build build/native/linux`) before retrying the gate. Do not ask the user to do it.
- If `agent/baselines/<mod>.json` is missing or older than 7 days, regenerate it from a fresh 50-game batch *before* triaging the queue task.
- If `git pull` reveals upstream changes touching the same mod, rebase, re-run the gate from scratch, and only then attempt the commit.

## Live test-watchdog protocol

Every `flutter test` invocation the agent makes must be supervised, not fire-and-forget:

1. Run with **live progress** enabled (`<MOD>_BATCH_LIVE_PROGRESS=1`, `-r compact`, no `--quiet`).
2. Stream stdout/stderr to the chat **and** to a per-run log file under `/tmp/agent-runs/<mod>-<run-id>.log`.
3. Watch for the following stop tokens — if any appears, **kill the run immediately** (Ctrl-C / `kill %1`), classify the failure, and act:
   - `FAILED:`, `EXCEPTION:`, `LoadException`, `Error:`, `Aborted`, `SIGSEGV`, `SIGABRT`, `Could not find`, `assertion failed`, `cannot open shared object` → infrastructure / rule-violation / crash. Fix and restart the run from scratch.
   - `worst_miss=` followed by a value `≥ 2.00` cp during a `_BATCH_STOP_AT_DELTA` run → tactical blunder. Stop the batch, capture the FEN, hand off to the position-probe recipe, fix, restart the batch.
   - No progress line for 5 minutes during an audit batch → hung search. Kill, capture stack via `flutter test --reporter=expanded`, file a `kind: crash` task, restart.
4. After fixing, the agent **must** restart the failing test from a clean state (no `--start-from`, no resumed iterators). Partial passes do not count toward gating.
5. Repeat until the run finishes cleanly **and** all gates from "Hard rules → 4" pass. Only then commit.

## Standard run env (Linux)

Always prefix `flutter test` commands with:

```bash
CHESSRECAST_NATIVE_ENGINE_LIB=$PWD/build/native/linux/libchess_engine.so \
LD_LIBRARY_PATH=$PWD/build/native/linux:$PWD \
```

Run from `frontend/`. Build the native lib first if missing (`cmake --build build/native/linux` or VS Code task **`Frontend: Rebuild Native Engine`**).

### Per-mod env-var prefixes (real names, not placeholders)

| Mod              | Batch prefix              | Probe prefix              | Regression test                           |
|------------------|---------------------------|---------------------------|-------------------------------------------|
| heir             | `HEIR_BATCH_*`            | `HEIR_PROBE_*`            | `heir_engine_regression_test.dart`        |
| friendly_fire    | `FRIENDLY_FIRE_BATCH_*`   | `FRIENDLY_FIRE_PROBE_*`   | `friendly_fire_engine_regression_test.dart` |
| kings_battle     | `KB_BATCH_*`              | `KB_PROBE_*`              | `kings_battle_engine_regression_test.dart` |
| mercenary        | `MERC_BATCH_*`            | `MERC_PROBE_*`            | `mercenary_engine_regression_test.dart`   |
| save_the_queen   | `STQ_BATCH_*`             | `STQ_PROBE_*`             | `save_the_queen_engine_regression_test.dart` |
| succession       | `SUCCESSION_BATCH_*`      | `SUCCESSION_PROBE_*`      | `succession_engine_regression_test.dart`  |
| truce            | `TRUCE_BATCH_*`           | `TRUCE_PROBE_*`           | `truce_engine_regression_test.dart`       |

Common suffixes: `_BATCH_OPENINGS` (CSV of opening UCI sequences, one per game — use ≥50 lines for a real batch), `_BATCH_MAX_PLIES`, `_BATCH_REPORT_PATH`, `_BATCH_STOP_AT_DELTA` (cp), `_BATCH_LIVE_PROGRESS=1`. Probes additionally accept `_PROBE_FEN`, `_PROBE_DEPTH`, `_PROBE_TIME_MS`, `_PROBE_SKILL`, `_PROBE_CANDIDATES`, `_PROBE_REPORT_PATH`.

## Difficulty levels (target)

The engine exposes five tiers in `frontend/lib/engine/engine.dart` (`EngineLevel`):

| Tier      | depth | time_ms | skill | randomness | Target rating |
|-----------|-------|---------|-------|------------|---------------|
| `easy`    | 3     | 200     | 0     | high       | ~800 Elo      |
| `medium`  | 5     | 500     | 1     | med        | ~1400 Elo     |
| `hard`    | 7     | 1500    | 3     | low        | ~2000 Elo     |
| `expert`  | 10    | 3000    | 4     | none       | ~2400 Elo     |
| `maximum` | 64    | 5000    | 4     | none       | 2800+ Elo     |

`maximum` is the only tier targeted at 2800+ Elo opposition; lower tiers must remain weaker by construction (lower depth/skill, added move noise), not by being broken. Audit batches always run at the **reference** preset (depth 6 / 500 ms / skill 4) so KPIs are comparable across runs.

## Long-session ergonomics

Before kicking off `/improve-mod ALL` for an overnight run:

```bash
./scripts/power/agent-session-start.sh   # disables auto-suspend + auto-logout, screen blank 2h
```

When the session is over:

```bash
./scripts/power/agent-session-stop.sh    # restores: 3h logout, 5h suspend, 5min screen blank
```

See `scripts/power/README.md` for what those scripts touch.

## Queue entry schema (for the take-initiative rule)

When the agent files a new finding, it appends an entry like this to `agent/queue.yaml`:

```yaml
- id: <mod>-<phase>-<short-slug>
  mod: heir | friendly_fire | kings_battle | mercenary | save_the_queen | succession | truce | shared
  status: pending
  kind: blunder | rule_violation | crash | kpi_regression | strategy | endgame_conversion | opening_principle | shared_edit
  phase: opening | midgame | endgame | tactics | strategy
  severity: low | med | high | critical
  evidence:
    report: agent/reports/<mod>/<run-id>.txt
    line: <int>
    fen: "<FEN if applicable>"
    move: "<UCI if applicable>"
  blunder_threshold_cp: 200
  notes: "<one sentence>"
```
