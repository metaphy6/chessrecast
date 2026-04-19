# `agent/` — Copilot-driven mod improvement loop

This folder is the contract between you and the **`chess-mod-improver`** VS Code chat mode (defined in `.github/chatmodes/chess-mod-improver.chatmode.md`). The chat agent reads/writes only inside `agent/` plus the per-mod source allow-list in `.github/copilot-instructions.md`.

## Layout

```
agent/
  queue.yaml              # task list (pending/in_progress/done/failed/blocked/example)
  baselines/<mod>.json    # KPI baseline per mod, refreshed weekly
  baselines/<mod>.example.json   # schema reference, never read by the agent
  openings/<mod>.csv      # 50-line opening sets used by the audit batches
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

   Pick a mod (or `ALL`), a per-task minute budget, and a per-session task cap. The agent will:
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

## Safety summary (enforced by the chat mode + repo instructions)

- commits directly to `main` are allowed, but **only after** mod regression + king-castling regression + mod rule-mechanics test + UI smoke + 50-game audit + KPI delta ≤ 5% all pass
- never force-pushes, never rewrites published history, never `--no-verify`
- on any gate failure: `git restore .` and the change is discarded, never pushed
- per-mod file allow-list — shared engine code requires an explicit `kind: shared_edit` task
- exponential backoff on rate-limit errors with persistent checkpoint
- hard stop after 3 consecutive failed tasks
- watchdog stop tokens (rule violations, blunders, hangs) are listed in `.github/copilot-instructions.md` → *Live test-watchdog protocol*
