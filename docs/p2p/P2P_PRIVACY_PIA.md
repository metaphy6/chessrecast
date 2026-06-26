# ChessRecast P2P — Privacy Impact Assessment (PIA)

**Status:** Published for Phase 18 beta-open gate.  
**Version:** 1.0 (Phase 18 privacy engineering)  
**Scope:** ChessRecast P2P multiplayer feature set, all data flows documented in
[P2P_PRIVACY.md](P2P_PRIVACY.md).

---

## 1. Purpose and legal context

This Privacy Impact Assessment (DPIA/PIA) evaluates the privacy risks introduced
by the ChessRecast P2P multiplayer feature and documents the mitigations in
place. It is required by Phase 18 (§18.6) before the P2P beta opens.

ChessRecast is subject to GDPR (EU/EEA users), CCPA (California users), and
any additional regional privacy laws that apply to the operator's jurisdiction.
This document follows the EDPB DPIA guidelines (WP248).

---

## 2. Lawful basis

| Processing activity | Lawful basis | Notes |
|---|---|---|
| Account identity (Ed25519 key pair) | **Consent** — user creates account voluntarily | No account = no P2P play |
| Game transcripts | **Contract performance** — necessary to run the game | Retained until user deletes account |
| Push token registration | **Legitimate interest** — delivering game invitations | Can be disabled by revoking push permission |
| Telemetry (DP-protected) | **Legitimate interest** — product analytics | Differential-privacy budget §8.11; opt-out available |
| Abuse reports filed against the user | **Legitimate interest** — safety and moderation | Retained anonymised per §14.3 |
| DSAR request data | **Legal obligation** — GDPR Art 15 / CCPA §1798.100 | 30-day response window (§18.3) |

---

## 3. Data categories

| Category | Sensitivity | Examples | Legal basis |
|---|---|---|---|
| Account identifier | Low | Account pubkey (hex), device pubkey | Consent |
| Communications metadata | Medium | Invite timestamps, game session IDs | Contract |
| Game content | Low | Move transcripts, chat history | Contract |
| Device data | Low | Push token (APNs/FCM) | Legitimate interest |
| Behavioural analytics | Low (DP-protected) | Feature-usage counts per DP window | Legitimate interest |
| Safety reports | Medium | Anonymised reporter hash, report reason | Legitimate interest |

No special-category data (GDPR Art 9) is processed.

---

## 4. Recipients

| Recipient | Data shared | Safeguard |
|---|---|---|
| ChessRecast signaling server | Account pubkey, push token (hashed), invite metadata | Operator-controlled, deployed per residency policy (§9.3) |
| TURN relay (Coturn) | Peer IPs, traffic volume | Disclosed in T-M-002; traffic analysis mitigated (T-PRIV-002) |
| Push provider (APNs/FCM) | Push token, wakeup notification | Standard Apple/Google DPA; token rotated on account rotation (T-PRIV-006) |
| Third-party analytics | None | No third-party analytics SDK is embedded |

---

## 5. Retention

| Data class | Retention period | Basis |
|---|---|---|
| Account row (pubkey, push token hash) | Until account deletion | Contract |
| Game transcripts (local) | Until account deletion | User control |
| Audit rows (DSAR) | 90 days rolling, pruned by PruneOldAuditRows | Legal obligation |
| Litestream snapshots | ≤ 30 days (operator enforced) | Proportionality |
| Push tokens | Auto-purged after 30 days of inactivity | Proportionality |
| Telemetry buckets | Per DP window, ~7 days | Product analytics |
| Abuse reports (against user) | Indefinite, anonymised (reporter hash only) | Safety / legal defence |

---

## 6. Transfers and residency

ChessRecast P2P is designed for single-region or self-hosted deployments.
- **Data stays in-region** by default: the signaling server stores everything in
  a regional SQLite + litestream instance; no cross-region replication unless the
  operator explicitly configures it.
- **TURN relay:** if the operator uses a remote TURN server, peer IPs cross to
  that server's region. The T-M-002 mitigation applies.
- **Push providers:** notifications pass through Apple/Google infrastructure,
  which may involve cross-border transfers. Standard Contractual Clauses (SCCs)
  apply under the respective DPAs.

