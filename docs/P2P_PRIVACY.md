# P2P Privacy Policy — Technical Documentation

*This document is the technical privacy reference for the ChessRecast P2P feature.
It supplements the end-user privacy policy and is cited by the threat model in
[docs/P2P_ROADMAP.md](P2P_ROADMAP.md) §9.5.*

---

## T-M-002 — TURN server learns peer IPs and traffic volume

### Scope
When a TURN relay is used (typically when both peers are behind symmetric NAT),
the TURN server observes:
- The source IP and port of each peer's connection to the relay.
- The total UDP/TCP byte volume per session.
- The session start and end times.

### Mitigation in scope
- TURN credentials are **short-lived** (5 minute TTL, see `signaling/internal/turn/turn.go`).
- TURN credentials are **session-bound** via HMAC (see `frontend/lib/services/p2p/transport/turn_session_binding.dart`).
- TURN relays do **not** see plaintext game data; the DataChannel payload is
  AEAD-encrypted end-to-end (§2.3 of P2P_PROTOCOL.md).

### Documented residual risk
A TURN relay operator (or an adversary with access to the relay) can observe:
- That two IP addresses communicated with each other at a given time.
- The approximate data volume and timing pattern.

This is inherent to the TURN relay model. **No full mitigation exists without
removing the need for TURN (e.g. onion routing), which is out of scope for v1.**

Users who require unlinkable communication (e.g. privacy-critical contexts)
should not use P2P chess unless both sides can achieve a direct peer-to-peer
connection without relaying.

**Documentation status:** informed consent included in the in-app privacy notice
before the first P2P session.

---

## T-M-003 — Push provider learns recipient device and wakeup frequency

### Scope
When a push notification is sent to wake a recipient device, the push provider
(Apple APNs / Google FCM) observes:
- The push token associated with the recipient's device.
- The timestamp and approximate frequency of wakeup events.

### Mitigations
1. **Payload minimisation** — the push payload is intentionally **empty**; only
   the wakeup intent is sent. No game data, no opponent identity, no match state
   travels through the push channel.
2. **Daily ceiling** — the signaling server enforces a per-`(sender, recipient)`
   wakeup ceiling (`signaling/internal/push/push.go:StalePushTokenTTL`). This
   limits the amount of wakeup-frequency metadata the provider can accumulate.
3. **Token encryption** — push tokens are stored encrypted at rest using a
   per-account KMS-derived key (`signaling/internal/store/pii_audit_test.go`).
   The provider-side mapping `(token → ChessRecast user)` is unavoidable from
   the provider's perspective, but requires both the provider's DB and the
   ChessRecast signaling DB to link.

### Documented residual risk
Apple APNs and Google FCM can, in principle, correlate the push token with a
device and an Apple / Google account. ChessRecast has no control over this. Users
who require unlinkable push wakeup should use polling instead (controlled via the
`prefer_polling` account flag, Phase 11).

---

## T-M-004 — Account fingerprint is an intentional stable cross-game identifier

### Design decision
The device fingerprint displayed in the opponent card (§14.9 of the roadmap) is
**intentionally stable across games** so that:
- Users who have manually verified an opponent (via safety numbers / QR) can
  confirm future opponents are the same person without repeating the verification
  ritual.
- Two-game stalkers (T-P-006 fork attack) are exposed: if the same fingerprint
  appears in a disputed second game, the link is provable.

### Privacy implication
A user who plays multiple games with different opponents will have their
fingerprint visible to all of those opponents. This means:
- An opponent from game 1 and an opponent from game 2 can **link the two games**
  as belonging to the same account, even without knowing each other.
- This is a **by-design cross-game linkability surface**.

### User control
Users who require unlinkable play across opponents must generate a fresh account
by rotating their recovery code (which derives a new device key → new
fingerprint). This operation is explicitly described in the in-app settings under
"Reset identity". The privacy notice shown at account creation explains that the
fingerprint is stable.

### Documentation status
This trade-off is documented in:
- This file (technical reference).
- The in-app onboarding privacy notice (UX copy TBD in Phase 14 §14.9 sprint).
- The roadmap §9.5 T-M-004 entry.

