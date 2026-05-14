# ChessRecast — Peer-to-Peer Multiplayer Roadmap

> **Version:** v4 · **Status banner:** 🟥 **0% shipped** — every checkbox in this document is empty (`[ ]`). No P2P code, no signaling server, no archive of the legacy backend exists yet. Everything below is design intent until a checkbox is ticked by a commit on `main`.
>
> **Companion docs:** [AGENTS.md](../AGENTS.md), [.github/copilot-instructions.md](../.github/copilot-instructions.md), [docs/coding/ai/automation.md](coding/ai/automation.md), [docs/game/GAME_MODS_DOCUMENTATION.md](game/GAME_MODS_DOCUMENTATION.md), [docs/game/DRAW_RULES.md](game/DRAW_RULES.md). When this roadmap and AGENTS.md disagree on cross-cutting policy (commit/push, tests-with-code, system safety), **AGENTS.md wins**. This document is authoritative only for P2P scope, sequencing, and acceptance gates.

## Status legend (apply to every `[ ]` in this doc)

- `[ ]` — **Not started.** No code, no test, no infra. Default state for v4.
- `[~]` — **Partial / in progress.** A commit has landed but the acceptance gate at the end of the sub-phase has not yet been met. Must cite the in-progress queue entry id from [agent/queue.yaml](../agent/queue.yaml).
- `[x]` — **Done and gated.** A commit on `main` has shipped the work, the proof test(s) listed for the bullet are green in CI, and the relevant KPI baseline (if applicable) was updated in `agent/baselines/p2p*.json`. Must cite the commit SHA and the proof-test path inline, e.g. `[x] (sha 1a2b3c4d, [frontend/test/p2p/foo_test.dart](../frontend/test/p2p/foo_test.dart))`.

