---
mode: chess-mod-improver
description: Kick off the autonomous improvement loop for a single mod (or the full queue). Streams every test, stops on the first error, fixes it, restarts.
---

# Improve mod: ${input:mod:heir|friendly_fire|kings_battle|mercenary|save_the_queen|succession|truce|ALL}

Operate per the `chess-mod-improver` chat mode and `.github/copilot-instructions.md`. In particular, honour the *Game-quality charter*, the *Take-initiative directive*, and the *Live test-watchdog protocol*.

## Pre-flight (one line each, before any task work)

1. Confirm `frontend/build/native/linux/libchess_engine.so` exists and is newer than the C sources; rebuild via the **`Frontend: Rebuild Native Engine`** VS Code task if not.
2. Confirm `git status -s` is clean and `main` is up to date (`git switch main && git pull --ff-only`). If dirty, stop and report.
3. Remind the user once: "If this is an overnight run, please run `./scripts/power/agent-session-start.sh` now and `./scripts/power/agent-session-stop.sh` when you're done."
4. If `agent/baselines/${input:mod}.json` (or any of the seven for `ALL`) is missing or older than 7 days, schedule a baseline-refresh batch as the first task before triaging the queue.

## Task selection

If `${input:mod}` is `ALL`, walk every `pending` task in `agent/queue.yaml` in order, prioritising by `severity` (critical > high > med > low) and then by `phase` (rule_violation > endgame > opening > tactics > strategy > kpi_regression).

Otherwise, only process tasks whose `mod` field equals `${input:mod}`.

## Empty-queue auto-discovery (do not stop, discover work)

If — after the pre-flight — there is **no `pending` task in `agent/queue.yaml`** matching `${input:mod}` (or, for `ALL`, no `pending` task at all), do **not** stop. Instead, run a discovery audit and seed the queue, then continue with the loop:

1. Pick the discovery target(s):
   - For a single mod, target = `${input:mod}`.
   - For `ALL`, target = every mod whose `agent/baselines/<mod>.json` is missing or older than 7 days; if all baselines are fresh, round-robin one mod (oldest baseline first).
2. For each target, run a fresh **50-game** discovery batch using the standard env recipe (see *Standard run env* and the per-mod prefixes in [.github/copilot-instructions.md](../copilot-instructions.md)):
   - openings: the first 50 lines of `agent/openings/<mod>.csv` (fall back to `<MOD>_BATCH_OPENINGS` if the CSV is missing — request user input only as a last resort),
   - reference preset: depth 6 / 500 ms / skill 4,
   - `<MOD>_BATCH_LIVE_PROGRESS=1`, `<MOD>_BATCH_REPORT_PATH=agent/reports/<mod>/discovery-<run-id>.txt`,
   - **no early-stop** (`<MOD>_BATCH_STOP_AT_DELTA` unset or 0) — we want to see *all* issues, not just the first one.
   - tee output to `/tmp/agent-runs/<mod>-discovery-<run-id>.log`.
3. After the batch completes, scan the report and the tee'd log for findings using the standard rules from [AGENTS.md](../../AGENTS.md) §9b:
   - any move with worst-miss ≥ 2.00 cp → one `kind: blunder` queue entry per distinct FEN (collapse duplicates),
   - any rule violation → `kind: rule_violation / severity: high`,
   - any crash / abort / segfault → `kind: crash / severity: critical`,
   - any KPI in `agent/baselines/<mod>.json` worse by >5% → `kind: kpi_regression` with severity per the baseline's threshold field,
   - opening-principle issues (early king moves, lost castling rights, queen sorties before ply 12) → `kind: opening_principle / phase: opening`,
   - endgame-conversion misses (won technical positions drawn / lost) → `kind: endgame_conversion / phase: endgame`.
4. Append every finding to `agent/queue.yaml` using the *Queue entry schema* in [.github/copilot-instructions.md](../copilot-instructions.md) — `evidence.report` must point at the discovery report file and `evidence.line` at the offending line. If discovery yields zero findings (genuinely clean batch), refresh `agent/baselines/<mod>.json` from the run, log a `discovery_clean` event to `agent/state/log.jsonl`, and exit as `no-op` (still commit the refreshed baseline + report file).
5. Commit the queue + report + (optional) refreshed baseline as a single `discovery` commit, push it, then **continue the loop with the newly-filed tasks** — do not exit just because the queue was empty when the command started. The discovery commit itself counts toward the per-session task budget as one task.

## Budgets

- Per-session budget: stop the whole loop after **${input:max_tasks:6}** tasks completed (pass or fail).

## Initiative

Before claiming the first task, post a one-line plan listing the task ids you intend to attempt this session, in order. As soon as a triage step surfaces a new finding, append it to `agent/queue.yaml` per the schema in `.github/copilot-instructions.md` → *Queue entry schema*, even if it is outside the current mod's scope.

## Stop conditions

Halt the loop when: file `agent/STOP` exists, three consecutive tasks ended in `failed`, the per-session task budget is exhausted, or the user types `stop`. **An empty queue is no longer a halt condition** — the *Empty-queue auto-discovery* step above will seed new tasks and continue. Halt only if discovery itself yields zero findings *and* there are still no `pending` tasks (genuine `no-op`).

## Mandatory terminal state — commit and push, no exceptions

This slash command **must** end with the agent in one of the four terminal states defined in [.github/copilot-instructions.md](../copilot-instructions.md) → *Hard rules → 8* (`pushed` / `reverted` / `no-op` / `blocked`) and equivalently in [AGENTS.md](../../AGENTS.md) → *§2 Mandatory commit & push*.

Concretely, the **last action** of this command, if at least one task ended with `result: pass` and the working tree is dirty, is:

```bash
git add -A
git commit -m "auto(<mod>): <one-line summary> [<run-id>]"
git switch main && git pull --ff-only   # rebase if needed; re-run the gate
git push origin main                    # normal push, never --force
```

Then report the commit SHA in chat. The agent is **forbidden** from ending with phrases like "I'll let you review and commit yourself", "this seems out of scope to push", "I'll leave this uncommitted for now". If the user wanted a dry run they would have said so before invoking the slash command.

If gates failed, the terminal action is `git restore .` (or `git reset --hard HEAD` if local-only) plus a fresh queue entry; never push the failing change.

If the diff was empty (`git status -s` clean), say so in one line and exit; that is a `no-op`, not a problem.
