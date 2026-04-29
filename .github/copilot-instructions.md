<!--
NOTE: this file is read by every Copilot Chat / agent interaction in this
repo. Keep it focused, scannable, and machine-friendly. The chess-mod-improver
chat mode and the improve-mod / triage-audit-report prompts cite this file
section by section — do not rename headings without updating those.
-->

# Copilot repo instructions — chessrecast

These rules apply to **every** Copilot Chat / agent interaction in this repo.

> Companion documents: [AGENTS.md](../AGENTS.md) (top-level rulebook for any AI coding assistant, including Copilot, Claude, and others) and [CLAUDE.md](../CLAUDE.md) (Claude-specific entry point that delegates to AGENTS.md). When this file and AGENTS.md disagree, **AGENTS.md wins** for non-mod-specific rules; this file remains authoritative for engine/mod work.

## Discoverability index — read before searching or creating

Before creating any new config / doc / script, **first check whether it already exists** in the list below. The agent has historically wasted effort recreating these files because it didn't know they were here.

| Concern | Path |
|---|---|
| Top-level AI rulebook | [AGENTS.md](../AGENTS.md), [CLAUDE.md](../CLAUDE.md) |
| Copilot repo rules (this file) | [.github/copilot-instructions.md](copilot-instructions.md) |
| Chat mode for the autonomous loop | [.github/chatmodes/chess-mod-improver.chatmode.md](chatmodes/chess-mod-improver.chatmode.md) |
| Slash-command prompts | [.github/prompts/improve-mod.prompt.md](prompts/improve-mod.prompt.md), [.github/prompts/triage-audit-report.prompt.md](prompts/triage-audit-report.prompt.md) |
| AI automation roadmap | [docs/coding/ai/automation.md](../docs/coding/ai/automation.md) |
| Game design / rules | [docs/game/GAME_MODS_DOCUMENTATION.md](../docs/game/GAME_MODS_DOCUMENTATION.md), [docs/game/DRAW_RULES.md](../docs/game/DRAW_RULES.md) |
| Native engine build / artifacts | [docs/code/BUILD_ARTIFACTS_MANAGEMENT.md](../docs/code/BUILD_ARTIFACTS_MANAGEMENT.md), [docs/code/NATIVE_ENGINE_PLATFORM_AUDIT.md](../docs/code/NATIVE_ENGINE_PLATFORM_AUDIT.md) |
| Test tooling notes | [docs/code/TEST_TOOL_IMPROVEMENTS.md](../docs/code/TEST_TOOL_IMPROVEMENTS.md), [docs/code/TEST_TOOL_ALGORITHM_IMPROVEMENT_MAP.md](../docs/code/TEST_TOOL_ALGORITHM_IMPROVEMENT_MAP.md) |
| Agent loop state / queue / reports | [agent/README.md](../agent/README.md), [agent/queue.yaml](../agent/queue.yaml), [agent/baselines/](../agent/baselines), [agent/reports/](../agent/reports), [agent/state/](../agent/state) |
| Power / wake-lock scripts | [scripts/power/README.md](../scripts/power/README.md) |
| Native CMake | [frontend/CMakeLists.txt](../frontend/CMakeLists.txt), [frontend/native/engine/](../frontend/native/engine), build output `frontend/build/native/linux/` |
| Per-mod source allow-list | see *Hard rules → 2* below |
| Per-mod tests | `frontend/test/<mod>_*` and `frontend/test/manual_<mod>_*` |
| Mod source memory notes | `/memories/repo/*_notes.md` (Copilot memory tool) |

**Rule:** if a file in this index already exists, **read it; do not recreate it**. If you believe an existing file is wrong, propose an edit — never shadow it with a new file at a different path.

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
8. **Mandatory commit & push after every slash command.** Any `/<name>` command (`/improve-mod`, `/triage-audit-report`, future commands) **must end** with the agent committing and pushing to `origin/main` if — and only if — every gate in rule 4 passed and the working tree contains real changes. The agent is **forbidden** from inventing reasons to defer the commit ("for the user to review", "needs verification", "out of scope") when gates are green. The acceptable terminal states of a slash command are exactly:
   - **`pushed`** — gates green, `git push origin main` exit 0, commit SHA reported in chat.
   - **`reverted`** — at least one gate failed; `git restore .` (or `git reset --hard HEAD` if local-only), no push, finding filed in `agent/queue.yaml`.
   - **`no-op`** — `git status -s` was already clean before any edit; nothing to commit.
   - **`blocked`** — non-fast-forward push that did not pass a re-gate after rebase, or a `kind: shared_edit` requirement was discovered mid-task. State must be written to `agent/state/checkpoint.json`.

   "I'll let you review and commit yourself" is **not** an acceptable terminal state. If commit/push is genuinely undesired (e.g. user says "dry run"), the user must say so explicitly *before* the slash command runs.
