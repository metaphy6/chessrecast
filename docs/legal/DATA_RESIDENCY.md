# Data Residency — ChessRecast P2P

**Version:** 1.0  
**Effective:** 2024-01-01  
**Owner:** See [P2P_OPERATIONS.md](../p2p/P2P_OPERATIONS.md) §1

---

## 1. Overview

ChessRecast uses a peer-to-peer architecture. The signaling server handles
only WebRTC offer/answer exchange and TURN credential provisioning — it does
**not** relay game state, moves, or chat in the steady state. This minimises
the personal data held on servers.

---

## 2. What data leaves the device

| Data type | Where processed | Retained? | Duration |
|---|---|---|---|
| WebRTC SDP offer/answer | Signaling server | No — in-memory only | < 30 s |
| TURN credential (ephemeral) | TURN server | No | TTL 24 h |
| Push notification token hash | Signaling server | Yes | Until account deletion |
| Account public key (Ed25519) | Signaling server | Yes | Until account deletion |
| `last_seen` coarse timestamp | Signaling server | Yes | Until account deletion |
| Audit rows (invite accepted/declined) | Signaling server | Yes | 90 days rolling |
| Game state, moves, chat | P2P direct / TURN relay | No | Never persisted server-side |

---

## 3. Regions

| Environment | Primary region | Backup region |
|---|---|---|
| Production (EU) | `eu-west-1` (Ireland) | `eu-central-1` (Frankfurt) |
| Production (US) | `us-east-1` (Virginia) | `us-west-2` (Oregon) |
| Staging | `eu-west-1` | None |

All signaling server deployments are in the same GDPR-jurisdictional zone as
the user's region selection (set at first launch). Users in the EEA are
routed to EU region servers only.

**Per-region routing:** implemented by the `X-Region` HTTP header returned
by the bootstrap endpoint. The client caches the region for 7 days and
re-negotiates on reconnect.

---

## 4. Data-subject rights

- **Access (DSAR):** operator provides a coarse last_seen timestamp, push-token
  hash, and audit rows on request. See `signaling/internal/dsar/` for the
  implementation.
- **Deletion:** the `/dsar/delete` endpoint wipes all rows including litestream
  snapshots within 30 days.
- **Rectification:** not applicable — no user-facing profile data is stored.
- **Portability:** not applicable — no user content is stored server-side.

---

## 5. Third-party sub-processors

| Processor | Role | DPA in place |
|---|---|---|
| TURN operator (coturn self-hosted) | Relay fallback | Operator-controlled |
| Push notification gateway (APNs/FCM) | Invite delivery | Apple/Google DPA |
| Litestream (optional) | WAL backup | Open-source, no SaaS |

---

## 6. Compliance notes

- **GDPR (EU 2016/679):** legitimate interest basis for signaling metadata;
  data minimisation applied (no game content server-side).
- **CCPA (Cal. Civ. Code §1798.100):** no "sale" of personal information;
  deletion right honoured via DSAR endpoint.
- **COPPA:** users under 13 are not permitted; enforced by app-store age gate.

---

## 7. Change log

| Version | Date | Change |
|---|---|---|
| 1.0 | 2024-01-01 | Initial draft (§8.5 / P2P roadmap Phase 8) |
