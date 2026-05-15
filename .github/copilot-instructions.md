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
- `xops/agent/` — agent tooling scripts (safe-run, session-bootstrap, run-test-with-retry, tracking_append).
- `xops/makefile/` — Python ops scripts invoked by the root `Makefile`.
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

1. **Agents never commit or push.** Make changes, append a row to `agent/tracking.csv` via [xops/agent/tracking_append.sh](../xops/agent/tracking_append.sh) with `action=commit, commit_sha=pending`, stage all files with `git add`, then stop. The user commits and pushes via `make git`. Forbidden under all circumstances: `git commit`, `git push`, `git push --force`, `git push --force-with-lease`, `git reset --hard` on already-pushed commits, `--no-verify`, rewriting published history, deleting `main`. On any gate failure the agent must `git restore .` (unstage and discard) and never stage the failing change.
2. **Per-mod isolation.** When fixing a single mod, only edit:
   - `frontend/lib/mods/<mod>.dart` (and any `frontend/lib/mods/<mod>/**` subtree),
   - `frontend/lib/engine/<mod>_*.dart` (if present),
   - mod-scoped overrides inside `frontend/native/engine/bridge.c` (the `*_refine_result` blocks),
   - mod-scoped C files: `frontend/native/engine/eval/eval_<mod>.c`, `frontend/native/engine/search/heuristics_<mod>.c`,
   - the mod's own tests under `frontend/test/manual_<mod>_*` and `frontend/test/<mod>_*`.

   Touching shared search/eval code (`frontend/native/engine/search/search.c`, `eval/eval.c`, `bridge.c` outside the `*_refine_result` blocks, `frontend/lib/engine/engine.dart`, `frontend/lib/engine/native.dart`) requires an explicit `kind: shared_edit` task in the queue with severity ≥ high and a written rationale. The native opening-book module (`frontend/native/engine/book/**` plus its `bridge.c` hook) is also shared; changes there require a `kind: opening_book` task (see *Opening corpus & native-book charter* below).
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
8. **Mandatory tracking entry + stage after every slash command.** Any `/<name>` command **must end** by appending a row to `agent/tracking.csv` with `action=commit, commit_sha=pending` and `commit_message` set to the exact conventional commit message, then running `git add -A`. The acceptable terminal states of a slash command are exactly:
   - **`staged`** — gates green, tracking row appended, `git add -A` clean, staged file list reported in chat. **Never `git commit` or `git push` directly.**
   - **`reverted`** — at least one gate failed; `git restore .` (or `git reset --hard HEAD` if local-only), no staging, finding filed in `agent/queue.yaml`.
   - **`no-op`** — `git status -s` was already clean before any edit; nothing to stage.
   - **`blocked`** — rebase needed, or a `kind: shared_edit` requirement was discovered mid-task. State must be written to `agent/state/checkpoint.json`.

   "I'll let you review and commit yourself" is **not** an acceptable terminal state. If gates are green and the diff is real, **you stage** (append tracking row + `git add`). The user commits via `make git`.

   **Commit message format:** every `commit_message` field **must** follow [Conventional Commits](https://www.conventionalcommits.org/) — `type(scope): description [<run-id>]`. Valid types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `chore`, `ci`, `build`, `revert`. Engine-mod fixes use `fix(<mod>)` (e.g. `fix(heir): fix castling heuristic [abc123]`), performance gains use `perf(<mod>)`. P2P work uses `feat(p2p-<phase>)` or `chore(p2p-<phase>)`. Tooling uses `chore(<area>)`. **Never** use `auto` or `p2p` as the commit type — those are non-standard and rejected by `make git`. `make git` reads this column and commits with it verbatim.
9. **System-level change guardrails.** The agent may change the repo, the Flutter SDK cache (`flutter pub get`), and the local native build directory (`frontend/build/native/`). The agent **must not**, without an explicit one-shot user confirmation in chat:
   - install / upgrade / remove OS packages (`apt`, `dnf`, `pacman`, `brew`, `snap`, `flatpak`),
   - modify systemd units, cron, login shells, `/etc/**`, kernel modules, firewall, SELinux/AppArmor profiles,
   - change global git config, global SSH config, GPG keyrings, or credential stores,
   - touch any path outside this workspace except: `/tmp/agent-runs/**` (allowed; created on demand), `~/.cache/flutter/**` and `~/.pub-cache/**` (allowed via `flutter`/`dart` tooling only).

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

    **Non-zero exit recovery (see [AGENTS.md](../AGENTS.md) §5a).** Wrap risky / long commands with [xops/agent/safe-run.sh](../xops/agent/safe-run.sh) so that exit code, full output, and command/env are persisted to `/tmp/agent-runs/<run-id>.{cmd,log,exit}` and a breadcrumb to `agent/state/last_failure.json` even if the chat session or terminal dies. On any non-zero exit (or unresolved `last_failure.json` at session start) the order is fixed: **read the .log → diagnose root cause → fix it → resume the interrupted task → mark `resolved: true` (or delete the marker)**. Never retry the same failing command without first reading its log; never silence a non-zero exit with `|| true` / `set +e` / `> /dev/null` to make a gate appear green.

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

| Mod              | Batch prefix              | Probe prefix              | Regression test                              |
|------------------|---------------------------|---------------------------|----------------------------------------------|
| heir             | `HEIR_BATCH_*`            | `HEIR_PROBE_*`            | `heir_engine_regression_test.dart`           |
| friendly_fire    | `FRIENDLY_FIRE_BATCH_*`   | `FRIENDLY_FIRE_PROBE_*`   | `friendly_fire_engine_regression_test.dart`  |
| kings_battle     | `KB_BATCH_*`              | `KB_PROBE_*`              | `kings_battle_engine_regression_test.dart`   |
| mercenary        | `MERC_BATCH_*`            | `MERC_PROBE_*`            | `mercenary_engine_regression_test.dart`      |
| save_the_queen   | `STQ_BATCH_*`             | `STQ_PROBE_*`             | `save_the_queen_engine_regression_test.dart` |
| succession       | `SUCCESSION_BATCH_*`      | `SUCCESSION_PROBE_*`      | `succession_engine_regression_test.dart`     |
| truce            | `TRUCE_BATCH_*`           | `TRUCE_PROBE_*`           | `truce_engine_regression_test.dart`          |

Common suffixes: `_BATCH_OPENINGS` (CSV of opening UCI sequences, one per game — use ≥50 lines for a real batch), `_BATCH_MAX_PLIES`, `_BATCH_REPORT_PATH`, `_BATCH_STOP_AT_DELTA` (cp), `_BATCH_LIVE_PROGRESS=1`. Probes additionally accept `_PROBE_FEN`, `_PROBE_DEPTH`, `_PROBE_TIME_MS`, `_PROBE_SKILL`, `_PROBE_CANDIDATES`, `_PROBE_REPORT_PATH`.

## Per-area source allow-list (for `/add-feature` and non-mod work)

The per-mod allow-list above (Hard rules → 2) governs *engine strength* tasks. For broader feature work driven by [`/add-feature`](prompts/add-feature.prompt.md), use the per-area allow-list below. Each area is a closed set; touching a path outside the listed prefixes requires an explicit `kind: shared_edit` task.

| Area       | Allowed paths |
|---|---|
| `engine`   | per-mod allow-list from Hard rules → 2 (no change). |
| `ui`       | `frontend/lib/ui/**`, `frontend/lib/board/**`, `frontend/lib/main.dart`, `frontend/lib/routes.dart`, `frontend/test/ui/**`, `frontend/test/info_panel_overflow_test.dart`, `frontend/test/widget_test.dart`, `frontend/assets/**`. |
| `network`  | `frontend/lib/services/**` (when P2P / multiplayer modules exist), `backend/internal/**`, `backend/cmd/**`, `backend/config/**`, the matching tests under `frontend/test/network/**` and `backend/internal/**/_test.go`. |
| `security` | `frontend/tool/scan_secrets.dart`, `frontend/analysis_options.yaml` (lints only), `backend/internal/**` (auth-touching code only), the matching tests. |
| `tooling`  | `frontend/tool/**`, `xops/agent/**`, `xops/makefile/**`, `.github/**`, `docs/coding/ai/**`, [agent/README.md](../agent/README.md). |

Forbidden in every area without a `kind: shared_edit` queue entry: `frontend/native/engine/search/search.c`, `frontend/native/engine/eval/eval.c`, `frontend/native/engine/bridge.c` outside `*_refine_result` blocks, `frontend/lib/engine/engine.dart`, `frontend/lib/engine/native.dart`, the chat mode file, the slash-command prompts, the `_audit_batch_test.dart` skip flags.

### P2P Roadmap Phase 0 — Special exception (legacy cleanup, no shared_edit required)

Phase 0 of [docs/P2P_ROADMAP.md](../docs/P2P_ROADMAP.md) is a one-time cleanup of the legacy backend and local-state migration. Per the `/implement-roadmap` chat mode (§2), Phase 0 work explicitly **does not require** `kind: shared_edit` queue entries for the following paths and operations:

- `backend/**` (legacy Go backend files; to be moved/archived per Phase 0.3)
- `archive/**` (destination directory for legacy code)
- Root-level `docker-compose.yml` (to be removed or replaced per Phase 0.3)
- `docker-compose.signaling.yml` (new signaling server compose file)
- Root `README.md` (to add P2P preview notice and remove legacy backend instructions per Phase 0.3)
- `docs/P2P_*.md` (new P2P documentation branches per roadmap leaves)
- `frontend/lib/services/saved_games_local.dart` and related local-storage decoupling per Phase 0.2
- Schema migrations and retention tests under `frontend/test/services/**` per Phase 0.6

This exception applies **only** to Phase 0.1–0.6 boxes in the roadmap. All other cross-cutting changes must respect the per-area allow-list and file `kind: shared_edit` entries when venturing outside their zone.

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

## Opening corpus & native-book charter

The opening files under `agent/openings/` are now **dual-purpose**: they are still the fixed gate slice for KPI batches, *and* they are the source of truth for the upcoming native opening-book layer in C. This shifts them from "static test fixtures" to a learning signal that feeds the engine. The rules below apply to every change in `agent/openings/**`, every new task that touches opening play, and every patch that adds or modifies the book layer.

### Corpus-quality targets (per gate file `agent/openings/<mod>.csv`)

| Property | Target | Rationale |
|---|---|---|
| Lines | exactly **50** | KPI comparability with all prior baselines. |
| Avg depth | **6–8 plies** | Cover the post-development inflection where mod rules start to bite. |
| Lines ≤ 2 plies | **< 20%** of file | Shallow lines under-test mod-specific motifs. |
| Cross-mod overlap (5 classical-style mods: heir, friendly_fire, mercenary, save_the_queen, succession) | **< 50%** of lines shared between any pair | Force per-mod stress motifs into the gate, not just generic openings. |
| Mod-specific stress lines | **≥ 30%** of file | Especially Kings Battle (Phase-1→Phase-2 transition) and Mercenary (pawn-as-minor-piece development). |
| Duplicates | **0** | Verified via `sort -u | wc -l` == `wc -l`. |

These targets are gate-side; corpus changes are still subject to *Hard rules → 4* (the new corpus must regenerate every affected baseline before any patch lands).

### Native opening-book layer (planned location)

The book lives under `frontend/native/engine/book/`:

- `frontend/native/engine/book/opening_book.h` — `book_lookup(zobrist_key, mod, skill, /*out*/ best_move, weights[])` API.
- `frontend/native/engine/book/opening_book.c` — per-mod tables compiled from `agent/openings/<mod>.csv` + `<mod>_discovery.csv` weighted by audit feedback.
- `frontend/native/engine/CMakeLists.txt` — add the new TU.
- `frontend/native/engine/bridge.c` — single hook **before** `search_think` in the root call. The hook is per-mod and respects `EngineLevel`:
  - `easy`: weighted-random over the top-N book moves (high temperature),
  - `medium`: weighted-random over the top-3 (low temperature),
  - `hard` / `expert` / `maximum`: deterministic strongest-weighted move.
- Out-of-book: book weights become **move-order priors** — fed into the existing move-order phase, never as a forcing constraint, and integrated with `frontend/native/engine/bridge_king_discipline.c` (do not bypass king-discipline checks).

The book module is **shared engine code** for the purposes of the per-mod allow-list: any change to `book/opening_book.{c,h}`, the CMake hook, or the bridge entry-point requires a `kind: opening_book` queue task (see schema below). Per-mod book *content* (entries derived from `agent/openings/<mod>.csv`) does not require a `shared_edit`, but does require a fresh ≥50-game gate for that mod.

### KPI → opening-weight feedback loop

After every successful audit batch the agent is expected to feed measurable signal back into the corpus:

1. For each opening line in `agent/openings/<mod>.csv`, compute the per-line worst-miss and blunder count from the report.
2. Down-weight (or move to `<mod>_discovery.csv`) lines that are *too easy* — zero blunders across the last 3 batches and worst-miss < 0.5 cp — they are no longer informative.
3. Up-weight (or *promote* to `<mod>_stress.csv`) lines that **expose** weak engine behavior — worst-miss ≥ 2.00 cp, recurring across batches, or rule-violation triggers.
4. Record every promotion / demotion as a `kind: corpus_curation` queue entry citing the source report. The entry is the audit trail; the CSV diff is the action.
5. Once `book/opening_book.{c,h}` exists, the same weights drive book selection — promotion implicitly raises a line's book weight, demotion lowers it.

This loop is intentionally manual until the `corpus-curation-tool` task (see queue) ships a `frontend/tool/curate_openings.dart` that does steps 1–3 mechanically.

### Discovery & stress slices (recap)

| File | Lines | Role |
|---|---|---|
| `agent/openings/<mod>.csv` | exactly 50 | **Gate.** KPI baseline source. Curated, deduped, depth-balanced. |
| `agent/openings/<mod>_discovery.csv` | ~100 | **Discovery.** Broader role/structure coverage; rotated freely. |
| `agent/openings/<mod>_stress.csv` | ~30 | **Stress.** Adversarial seeds + verified-fixed regression openings. |

The native book draws from gate + discovery (weighted); stress is reserved for targeted hunts and is *not* fed into the book.

## Queue entry schema (for the take-initiative rule)

When the agent files a new finding, it appends an entry like this to `agent/queue.yaml`:

```yaml
- id: <mod>-<phase>-<short-slug>
  mod: heir | friendly_fire | kings_battle | mercenary | save_the_queen | succession | truce | shared
  status: pending
  kind: blunder | rule_violation | crash | kpi_regression | strategy | endgame_conversion | opening_principle | shared_edit | opening_book | corpus_curation
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

`kind` notes:
- `opening_book` — touches `frontend/native/engine/book/**` or the bridge book hook. Treated as `shared_edit` for allow-list purposes; a written rationale is required.
- `corpus_curation` — touches only `agent/openings/**`. Must cite a source report and list the lines added / removed / re-weighted; baselines for every affected mod must be refreshed in the same commit.
