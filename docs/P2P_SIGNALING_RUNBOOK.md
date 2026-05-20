# P2P Signaling Server — Alerts Runbook

This runbook covers alerting, on-call response, and escalation procedures for the
`chessrecast/signaling` service.

---

## 1. Alert Inventory

| Alert | Condition | Severity | Response Time |
|---|---|---|---|
| `SignalingHighErrorRate` | HTTP 5xx > 5% over 1 min | critical | < 5 min |
| `SignalingHighLatencyP99` | p99 latency > 500 ms over 5 min | warning | < 15 min |
| `SignalingRateLimitSpiking` | `rate_limit_rejected_total` > 500/min over 2 min | warning | < 15 min |
| `SignalingDBWritesBlocked` | `db_write_errors_total` > 0 (HA failover?) | critical | < 5 min |
| `SignalingCrash` | process restart detected | critical | < 5 min |
| `SignalingCertExpirySoon` | TLS cert expires in < 14 days | warning | < 24 h |

---

## 2. Triage Steps

### SignalingHighErrorRate
1. `kubectl logs -l app=signaling --tail=100` — look for panic, assertion, or nil dereference.
2. Check `/v1/ready` — if `db_ready: false`, the SQLite WAL is blocked; follow §3 (DB recovery).
3. Check `/v1/metrics` — `http_errors_total` breakdown by path.
4. If all errors are on `/v1/accounts/register` or `/v1/accounts/rebind`, a burst of registrations
   may have exhausted the per-IP token bucket; check `rate_limit_rejected_total`.

### SignalingHighLatencyP99
1. Profile with `go tool pprof http://signaling:6060/debug/pprof/heap`.
2. Check SQLite WAL checkpoint lag: `PRAGMA wal_checkpoint(PASSIVE)` via a read replica connection.
3. Verify quic-go `MaxIncomingStreams` is not saturated under HTTP/3.

### SignalingDBWritesBlocked
1. SSH to the signaling pod: `sqlite3 /data/signaling.db ".schema"` — confirms DB is accessible.
2. If HA failover is in progress: set `SIGNALING_READ_ONLY=true` on the standby until the primary
   confirms the new primary lease. Then clear the flag and restart.
3. If not a failover, check disk full: `df -h /data`.

### SignalingCrash
1. `kubectl describe pod` — check OOMKilled flag.
2. Read `agent/state/last_failure.json` for the last captured exit-code log.
3. If `SIGSEGV` / `Aborted`: capture core dump, attach to issue, file `kind: crash` queue entry.

---

## 3. DB Recovery (Cold Restore)

See [DR drill test](../signaling/test/dr/cold_restore_drill_test.go) for the automated proof.

Manual steps:
```bash
# 1. Stop signaling server to prevent writes.
kubectl scale deployment signaling --replicas=0

# 2. Restore from litestream backup.
litestream restore -config /etc/litestream.yml /data/signaling.db

# 3. Verify schema integrity.
sqlite3 /data/signaling.db "PRAGMA integrity_check;"

# 4. Restart.
kubectl scale deployment signaling --replicas=1
```

---

## 4. Escalation

| Escalation Level | Contact | When |
|---|---|---|
| L1 On-call | PagerDuty rotation | All critical alerts |
| L2 Backend lead | Slack `#backend-oncall` | If L1 cannot resolve in 30 min |
| L3 Infra / SRE | Direct message | Persistent DB corruption or data loss |

---

## 5. SLOs

| Metric | Target | Measurement window |
|---|---|---|
| Availability | 99.9% | 30-day rolling |
| p99 latency (`POST /v1/offers`) | < 200 ms | 5-min window |
| Error rate | < 0.1% | 1-min window |
| Recovery from cold restore | < 10 min | Per DR drill |

---

## 6. Rollback

This section documents the full rollback procedure for disabling P2P at the
server level.  The client-side kill-switch (`kEnableP2P`) is documented in
`frontend/lib/services/p2p/config/remote_config.dart`; this section covers the
**signaling-server** side.

### 6.1 Immediate disable (< 1 minute)

The fastest path: hit the admin endpoint on the running instance.

