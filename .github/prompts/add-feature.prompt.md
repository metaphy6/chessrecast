---
mode: chess-mod-improver
description: Add a single small feature with an acceptance test that fails first. Commit and push when gates pass. Forbidden from drive-by refactors.
---

# Add feature — area=`${input:area:engine|ui|network|security|tooling}` summary=`${input:summary}`

Operate per [AGENTS.md](../../AGENTS.md), [.github/copilot-instructions.md](../copilot-instructions.md), and the per-area allow-list (see Copilot instructions → *Per-area source allow-list*).

## Pre-flight

1. Run [xops/agent/session-bootstrap.sh](../../xops/agent/session-bootstrap.sh).
2. `git switch main && git pull --ff-only`. Stop if dirty.
3. Confirm the area allow-list — only those paths may be edited in this command. If the change escapes the allow-list, stop and file a `kind: shared_edit` queue entry instead.

## Plan (post in chat, 5 lines max)

- Restate the feature in one sentence.
- List the exact files you will create or edit.
- Describe the acceptance test you will write (one paragraph). It must fail before the change.
- List the gates you will run (regression, UI smoke, audit batch if engine area).
- State the expected commit message.

## Implement

1. **Write the failing test first.** Run it once to confirm it fails for the right reason. Save the failure log line to `agent/state/log.jsonl` (event `feature_test_red`).
2. Implement the minimal change to make the test green.
3. Do **not** add unrelated formatting changes, comments, or refactors. Per [AGENTS.md](../../AGENTS.md) §3, only edit code that is directly necessary.

## Gate

Run, in order, aborting on the first failure:

1. `flutter analyze` — clean.
2. The new acceptance test — green.
3. The matching regression test for the area:
   - **engine** → `<mod>_engine_regression_test.dart` for every mod whose code was touched, plus `king_castling_policy_regression_test.dart`, plus a fresh ≥50-game audit batch for the touched mod with KPI delta ≤ 5%.
   - **ui** → `info_panel_overflow_test.dart`, `widget_test.dart`, plus any per-screen test under `test/ui/`.
   - **network** → P2P / multiplayer integration test (when the suite exists).
   - **security** → `dart run tool/scan_secrets.dart`, plus the matching unit test.
   - **tooling** → run the tool you changed; ensure it produces the expected output on a known fixture.

## Terminal state (mandatory)

- **`pushed`** — gates green, working tree dirty: commit with message `feat(<area>): ${input:summary} [<run-id>]`, `git push origin main`, report SHA. **No exceptions** — see [AGENTS.md](../../AGENTS.md) §2.
- **`reverted`** — any gate failed: `git restore .`, file a queue entry, no push.
- **`blocked`** — change requires shared-engine edits or a system-level change; write `agent/state/checkpoint.json`, file a queue entry, stop.
- **`no-op`** — never expected for this command (the user asked to add a feature). If you find yourself here, you misread the request — clarify.

## Forbidden in this command

- editing more than one area's allow-list,
- silencing or weakening tests to make the gate pass,
- skipping the failing-test-first step ("I'll add the test after"),
- pushing without running the full gate,
- ending with "I'll let you commit this yourself".
