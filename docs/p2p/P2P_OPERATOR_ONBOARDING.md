# P2P Operator Onboarding

**Date:** 2026-05-20
**Scope:** Signaling server and Chess Recast P2P infrastructure — production and staging.

> This runbook brings a new operator from zero access to full on-call readiness.
> Required by §16.7.3 of the P2P Roadmap. Revisit this document at every major
> release and re-confirm accuracy no less than every 6 months.

---

## Prerequisites

Before starting onboarding, ensure the new operator has:

- [ ] GitHub organisation membership (`chessrecast` org, role: Member)
- [ ] Two-factor authentication enabled on GitHub
- [ ] GPG key registered with the org for commit signing
- [ ] VPN / bastion access approved by security

---

## 1 KMS access

The signaling server uses a KMS for the following keys (see
[P2P_OPERATIONS.md §Key-Rotation Calendar](P2P_OPERATIONS.md)):

| Key alias | Cadence | Used for |
|---|---|---|
| `turn-hmac-key` | 90 days | TURN credential HMAC |
| `push-token-key` | 30 days | Push-wake token signing |
| `signed-config-key` | 1 year | Signed-config Ed25519 key |
| `kms-master-key` | 2 years | KMS envelope key |

**Onboarding steps:**

1. Request IAM role `ops-kms-read` from `#infra-access` (Slack or GitHub issue).
2. Verify access: `aws kms list-keys --profile chessrecast-ops` (or GCP equivalent).
3. For rotation duties, request `ops-kms-rotate` — requires manager approval and a
   co-signer (two-person rule for all key rotations).

---

## 2 Signing-key access

- The `signed-config-key` (Ed25519) is stored as a KMS CMK; the public key is
  baked into each client release.
- Signing new config payloads requires `ops-kms-rotate` role + second operator
  confirmation (§16.8.5 — rotation events must be signed by the predecessor key).

---

## 3 Dashboard access

| Dashboard | URL | Auth |
|---|---|---|
| Signaling latency / error rate | Internal Grafana → `P2P Signaling` board | SSO |
| CVE queue | `https://<internal>/ops/cve` | SSO |
| Key-rotation calendar | `https://<internal>/ops/key-rotation` | SSO |
| Dead-man switch status | `https://<internal>/ops/dms` | SSO |

Request access in `#infra-access`. Grafana editor access requires tech-lead approval.

---

## 4 Status-page admin

The public status page is at `https://status.chessrecast.app`.

- Write access is granted via the status-page provider (Statuspage / BetterUptime —
  TBD before GA).
- On-call operators must have write access to post incident updates.
- Policy: initial incident post within 15 min of detection; hourly updates during
  active incidents; final resolved notice within 2 h of service restoration.
- Reference: [P2P_OPERATIONS.md §16.6.2](P2P_OPERATIONS.md).

---

## 5 Runbook locations

| Situation | Runbook |
|---|---|
| Kill-switch engagement | [P2P_SIGNALING_RUNBOOK.md §kill-switch](P2P_SIGNALING_RUNBOOK.md) |
| Key rotation | [P2P_OPERATIONS.md §Key-Rotation Calendar](P2P_OPERATIONS.md) |
| CVE triage & forced update | [P2P_OPERATIONS.md §CVE Severity Playbook](P2P_OPERATIONS.md) |
| Restore drill | [P2P_SIGNALING_RUNBOOK.md §restore-drill](P2P_SIGNALING_RUNBOOK.md) |
| On-call schedule | [P2P_OPERATIONS.md §On-call Schedule](P2P_OPERATIONS.md) |
| Post-mortem | [P2P_INCIDENT_RESPONSE.md](P2P_INCIDENT_RESPONSE.md) |
| NAT traversal failures | [P2P_NAT_MATRIX.md](P2P_NAT_MATRIX.md) |
| Android OEM issues | [P2P_ANDROID_OEM_MATRIX.md](P2P_ANDROID_OEM_MATRIX.md) |

---

## 6 Recovery from common queue entries

The `bots/queue.yaml` file tracks known issues. Below are the runbook procedures
for P2P-related entries an operator may encounter.

### `kind: p2p_kpi_regression`

1. Open the flagged report under `bots/reports/p2p/`.
2. Identify the failing SLA bucket.
3. Check the signaling Grafana board for latency spikes or error rate increases.
4. If the regression is a signaling server issue, follow
   [P2P_SIGNALING_RUNBOOK.md §latency-spike](P2P_SIGNALING_RUNBOOK.md).
5. If the regression is a client-side ICE failure rate, check
   [P2P_NAT_MATRIX.md §edge-cases](P2P_NAT_MATRIX.md).
6. Open a post-mortem using [P2P_INCIDENT_RESPONSE.md](P2P_INCIDENT_RESPONSE.md).

### `kind: p2p_security`

1. Follow the CVE playbook in [P2P_OPERATIONS.md §CVE Severity Playbook](P2P_OPERATIONS.md).
2. If a forced update is required, run the forced-update drill procedure in
   [P2P_SIGNALING_RUNBOOK.md §forced-update-drill](P2P_SIGNALING_RUNBOOK.md).
3. File a post-mortem if any users were affected.

### `kind: p2p_crash`

1. Retrieve the crash log from the signaling server (`journalctl -u signaling` or
   cloud logging).
2. File a bug in the GitHub issue tracker with severity `P1` or `P2`.
3. If the crash caused data loss, follow the data-breach procedure in
   [P2P_GDPR_CHECKLIST.md](P2P_GDPR_CHECKLIST.md).

### `kind: p2p_key_rotation_overdue`

1. Confirm the key rotation calendar in [P2P_OPERATIONS.md §Key-Rotation Calendar](P2P_OPERATIONS.md).
2. Execute the rotation procedure immediately (two-person rule applies).
3. Record the rotation event in the audit log.
4. Resolve the queue entry.

---

## 7 On-call readiness checklist

Before your first on-call shift:

- [ ] All dashboard links above load successfully with your SSO credentials
- [ ] You can post a test update to the status page
- [ ] You have received and acknowledged a test PagerDuty (or equivalent) alert
- [ ] You have read the kill-switch runbook and can engage it unassisted
- [ ] You have read the CVE forced-update procedure and can execute it unassisted
- [ ] You have a second operator (buddy) identified for key-rotation tasks
- [ ] You have the `#p2p-oncall` Slack channel notifications enabled

---

## 8 Offboarding

When an operator leaves the on-call rotation:

1. Revoke `ops-kms-read` and `ops-kms-rotate` IAM roles.
2. Revoke status-page write access.
3. Remove from the on-call schedule in [P2P_OPERATIONS.md §On-call Schedule](P2P_OPERATIONS.md).
4. Rotate any shared credentials the operator had direct access to.
5. Update this document's last-reviewed date.

---

*Last reviewed: 2026-05-20*
