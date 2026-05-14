# `agent/tracking.csv` — schema

> Single source of truth for **all agent-driven changes in this repository**: feature implementation, bug fixes, engine improvements, chores, refactors, and review activity. Written by any agent or slash command that makes a change. **Agents never call `git commit`; they append rows here and stage files. The human commits and pushes via `make git`.**

## File location & format

- Path: [agent/tracking.csv](tracking.csv).
- Encoding: UTF-8, LF line endings, no BOM.
- Format: RFC 4180 CSV. Header is the first line and is fixed (see below). Fields containing `,`, `"`, or LF MUST be double-quoted; literal `"` inside quoted fields is doubled (`""`).
- Append-only. Existing rows are immutable; corrections land as a *new* row with `action=amend` referencing the prior row's `run_id` + `phase` in `notes`.
- Use [xops/agent/tracking_append.sh](../xops/agent/tracking_append.sh) to append rows; it enforces column count, escaping, and atomic writes.

## Columns (in order)

| # | Column | Type | Required | Description |
|---|---|---|---|---|
| 1 | `ts_utc` | ISO-8601 UTC, `YYYY-MM-DDTHH:MM:SSZ` | yes | Wall clock at row write. |
| 2 | `run_id` | `[a-z0-9-]{6,40}` | yes | Stable id for the slash-command invocation. Reused across every row from the same run. |
| 3 | `command` | string | yes | The slash command or agent action that produced this row (e.g. `/implement-roadmap`, `/improve-mod`, `/triage-audit-report`, `/review-roadmap-phase`). Must start with `/` or be a valid identifier. |
| 4 | `model` | string | yes | The model the agent reports it is running under (e.g. `claude-opus-4.7`, `gpt-5`, `auto`). When unknown, write `unknown`. |
| 5 | `phase` | string | yes | Identifier for the work unit — a roadmap phase (`0`–`19`, `3.3`, `7.9.bullet-2`), a mod name (`heir`), a chore slug (`ops-rename`), or any short stable token. |
| 6 | `phase_title` | string | yes | Human-readable description of the work unit (≤ 80 chars); quoted. |
| 7 | `action` | enum | yes | `plan` \| `implement` \| `test` \| `review` \| `amend` \| `skip` \| `gate_fail` \| `drift_detected` \| `commit` \| `revert`. |
| 8 | `status` | enum | yes | `started` \| `in_progress` \| `passed` \| `failed` \| `reverted` \| `blocked` \| `completed`. |
| 9 | `commit_sha` | 7–40 hex chars or empty | no | Set on `action=commit` / `revert`; otherwise empty. |
| 10 | `files_changed` | integer ≥ 0 | yes | Files touched by this action (0 for `plan` / `review` rows). |
| 11 | `tests_added` | integer ≥ 0 | yes | Net new test functions / files in this action. |
| 12 | `tests_run` | integer ≥ 0 | yes | Total tests executed in this action. |
| 13 | `tests_passed` | integer ≥ 0 | yes | ≤ `tests_run`. |
| 14 | `tests_failed` | integer ≥ 0 | yes | `tests_run - tests_passed`. |
| 15 | `proof_test_paths` | semi-colon-separated paths | no | Workspace-relative paths of proof tests cited by the roadmap bullet(s) this row covers. Quote the cell. |
| 16 | `roadmap_box_state` | `[ ]` \| `[~]` \| `[x]` | yes | The state the agent set for the bullet **after** this action. Must match what the agent wrote into [docs/P2P_ROADMAP.md](../docs/P2P_ROADMAP.md). |
| 17 | `drift_kind` | enum | yes | `none` \| `spec_mismatch` \| `missing_test` \| `stale_box` \| `extra_change` \| `test_skipped` \| `assertion_weakened` \| `csv_tamper` \| `roadmap_edit_outside_p2p`. |
| 18 | `evidence_path` | string | no | Path to a generated report / log under `agent/reports/p2p/` or `/tmp/agent-runs/`. |
| 19 | `notes` | string ≤ 280 chars | no | One-sentence rationale; quoted. |
| 20 | `component` | string | no | Logical sub-system this action belongs to (e.g. `p2p/signaling`, `p2p/peer-connection`, `p2p/frontend`, `engine/heir`). See [agent/components.yaml](components.yaml) for the canonical list and current versions. |
| 21 | `component_version` | semver or empty | no | Version of the component from [agent/components.yaml](components.yaml) at the time of this action (e.g. `0.1.0`). Agents read the registry file to fill this in. |
| 22 | `commit_message` | string | no | **The exact conventional commit message for this action when `action=commit`.** `make git` reads this column directly — no derivation is needed. Leave empty for non-commit rows. Must follow `type(scope): description [run_id]` format. When empty on a `commit` row, `make git` falls back to deriving the message from `phase`, `phase_title`, and `run_id`. |

## Drift definitions

A drift row (`action=drift_detected`, non-`none` `drift_kind`) MUST be filed whenever the agent observes any of:

- **`spec_mismatch`** — a checkbox on `[x]` whose proof test does not exist or fails on a fresh checkout.
- **`missing_test`** — a behavior-change commit has no matching test (violates AGENTS.md §3).
- **`stale_box`** — code that fulfils a roadmap bullet exists on `main`, but the box is still `[ ]`.
- **`extra_change`** — files outside the per-area allow-list were modified by a prior run.
- **`test_skipped`** — a proof test was added with `@Skip` / `skip:` / `markTestSkipped(`.
- **`assertion_weakened`** — a test was edited to remove or relax `expect(`.
- **`csv_tamper`** — `agent/tracking.csv` has rows whose `tests_failed > 0` followed by `roadmap_box_state=[x]`, any non-monotone `ts_utc`, or any row not appended via [xops/agent/tracking_append.sh](../xops/agent/tracking_append.sh).
- **`edit_outside_scope`** — a commit changed files outside the task's allowed paths without a `shared_edit` queue entry.

## Invariants the appender script enforces

1. Header line is byte-for-byte the line above.
2. Every row has exactly **22 columns**.
3. `ts_utc` strictly ≥ the previous row's `ts_utc` (monotone non-decreasing).
4. `tests_passed + tests_failed == tests_run`.
5. `roadmap_box_state == "[x]"` **only** if `tests_failed == 0` AND (`action ∈ {commit, review}`).
6. `commit_sha` rules by action:
   - `action=commit` → `commit_sha` must be `pending` (written by agent before `make git` commits) **or** a 7–40 hex SHA (after `make git` has updated the row).
   - `action=revert` → `commit_sha` must be a 7–40 hex SHA (revert happens after an existing commit).
   - all other actions → `commit_sha` must be empty.
7. Atomic write via `flock` + temp-file rename so concurrent agent runs cannot interleave.
