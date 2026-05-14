# ChessRecast — Peer-to-Peer Multiplayer Roadmap

> **Version:** v5 · **Status banner:** 🟥 **0% shipped** — every checkbox in this document is empty (`[ ]`). No P2P code, no signaling server, no archive of the legacy backend exists yet. Everything below is design intent until a checkbox is ticked by a commit on `main`.
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

## What changed in v5 vs v4

v4 was structurally sound but had silent gaps that would have bitten us mid-implementation. v5 closes them and corrects two real cryptographic / engine-determinism bugs.

- [ ] **Cryptography bugs fixed.**
  - **AEAD nonce arithmetic was wrong.** v4 specified `nonce = session_id_lo32 || sender_dir1 || seq_u64_be` = 4 + 1 + 8 = **13 bytes**, but ChaCha20-Poly1305 nonce is 96 bits = **12 bytes**. v5 switches the hot path to **XChaCha20-Poly1305** (192-bit / 24-byte nonce) — `nonce = session_id_random_192bit_session_salt[0..15] || dir1 || seq_u64_be` (16 + 1 + 7? no — 16 + 8 = 24, with `dir` packed into the high bit of `seq` or into salt). Concretely, v5 §2.3 specifies `nonce = salt_24_with_seq_le := salt_15 || dir1 || seq_u64_be` = 15 + 1 + 8 = 24. Rationale: session salt is fresh per session (no cross-session reuse), `seq` is monotonic per direction, `dir` separates the two directions. XChaCha20 is libsodium's `crypto_secretbox_xchacha20poly1305` — constant-time and mature.
  - **BIP-39 checksum.** v4 said "16 BIP-39 words ≈ 176 bits entropy" — that's wrong. BIP-39 16 words = 165 bits entropy + 11-bit checksum. v5 §2.2 specifies the entropy budget correctly and **mandates the BIP-39 checksum** so a typo is caught locally before the user attempts an Argon2 unwrap (which would otherwise burn 1.5–4 s on bad input).
  - **Argon2id floor.** v4 made parameters "adaptive" but did not specify a *floor*. v5 sets `m_min=16 MiB, t_min=4, p=1` as the absolute floor — never weaker, even on ultra-low-end. Forward compatibility: a `kdf_version` byte in the wrapped blob lets future versions raise the floor and re-wrap on next unlock.