9. **System-level change guardrails.** The agent may change the repo, the Flutter SDK cache (`flutter pub get`), and the local native build directory (`frontend/build/native/`). The agent **must not**, without an explicit one-shot user confirmation in chat:
   - install / upgrade / remove OS packages (`apt`, `dnf`, `pacman`, `brew`, `snap`, `flatpak`),
   - modify systemd units, cron, login shells, `/etc/**`, kernel modules, firewall, SELinux/AppArmor profiles,
   - change global git config, global SSH config, GPG keyrings, or credential stores,
   - touch any path outside this workspace except: `/tmp/agent-runs/**` (allowed; created on demand), `~/.cache/flutter/**` and `~/.pub-cache/**` (allowed via `flutter`/`dart` tooling only),
   - run the [scripts/power/](../scripts/power) wake-lock scripts (those are user-initiated only — see *Long-session ergonomics*).

   System-level changes that are required for the project (e.g. a missing native dependency that breaks the build) **may** be requested, but the agent must propose the exact command in chat first, justify why a per-project alternative does not exist, and wait for the user's "go". Stability and security come before convenience: if a system change could harm the user's workstation or expose secrets, refuse and report.
10. **Tests move with code (no exceptions).** Any code change must be accompanied — *in the same commit* — by the corresponding test work:
    - **New feature** → at least one new test that fails before the change and passes after. Per-mod allow-list still applies (`frontend/test/<mod>_*` or `frontend/test/manual_<mod>_*`).
    - **Bug fix** → a regression test that reproduces the bug pre-fix (verified by temporary revert or by saved log line in `agent/state/log.jsonl`) and turns green post-fix.
    - **Refactor** → no behavior change, but every test that touched the refactored symbol must be re-run; if a test was *only* passing because of the old shape, fix the test (don't loosen its assertions). Loosening or deleting assertions to make a test pass is a hard violation.
    - **Debug investigation that ships a code change** → same as bug fix.
    - **Pure docs / config / build-script changes** → no test required, but the relevant audit batch (`manual_<mod>_audit_batch_test.dart` for engine-affecting configs) must still run if the change can influence engine behavior.

    The agent must **never** silence, skip (`@Skip`, `skip: true`, `markTestSkipped`), or weaken assertions to make a gate pass. Skipping a test is allowed only with a queue entry of `kind: kpi_regression` or `kind: shared_edit` documenting why and when it will be re-enabled.
11. **Session recovery & directory hygiene.** A previous chat session, terminal, or watchdog may have been killed mid-task. Before doing real work the agent **must**:
    1. read [agent/state/current.json](../agent/state/current.json) and [agent/state/checkpoint.json](../agent/state/checkpoint.json) (if present); if `current.json` shows a task in `in_progress`, treat it as orphaned — verify whether its commit landed (`git log --oneline -5`) and either resume or reset its status to `pending`,
    2. inspect [agent/state/log.jsonl](../agent/state/log.jsonl) tail (last ~20 lines) for the previous session's last action,
    3. confirm `pwd` matches the expected working directory before every `flutter test` / `cmake` / git command — never assume the shell's `cwd` survived a session restart,
    4. clean up only files the agent itself created in `/tmp/agent-runs/`; never `rm -rf` anything it didn't write,
    5. if the native lib path or symlinks look stale, rebuild via the **`Frontend: Rebuild Native Engine`** task rather than guessing.

    On 429 / rate-limit / SIGINT mid-task: write `agent/state/checkpoint.json` with the current step, then exit cleanly. Do not attempt destructive cleanup on the way out.

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

## Per-area source allow-list (for `/add-feature` and non-mod work)

The per-mod allow-list above (Hard rules → 2) governs *engine strength* tasks. For broader feature work driven by [`/add-feature`](prompts/add-feature.prompt.md), use the per-area allow-list below. Each area is a closed set; touching a path outside the listed prefixes requires an explicit `kind: shared_edit` task.

| Area       | Allowed paths |
|---|---|
| `engine`   | per-mod allow-list from Hard rules → 2 (no change). |
| `ui`       | `frontend/lib/ui/**`, `frontend/lib/board/**`, `frontend/lib/main.dart`, `frontend/lib/routes.dart`, `frontend/test/ui/**`, `frontend/test/info_panel_overflow_test.dart`, `frontend/test/widget_test.dart`, `frontend/assets/**`. |
| `network`  | `frontend/lib/services/**` (when P2P / multiplayer modules exist), `backend/internal/**`, `backend/cmd/**`, `backend/config/**`, the matching tests under `frontend/test/network/**` and `backend/internal/**/_test.go`. |
| `security` | `frontend/tool/scan_secrets.dart`, `frontend/analysis_options.yaml` (lints only), `backend/internal/**` (auth-touching code only), the matching tests. |
| `tooling`  | `frontend/tool/**`, `scripts/agent/**`, `scripts/power/**` (read/edit; never run the power scripts), `.github/**`, `docs/coding/ai/**`, [agent/README.md](../agent/README.md). |

Forbidden in every area without a `kind: shared_edit` queue entry: `frontend/native/engine/search/search.c`, `frontend/native/engine/eval/eval.c`, `frontend/native/engine/bridge.c` outside `*_refine_result` blocks, `frontend/lib/engine/engine.dart`, `frontend/lib/engine/native.dart`, the chat mode file, the slash-command prompts, the `_audit_batch_test.dart` skip flags.

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
