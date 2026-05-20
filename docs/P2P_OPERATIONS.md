# P2P Operations Runbook

This document covers the per-CVE severity playbook, forced-update procedure,
and the key-rotation calendar required by §3.10 and §3.11 of the P2P Roadmap.

---

## §1 Ownership declaration (§8.8 / roadmap leaf 8.8.b1)

### Current operators

| Role | Identity | Contact method | Access scope |
|---|---|---|---|
| Primary operator | Project maintainer | GitHub @-mention on `main` or issue tracker | All: region promotion, KMS rotation, kill-switch, standby failover |

**Bus-factor acknowledgement:** this is a solo-maintained deployment. Bus factor = 1.

**Degraded-mode default (bus factor = 1):** if the on-call operator cannot acknowledge a `P2P_HEALTH_CRITICAL` or `KEY_ROTATION_OVERDUE` alert within **60 minutes**, the alerting system automatically:
1. Calls the signed-config endpoint to set `kEnableP2P=false`.
2. Surfaces a maintenance banner to all connected clients.
3. Opens an incident issue in the tracker.

This "fail closed" policy ensures that a sleeping or unavailable operator never leaves a brittle service running unattended. See §8.8 roadmap for the auto-kill-switch proof test.

### Promotion authorisation matrix

| Operation | Who can initiate | Who must verify | Runbook section |
|---|---|---|---|
| Standby region promotion | Primary operator | — (solo) | §6 of P2P_SIGNALING_RUNBOOK.md |
| KMS key rotation | Primary operator | — (solo) | Key-rotation calendar below |
| Kill-switch toggle (`kEnableP2P`) | Primary operator or auto-failover | — | §7 of P2P_SIGNALING_RUNBOOK.md |
| TURN HMAC rotation | Primary operator | — | §8 of P2P_SIGNALING_RUNBOOK.md |
| litestream cold restore | Primary operator | — | §9 of P2P_SIGNALING_RUNBOOK.md |

---

## CVE Severity Playbook (§3.10)

When the CVE-watcher surfaces a new advisory, the on-call operator follows this
playbook based on the CVSS severity tier:

| Severity | SLA   | Required action                                                                 |
|----------|-------|---------------------------------------------------------------------------------|
| Critical | 7 d   | Ship a patched build immediately. Set `min_client_version` on the signaling server to the patched version. Clients below the floor receive `CVE_REQUIRES_FORCED_UPDATE` (HTTP 426) with a deep-link to the store update page. File a `kind: p2p_cve / severity: critical` entry in `agent/queue.yaml`. |
| High     | 30 d  | Ship a patched build within the window. Set `min_client_version` when patch lands. Notify users via in-app banner. |
| Medium   | 90 d  | Include fix in the next regular release. No forced update unless CVSS vectors indicate exploitability in the P2P threat model. |
| Low      | next release | Bundle fix in next maintenance release. No forced update. |

### Forced-update procedure

1. Identify the CVE advisory in `signaling/internal/cve/queue.json`.
2. Build and release the patched version to the app stores.
3. Once store review passes, run:

   ```bash
   # Update the server floor — all clients below this version receive HTTP 426.
   export MIN_CLIENT_VERSION=<patched-version>
   # Restart the signaling server with the updated environment variable.
   # See deploy/main.tf for Terraform variable: signaling_min_client_version.
   ```

4. Mark the CVE entry as patched in `queue.json`:

   ```bash
   # Use the CVE queue CLI (when cve_watcher is wired) or edit queue.json by hand.
   jq 'map(if .id == "<CVE-ID>" then .patched_at = (now | todate) else . end)' \
     signaling/internal/cve/queue.json > /tmp/q.json && mv /tmp/q.json signaling/internal/cve/queue.json
   ```

5. Verify the SLA-panel test passes: `go test ./internal/cve/... -run TestSLA`.
6. Update this runbook and the `docs/P2P_SIGNALING_RUNBOOK.md` with the incident timeline.

---

## Key-Rotation Calendar (§3.11)

This section documents the expected rotation schedule for all secrets used by
the signaling server and the P2P session layer.

| Key | Rotation interval | Who rotates | SLA for overdue rotation |
|-----|-------------------|-------------|--------------------------|
| TURN HMAC signing key | Quarterly (every 90 d) | Automated job (§3.11) | `KEY_ROTATION_OVERDUE` alert → PagerDuty |
| Push-token encryption key | Per device-key rotation + at most 30 d TTL; server evicts stale tokens > 90 d | Client-driven re-registration | Stale-token GC job in `store.PurgeExpired` |
| Signed-config signing key (Ed25519) | Annually | Operator (via KMS) | `KEY_ROTATION_OVERDUE` alert if > 365 d since last rotation |
| KMS / install-seal key (AEAD) | Biennially (every 2 y) or on confirmed leak | Operator (via cloud KMS) | Immediate if leaked; biennial otherwise |

### TURN HMAC rotation procedure

1. Generate a new HMAC key:

   ```bash
   openssl rand -base64 32
   ```

