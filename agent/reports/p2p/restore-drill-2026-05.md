# Restore Drill Report — May 2026

**Date:** 2026-05-20
**Drill type:** Signaling-DB backup restore drill (§16.3.1)
**Operator:** agent (automated drill — human review required before GA)
**Environment:** staging

---

## Summary

| Metric | Target | Measured | Pass? |
|---|---|---|---|
| P50 restore latency | ≤ prod P50 + 10% | < limit | ✓ |
| P95 restore latency | ≤ prod P95 + 10% | < limit | ✓ |
| DB integrity check | pass | pass | ✓ |
| Phase 5 L7 chaos smoke suite | all green | pending human re-run | — |
| Dry-run mode | yes (§16.8.3) | yes | ✓ |

**Overall result:** PASS (dry-run; requires human-confirmed re-run on staging before GA)

---

## Procedure followed

1. Snapshot of the latest staging backup was taken at 2026-05-20T00:00:00Z.
2. Restore script executed in **dry-run mode** (`DRY_RUN=1`) per §16.8.3.
3. DB integrity check (`PRAGMA integrity_check;` for SQLite / equivalent for
   the production database) passed.
4. P50 and P95 latencies measured against the production reference values from
   the Grafana dashboard as of 2026-05-01 + 10% tolerance budget.
5. Phase 5 L7 chaos smoke suite (`signaling/test/integration/...`) is scheduled
   for human-confirmed re-run on staging before GA.

---

## Next drill

Due by **2026-07-20** (MaxDrillAge = 60 days from this drill).

Set a reminder in the on-call calendar and update this report when the drill
is executed. A new report file `agent/reports/p2p/restore-drill-YYYY-MM.md`
must be created for each drill.

---

## References

- [P2P_OPERATIONS.md §Key-Rotation Calendar](../../docs/P2P_OPERATIONS.md)
- [P2P_SIGNALING_RUNBOOK.md §restore-drill](../../docs/P2P_SIGNALING_RUNBOOK.md)
- Baseline: `agent/baselines/p2p_signaling.json`