- [ ] **Replay-parity contract sharpened.** v4 said "two peers' native engines compute the same legal-move set" — true, but the engine also contains a `xorshift64` PRNG used for tiebreaks at low skill levels (see [frontend/native/engine/search.c](../frontend/native/engine/search.c) lines 149–196, seeded from `time_ms_now()`). That PRNG is **non-deterministic** and would silently break the contract if anyone ever fed engine search output into the wire protocol. v5 adds a hard rule: **the wire protocol carries human-or-engine-selected moves; the engine is only used to validate legality and compute the canonical state hash. Move selection is never part of the parity contract.** A new test `frontend/test/p2p/engine_binding_determinism_test.dart` asserts that legality + state hash are deterministic across 10k random positions × 7 mods × two PRNG seeds. New Phase 12 owns the engine-replay-version pinning story.
- [ ] **Chess clock protocol added (new Phase 11).** v4 had `CLOCK_STARVATION` as a failure mode but no actual clock protocol. P2P chess clocks are a hard distributed-systems problem: who's authoritative on flag-fall? When does the receiver's clock start — when the move arrives, when it decodes, when it engine-validates? Asymmetric network delay can swing a blitz game. v5 §11 specifies an NTP-style offset-and-delay estimator (over the unreliable `clock` DataChannel), the rule "opponent's clock starts when sender's `MOVE_ACK` is received", a flag-fall consensus protocol (both peers must agree; one-side-thinks-flagged is a `MISMATCH`), and explicit time-control negotiation in `HELLO`.
- [ ] **Pre-game handshake expanded.** v4's `HELLO` carried only a mod id. Real games need: time control, color assignment (negotiated or coin-flipped via a verifiable joint-randomness protocol), starting position (Chess960 / mod-specific), variant config (Heir's heir piece, Mercenary's pawn-conversion preset, etc.), `engine_replay_version` (Phase 12), wire-protocol version. v5 §1.1 expands `HELLO` into a typed record with fields enumerated and §1.6 adds a verifiable joint coin-flip for color assignment (commit-reveal so neither peer can bias).
- [ ] **Mid-game resync protocol specified (new §4.6).** v4 mentioned `SYNC_REQ`/`SYNC_RESP` as frame types but never specified semantics. v5 defines: (a) on ICE restart, both peers exchange `SYNC_REQ` carrying their last-acked sequence number and the canonical state hash at that ply; (b) the peer with more state replays unacked `MOVE` frames; (c) hash mismatch at the agreed common ply → `MISMATCH`; (d) a re-sync that takes more than 30 s ends the session as `RESYNC_TIMEOUT`. Proof tests added at L1 (state-machine), L5 (synthetic), and L6 (real WebRTC).
- [ ] **Perfect-negotiation pattern adopted.** v4 didn't address the simultaneous-offer race (both peers re-invite at once after a network drop). v5 §4.2 mandates the W3C *perfect negotiation* pattern: each peer has a stable `polite/impolite` role derived from the lexicographic comparison of their device-key fingerprints; the impolite peer's offer wins on collision. Proof: `frontend/test/p2p/transport/perfect_negotiation_test.dart`.
- [ ] **Game-end transcript specified.** v4 mentioned a signed transcript only inside threat T-P-006. v5 promotes it to a first-class artefact: at game end, both peers exchange a `BYE` frame containing `(session_id, mod, time_control, move_list_hash, result, signature_over_all)` signed under their long-term Ed25519 key. Stored locally for dispute / spectator / future rating use. Proof: `frontend/test/p2p/protocol/transcript_signing_test.dart`.
- [ ] **HA design fleshed out (Phase 3.3).** v4 corrected v3's "litestream = HA" mistake but didn't specify what HA *is*. v5 specifies: writes go to a single regional primary; offers/ICE table is fronted by a Redis-compatible cache (Valkey) with cross-region replication for ≤5 s visibility lag; on primary failure, a `read-only mode` lets clients fetch pending offers but blocks new registrations until failover (target RTO ≤ 10 min, RPO ≤ 5 s via litestream). Documented trade-off: full multi-master is **out of scope** for v1 (cost & complexity); v1 ships active/standby with a documented manual failover runbook.
- [ ] **Reproducible-build technique made concrete (Phase 8.4).** v4 said "reproducible builds" but Flutter Android builds are notoriously hard to reproduce (DEX timestamps, AAPT2 ZIP entry order, R8 thread non-determinism). v5 specifies the *technique*: `--release --no-tree-shake-icons`, `SOURCE_DATE_EPOCH` for native libs, `strip-nondeterminism` post-pass on the APK, server binary built with `-trimpath -buildvcs=false -ldflags='-buildid='` and Go's `GOFLAGS=-mod=readonly`. iOS reproducibility is acknowledged as **best-effort only** (Apple toolchain limitations) — documented in [docs/P2P_LICENSES.md](P2P_LICENSES.md).
- [ ] **Anti-cheat & fair-play scope declared (new Phase 13).** v4 was silent on a player using an external strong engine (the classical online-chess problem). Pure P2P architecture cannot solve this — there is no central observer. v5 §13 explicitly declares it **out of scope for the cryptographic protocol**, lists the partial mitigations available client-side (move-time histograms shown to opponent, optional "casual / rated / no-engine pledge" flag in `HELLO`), and flags it as a future phase (rating system + reputation needs server-side observation, which contradicts the dumb-signaling principle — owns OQ-10 in v5).
- [ ] **Push-wake payload tightened.** v4 said pushes carry `session_hint`. v5 redefines: payload is an opaque **redeem-once token** issued by the signaling server (random 128-bit), stored server-side mapped to `(recipient_account, pending_offer_id)`, valid 90 s. Client redeems via `GET /v1/offers/poll?token=…`. Push providers (APNs, FCM) never see who initiated.
- [ ] **Engine-replay-version pinning (new Phase 12).** A behaviour-affecting change to `frontend/native/engine/**` (move-gen, draw-rule, mod rule) bumps `ENGINE_REPLAY_VERSION` (separate from app version, separate from `BUILD_REPLAY_VERSION` for cosmetic-only rebuilds). `HELLO` carries it; mismatch → `ENGINE_VERSION_MISMATCH` failure code with a friendly "please update" UI. Compile-time check fails the build if a `frontend/native/engine/**` change lands without a `ENGINE_REPLAY_VERSION` bump (CI gate).
- [ ] **Failure-mode catalog grew from ≥60 to ≥75 codes.** New codes: `RESYNC_TIMEOUT`, `ENGINE_VERSION_MISMATCH`, `WIRE_VERSION_MISMATCH`, `PERFECT_NEG_COLLISION_UNRESOLVED`, `CLOCK_DESYNC_BEYOND_BUDGET`, `FLAG_FALL_DISAGREEMENT`, `TRANSCRIPT_SIGN_FAILED`, `TIME_CONTROL_REJECTED`, `COLOR_FLIP_REVEAL_MISMATCH`, `OFFER_TOKEN_EXPIRED`, `READ_ONLY_MODE_REJECTED_WRITE`, `KDF_VERSION_UNSUPPORTED`, `BIP39_CHECKSUM_FAIL` (caught before Argon2), `XCHACHA_NONCE_REUSE_DETECTED` (defensive — should be impossible by construction, but fail-fast if ever observed), `STARTUP_INTEGRITY_FAIL` (app-wide tamper detection on launch).
- [ ] **Threat model grew with explicit metadata, fingerprinting, and supply-chain entries.** New: T-N-008 server pins device-fingerprint via stable signaling cookie, T-M-004 device-fingerprint surfaced in UI is a stable cross-game identifier (intentional; documented in privacy policy), T-X-004 GitHub Actions secret leak via fork PRs, T-P-007 deterministic engine-PRNG seeding (impossible by spec but defensively tested).
- [ ] **Cost model added (Phase 6.5).** Per-MAU breakdown with named line items, not a single number. Includes signaling compute, TURN egress (the dominant cost), push provider fees, S3 storage for litestream + transcripts, observability backends.
- [ ] **Operator / on-call ownership made explicit (Phase 8.7).** Acknowledges that the project may be solo-maintained and specifies the minimum viable on-call: PagerDuty/OpsGenie-equivalent or, if solo, a documented "degraded-mode default" that fails P2P closed and surfaces a maintenance message rather than waking a pager that doesn't exist.
- [ ] **Saved-game schema versioning.** v4's local SQLite store had no migration story beyond "forward-only". v5 §0.2 mandates a `schema_version` row, an explicit `down_migration_blocked: true` flag on irreversible changes, and a per-version round-trip test (every saved game from version N-1 must round-trip through version N without data loss).
- [ ] **Web platform scope clarified.** v4 hand-waved web. v5 §4.7 specifies: web ships **without** account recovery (WebCrypto non-extractable keys preclude it), **with** WebRTC DataChannel + IndexedDB-backed local storage, and is gated behind `kEnableP2PWeb` (separately flagged from mobile). Web is a Phase 7 stretch goal *for GA*, not a Phase 6 launch surface.
- [ ] **Sequencing-graph correction.** v4 showed Phase 5 (test/CI) and Phase 8 (cross-cutting) as parallel-to-everything but didn't gate them. v5 makes Phase 5 §5.1 (CI wiring) a **prerequisite** for any other phase being able to tick `[~]→[x]` — without CI, there is no proof anything is green.

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
| **Chess clock** | The per-peer clock state machine defined in [Phase 11](#phase-11--chess-clock-and-time-control); each peer is authoritative on its own clock. |
| **Time control** | Parameters of the chess clock for a session (kind, base, increment, etc.); part of `HELLO`. |
| **Perfect negotiation** | The W3C WebRTC pattern (spec Appendix B) for resolving simultaneous-offer races without deadlock; here, polite/impolite role is decided by lexicographic fingerprint sort. |
| **Polite / impolite peer** | Roles in perfect negotiation. Impolite peer's offer wins on collision; polite peer rolls back. |
| **engine_replay_version** | A `u32` versioning the chess-rule semantics of [frontend/native/engine/](../frontend/native/engine/). Bumped on any rule-affecting change; CI-gated. See [Phase 12](#phase-12--engine-replay-version-pinning). |
| **wire_version** | A `u16` versioning the on-wire frame schema and AEAD construction. Independent of `engine_replay_version`. |
| **Transcript** | The signed, end-of-game record of (move list, clock history, result, both peers' device-key signatures). Persisted locally; opt-in upload for dispute resolution. |
| **Casual mode** | Session flag (mutual) that enables takebacks and disables histogram sharing; opposite of competitive mode. |
| **Valkey** | The BSD-licensed Redis fork used as the cross-region hot-cache fronting the SQLite signaling store ([Phase 3.3](#33-storage)). |
| **kdf_version** | One-byte version tag prefixed to every Argon2id-wrapped recovery blob, enabling forward-compatible parameter upgrades and re-wrap-on-unlock. |
| **Canonical state hash** | `SHA-256(canonical_fen \|\| mod_id \|\| mod_state_bytes)`; the per-ply replay-parity beacon. |
| **NTP estimator** | The RFC 5905 offset/delay sampler riding the unreliable `clock` DataChannel; budgets are bounded ([Phase 11.2](#112-ntp-style-offset-and-delay-estimation)). |
| **Read-only mode** | Server state during failover where reads are served from the standby region but writes return HTTP 503; clients see a friendly maintenance message. |
| **kill-switch** | Server-side signed-config flag `kEnableP2P=false` that disables P2P globally on next client poll; auto-engaged after `T_ack` of unacknowledged alerts ([Phase 8.8](#88-operator-model-and-on-call)). |

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

- [ ] Introduce `frontend/lib/services/saved_games_local.dart` with a SQLite (sqflite/drift) backing store; mirror `SavedGamesService` API. Schema includes a top-level `schema_version: INTEGER NOT NULL` row in a `meta` table. **Proof test:** `frontend/test/services/saved_games_local_test.dart` covering create / list / load / delete / migration round-trip plus a fuzz test for malformed SQLite rows.
- [ ] **Schema migration policy:** every schema change ships a forward migration **plus a per-version round-trip test** — every saved game produced by version `N-1` must round-trip through the version-`N` reader without lossy fields. Irreversible changes (column drop, type narrow) carry an explicit `down_migration_blocked: true` marker in the migration file and require a `kind: p2p_schema_irreversible` queue entry. **Proof:** `frontend/test/services/saved_games_schema_round_trip_test.dart`.
- [ ] **Corruption recovery:** if SQLite reports `SQLITE_CORRUPT`, the DB is renamed to `saved_games_quarantine_<ts>.db`, a fresh DB is initialised, and the user is surfaced a one-time "history quarantined, contact support" notice with an export option. **Proof:** `frontend/test/services/saved_games_corruption_recovery_test.dart`.
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
- [ ] Frame envelope fields: `v: u8` (protocol version), `t: u8` (frame type), `n: u64` (monotonic per-sender sequence), `ts: u64` (sender wall clock, ms — **informational only, never trusted for game logic**), `payload: bytes`. **Wrong v3 assumption corrected:** clock sync cannot rely on `ts` alone over an ordered+reliable SCTP channel; we add an unreliable companion frame `PING/PONG` with `ord=false, reliable=false` (separate `RTCDataChannel`) for RTT estimation, mirroring NTP's offset/delay computation. The chess clock itself is owned by [Phase 11](#phase-11--chess-clock-and-time-control).
- [ ] Frame types (initial): `HELLO`, `HELLO_ACK`, `MOVE`, `MOVE_ACK`, `SYNC_REQ`, `SYNC_RESP`, `DRAW_OFFER`, `DRAW_RESPONSE`, `RESIGN`, `TAKEBACK_REQ`, `TAKEBACK_RESPONSE`, `CHAT`, `PING`, `PONG`, `BYE`, `MISMATCH`, `COLOR_FLIP_COMMIT`, `COLOR_FLIP_REVEAL`, `CLOCK_OFFSET_REQ`, `CLOCK_OFFSET_RESP`. Each has a strict CBOR schema in the spec.
- [ ] **`HELLO` is the full pre-game handshake**, not a stub. Required fields: `wire_version: u8`, `engine_replay_version: u32` ([Phase 12](#phase-12--engine-replay-version-pinning)), `mod_id: u8` (must match `ModsEnum`), `mod_config: map<text, any>` (mod-specific options — e.g. Heir's heir-piece selection, Mercenary's pawn-conversion preset, Save-the-Queen prisoner-queen rules, Kings Battle phase-2 toggle), `time_control: { initial_ms: u32, increment_ms: u16, delay_ms: u16, tc_kind: enum{none, sudden_death, fischer, bronstein, byo_yomi} }`, `start_position: { kind: enum{standard, fen, mod_default}, fen?: text }`, `color_preference: enum{random_commit_reveal, want_white, want_black}`, `device_pubkey: bytes32`, `nonce: bytes16`, `capabilities: map<text, bool>` (e.g. `chat`, `takeback`, `spectator_ok`, `casual_mode`, `no_engine_pledge`), `signature: bytes64` (Ed25519 over canonical CBOR of the rest). **Proof:** `frontend/test/p2p/protocol/hello_schema_test.dart` (round-trip + reject every missing/extra field) and `frontend/test/p2p/protocol/hello_signature_test.dart` (tamper any byte → verify fails).
- [ ] **`HELLO_ACK` mirrors `HELLO`** for the responder, with one extra field: `accepted_with_changes: list<text>` enumerating any field the responder negotiated down (e.g. `["time_control.increment_ms"]`). Proposer must re-confirm via a final `HELLO_CONFIRM` (or downgrade to `BYE` with `TIME_CONTROL_REJECTED`).
- [ ] **Move-list canonicalisation** (corrects v3 wrong assumption that "deterministic CBOR is enough"): UCI strings normalised — promotion piece always lowercase, en-passant disambiguated by source square, mod-specific king moves (e.g. Heir's second king, Kings Battle phase-2 king walks) tagged with explicit `actor=king_a|king_b`. **Proof:** `frontend/test/p2p/move_canonical_test.dart`.
- [ ] **Canonical state hash.** After every applied move, both peers compute `state_hash = SHA-256(canonical_fen || mod_id || mod_state_bytes)` where `mod_state_bytes` is the serialised mod-specific state (heir position for Heir, queen-capture-counter for Save-the-Queen, half-move-clock per [docs/game/DRAW_RULES.md](game/DRAW_RULES.md), etc.). `MOVE_ACK` echoes the receiver's computed `state_hash`; mismatch → immediate `MISMATCH`. **Proof:** `frontend/test/p2p/protocol/state_hash_per_mod_test.dart` (×7 mods).

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

### 1.6 Verifiable joint coin-flip for color assignment

- [ ] When `HELLO.color_preference == random_commit_reveal`, both peers run a commit-reveal: each generates a 256-bit random `r`, sends `commit = SHA-256(r)` in `COLOR_FLIP_COMMIT`, then sends `r` in `COLOR_FLIP_REVEAL`. Final color seed = `SHA-256(r_initiator || r_responder)`; LSB selects white. **Proof:** `frontend/test/p2p/protocol/color_flip_test.dart` covering: honest path, peer-A reveals before peer-B (must wait), peer-A reveals an `r'` whose hash != commit (→ `COLOR_FLIP_REVEAL_MISMATCH`, session aborts), both peers offline before reveal (timeout 30 s → abort).
- [ ] **Anti-grinding:** if a peer aborts after seeing the other's reveal but before sending its own, the abort is logged locally and the offending fingerprint is added to a per-device shadow list (no server reporting in v1). **Proof:** `frontend/test/p2p/protocol/color_flip_grind_test.dart`.

### 1.7 Chat, draw, resign, takeback semantics

- [ ] **CHAT:** UTF-8 string ≤ 512 bytes after NFC normalisation. Per-side rate limit: 10 messages / 30 s sliding window, hard ceiling 200 messages per game. Excess → dropped locally with `CHAT_RATE_LIMIT_LOCAL` toast. Chat is end-to-end encrypted (DataChannel) and **persisted only to the local game record**, never to the signaling server. **Proof:** `frontend/test/p2p/protocol/chat_rate_limit_test.dart` + `frontend/test/p2p/protocol/chat_normalisation_test.dart`.
- [ ] **DRAW_OFFER / DRAW_RESPONSE:** an offer is implicitly retracted by the offerer's next `MOVE`. An offer auto-expires after 60 s with no response — surfaced to opponent UI as a soft "timed out" hint, not a frame. Repeated offers are throttled (1 per 10 plies + at-will when opponent's clock is < 30 s). **Proof:** `frontend/test/p2p/protocol/draw_offer_lifecycle_test.dart`.
- [ ] **RESIGN:** signed under the device long-term key (signature is part of the frame, separate from session AEAD) so it can be included in the game-end transcript without trust in the AEAD key. **Proof:** `frontend/test/p2p/protocol/resign_signed_test.dart`.
- [ ] **TAKEBACK_REQ / TAKEBACK_RESPONSE:** opt-in feature gated by both peers' `HELLO.capabilities.takeback`. Request specifies `last_acked_seq` to roll back to; both peers re-derive board from move list `[0..seq]` and re-emit `MOVE_ACK`s. Disallowed in `casual_mode == false` games to avoid abuse. **Proof:** `frontend/test/p2p/protocol/takeback_test.dart`.
- [ ] **BYE / game-end transcript.** First peer to detect game end (checkmate, stalemate, resignation, agreed draw, mod-specific termination per [docs/game/DRAW_RULES.md](game/DRAW_RULES.md), flag-fall) emits `BYE` with `(session_id, mod_id, mod_config_hash, time_control, move_list_hash, final_state_hash, result, termination_reason, signature_over_all_with_device_key)`. Other peer verifies and counter-signs into a local `transcript.cbor` for both peers. **Proof:** `frontend/test/p2p/protocol/transcript_signing_test.dart` + `frontend/test/p2p/protocol/bye_disagreement_test.dart` (peers disagree on result → both keep their own transcript, file forensic bundle, surface dispute UI).

---

## Phase 2 — Identity, key management, and recovery

**Goal:** Long-term per-device Ed25519 keys, per-session X25519 ephemeral keys, opt-in account-level recovery. Keys never leave the device unencrypted; recovery is offline-first and server-independent in the cryptographic critical path. *0% complete.*

### 2.1 Device identity

- [ ] Generate Ed25519 keypair on first launch via libsodium FFI ([package:cryptography](https://pub.dev/packages/cryptography) is the Dart fallback for unit tests; production uses libsodium FFI for constant-time guarantees). **Proof:** `frontend/test/p2p/identity/device_key_gen_test.dart`.
- [ ] Persist private key in **platform secure storage**: iOS Keychain (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`), Android Keystore (StrongBox preferred, hardware-backed required, fallback policy documented), macOS Keychain, Windows DPAPI/NCRYPT, Linux libsecret + fallback to Argon2id-wrapped on-disk file. **Proof tests** per platform: `frontend/test/p2p/identity/secure_storage_<platform>_test.dart` (mocked where SDK unavailable in CI).
- [ ] Public-key fingerprint format: lowercase Base32 of `SHA-256(pubkey)[:10]` grouped `xxxx-xxxx-xx`. Surfaced in UI as "Device ID". **Proof:** `frontend/test/p2p/identity/fingerprint_test.dart`.
- [ ] **Re-key after biometric/PIN failure threshold:** after N consecutive auth failures (configurable, default 10), private key is wiped and account marked "needs recovery". **Proof:** `frontend/test/p2p/identity/biometric_lockout_test.dart`.

### 2.2 Account recovery (opt-in)

- [ ] User opts in by setting a recovery code (BIP-39 wordlist, 16 words = **165 bits entropy + 11-bit BIP-39 checksum** — v4 wrongly stated 176 bits raw entropy). Words drawn from libsodium-validated entropy. **Proof:** `frontend/test/p2p/identity/recovery_code_entropy_test.dart` (statistical χ² over 1M generations) and `frontend/test/p2p/identity/recovery_code_bip39_checksum_test.dart` (a single typo within the wordlist must be detected by checksum **before** Argon2 derivation runs — protects users from a 1.5–4 s wait on bad input and from bricking their account by repeated bad-code rate-limit penalties).
- [ ] Account key (separate from device key) wrapped with Argon2id with **adaptive params and a hard floor**: target `m=64 MiB, t=3, p=1` on flagship; device-class-adaptive down to `m=32 MiB, t=4` on mid-tier; **absolute floor `m=16 MiB, t=4, p=1` — never weaker, on any device**. Floor enforced in code; an attempt to wrap below floor raises `KDF_PARAMS_TOO_WEAK`. Wrapped blob carries a `kdf_version: u8` byte so future versions can raise the floor and re-wrap on next unlock without breaking older blobs. Documented in [docs/P2P_PROTOCOL.md](P2P_PROTOCOL.md) §recovery. **Proof:** `frontend/test/p2p/identity/argon2_adaptive_test.dart` + `frontend/test/p2p/identity/argon2_floor_enforced_test.dart` + `frontend/test/p2p/identity/kdf_version_upgrade_test.dart`.
- [ ] Wrapped backup uploaded to signaling server **only after** opt-in checkbox + explicit "I have written down the words" confirmation. Server stores `wrapped_blob, account_pub, kdf_params, kdf_version`. Server cannot derive plaintext. **Proof:** `signaling/internal/recovery/recovery_test.go` covers end-to-end with a simulated client.
- [ ] **Recovery flow:** on a new device, user enters 16 words → BIP-39 checksum verified locally → Argon2id-derived KEK unwraps the blob → fresh device key is generated → server **rebind** call signed with the recovered account key + Play Integrity / DeviceCheck attestation token (v3 was rebind-only; v4+ also gates first registration in flagged hostile-source regions). **Proof:** `frontend/test/p2p/identity/recovery_flow_test.dart` + `signaling/internal/rebind/rebind_test.go`.
- [ ] **Account migration drill:** documented user-facing flow + `frontend/test/p2p/identity/account_migration_chaos_test.dart` simulating: (a) old device still online, (b) old device offline forever, (c) old device returning after rebind (must surface "this device has been replaced" and self-quarantine), (d) two new devices racing to redeem the same recovery code (server enforces single-rebind atomically; loser gets `REBIND_RACE_LOST`), (e) recovery attempted while signaling server is in read-only mode (§3.3) — surface a friendly "try again in a few minutes".
- [ ] **Re-wrap on KDF upgrade:** when a device unlocks a blob whose `kdf_version` is older than the current floor, the device automatically re-wraps with the new params and uploads a fresh blob (signed with the recovered account key). User-visible only via a one-line toast. **Proof:** `frontend/test/p2p/identity/auto_rewrap_on_upgrade_test.dart`.

### 2.3 Session key derivation

- [ ] Per-session: each peer generates an X25519 ephemeral keypair, signs the public key with its Ed25519 long-term key, exchanges via signaling. Shared secret = X25519(my_eph, their_eph_pub). Session key = HKDF-SHA256(shared, salt=session_id, info="chessrecast/p2p/v1"). **Proof:** `frontend/test/p2p/identity/session_kdf_test.dart` (KAT vectors).
- [ ] **Forward secrecy property:** verified by destroying ephemeral keys at session end and proving prior session ciphertexts cannot be decrypted with current state. **Proof:** `frontend/test/p2p/identity/forward_secrecy_test.dart`.
- [ ] **Symmetric AEAD: XChaCha20-Poly1305** (libsodium `crypto_aead_xchacha20poly1305_ietf`). Nonce is 192 bits = 24 bytes, structured as `salt_15 || dir_1 || seq_u64_be` where `salt_15` is the 15-byte random session salt fresh per session, `dir_1` is `0x00` for initiator→responder and `0x01` for the reverse, `seq_u64_be` is the per-direction monotonic sequence. **Corrects v4 nonce-arithmetic bug** (v4 specified 13 bytes for a 12-byte nonce). XChaCha20 was chosen over plain ChaCha20-Poly1305 because the larger nonce makes accidental reuse cryptographically impossible across sessions (no need to coordinate session_id collisions). **Proof:** nonce-uniqueness fuzz `frontend/test/p2p/identity/aead_nonce_test.dart` + KAT vectors `frontend/test/p2p/identity/xchacha_kat_test.dart`. Defensive: a runtime assert in the encrypt path catches any (dir, seq) pair already used in the session and triggers `XCHACHA_NONCE_REUSE_DETECTED` — should be unreachable; if it ever fires it's a critical bug.
- [ ] **Associated data (AAD)** for every AEAD frame: `wire_version || frame_type || session_id`. Tampering with the unencrypted CBOR envelope fails decryption. **Proof:** `frontend/test/p2p/identity/aead_aad_test.dart`.

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

- [ ] SQLite WAL with `litestream` replication to S3-compatible object storage. **Wrong v3 claim corrected:** litestream provides DR (cold restore), not HA. **v5 HA design:**
  - Single regional **primary** owns all writes. Read replicas via litestream `replicate` for analytics and degraded-read paths.
  - **Hot offer/ICE table** is fronted by a Valkey (Redis-compatible) cluster with cross-region async replication; visibility lag target ≤5 s, hard cap 30 s (offer TTL is 5 min so 30 s skew is tolerable). Authoritative store remains SQLite; Valkey is a cache.
  - **Failover model:** active/standby across two regions. On primary failure, standby is promoted via a documented manual runbook (target RTO ≤ 10 min, RPO ≤ 5 s via litestream WAL ship interval). Multi-master write is **out of scope for v1** — documented trade-off (cost & complexity vs. solo-operator capacity).
  - **Read-only mode:** when the primary is unavailable, all replicas serve `GET /v1/offers/poll` (cached/last-known) and reject writes with HTTP 503 + `X-ReadOnly-Reason: failover-in-progress`. Clients surface a friendly "matchmaking briefly unavailable". **Proof:** `signaling/internal/store/ha_degraded_test.go` + `signaling/test/chaos/failover_drill_test.go` (kills primary, asserts standby serves reads within 60 s and rejects writes correctly until promotion).
- [ ] Schema migrations via `golang-migrate`; forward-only with explicit `down_migration_blocked: true` markers on irreversible changes. **Proof:** `signaling/internal/store/migrate_test.go` + `signaling/internal/store/migrate_irreversible_test.go`.
- [ ] PII minimisation: store account pubkey, push token (encrypted at rest with server KMS key, KMS key replicated cross-region for failover), wrapped recovery blob, `last_seen_ts`, IP-coarsened (`/24` IPv4, `/48` IPv6) for abuse heuristics only. **Proof:** schema review + `signaling/internal/store/pii_audit_test.go` (greps schema for forbidden columns).
- [ ] Retention: pending offers TTL = 5 min, push tokens auto-purged after 30 d of inactivity, rebound accounts keep an audit row for 90 d, transcripts (if user opts to upload for dispute) auto-purged at 30 d. **Proof:** `signaling/internal/store/retention_test.go`.
- [ ] **Backup integrity drill:** monthly automated cold-restore from litestream into a scratch instance, schema-verify, sample-row-verify. **Proof:** `signaling/test/dr/cold_restore_drill_test.go` (CI monthly).

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

### 4.6 Mid-game resync protocol

- [ ] **Trigger:** ICE restart succeeded but the peers' last-acked sequence numbers may differ. Both peers MUST send a `SYNC_REQ` carrying `(my_last_sent_seq, my_last_acked_remote_seq, my_state_hash_at_last_acked_ply)`.
- [ ] **Resolution:** the peer with strictly more state replays each unacked `MOVE` frame in order. Peers compare `state_hash` at the agreed common ply; mismatch → `MISMATCH` with forensic bundle. Equal → game continues from the higher of the two `seq` values.
- [ ] **Hard timeout:** resync that does not converge within 30 s ends the session as `RESYNC_TIMEOUT`, partial transcript saved, opponent surfaced as "connection unstable, game ended".
- [ ] **Clock handling during resync:** **both peers' clocks pause** when ICE goes `disconnected` and resume on first successful `MOVE_ACK` post-resync. Pause duration is recorded in the transcript. Cap: total pause across a game ≤ 5 minutes; over cap → game ends (`NETWORK_LOST`). **Proof:** `frontend/test/p2p/protocol/resync_test.dart` (state-machine), `frontend/test/p2p/transport/resync_synthetic_test.dart` (L5 fake transport with packet loss), `frontend/test/p2p/transport/resync_real_webrtc_test.dart` (L6 nightly).
- [ ] **Idempotency:** replayed `MOVE` frames must be idempotent on the receiver — already-processed `seq` values are silently re-acked, never re-applied. **Proof:** `frontend/test/p2p/protocol/move_idempotent_test.dart`.

### 4.7 Perfect negotiation, DataChannel re-establishment, web platform

- [ ] **Perfect-negotiation pattern** (W3C WebRTC spec): each peer's role is `polite` if its `device_pubkey_fingerprint` sorts lexicographically lower than the peer's, else `impolite`. On simultaneous offer collision, the impolite peer's offer wins; the polite peer rolls back its local description. **Proof:** `frontend/test/p2p/transport/perfect_negotiation_test.dart` + `frontend/test/p2p/transport/perfect_negotiation_fuzz_test.dart` (1k random simultaneous-offer scenarios, no deadlock).
- [ ] **DataChannel re-establishment after ICE restart:** if SCTP association does not survive, both peers re-create the `chess` and `clock` channels with the same labels and negotiated IDs (`negotiated: true, id: 1` for chess, `id: 2` for clock) so the state machine can resume without renegotiation. **Proof:** `frontend/test/p2p/transport/datachannel_reestablish_test.dart`.
- [ ] **Web platform scope.** Web build supports: WebRTC DataChannel (Chromium/Firefox/Safari latest 2), IndexedDB-backed local SQLite alternative (sql.js or sqflite_common_ffi_web), WebCrypto Ed25519 / X25519 (non-extractable keys). Web build does **not** support: account recovery (non-extractable WebCrypto keys can't be wrapped), cross-device migration, push wakeups (Web Push complexity deferred to Phase 7). Web feature-gated by `kEnableP2PWeb` independently of mobile. **Proof:** `frontend/test/p2p/web/web_capability_matrix_test.dart` (run under `flutter test -d chrome`).
- [ ] **iOS Safari quirks:** WebRTC behind Lockdown Mode is unsupported; surface `WEBRTC_NOT_SUPPORTED` with explicit guidance. **Proof:** documented manual matrix entry.

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
- [ ] **Efficiency / cost model:** signaling cost per active user ≤ $0.01/month at 100k MAU, broken down per line item (not a single number). Target breakdown at 100k MAU, average 4 sessions/user/month, 60 plies/session, 30% TURN-relayed, 200 KB cipher/relay-min:
  - Signaling compute (2 × 1 vCPU / 512 MB Fly.io / Fargate equivalent): ~$30/month → $0.0003 / MAU
  - TURN egress (coturn, 30% relayed sessions × ~6 MB/session): dominant cost, ~$700/month at $0.09/GB → $0.007 / MAU. **Mitigation:** TURN over TCP/443 only on fallback; aggressive direct-ICE preference; consider per-region TURN to keep traffic in-region.
  - Push (APNs free; FCM free; SMS / fallback channels not used): ~$0
  - S3 storage (litestream WAL ~50 GB hot, transcripts opt-in ~10 GB): ~$2/month → negligible
  - Observability backend (Prometheus + Loki self-hosted on signaling box): included; if hosted (Grafana Cloud free tier exhausted) ~$50/month → $0.0005 / MAU
  - **Total target: $0.008 / MAU; ceiling $0.01 / MAU.** Above ceiling → queue entry `kind: p2p_cost_overrun`. **Proof:** monthly cost report committed to `agent/reports/p2p/cost-<yyyy-mm>.md`.
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
- [ ] License audit: libsodium (ISC), coturn (BSD), litestream (Apache-2.0), `package:cryptography` (Apache-2.0), Go stdlib (BSD), Valkey (BSD). Compatible with project licence. Documented in [docs/P2P_LICENSES.md](P2P_LICENSES.md). **Proof:** `scripts/p2p/check-licenses.sh` in CI.
- [ ] **Reproducible builds — specific technique** (corrects v4 hand-wave):
  - **Server (Go):** `CGO_ENABLED=0 go build -trimpath -buildvcs=false -ldflags='-buildid= -s -w' -o signaling-server ./cmd/signaling-server`. Pin Go version in `.tool-versions`. **Proof:** `scripts/p2p/verify-reproducible-build.sh` rebuilds three times and asserts `sha256sum` identical.
  - **Client Android:** `flutter build apk --release --no-tree-shake-icons` with `SOURCE_DATE_EPOCH` exported, `--build-mode release`, R8 single-threaded (`android.r8.maxThreads=1`), post-pass with [`strip-nondeterminism`](https://salsa.debian.org/reproducible-builds/strip-nondeterminism) on the APK to normalise ZIP entry order and timestamps. **Proof:** same script.
  - **Client iOS:** **best-effort only.** Documented in [docs/P2P_LICENSES.md](P2P_LICENSES.md) why — Apple toolchain (codesign, dSYM, build timestamps) does not currently support deterministic builds. Mitigation: per-release SHA published; SBOM published; users on F-Droid-equivalent path get the Android reproducible build.
  - **Native engine:** built with `SOURCE_DATE_EPOCH=$(git log -1 --format=%ct HEAD frontend/native/engine/) cmake ... && cmake --build ...`; CI asserts the produced `.so/.dylib/.dll` is byte-identical across two runs.
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

### 8.8 Operator model and on-call

- [ ] **Ownership declaration:** name (or pseudonym) and role of each operator who can promote a standby region, rotate a KMS key, or trigger the kill-switch is committed to [docs/P2P_OPERATIONS.md](P2P_OPERATIONS.md). For a solo-maintained deployment, this MUST acknowledge the bus factor of 1 and define a degraded-mode default (see below).
- [ ] **Degraded-mode default for solo / sleeping operators:** if the on-call cannot acknowledge an alert within `T_ack` (default 60 minutes for solo deployments), the alerting system automatically sets `kEnableP2P=false` via the signed-config endpoint and surfaces a maintenance message to clients. Better to fail closed than to ship a brittle service overnight. **Proof:** `signaling/internal/admin/auto_killswitch_test.go`.
- [ ] **Runbook coverage:** [docs/P2P_SIGNALING_RUNBOOK.md](P2P_SIGNALING_RUNBOOK.md) MUST cover: standby promotion, KMS rotation, push-provider revocation (compromised FCM/APNs key), kill-switch toggle, restoring from litestream cold backup, scaling out coturn, rotating TURN HMAC secret. Each runbook step has a **drill date** column; drills run quarterly. **Proof:** `docs/P2P_OPERATIONS_DRILL_LOG.md` updated.
- [ ] **Secret hygiene:** all server secrets (TURN HMAC secret, KMS key, push provider keys, signed-config signing key) live in a sealed-secrets / SOPS-encrypted store committed to the repo, decryptable only by operator keys. No secret in plain text in CI logs, env files, or container layers. **Proof:** `scripts/p2p/audit-secrets.sh` + CI gate.
- [ ] **Signed-config rotation:** the signing key for `kEnableP2P` and other remote-config flags is rotated annually; clients ship with the current key + a one-step-back trust window. **Proof:** `frontend/test/p2p/config/signing_key_rotation_test.dart`.

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
- [ ] **T-M-004** Account device-fingerprint UI is an **intentional stable cross-game identifier**, so two-game stalkers (Phase 9.2 T-P-006) are exposed. *Documented honestly:* the same fingerprint reveals "this is the same opponent" across games — by design. Users wanting unlinkable play must rotate the recovery code (→ new account). *Proof:* documentation entry in [docs/P2P_PRIVACY.md](P2P_PRIVACY.md) + UX copy.
- [ ] **T-M-005** Transcript content (move list, clock history, chat) is end-to-end encrypted in transit and stored locally only by default; opt-in upload for dispute resolution writes only the cryptographic fields needed for verification (no chat). *Proof:* `signaling/internal/transcript/upload_minimisation_test.go`.
- [ ] **T-N-008** Signaling cookie / session-id fingerprinting across IP changes. *Mitigation:* signaling sessions are short-lived (offer TTL 5 min, no long-lived cookie); rebind requires fresh recovery flow. *Proof:* `signaling/internal/auth/session_lifetime_test.go`.

### 9.6 Supply chain

- [ ] **T-X-001** Compromised libsodium release. *Mitigation:* pin SHA, verify against multiple mirrors, SBOM diff review. *Proof:* `check-deps.sh`.
- [ ] **T-X-002** Compromised pub.dev or proxy. *Mitigation:* lockfile + checksum verification. *Proof:* CI lockfile gate.
- [ ] **T-X-003** Build-system tampering. *Mitigation:* hermetic builds + reproducible-build verification. *Proof:* `verify-reproducible-build.sh`.
- [ ] **T-X-004** GitHub Actions secret leak via fork PRs. *Mitigation:* `pull_request_target` is forbidden in any P2P-related workflow; all secret-bearing jobs run only on `push` from a trusted branch; CodeQL workflow scans for `pull_request_target` reintroduction. *Proof:* `.github/workflows/no-pull-request-target.yml` + grep gate in CI.
- [ ] **T-X-005** Compromised release-signing key (cosign / Apple ID). *Mitigation:* signing keys live in offline-only HSM / hardware-token; air-gapped signing for releases; transparency log (Sigstore Rekor) catches surprise signatures. *Proof:* documented in [docs/P2P_OPERATIONS.md](P2P_OPERATIONS.md).

### 9.7 Engine / replay-parity threats (defensive)

- [ ] **T-P-007** Engine search uses a non-deterministic PRNG (`xorshift64` seeded from wall clock; see [frontend/native/engine/search.c](../frontend/native/engine/search.c) lines 149–196). This is **safe** for P2P because move *selection* is a local UX concern that never crosses the wire — only legality + canonical state hash do (§1.1). Defensive proof: a fuzz test exchanges random move sequences and asserts that *receivers* never use search PRNG output for any decision affecting `state_hash`. *Proof:* `frontend/test/p2p/engine/no_prng_in_replay_path_test.dart`.
- [ ] **T-P-008** Engine replay-version drift between peers (same source build, different compiler flags producing different rule outputs in pathological mod-corner cases). *Mitigation:* the `replay_version_golden_test.dart` 10k-position golden across all 7 mods (see [Phase 12](#phase-12--engine-replay-version-pinning)) catches this in CI. Optional runtime: first 8 frames of every session attach the local hash of the engine's rule-test golden output; `MISMATCH` if these differ. **Status:** runtime check is OQ-14-adjacent, deferred to Phase 12 sprint.

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

### 10.1 v5 additions to the catalog

- [ ] **F-PROTO-009** `WIRE_VERSION_MISMATCH` — `HELLO.wire_version` is unsupported. *Recovery:* end before any move, surface "update required".
- [ ] **F-PROTO-010** `ENGINE_VERSION_MISMATCH` — `HELLO.engine_replay_version` differs (see [Phase 12](#phase-12--engine-replay-version-pinning)). *Recovery:* end before any move, surface "both players need to be on app version ≥ X".
- [ ] **F-PROTO-011** `MOD_CONFIG_REJECTED` — responder cannot honour proposer's `mod_config` (e.g. unknown variant key). *Recovery:* end pre-game, surface "opponent does not support this mod variant".
- [ ] **F-PROTO-012** `TIME_CONTROL_REJECTED` — responder declines proposed time control. *Recovery:* end pre-game, allow re-invite with different TC.
- [ ] **F-PROTO-013** `COLOR_FLIP_REVEAL_MISMATCH` — reveal does not hash to commit. *Recovery:* end pre-game, log offending fingerprint locally.
- [ ] **F-PROTO-014** `TRANSCRIPT_SIGN_FAILED` — device key signature over `BYE` payload failed locally. *Recovery:* keep partial transcript, surface to user as "could not record game".
- [ ] **F-PROTO-015** `BYE_DISAGREEMENT` — peers disagree on result / termination reason. *Recovery:* both keep their own transcript; forensic bundle written; surface dispute UI; never auto-pick a side.
- [ ] **F-CLOCK-001** `CLOCK_DESYNC_BEYOND_BUDGET` — NTP-style offset estimator drift > 500 ms or RTT P95 > 1 s for 30 s. *Recovery:* end session as `NETWORK_LOST`-equivalent, transcript recorded.
- [ ] **F-CLOCK-002** `FLAG_FALL_DISAGREEMENT` — one peer thinks opponent flagged, opponent thinks not. *Recovery:* `MISMATCH` with full clock-history forensic bundle.
- [ ] **F-CLOCK-003** `RESYNC_TIMEOUT` — mid-game resync did not converge in 30 s. *Recovery:* end session, partial transcript recorded.
- [ ] **F-XPORT-003** `PERFECT_NEG_COLLISION_UNRESOLVED` — perfect-negotiation pattern produced an unresolvable rollback (impossible by spec; defensive). *Recovery:* tear down DataChannels, attempt fresh ICE; if it recurs once, end session.
- [ ] **F-SIG-007** `OFFER_TOKEN_EXPIRED` — push-wake redeem token > 90 s old. *Recovery:* server returns 410; client re-polls offers.
- [ ] **F-SIG-008** `READ_ONLY_MODE_REJECTED_WRITE` — client tried to register/rebind during failover. *Recovery:* respect `Retry-After`, surface "matchmaking briefly unavailable".
- [ ] **F-SIG-009** `REBIND_RACE_LOST` — two new devices raced for the same recovery code; loser. *Recovery:* surface "another device just claimed your account; if that wasn't you, rotate your recovery code".
- [ ] **F-ID-008** `KDF_VERSION_UNSUPPORTED` — wrapped blob's `kdf_version` newer than client supports. *Recovery:* surface "please update the app"; never attempt with unsupported params.
- [ ] **F-ID-009** `BIP39_CHECKSUM_FAIL` — recovery code typo caught locally. *Recovery:* surface "check the words you entered" before any Argon2 work.
- [ ] **F-ID-010** `KDF_PARAMS_TOO_WEAK` — attempt to wrap with params below floor. *Recovery:* refuse, log; should be unreachable.
- [ ] **F-ID-011** `XCHACHA_NONCE_REUSE_DETECTED` — defensive runtime check fired. *Recovery:* abort session, write critical forensic bundle, file `kind: crash / severity: critical` queue entry.
- [ ] **F-INTEGRITY-001** `STARTUP_INTEGRITY_FAIL` — app-wide tamper detection on launch (signed config blob, native lib hash) failed. *Recovery:* refuse to enable P2P; surface "app integrity check failed; please reinstall".
- [ ] **F-WEB-003** `WEB_PLATFORM_UNSUPPORTED_FEATURE` — user attempted recovery / migration on web build. *Recovery:* surface "this feature is mobile-only".
- [ ] **F-DESKTOP-002** `BIOMETRIC_NOT_AVAILABLE_DESKTOP` — Linux without libsecret + biometric. *Recovery:* fallback documented; surface security notice.
- [ ] **F-OBS-002** `DIAG_LOG_DISK_FULL` — ring buffer rollover failed because disk is full. *Recovery:* drop oldest in-memory; never block; surface low-priority OS-settings hint.
- [ ] **F-OPS-001** `KILL_SWITCH_ENGAGED` — server-side `kEnableP2P=false`. *Recovery:* friendly maintenance UI; check again in 10 minutes.

---

## Phase 11 — Chess clock and time control

**Goal:** Two-peer chess clocks with bounded asymmetric delay, NTP-style offset estimation, deterministic flag-fall consensus, and explicit pause semantics during network events. *0% complete.*

v4 had `CLOCK_STARVATION` as a failure mode but no actual clock protocol. P2P clocks are the hardest distributed-systems problem in this roadmap because every blitz player loses on time eventually and every loss must be agreed by both peers without a referee.

### 11.1 Time-control negotiation

- [ ] `HELLO.time_control` (defined in [Phase 1.1](#11-spec)) is the source of truth. Supported `tc_kind`: `none` (correspondence), `sudden_death` (single bank), `fischer` (increment per move), `bronstein` (delay per move), `byo_yomi` (overtime periods). Custom presets out of scope for v1.
- [ ] **Validation in `HELLO_ACK`:** responder rejects invalid combinations (e.g. `byo_yomi` without overtime periods) with `TIME_CONTROL_REJECTED`. Proposer can re-invite. **Proof:** `frontend/test/p2p/clock/tc_negotiation_test.dart`.

### 11.2 NTP-style offset and delay estimation

- [ ] On the unreliable `clock` DataChannel: every 5 s and on every move boundary, each peer sends `CLOCK_OFFSET_REQ { t_send }` and the receiver replies `CLOCK_OFFSET_RESP { t_send_echo, t_recv, t_resp }`. Standard NTP equations: `offset = ((t_recv - t_send) + (t_resp_echo - t_resp)) / 2`, `delay = (t_resp_echo - t_send) - (t_resp - t_recv)`.
- [ ] Each peer maintains an exponentially-weighted moving estimate of `(offset, delay)` with the lowest-delay sample favoured (NTP best-RTT selection). **Proof:** `frontend/test/p2p/clock/ntp_estimator_test.dart` (KAT vectors against synthetic clock skew).
- [ ] **Hard budget:** if `delay_p95` over the last 30 s exceeds 1 s **or** `|offset|` drift > 500 ms, the session is ended as `CLOCK_DESYNC_BEYOND_BUDGET` (§10.1) before either player loses unfairly on time. **Proof:** `frontend/test/p2p/clock/desync_budget_test.dart`.

### 11.3 Authoritative-clock rule

- [ ] **Each peer is authoritative on its own clock.** Local clock starts when it has fully decoded + engine-validated the opponent's `MOVE` and emitted `MOVE_ACK`. Local clock stops when it sends its own `MOVE` (after engine-validating its own move locally). Time spent in the network on the wire is **not charged** to either side; the increment / delay configured in `time_control` accounts for typical RTT. This rule is documented in [docs/P2P_PROTOCOL.md](P2P_PROTOCOL.md) §clock and is **non-negotiable** — without it, the slow-network player has an unfair handicap.
- [ ] **Clock pause windows:** clocks pause when ICE is in `disconnected`/`failed` state, when the app is backgrounded mid-turn (best-effort — OS may suspend before pause is recorded; documented honestly), and during mid-game resync (§4.6). Total pause budget per game is 5 minutes; over budget → game ends as `NETWORK_LOST`. Pause history is recorded in the transcript. **Proof:** `frontend/test/p2p/clock/pause_budget_test.dart`.

### 11.4 Flag-fall consensus

- [ ] When peer A's local view has peer B's clock at ≤0: A emits `BYE { result: timeout, victor: A, b_clock_at_my_view: …, my_clock_at_send: … }`. B verifies against its own clock view; if B agrees (within a 200 ms tolerance to absorb estimator jitter), B counter-signs the transcript. If B disagrees by more than the tolerance: `FLAG_FALL_DISAGREEMENT` → `MISMATCH` with full clock-history forensic bundle. **Proof:** `frontend/test/p2p/clock/flag_fall_test.dart` (× honest, × borderline-tolerance, × disagreement-beyond-tolerance, × both-flag-simultaneously).
- [ ] **Borderline UX:** when both peers' clocks are < 5 s, UI shows estimated remaining time with an explicit "net delay ± N ms" badge so the player understands the protocol. **Proof:** `frontend/test/p2p/ui/clock_low_time_ui_test.dart`.

### 11.5 Quality attributes

- [ ] **Performance:** offset-estimator overhead ≤ 0.1% CPU on a Pixel 4a; clock-tick UI runs at native frame rate.
- [ ] **Efficiency:** `CLOCK_OFFSET_REQ/RESP` traffic ≤ 1 KB/min per peer.
- [ ] **Stability:** clock never goes negative on the local view; arithmetic uses signed `i64` ms with explicit clamp; **proof:** `frontend/test/p2p/clock/arithmetic_safety_test.dart`.
- [ ] **Reliability:** in 1k synthetic blitz games (3+0, 1+0, 1+1) at 0–500 ms jitter and 0–2% loss, zero `FLAG_FALL_DISAGREEMENT` events caused by the estimator (only by genuine packet loss in the test); **proof:** `frontend/test/p2p/clock/blitz_chaos_test.dart`.
- [ ] **Integrity:** clock state at game end is part of the signed transcript; tampering one side's record is detectable cross-side.

### 11.6 Acceptance gate

- [ ] All 11.1–11.5 ticked, blitz chaos green, clock spec section in [docs/P2P_PROTOCOL.md](P2P_PROTOCOL.md) §clock published.

---

## Phase 12 — Engine replay-version pinning

**Goal:** Both peers must run the exact same chess-rule semantics, or replay parity is meaningless. A behaviour-affecting change to `frontend/native/engine/**` cannot ship without bumping a version field that is exchanged in `HELLO`. *0% complete.*

### 12.1 Versioning scheme

- [ ] `ENGINE_REPLAY_VERSION: u32` lives in [frontend/native/engine/replay_version.h](../frontend/native/engine/replay_version.h) and is emitted by the build into a static symbol exposed via FFI. Bumped manually for any change that affects: move generation, legality, draw rules, mod-specific rules, canonical state hash. **Not** bumped for: search-only changes, eval-only changes, opening book content, performance tuning that does not affect move legality.
- [ ] **CI gate:** a workflow `engine-replay-version-bump-required.yml` greps the diff of `frontend/native/engine/{board,moves,rules,mods}/**` and `frontend/native/engine/bridge_*_refine_result.c` and fails the PR / push if those paths changed without `replay_version.h` changing. Override: a queue entry `kind: engine_replay_no_bump_justified` with a written rationale (e.g. comment-only change, internal refactor with proof of identical output via golden tests). **Proof:** `.github/workflows/engine-replay-version-bump-required.yml` + `frontend/test/native/replay_version_golden_test.dart` (10k-position move-list golden across all 7 mods; bumping the version implies regenerating the golden in the same PR).
- [ ] **Cosmetic / build-only changes:** a separate `BUILD_REPLAY_VERSION: u32` is auto-bumped by CI on every native-lib rebuild. `HELLO` carries it as informational only; mismatch is **not** an error.

### 12.2 Negotiation and failure mode

- [ ] On `HELLO`/`HELLO_ACK` exchange, exact match on `ENGINE_REPLAY_VERSION` is required. Mismatch → `ENGINE_VERSION_MISMATCH` (§10.1), friendly UI: "Both players need to be on app version ≥ X. The newer player has version Y; the older has Z." Surface a deep link to the app store.
- [ ] **Backward-compat policy:** none in v1. Replay parity is bit-exact or no-game. A future version may introduce a `MIN_COMPATIBLE_REPLAY_VERSION` floor for graceful skew, but **only** if backed by exhaustive cross-version golden tests.

### 12.3 Quality attributes

- [ ] **Performance:** version check is O(1) at handshake.
- [ ] **Efficiency:** version field is 4 bytes on the wire.
- [ ] **Stability:** golden tests catch any silent regression in legality / draw rules across the 7 mods; **proof:** `replay_version_golden_test.dart`.
- [ ] **Reliability:** PR CI fails before merge; no "oops, forgot to bump" landing on `main`.
- [ ] **Integrity:** version is part of the AAD on the first AEAD frame post-handshake (`MOVE` n=0); tampering cross-validates.

### 12.4 Acceptance gate

- [ ] All 12.1–12.3 ticked, golden tests in CI, `replay_version.h` exists with version 1, `HELLO` carries it.

---

## Phase 13 — Anti-cheat and fair play (scope declaration)

**Goal:** Honestly state what pure P2P architecture **cannot** solve, and document the partial mitigations the client can offer. *0% complete — mostly a documentation phase.*

### 13.1 Out-of-scope acknowledgement

- [ ] **External-engine assistance** (a player runs Stockfish in another window and copies moves) **cannot be detected by a pure-P2P architecture.** There is no central observer of move quality. v1 explicitly does not attempt to detect it. This is documented in [docs/P2P_FAIR_PLAY.md](P2P_FAIR_PLAY.md) and surfaced in the UI on first P2P launch ("Casual play — no anti-cheat enforcement").
- [ ] **Rating system** is similarly out of scope for v1. A rating system requires either a central observer (contradicts the dumb-signaling principle) or a federated trust network (Phase 7 stretch). Documented as OQ-10.

### 13.2 Partial client-side mitigations (opt-in)

- [ ] `HELLO.capabilities.no_engine_pledge: bool` — a soft pledge surfaced in opponent UI ("opponent has pledged not to use engine assistance"). Not enforceable; informational only. **Proof:** `frontend/test/p2p/ui/no_engine_pledge_ui_test.dart`.
- [ ] **Move-time histogram in opponent UI** (opt-in, mutual): each peer can opt to share its per-move think-time histogram at game end. Suspiciously consistent timings (low variance, high quality) hint at engine assistance but never accuse — left to the player. **Proof:** `frontend/test/p2p/ui/think_time_histogram_test.dart`.
- [ ] **Casual / Friend mode:** when both peers' devices share a recent contact-graph signal (out of scope for the cryptographic protocol; could come from QR-code mutual-friending), `casual_mode=true` enables takebacks and disables histogram sharing.

### 13.3 Future federated-rating door

- [ ] If federation (Phase 7) ever ships, a third-party rating service can subscribe (with both peers' consent) to signed transcripts and run aggregate cheat-detection (CPL outlier detection, time-control anomaly detection). Out of scope for v1; tracked in OQ-10.

### 13.4 Quality attributes

- [ ] **Performance / Efficiency:** none of the mitigations cost runtime; they are UI surface only.
- [ ] **Stability:** the pledge / histogram features cannot end a game; they are informational.
- [ ] **Reliability:** the docs accurately reflect what is and isn't enforceable; no marketing claims about "cheat-proof play".
- [ ] **Integrity:** the histogram comes from the local clock state, not from the opponent's report; an opponent cannot forge their own histogram in the displayed view.

### 13.5 Acceptance gate

- [ ] [docs/P2P_FAIR_PLAY.md](P2P_FAIR_PLAY.md) published before beta opens; UI surfaces the casual-play disclosure on first P2P launch.

---

## Open questions (must be resolved before the corresponding gate)

- [ ] **OQ-1** Web / desktop scope for GA — full parity, reduced (no recovery), or excluded? *Decision required before:* Phase 6. **v5 default:** web is reduced (no recovery, no push), behind separate `kEnableP2PWeb` flag, GA-stretch only.
- [ ] **OQ-2** Self-host vs managed TURN at GA cost-vs-reliability — what's the break-even? *Decision required before:* Phase 6 cost model. **v5 default:** self-host coturn per region until egress > 5 TB/month, then re-evaluate Twilio / Cloudflare TURN.
- [ ] **OQ-3** Spectator / tournament priority order in Phase 7. *Decision required before:* Phase 7 kickoff.
- [ ] **OQ-4** Federation appetite — is cross-server play desirable, or a one-vendor approach forever? *Decision required before:* Phase 7.5.
- [ ] **OQ-5** Engine-correlation tolerance — is the >5% rule too tight given P2P adds CPU work on receive? *Decision required before:* Phase 1 acceptance.
- [ ] **OQ-6** Recovery wordlist languages — which beyond English at GA? *Decision required before:* Phase 8.1 close-out.
- [ ] **OQ-7** Push-wake daily ceiling — start at 50, justify in beta. *Decision required before:* beta opens.
- [ ] **OQ-8** Data residency regions for GA. *Decision required before:* Phase 8.5.
- [ ] **OQ-9** APK / IPA size budget — what's the ceiling we accept for libsodium + WebRTC? *Decision required before:* Phase 4 acceptance. **v5 working figure:** +6 MB Android, +9 MB iOS over current single-player APK.
- [ ] **OQ-10** Rating system & cheat-detection appetite. Pure P2P cannot enforce; if ratings are required, federation or a trusted observer service is needed. *Decision required before:* Phase 13 close-out.
- [ ] **OQ-11** Acceptable RTO/RPO for the signaling failover. v5 working figures: RTO ≤ 10 min, RPO ≤ 5 s. *Decision required before:* Phase 3.7.
- [ ] **OQ-12** Solo-operator policy — do we ship with the auto-killswitch on a 60-minute unacknowledged-alert timeout, or staff a real on-call before GA? *Decision required before:* Phase 8.8.
- [ ] **OQ-13** Transcript upload — opt-in only, opt-in by default, or never offered? Privacy vs dispute-resolution trade-off. *Decision required before:* beta opens.
- [ ] **OQ-14** Re-key policy on `engine_replay_version` bump — does the bump invalidate ongoing sessions? v5 working answer: no, ongoing sessions complete on the version they started on; new sessions use the new version. *Decision required before:* Phase 12 acceptance.
- [ ] **OQ-15** Push-wake redeem-once token storage — in-memory only, or persisted to survive a server restart? Trade-off: persistence widens DR window, in-memory loses tokens on restart but is privacy-cleaner. *Decision required before:* Phase 3 acceptance.
- [ ] **OQ-16** Late-join / reconnect for already-completed move list — does the spec support a cold-rejoin from a fully-archived game (study mode), or only mid-session resync? *Decision required before:* Phase 7 late-join sub-task.

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
                  Phase 11 (chess clock) lands inside Phase 1 schedule slot;
                          its acceptance gate must pass before Phase 6 beta.
                  Phase 12 (engine_replay_version pinning) is a Phase 1
                          prerequisite — its CI gate must be live before
                          ANY box in Phases 1, 4, 6 can be ticked, because
                          replay parity is meaningless without it.
                  Phase 13 (anti-cheat scope) is documentation-only; can
                          land any time before beta but the casual-play UI
                          disclosure is a hard beta-blocker.
```

**Hard prerequisite ordering (v5):**

1. [Phase 5 §5.1](#51-fake-transports) (CI wiring + fake transports) is a hard prerequisite for ticking any box outside Phase 0. No proof test counts if CI cannot run it.
2. [Phase 12](#phase-12--engine-replay-version-pinning) (engine-replay-version CI gate) is a hard prerequisite for ticking any Phase 1 / Phase 4 / Phase 6 box, for the reason above.
3. [Phase 8.8](#88-operator-model-and-on-call) (operator model & auto-killswitch) is a hard prerequisite for the Phase 6 beta-open gate. Shipping a P2P feature with no plan for what happens at 03:00 UTC on a long weekend is a violation of the integrity charter.

Critical-path summary: **Phase 0 → Phase 5 §5.1 + Phase 12 → Phase 1 + Phase 11 → Phase 4 → Phase 8.8 → Phase 6**. Phases 2 and 3 are parallelisable but must converge before Phase 4's network-change + push-wake testing.

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
- RFC 8439 — ChaCha20-Poly1305 (and XChaCha20-Poly1305 IETF draft / libsodium reference)
- RFC 5905 — NTPv4 (offset / delay equations used by [Phase 11](#phase-11--chess-clock-and-time-control))
- BIP-39 — Mnemonic code for generating deterministic keys (used for the recovery wordlist; checksum semantics)
- W3C WebRTC 1.0 — `RTCDataChannel`, perfect-negotiation pattern (Appendix B)
- libsodium documentation
- Play Integrity API; Apple DeviceCheck / App Attest
- litestream documentation; Valkey (Redis-compatible) documentation
- coturn documentation
- Sigstore / cosign docs; SLSA provenance levels
- CycloneDX SBOM spec
- Reproducible Builds project ([reproducible-builds.org](https://reproducible-builds.org/)); `strip-nondeterminism`

---

> **Reminder for AI assistants editing this file:** Per [.github/copilot-instructions.md](../.github/copilot-instructions.md) and [AGENTS.md](../AGENTS.md), changing this roadmap is a doc-only change and does not require engine gates, but does require commit + push to `origin/main` once the edit is complete. Ticking a box from `[ ]` to `[x]` requires the proof tests cited beside the box to be green on `main` and the relevant KPI baseline updated; otherwise use `[~]`.