> **Tick discipline.** A box may be ticked **only** when (a) the code is on `origin/main`, (b) the proof tests cited beside it are green, (c) any new failure mode it introduces is reflected in [Phase 10 — Failure-mode catalog](#phase-10--failure-mode-catalog), and (d) any new threat surface is reflected in [Phase 9 — Threat model](#phase-9--threat-model). Half-ticks are recorded as `[~]`, never as `[x]`.

## What changed in v4 vs v3

- [ ] **Checkbox discipline added end-to-end.** Every actionable line is now a `[ ]` checkbox so partial / done states can be tracked at-a-glance.
- [ ] **Per-phase Quality Attributes block.** Each phase carries an explicit *Performance · Efficiency · Stability · Reliability · Integrity* sub-section with measurable acceptance criteria, not vibes. v3 mixed these into prose; v4 separates them so they can be gated independently.
- [ ] **Proof-test gaps closed.** v3 had strong unit/integration coverage but under-specified proof tests for: Phase 0 cleanup invariants, Phase 2 recovery-flow chaos, Phase 3 signaling server load + abuse, Phase 4 NAT / IPv6-only / path-MTU, Phase 6 beta telemetry sanity, supply-chain integrity (SBOM diff, dependency confusion). v4 adds them.
- [ ] **Wrong / fragile assumptions corrected.** v3 assumed (a) `RTCDataChannel` SCTP ordered+reliable is sufficient for clock sync — *no, clock sync needs an unreliable side-channel or NTP-style RTT estimator on the same channel*; (b) Argon2id `m=64MB` is universally affordable on low-end Android — *flagged as device-class adaptive*; (c) Play Integrity / DeviceCheck only on rebind — *expanded to also gate first-time signaling-server registration on hostile-region heuristics*; (d) "deterministic CBOR is enough for replay parity" — *no, also need canonical move-list normalisation for promotions, en-passant disambiguation, and mod-specific king-move tags*; (e) "litestream WAL replication = HA" — *no, that's DR not HA; HA needs a second active replica or graceful degraded mode*.
- [ ] **New cross-cutting subsections.** Battery & thermal budget (Phase 4 + Phase 8), accessibility for connection-state UI (Phase 8), supply-chain provenance (Phase 8), legal/data-residency for signaling and TURN (Phase 6/8), licence audit for libsodium / coturn / litestream (Phase 8).
- [ ] **Engine-correlation hooks.** P2P feature must not regress single-player engine KPIs (`agent/baselines/<mod>.json`); v4 adds a Phase 5 gate that re-runs the per-mod regression suite on every signaling-touching change because shared services (analytics, lifecycle, native-lib loader) can leak.
- [ ] **Failure-mode catalog grew from 41 to ≥60 codes** (storage corruption, web/desktop variants, push-notification deferral, biometric re-key failures, deep-link cold-start races, CRDT-style late-join collisions).
- [ ] **Sequencing graph revised.** Phase 3 (signaling) and Phase 2 (identity) were drawn as strictly serial in v3; in v4 they overlap from week 2 onward because identity bytes block signaling registration but server scaffolding does not.

## Mission

Replace the current single-player + legacy backend matchmaking with **direct, end-to-end-encrypted, peer-to-peer multiplayer** that:

- works with **no central game-state server** (signaling + TURN are the only server roles),
- preserves the seven-mod chess engine bit-for-bit between peers (replay parity),
- survives realistic mobile conditions: NAT, captive portals, network handoffs, app suspension, low battery, hostile peers,
- is **forward-secret** (per-session keys), **identity-stable** (long-term Ed25519 device keys + recoverable account keys), and **abuse-resistant** (rate-limited signaling, proof-of-work fallback, push-spam ceiling),
- never regresses single-player engine strength (per-mod KPIs in `agent/baselines/<mod>.json`).

## Guiding principles (load-bearing)

1. **Replay parity over feature speed.** A move is legal iff both peers' native engines compute the same legal-move set from the same board state. If they disagree, the session ends with `MISMATCH` and a forensic bundle is written locally — *never* a "trust the server" fallback.
2. **Identity is local, recovery is opt-in.** The Ed25519 device key never leaves the device unencrypted. Account-level recovery (across devices) is opt-in, requires Argon2id-wrapped backup, and is independent of the signaling server's database.
3. **Signaling server is dumb on purpose.** It brokers SDP offers/answers, ICE candidates, and push wakeups. It does **not** see plaintext moves, board state, or chat. Compromise of the signaling server must not break confidentiality of past or future games.
4. **Test pyramid is non-negotiable.** Every phase ships with the test layers listed in [Phase 5](#phase-5--test-and-ci-strategy). No phase is "done" without proof tests.
5. **Engine correlation.** A P2P change that regresses any per-mod engine KPI in `agent/baselines/<mod>.json` by >5% is a hard revert, exactly as in [.github/copilot-instructions.md](../.github/copilot-instructions.md) Hard rules → 4.
6. **No silent fallbacks.** Every degradation (TURN relay engaged, push wakeup used, recovery code consumed) is surfaced in UI and recorded in local telemetry.

## Glossary

| Term | Definition |
|---|---|
| **Peer** | A device running ChessRecast holding a long-term Ed25519 device key. |
| **Account** | A user-level identity; one or more peers may attach to it via the recovery flow. |
| **Session** | One game between two peers, with a fresh symmetric key derived via X25519 ECDH + HKDF. |
| **Signaling server** | A Go service that brokers offers/answers/ICE candidates and queues push wakeups. Stores no game state. |
| **TURN** | A coturn relay used when direct ICE fails. Carries opaque ciphertext; it learns peer IPs and traffic volume only. |
| **STUN** | A coturn binding-discovery endpoint (free, public is acceptable but a self-hosted twin is preferred for reliability metrics). |
| **Recovery code** | A 16-word BIP-39-style mnemonic that, with Argon2id, unwraps an account-key backup. Held by the user, never by the server. |
| **Replay parity** | Property that two peers' native engines, fed the same UCI move list and same mod, reach byte-identical board states for every ply. |
| **Push wake** | An APNs / FCM payload that wakes the recipient app to attempt to redeem a pending offer. Carries no game data. |
| **Rebind** | A server-side action of re-associating an account with a fresh device key (after device loss). Gated by recovery code + integrity attestation. |

## Architecture overview

```
┌─────────────┐                ┌─────────────┐
│  Peer A     │                │  Peer B     │
│ (Flutter +  │                │ (Flutter +  │
│  native C)  │                │  native C)  │
└──────┬──────┘                └──────┬──────┘
       │                              │
       │  1. Register / heartbeat     │
       │     (Ed25519-signed)         │
       ▼                              ▼
   ┌────────────────────────────────────┐
   │   Signaling Server (Go, stateless  │
   │   per-request; SQLite + litestream │
   │   for accounts & pending offers)   │
   └─────────┬─────────────────┬────────┘
             │  2. SDP offer   │  2'. SDP answer
             │     + ICE       │      + ICE
             ▼                 ▼
       ┌──────────────────────────┐
       │   3. WebRTC SCTP         │
       │      DataChannel         │
       │   (E2E: X25519 + HKDF +  │
       │    ChaCha20-Poly1305)    │
       └──────────────────────────┘
                │
                │  4. CBOR-framed protocol
                │     (move, ack, sync, chat,
                │      resign, draw-offer, …)
                ▼
       ┌──────────────────────────┐
       │   Native engine (FFI)    │
       │   validates every move   │
       │   from peer (no trust)   │
       └──────────────────────────┘

   Side channels:
   - APNs / FCM push wake (no game data)
   - TURN relay (opaque ciphertext) when direct ICE fails
```

---

## Phase 0 — Cleanup of the legacy backend

**Goal:** Remove the existing client→server game-state coupling so Phase 1+ can land without bit-rot. *0% complete.*

### 0.1 Inventory and freeze

- [ ] Enumerate every Dart symbol referencing the legacy HTTP / WebSocket backend. Source files known to be in scope: [frontend/lib/services/api_service.dart](../frontend/lib/services/api_service.dart), [frontend/lib/services/game_websocket.dart](../frontend/lib/services/game_websocket.dart), [frontend/lib/services/saved_game.dart](../frontend/lib/services/saved_game.dart), [frontend/lib/services/saved_games_service.dart](../frontend/lib/services/saved_games_service.dart). Output: `docs/code/LEGACY_BACKEND_USAGES.md` listing every call site (file, symbol, purpose). **Proof test:** `frontend/test/legacy/legacy_usages_inventory_test.dart` — fails if any new file in `frontend/lib/**` (added after the freeze) imports a symbol from one of the four legacy files.
- [ ] Freeze the Go backend: tag the last legacy commit (`backend-legacy-final`), update `backend/README.md` with the freeze notice and a pointer to this roadmap. **Proof:** `git tag --list backend-legacy-final` returns the tag.
- [ ] Snapshot the legacy API contract (OpenAPI / proto-equivalent) under [docs/P2P_LEGACY_API_SNAPSHOT.md](P2P_LEGACY_API_SNAPSHOT.md) so Phase 0.4 can prove "no live caller is left".

### 0.2 Decouple via local stubs

- [ ] Introduce `frontend/lib/services/saved_games_local.dart` with a SQLite (sqflite/drift) backing store; mirror `SavedGamesService` API. **Proof test:** `frontend/test/services/saved_games_local_test.dart` covering create / list / load / delete / migration round-trip plus a fuzz test for malformed SQLite rows.
- [ ] Add a feature flag `kUseLegacyBackend` defaulting to `false` in [frontend/lib/constants.dart](../frontend/lib/constants.dart). **Proof:** widget test that flipping the flag does not crash any screen.
- [ ] Replace every call site identified in 0.1 with the local stub when `kUseLegacyBackend` is `false`. **Proof test:** `frontend/test/legacy/no_legacy_calls_when_flag_off_test.dart` — runs the app shell and asserts zero outbound HTTP/WebSocket calls to the legacy host.

### 0.3 Archive the Go backend

- [ ] `git mv backend/ archive/backend-go-legacy/` and add `archive/README.md` explaining the freeze. **Proof:** `git log --diff-filter=R -- backend/` shows the rename; CI fails if `backend/` reappears.
- [ ] Remove `docker-compose.yml` from repo root (was pulling the legacy backend); replace with `docker-compose.signaling.yml` (empty stub for Phase 3). **Proof:** `docker compose -f docker-compose.yml config` no longer references the legacy backend.
- [ ] Update [README.md](../README.md) to remove "run the backend" instructions and add a "P2P preview not yet shipped" banner.

### 0.4 Quality attributes

- [ ] **Performance:** Local SQLite saved-games path must serve 1000-game list in <50 ms cold and <10 ms warm on a low-end Android (Pixel 4a class). **Proof:** `frontend/test/perf/saved_games_local_perf_test.dart`.
- [ ] **Efficiency:** Cleanup must reduce APK size by ≥1.2 MB (no more http/web_socket_channel imports for game state). **Proof:** size diff in CI artefact `frontend/build/size-report.txt`.
- [ ] **Stability:** Zero regressions in the per-mod regression suites after the cleanup. **Proof:** all seven `<mod>_engine_regression_test.dart` green; CI gate.
- [ ] **Reliability:** Migration from any pre-existing legacy save format (JSON-on-disk, if present) to local SQLite is idempotent and survives mid-write crash injection. **Proof:** `frontend/test/services/saved_games_local_migration_chaos_test.dart`.
- [ ] **Integrity:** No legacy backend URL or secret remains in the repo after 0.3. **Proof:** `frontend/tool/scan_secrets.dart` clean; explicit grep test in CI.

### 0.5 Acceptance gate

- [ ] All 0.1–0.4 boxes ticked, all proof tests green, commit pushed, the "P2P preview not yet shipped" banner is live in `README.md`.

---

## Phase 1 — Wire protocol (CBOR over SCTP DataChannel)

**Goal:** Define and implement a versioned, deterministic, replay-parity-safe wire format for moves, acks, sync, chat, draw/resign, and protocol housekeeping. *0% complete.*

### 1.1 Spec

- [ ] Author [docs/P2P_PROTOCOL.md](P2P_PROTOCOL.md) v0 covering: frame envelope, frame types, version negotiation, error codes, MUST/SHOULD per RFC 2119. Encode with **deterministic CBOR (RFC 8949 §4.2)** — sorted map keys, shortest-form integers, no indefinite-length strings.
- [ ] Frame envelope fields: `v: u8` (protocol version), `t: u8` (frame type), `n: u64` (monotonic per-sender sequence), `ts: u64` (sender wall clock, ms), `payload: bytes`. **Wrong v3 assumption corrected:** clock sync cannot rely on `ts` alone over an ordered+reliable SCTP channel; we add an unreliable companion frame `PING/PONG` with `ord=false, reliable=false` (separate `RTCDataChannel`) for RTT estimation, mirroring NTP's offset/delay computation.
- [ ] Frame types (initial): `HELLO`, `HELLO_ACK`, `MOVE`, `MOVE_ACK`, `SYNC_REQ`, `SYNC_RESP`, `DRAW_OFFER`, `DRAW_RESPONSE`, `RESIGN`, `CHAT`, `PING`, `PONG`, `BYE`, `MISMATCH`. Each has a strict CBOR schema in the spec.
- [ ] **Move-list canonicalisation** (corrects v3 wrong assumption that "deterministic CBOR is enough"): UCI strings normalised — promotion piece always lowercase, en-passant disambiguated by source square, mod-specific king moves (e.g. Heir's second king, Kings Battle phase-2 king walks) tagged with explicit `actor=king_a|king_b`. **Proof:** `frontend/test/p2p/move_canonical_test.dart`.

### 1.2 Implementation

- [ ] `frontend/lib/services/p2p/protocol/frame.dart` — pure-Dart codec. No I/O. **Proof tests:** `frontend/test/p2p/protocol/frame_codec_test.dart` (round-trip), `frontend/test/p2p/protocol/frame_fuzz_test.dart` (≥100k random/malformed inputs, no panics, all rejected with typed errors), `frontend/test/p2p/protocol/frame_determinism_test.dart` (re-encoding any decoded frame produces byte-identical output).
- [ ] `frontend/lib/services/p2p/protocol/session.dart` — state machine: `idle → handshake → playing → finished | aborted`. Transitions documented in `docs/P2P_PROTOCOL.md` §state-machine. **Proof:** `frontend/test/p2p/protocol/session_state_test.dart` (every illegal transition raises typed `ProtocolStateError`).
- [ ] Sequence-number monotonicity enforced; out-of-order or duplicate `n` for a sender → `MISMATCH`. **Proof:** `frontend/test/p2p/protocol/sequence_test.dart`.
- [ ] `MISMATCH` writes a forensic bundle (last 64 frames, both sides' move lists, mod, native lib SHA) to `getApplicationDocumentsDirectory()/p2p/forensics/<session-id>/`. **Proof:** `frontend/test/p2p/protocol/mismatch_forensics_test.dart`.

### 1.3 Engine binding

- [ ] `frontend/lib/services/p2p/engine_binding.dart` — given mod + UCI move list, validates each remote move via the existing native engine (no trust). Rejects with `ILLEGAL_MOVE` → `MISMATCH`. **Proof:** `frontend/test/p2p/engine_binding_test.dart` per mod (×7).
- [ ] **Engine-correlation gate:** the per-mod regression suites must remain green after this binding lands. **Proof:** CI runs all seven `<mod>_engine_regression_test.dart` on every commit touching `frontend/lib/services/p2p/**`.

### 1.4 Quality attributes

- [ ] **Performance:** Frame encode + decode < 50 µs P99 on a Pixel 4a class CPU; `MOVE` round-trip path (encode → channel mock → decode → engine validate → ack encode) < 2 ms P99. **Proof:** `frontend/test/p2p/perf/frame_perf_test.dart`.
- [ ] **Efficiency:** Average `MOVE` frame ≤ 48 bytes on the wire (CBOR-encoded, pre-encryption). **Proof:** `frontend/test/p2p/perf/frame_size_test.dart`.
- [ ] **Stability:** State machine has no reachable deadlocks; verified by exhaustive symbolic exploration of the documented transitions. **Proof:** `frontend/test/p2p/protocol/session_state_exhaustive_test.dart`.
- [ ] **Reliability:** Fuzz suite (1M iterations nightly in CI) finds zero panics, zero hangs > 10 ms per frame. **Proof:** nightly CI job artifact.
- [ ] **Integrity:** Re-encoding any externally-supplied frame is byte-identical to the input (deterministic CBOR holds). **Proof:** part of `frame_determinism_test.dart`.

### 1.5 Acceptance gate

- [ ] All 1.1–1.4 boxes ticked, `docs/P2P_PROTOCOL.md` v0 published, all proof tests green, commit pushed, KPI baseline `agent/baselines/p2p_protocol.json` created (encode/decode latency, frame size).

---

## Phase 2 — Identity, key management, and recovery

**Goal:** Long-term per-device Ed25519 keys, per-session X25519 ephemeral keys, opt-in account-level recovery. Keys never leave the device unencrypted; recovery is offline-first and server-independent in the cryptographic critical path. *0% complete.*

### 2.1 Device identity

- [ ] Generate Ed25519 keypair on first launch via libsodium FFI ([package:cryptography](https://pub.dev/packages/cryptography) is the Dart fallback for unit tests; production uses libsodium FFI for constant-time guarantees). **Proof:** `frontend/test/p2p/identity/device_key_gen_test.dart`.
- [ ] Persist private key in **platform secure storage**: iOS Keychain (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`), Android Keystore (StrongBox preferred, hardware-backed required, fallback policy documented), macOS Keychain, Windows DPAPI/NCRYPT, Linux libsecret + fallback to Argon2id-wrapped on-disk file. **Proof tests** per platform: `frontend/test/p2p/identity/secure_storage_<platform>_test.dart` (mocked where SDK unavailable in CI).
- [ ] Public-key fingerprint format: lowercase Base32 of `SHA-256(pubkey)[:10]` grouped `xxxx-xxxx-xx`. Surfaced in UI as "Device ID". **Proof:** `frontend/test/p2p/identity/fingerprint_test.dart`.
- [ ] **Re-key after biometric/PIN failure threshold:** after N consecutive auth failures (configurable, default 10), private key is wiped and account marked "needs recovery". **Proof:** `frontend/test/p2p/identity/biometric_lockout_test.dart`.

### 2.2 Account recovery (opt-in)

- [ ] User opts in by setting a recovery code (BIP-39 wordlist, 16 words ≈ 176 bits entropy). Words drawn from libsodium-validated entropy. **Proof:** `frontend/test/p2p/identity/recovery_code_entropy_test.dart` (statistical χ² over 1M generations).
- [ ] Account key (separate from device key) wrapped with Argon2id: `m=64MB, t=3, p=1` on flagship, **device-class-adaptive** (`m=32MB, t=4` on low-end Android per `getTotalMem` thresholds; documented in [docs/P2P_PROTOCOL.md](P2P_PROTOCOL.md) §recovery). v3 wrong assumption corrected. **Proof:** `frontend/test/p2p/identity/argon2_adaptive_test.dart`.
- [ ] Wrapped backup uploaded to signaling server **only after** opt-in checkbox + explicit "I have written down the words" confirmation. Server stores `wrapped_blob, account_pub, kdf_params`. Server cannot derive plaintext. **Proof:** `signaling/internal/recovery/recovery_test.go` covers end-to-end with a simulated client.
- [ ] **Recovery flow:** on a new device, user enters 16 words → Argon2id-derived KEK unwraps the blob → fresh device key is generated → server **rebind** call signed with the recovered account key + Play Integrity / DeviceCheck attestation token (v3 was rebind-only; v4 also gates first registration in flagged hostile-source regions). **Proof:** `frontend/test/p2p/identity/recovery_flow_test.dart` + `signaling/internal/rebind/rebind_test.go`.
- [ ] **Account migration drill:** documented user-facing flow + `frontend/test/p2p/identity/account_migration_chaos_test.dart` simulating: (a) old device still online, (b) old device offline forever, (c) old device returning after rebind (must surface "this device has been replaced" and self-quarantine).

### 2.3 Session key derivation

- [ ] Per-session: each peer generates an X25519 ephemeral keypair, signs the public key with its Ed25519 long-term key, exchanges via signaling. Shared secret = X25519(my_eph, their_eph_pub). Session key = HKDF-SHA256(shared, salt=session_id, info="chessrecast/p2p/v1"). **Proof:** `frontend/test/p2p/identity/session_kdf_test.dart` (KAT vectors).
- [ ] **Forward secrecy property:** verified by destroying ephemeral keys at session end and proving prior session ciphertexts cannot be decrypted with current state. **Proof:** `frontend/test/p2p/identity/forward_secrecy_test.dart`.
- [ ] Symmetric AEAD: ChaCha20-Poly1305, 96-bit nonce = `session_id_lo32 || sender_dir1 || seq_u64_be` (deterministic, never reused). **Proof:** nonce-uniqueness fuzz `frontend/test/p2p/identity/aead_nonce_test.dart`.

### 2.4 Quality attributes

- [ ] **Performance:** Argon2id derivation completes in <1.5 s on flagship, <4 s on low-end (within adaptive params). **Proof:** `frontend/test/p2p/perf/argon2_perf_test.dart`.
- [ ] **Efficiency:** Wrapped backup blob ≤ 256 bytes; uploaded once, refreshed only on user-initiated re-key. **Proof:** asserted in `recovery_test.go`.
- [ ] **Stability:** Key wipe after biometric lockout is atomic (no half-state where device key is unusable but app thinks it can sign). **Proof:** `frontend/test/p2p/identity/wipe_atomicity_test.dart` with crash injection.
- [ ] **Reliability:** Recovery succeeds on every supported platform with the same 16 words (cross-platform KDF determinism). **Proof:** `frontend/test/p2p/identity/recovery_cross_platform_kat_test.dart`.
- [ ] **Integrity:** Account-key wrapped blob is integrity-protected (AEAD, AAD = `account_pub || kdf_params`). Tampered blob fails to unwrap with a typed error, never with silent garbage output. **Proof:** `frontend/test/p2p/identity/wrapped_blob_aead_test.dart`.

### 2.5 Acceptance gate

- [ ] All 2.1–2.4 ticked, recovery user flow has a documented runbook in [docs/P2P_RECOVERY_RUNBOOK.md](P2P_RECOVERY_RUNBOOK.md), all proof tests green on iOS / Android / Linux / macOS / Windows / web (best-effort: web uses non-extractable WebCrypto Ed25519, recovery flow is reduced).

---

## Phase 3 — Signaling server (Go)

**Goal:** Stateless-per-request signaling with SQLite + litestream replication, rate-limited, observable, abuse-resistant. Stores accounts, pending offers, push tokens. Stores **no** game data. *0% complete.*

### 3.1 Project scaffold

- [ ] `signaling/` Go module: `cmd/signaling-server`, `internal/{accounts,offers,push,rebind,ratelimit,attest,store}`, `pkg/api`. **Proof:** `signaling/Makefile` builds the binary; `go vet` and `staticcheck` clean in CI.
- [ ] HTTP/3 (QUIC) + HTTP/2 fallback. Frameworks: stdlib `net/http` + `quic-go`. No web framework dependency. **Proof:** `signaling/internal/server/transport_test.go` exercises both.
- [ ] Auth: every authenticated endpoint requires an Ed25519 signature over `(method, path, ts, body_sha256)` with `ts` within ±60 s; replay-protected via short-lived `ts → seen` cache. **Proof:** `signaling/internal/auth/sig_test.go` + replay-attack test.

### 3.2 Endpoints (HTTPS / HTTP-3)

- [ ] `POST /v1/accounts/register` — first-time registration, body signed with new device key. Optionally carries a wrapped recovery blob (Phase 2.2). Hostile-region requests gated by integrity attestation.
- [ ] `POST /v1/accounts/rebind` — recovery flow; signed with recovered account key + integrity attestation.
- [ ] `POST /v1/offers` — push an SDP offer to a peer; payload is opaque (encrypted client-side under the account key of the recipient if known, else plain SDP — SDP itself is not secret, the data channel is).
- [ ] `GET /v1/offers/poll` — long-poll (max 25 s) for pending offers; returns immediately if any.
- [ ] `POST /v1/offers/{id}/answer` — submit SDP answer.
- [ ] `POST /v1/ice/{session}` — relay ICE candidates (small JSON), authenticated.
- [ ] `POST /v1/push/register` — APNs/FCM token; one per device key.
- [ ] `POST /v1/push/wake` — request the server send a content-less push to a peer (rate-limited per `(sender, recipient)`, daily ceiling).
- [ ] `GET /v1/health` — liveness; `GET /v1/ready` — readiness (DB reachable, push provider reachable).
- [ ] `GET /v1/metrics` — Prometheus exposition (admin-token gated).

### 3.3 Storage

- [ ] SQLite WAL with `litestream` replication to S3-compatible object storage. **Wrong v3 claim corrected:** litestream provides DR (cold restore), not HA. v4 adds: a hot read-replica via litestream's `replicate` + a graceful read-only mode the server enters when the writable store is unavailable. **Proof:** `signaling/internal/store/ha_degraded_test.go`.
- [ ] Schema migrations via `golang-migrate`; forward-only. **Proof:** `signaling/internal/store/migrate_test.go`.
- [ ] PII minimisation: store account pubkey, push token (encrypted at rest with server KMS key), wrapped recovery blob, `last_seen_ts`, IP-coarsened (`/24` IPv4, `/48` IPv6) for abuse heuristics only. **Proof:** schema review + `signaling/internal/store/pii_audit_test.go` (greps schema for forbidden columns).
- [ ] Retention: pending offers TTL = 5 min, push tokens auto-purged after 30 d of inactivity, rebound accounts keep an audit row for 90 d. **Proof:** `signaling/internal/store/retention_test.go`.

### 3.4 Rate limiting and abuse resistance

- [ ] Per-IP token bucket (refill 10/min, burst 30) at edge. **Proof:** `signaling/internal/ratelimit/ip_test.go`.
- [ ] Per-account token bucket (refill 60/min, burst 120) for authenticated endpoints. **Proof:** `signaling/internal/ratelimit/account_test.go`.
- [ ] Per-`(sender, recipient)` push wakeup ceiling: 50/day, exponential backoff after 5 ignored wakes. **Proof:** `signaling/internal/push/wake_ceiling_test.go`.
- [ ] **Proof-of-work fallback** for register / rebind under burst: scrypt-based PoW challenge from the server, difficulty adjusted by sliding-window QPS. **Proof:** `signaling/internal/abuse/pow_test.go` + load test that confirms PoW kicks in under synthetic abuse.
- [ ] Hostile-region heuristics: GeoIP + ASN risk score; high-risk requests require Play Integrity / DeviceCheck attestation even on first registration (v4 expansion of v3 rebind-only attestation). **Proof:** `signaling/internal/attest/integrity_test.go`.

### 3.5 Observability

- [ ] Prometheus metrics: per-endpoint latency histograms, error counters, rate-limit drops, PoW issuances, push success/fail per provider, DB connection-pool stats. **Proof:** `signaling/internal/metrics/metrics_test.go` asserts metric registration; CI scrapes a test instance.
- [ ] Structured logs (JSON) with `request_id`, `account_id_hash`, `endpoint`, `latency_ms`, `outcome`, `region_coarse`. **No PII** (no IP, no push token, no SDP body). **Proof:** `signaling/internal/log/redaction_test.go`.
- [ ] OpenTelemetry traces (OTLP/gRPC) for the full request path including DB and push provider calls. **Proof:** `signaling/internal/tracing/tracing_test.go`.
- [ ] Alerts (runbook in [docs/P2P_SIGNALING_RUNBOOK.md](P2P_SIGNALING_RUNBOOK.md)): readiness-down >2 min, error-rate >1% over 5 min, push-fail >5% over 15 min, PoW issuance >1 Hz sustained.

### 3.6 Quality attributes

- [ ] **Performance:** P50 < 30 ms, P99 < 250 ms for `/v1/offers/poll` (excluding long-poll wait), P99 < 80 ms for `/v1/ice/*` and `/v1/offers`. **Proof:** k6/vegeta load test pipeline `signaling/loadtest/` + report artefact.
- [ ] **Efficiency:** Server fits in a single 1 vCPU / 512 MB instance up to 1k concurrent long-polls. **Proof:** load test report.
- [ ] **Stability:** 24-hour soak at 50% peak load: zero memory growth (>5%/hour), zero goroutine leaks. **Proof:** soak job in CI nightly.
- [ ] **Reliability:** Chaos suite — kill -9 mid-write, disk-full, network partition to S3 (litestream backlog), push provider 5xx burst, NTP skew ±5 min. Each scenario must either succeed or fail closed with a typed error. **Proof:** `signaling/test/chaos/`.
- [ ] **Integrity:** Every authenticated request signature is verified before any DB read; no DB read leaks the existence of an unknown account (uniform "no offers" response timing). **Proof:** `signaling/internal/auth/timing_test.go` (statistical timing-side-channel test).

### 3.7 Deployment

- [ ] Container image: distroless-base, non-root, read-only filesystem, seccomp profile attached. **Proof:** `signaling/Dockerfile` + `signaling/.docker/seccomp.json`; image scan in CI (`trivy --severity HIGH,CRITICAL`).
- [ ] IaC under `signaling/deploy/` (Terraform) — must be idempotent, no plan drift on no-op apply. **Proof:** CI re-applies and asserts `terraform plan` is empty.
- [ ] Multi-region: 2 regions active-active with anycast or latency-based DNS; per-region SQLite + litestream; cross-region eventual consistency (offer routing tolerant of momentary visibility lag, max 5 s). **Proof:** `signaling/test/multiregion/visibility_lag_test.go`.

### 3.8 Acceptance gate

- [ ] All 3.1–3.7 ticked, soak + chaos green for one week, runbook published, on-call rotation defined.

---

## Phase 4 — WebRTC transport and NAT traversal

**Goal:** Reliable peer-to-peer DataChannel under realistic mobile conditions: NATs, captive portals, IPv6-only, network handoff, suspension. *0% complete.*

### 4.1 ICE / STUN / TURN

- [ ] Wire ICE: 1 STUN (self-hosted twin) + 2 TURN (UDP + TCP/443 fallback for restrictive networks). **Proof:** `frontend/test/p2p/transport/ice_candidate_gather_test.dart`.
- [ ] TURN credentials short-lived (5 min) HMAC-SHA256-issued by signaling server; never long-lived static creds. **Proof:** `signaling/internal/turn/cred_test.go` + integration `frontend/test/p2p/transport/turn_cred_refresh_test.dart`.
- [ ] **IPv6-only carriers**: explicitly tested path with synthetic NAT64/DNS64 + path-MTU clamp at 1280. **Proof:** `frontend/test/p2p/transport/ipv6_only_test.dart` (mocked) + manual matrix entry in [docs/P2P_NAT_MATRIX.md](P2P_NAT_MATRIX.md).
- [ ] **NAT type matrix**: documented coverage for cone / restricted-cone / port-restricted-cone / symmetric × 2 peers; symmetric × symmetric forces TURN. **Proof:** `frontend/test/p2p/transport/nat_matrix_test.dart`.

### 4.2 DataChannel configuration

- [ ] Two channels: `chess` (ordered, reliable, max-retransmits=∞) for protocol frames; `clock` (unordered, max-retransmits=0) for `PING/PONG` and clock-sync side traffic (corrects v3 wrong assumption). **Proof:** `frontend/test/p2p/transport/datachannel_config_test.dart`.
- [ ] SCTP buffer / send-queue thresholds tuned to drop the session on backpressure > 256 KB sustained for 5 s, surfaced as `BACKPRESSURE_DROP`. **Proof:** `frontend/test/p2p/transport/backpressure_test.dart`.
- [ ] Per-frame size cap: 16 KB (well under SCTP defaults). **Proof:** `frontend/test/p2p/transport/frame_size_cap_test.dart`.

### 4.3 Lifecycle

- [ ] Network change (Wi-Fi ↔ cellular, VPN toggle) triggers ICE restart, not session teardown, if the encrypted session key is still valid (under 30 min). **Proof:** `frontend/test/p2p/transport/network_change_ice_restart_test.dart`.
- [ ] App suspension: on Android, a foreground service keeps the connection alive during in-game; on iOS, VoIP-style background mode is **not** abused — instead, connection is gracefully closed and a push wakeup re-establishes. **Proof:** `frontend/test/p2p/transport/android_foreground_service_test.dart`, `frontend/test/p2p/transport/ios_suspend_resume_test.dart`.
- [ ] Push wakeup → in-app cold-start → handshake completion P95 < 5 s on a warm cache. **Proof:** `frontend/test/p2p/perf/push_wake_cold_start_test.dart`.
- [ ] iOS Notification Service Extension (NSE) decrypts the wakeup payload (no game data, just `session_hint`) and pre-warms the app (best-effort). **Proof:** `frontend/test/p2p/transport/ios_nse_test.dart`.
- [ ] Deep-link cold-start race: tapping a "Join game" notification while the app is launching does not lose the offer. **Proof:** `frontend/test/p2p/transport/deeplink_cold_start_test.dart`.

### 4.4 Quality attributes

- [ ] **Performance:** Direct (no TURN) move RTT P50 < 80 ms in same-country, P95 < 200 ms; TURN-relayed P95 < 350 ms. **Proof:** synthetic-network test harness `frontend/test/p2p/perf/rtt_*_test.dart` + a real-world beta dashboard panel.
- [ ] **Efficiency:** Battery — sustained 30-min session must not exceed 4% battery on a Pixel 6 / iPhone 13 reference device (screen-on baseline subtracted). **Proof:** documented manual test + CI proxy `frontend/test/p2p/perf/cpu_budget_test.dart` enforcing CPU ≤ 6% average over a 5-min synthetic session.
- [ ] **Efficiency:** Thermal — no thermal-throttle event in a 30-min session at 25 °C ambient. **Proof:** documented manual matrix.
- [ ] **Stability:** 1000 synthetic move exchanges with random 0–500 ms jitter and 0–2% loss: zero session drops, zero `MISMATCH`, zero memory growth >5%. **Proof:** `frontend/test/p2p/transport/long_run_stability_test.dart`.
- [ ] **Reliability:** Network-change suite: airplane-mode toggle, Wi-Fi reconnect, cellular handoff, VPN on/off — each must heal within 10 s or end the session with a typed `NETWORK_LOST`. **Proof:** `frontend/test/p2p/transport/network_chaos_test.dart`.
- [ ] **Integrity:** Every byte arriving on `chess` channel is AEAD-decrypted and CBOR-validated before reaching the engine. Drop with `BAD_FRAME` on any failure. **Proof:** `frontend/test/p2p/transport/aead_decrypt_path_test.dart`.

### 4.5 Acceptance gate

- [ ] All 4.1–4.4 ticked, NAT matrix documented and verified, beta-network telemetry shows P95 RTT under target on real users.

---

## Phase 5 — Test and CI strategy (the 9-layer pyramid)

**Goal:** Every phase ships with proof at every relevant layer of the pyramid. *0% complete.*

The 9 layers, smallest-fastest at the top:

- [ ] **L1 — Pure unit tests** (codec, KDF, state machine). Target: <50 ms each, run on every save in IDE.
- [ ] **L2 — Property tests** (codec round-trip, state-machine transitions). Run in CI, ≥1k iterations.
- [ ] **L3 — Fuzz tests** (frame parser, signature verifier, recovery-blob unwrap). Nightly, ≥1M iterations.
- [ ] **L4 — Engine-correlation tests** (per-mod regression suites stay green on every P2P change). CI gate.
- [ ] **L5 — Synthetic-network integration** (two `Session` instances + a fake transport with jitter/loss/reorder). CI gate.
- [ ] **L6 — Real WebRTC integration** (two flutter_driver-controlled apps over loopback / LAN). CI nightly + on release branches.
- [ ] **L7 — Server load + chaos** (signaling server under k6 + chaos toolkit). CI nightly.
- [ ] **L8 — Cross-platform device matrix** (iOS / Android / Web / Linux / macOS / Windows). CI on release branches via device farm.
- [ ] **L9 — Beta production telemetry** (real users; KPIs in [docs/P2P_BETA_KPIS.md](P2P_BETA_KPIS.md)). Continuous.

### 5.1 CI wiring

- [ ] GitHub Actions matrix: per-OS, per-platform, per-mod. Cache pub + cargo + go modules + the native engine `.so/.dylib/.dll`. **Proof:** `.github/workflows/p2p-ci.yml` exists and is green.
- [ ] Hermetic builds: pinned Flutter / Dart / Go versions in `.tool-versions` + `mise` (or asdf) onboarding script. **Proof:** `scripts/p2p/bootstrap-dev.sh` builds from a clean Ubuntu image in CI.
- [ ] Artefact retention: load-test + chaos reports kept ≥30 d under `agent/reports/p2p/<run-id>/`.

### 5.2 KPI baselines

- [ ] `agent/baselines/p2p_protocol.json` — frame encode/decode latency, frame size, fuzz iterations.
- [ ] `agent/baselines/p2p_transport.json` — handshake P50/P95, move RTT P50/P95, network-change recovery P95, push-wake cold-start P95, battery %.
- [ ] `agent/baselines/p2p_signaling.json` — endpoint P50/P95, error rate, soak memory drift, chaos pass-rate.
- [ ] `agent/baselines/p2p_identity.json` — Argon2 timing per device class, recovery-flow success rate.
- [ ] Threshold rule (parity with engine baselines): >5% regression on any baseline metric is a hard revert.

### 5.3 Quality attributes

- [ ] **Performance:** CI wall-clock for the L1–L4 suite under 4 minutes; L5–L7 under 25 minutes.
- [ ] **Efficiency:** Test parallelism saturates available cores without flakes; `flutter test --concurrency` tuned per platform.
- [ ] **Stability:** Flake budget ≤ 0.2% per layer over a rolling 30-day window; over budget triggers `kind: p2p_flake` queue entry.
- [ ] **Reliability:** Every red CI on `main` triggers `agent/state/last_failure.json` and blocks ticking any P2P box.
- [ ] **Integrity:** No test relies on network access except L6/L7/L8 explicitly; L1–L5 hermetic. **Proof:** CI runs L1–L5 with network namespace dropped.

### 5.4 Acceptance gate

- [ ] All 9 layers wired, all baselines created, CI green on `main`, flake rate within budget.

---

## Phase 6 — Beta and release

**Goal:** Controlled rollout with measurable KPIs, kill-switch, and a documented rollback. *0% complete.*

### 6.1 Closed beta

- [ ] Feature flag `kEnableP2P` defaulting `false`, served via remote config (signed config blob fetched from signaling server, cached). **Proof:** `frontend/test/p2p/config/remote_config_test.dart`.
- [ ] Opt-in via TestFlight / Play Internal. ≥100 invitees over ≥2 regions.
- [ ] In-app feedback channel + opt-in crash reporting (Sentry or equivalent, PII-scrubbed). **Proof:** `frontend/test/p2p/telemetry/redaction_test.dart`.

### 6.2 Telemetry KPIs (must be live and graphed before opening beta)

- [ ] Connection success rate (handshake completed within 30 s of intent).
- [ ] Direct-connect rate vs TURN-relay rate.
- [ ] P50/P95 move RTT.
- [ ] `MISMATCH` rate (target: 0 in 10⁵ moves).
- [ ] `BACKPRESSURE_DROP` rate.
- [ ] Push-wake redemption rate and time-to-handshake.
- [ ] Recovery-flow attempts vs successes.
- [ ] Battery & thermal anomalies (opt-in).
- [ ] Per-mod engine KPIs (must remain at single-player baseline).

### 6.3 Kill switch and rollback

- [ ] `kEnableP2P` can be flipped off remotely within 10 minutes globally; client falls back to local-only mode (single-player). **Proof:** `frontend/test/p2p/config/kill_switch_test.dart`.
- [ ] Server-side: `/v1/offers` returns 503 with `Retry-After` when admin-disabled; clients respect and surface a friendly message. **Proof:** `signaling/internal/admin/disable_test.go`.
- [ ] Documented rollback runbook in [docs/P2P_SIGNALING_RUNBOOK.md](P2P_SIGNALING_RUNBOOK.md) §rollback.

### 6.4 Public release

- [ ] Open beta → GA staged: 1% → 10% → 50% → 100% with 24 h soak between steps; auto-halt on KPI regression >5%. **Proof:** rollout config + dashboard alert rules.
- [ ] Store listing & screenshots updated; privacy policy revised to disclose signaling data minimisation. **Proof:** legal review checkbox in this doc + diff in [docs/legal/PRIVACY.md](legal/PRIVACY.md) (placeholder until created).

### 6.5 Quality attributes

- [ ] **Performance:** Public-release KPIs hit beta targets at full traffic.
- [ ] **Efficiency:** Signaling cost per active user ≤ $0.01/month at 100k MAU (calculated from request volume × per-request cost).
- [ ] **Stability:** 7-day rolling crash-free rate ≥ 99.9% for the P2P-flag-on cohort.
- [ ] **Reliability:** No `MISMATCH` event in production over the rollout window; if any, automatic halt + forensic bundle uploaded (with consent).
- [ ] **Integrity:** Every released APK / IPA build is reproducible from source; SBOM published per release. **Proof:** `scripts/p2p/verify-reproducible-build.sh` + release-asset attestation.

### 6.6 Acceptance gate

- [ ] All 6.1–6.5 ticked, GA at 100% with KPIs at or above beta targets for 7 consecutive days.

---

## Phase 7 — Stretch goals

*0% complete. Unblocked only after Phase 6 GA.*

- [ ] **Spectator mode**: a third peer subscribes (read-only) via the signaling server's "join as spectator" endpoint; receives a derived view-only key; cannot inject moves. Proof: `frontend/test/p2p/spectator_test.dart`.
- [ ] **Multi-device per account**: same account key on N devices; signaling routes offers to all reachable devices; first-to-answer wins; others abort gracefully. Proof: `frontend/test/p2p/multi_device_routing_test.dart`.
- [ ] **Tournament mode**: signed bracket served by signaling server; pairings are deterministic from the bracket commitment + round number; results signed by both peers. Proof: `frontend/test/p2p/tournament_test.dart`.
- [ ] **Late-join / reconnect**: a peer rejoining mid-game synchronises via a CRDT-style move log with Lamport-clock-tagged moves; conflicts (impossible if protocol is correct) end the session. Proof: `frontend/test/p2p/late_join_test.dart`.
- [ ] **Federation**: peer-discovery via well-known signaling servers; cross-server play with capability negotiation. Proof: `signaling/internal/federation/federation_test.go`.

---

## Phase 8 — Cross-cutting concerns

*0% complete. Some items partially addressed by phase-specific subsections; this phase is the holistic owner.*

### 8.1 Internationalisation

- [ ] All P2P UI strings in [frontend/lib/l10n/](../frontend/lib/l10n/) (ARB files). RTL layouts verified (Arabic, Hebrew). **Proof:** `frontend/test/i18n/p2p_strings_test.dart`.
- [ ] Recovery-code wordlist localised — fallback to English if a locale wordlist is unavailable, with explicit user-visible note.

### 8.2 Accessibility

- [ ] Connection-state UI: every state has a `Semantics` label; live-region announcements on state change. **Proof:** `frontend/test/a11y/p2p_connection_state_a11y_test.dart`.
- [ ] Recovery-code entry: large-font / high-contrast mode tested; screen-reader announces word numbers. **Proof:** `frontend/test/a11y/recovery_entry_a11y_test.dart`.
- [ ] Colour is never the sole indicator of connection status (icons + text + semantics). Colour-blind matrix verified.

### 8.3 Observability (client-side)

- [ ] Local rolling diagnostic log (256 KB ring buffer) persisted, redacted, exportable via "Help → Send diagnostics" (opt-in). **Proof:** `frontend/test/p2p/telemetry/diag_log_test.dart`.
- [ ] No PII in client telemetry by default; opt-in detailed mode adds session ids only. **Proof:** redaction test.

### 8.4 Supply chain & provenance

- [ ] SBOM generated per build (CycloneDX) for client and signaling server. **Proof:** CI artefact `sbom-*.cdx.json`.
- [ ] Dependency confusion guard: pin all direct deps; CI fails on resolution that pulls a higher-numbered same-name package from a non-allow-listed registry. **Proof:** `scripts/p2p/check-deps.sh`.
- [ ] License audit: libsodium (ISC), coturn (BSD), litestream (Apache-2.0), `package:cryptography` (Apache-2.0), Go stdlib (BSD). Compatible with project licence. Documented in [docs/P2P_LICENSES.md](P2P_LICENSES.md). **Proof:** `scripts/p2p/check-licenses.sh` in CI.
- [ ] Reproducible builds for both client (per-platform) and server (single-binary). **Proof:** `scripts/p2p/verify-reproducible-build.sh`.
- [ ] Release assets signed (Sigstore / cosign) with provenance attestation. **Proof:** release workflow.

### 8.5 Legal & data residency

- [ ] Signaling server deployed in regions consistent with the privacy policy; per-region routing. **Proof:** documented in [docs/legal/DATA_RESIDENCY.md](legal/DATA_RESIDENCY.md).
- [ ] DSAR (data subject access request) flow: account pubkey → coarse `last_seen`, push-token hash, audit rows; deletion endpoint wipes all rows including litestream snapshots ≤ 30 d. **Proof:** `signaling/internal/dsar/dsar_test.go`.
- [ ] GDPR / CCPA review checklist completed.

### 8.6 Quality attributes (cross-cutting)

- [ ] **Performance:** Telemetry path adds ≤ 50 µs per move. **Proof:** `frontend/test/p2p/perf/telemetry_overhead_test.dart`.
- [ ] **Efficiency:** Diagnostic log rotation never blocks UI thread. **Proof:** `frontend/test/p2p/telemetry/diag_log_async_test.dart`.
- [ ] **Stability:** No localisation key missing in any locale (CI gate).
- [ ] **Reliability:** A11y semantics survive Flutter SDK upgrades (golden tests).
- [ ] **Integrity:** SBOM diff between consecutive releases is reviewed by a human; new direct deps require a queue entry of `kind: p2p_dep_review`.

### 8.7 Acceptance gate

- [ ] All 8.1–8.6 ticked, every release shipped after this phase carries SBOM + provenance, every supported locale has all P2P strings, a11y suite green.

---

## Phase 9 — Threat model

*Living document; minimum 60 entries by GA. v3 had 36; v4 adds 24+. Each entry: ID · vector · asset · likelihood · impact · mitigation · proof test reference.*

### 9.1 Network attacker (active)

- [ ] **T-N-001** Signaling server impersonation → MITM. *Mitigation:* TLS 1.3 with HPKP/HSTS-style pinning, request signatures over body hash. *Proof:* `signaling/internal/auth/sig_test.go`.
- [ ] **T-N-002** SDP offer tampering → wrong ICE candidates. *Mitigation:* offer/answer signed under the long-term device key. *Proof:* `frontend/test/p2p/transport/offer_signature_test.dart`.
- [ ] **T-N-003** ICE candidate injection → traffic mirroring via attacker TURN. *Mitigation:* TURN cred is HMAC-bound to session; mismatched relay rejected. *Proof:* `frontend/test/p2p/transport/turn_cred_bind_test.dart`.
- [ ] **T-N-004** TURN credential leak / re-use. *Mitigation:* 5-min lifetime + per-session binding. *Proof:* `signaling/internal/turn/cred_test.go`.
- [ ] **T-N-005** DataChannel ciphertext replay. *Mitigation:* deterministic nonce + sequence enforcement. *Proof:* `frontend/test/p2p/protocol/sequence_test.dart`.
- [ ] **T-N-006** Push-wake forgery → spam. *Mitigation:* per-(sender,recipient) ceiling + signed wakeup request. *Proof:* `signaling/internal/push/wake_ceiling_test.go`.
- [ ] **T-N-007** Captive-portal hijack. *Mitigation:* connection state surfaces "captive portal detected" via known-good HTTPS canary. *Proof:* `frontend/test/p2p/transport/captive_portal_test.dart`.

### 9.2 Malicious peer

- [ ] **T-P-001** Illegal-move injection. *Mitigation:* every remote move re-validated by local engine. *Proof:* per-mod `engine_binding_test.dart`.
- [ ] **T-P-002** Replay of own previous move. *Mitigation:* sequence enforcement. *Proof:* sequence test.
- [ ] **T-P-003** Excessive frame size → DoS. *Mitigation:* 16 KB cap + AEAD failure on tamper. *Proof:* `frame_size_cap_test.dart`.
- [ ] **T-P-004** Slow-loris on `chess` channel → starve clock. *Mitigation:* per-side move time budget enforced locally. *Proof:* `frontend/test/p2p/protocol/clock_starvation_test.dart`.
- [ ] **T-P-005** Mod mismatch (Heir vs Truce). *Mitigation:* `HELLO` includes signed mod id; mismatch → abort. *Proof:* `frontend/test/p2p/protocol/hello_mod_match_test.dart`.
- [ ] **T-P-006** Fork attack — peer claims a different game state to a third party. *Mitigation:* signed game-end transcript; spectator (Phase 7) verifies. *Proof:* `frontend/test/p2p/protocol/transcript_signing_test.dart`.

### 9.3 Server compromise

- [ ] **T-S-001** DB read → no plaintext game data exists; only account pubkeys, hashed push tokens, wrapped recovery blobs. *Proof:* PII audit test.
- [ ] **T-S-002** DB write (insert rogue offers). *Mitigation:* offers are opaque blobs; client validates handshake signatures end-to-end. *Proof:* `frontend/test/p2p/transport/handshake_signature_test.dart`.
- [ ] **T-S-003** Push token leak → off-platform spam to users. *Mitigation:* tokens encrypted at rest with KMS; rate-limited send. *Proof:* `signaling/internal/store/pii_audit_test.go`.
- [ ] **T-S-004** Backdoored binary → poisoned wakeup. *Mitigation:* SBOM + reproducible build + Sigstore. *Proof:* `verify-reproducible-build.sh`.
- [ ] **T-S-005** Hostile-region traffic spike → resource exhaustion. *Mitigation:* PoW + GeoIP throttling. *Proof:* `signaling/internal/abuse/pow_test.go`.

### 9.4 Device compromise

- [ ] **T-D-001** Device-key theft via keystore extraction. *Mitigation:* hardware-backed Keystore / Secure Enclave required where available; fall-through documented. *Proof:* `secure_storage_<platform>_test.dart`.
- [ ] **T-D-002** Recovery code phished. *Mitigation:* user-visible warnings + rebind requires fresh attestation; old device self-quarantines. *Proof:* `account_migration_chaos_test.dart`.
- [ ] **T-D-003** Biometric spoofing → silent rebind. *Mitigation:* biometric only unlocks the local key; rebind also requires the recovery code. *Proof:* recovery flow test.
- [ ] **T-D-004** Backup leak (cloud backup of app data). *Mitigation:* device-key marked non-backup on iOS / Android; secret-storage flags asserted. *Proof:* per-platform secure-storage tests.

### 9.5 Privacy / metadata

- [ ] **T-M-001** Server learns who plays whom and when. *Mitigation:* unavoidable for a signaling server; coarsen IP, drop UA, time-bucket logs to 5 min, no per-game retention. *Proof:* `signaling/internal/log/redaction_test.go`.
- [ ] **T-M-002** TURN learns peer IPs and traffic volume. *Documented* — no full mitigation in scope; users informed in privacy policy.
- [ ] **T-M-003** Push provider learns recipient device + wakeup frequency. *Mitigation:* batch wakeups under daily ceiling; payload empty.

### 9.6 Supply chain

- [ ] **T-X-001** Compromised libsodium release. *Mitigation:* pin SHA, verify against multiple mirrors, SBOM diff review. *Proof:* `check-deps.sh`.
- [ ] **T-X-002** Compromised pub.dev or proxy. *Mitigation:* lockfile + checksum verification. *Proof:* CI lockfile gate.
- [ ] **T-X-003** Build-system tampering. *Mitigation:* hermetic builds + reproducible-build verification. *Proof:* `verify-reproducible-build.sh`.

---

## Phase 10 — Failure-mode catalog

*Living document; minimum 60 codes by GA. Each: code · trigger · detection · user-visible state · auto-recovery · proof test.*

> v4 expansion areas vs v3 (storage corruption, web/desktop, push deferral, biometric re-key failures, deep-link cold-start, late-join collisions). Every code must have a typed Dart enum value in `frontend/lib/services/p2p/errors.dart` and a matching test reference.

- [ ] **F-PROTO-001** `BAD_FRAME` — CBOR parse failed. *Recovery:* drop, count; threshold (5/min) → end session.
- [ ] **F-PROTO-002** `BAD_VERSION` — version negotiation failed. *Recovery:* end with friendly UI ("update required").
- [ ] **F-PROTO-003** `OUT_OF_SEQUENCE` — sequence skip or duplicate. *Recovery:* `MISMATCH`.
- [ ] **F-PROTO-004** `ILLEGAL_MOVE` — engine rejected. *Recovery:* `MISMATCH` with forensic bundle.
- [ ] **F-PROTO-005** `MOD_MISMATCH` — `HELLO` mod id differs. *Recovery:* end before any move.
- [ ] **F-PROTO-006** `CLOCK_STARVATION` — peer too slow. *Recovery:* time-out per game rules.
- [ ] **F-PROTO-007** `BACKPRESSURE_DROP` — SCTP queue overflow. *Recovery:* end session, surface "connection unstable".
- [ ] **F-PROTO-008** `MISMATCH` — replay parity broken. *Recovery:* end + write forensic bundle.

- [ ] **F-NET-001** `ICE_FAILED` — no candidate pair. *Recovery:* prompt user to retry; surface diagnostics.
- [ ] **F-NET-002** `ICE_DISCONNECTED` — mid-session loss. *Recovery:* ICE restart within 10 s, else `NETWORK_LOST`.
- [ ] **F-NET-003** `NETWORK_LOST` — unrecoverable. *Recovery:* save partial game; offer to resume via push wake.
- [ ] **F-NET-004** `TURN_UNAVAILABLE` — both TURN endpoints down. *Recovery:* fail with explicit message; queue entry `kind: p2p_infra`.
- [ ] **F-NET-005** `CAPTIVE_PORTAL` — canary failed. *Recovery:* prompt user to sign in to network.
- [ ] **F-NET-006** `NAT_HARD_BLOCK` — symmetric × symmetric, TURN also blocked. *Recovery:* fail with guidance to switch network.
- [ ] **F-NET-007** `IPV6_PMTU_BLACK_HOLE` — IPv6-only path with MTU issues. *Recovery:* clamp + retry; if still failing, surface diagnostics.

- [ ] **F-XPORT-001** `DATACHANNEL_CLOSED_UNEXPECTEDLY`. *Recovery:* attempt rebind once.
- [ ] **F-XPORT-002** `SCTP_HANDSHAKE_TIMEOUT`. *Recovery:* `ICE_FAILED` path.

- [ ] **F-SIG-001** `SIGNALING_5XX` — server unreachable. *Recovery:* exponential backoff; cached config.
- [ ] **F-SIG-002** `SIGNALING_RATE_LIMITED` — 429. *Recovery:* respect `Retry-After`; surface gentle UI.
- [ ] **F-SIG-003** `SIGNALING_POW_REQUIRED` — 421-style PoW challenge. *Recovery:* solve transparently; surface only on persistent loop.
- [ ] **F-SIG-004** `OFFER_EXPIRED` — pending offer past TTL. *Recovery:* prompt to re-invite.
- [ ] **F-SIG-005** `OFFER_DUPLICATE_ANSWER` — race of two devices answering. *Recovery:* server returns 409; loser aborts cleanly.
- [ ] **F-SIG-006** `ADMIN_DISABLED` — `kEnableP2P` off. *Recovery:* fall back to local-only.

- [ ] **F-ID-001** `KEY_GEN_FAILED` — entropy unavailable. *Recovery:* surface with "try again later"; never proceed with weak entropy.
- [ ] **F-ID-002** `KEY_STORAGE_UNAVAILABLE` — secure storage broken. *Recovery:* refuse to proceed; document support path.
- [ ] **F-ID-003** `BIOMETRIC_LOCKOUT` — N failed attempts. *Recovery:* wipe device key, mark "needs recovery".
- [ ] **F-ID-004** `RECOVERY_BAD_CODE` — Argon2 unwrap MAC fail. *Recovery:* allow retry with backoff (1s, 5s, 30s, 5m, 1h).
- [ ] **F-ID-005** `RECOVERY_PARAM_MISMATCH` — KDF params unsupported on this device. *Recovery:* fail with clear "open on your old device first" message.
- [ ] **F-ID-006** `REBIND_ATTESTATION_FAILED` — Play Integrity / DeviceCheck rejected. *Recovery:* surface friendly error; queue entry.
- [ ] **F-ID-007** `OLD_DEVICE_REJECTED_AFTER_REBIND` — quarantine state. *Recovery:* show "this device has been replaced".

- [ ] **F-PUSH-001** `PUSH_TOKEN_INVALID` — provider rejected. *Recovery:* drop token, request re-register.
- [ ] **F-PUSH-002** `PUSH_PROVIDER_DOWN` — APNs/FCM 5xx. *Recovery:* server retries with backoff; client UI shows "your friend may be offline".
- [ ] **F-PUSH-003** `PUSH_DEFERRED_BY_OS` — Doze / Low Power Mode. *Recovery:* surface as "expected delivery delayed"; do not retry-spam.
- [ ] **F-PUSH-004** `PUSH_RECEIVED_NO_OFFER` — wakeup race. *Recovery:* client polls once, then quiet exit.

- [ ] **F-LIFECYCLE-001** `APP_SUSPENDED_MID_HANDSHAKE`. *Recovery:* mark intent; resume on foreground.
- [ ] **F-LIFECYCLE-002** `FOREGROUND_SERVICE_KILLED` — Android OEM kills service. *Recovery:* end session with friendly message; queue entry to track OEM.
- [ ] **F-LIFECYCLE-003** `IOS_NSE_TIMEOUT` — NSE budget exceeded. *Recovery:* cold-start path.
- [ ] **F-LIFECYCLE-004** `DEEP_LINK_COLD_START_LOST` — race lost the offer. *Recovery:* automatic re-poll on launch; tracked metric.

- [ ] **F-STORE-001** `SAVED_GAMES_DB_CORRUPT` — SQLite corruption (sqlite_corrupt). *Recovery:* quarantine DB, fresh DB, surface "history unavailable, contact support".
- [ ] **F-STORE-002** `SAVED_GAMES_MIGRATION_FAILED`. *Recovery:* roll back, do not destroy old data, surface clearly.
- [ ] **F-STORE-003** `DISK_FULL`. *Recovery:* refuse to start new session; surface OS settings link.

- [ ] **F-WEB-001** `WEBRTC_NOT_SUPPORTED` — old browser. *Recovery:* feature gate by browser version.
- [ ] **F-WEB-002** `WEBCRYPTO_NON_EXTRACTABLE_LIMIT` — recovery flow not feasible on web. *Recovery:* document; suggest mobile.

- [ ] **F-DESKTOP-001** `LIBSECRET_UNAVAILABLE` (Linux). *Recovery:* fallback to Argon2id-wrapped on-disk file with explicit user consent.

- [ ] **F-OBS-001** `TELEMETRY_QUEUE_OVERFLOW`. *Recovery:* drop oldest; never block UI.

- [ ] **F-CHAT-001** `CHAT_FRAME_TOO_LARGE`. *Recovery:* reject locally before send; surface "message too long".
- [ ] **F-CHAT-002** `CHAT_RATE_LIMIT_LOCAL` — anti-flood per peer. *Recovery:* drop with toast.

- [ ] **F-LATEJOIN-001** `LAMPORT_CONFLICT` (Phase 7 stretch). *Recovery:* end session as `MISMATCH`-equivalent.

- [ ] **F-FORENSIC-001** `FORENSIC_BUNDLE_WRITE_FAILED` — disk full during forensic dump. *Recovery:* in-memory tail kept until next launch.

> **Catalog ownership rule.** Every new failure code must land with: (a) a typed enum value, (b) at least one proof test, (c) a UX string in [frontend/lib/l10n/](../frontend/lib/l10n/), (d) a row in this catalog, (e) a queue entry of `kind: p2p_failure_mode` if it surfaced from a real incident.

---

## Open questions (must be resolved before the corresponding gate)

- [ ] **OQ-1** Web / desktop scope for GA — full parity, reduced (no recovery), or excluded? *Decision required before:* Phase 6.
- [ ] **OQ-2** Self-host vs managed TURN at GA cost-vs-reliability — what's the break-even? *Decision required before:* Phase 6 cost model.
- [ ] **OQ-3** Spectator / tournament priority order in Phase 7. *Decision required before:* Phase 7 kickoff.
- [ ] **OQ-4** Federation appetite — is cross-server play desirable, or a one-vendor approach forever? *Decision required before:* Phase 7.5.
- [ ] **OQ-5** Engine-correlation tolerance — is the >5% rule too tight given P2P adds CPU work on receive? *Decision required before:* Phase 1 acceptance.
- [ ] **OQ-6** Recovery wordlist languages — which beyond English at GA? *Decision required before:* Phase 8.1 close-out.
- [ ] **OQ-7** Push-wake daily ceiling — start at 50, justify in beta. *Decision required before:* beta opens.
- [ ] **OQ-8** Data residency regions for GA. *Decision required before:* Phase 8.5.
- [ ] **OQ-9** APK / IPA size budget — what's the ceiling we accept for libsodium + WebRTC? *Decision required before:* Phase 4 acceptance.

---

## Sequencing graph

```
Phase 0 (cleanup) ──► Phase 1 (protocol) ──► Phase 4 (transport) ──► Phase 6 (beta) ──► GA ──► Phase 7
                  ╲                       ╲                      ╱
                   ╲─► Phase 2 (identity) ─╳► Phase 3 (signaling)
                                            (Phase 2 & 3 overlap from week 2;
                                             identity bytes block signaling
                                             registration but server scaffolding
                                             does not.)
                  Phase 5 (test/CI) accompanies every other phase.
                  Phase 8 (cross-cutting) accompanies every other phase.
                  Phase 9 (threat model) is updated continuously.
                  Phase 10 (failure catalog) is updated continuously.
```

Critical-path summary: **Phase 0 → Phase 1 → Phase 4 → Phase 6**. Phases 2 and 3 are parallelisable but must converge before Phase 4's network-change + push-wake testing.

---

## References

- RFC 8949 — CBOR (deterministic encoding §4.2)
- RFC 8489 — STUN
- RFC 8656 — TURN
- RFC 8445 — ICE
- RFC 9147 — DTLS 1.3 (used inside WebRTC for media; SCTP DataChannel uses DTLS for transport security)
- RFC 8032 — EdDSA (Ed25519)
- RFC 7748 — X25519
- RFC 5869 — HKDF
- RFC 9106 — Argon2
- RFC 8439 — ChaCha20-Poly1305
- W3C WebRTC 1.0 — `RTCDataChannel`
- libsodium documentation
- Play Integrity API; Apple DeviceCheck / App Attest
- litestream documentation
- coturn documentation
- Sigstore / cosign docs
- CycloneDX SBOM spec

---

> **Reminder for AI assistants editing this file:** Per [.github/copilot-instructions.md](../.github/copilot-instructions.md) and [AGENTS.md](../AGENTS.md), changing this roadmap is a doc-only change and does not require engine gates, but does require commit + push to `origin/main` once the edit is complete. Ticking a box from `[ ]` to `[x]` requires the proof tests cited beside the box to be green on `main` and the relevant KPI baseline updated; otherwise use `[~]`.