For deployments with EU users, the operator must ensure the signaling server is
hosted within the EU/EEA (or a jurisdiction with an adequacy decision) unless an
Article 46 safeguard (e.g. SCCs) is in place.

---

## 7. User rights

ChessRecast implements all GDPR/CCPA user rights:

| Right | Implementation | Reference |
|---|---|---|
| Access (Art 15) | DSAR endpoint returns JSON export within 30 days | §18.3, `signaling/internal/dsar/dsar.go` |
| Portability (Art 20) | Encrypted CBOR archive via "Export my data" | §18.4, `lib/services/p2p/privacy/export_service.dart` |
| Erasure (Art 17) | "Delete my account" wipes server + local state | §18.5, `lib/services/p2p/privacy/delete_account_service.dart` |
| Objection (Art 21) | Telemetry opt-out in settings; push-notification opt-out via OS | §8.11 |
| Rectification (Art 16) | Display-name override (local); account key rotation (§2.11) | §2.11 |

---

## 8. DPIA risk ratings

| Risk ID | Description | Likelihood | Severity | Residual risk after mitigation |
|---|---|---|---|---|
| R-01 | Cross-session linkage via stable fingerprint | Medium | Medium | **Low** — user can rotate identity (T-PRIV-001) |
| R-02 | Traffic analysis on signaling endpoints | Low | Low | **Very low** — 256-byte padding + jitter (T-PRIV-002) |
| R-03 | Spectator-presence inference via TURN | Low | Low | **Low** — documented residual (T-PRIV-003) |
| R-04 | Export archive used for social engineering | Low | Medium | **Low** — 5-min cooldown + passphrase (T-PRIV-004) |
| R-05 | Telemetry cross-correlation | Low | Low | **Very low** — DP budget + per-window salt (T-PRIV-005) |
| R-06 | Push-token reuse across account rotations | Low | Low | **Very low** — token revoked on rotation (T-PRIV-006) |
| R-07 | TURN server learns peer IPs | Medium | Low | **Low** — disclosed; in-region TURN mitigates (T-M-002) |
| R-08 | Push provider learns wakeup patterns | Low | Low | **Low** — disclosed; opt-out available (T-M-003) |

No risk is rated **High** or **Very High** after mitigation.

---

## 9. Mitigations summary

All mitigations are implemented and tested as part of Phase 18:
- **T-PRIV-001** — Identity rotation (§2.11 recovery code rotation)
- **T-PRIV-002** — 256-byte request padding + jittered long-poll (`signaling/internal/privacy/traffic_padding.go`)
- **T-PRIV-003** — Spectator isolation design (documented residual)
- **T-PRIV-004** — Export cooldown + passphrase + biometric re-confirm (§18.4)
- **T-PRIV-005** — Per-window DP salt rerandomisation (§8.11)
- **T-PRIV-006** — Push-token revocation on account rotation (§2.11)
- Data-flow inventory CI gate (`xops/p2p/data-flow-completeness-check.sh`)
- DSAR access/portability/erasure flows (§18.3–§18.5)

---

## 10. DPO contact

| Role | Contact |
|---|---|
| Data Protection Officer (DPO) | dpo@chessrecast.example (replace with actual operator contact) |
| Privacy-related support | privacy@chessrecast.example |

*Solo-deployment operators: GDPR Art 37 does not require a DPO for all
organisations. If no DPO is required, the controller's primary contact should
be listed.*

---

## 11. Reviewer attestation

This PIA was reviewed and attested as follows:

| Item | Status |
|---|---|
| Reviewed by qualified privacy reviewer | Operator self-attest (permitted for solo deployment per §18.6) |
| Data-flow inventory complete | ✅ (11 classes, §18.1 CI gate live) |
| All T-PRIV threats documented with mitigations | ✅ (T-PRIV-001..006, §18.2) |
| DSAR flow tested | ✅ (§18.3, 4/4 tests green) |
| Portability flow tested | ✅ (§18.4, 9/9 tests green) |
| Erasure flow tested | ✅ (§18.5, 10/10 tests green) |
| Date of attestation | Phase 18 completion |

*For a multi-user or enterprise deployment, replace the self-attestation above
with a review from a qualified Data Protection Officer or privacy counsel.*

---

*Published: Phase 18 privacy engineering.*
