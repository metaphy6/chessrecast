# P2P Operations Drill Log

Quarterly drill record for `docs/P2P_SIGNALING_RUNBOOK.md` runbook sections.  
Each row records: who ran the drill, what the outcome was, and any corrective actions opened.

> **Policy:** drills run once per quarter (Q1–Q4). If a quarter lapses with no drill for a critical section (§7, §9, §10), file a `kind: p2p_ops / severity: high` entry in `agent/queue.yaml`.

---

## Drill table

| Date | Runbook section | Operator | Outcome | Notes / corrective actions |
|---|---|---|---|---|
| — | §7 Standby region promotion | — | — | *No drills run yet — first drill due Q3 2025* |
| — | §8 KMS key rotation | — | — | *Annual cadence — due on first anniversary of key creation* |
| — | §9 litestream cold restore | — | — | *No drills run yet — first drill due Q3 2025* |
| — | §10 Scaling out coturn | — | — | *Run on demand before each traffic-spike event* |
| — | §11 TURN HMAC rotation | — | — | *Annual cadence — due on first anniversary of secret creation* |
| — | §12 Push-provider revocation | — | — | *Run only on confirmed breach; no breaches to date* |

---

## How to record a drill

1. Run the drill per the runbook section.
2. Append a row to the table above with:
   - **Date** — ISO 8601 (`YYYY-MM-DD`).
   - **Runbook section** — e.g. `§7 Standby region promotion`.
   - **Operator** — GitHub username or "solo-operator".
   - **Outcome** — `pass`, `partial`, or `fail`.
   - **Notes** — any corrective actions; link to `agent/queue.yaml` entry if one was filed.
3. Commit with message: `docs(p2p-ops): drill log YYYY-MM-DD §N <section name>`.

---

## Quarterly schedule

| Quarter | Target drills |
|---|---|
| Q1 | §9 litestream cold restore |
| Q2 | §7 Standby region promotion |
| Q3 | §9 litestream cold restore |
| Q4 | §7 Standby region promotion, §10 coturn scale-out |

KMS and TURN HMAC rotation follow their annual/biennial calendars independently.