```bash
# 1. Open an authenticated shell to the signaling server.
kubectl exec -it deploy/signaling -- /bin/sh   # Kubernetes
# OR: fly ssh console -a chessrecast-signaling  # Fly.io

# 2. Toggle the kill-switch.  This causes every subsequent request to
#    /v1/offers to receive HTTP 503 + Retry-After: 600.
curl -s -X POST http://localhost:8080/admin/v1/disable \
  -H "Authorization: Bearer $SIGNALING_ADMIN_TOKEN"

# 3. Verify the endpoint is now returning 503.
curl -I http://localhost:8080/v1/offers
# Expected: HTTP/1.1 503 Service Unavailable
#           Retry-After: 600
```

### 6.2 Re-enable (after incident resolved)

```bash
curl -s -X POST http://localhost:8080/admin/v1/enable \
  -H "Authorization: Bearer $SIGNALING_ADMIN_TOKEN"

# Verify:
curl -I http://localhost:8080/v1/offers
# Expected: HTTP/1.1 200 OK  (or 401 if not authenticated — that is correct)
```

### 6.3 Deploy-based rollback (if binary is broken)

Use this when the running binary itself is broken and must be replaced.

```bash
# 1. Identify the last-known-good image tag in the deployment history.
kubectl rollout history deployment/signaling

# 2. Roll back to the previous revision.
kubectl rollout undo deployment/signaling

# 3. Wait for rollout to finish and confirm all pods are healthy.
kubectl rollout status deployment/signaling --timeout=5m
kubectl get pods -l app=signaling

# 4. Run the smoke test.
curl -s https://signaling.chessrecast.example/health | jq .status
# Expected: "ok"
```

### 6.4 Decision matrix

| Symptom | First action | Owner |
|---|---|---|
| KPI regression > 5% on any P2P metric | Client kill-switch via remote config (§6.1.1 `kEnableP2P=false`) | On-call |
| `/v1/offers` returning 5xx at > 0.1% error rate | Admin disable (§6.1 above) | On-call |
| Native-engine regression (chess quality) | Admin disable + queue `kind: kpi_regression` entry | Engine team |
| Security incident (auth bypass / data leak) | Admin disable + escalate to L3 immediately | Security lead |
| Signaling binary crash-loop | Deploy-based rollback (§6.3 above) | SRE |

### 6.5 Post-incident checklist

1. [ ] All KPIs confirmed back in `ok` state on the dashboard.
2. [ ] Root cause documented in `agent/reports/p2p/<date>-incident.md`.
3. [ ] Queue entry filed (`kind: kpi_regression` or `kind: crash`) if applicable.
4. [ ] Baseline regenerated for any affected mod (`agent/baselines/<mod>.json`).
5. [ ] Re-enable issued and smoke test passed.
6. [ ] Incident summary sent to `#backend-oncall`.

> **§6.3.3 proof:** This §6 "Rollback" section satisfies the rollback runbook
> requirement for leaf 6.3.3 of `docs/P2P_ROADMAP.md` [p2p-20260516-105107-14206].

---

## §7 Standby region promotion

*Drill cadence: quarterly. Log drills in `docs/P2P_OPERATIONS_DRILL_LOG.md`.*

| Step | Command / action | Drill date column |
|---|---|---|
| 7.1 | Confirm standby DB is < 5 s behind primary via litestream metrics. | last_drill |
| 7.2 | Update DNS / load-balancer to point to standby region. | last_drill |
| 7.3 | Set `SIGNALING_READ_ONLY=false` on standby; set `SIGNALING_READ_ONLY=true` on old primary. | last_drill |
| 7.4 | Smoke test: `curl -s https://<new-primary>/health \| jq .status` → `"ok"`. | last_drill |
| 7.5 | Verify litestream replication resumed (new primary → old primary now replicates). | last_drill |
| 7.6 | Update `docs/P2P_OPERATIONS.md` §1 operator table with new region. | last_drill |

```bash
# Example (replace <standby> and <primary> with actual hostnames):
kubectl config use-context <standby-cluster>
kubectl set env deployment/signaling SIGNALING_READ_ONLY=false
kubectl config use-context <primary-cluster>
kubectl set env deployment/signaling SIGNALING_READ_ONLY=true
```

---

## §8 KMS key rotation

*Drill cadence: annually or on confirmed leak. Log in `docs/P2P_OPERATIONS_DRILL_LOG.md`.*

