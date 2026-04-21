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

## Budgets

- Per-task budget: stop the task and revert if it exceeds **${input:max_minutes:45}** minutes wall-clock.
- Per-session budget: stop the whole loop after **${input:max_tasks:6}** tasks completed (pass or fail).
- If a single audit batch alone exceeds the per-task budget, file a `kind: kpi_regression` task noting the slowdown and continue.

## Initiative

Before claiming the first task, post a one-line plan listing the task ids you intend to attempt this session, in order. As soon as a triage step surfaces a new finding, append it to `agent/queue.yaml` per the schema in `.github/copilot-instructions.md` → *Queue entry schema*, even if it is outside the current mod's scope.

## Stop conditions

Halt the loop when: queue is empty for the requested mod, file `agent/STOP` exists, three consecutive tasks ended in `failed`, or the user types `stop`.