---

## §9.8 Post-Quantum readiness — privacy implications

Classical Ed25519 signatures on transcripts (and X25519 ephemeral keys) are
vulnerable to a "harvest-now, decrypt-later" adversary with a future quantum
computer. For ChessRecast v1:
- Game content is end-to-end encrypted; a quantum adversary harvesting
  ciphertexts today could decrypt them post-quantum. **Impact:** low (chess
  games are not sensitive data).
- Identity fingerprints derived from Ed25519 public keys would remain valid
  for identity linkage even after key material is rotated, because an old
  transcript's signature is forever attributable.

Migration to hybrid PQ suite (`crypto_suite_id: 0x02`) is tracked in
Phase 12 and will address both concerns.

---

*Last updated: Phase 18 privacy engineering.*

---

## Privacy Threat Model (T-PRIV-*)

Privacy-specific threats added by Phase 18. Broader network/metadata threats
(T-M-002, T-M-003, T-M-004) are documented above.

---

## T-PRIV-001 — Cross-session linkage via stable account fingerprint

### Scope
The account fingerprint (derived from the long-term Ed25519 device key) is
**intentionally stable** across games (see T-M-004 above), enabling
cross-session linkage. An adversary who participates in two separate games
against the same account can link those games to the same identity.

### Mitigation
Users can rotate their recovery code (§2.11), which derives a fresh device key
and therefore a fresh account fingerprint. The previous account's games become
unlinkable from the new account. This operation is described in the in-app
"Reset identity" settings page.

### Documented residual risk
Cross-session linkage by opponents who have *previously verified* the fingerprint
is a **by-design property** — it is how the verified-badge system works. Users
who require per-game unlinkability must rotate between every game.

*Already documented in §9.5 T-M-004; folded here for Phase 18 completeness.*

---

## T-PRIV-002 — Traffic analysis on signaling endpoints

### Scope
An observer with access to signaling-server network traffic can distinguish
request types by payload size (e.g. a small "offer" vs. a large "poll
response with moves") or by timing patterns (e.g. long-poll wakeup cadence
reveals when games are active).

### Mitigation
- **Request padding:** all signaling API responses are padded to the nearest
  256 bytes before encryption/transmission (see
  `signaling/internal/privacy/traffic_padding.go`). This prevents size-based
  classification.
- **Jittered long-poll wakeup:** the server introduces a per-request random
  jitter of ±50 ms on long-poll response delays, breaking deterministic
  timing fingerprints.

### Proof
`signaling/internal/privacy/traffic_padding_test.go` — verifies that
`PadToNearest256` rounds up correctly for all input sizes and that
`JitteredWakeDelay` returns values within the expected jitter window.

### Documented residual risk
A sufficiently patient observer who collects many sessions can still infer
traffic patterns via aggregate analysis. Full traffic-analysis resistance would
require onion routing, which is out of scope for v1.

---

## T-PRIV-003 — Spectator-presence inference via TURN allocation patterns

### Scope
When a spectator joins a live game, a separate TURN allocation is created for
the spectator (§7.10.3 separate-allocation design). An observer who monitors
the TURN server's allocation table can therefore infer whether a game has
spectators — and approximately how many.

### Mitigation
The §7.10.3 separate-allocation design already obscures the spectator count
from the two players. An operator-level observer can see the allocation count
but cannot identify the spectators without also observing push-token → account
mappings.

### Documented residual risk
Operator-level visibility of spectator allocation counts is an inherent
consequence of using a shared TURN relay. A privacy-critical deployment would
need a dedicated TURN server per session, which is out of scope for v1.

---

## T-PRIV-004 — Export-my-data archive as social-engineering vector

### Scope
A phishing or social-engineering attacker might trick a user into generating
and sending their data export, which contains account pubkeys, device pubkeys,
and historical transcripts (never the wrapped recovery blob — that is
explicitly excluded from exports).