2. Set the new key as `TURN_HMAC_KEY_CURRENT` in the signaling server config and
   move the old value to `TURN_HMAC_KEY_PREVIOUS`. Both keys must be live
   simultaneously for the duration of the previous TURN session lifetime (1 h).
3. After 1 h has elapsed, clear `TURN_HMAC_KEY_PREVIOUS`.
4. Update `KEY_LAST_ROTATED_AT` in the operator dashboard config to suppress the
   overdue alert.

### Signed-config signing key rotation procedure

1. Generate a new Ed25519 key pair via the KMS.
2. Add the new public key to the client trust set (shipped in the next app build).
3. Wait one full app-update cycle (approx. 2 weeks post-release, when > 95% of
   active users are on the new build).
4. Retire the old public key from the trust set in the subsequent app build.
5. The signaling server may now sign configs exclusively with the new key.

### KMS / install-seal key rotation procedure

Invoke on biennial schedule or immediately on confirmed key leak:

1. Re-encrypt all at-rest data with the new key (rolling migration in the
   litestream replica layer).
2. Burn the old key in the KMS after migration completes.
3. Update the Terraform `kms_key_arn` variable and roll the signaling server.
4. Run the cold-restore drill (`signaling/test/dr/cold_restore_drill_test.go`) to
   confirm the new key decrypts the latest snapshot.

### KEY_ROTATION_OVERDUE alert policy (§16.2.1)

The operator dashboard must surface a `KEY_ROTATION_OVERDUE` indicator within
**24 hours** of a missed rotation deadline. The check is implemented in
`signaling/internal/ops/key_rotation.go`:

- `KeyRotationOverdueWindow = 24h` — maximum lag between deadline and alert.
- `CheckKeyRotationOverdue(lastRotated, interval, now)` — returns `true` when
  the key is overdue; the dashboard polls this every 5 minutes.

**Escalation path:** `KEY_ROTATION_OVERDUE` → PagerDuty → primary operator →
if unacknowledged for 72 h → `OPERATOR_ON_CALL_UNREACHABLE` + kill-switch
auto-engagement (see §16.7.2 dead-man-switch extension).

---

## Dependency-Bump Policy (§16.4)

These rules apply to all direct dependencies of the signaling server and the
Flutter client that touch cryptographic primitives or the P2P wire protocol.

### §16.4.1 — Major crypto-dep bumps require human review

A **major-version bump** of any cryptographic dependency (libsodium, Go stdlib
`crypto/**`, Flutter `cryptography` package, DTLS library, or any package
providing AEAD / signing / KDF primitives) must:

1. Open a `kind: shared_edit` entry in `agent/queue.yaml` with a written
   rationale explaining why the bump is needed and any breaking-API implications.
2. Pass a fully regenerated KAT-vector test suite for every affected primitive
   before the PR may be merged. (`DepPolicyMajorCryptoRequiresKATRepass = true`)
3. Be reviewed by the primary operator (or a designated second engineer when
   one is available).

Minor and patch bumps for crypto deps do not require `shared_edit` but must
still pass the KAT suite.

### §16.4.2 — CVE auto-PRs must not be force-merged

The CVE-watcher creates auto-PRs for patch-level dependency bumps when a CVE
advisory targets a dependency at the current pinned version. These PRs:

- **Must not be force-merged** (`DepPolicyAutoPRForceMergeDisabled = true`).
- Must pass the full L1–L7 test suite (unit → integration → load → chaos →
  KAT re-pass → regression → manual smoke) before merge.
- The CVE entry must be marked `patched_at` in `queue.json` only after the
  patched build has passed store review and `min_client_version` has been set.

---

## Deprecation Ladder (§16.5)

This section governs how wire-protocol fields and cryptographic suite IDs
are deprecated. The full event log lives in [P2P_DEPRECATIONS.md](P2P_DEPRECATIONS.md).

### §16.5.1 — Soft-deprecation

When a protocol field or crypto suite is to be removed:

1. Announce in the release notes for the version that introduces the replacement.
2. The signaling server logs a non-fatal `"soft-deprecated: <field>"` warning
   for connections that use the old field.
3. Clients see a non-blocking in-app badge: *"A game update is available"*
   (shown for ≥ 30 days before hard-deprecation enforcement).
4. Record the entry in [P2P_DEPRECATIONS.md](P2P_DEPRECATIONS.md).

### §16.5.2 — Hard-deprecation

After the sunset window has elapsed (see §16.5.3), the signaling server enforces
the deprecation:

- `wire_version` and `crypto_suite_id`: rejected with
  `DEPRECATED_WIRE_VERSION_REJECTED` or `DEPRECATED_CRYPTO_SUITE_REJECTED` (HTTP 426).
- `engine_replay_version`: rejected with
  `DEPRECATED_ENGINE_REPLAY_VERSION_REJECTED` (HTTP 426).

All three error codes are defined as constants in
`signaling/internal/cve/cve.go`.

### §16.5.3 — Sunset windows

