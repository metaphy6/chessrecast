# `agent/` — Copilot-driven mod improvement loop

This folder is the contract between you and the **`chess-mod-improver`** VS Code chat mode (defined in `.github/chatmodes/chess-mod-improver.chatmode.md`). The chat agent reads/writes only inside `agent/` plus the per-mod source allow-list in `.github/copilot-instructions.md`.

## Layout

```
agent/
  queue.yaml              # task list (pending/in_progress/done/failed/blocked/example)
  baselines/<mod>.json    # KPI baseline per mod, refreshed weekly
  baselines/<mod>.example.json   # schema reference, never read by the agent
  openings/<mod>.csv             # FIXED gate slice (50 lines) — used by every audit batch
  openings/<mod>_discovery.csv   # ROTATING discovery slice (~100 lines) — refresh periodically
  openings/<mod>_stress.csv      # STRESS slice (~30 lines) — adversarial / failure-prone seeds
  reports/<mod>/*.txt     # raw audit-batch outputs
  state/
    current.json          # the task currently in flight
    log.jsonl             # append-only history (baseline / claim / watchdog / gate / commit / done)
    usage.json            # rolling tool-call counter for rate-limit guard
    checkpoint.json       # written on rate-limit / crash for safe resume
  STOP                    # create this file to ask the agent to halt cleanly
```

## How to run a session

1. Open this repo in VS Code with the GitHub Copilot Chat extension installed and signed in (Pro or Business plan; Agent mode enabled in settings).
2. **Keep the workstation awake:**

   ```bash
   ./scripts/power/agent-session-start.sh   # disables auto-suspend + auto-logout, screen blank 2h
   ```

   Restore defaults when you are done:

   ```bash
   ./scripts/power/agent-session-stop.sh    # 3h logout, 5h suspend, 5min screen blank
   ```

3. Open Copilot Chat, switch to **Agent** mode, then select the **chess-mod-improver** chat mode from the mode dropdown.
4. Run the slash prompt:

   ```
   /improve-mod
   ```

   Pick a mod (or `ALL`) and a per-session task cap. The agent will:
   - read `agent/queue.yaml`,
   - process pending tasks one at a time,
   - run audits (≥50 games), gate, commit directly to `main` on pass, or revert on regression,
   - **watchdog every test run** — kill it the moment the first error / blunder token shows up, fix, restart from a clean state,
   - back off on rate limits, checkpoint on stop,
   - file new findings as fresh queue entries on its own (take-initiative directive).

5. To stop cleanly: `touch agent/STOP` from a terminal, or type `stop` in the chat. The agent will finish its current gate step, write a checkpoint, and exit.

## Why this template stops short of "fully unattended overnight"

VS Code Copilot Chat sessions are interactive: they do not persist across window reloads, they have per-session tool-call caps, and they require you to start them. With the power scripts above and a single `/improve-mod ALL` kick the agent will run as long as Copilot Chat allows.

If you want truly unattended multi-night operation, switch to the GitHub Copilot **coding agent** (cloud, issue-assignment based) and have a local cron seed issues from this same `queue.yaml`.

## Editing the queue by hand

Append YAML entries matching the schema in `.github/copilot-instructions.md` → *Queue entry schema*. The `triage-audit-report` prompt (`/triage-audit-report`) generates schema-compliant entries from any report file without touching code.

## Opening slices — gate / discovery / stress

Each mod has **three** opening files in `agent/openings/`. They serve different roles:

| File | Size | Purpose | Lifecycle |
|---|---|---|---|
| `<mod>.csv` | exactly 50 lines | **Fixed gate slice.** Consumed by every `manual_<mod>_audit_batch_test.dart` gate and by all KPI/baseline computations. Stable on purpose so KPI deltas are comparable across runs. | Treat as a baseline artifact: only revise via an explicit `kind: shared_edit` queue entry, and regenerate every mod's baseline immediately after any change. |
| `<mod>_discovery.csv` | ~100 lines | **Rotating discovery slice.** Broader structural / role / mod-rule coverage. Used for non-gate exploration runs (e.g. `/improve-mod` may pull a 50-line random sample from here for an extra "discovery batch" alongside the gate batch). | Periodically refresh content; re-shuffle / re-curate without invalidating gate baselines. |
| `<mod>_stress.csv` | ~30 lines | **Stress slice.** Adversarial seeds (sharp gambits, premature king walks, mod-specific failure modes already observed). Use as the opening source for targeted hunts after a regression / new finding. | Append to it whenever a fresh blunder / rule violation is found; keep verified-fixed lines in for permanent regression coverage. |

The harness still consumes whatever CSV path is fed via `<MOD>_BATCH_OPENINGS=$(cat ...)`. Slices are *file-naming convention* + agent discipline, not a code-level mechanism. Gate runs **must** continue to use the first 50 lines of `<mod>.csv` as required by `.github/copilot-instructions.md` → *Hard rules → 4*.

## Safety summary (enforced by the chat mode + repo instructions)

- commits directly to `main` are allowed, but **only after** mod regression + king-castling regression + mod rule-mechanics test + UI smoke + 50-game audit + KPI delta ≤ 5% all pass
- never force-pushes, never rewrites published history, never `--no-verify`
- on any gate failure: `git restore .` and the change is discarded, never pushed
- per-mod file allow-list — shared engine code requires an explicit `kind: shared_edit` task
- exponential backoff on rate-limit errors with persistent checkpoint
- hard stop after 3 consecutive failed tasks
- watchdog stop tokens (rule violations, blunders, hangs) are listed in `.github/copilot-instructions.md` → *Live test-watchdog protocol*
