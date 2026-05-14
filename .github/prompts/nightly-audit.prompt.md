---
mode: chess-mod-improver
description: Run a one-mod-per-night audit batch, diff KPIs against the baseline, file findings on regression. Never edits code.
---

# Nightly audit — `${input:mod:heir|friendly_fire|kings_battle|mercenary|save_the_queen|succession|truce|AUTO}`

Operate per [.github/copilot-instructions.md](../copilot-instructions.md) and [AGENTS.md](../../AGENTS.md). This command is **read-only for code** — its job is observation, not fixing.

## Pre-flight

1. Run [xops/agent/session-bootstrap.sh](../../xops/agent/session-bootstrap.sh) and post the summary in chat.
2. If `${input:mod}` is `AUTO`, pick the mod whose latest report under `agent/reports/<mod>/` is **oldest** (round-robin). Tie-break alphabetically.
3. Confirm `git status -s` is clean. If dirty, **stop** and report — never push someone else's WIP.

## Batch

Run the standard 50-game audit batch from the *Run recipes* section of the chat-mode file (no `_BATCH_STOP_AT_DELTA` — we want a complete run for KPI extraction, not early termination). Use `LIVE_PROGRESS=1` and the watchdog tokens.

Save the report to `agent/reports/<mod>/nightly-<run-id>.txt`.

## KPI diff

Run [frontend/tool/kpi_dashboard.dart](../../frontend/tool/kpi_dashboard.dart) with `--mod <mod>`, post the markdown table in chat.

For each metric flagged `warn` or `bad` (per the dashboard's status legend):

- **bad** (>10% regression) → file a queue entry, severity `high`, kind `kpi_regression`, evidence pointing at `nightly-<run-id>.txt`.
- **warn** (5..10%) → file a queue entry, severity `med`, same kind.
- **ok** → no entry.

Also file entries for any:
- `ruleViolations > 0` → severity `critical`, kind `rule_violation`,
- `engineCrashes > 0` → severity `critical`, kind `crash`,
- new blunders in the report with `worst_miss ≥ 2.00` cp → severity `high`, kind `blunder`.

## Terminal state

This command does **not** edit code. Acceptable terminal states:

- **`pushed`** — you appended new queue entries to [agent/queue.yaml](../../agent/queue.yaml); commit + push the queue change with message `auto(nightly): file findings for <mod> [<run-id>]`. Per [AGENTS.md](../../AGENTS.md) §2 this is mandatory when there is a non-empty diff.
- **`no-op`** — every KPI was `ok` and no new blunders/rule-violations/crashes; nothing to commit. Say so in one line.

You may **not** edit any source file in this command. If a finding looks urgent, file it and let `/improve-mod <mod>` pick it up next.
