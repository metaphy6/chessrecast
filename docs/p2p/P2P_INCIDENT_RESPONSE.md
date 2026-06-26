# P2P Incident Response — Post-Mortem Template

> **Required by §16.6.1 of the P2P Roadmap.** Every production incident (KPI
> breach, kill-switch engagement, security advisory acknowledged) must produce a
> completed post-mortem within **7 days** using this template. A public-facing
> summary must appear on the status page within **14 days** for any incident
> affecting > 1% of beta MAU.

---

## Incident header

| Field | Value |
|---|---|
| **Incident ID** | `INC-YYYY-NN` |
| **Date / time (UTC)** | YYYY-MM-DD HH:MM |
| **Duration** | X h Y min |
| **Severity** | P1 (Critical) / P2 (High) / P3 (Medium) / P4 (Low) |
| **Type** | KPI breach / kill-switch / security advisory / other |
| **% of beta MAU affected** | N% |
| **Post-mortem author** | @github-handle |
| **Post-mortem due date** | YYYY-MM-DD (detection date + 7 d) |
| **Status page summary due** | YYYY-MM-DD (detection date + 14 d, if MAU > 1%) |

---

## 1 Timeline

List events in chronological order.

| Time (UTC) | Event |
|---|---|
| HH:MM | Incident detected (how: alert / user report / dashboard) |
| HH:MM | On-call acknowledged |
| HH:MM | Initial diagnosis |
| HH:MM | Mitigation applied |
| HH:MM | Service restored |
| HH:MM | Post-mortem opened |

**Detection lag:** `(on-call acknowledge time) – (incident start time)` = X min

---

## 2 Impact

- **Users affected:** N (N% of active sessions)
- **Features degraded:** P2P matchmaking / game session / spectator / push-wake / other
- **Data affected:** yes / no (if yes, see §7 below)
- **SLA breached:** yes / no (cite which SLA from [P2P_OPERATIONS.md §CVE Severity Playbook](P2P_OPERATIONS.md))

---

## 3 Root cause (5-whys minimum)

**Why #1:** (observed symptom)
**Why #2:** (underlying cause of #1)
**Why #3:** (underlying cause of #2)
**Why #4:** (underlying cause of #3)
**Why #5:** (root cause)

*Do not stop before reaching a systemic cause (process gap, missing test, missing
alert, documentation gap).*

---

## 4 Resolution

Describe the mitigation and the permanent fix:

- **Immediate mitigation:** (what was done to stop the bleeding)
- **Permanent fix:** (PR / commit that prevents recurrence)
- **Verification:** (how the fix was confirmed)

---

## 5 Action items

| # | Action | Owner | Due date | Status |
|---|---|---|---|---|
| 1 | Add regression test (see §6 below) | @handle | YYYY-MM-DD | open |
| 2 | … | | | |

---

## 6 Prevention test

> §16.6.1 requires that every post-mortem adds at least one prevention test.

- **Test file:** `signaling/internal/<area>/<slug>_regression_test.go` or
  `frontend/test/p2p/<area>/<slug>_regression_test.dart`
- **Test name:** `TestRegressionINC_YYYY_NN_<description>`
- **What it verifies:** (one sentence — the condition that would have caught
  the incident before it reached production)
- **PR / commit:** (link)

---

## 7 Data / privacy impact (fill when applicable)

- **Personal data involved:** yes / no
- **GDPR notification required:** yes / no (threshold: likely risk to rights)
- **Affected users notified:** yes / no / N/A
- **DSAR audit trail updated:** yes / no / N/A

See [P2P_GDPR_CHECKLIST.md](P2P_GDPR_CHECKLIST.md) for the full GDPR runbook.

---

## 8 Public-facing status-page summary (required when MAU > 1%)

> Due within 14 days of incident detection. Write this section last.

```
[YYYY-MM-DD] Incident summary — Chess Recast P2P

We experienced [X-min / X-hour] degradation of [feature] affecting approximately
N% of users between HH:MM and HH:MM UTC on YYYY-MM-DD.

Root cause: [one-paragraph plain-language explanation]

What we fixed: [one paragraph]

We apologise for the disruption.
```

---

## Revision history

| Version | Date | Change |
|---|---|---|
| 1.0 | YYYY-MM-DD | Initial post-mortem |
| 1.1 | YYYY-MM-DD | Added prevention test link |
