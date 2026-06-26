# ChessRecast — Identity and Display-Name Policy

> **Document scope:** peer-to-peer multiplayer feature.  
> **Status:** v1 — published with Phase 14 implementation.  
> **Companion:** [docs/p2p/P2P_PROTOCOL.md](P2P_PROTOCOL.md) §2, [docs/p2p/P2P_TRUST_AND_SAFETY.md](P2P_TRUST_AND_SAFETY.md) §2.

---

## 1. No central handle registry

ChessRecast does **not** operate a central handle or username registry.

- There are no unique display-name reservations.
- Display names are self-attested and carried only in `HELLO.capabilities.display_name`.
- Display names are visible only to the peer in the current session; they are not stored on the signaling server.
- Two users can choose the same display name simultaneously; the system does not prevent this and makes no uniqueness guarantee.

The authoritative identity for any peer is their **device fingerprint** (SHA-256 of their Ed25519 public key, hex-encoded). The fingerprint is always visible in the UI and is never hidden by a display name.

---

## 2. Display-name rules

A display name carried in `HELLO.capabilities.display_name` must satisfy all of the following (enforced by `frontend/lib/services/p2p/identity/handle_policy.dart`):

| Rule | Value |
|---|---|
| Maximum length | 32 Unicode grapheme clusters |
| Allowed form | NFC-normalised Unicode |
| Forbidden code points | Zero-width joiners/non-joiners, direction-override characters (U+200B–U+200F, U+202A–U+202E, U+2066–U+2069, U+FEFF) |
| Protected patterns | Must not contain: `admin`, `moderator`, `support`, `system`, `chessrecast`, `official` (case-insensitive) |

A display name that fails validation is silently ignored; the peer is shown by fingerprint only.

---

## 3. Fingerprint always visible

The device fingerprint is **always** shown in the UI, even when a display name is present.

- Minimum display: abbreviated fingerprint (first 8 hexadecimal characters of the SHA-256).
- Full fingerprint: available in the opponent info panel (tap on the abbreviated fingerprint).
- The fingerprint is the only non-repudiable identity for abuse reports, match verification, and key pinning.

This is codified as `kFingerprintAlwaysVisible = true` in `handle_policy.dart`.

---

## 4. Homoglyph / confusables protection

Full Unicode confusables protection (Unicode Technical Standard #39, confusables skeleton algorithm) is a planned §14.9.2 enhancement. In Phase 14 v1:

- Exact-match (post-NFC normalisation) of protected patterns is rejected.
- Visual confusables (e.g. Cyrillic `а` substituting for Latin `a` in the string `аdmin`) are **not** caught by the v1 implementation and must be addressed in §14.9.2.
- Users should rely on the fingerprint — not the display name — for identity assurance.

---

## 5. What the signaling server stores

The signaling server stores:

- The account fingerprint (hash of the Ed25519 public key).
- Bound device fingerprints (up to `MaxDevicesPerAccount = 8`).
- The session signaling state (offer/answer/ICE — ephemeral, purged after session close).

The signaling server does **not** store display names. There are no handle-registration API endpoints in the server (see `signaling/internal/accounts/no_handle_endpoint_test.go` for a negative test).

---

## 6. Impersonation and identity abuse

If you believe an opponent is using a display name to impersonate a known person or service:

1. The fingerprint is always different from any legitimate person's device — verify it via an out-of-band channel (e.g. compare fingerprints with your regular opponent before accepting a match request from an unknown peer).
2. Report the session using the in-game report tool (§14.3).
3. Block the device fingerprint (§14.1).

There is no name-squatting surface because there is no registry.

---

## 7. Policy updates

This policy is versioned in the repository (`docs/p2p/P2P_IDENTITY_POLICY.md`). Material changes are noted in the release notes. Current version: v1, published with Phase 14.
