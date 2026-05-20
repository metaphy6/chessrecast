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

*Last updated: Phase 9 threat model implementation.*
