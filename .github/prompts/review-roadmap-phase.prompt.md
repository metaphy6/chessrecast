---
mode: p2p-roadmap-implementer
description: Re-audit one P2P roadmap phase that has been ticked. Re-runs every cited proof test, scans for drift (weakened tests, missing files, stale box, out-of-scope edits, CSV tamper), auto-amends what it can, files queue entries for what it can't, commits & pushes the fixes.
---

# /review-roadmap-phase

Operate per the [`p2p-roadmap-implementer`](../chatmodes/p2p-roadmap-implementer.chatmode.md) chat mode and [AGENTS.md](../../AGENTS.md).

## Arguments

- `PHASE=<id>` — required. A single phase token: top-level (`3`), sub-section (`3.3`), or glob (`7.*`). Comma lists are **not** allowed here — review one slice at a time.
- `STRICT=1` — optional. When set, any drift downgrades the affected box from `[x]` back to `[~]` and files a queue entry, even if the auto-amend succeeded. Use during release-candidate gates.

Examples:

```
/review-roadmap-phase PHASE=3
/review-roadmap-phase PHASE=3.3
/review-roadmap-phase PHASE=7.* STRICT=1
```

## Pre-flight

1. Run [xops/agent/session-bootstrap.sh](../../xops/agent/session-bootstrap.sh).
2. `git switch main && git pull --ff-only`. Stop if dirty.
3. Verify CSV header (chatmode §4.1 step 3).
4. Resolve `PHASE` to its leaf list (same grammar as chatmode §3). For each leaf, also resolve its `**Proof:**` clause to a concrete test path (or note `missing_test` drift if absent).
5. Generate one `run_id`. Append `action=plan, status=started, command=/review-roadmap-phase, notes="<N> leaves"`.

## Audit steps (apply each to every leaf, collect findings — do not abort early)

For each leaf in the resolved list:

### A. Box-state vs. CSV consistency

- Look up the most recent CSV row for this leaf. If the latest row's `roadmap_box_state` disagrees with the actual roadmap box → `drift_kind=stale_box` (or `csv_tamper`). Auto-fix: re-run proof test (step C), then write whichever value is correct based on the test result.

### B. Proof-test existence

- If the bullet's `**Proof:**` cites a path that does not exist on disk → `drift_kind=missing_test`.
- If the bullet has no `**Proof:**` clause but is `[x]` → `drift_kind=spec_mismatch`. Auto-fix: write the test (per chatmode §4.4), then proceed. If the implementation does not pass the new test, **revert the box to `[~]`** and file `kind: missing_proof` in `agent/queue.yaml`.

### C. Proof-test green

- Run the cited test via [xops/agent/safe-run.sh](../../xops/agent/safe-run.sh) on a clean tree. Red → `drift_kind=spec_mismatch`. Auto-fix: re-implement (loop back to chatmode §4.5) up to 2 attempts; on persistent failure, revert the box to `[~]` and file `kind: regression_p2p`.

### D. Test honesty

- `git log --since="30 days ago" --diff-filter=AM --name-only -- frontend/test/p2p/** signaling/internal/**` → grep each new/modified test for `@Skip`, `skip:`, `markTestSkipped(`, `t.Skip(`, `expect(.*, isNotNull)` (and the Go equivalents). Hits → `drift_kind=test_skipped` / `assertion_weakened`. Auto-fix: revert the offending diff (`git revert <sha>`), re-run the gate, push. If the revert breaks an unrelated leaf, file `kind: shared_edit` and exit `blocked`.

### E. Allow-list audit

- For every commit on `main` since the leaf's commit row was written, run `git show --stat <sha> -- ':!docs/**'` and confirm every changed path falls inside chatmode §2's allow-list. Out-of-scope path → `drift_kind=extra_change`. Auto-fix is **not** automatic here — file `kind: shared_edit` and exit `blocked` if the commit is already on `origin/main`.

### F. CSV invariants

- Re-run the schema invariants from [agent/p2p_tracking.schema.md](../../agent/p2p_tracking.schema.md) §"Invariants the appender script enforces" against the file. Any violation → `drift_kind=csv_tamper`, exit `blocked`. Do **not** edit the CSV by hand to "fix" tampering — write a new `action=drift_detected` row via the appender.

### G. Roadmap-edit audit

- `git log --since="30 days ago" -- docs/P2P_ROADMAP.md` → for each commit, confirm there is a matching `action=commit` row in the CSV with the same SHA. Mismatch → `drift_kind=roadmap_edit_outside_p2p`. Auto-fix is to file `kind: roadmap_edit` and exit `blocked` (do not silently revert someone else's manual edit).

## Per-leaf row pattern

For each leaf, append at minimum:

1. One `action=test, status=passed|failed, tests_run=N, tests_passed=K, tests_failed=N-K, proof_test_paths="…"` row.
2. Zero or more `action=drift_detected, drift_kind=<k>, evidence_path="…"` rows.
3. Zero or more `action=amend, status=passed|failed, files_changed=N` rows.
4. One terminal `action=review, status=passed|failed|completed, roadmap_box_state=<final>` row.

## Commit

If any auto-amend produced changes:

1. `git add -A`
2. `git commit -m "p2p(<phase>): review fixes [<run-id>]"`
3. Append `action=commit, status=completed, commit_sha=<short>`.

**Do not push** — commits accumulate for `make git`.

If no amend was needed and every leaf's `action=review` is `passed` → exit `no-op`.

## Mandatory terminal state

Per [AGENTS.md](../../AGENTS.md) §2: `committed` / `reverted` / `no-op` / `blocked`. Report:

- phase id,
- count of leaves audited / drift kinds found / auto-fixed / queued,
- pushed SHAs,
- any `[x]→[~]` downgrades.

If invoked at the end of an `/implement-roadmap` phase (chatmode §4.9), the calling loop folds this command's findings into its own progress and continues; this prompt does **not** exit the parent loop.
