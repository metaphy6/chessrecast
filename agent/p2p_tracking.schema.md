# `agent/p2p_tracking.csv` — schema

> Single source of truth for **P2P-roadmap implementation progress, drift, and review activity**. Written **only** by agents executing the `/implement-roadmap`, `/review-roadmap-phase`, and `/roadmap-status` slash commands. **No human edits, no other slash commands, no other code paths write to this file.** Tampering = treat as drift and revert per [AGENTS.md](../AGENTS.md) §3.

## File location & format

- Path: [agent/p2p_tracking.csv](p2p_tracking.csv).
- Encoding: UTF-8, LF line endings, no BOM.
- Format: RFC 4180 CSV. Header is the first line and is fixed (see below). Fields containing `,`, `"`, or LF MUST be double-quoted; literal `"` inside quoted fields is doubled (`""`).
- Append-only. Existing rows are immutable; corrections land as a *new* row with `action=amend` referencing the prior row's `run_id` + `phase` in `notes`.
- Use [xops/agent/p2p_tracking_append.sh](../xops/agent/p2p_tracking_append.sh) to append rows; it enforces column count, escaping, and atomic writes.

## Columns (in order)

| # | Column | Type | Required | Description |
|---|---|---|---|---|
| 1 | `ts_utc` | ISO-8601 UTC, `YYYY-MM-DDTHH:MM:SSZ` | yes | Wall clock at row write. |
| 2 | `run_id` | `[a-z0-9-]{6,40}` | yes | Stable id for the slash-command invocation. Reused across every row from the same run. |
| 3 | `command` | enum | yes | `/implement-roadmap` \| `/review-roadmap-phase` \| `/roadmap-status`. |
| 4 | `model` | string | yes | The model the agent reports it is running under (e.g. `claude-opus-4.7`, `gpt-5`, `auto`). When unknown, write `unknown`. |
| 5 | `phase` | string | yes | Phase identifier — `0`, `3`, `3.3`, `7.9`, or `3.3.bullet-2` for sub-bullet granularity. Top-level phases are `0`–`19`. |
| 6 | `phase_title` | string | yes | First ≤ 80 chars of the roadmap heading; quoted. |
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

## Drift definitions

A drift row (`action=drift_detected`, non-`none` `drift_kind`) MUST be filed whenever the agent observes any of:

- **`spec_mismatch`** — a checkbox on `[x]` whose proof test does not exist or fails on a fresh checkout.
- **`missing_test`** — a checkbox on `[x]` or `[~]` for a bullet whose `**Proof:**` clause references a path that doesn't exist in `frontend/test/p2p/**` or `signaling/internal/**`.
- **`stale_box`** — code that fulfils a bullet exists on `main`, but the box is still `[ ]`.
- **`extra_change`** — files outside the per-area allow-list (see chatmode) were modified by a prior P2P run.
- **`test_skipped`** — a P2P proof test was added with `@Skip` / `skip:` / `markTestSkipped(`.
- **`assertion_weakened`** — a P2P proof test was edited to remove or relax `expect(`.
- **`csv_tamper`** — `agent/p2p_tracking.csv` has rows whose `tests_failed > 0` followed by `roadmap_box_state=[x]`, or any non-monotone `ts_utc`, or any row not appended via [xops/agent/p2p_tracking_append.sh](../xops/agent/p2p_tracking_append.sh) (verifiable by the per-row trailing newline + RFC 4180 quoting check the script enforces).
- **`roadmap_edit_outside_p2p`** — a recent commit changed [docs/P2P_ROADMAP.md](../docs/P2P_ROADMAP.md) without a matching `commit` row in this CSV.

The agent **must** auto-amend drift on detection (re-run the gate, re-toggle the box, file a `revert` row if a commit must be backed out).

## Invariants the appender script enforces

1. Header line is byte-for-byte the line above.
2. Every row has exactly 19 columns.
3. `ts_utc` strictly ≥ the previous row's `ts_utc` (monotone non-decreasing).
4. `tests_passed + tests_failed == tests_run`.
5. `roadmap_box_state == "[x]"` **only** if `tests_failed == 0` AND (`action ∈ {commit, review}`).
6. `commit_sha` non-empty **iff** `action ∈ {commit, revert}`.
7. Atomic write via `flock` + temp-file rename so concurrent agent runs cannot interleave.