### Mitigation
The export flow (§18.4) includes:
- A 5-minute cooldown between exports (rate-limits social-engineering attempts).
- Biometric re-confirmation before export generation.
- The export archive is AEAD-encrypted under a user-chosen passphrase; the
  passphrase is *not* exported and must be communicated separately. An attacker
  who obtains only the archive cannot read it without the passphrase.
- The in-app export screen warns explicitly: "Only share this file with people
  you trust completely."

### Documented residual risk
A user who chooses a weak passphrase and shares both the archive and the
passphrase with an attacker suffers full data exposure. This is equivalent to
any encrypted-archive design; no cryptographic mitigation is possible.

---

## T-PRIV-005 — Telemetry cross-correlation across DP windows

### Scope
ChessRecast emits privacy-preserving telemetry batches (§8.11). Each batch
applies a per-window Differential Privacy (DP) budget. An operator who
aggregates telemetry across multiple DP windows could potentially re-link
user activity if the per-window salt is static.

### Mitigation
- The per-window DP budget is enforced client-side and server-side.
- A **rerandomised salt** is generated for each new DP window so cross-window
  correlation requires breaking the randomness of both salts.
- Budget enforcement details are implemented in the telemetry service
  (`frontend/lib/services/p2p/telemetry/`).

### Documented residual risk
A resource-intensive adversary who can break the DP budget (e.g. via auxiliary
information) could correlate across windows. The DP parameters are set
conservatively; any budget increase requires a queue entry of
`kind: p2p_dp_budget_increase`.

---

## T-PRIV-006 — Push-token reuse across account rotations enables provider-side linkage

### Scope
When a user rotates their recovery code (§2.11), generating a fresh account
fingerprint, the push notification token (APNs / FCM) may remain the same.
The push provider can then link the old and new accounts via the unchanged
token.

### Mitigation
On every account rotation (§2.11), the client:
1. Deregisters the old push token via `DELETE /v1/push/register` (signed
   under the old device key, which the server verifies and then expires).
2. Re-registers a fresh push token under the new device key. On most devices,
   a new token is automatically issued after re-registration; if the provider
   issues the same token, the server logs it for audit but still accepts the
   new device-key binding.

The push token is stored encrypted at rest per T-M-003; the provider-side
linkage is the residual risk documented there.

### Documented residual risk
Push providers can internally correlate tokens even if the same token is
reused. This is outside ChessRecast's control. Users who require perfect
unlinkability should disable push notifications and use polling.

---

---

## Data-flow inventory

Every byte the user produces that is persisted or transmitted. Maintained per roadmap §18.1.
New `INSERT` / `WRITE` / network-egress calls in P2P-tagged code must have a corresponding row here;
the CI gate [`xops/p2p/data-flow-completeness-check.sh`](../xops/p2p/data-flow-completeness-check.sh)
enforces this automatically.

| Data class | Lifetime | Residency | At-rest encryption | Readable by | Purge trigger |
|---|---|---|---|---|---|
| Account pubkey | account lifetime | server (region per §8.5) | server KMS | operator (DSAR) | DSAR delete |
| Device pubkey | device lifetime | local + server hash | local SecureStorage / server KMS | local + DSAR | rebind / DSAR |
| Wrapped recovery blob | account lifetime | server | Argon2id + AEAD | nobody (without code) | DSAR delete |
| Transcript | game lifetime | local-only (default) | SQLCipher | local | retention cap (§0.6) |
| Chat history (player) | game lifetime | local-only | SQLCipher | local | retention cap |
| Chat history (spectator) | game lifetime | RAM-only | RAM | local | game end / leave |
| Push token | rotation cycle | server | server KMS | operator (rate-limit) | rotation / DSAR |
| Telemetry batch | DP-budget window | server | server KMS | operator (aggregate) | window expiry |
| Abuse report bundle | 90 d | operator KMS | operator KMS | operator (review) | 90 d auto-purge |
| Diag bundle (opt-in) | 90 d | operator KMS | operator KMS | operator (debug) | 90 d auto-purge |
| Forensic bundle | until upload + 90 d | local then operator | SQLCipher then KMS | operator (debug) | 90 d auto-purge |
