# P2P Beta KPIs

**Document type:** Phase 5 §5.5 L9 proof artefact — defines the observable metrics that
must be live-graphed before the open beta begins (see [docs/P2P_ROADMAP.md](P2P_ROADMAP.md) §6.2
and §L9 in Phase 5).

---

## Scope

These KPIs apply to the **closed-beta cohort** (100–1 000 opted-in users over ≥2 regions).
They must be instrumented, dashboarded, and alert-wired before any beta build reaches
TestFlight / Play Internal. A KPI that cannot be measured is equivalent to a KPI that
fails: the beta gate stays closed until every row in this table has a live data feed.

---

## KPI table

| # | KPI name | Target (beta) | Target (GA) | Alarm threshold | Collection method |
|---|---|---|---|---|---|
| B-1 | **Connection success rate** | ≥ 90% | ≥ 99% | < 85% → PagerDuty P2 | Client event `p2p.handshake.success/fail`; 10-min window |
| B-2 | **Handshake P50 latency** | ≤ 10 s | ≤ 5 s | > 20 s P50 → P2 | Timer from intent to `HELLO_ACK`; reported as histogram |
| B-3 | **Handshake P95 latency** | ≤ 30 s | ≤ 15 s | > 45 s → P2 | Same histogram |
| B-4 | **Direct-connect rate** (no TURN) | ≥ 60% | ≥ 70% | < 50% → P3 | ICE candidate type in `p2p.ice.selected` event |
| B-5 | **Move RTT P50** | ≤ 200 ms | ≤ 100 ms | > 500 ms → P3 | Timer from `MOVE` send to `MOVE_ACK` receive |
| B-6 | **Move RTT P95** | ≤ 800 ms | ≤ 400 ms | > 2 000 ms → P2 | Same |
| B-7 | **MISMATCH rate** | 0 / 10⁴ moves | 0 / 10⁵ moves | Any → P1 immediate halt | `MISMATCH` frame count; session hash delta |
| B-8 | **BACKPRESSURE_DROP rate** | < 0.1% of moves | < 0.01% | > 1% → P2 | `BACKPRESSURE_DROP` frame count / total move frames |
| B-9 | **Push-wake redemption rate** | ≥ 70% | ≥ 85% | < 60% → P3 | Push sent → ICE restart completed within 60 s |
| B-10 | **Recovery-flow success rate** | ≥ 95% | ≥ 99% | < 90% → P2 | Recovery attempt → successful restore |
| B-11 | **7-day crash-free rate** (P2P cohort) | ≥ 99.5% | ≥ 99.9% | < 99% → P1 | Sentry `p2p.crash` tag; 7-day rolling |
| B-12 | **Battery drain delta** (opt-in) | ≤ 5% extra vs single-player | ≤ 3% | > 10% → P3 | BatteryManager / `UIDevice.batteryLevel` delta over 30-min session |
| B-13 | **Signaling server P95 latency** | ≤ 200 ms | ≤ 100 ms | > 500 ms → P2 | Prometheus `http_request_duration_seconds` p95 |
| B-14 | **TURN egress cost** | ≤ $0.007 / MAU | ≤ $0.007 | > $0.01 → P3 | Monthly billing report committed to `agent/reports/p2p/cost-<yyyy-mm>.md` |
| B-15 | **Per-mod engine KPIs** | No regression | Baseline held | > 5% regression → P1 | `agent/baselines/<mod>.json`; re-run on every P2P change |

---

## Instrumentation requirements

1. **Event schema** — all client events are CBOR-encoded, PII-stripped at collection boundary, and written to the telemetry endpoint defined in `docs/P2P_PROTOCOL.md §telemetry-v1`. No raw IPs, no player names, no move content in telemetry.
2. **Dashboard** — Grafana (or equivalent) with one panel per KPI row, connected to the Prometheus/Loki instance defined in `docs/P2P_SIGNALING_RUNBOOK.md §observability`. Dashboard JSON committed to `agent/reports/p2p/dashboards/beta_kpis.json` before beta opens.
3. **Alert routing** — P1 alerts wake the on-call engineer within 5 minutes; P2 within 30 minutes; P3 by next business day. Runbook URL in every alert body.
4. **Baseline freeze** — at beta start, all KPI values are snapshotted into `agent/baselines/p2p_beta_snapshot_<date>.json` and pinned. Regressions during beta are measured against this snapshot.

---

## Acceptance gate for L9 (Phase 5 §5.3)

All of the following must be true before L9 is considered fully operational:

- [ ] All 15 KPI rows have a live Prometheus/Loki query confirmed by a manual spot-check.
- [ ] The Grafana dashboard is committed and rendering in the staging observability stack.
- [ ] Alerts B-7 and B-11 have been fire-tested in staging (synthetic event injection).
- [ ] `agent/baselines/p2p_beta_snapshot_<date>.json` committed to main at beta open.
- [ ] `docs/P2P_OPERATIONS.md` updated with the telemetry endpoint URL and the cost runbook.

*This file is the L9 proof artefact referenced by [docs/P2P_ROADMAP.md](P2P_ROADMAP.md) Phase 5.*