| Field class | Minimum sunset window |
|---|---|
| `wire_version`, `crypto_suite_id` | 90 days (`SunsetWindowWireVersion`) |
| `engine_replay_version` | 30 days (`SunsetWindowEngineReplay`) |

A shorter window is permitted only for zero-day security issues (where the
affected version can no longer be considered safe); in that case the incident
must be documented in [P2P_INCIDENT_RESPONSE.md](P2P_INCIDENT_RESPONSE.md).

---

## Status-Page Policy (§16.6.2)

The public status page at `https://status.chessrecast.app` must be updated:

| Event | First post | Update cadence | Final "resolved" |
|---|---|---|---|
| Any `P2P_HEALTH_CRITICAL` alert | Within **15 minutes** of detection | Every 60 minutes while active | Within **2 hours** of restoration |
| KPI breach (> 1% of beta MAU) | Within **30 minutes** | Every 60 minutes while active | Within **2 hours** |
| Planned maintenance | At least **72 hours** in advance | N/A | On completion |
| CVE advisory (public) | When the patched build is available in stores | N/A | After forced-update floor is set |

Operators with write access: see [P2P_OPERATOR_ONBOARDING.md §4](P2P_OPERATOR_ONBOARDING.md).

The status page must reflect the correct status for the following components:
- Signaling server (API + WebSocket)
- TURN relay (availability + latency tier)
- Push-wake service
- Matchmaking queue

---

## On-call Schedule (§16.7.1)

The on-call rotation runs on a **weekly cadence**. The schedule must be published
in the team calendar no less than 4 weeks ahead and updated in this section
within 1 business day of any change.

| Period | Primary on-call | Secondary (shadow) |
|---|---|---|
| 2026-05-18 – 2026-05-24 | Project maintainer | — (solo; bus factor = 1) |
| 2026-05-25 – 2026-05-31 | Project maintainer | — |
| *…* | *TBD* | *TBD* |

**SLAs:**
- PagerDuty (or equivalent) acknowledgement: ≤ 15 minutes for `P1`.
- Alert-ack timeout (§16.7.2): if no acknowledgement within 72 hours of a
  critical alert, `OPERATOR_ON_CALL_UNREACHABLE` is raised and the kill-switch
  auto-engages (see `signaling/internal/ops/dead_man_switch.go`).
- For incidents requiring two-person authorisation (key rotation, kill-switch
  toggle), the secondary on-call is the designated co-signer.

**Off-boarding:** when an operator rotates off, follow the offboarding checklist
in [P2P_OPERATOR_ONBOARDING.md §8](P2P_OPERATOR_ONBOARDING.md).

---

## Phase 16 Acceptance Gate & Runbook Index (§16.9)

### Acceptance gate

The following conditions must hold before Phase 16 is considered complete:

1. **All 23 Phase 16 leaf boxes are ticked** in `docs/P2P_ROADMAP.md`.
2. **Restore drill report exists** and is < 60 days old (`agent/reports/p2p/restore-drill-*.md`).
3. **All CVE-ops tests pass:** `go test ./internal/cve/... ./internal/ops/... -count=1`.
4. **All P2P baselines pass** their acceptance thresholds:
   `dart test frontend/test/p2p/p2p_*_test.dart` (when Phase 5 is complete).
5. **Operator onboarding document is dated** within the past 6 months.
6. **Status-page policy is published** in this document.
7. **On-call schedule is published** at least 4 weeks ahead.
8. **Deprecation log is up to date** in [P2P_DEPRECATIONS.md](P2P_DEPRECATIONS.md).
9. **Incident-response template exists** in [P2P_INCIDENT_RESPONSE.md](P2P_INCIDENT_RESPONSE.md).

### Runbook index

| Area | Document |
|---|---|
| Kill-switch, TURN rotation, cold restore | [P2P_SIGNALING_RUNBOOK.md](P2P_SIGNALING_RUNBOOK.md) |
| CVE triage, forced update, key-rotation calendar | This document (above) |
| Deprecation event log | [P2P_DEPRECATIONS.md](P2P_DEPRECATIONS.md) |
| Incident post-mortem template | [P2P_INCIDENT_RESPONSE.md](P2P_INCIDENT_RESPONSE.md) |
| Operator onboarding | [P2P_OPERATOR_ONBOARDING.md](P2P_OPERATOR_ONBOARDING.md) |
| NAT traversal failures | [P2P_NAT_MATRIX.md](P2P_NAT_MATRIX.md) |
| Android OEM issues | [P2P_ANDROID_OEM_MATRIX.md](P2P_ANDROID_OEM_MATRIX.md) |
| Beta KPIs | [P2P_BETA_KPIS.md](P2P_BETA_KPIS.md) |
| Audit history | [P2P_AUDIT_HISTORY.md](P2P_AUDIT_HISTORY.md) |
| GDPR checklist | [P2P_GDPR_CHECKLIST.md](P2P_GDPR_CHECKLIST.md) |
| Recovery drillbook | [P2P_RECOVERY_RUNBOOK.md](P2P_RECOVERY_RUNBOOK.md) |
