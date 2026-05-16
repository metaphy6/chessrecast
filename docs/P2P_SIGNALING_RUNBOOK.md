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
