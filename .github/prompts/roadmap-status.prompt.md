---
mode: agent
description: Read-only status report on P2P roadmap progress. Counts ticked vs pending leaves per phase, flags drift candidates, lists rate-limit checkpoints and recent activity, and prints the next 5 leaves the implementer would attempt.
---

# /roadmap-status

Operate per the [`p2p-roadmap-implementer`](../chatmodes/p2p-roadmap-implementer.chatmode.md) chat mode. **Read-only:** must not edit code, must not run any test that mutates state, must not commit, must not push.

## Arguments

- `PHASE=<id>` — optional. Limit the report to a single phase (top-level, sub-section, or glob). Default: every phase.
- `RECENT=<int>` — optional. Number of most-recent CSV rows to surface. Default `15`.

## Steps

1. Run [xops/agent/session-bootstrap.sh](../../xops/agent/session-bootstrap.sh) (it is read-only); surface any unresolved `agent/state/last_failure.json` at the top of the report.
2. Read [docs/P2P_ROADMAP.md](../../docs/P2P_ROADMAP.md). For each phase in scope, count:
   - total `[ ]` / `[~]` / `[x]` leaves,
   - leaves whose bullet text contains `**Proof:**` vs. those that don't (`missing_proof_clause` candidates).
3. Read [agent/tracking.csv](../../agent/tracking.csv). Tabulate:
   - last `ts_utc`,
   - distinct `run_id`s in scope,
   - per-phase row counts split by `action`,
   - any `drift_detected` rows whose `notes` indicate the drift was not later amended,
   - any `commit` row whose `commit_sha` is **not** present on `origin/main` (`git merge-base --is-ancestor <sha> origin/main` returns false) — flag as **lost commit**.
4. Read [agent/state/checkpoint.json](../../agent/state/checkpoint.json) if present; report the leaf and step the next `/implement-roadmap` would resume from.
5. Compute the **next 5 leaves** an unconstrained `/implement-roadmap` (no INCLUDE/EXCLUDE) would attempt: in roadmap order, the first 5 leaves whose box is `[ ]`.
6. Print one CSV invariant check (chatmode §4.1 step 3): header byte-identical, all rows 19 columns, monotone `ts_utc`. Pass / fail per check.

## Output format

A markdown report with these sections, in this order:

```
## P2P Roadmap Status — <UTC timestamp>

### Recovery
- Unresolved last_failure.json: <yes/no, with path>
- Active checkpoint: <leaf or none>

### Per-phase progress
| Phase | [ ] | [~] | [x] | total | %done | last activity |

### Drift candidates
- <count> rows of action=drift_detected without a follow-up amend
- <count> bullets [x] without a Proof: clause
- <count> commits on docs/P2P_ROADMAP.md without a matching CSV row
- <count> CSV commit_sha values not on origin/main

### CSV invariants
- header: pass/fail
- 19-column rows: pass/fail
- monotone ts_utc: pass/fail

### Next 5 leaves
1. <phase> — <title>
2. …

### Last <RECENT> CSV rows
<a small markdown table>
```

## Terminal state

Always `no-op` (read-only). Do not commit. Do not push. Append exactly **one** CSV row at the end via the appender:

```
action=review status=completed phase=<scope> drift_kind=none notes="status report only, run_id=<id>"
```

so the report itself is auditable.