| Step | Action | Drill date |
|---|---|---|
| 8.1 | Generate new AEAD key via cloud KMS or `openssl rand -hex 32`. | last_drill |
| 8.2 | Update SOPS-encrypted secret store: `sops -e -i secrets/kms.enc.yaml`. | last_drill |
| 8.3 | Roll out new key to all signaling pods (rolling restart). | last_drill |
| 8.4 | Verify `KEY_LAST_ROTATED_AT` updated; suppress `KEY_ROTATION_OVERDUE` alert. | last_drill |
| 8.5 | Re-encrypt all install-sealed blobs with new key (offline batch job). | last_drill |
| 8.6 | Delete old key from KMS after one rotation-window overlap (7 days). | last_drill |

---

## §9 litestream cold backup restore

*Drill cadence: quarterly. Log in `docs/P2P_OPERATIONS_DRILL_LOG.md`.*

Extends §3 (DB recovery) with full cold-restore procedure from object storage.

| Step | Action | Drill date |
|---|---|---|
| 9.1 | Stop signaling: `kubectl scale deployment signaling --replicas=0`. | last_drill |
| 9.2 | Locate latest snapshot: `litestream snapshots -config /etc/litestream.yml`. | last_drill |
| 9.3 | Restore: `litestream restore -config /etc/litestream.yml /data/signaling.db`. | last_drill |
| 9.4 | Verify integrity: `sqlite3 /data/signaling.db "PRAGMA integrity_check;"` → `ok`. | last_drill |
| 9.5 | Restart: `kubectl scale deployment signaling --replicas=1`. | last_drill |
| 9.6 | Smoke test `/v1/health` → `200 ok`. | last_drill |

---

## §10 Scaling out coturn

*Drill cadence: as needed / pre-traffic-spike. Log in `docs/P2P_OPERATIONS_DRILL_LOG.md`.*

| Step | Action | Drill date |
|---|---|---|
| 10.1 | Increase coturn deployment replica count. | last_drill |
| 10.2 | Verify all replicas share the same TURN HMAC secret (from sealed secret). | last_drill |
| 10.3 | Update signaling `TURN_URLS` env var with new coturn IPs. | last_drill |
| 10.4 | Smoke-test TURN allocation: `turnutils_uclient -u test -w $HMAC_SECRET <new-turn-ip>`. | last_drill |

---

## §11 Rotating TURN HMAC secret

*Drill cadence: annually or on confirmed leak. Log in `docs/P2P_OPERATIONS_DRILL_LOG.md`.*

| Step | Action | Drill date |
|---|---|---|
| 11.1 | Generate new HMAC: `openssl rand -hex 32`. | last_drill |
| 11.2 | Update SOPS store: `sops -e -i secrets/turn.enc.yaml` with new value. | last_drill |
| 11.3 | Apply to all coturn pods via rolling restart. | last_drill |
| 11.4 | Update `TURN_HMAC_SECRET` env var in signaling deployment; rolling restart. | last_drill |
| 11.5 | Smoke-test TURN credential issuance via `/v1/turn_credential`. | last_drill |

---

## §12 Push-provider revocation (compromised FCM/APNs key)

*Drill cadence: on confirmed leak only. Log in `docs/P2P_OPERATIONS_DRILL_LOG.md`.*

| Step | Action | Drill date |
|---|---|---|
| 12.1 | Revoke compromised key in Firebase Console / Apple Developer portal immediately. | on-breach |
| 12.2 | Generate new service-account JSON (FCM) or `.p8` key (APNs). | on-breach |
| 12.3 | Update SOPS store; roll out to signaling pods. | on-breach |
| 12.4 | Verify push delivery to a test device. | on-breach |
| 12.5 | Audit `dsar_audit` table for any push delivery during the window of compromise. | on-breach |
| 12.6 | Notify affected users if any personal data was accessible to the compromised key. | on-breach |

---

## §13 Forced-update drill (§16.1.3)

> **Purpose:** Verify the end-to-end forced-update path — from setting
> `min_client_version` on the signaling server to clients receiving HTTP 426
> `CVE_REQUIRES_FORCED_UPDATE` — without affecting real users.
>
> **Cadence:** Monthly (or within 48 h of any Critical CVE advisory).
> **Log drills in:** `docs/P2P_OPERATIONS_DRILL_LOG.md`.

### Pre-conditions

- Staging signaling server running at `https://signaling-staging.chessrecast.example`.
- At least two staging test accounts available.
- An old client build (version < the drill target version) available on the
  device under test.

### Drill steps

