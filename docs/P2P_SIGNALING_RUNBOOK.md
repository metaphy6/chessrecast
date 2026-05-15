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
