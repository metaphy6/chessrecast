# Privacy Policy — ChessRecast

> **Status:** PLACEHOLDER — legal review pending.  
> See `docs/P2P_ROADMAP.md` §6.4 for the acceptance gate.  
> **Legal review checkbox:** `[ ]` *Sign off by completing the checkbox below once the full review is done.*

---

## What data ChessRecast collects

### Single-player mode (no P2P)
- **No personal data collected.** The engine runs entirely on-device. No game data leaves the device unless you explicitly export it.

### P2P mode (opt-in, controlled by `kEnableP2P` feature flag)

When P2P is enabled you choose to connect with another player over the internet. The following data is processed:

| Data | Purpose | Retention |
|---|---|---|
| Account public key (Ed25519, random — no PII by construction) | Peer identification, invite-link HMAC | Stored locally; transmitted to signaling server only to route offers |
| SDP offer / answer blobs | WebRTC session negotiation | Signaling server holds each offer for ≤ 90 s then deletes it |
| ICE candidates (may include LAN/WAN IP) | Establishing direct or TURN-relayed connections | Never persisted; ephemeral in-memory only |
| Push-wake redeem-once token (random 128-bit, no PII) | Background wakeup for incoming game invites | Signaling server stores for ≤ 90 s |
| Invite link token (HMAC-signed, carries account pubkey + nonce + expiry) | Invite flow | TTL 24 h; single-use; deleted on redemption |
| Crash reports (opt-in only, PII-scrubbed before transmission) | Improving app stability | See §Crash reporting below |

### What ChessRecast does **not** collect
- Real names, email addresses, phone numbers.
- Device identifiers (IDFA, GAID, Android ID).
- Location data.
- Game content (moves, positions) — game records are stored locally only unless you explicitly share them.

---

## Signaling server data minimisation

The signaling server (`signaling/`) is designed for **minimal data retention**:
- Offers are stored in-memory with a 90-second TTL.
- No game content transits the signaling server; it only routes the WebRTC handshake.
- No IP addresses are logged beyond the standard ephemeral access log (rotated daily, retained 7 days).
- No user accounts in the traditional sense: identity is a local key pair generated on-device.

---

## Crash reporting (opt-in)

Crash reporting is **off by default**. You must explicitly opt in.

When enabled:
- Stack traces are scrubbed for PII (IP addresses, account public keys, device UUIDs) before leaving the device — see `frontend/lib/services/p2p/telemetry/crash_reporter.dart`.
- Reports are sent to the configured sink (currently: none in production; a sink must be wired before GA — **legal review required**).
- You can revoke consent at any time in Settings → Privacy → Crash Reporting.

---

## TURN relay

When a direct WebRTC connection is not possible, traffic is relayed through a TURN server. The TURN server:
- Sees encrypted ciphertext only (XChaCha20-Poly1305 + DTLS); it cannot read game content.
- Does not log peer identifiers.
- Is operated by ChessRecast and subject to this privacy policy.

---

## Data residency

The signaling server is deployed in **[REGION PLACEHOLDER — to be filled before GA]**. TURN servers are deployed in **[REGION PLACEHOLDER]**. Data does not leave those regions.

---

## Your rights (GDPR / CCPA)

- **Access:** You can export your local identity by backing up your recovery code (§2.2).
- **Deletion:** Uninstalling the app deletes all local data. The signaling server holds no data beyond the 90-second TTL.
- **Portability:** Game transcripts can be exported in PGN format from the app.
- **Objection:** You can disable P2P at any time in Settings → P2P.

---

## Legal review checklist

Before this policy goes live (GA milestone), the following reviews must be completed:

- [ ] Legal counsel review of §Data collected in P2P mode (especially ICE candidate handling)
- [ ] GDPR Article 13 disclosure completeness review
- [ ] CCPA "Do Not Sell" applicability review (ChessRecast does not sell data; confirm language)
- [ ] Data residency placeholders filled with confirmed deployment regions
- [ ] Crash-reporting sink operator identified and added to §Crash reporting
- [ ] App Store / Google Play privacy nutrition label updated to match this policy
- [ ] In-app privacy link updated to point to published URL

> Once all checkboxes above are ticked, replace `PLACEHOLDER` in the status
> line at the top of this document and update §6.4.2 in `docs/P2P_ROADMAP.md`.

---

*Last updated: 2026-05-16 — initial placeholder draft [p2p-20260516-105107-14206]*
