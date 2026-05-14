---
mode: p2p-roadmap-implementer
description: Walk leaves of docs/P2P_ROADMAP.md selected by INCLUDE/EXCLUDE filters; for each, write a failing proof test, implement until it passes, self-review, tick the box, log to agent/p2p_tracking.csv, commit & push. Resumable on rate limits.
---

# /implement-roadmap

Operate per the [`p2p-roadmap-implementer`](../chatmodes/p2p-roadmap-implementer.chatmode.md) chat mode and [AGENTS.md](../../AGENTS.md). Do not deviate.

## Arguments

The user invokes this command with two **optional** arguments in `KEY=VALUE` form, separated by spaces. They are parsed as comma-separated dot-notation phase tokens (see chatmode §3 for the grammar):

- `INCLUDE=<csv>` — phases / sub-phases / globs to attempt. Default: every top-level phase `0,1,…,19`.
- `EXCLUDE=<csv>` — phases / sub-phases / globs to skip. EXCLUDE always wins on overlap.
- `MAX=<int>` — per-session leaf budget. Default `8`. Use `MAX=999` for unattended overnight runs.
- `DRY_RUN=1` — produce the plan + CSV `plan` rows, but do not edit any code, run any test, commit, or push. Useful before kicking off a long run.

User examples (verbatim from the request):

```
/implement-roadmap INCLUDE=3 EXCLUDE=3.3
/implement-roadmap INCLUDE=0,1 EXCLUDE=1.6,1.10
/implement-roadmap INCLUDE=7.* EXCLUDE=7.10 MAX=20
/implement-roadmap                              # all phases, default budget
/implement-roadmap DRY_RUN=1 INCLUDE=4
```

If the user passes any unrecognised argument, **stop immediately** and ask for clarification — do not guess.

## Pre-flight (one line each, before any leaf work)

1. Run [xops/agent/session-bootstrap.sh](../../xops/agent/session-bootstrap.sh). Triage any unresolved `agent/state/last_failure.json` first.
2. `git switch main && git pull --ff-only`. Stop if dirty.
3. Verify [agent/p2p_tracking.csv](../../agent/p2p_tracking.csv) header is intact (chatmode §4.1 step 3). On mismatch → `drift_kind=csv_tamper`, exit `blocked`.
4. Verify [xops/agent/p2p_tracking_append.sh](../../xops/agent/p2p_tracking_append.sh) is executable (`chmod +x` if not — this is in-repo, allowed).
5. Resolve INCLUDE/EXCLUDE into a flat ordered leaf list. Post the count + first 5 leaves to chat. If the count is `0`, exit `no-op`.
6. Generate one `run_id` (`p2p-$(date -u +%Y%m%d-%H%M%S)-$RANDOM`, matching the chat-mode convention). Reuse for every CSV row this session.
7. Detect the active model name from the conversation context. If unknown, write `auto`. Reuse for every row.
8. Append one `action=plan, status=started` row that lists the resolved leaves in `notes` (truncate to 280 chars; if more, write the first 10 + `… (+N more)`).

## Loop

For each leaf, follow chatmode §4.2 → §4.7 verbatim. **Do not skip §4.4** (failing test first) — that is the user's "no false positives" guarantee.

After each leaf finishes, decrement the `MAX` counter and check stop conditions (chatmode §4.10).

After the **last leaf of a top-level phase** is committed, run [/review-roadmap-phase](review-roadmap-phase.prompt.md) inline for that phase id and append its findings as the next chunk of CSV rows + a follow-up commit if amendments are needed.

## Phase completeness

Per the user's requirement *"be sure that a given phase is fully complete without concerns of rate limits or such (we can gracefully wait if rate limits are reached anyway)"*: a phase is **only** considered complete when

1. every non-EXCLUDED leaf in that phase is `[x]` in the roadmap,
2. every cited proof test is green on a fresh run,
3. the phase-review row has `action=review, status=passed`,
4. the corresponding `commit` row's `commit_sha` exists on `origin/main`.

If a rate-limit interruption blocks step 1, the loop exits **`blocked`**, writes `agent/state/checkpoint.json`, and the next invocation of this command (with the same INCLUDE/EXCLUDE args, or a re-issue of the same command) **resumes** at the recorded leaf — never re-implementing already-`[x]` leaves.

## Drift handling

While processing a leaf, if the agent observes any drift kind from the schema (`spec_mismatch`, `missing_test`, `stale_box`, `extra_change`, `test_skipped`, `assertion_weakened`, `csv_tamper`, `roadmap_edit_outside_p2p`):

1. Append a `action=drift_detected, status=in_progress, drift_kind=<k>, evidence_path=<…>` row.
2. Apply the prescribed fix (chatmode §4.2, §4.6 step 2/3): re-run the gate, revert the offending edit, or amend the box state.
3. Append a `action=amend, status=passed` (or `failed`) row when the fix lands.

The user's exact requirement: *"misimplementations and drifts so take actions to amend them accordingly"* — this is non-optional.

## Mandatory terminal state

Per chatmode §6, end in exactly one of `staged` / `reverted` / `no-op` / `blocked`. Report:

- `run_id`,
- selected vs. completed leaf count,
- staged file list and pending CSV `run_id` (push and commit are deferred to `make git`),
- any `blocked` leaf with its checkpoint reason.

Forbidden terminal phrases: "I'll let you review and commit yourself", "this seems out of scope", "you might want to verify". If gates were green and code changed, **you stage (`make git` commits from CSV).**

## DRY_RUN behaviour

If `DRY_RUN=1`:

- Resolve INCLUDE/EXCLUDE into the leaf list and post it.
- Append a single `action=plan, status=started, notes="DRY_RUN"` row.
- Do **not** edit code, run tests, commit, or push.
- Exit `no-op`.
