---
mode: agent
description: Weekly Flutter dependency + secrets audit. Read-only for code; writes only reports and queue entries.
---

# /dependency-audit — weekly supply-chain sweep (frontend only)

> Scope: **frontend Dart / Flutter packages only.** The Go backend is intentionally out of scope and slated for replacement by a P2P stack. Do not run `go list -m -u all` or touch `backend/`.

## What this command does

1. From `frontend/`, run `dart run tool/dependency_audit.dart --write-queue`. This:
   - executes `flutter pub outdated --json` and parses the result,
   - writes a markdown report to `agent/reports/_security/<run-id>.md`,
   - appends a `kind: shared_edit / severity: med` queue entry for every dependency that is either (a) more than one major version behind, or (b) on the security-sensitive allow-list inside the tool.
2. Run `dart run tool/scan_secrets.dart HEAD~50...HEAD` to look for accidentally-committed secrets in the last ~50 commits. Any finding becomes a `kind: shared_edit / severity: high` queue entry with the report path.
3. Run `dart run tool/scan_runtime_telemetry.dart` to fold any new crash / illegal-move evidence from `/tmp/agent-runs/*.log` into `agent/reports/_runtime/`.
4. Commit only the new report files and the modified `agent/queue.yaml`. **Do not** modify any source code or `pubspec.yaml` in this command — the queue entries are the work item, and the actual bumps happen via `/improve-mod` or `/add-feature` follow-ups.

## Mandatory terminal state

Same contract as every other slash command (see [AGENTS.md](../../AGENTS.md) §2). Acceptable terminal states:

- `pushed` — queue entries and/or reports were added; commit + `git push origin main`; report SHA.
- `no-op` — clean audit, nothing to commit.
- `reverted` — the audit itself crashed (parse error, missing tool); revert any partial state.
- `blocked` — non-fast-forward push that did not survive a re-gate after rebase.

## Forbidden in this command

- Editing any `*.dart` source under `frontend/lib/`, any `*.c` / `*.h` under `frontend/native/`, any test under `frontend/test/`.
- Editing `frontend/pubspec.yaml` or `frontend/pubspec.lock`.
- Touching `backend/` for any reason.
- Running `flutter pub upgrade` (only `flutter pub outdated`, which is read-only).

## Cron / cadence guidance

This command is designed to be run weekly (e.g. Monday morning by the user, or by the cloud agent once that exists). Manual invocation between weekly runs is fine — duplicate findings are deduplicated by the queue triage step.