| Step | Command / action | Expected outcome |
|---|---|---|
| 13.1 | Set `MIN_CLIENT_VERSION` on staging to a version **higher** than the test device's build: `export MIN_CLIENT_VERSION=99.0.0`. | — |
| 13.2 | Restart staging signaling with the new floor: `kubectl set env deployment/signaling-staging MIN_CLIENT_VERSION=99.0.0`. | `kubectl rollout status deployment/signaling-staging` → `successfully rolled out`. |
| 13.3 | From the test device (old build), attempt to open a P2P match. | Client receives HTTP 426. `"code": "CVE_REQUIRES_FORCED_UPDATE"` in the JSON body. |
| 13.4 | Verify the deep-link in the 426 body points to the correct store page. | URL is non-empty and resolves. |
| 13.5 | From a test device with a current build (version ≥ `99.0.0` — use a staging build that is patched), repeat the P2P match attempt. | Match proceeds normally; no 426 received. |
| 13.6 | Restore staging floor: `kubectl set env deployment/signaling-staging MIN_CLIENT_VERSION=`. | Staging floor cleared. Old-client test device can connect again. |
| 13.7 | Verify the CVE queue entry's `MinClientVersion` field is honoured by running: `go test ./internal/cve/... -run TestForcedUpdate -v`. | All tests pass. |
| 13.8 | Record the drill outcome in `docs/P2P_OPERATIONS_DRILL_LOG.md` with: drill date, operator, outcome (pass/fail), P50/P95 latency of the 426 response (from curl timing), and any deviations. | — |

### Post-drill checklist

- [ ] Staging `MIN_CLIENT_VERSION` cleared (Step 13.6 confirmed).
- [ ] Drill logged in `docs/P2P_OPERATIONS_DRILL_LOG.md`.
- [ ] If the drill failed, a `kind: p2p_security / severity: high` entry filed in `agent/queue.yaml`.

### Drill failure criteria

The drill is **failed** if any of the following:
- The old client does not receive HTTP 426 within 5 seconds.
- The 426 body does not contain `"code": "CVE_REQUIRES_FORCED_UPDATE"`.
- The deep-link URL is empty or does not resolve.
- The new-build client is also rejected (false positive).
- `go test ./internal/cve/... -run TestForcedUpdate` exits non-zero.

> **§16.1.3 proof:** This §13 satisfies the forced-update drill procedure
> requirement for leaf 16.1.3 of `docs/P2P_ROADMAP.md`.

---

## §14 Backup restore drill (§16.3.1–16.3.2)

> **Purpose:** Monthly verification that the litestream backup can be restored
> within the P50/P95 latency budget (≤ production + 10%) and that the restored
> DB passes integrity checks and the Phase 5 L7 chaos smoke suite.
>
> **Cadence:** Monthly. Maximum gap between successful drills: **60 days**
> (`MaxDrillAge`). Exceeding this threshold auto-suspends the GA gate
> (`GAGateStatus` returns `DrillStatusFailed`).
>
> **Log reports in:** `agent/reports/p2p/restore-drill-YYYY-MM.md`.

### Drill steps

| Step | Command / action | Expected outcome |
|---|---|---|
| 14.1 | Record production P50 and P95 restore latency from Grafana as of drill date. | Values noted in the report. |
| 14.2 | Run dry-run drill on staging: `DRY_RUN=1 go test ./test/dr/... -run TestColdRestore -v`. | All assertions pass. |
| 14.3 | Record actual P50 and P95 latency from the drill run. | Both ≤ production + 10%. |
| 14.4 | Verify DB integrity: `sqlite3 /tmp/drill_restore.db "PRAGMA integrity_check;"`. | `ok` |
| 14.5 | Run Phase 5 L7 chaos smoke suite: `go test ./test/integration/... -count=1`. | All pass. |
| 14.6 | Create `agent/reports/p2p/restore-drill-YYYY-MM.md` using the template. | File committed. |

### DrillResult status codes

The drill is captured as a `DrillResult` struct (defined in
`signaling/internal/ops/restore_drill.go`):

- `DrillResult.Success = true` + `DrillResult.WithinBounds() = true` → drill passes.
- Either `false` → drill fails; `GAGateStatus` returns `DrillStatusFailed`; GA gate suspended.

> **§16.3.1–16.3.2 proof:** This §14 satisfies the restore-drill runbook
> requirement for leaves 16.3.1 and 16.3.2 of `docs/P2P_ROADMAP.md`.

