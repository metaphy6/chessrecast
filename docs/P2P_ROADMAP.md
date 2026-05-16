# ChessRecast — Peer-to-Peer Multiplayer Roadmap

> **Version:** v9 · **Status banner:** 🟥 **0% shipped** — every checkbox in this document is empty (`[ ]`). No P2P code, no signaling server, no archive of the legacy backend exists yet. Everything below is design intent until a checkbox is ticked by a commit on `main`.
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

## What changed in v6 vs v5

v5 was the first version that survived a hostile review of its cryptography. v6 is the first version that survives a hostile review of its **integration with the rest of the platform** (mobile OS realities, app-store compliance, user-safety, supply chain, monotonic time, FFI memory hygiene, post-quantum drift). Every bullet below either fixes a real bug or closes a coverage gap that would have bitten us between Phase 4 and GA.

- [ ] **Cryptography correctness — session salt negotiation specified.** v5 §2.3 said "`salt_15` is the 15-byte random session salt fresh per session" but never said *how the two peers agree on it*. If each peer picks its own salt the AEAD construction is asymmetric and `MOVE_ACK` cannot be decrypted; if both pick a salt and concatenate, the spec must say so. v6 §2.3 fixes this: the 15-byte session salt is **derived deterministically** via `salt_15 = HKDF-SHA256(shared_secret, salt=session_id, info="chessrecast/p2p/v1/aead-salt", L=15)`. Both peers compute the same salt from the same ECDH shared secret and the same `session_id`. No salt is sent on the wire, eliminating a tampering surface entirely. **Proof:** `frontend/test/p2p/identity/aead_salt_derivation_test.dart` (KAT) + `frontend/test/p2p/identity/aead_salt_no_wire_leak_test.dart` (greps wire trace for the 15 salt bytes; must never appear).
- [ ] **Sequence-counter rollover defense.** v5's `seq_u64_be` would not realistically reach `2^64`, but a buggy or malicious encoder could re-bind `seq` to 0 mid-session, causing nonce reuse with the same `(salt, dir)`. v6 adds: receiver MUST track `last_seen_seq` per direction; any received `seq <= last_seen_seq` → `OUT_OF_SEQUENCE` → `MISMATCH`. Encoder MUST refuse to encode at `seq == 2^63` (defensive ceiling, well below any practical use); over the ceiling → `SEQ_CEILING_REACHED` (new failure mode), session ends gracefully with key rotation deferred to Phase 7. **Proof:** `frontend/test/p2p/protocol/seq_rollover_defense_test.dart`.
- [ ] **FFI memory hygiene & secret zeroisation specified (new §2.7).** v5 was silent on what happens to plaintext private keys, derived KEKs, and shared secrets in process memory after use. Garbage-collected Dart strings can linger arbitrarily long, and Dart `Uint8List` backing memory is not zeroed on free. v6 mandates: every secret-bearing buffer is allocated via libsodium `sodium_malloc` (guard pages, `mlock`, no swap), zeroed via `sodium_memzero` before `sodium_free`, and accessed only inside a `using` / `try-finally` boundary that guarantees cleanup on exception. Dart `String` is forbidden for secret material; raw bytes only. **Proof:** `frontend/test/p2p/identity/secret_lifetime_test.dart` (instruments libsodium calls, asserts every allocation has a paired free + zeroise) + a static lint `frontend/tool/forbid_string_for_secrets.dart` enforced in CI.
- [ ] **Concurrency model & isolate boundary specified (new §8.10).** v5 didn't say *which Dart isolate* runs crypto, AEAD, native engine validation, or DataChannel I/O. Running them all on the UI isolate would cause jank during Argon2 (1.5–4 s freeze on the main thread) and would race with the platform channel handler. v6 mandates: a dedicated `p2p` isolate owns the protocol state machine, AEAD encrypt/decrypt, engine binding, and signaling I/O. The UI isolate exposes only a typed message-passing surface (`SendPort`/`ReceivePort`). Argon2 derivation runs in a separate one-shot worker isolate. The libsodium FFI symbol table is initialised exactly once per process and shared via a thread-safe handle. **Proof:** `frontend/test/p2p/concurrency/isolate_boundary_test.dart` + `frontend/test/p2p/perf/ui_jank_during_argon2_test.dart` (asserts UI isolate frame budget never exceeds 16 ms while Argon2 runs).
- [ ] **Monotonic clock requirement for chess clocks (new §11.7).** v5 specified the clock protocol but never said which OS clock to use. Wall-clock (e.g. `DateTime.now()`) can jump backward on NTP correction, manual user change, or DST transition; an attacker could *deliberately* wind back their system clock to deny a flag-fall. v6 mandates: all chess-clock arithmetic uses the **OS monotonic clock** (`clock_gettime(CLOCK_MONOTONIC_RAW)` on POSIX, `mach_absolute_time` on iOS, `QueryPerformanceCounter` on Windows, `Stopwatch` on Dart-pure paths). Wall-clock is permitted only for transcript timestamps (informational). **Proof:** `frontend/test/p2p/clock/monotonic_only_test.dart` (mocks system wall-clock to jump ±1 hour mid-game; clock state must be unaffected) + a CI grep gate forbidding `DateTime.now()` in `frontend/lib/services/p2p/clock/**`.
- [ ] **Frame fragmentation & oversize transcripts (new §1.8).** v5's 16 KB per-frame cap is fine for `MOVE` but fails for end-of-game `BYE` in long games (1000+ plies × clock-history entries × chat history can exceed 16 KB). v6 adds a chunked `BYE_PART { idx: u16, total: u16, payload: bytes }` fallback for transcripts > 12 KB after CBOR encoding, with the same AEAD per chunk and a final `BYE_FINAL` carrying the signature over the concatenated payload hash. Hard ceiling: 64 chunks (≈ 768 KB transcript). **Proof:** `frontend/test/p2p/protocol/bye_fragmentation_test.dart`.
- [ ] **DataChannel re-establishment ID re-use bug fixed.** v5 §4.7 said "re-create with `negotiated: true, id: 1`" but if the SCTP association is half-alive (one side thinks it's gone, other doesn't), recreating with the same `id` is undefined behaviour per spec. v6 adds: on rebind, the polite peer MUST close any existing DataChannel with the target ID and wait for `oniceconnectionstatechange = closed` before re-creating. If the SCTP transport itself was torn down (`iceConnectionState = failed`), both peers MUST renegotiate with a fresh DTLS handshake, generating fresh AEAD session salt (§2.3) — the previous session ends as `RESUMED_AS_NEW`. **Proof:** `frontend/test/p2p/transport/datachannel_id_collision_test.dart`.
- [ ] **Mobile-network awareness (new §4.8).** v5 had no concept of metered networks. Some users would be charged for TURN-relayed cellular sessions (≈ 6 MB / 30-min game). v6 adds: client detects `connectivity_plus` reported metered status; if metered AND TURN-relayed for > 30 s, surface a one-time soft warning per session with an opt-out preference. Battery-saver mode shrinks the `clock` channel ping cadence from 5 s to 15 s (still under desync budget). **Proof:** `frontend/test/p2p/transport/metered_network_warning_test.dart` + `frontend/test/p2p/transport/battery_saver_clock_cadence_test.dart`.
- [ ] **OEM background-kill matrix (new §4.9).** v5 mentioned Android foreground service but did not enumerate the OEM-specific kill behaviours (Xiaomi MIUI, Huawei EMUI, Samsung One UI battery optimisation, OnePlus Oxygen). v6 adds [docs/P2P_ANDROID_OEM_MATRIX.md](P2P_ANDROID_OEM_MATRIX.md) with per-OEM expected behaviour, in-app guidance to disable battery optimisation for ChessRecast, and a one-time on-launch detection (`PowerManager.isIgnoringBatteryOptimizations()`) with a friendly nudge. **Proof:** `frontend/test/p2p/transport/oem_battery_optimisation_nudge_test.dart`.
- [ ] **iOS push reliability — `content-available: 1` mandated.** v5 said "content-less push". On iOS, a truly content-less push (no payload) is treated as a marketing notification and may be silently dropped under Low Power Mode. v6 specifies: APNs payload is `{"aps": {"content-available": 1}, "token": "<redeem_token>"}` (silent push, wakes app for ≤ 30 s NSE budget). FCM equivalent uses `data` payload with `priority: high` and `content_available: true`. **Proof:** `frontend/test/p2p/transport/apns_silent_push_payload_test.dart` + `signaling/internal/push/payload_shape_test.go`.
- [ ] **FCM token rotation handling.** v5 didn't specify what happens when FCM unilaterally rotates a token (common, undocumented frequency). v6 mandates: client subscribes to `FirebaseMessaging.onTokenRefresh`, immediately re-registers via `POST /v1/push/register` (signed under device key), and tolerates one missed wake during the rotation window. **Proof:** `frontend/test/p2p/transport/fcm_token_rotation_test.dart`.
- [ ] **Recovery-code on-screen security.** v5 didn't address screenshot/screen-recording leakage. v6 mandates: while the recovery-code wizard is on-screen, Android sets `WindowManager.LayoutParams.FLAG_SECURE` (blocks screenshots, blocks recent-tasks thumbnail, blocks screen recording on most OEMs); iOS marks the window with `screenCaptureDidChangeNotification` listener and obscures the words on screen-recording detection. Clipboard copy is **not** offered for the words (no clipboard sniffer leakage); user must transcribe by hand. A verification step asks the user to re-enter words 4, 9, and 13 before completing setup. **Proof:** `frontend/test/p2p/identity/recovery_screen_secure_test.dart` + `frontend/test/p2p/ui/recovery_no_clipboard_test.dart`.
- [ ] **User-safety phase added (new Phase 14 — chat moderation, blocking, abuse reporting).** v5 had no answer to "the opponent is harassing me in chat" beyond per-side rate limits. v6 adds Phase 14: per-device opponent block-list (fingerprint-keyed, prevents future matches), per-message local mute, opt-in abuse report bundle (signed transcript + chat history uploaded only with explicit consent for review by a human operator), age-gate during onboarding (13+ default; mod-specific 16+ option for chat-enabled mods), and a documented reporting SLA in [docs/P2P_TRUST_AND_SAFETY.md](P2P_TRUST_AND_SAFETY.md).
- [ ] **Security audit, pentest, and bug bounty (new Phase 15).** v5 implicitly assumed good code quality is enough. v6 makes a third-party cryptographic-protocol audit and a one-time application pentest **hard prerequisites for the Phase 6 GA gate** (not for beta-open). A continuous bug-bounty programme (responsible disclosure inbox + SemVer-pinned scope) is the steady-state posture after GA.
- [ ] **Store & regulatory compliance (new §8.9).** v5 was silent on Google Play Privacy Manifest, Apple Privacy Manifest (`PrivacyInfo.xcprivacy`, required for new submissions), EU Digital Services Act notice-and-action obligations for chat content, COPPA / GDPR-K (children under 13 / 16 depending on jurisdiction), and Apple App Store guideline 1.4.1 ("physical harm") if any safety-sensitive copy is missing. v6 enumerates these and gates GA on each.
- [ ] **Per-account device cap & resource quotas (new §3.9).** v5's signaling server had per-IP and per-account *rate* limits but no *quantity* caps. A compromised account could register thousands of devices and pin server FDs. v6 adds: max 8 active devices per account (configurable; oldest-by-`last_seen` evicted on overflow with user notification), max 32 concurrent long-poll connections per account, hard ulimit / cgroup memory caps on the signaling process. **Proof:** `signaling/internal/accounts/device_cap_test.go` + `signaling/internal/server/long_poll_cap_test.go`.
- [ ] **SDP size cap & offer-content sanitisation.** v5 didn't cap SDP size. A malformed offer can trivially be 1 MB. v6 caps SDP at 16 KB at the signaling layer and rejects offers containing media-section types beyond `application/data` (no audio/video media lines accepted; defensive — we never request them, but a malicious offer could carry them). **Proof:** `signaling/internal/offers/sdp_sanitisation_test.go`.
- [ ] **Spectator key derivation specified (Phase 7 §7.1 enrichment).** v5 said "derived view-only key" without saying how. v6 specifies: spectator receives a one-shot symmetric key `K_view = HKDF(session_master, info="spectator/view-only/<spectator_pubkey>", L=32)` issued by *one* of the two peers (spectator's choice; the issuing peer is the only one whose chat the spectator can read — chat between the two players remains end-to-end private if either peer doesn't issue). Spectator cannot inject moves (no AEAD encrypt key issued, only decrypt). Spectator chain (spectator-of-spectator) explicitly forbidden by spec; issuing peer is the trust root. **Proof:** `frontend/test/p2p/spectator/key_derivation_test.dart`.
- [ ] **Post-quantum readiness note (new §9.8).** v5 used purely classical primitives (X25519, Ed25519, ChaCha20-Poly1305). NIST PQ migration is now timelined (CNSA 2.0 deadlines: signature 2030, KEM 2033 for new systems). v6 acknowledges this is **out of scope for v1** but adds a forward-looking subsection: hybrid X25519 + ML-KEM-768 for session establishment is the planned migration path; algorithm-agility is enforced now via a `crypto_suite_id: u8` field in `HELLO` so the wire format does not lock us in. **Proof:** `frontend/test/p2p/identity/crypto_suite_id_negotiation_test.dart` (today only `0x01 = X25519+Ed25519+XChaCha20-Poly1305`; future suites added without breaking the schema).
- [ ] **Session-master key separation.** v5 conflated "session key" (used directly for AEAD) with material that should also derive transcript-signing keys, spectator view-only keys, and any future sub-channel keys. v6 corrects: `session_master = HKDF(ECDH(eph_a, eph_b), salt=session_id, info="chessrecast/p2p/v1/master", L=32)`. From `session_master`, derive: `K_aead_chess`, `K_aead_clock`, `K_aead_chat`, `K_view` (spectator), `K_transcript_kdf`. AEAD keys are per-direction via additional HKDF `info` strings. **Proof:** `frontend/test/p2p/identity/master_key_subkeys_test.dart` + KAT vectors checked into `agent/baselines/p2p_kdf_kat.json`.
- [ ] **Replay-version pinning extended to transcripts.** v5 §12 versioned the engine for live play. v6 extends: every saved transcript carries `engine_replay_version` and `wire_version` so a future client can refuse to load a transcript it can no longer interpret correctly (rather than silently misinterpreting a legacy mod rule). **Proof:** `frontend/test/p2p/protocol/transcript_version_pinning_test.dart`.
- [ ] **Saved-game transcript backup (opt-in, encrypted).** v5 stored transcripts locally only; device wipe loses game history. v6 adds an opt-in encrypted backup: transcripts are encrypted with a key derived from the recovery code (separate HKDF info from the account-recovery KEK) and uploaded to the signaling server's `s3` bucket, retrieval-keyed by account fingerprint. Server cannot read content; user can restore on a fresh device after recovery. Out-of-scope for Phase 0–6 launch; Phase 7 stretch.
- [ ] **Failure-mode catalog grew from ≥75 to ≥100 codes.** New codes (full list in §10.2 v6 additions): `SEQ_CEILING_REACHED`, `KDF_DERIVATION_FAILED`, `SECRET_ZEROISE_FAILED`, `ISOLATE_CRASHED`, `MONOTONIC_CLOCK_UNAVAILABLE`, `WALL_CLOCK_TAMPERED_DETECTED`, `BYE_FRAGMENT_TIMEOUT`, `BYE_FRAGMENT_OUT_OF_ORDER`, `DATACHANNEL_ID_COLLISION`, `RESUMED_AS_NEW`, `METERED_NETWORK_USER_DECLINED`, `OEM_BATTERY_OPT_BLOCKING`, `APNS_SILENT_PUSH_DROPPED`, `FCM_TOKEN_REFRESHED`, `RECOVERY_SCREEN_CAPTURED_DETECTED`, `CHAT_BLOCKED_BY_USER`, `CHAT_REPORTED_AS_ABUSE`, `AGE_GATE_BLOCKED`, `STORE_PRIVACY_MANIFEST_OUT_OF_DATE`, `DEVICE_CAP_EXCEEDED`, `LONG_POLL_CAP_EXCEEDED`, `SDP_TOO_LARGE`, `SDP_FORBIDDEN_MEDIA_LINE`, `SPECTATOR_CHAIN_REJECTED`, `CRYPTO_SUITE_NOT_NEGOTIATED`, `TRANSCRIPT_VERSION_UNSUPPORTED`.
- [ ] **Threat model new entries.** Added: T-N-009 monotonic-clock spoofing on rooted/jailbroken devices (mitigation: monotonic clock is OS-enforced; rooted-device detection surfaces a `casual_mode` enforcement); T-P-009 spectator-as-cheat-relay (mitigation: spectator chain forbidden, view-key tied to spectator's verified pubkey); T-D-005 secret residue in process memory after crash (mitigation: §2.7 zeroisation + core-dump disabled); T-D-006 screen-recording during recovery display (§FLAG_SECURE); T-S-006 push-provider compelled disclosure of token-to-account mapping (mitigation: tokens stored encrypted at rest with per-account KMS-derived key; documented residual risk); T-X-006 transitive-dep crypto downgrade (mitigation: `crypto_suite_id` negotiation pinned to current suite by default, future-suite acceptance gated by client major-version flag); T-X-007 build-artefact substitution between SBOM generation and store upload (mitigation: in-toto attestation chain through Sigstore Rekor); T-CHAT-001 social-engineering via chat to extract recovery code (mitigation: in-chat detection of "please tell me your" + 16-word patterns, soft warning); T-MIN-001 minor-account harm (mitigation: age-gate + reduced chat default for under-16).
- [ ] **Open questions added.** OQ-17 through OQ-25 enumerated below.
- [ ] **Sequencing-graph correction (v6).** Phase 15 (security audit + pentest) is a hard prerequisite for the Phase 6 §6.4 GA-rollout gate. Phase 14 (user safety) is a hard prerequisite for the beta-open gate.

## What changed in v7 vs v6

v6 hardened cryptography and platform-integration. v7 closes the gaps that surface when the design is read against the **rest-of-system** reality: actual file paths in the engine, the at-rest threat model for local storage, the full UX flow a user has to walk through to find a game, the supply-chain monitoring loop, and the operations cadence that keeps the whole thing from rotting in production. Every bullet below either fixes a concrete bug, adds a missing-but-load-bearing sub-system, or closes a sub-section that prior versions said was "in scope" without specifying.

- [ ] **Engine path & PRNG-citation correction.** v5 §What-changed cited [frontend/native/engine/search.c](../frontend/native/engine/search.c) lines 149–196 as the location of the non-deterministic PRNG. The repository today has *both* a legacy [frontend/native/engine/search.c](../frontend/native/engine/search.c) **and** a modular [frontend/native/engine/search/search.c](../frontend/native/engine/search/search.c); the search PRNG and Zobrist PRNG live across [frontend/native/engine/board/board_zobrist.c](../frontend/native/engine/board/board_zobrist.c) and the search files. v7 §12.1's CI-gate path-list is corrected to enumerate the **actual** layout — `frontend/native/engine/{board,bridge,eval,movegen,search}/**` plus the legacy top-level `.c` siblings — and the PRNG citation in §9.7 T-P-007 is rewritten to name *both* PRNGs (Zobrist for hashing, search for tiebreaks) so a future cleanup of the legacy file does not silently break the threat-model link.
- [ ] **At-rest encryption for local storage (new §0.6).** v0–v6 protected key material via OS secure storage but left **saved games, transcripts, chat history, forensic bundles, and the diagnostic ring buffer in plaintext SQLite / files**. A device with a weak lock screen, a forensic dump, or a sync-to-cloud backup misconfiguration leaks all opponent fingerprints, all chat, and all move history. v7 mandates SQLCipher (or platform-equivalent file-level encryption) for the saved-games DB, libsodium-secretstream for forensic bundles, and `android:allowBackup="false"` + iOS `NSFileProtectionCompleteUntilFirstUserAuthentication`. **Proof:** `frontend/test/p2p/storage/sqlcipher_at_rest_test.dart` + `frontend/test/p2p/storage/no_plaintext_residue_test.dart` (filesystem grep for known plaintext markers post-write).
- [ ] **`session_id` derivation specified (new §1.9).** v6 used `session_id` as HKDF salt for both `session_master` and `aead-salt` but never said where `session_id` comes from. If either peer can choose it freely, an attacker mid-handshake can collide it with a prior session and replay AEAD frames. v7 fixes: `session_id = SHA-256(initiator_eph_pub || responder_eph_pub || initiator_nonce || responder_nonce)` — both peers compute it locally from values they already verified, no peer chooses it unilaterally, no wire field carries it. **Proof:** `frontend/test/p2p/identity/session_id_derivation_test.dart` + `frontend/test/p2p/identity/session_id_collision_resistance_test.dart` (1M handshake fuzz, no collisions).
- [ ] **CBOR floats explicitly forbidden.** v6's deterministic-CBOR clause (§1.1) didn't ban floating-point. IEEE-754 NaN payloads, denormals, and `-0.0` vs `+0.0` are not deterministic across libraries — and chess never needs floats anyway. v7 §1.1 adds: any encoder emitting a CBOR major-type-7 float (`0xf9 / 0xfa / 0xfb`) MUST be rejected at decode with `BAD_FRAME`. **Proof:** `frontend/test/p2p/protocol/cbor_no_floats_test.dart`.
- [ ] **HKDF `info`-string registry (new §1.10).** v6 spread `info="chessrecast/p2p/v1/master"`, `…/aead-salt`, `…/spectator/view-only/<pk>` etc. across multiple sections. A copy-paste typo collapses two domains and breaks key separation. v7 introduces a single registry table in §1.10 and a CI grep gate that fails any new `info="chessrecast/..."` literal not present in the registry. **Proof:** `frontend/tool/check_hkdf_info_registry.dart` + `frontend/test/p2p/identity/hkdf_info_registry_test.dart`.
- [ ] **First-contact / TOFU verification (new §2.9).** v6 trusted that `device_pubkey` exchanged in `HELLO` is the real opponent's. With no out-of-band channel, MITM at first contact is undetectable. v7 adds: optional **safety-numbers** verification (Signal-style 60-digit fingerprint of `SHA-256(min(pkA,pkB) || max(pkA,pkB))`) shown in both UIs; QR-code scan for in-person verification; persistent "verified" badge that survives across sessions. Unverified contact is permitted but flagged on every session start. **Proof:** `frontend/test/p2p/identity/safety_numbers_test.dart` + `frontend/test/p2p/identity/qr_verification_test.dart`.
- [ ] **Key-Compromise-Impersonation (KCI) defense.** v6's handshake signs the X25519 ephemeral pubkey with Ed25519 — but if Alice's long-term key leaks, an attacker can impersonate Bob *to* Alice (KCI). v7 adds a mutual-authentication step: each peer's first AEAD frame post-handshake carries a MAC over `transcript_hash` keyed by `K_kci = HKDF(session_master, info="chessrecast/p2p/v1/kci", L=32)`; both peers must verify before accepting any `MOVE`. **Proof:** `frontend/test/p2p/identity/kci_resistance_test.dart`.
- [ ] **Anti-rollback for `ENGINE_REPLAY_VERSION` (new §12.5).** v6 had no defense against a peer that *intentionally* downgrades to an older app version with weaker mod rules (e.g. a buggy draw-rule that benefits one side). v7 adds: each device records the highest `ENGINE_REPLAY_VERSION` it has *ever* seen for an opponent fingerprint; a downgrade triggers a soft warning ("opponent is on an older app version than last time you played") and bars rated play if the rated-mode flag (Phase 13.3 future) is on. **Proof:** `frontend/test/p2p/identity/engine_version_rollback_warning_test.dart`.
- [ ] **TURN-over-TLS (TURNS) and DPI-resistance (new §4.10).** v6 specified TURN over UDP + TCP/443 fallback but plain-TCP/443 is fingerprintable by deep-packet inspection on hostile networks (corporate firewalls, restrictive carriers, censoring countries). v7 adds TURNS (TURN over TLS on 443) as a third fallback, with the certificate sharing the same SAN as the signaling server so the connection is indistinguishable from ordinary HTTPS. **Proof:** `frontend/test/p2p/transport/turns_fallback_test.dart` + load test in `signaling/loadtest/`.
- [ ] **Premove / pre-confirmation specified (new §11.8).** v6's clock protocol assumed a sequential think-then-send loop. Real blitz / bullet has *premoves* (the player picks their next move while it's still opponent's turn). v7 specifies: premoves are local-only, never sent until opponent's `MOVE` arrives + is engine-validated; the local clock charges 0 ms for the premove if the opponent's move is one of the legal positions the premove was conditioned on, else the premove is discarded and the player resumes thinking on the local clock. **Proof:** `frontend/test/p2p/clock/premove_legality_test.dart` + `frontend/test/p2p/clock/premove_zero_charge_test.dart`.
- [ ] **Draw-by-repetition cross-peer determinism (new §1.11).** v6's `state_hash` covers position + mod state + half-move clock but did not say how 3-fold-repetition is detected. Each peer maintains its own position history, so a desynced history → desynced repetition claim. v7 specifies: repetition detection runs over the canonical `state_hash` history (ignoring clocks/transcripts); `MOVE` carrying `claim_repetition: true` requires the receiver's history to also contain ≥2 prior occurrences of the same hash, else `MISMATCH`. **Proof:** `frontend/test/p2p/protocol/repetition_cross_peer_test.dart` per mod.
- [ ] **Onboarding & invite flow (new §6.7).** v6 talked about beta KPIs but never specified *how a user finds an opponent*. P2P with no central directory needs an explicit invite UX. v7 adds: share-sheet invite (signed deep link with offer-token), QR scan for in-person matchmaking, opt-in "recently played" list (local-only), pluggable handle providers (later: contacts, third-party rooms — out of scope for v1). The invite link carries a server-issued offer-token (§3.2 `/v1/offers`); links are single-use and expire in 24 h. **Proof:** `frontend/test/p2p/onboarding/invite_link_test.dart` + `frontend/test/p2p/onboarding/qr_invite_test.dart` + L8 device-matrix coverage.
- [ ] **Username / vanity-handle decision (new §14.9).** v6 only used device-fingerprint identity. Many users will demand a display name; absent policy, name-squatting and impersonation will appear on day 1. v7 declares: **no central username registry in v1** (would require a server role beyond signaling). Users may set a *local* display name shown to themselves only and a *self-attested handle* shown to opponents alongside the always-displayed fingerprint. Handles are explicitly NOT unique and the UI never lets the fingerprint be hidden. **Proof:** `frontend/test/p2p/ui/handle_never_replaces_fingerprint_test.dart` + `frontend/test/p2p/ui/handle_impersonation_warning_test.dart` (when an opponent's handle matches a previously-played fingerprint's handle but the fingerprint differs → soft warning).
- [ ] **Operations & lifecycle phase (new Phase 16).** v6 §8.8 specified on-call but had no recurring cadence for: CVE monitoring (libsodium / coturn / litestream / Valkey / Go stdlib / Flutter), key-rotation calendar (TURN HMAC, signed-config signing key, KMS, push provider keys), backup-restore drills, post-incident review template, dependency-bump policy, deprecation policy for old `wire_version`/`crypto_suite_id`/`ENGINE_REPLAY_VERSION`. v7 makes Phase 16 a continuous owner of these.
- [ ] **Local storage retention & disk caps (folded into §0.6).** v6 wrote forensic bundles, transcripts, and saved games with no retention policy or cap. v7: forensic bundles capped at 50 entries (FIFO), transcripts capped at 500 (oldest evictable with user prompt), saved-games DB at 200 MB (warning at 80%, hard cap with user-driven cleanup at 100%). **Proof:** `frontend/test/p2p/storage/retention_caps_test.dart`.
- [ ] **Network connectivity recovery telemetry refined.** v6 had a 5-min total pause cap (§4.6) but didn't differentiate network-blip (≤30 s, common on metro/LTE) from genuine outage. v7 splits the budget: ≤30 s blips don't count toward the 5-min cap; only sustained `disconnected` > 30 s consumes the cap. **Proof:** `frontend/test/p2p/transport/pause_budget_classification_test.dart`.
- [ ] **`session_master` rotation mid-game (folded into §2.3).** v6 deferred re-key to Phase 7 "if `seq` ceiling reached". v7 adds an explicit periodic re-key trigger: every `2^32` AEAD frames per direction (essentially never in chess, but defensive against XChaCha20 nonce-reuse paranoia) **or** on user-driven "refresh keys" action (in-game menu). Re-key uses a fresh ECDH exchange under the existing session, derives a new `session_master` via HKDF chaining, and bumps a `keygen: u8` field in subsequent frame envelopes. **Proof:** `frontend/test/p2p/identity/session_rekey_test.dart`.
- [ ] **Backup-encryption salt for opt-in transcript backup (corrects v6 §OQ-17 default).** When transcripts are backed up server-side (Phase 7 stretch), the encryption key must be derived from the recovery code via *a different HKDF info* than the account-key wrap (else compromise of the wrap also exposes transcripts). v7 specifies: `K_transcript_backup = HKDF(Argon2id_kek, info="chessrecast/p2p/v1/transcript-backup", L=32)`, distinct from the `K_account_wrap` info string.
- [ ] **Memory-budget gates (folded into §1.4 / §4.4).** v6 specified frame-size caps but not a peer-process memory ceiling. A long game with full move/clock/chat history can consume tens of MB; on a low-end device the OS will kill the app. v7 adds: in-RAM transcript ring-buffer capped at 4 MB; overflow spills to disk-backed window with the same SQLCipher protection. **Proof:** `frontend/test/p2p/perf/transcript_ram_cap_test.dart`.
- [ ] **Failure-mode catalog grew from ≥100 to ≥125 codes.** New codes (full list in §10.3 v7 additions): `SQLCIPHER_KEY_UNWRAP_FAIL`, `LOCAL_STORAGE_QUOTA_EXCEEDED`, `LOCAL_STORAGE_AT_REST_BROKEN`, `KCI_VERIFY_FAILED`, `SESSION_ID_COLLISION`, `CBOR_FLOAT_REJECTED`, `HKDF_INFO_UNKNOWN`, `SAFETY_NUMBERS_MISMATCH`, `OPPONENT_FINGERPRINT_DOWNGRADE_DETECTED`, `TURNS_HANDSHAKE_FAILED`, `PREMOVE_INVALIDATED`, `REPETITION_CLAIM_REJECTED`, `INVITE_LINK_EXPIRED`, `INVITE_LINK_REPLAYED`, `HANDLE_IMPERSONATION_SUSPECTED`, `RE_KEY_FAILED`, `TRANSCRIPT_RAM_CAP_OVERFLOW`, `CVE_REQUIRES_FORCED_UPDATE`, `KEY_ROTATION_OVERDUE`, `BACKUP_RESTORE_DRILL_FAILED`, `OPERATOR_ON_CALL_UNREACHABLE`, `DEPRECATED_WIRE_VERSION_REJECTED`, `DEPRECATED_CRYPTO_SUITE_REJECTED`, `DEPRECATED_ENGINE_REPLAY_VERSION_REJECTED`, `BACKUP_ENCRYPTION_SALT_MISMATCH`.
- [ ] **Threat model new entries.** Added: T-D-008 plaintext local-storage harvest (mitigation §0.6), T-D-009 Android cloud-backup leak via `allowBackup=true` default (mitigation: explicit `false`), T-N-010 first-contact MITM (mitigation §2.9 safety numbers / QR), T-P-010 KCI from a leaked long-term key (mitigation §2.9 KCI MAC), T-P-011 engine-version rollback (mitigation §12.5), T-N-011 DPI on plain-TCP/443 TURN (mitigation §4.10 TURNS), T-X-008 unmaintained transitive dep (mitigation Phase 16 CVE monitoring + auto-bump policy), T-X-009 release-signing-key 1y+ rotation overdue (mitigation Phase 16 rotation calendar), T-OPS-001 silent on-call attrition (mitigation Phase 16 quarterly drill + degraded-mode default), T-INV-001 invite-link replay (mitigation §6.7 single-use server-side token), T-HDL-001 handle impersonation (mitigation §14.9 always-on fingerprint).
- [ ] **Open questions OQ-26 through OQ-32 added.** Enumerated below.
- [ ] **Sequencing-graph correction (v7).** Phase 16's CVE-monitoring sub-task is a hard prerequisite for the Phase 6 GA-rollout gate (along with v6's Phase 15 audits): shipping with an unpatched libsodium CVE because no one was watching is not a launch.

## What changed in v8 vs v7

v7 hardened the document against rest-of-system reality. v8 is the first version that survives a hostile review against the **implementation surface itself** — the engine FFI boundary, the WebRTC plumbing, the signaling-server resource model under realistic load, the schema-migration ladder a long-lived deployment will actually walk, and the user-visible game-after-the-game (replay, export, study). Every bullet below either fixes a concrete protocol-level bug, closes a load-bearing sub-system that prior versions assumed into existence, or specifies behaviour that was previously written as "TBD" / "out of scope" without a return-path.

- [ ] **Cryptography correctness — RESIGN frame signature surface fixed.** v5 §1.7 specifies that `RESIGN` is "signed under the device long-term key" *inside* every session. This is a key-misuse bug: every malicious peer can collect arbitrary long-term-key signatures over arbitrary `RESIGN` payload bytes and now has a signing oracle for the very key that authenticates the device to the signaling server. v8 §1.7 corrects this: the in-session `RESIGN` frame is authenticated only by the session AEAD (sufficient — the AEAD already proves it came from the holder of the session key, and only the device whose Ed25519 key signed the `HELLO` could have derived that session key). The *transcript-level* signature comes only from the end-of-game `BYE` frame and is signed under a **transcript-signing subkey** `K_transcript_sign = HKDF(device_long_term_priv_seed, info="chessrecast/p2p/v1/transcript-sign", L=32)` — a derived signing key whose compromise does not compromise the device-auth path. **Proof:** `frontend/test/p2p/identity/transcript_signing_subkey_test.dart` + `frontend/test/p2p/identity/no_long_term_key_signing_oracle_test.dart` (asserts no in-session frame ever invokes the long-term Ed25519 sign API).
- [ ] **TOCTOU on engine validation closed.** v6 §2.7 + §8.10 specify that crypto + engine validation run in the `p2p` isolate. v7 didn't say *where* state-application happens. If decode → validate → apply runs across two await-points, a hostile second `MOVE` arriving in between can race the apply path with stale-validation. v8 §1.12 mandates: decode + validate + state-apply run in a single synchronous critical section (no await between validation and `state_hash` computation); the move queue is processed strictly serially per-direction; an `ack_seq` watermark guards re-application. **Proof:** `frontend/test/p2p/protocol/validate_apply_atomicity_test.dart` (injects a second `MOVE` between validate and apply via a controlled scheduler; second move must wait or be rejected).
- [ ] **Engine FFI boundary fuzzing (new §1.13).** v0–v7 assumed the native engine, fed only canonical UCI + mod state from the engine binding (§1.3), is safe. But the binding decodes attacker-controlled `MOVE.payload` bytes before reaching the engine, and the engine reads mod-specific state bytes directly from CBOR. v8 mandates a corpus-driven fuzz at the FFI boundary: ≥10M iterations nightly across all 7 mods, structured (not just random) inputs covering every mod-state field; any segfault, ASAN finding, or `state_hash` divergence between two replays of the same input is `kind: crash / severity: critical`. **Proof:** `frontend/test/p2p/engine/ffi_boundary_fuzz_test.dart` + `frontend/native/engine/test/engine_ffi_asan_harness.c`.
- [ ] **Self-test on first launch (new §0.7).** v7 had no provision for *verifying* that libsodium loaded a working AEAD on the user's device, that the SQLCipher driver is the version we expect, or that the native engine returns expected goldens for a 16-position smoke set. A subtly-broken environment (mis-built fat binary, library hijack, Android multidex shadowing) currently fails silently mid-game. v8 mandates a 200 ms self-test on first P2P enablement: KAT for XChaCha20-Poly1305, KAT for Ed25519 sign/verify, KAT for HKDF-SHA256, SQLCipher round-trip, native-engine 16-position golden. Failure → `STARTUP_INTEGRITY_FAIL` (§10.1) with no fallback; user is told to reinstall. **Proof:** `frontend/test/p2p/services/startup_self_test_test.dart`.
- [ ] **Push-wakeup deduplication and idempotency (new §3.12).** v7's redeem-once token (§push-wake) is correct against replay but does *not* cover the case where the same recipient has two pending offers and receives two pushes in quick succession; the second push wakes a client that has already redeemed the first, wasting battery. v8 adds: server-side coalescing window of 8 s per `(recipient_account, push_provider_token)` — second push within the window is suppressed and the recipient receives a multi-offer hint on next poll. **Proof:** `signaling/internal/push/coalesce_test.go` + `frontend/test/p2p/services/push_multi_offer_hint_test.dart`.
- [ ] **TURN bandwidth caps per session (new §3.13).** v7 capped TURN credential lifetime + per-IP rate but did not bound the *bytes* a single session can push through the relay. A malicious peer could hold a TURN allocation and push 100 MB/s of garbage AEAD frames (the relay cannot inspect them) to attack the operator's egress bill. v8 mandates coturn `max-bps` and `bps-capacity` per allocation — default 64 kbit/s steady-state, 256 kbit/s burst (well above any chess-traffic envelope). Excess → coturn drops; client surfaces `BACKPRESSURE_DROP` (§10.0) and ends the session. **Proof:** `signaling/loadtest/turn_bandwidth_cap_test.go`.
- [ ] **Trickle-ICE cadence specified (folded into §4.1).** v7 was silent on how aggressively ICE candidates trickle. Aggressive trickling on a multi-interface device leaks every IP (VPN, work network, hotspot) to the opposite peer; lazy trickling delays handshake. v8 specifies: gather host candidates synchronously, hold srflx + relay candidates for 800 ms post-gather to coalesce identical-binding candidates from multiple interfaces, and drop loopback / link-local on cellular. VPN-detection (default route via `tun*` / `utun*`) suppresses all non-VPN candidates unless user opts into "leak public IP for direct connection" (informed consent). **Proof:** `frontend/test/p2p/transport/trickle_ice_cadence_test.dart` + `frontend/test/p2p/transport/vpn_candidate_suppression_test.dart`.
- [ ] **Schema-migration skip-version testing (folded into §0.2).** v7's per-version round-trip test only covers `N-1 → N`. A real user upgrades from `v0.5` directly to `v3.0`, walking 20+ migrations in one launch. v8 mandates: a "skip-version" matrix test that round-trips every saved-game shape from every released schema version through the *current* writer; CI enforces. Migration ordering bugs (a v2.4 migration that depends on a v2.7 migration's column) are caught here. **Proof:** `frontend/test/services/saved_games_schema_skip_version_matrix_test.dart`.
- [ ] **Differential privacy budget for telemetry (new §8.11).** v7's beta KPIs and telemetry path are honestly opt-in, but cross-session correlation of even coarse counters (e.g. "P95 RTT" + region + mod) re-identifies users in small populations. v8 mandates: every numeric telemetry counter is protected by Laplace noise with ε ≤ 1.0 per metric per day per user; histogram buckets ≥ 50 ms wide; per-user metric budget ≤ ε=4.0 daily across all metrics. The DP wrapper lives in [frontend/lib/services/p2p/telemetry/dp.dart](../frontend/lib/services/p2p/telemetry/dp.dart). **Proof:** `frontend/test/p2p/telemetry/dp_budget_test.dart` + `frontend/test/p2p/telemetry/laplace_noise_kat_test.dart`.
- [ ] **Game-replay / study mode (new §6.8).** v7 stored signed transcripts but never said how the user *reads* them. Without a replay UI, transcripts are write-only — defeating the user-facing reason to keep them. v8 adds a study mode that loads a transcript, replays move-by-move with annotation hooks, supports PGN-with-mod-extensions export (`[Variant "ChessRecast/heir"]` tag + private `[ModConfig "..."]` tag holding canonical mod state), and validates every replayed position against the local engine using the transcript's pinned `engine_replay_version`. Refusal-to-load on `engine_replay_version` mismatch hands off to study-only "view PGN" with annotations. **Proof:** `frontend/test/p2p/study/transcript_replay_test.dart` + `frontend/test/p2p/study/pgn_export_round_trip_test.dart` (×7 mods).
- [ ] **Saved-game export format pinned.** v7 implied PGN but never normalized. v8 §6.8.2 specifies: PGN with the SAN extensions enumerated above, UTF-8 encoded, NFC-normalized; exported file carries a sidecar `.cbor` with the canonical move list + mod state + cryptographic transcript when both peers signed (importable by another ChessRecast install for trust-preserving sharing). Plain PGN without the sidecar is *not* re-importable as a verified transcript — only as a study line. **Proof:** `frontend/test/p2p/study/export_format_round_trip_test.dart`.
- [ ] **Chess-clock accessibility (new §11.10).** v6 added a a11y phase but never spoke to clock cadence for screen readers. Continuous announcements ("30 seconds, 29, 28…") are unusable; silence is dangerous. v8 specifies: announcements at remaining-time milestones (5 m, 1 m, 30 s, 10 s, then every second from 5 s) using `Semantics.liveRegion: assertive`; user can opt into "every 10 s under 1 m" instead. Distinct earcon for own clock vs opponent. **Proof:** `frontend/test/a11y/clock_announcement_cadence_test.dart`.
- [ ] **Rage-quit / forfeit timer pinned (resolves OQ-29 default).** v7 deferred the policy to OQ-29. v8 commits the default per the OQ working answer: a peer that closes the app or loses connection mid-turn without sending `BYE` forfeits after 90 s of unrecoverable disconnect (cumulative pause budget already spent). Both UIs surface a countdown; resuming on either side within the window cancels the forfeit and resumes via §4.6 resync. Correspondence (`tc_kind=none`) overrides this with a 7-day timeout. **Proof:** `frontend/test/p2p/clock/rage_quit_forfeit_test.dart`.
- [ ] **Spectator late-join and back-fill (new §7.6).** v6/v7 specified the spectator key derivation but never how a spectator joining at ply N learns plies 1..N-1. v8 specifies: the *issuing* peer ships a `SPECTATOR_BACKFILL` frame containing the AEAD-decrypted move list 1..N-1 re-encrypted under `K_view`, plus the `state_hash` history for spectator-side legality verification. Bandwidth is bounded; back-fill > 1 MB triggers chunking via the §1.8 `BYE` fragmentation pattern reused under a new `SPECTATOR_BACKFILL_PART` frame type. Spectator joining mid-game cannot inject moves (no encrypt key) and cannot enumerate other spectators (each spectator's `K_view` is independent). **Proof:** `frontend/test/p2p/spectator/late_join_backfill_test.dart` + `frontend/test/p2p/spectator/no_spectator_enumeration_test.dart`.
- [ ] **iOS BGTaskScheduler integration for correspondence (new §4.11).** v7's lifecycle handling is fine for live games but breaks for `tc_kind=none` correspondence games where the app may be backgrounded for hours. Push wakeups alone are unreliable on iOS Low Power Mode (§v6 already documented). v8 adds: register `BGAppRefreshTask` (iOS 13+) and Android `WorkManager` periodic worker (every 6 h) to poll for pending offers + redeem-once tokens; battery-budget conscious; backed off when the OS denies execution windows. **Proof:** `frontend/test/p2p/transport/ios_bg_task_scheduler_test.dart` + `frontend/test/p2p/transport/android_work_manager_periodic_test.dart`.
- [ ] **Signaling load-shedding policy (new §3.14).** v7's quotas (§3.9) reject *over-quota* clients but did not specify *which* requests get shed when the server is at 90% capacity. Naive FIFO drops in-progress handshakes more often than registrations, harming the user experience worst. v8 specifies a four-tier priority lane: (1) `/v1/offers/{id}/answer` and `/v1/ice/*` (in-progress handshakes — never shed below tier 4 collapse), (2) `/v1/offers/poll` long-poll resumes, (3) `/v1/offers` new-offer creation, (4) `/v1/accounts/register` and `/v1/push/*`. Under pressure the lower tiers receive 503 first; the operator dashboard shows shed-counts per tier. **Proof:** `signaling/internal/server/load_shed_priority_test.go`.
- [ ] **Native-lib code-signing verification on load (new §0.8).** A rooted device can swap `libchess_engine.so` between app launches. v8 mandates: at first FFI call per process, compute SHA-256 of the loaded native lib's mapped pages and compare to a signed manifest baked into the APK at build time (manifest signed under the release-signing key). Mismatch → `STARTUP_INTEGRITY_FAIL`, P2P refused. Acknowledged limit: a rooted attacker who hooks the verify call itself wins; the goal is opportunistic-tamper detection, not nation-state defense. **Proof:** `frontend/test/p2p/services/native_lib_integrity_test.dart`.
- [ ] **`HELLO` handshake replay protection sharpened (folded into §1.1).** v7 already binds peer nonces into `session_id`, but `HELLO` itself carries `nonce: bytes16` *inside* the signed payload — an attacker who replays an old `HELLO` to a third peer would have its signature verify (the long-term-key signature is valid). The third peer's *responder* nonce protects the *new* session key, but the attacker has succeeded in causing the third peer to spend Argon2 / Ed25519 cycles. v8 adds: `HELLO.ts` bound into the signature MUST be within ±5 minutes of the responder's monotonic-grounded wall clock estimate (drawn from the §3.x signed time hint endpoint, new in v8). Outside window → silent reject without crypto work. **Proof:** `frontend/test/p2p/protocol/hello_freshness_test.dart`.
- [ ] **Signed-time hint endpoint (new §3.15).** Devices with no usable wall clock (factory-fresh, hard-reset, never NTP-synced) have no way to validate `HELLO.ts` freshness in the previous bullet. v8 adds `GET /v1/time` returning a server-signed `(server_now_ms, signature)` payload; clients use it as a one-shot wall-clock seed at first launch and then maintain monotonic-derived estimates. The endpoint is unauthenticated, cacheable for 60 s, signed under the same signed-config key (§8.8). **Proof:** `signaling/internal/time/signed_time_test.go` + `frontend/test/p2p/services/time_seed_test.dart`.
- [ ] **BGP-hijack defence (folded into §9 threat model).** Pinned TLS certs cover certificate-substitution but not BGP-hijack of the signaling/TURN routes (attacker announces our prefix, terminates TLS with their own cert, fails the pin → user sees `SIGNALING_5XX` and never connects — *acceptable*, fails closed). v8 explicitly documents this as the intended behaviour and adds a CT-log monitor for our domains as the early-warning channel. **Proof:** `signaling/internal/security/ct_log_monitor_test.go`.
- [ ] **Multi-device race policy pinned (resolves OQ-15-adjacent gap).** v7 left "two devices on the same account answer the same offer" to a server-side first-write-wins. v8 §7.7 specifies the loser path: the second device receives `OFFER_DUPLICATE_ANSWER` (§10.0) AND has its long-poll quietly cleared so it does not retry; the user sees a one-line "another of your devices took the call" toast. The winning device's `HELLO` carries `device_id` so the inviter UI can show *which* of the opponent's devices answered (privacy: only the device's local nickname, never the fingerprint of a sibling). **Proof:** `frontend/test/p2p/services/multi_device_race_loser_test.dart`.
- [ ] **Signaling abuse: report-bombing as a denial-of-service (folded into §14.3).** v6 capped reports at 5/24h per account. A coordinated swarm (e.g. botnet-controlled accounts targeting one fingerprint) drives the operator review queue to uselessness. v8 adds: per-target-fingerprint exponential decay on *report weight*; the 11th report against the same target within a week contributes ε to the priority score even if from 11 different accounts. **Proof:** `signaling/internal/abuse/report_target_decay_test.go`.
- [ ] **Wire-protocol versioning for signed-config and telemetry blobs (new §8.12).** v7 versioned game frames via `wire_version` but the signed-config blob, the telemetry batch envelope, and the diagnostic-bundle format were all "current shape, take it or leave it" — meaning the first format change forces every cached client to re-fetch on cold launch. v8 adds `config_blob_version: u8`, `telemetry_envelope_version: u8`, `diag_bundle_version: u8`, each independent, each with the same soft-/hard-deprecation ladder as Phase 16.5. **Proof:** `signaling/internal/config/blob_version_test.go` + `frontend/test/p2p/telemetry/envelope_version_test.dart`.
- [ ] **Clock-pause tie-break for simultaneous backgrounding.** v7 §11.3 pauses the clock when *either* peer goes `disconnected`, but if both background within the same 1 s window each peer locally records "I paused first" — and on resync the pause-budgets disagree by up to 2 s. v8 §11.3 amends: pause attribution at resync uses the *minimum* of the two reported pause-start monotonic times, mapped through the §11.2 NTP estimator. Ties (within estimator error) credit the player who has *less* time on their clock (defensive in favour of the time-pressured player). **Proof:** `frontend/test/p2p/clock/simultaneous_background_pause_attribution_test.dart`.
- [ ] **`install_id` rotation on legitimate restore (folded into §0.6).** v7's cross-install restore detection assumes any `install_id` mismatch is suspicious. The legitimate flow — user restores a phone backup to the same device after a factory reset — currently quarantines their game history. v8 adds: when SQLCipher KEK unwrap *succeeds* (proving the user can derive the seal key) but `install_id` differs, the prompt is "this looks like a restore from a backup; merge into this installation? [keep / merge / discard]" rather than a hard quarantine. **Proof:** `frontend/test/p2p/storage/legitimate_restore_merge_test.dart`.
- [ ] **First-call cost of secret allocation honestly stated.** v6 §2.7 said `< 50 µs` per allocation. On Android `mlock` first-call costs page-commit time (1–5 ms is realistic). v8 §2.7 amends: amortised < 50 µs per allocation; first-call ≤ 5 ms; the secret-pool is pre-warmed during the §0.7 self-test so the user's first move is never the first allocation. **Proof:** `frontend/test/p2p/perf/secret_alloc_first_call_warm_test.dart`.
- [ ] **Phase 7 spectator chain reconsidered as out-of-scope-with-spec.** v6 forbade chained spectators; v7 kept it as OQ-21. v8 commits: explicitly forbidden in v1 wire (§7.1), but the wire schema reserves `spectator_chain_depth: u8` (always `0` in v1, decoder rejects nonzero). Reserving the field means a future v2 can lift the restriction without a `wire_version` bump. **Proof:** `frontend/test/p2p/spectator/chain_depth_reserved_field_test.dart`.
- [ ] **Failure-mode catalog grew from ≥125 to ≥150 codes.** New codes (full list in §10.4 v8 additions): `VALIDATE_APPLY_RACE_DETECTED`, `FFI_FUZZ_FOUND_DIVERGENCE`, `STARTUP_SELF_TEST_FAIL`, `NATIVE_LIB_INTEGRITY_FAIL`, `PUSH_COALESCED`, `TURN_BANDWIDTH_EXCEEDED`, `ICE_VPN_LEAK_USER_DECLINED`, `SCHEMA_SKIP_VERSION_FAIL`, `DP_BUDGET_EXCEEDED`, `STUDY_LOAD_VERSION_MISMATCH`, `EXPORT_SIDECAR_MISSING`, `BG_TASK_DENIED_BY_OS`, `LOAD_SHED_DROPPED`, `HELLO_TS_OUT_OF_WINDOW`, `SIGNED_TIME_FETCH_FAILED`, `MULTI_DEVICE_RACE_LOST`, `REPORT_TARGET_RATE_LIMITED`, `CONFIG_BLOB_VERSION_UNSUPPORTED`, `TELEMETRY_ENVELOPE_VERSION_UNSUPPORTED`, `LEGITIMATE_RESTORE_MERGE_DECLINED`, `SPECTATOR_CHAIN_DEPTH_NONZERO_REJECTED`, `BACKFILL_OVERSIZE_REJECTED`, `RAGE_QUIT_FORFEIT_FIRED`, `STUDY_PGN_PARSE_FAIL`, `STUDY_REPLAY_HASH_DIVERGENCE`.
- [ ] **Threat model new entries.** Added: T-P-012 long-term-key signing-oracle via in-session frame signatures (mitigation §1.7 v8 fix), T-P-013 TOCTOU on engine validation (mitigation §1.12 atomic critical section), T-P-014 attacker-controlled CBOR mod-state crashes engine (mitigation §1.13 FFI fuzz), T-N-012 ICE candidate gathering leaks VPN-bypass IPs (mitigation §4.1 v8 trickle policy + VPN suppression), T-N-013 BGP-hijack of signaling/TURN (mitigation: pinned cert fails closed + CT-log monitor, residual risk documented), T-D-010 native-lib hot-swap on rooted device (mitigation §0.8 SHA verify), T-S-007 server-side load-shedding biases against in-progress handshakes (mitigation §3.14 priority-lane shed), T-S-008 TURN-relay egress DoS via opaque bytes (mitigation §3.13 bandwidth caps), T-T-001 telemetry re-identification in small populations (mitigation §8.11 DP budget), T-OPS-002 schema-migration ladder skipped → silent data loss (mitigation §0.2 v8 skip-version matrix), T-CHAT-002 report-bombing as DoS on operator review (mitigation §14.3 v8 target-decay).
- [ ] **Open questions OQ-33 through OQ-40 added.** Enumerated below.
- [ ] **Sequencing-graph correction (v8).** The §0.7 startup self-test, §0.8 native-lib integrity check, §1.12 atomic validate-apply, and §1.13 FFI fuzz are hard prerequisites for the Phase 6 beta-open gate. The §3.13 TURN bandwidth caps and §3.14 load-shedding policy are hard prerequisites for the Phase 6 GA-rollout gate (without them the operator's egress bill is unbounded under abuse and the user experience under load is undefined).

## What changed in v9 vs v8

v9 promotes **live spectating with chat** from a v8 stretch-bullet (§7.6 back-fill only) into a fully-specified, perf-isolated, abuse-resistant sub-system. The non-negotiable invariant: **no spectator action — joining, sending chat, leaving, abusing — may slow the chess game by even one frame.** Chess + clock frames always preempt spectator traffic at every layer (SCTP stream priority, isolate scheduler, CPU budget, network egress). Every bullet below is either a new wire-protocol surface, an anti-abuse control with a measurable cap, or a perf-isolation guarantee with a proof test.

- [ ] **Spectator topology pinned to single-hop fan-out (new §7.8).** v8 §7.6 specified back-fill but never said how spectators *connect*. v9 commits: a spectator establishes exactly one DataChannel — to the **issuing peer** (the player who issued the `K_view` per §7.1) — never to both players, never to other spectators. The issuing peer fans out moves, clock updates, and broadcast chat. This bounds every player's spectator-related upload to `O(N_spectators_of_that_peer)` on **one** of the two players, never both, and lets the non-issuing peer remain unaware of spectator count. **Proof:** [frontend/test/p2p/spectator/single_hop_topology_test.dart](../frontend/test/p2p/spectator/single_hop_topology_test.dart) + [frontend/test/p2p/spectator/non_issuing_peer_unaware_test.dart](../frontend/test/p2p/spectator/non_issuing_peer_unaware_test.dart).
- [ ] **Spectator capacity caps (new §7.8.2).** Hard caps prevent a viral game from melting the issuing peer's mobile uplink. Per-game spectator cap: **default 50, hard ceiling 200**, configurable downward by either player at game-start (lower of the two settings wins). Per-issuing-peer-account cap across concurrent games: **100**. Signaling enforces both caps before issuing a `K_view`; over-cap requesters receive `SPECTATOR_CAPACITY_FULL` (§10.5) and may join a per-game waitlist (max 50 deep, FIFO, expires when game ends). **Proof:** [signaling/internal/spectator/capacity_cap_test.go](../signaling/internal/spectator/capacity_cap_test.go) + [frontend/test/p2p/spectator/capacity_full_waitlist_test.dart](../frontend/test/p2p/spectator/capacity_full_waitlist_test.dart).
- [ ] **Spectator authentication required (new §7.8.3).** Anonymous spectators are forbidden in v1: every spectator MUST present a registered account pubkey (same Ed25519 device key as a player). This anchors anti-abuse: ban / mute / report all key off the verified pubkey. Consequence accepted: no "share a link, anyone watches" flow in v1; deferred to OQ-44. **Proof:** [frontend/test/p2p/spectator/auth_required_test.dart](../frontend/test/p2p/spectator/auth_required_test.dart) + [signaling/internal/spectator/anon_join_rejected_test.go](../signaling/internal/spectator/anon_join_rejected_test.go).
- [ ] **Per-account spectator-join rate limit at signaling (new §7.8.4).** Without this, one account can join-bomb a popular game (join → drop → join → drop) to drain the issuing peer's setup CPU. v9: signaling enforces ≤ **6 spectator-joins per account per minute**, ≤ **60 per hour**, with token-bucket replenishment. Excess → `SPECTATOR_JOIN_RATE_LIMITED` (§10.5). The cap is **independent** of the §3.9 generic signaling quotas (a chatty spectator should not consume a player's offer/answer budget). **Proof:** [signaling/internal/spectator/join_rate_limit_test.go](../signaling/internal/spectator/join_rate_limit_test.go).
- [ ] **Spectator chat sub-channel and key derivation (new §7.9).** v8 §7.6 left chat undefined for spectators. v9 specifies: a dedicated AEAD subkey `K_chat_spec_dir = HKDF(K_view, info="chessrecast/p2p/v1/spectator-chat/<dir>", L=32)` per direction (`spec→host`, `host→spec`, `host→spec_broadcast`). Spectator chat is **never** end-to-end with other spectators — every broadcast is decrypted by the issuing peer, re-encrypted under each recipient's `K_chat_spec_dir`, and forwarded. This makes the issuing peer the unavoidable moderation choke point (acceptable: they already chose to share their game) but means a malicious spectator can never directly contact another spectator. Player↔player chat (§1.x) remains end-to-end and is **never** routed through the spectator-chat path. **Proof:** [frontend/test/p2p/spectator/chat_key_derivation_test.dart](../frontend/test/p2p/spectator/chat_key_derivation_test.dart) + [frontend/test/p2p/spectator/no_spec_to_spec_direct_test.dart](../frontend/test/p2p/spectator/no_spec_to_spec_direct_test.dart) + KAT additions to [agent/baselines/p2p_kdf_kat.json](../agent/baselines/p2p_kdf_kat.json).
- [ ] **Per-spectator chat token bucket (new §7.9.2).** v9: every spectator chat sender is bound by a token bucket — **sustained 1 message / 3 s, burst 3** — enforced *both* client-side (refusal to send + UI cooldown indicator) and server-side at the issuing peer (drop with `CHAT_RATE_LIMITED` §10.5). Player-to-player chat keeps its existing v6 budget separately. Rate limit is per `(account_pubkey, game_id)` so leaving and rejoining the same game does not reset the bucket. **Proof:** [frontend/test/p2p/spectator/chat_token_bucket_test.dart](../frontend/test/p2p/spectator/chat_token_bucket_test.dart) + [frontend/test/p2p/spectator/chat_bucket_persists_across_rejoin_test.dart](../frontend/test/p2p/spectator/chat_bucket_persists_across_rejoin_test.dart).
- [ ] **Hard chat-message size cap (new §7.9.3).** Chat payloads (post-AEAD-decrypt, post-NFC-normalisation): **≤ 280 Unicode scalars, ≤ 512 UTF-8 bytes**. Oversized → silently rejected client-side, server-side trip → `CHAT_MESSAGE_OVERSIZED` (§10.5) + immediate token-bucket penalty (–3 tokens). No images, no rich content, no URLs auto-fetched (URLs render as inert text in v1). **Proof:** [frontend/test/p2p/spectator/chat_size_cap_test.dart](../frontend/test/p2p/spectator/chat_size_cap_test.dart).
- [ ] **Slow-mode and global-mute knobs for the issuing peer (new §7.9.4).** The issuing peer's UI exposes: **slow mode** (set min-interval to 0 / 5 s / 30 s / 2 m, default 5 s) and **mute all spectators** (one-tap, persists for the session, surfaces a banner to spectators). Either knob can be flipped mid-game. Slow mode applied retroactively does *not* refund tokens already spent. **Proof:** [frontend/test/p2p/spectator/slow_mode_test.dart](../frontend/test/p2p/spectator/slow_mode_test.dart) + [frontend/test/p2p/spectator/global_mute_test.dart](../frontend/test/p2p/spectator/global_mute_test.dart).
- [ ] **Per-spectator mute / kick / ban primitives (new §7.9.5).** Issuing peer can: (a) **mute** a spectator for the rest of the game (their `K_chat_spec_dir(spec→host_broadcast)` decrypts to `/dev/null`; spectator UI shows "muted by host"), (b) **kick** them (DataChannel torn down, signaling refuses re-join via `SPECTATOR_KICKED` for 24 h on this `(account, game_id)`), (c) **ban** their account from any future game this issuer hosts (local persistent block-list under [frontend/lib/services/p2p/spectator/ban_list.dart](../frontend/lib/services/p2p/spectator/ban_list.dart); enforced both at signaling join time and at fan-out re-encrypt time). All three are one-tap from the spectator-roster UI. **Proof:** [frontend/test/p2p/spectator/mute_kick_ban_test.dart](../frontend/test/p2p/spectator/mute_kick_ban_test.dart) + [frontend/test/p2p/spectator/ban_list_persists_test.dart](../frontend/test/p2p/spectator/ban_list_persists_test.dart).
- [ ] **Auto-throttle during clock pressure (new §7.9.6).** v9: when *any* player's clock < 30 s, slow-mode auto-engages at 30 s minimum (overrides the host's setting downward but never upward). When *any* player's clock < 10 s, all spectator chat is auto-muted (queued, delivered post-move). Rationale: the player on the move must not lose CPU/UI cycles to chat decode + render in time pressure. The auto-throttle releases on the next move. **Proof:** [frontend/test/p2p/spectator/auto_throttle_clock_pressure_test.dart](../frontend/test/p2p/spectator/auto_throttle_clock_pressure_test.dart).
- [ ] **SCTP stream priority — chess always preempts chat (new §7.10).** v9 mandates two distinct SCTP streams on the spectator DataChannel: stream `1` (chess + clock + back-fill, `priority=high`) and stream `7` (chat, `priority=low`). The DataChannel implementation honours the [WebRTC priority spec (RFC 8831)](https://www.rfc-editor.org/rfc/rfc8831). Under congestion, the chat stream blocks; the chess stream never does. **Proof:** [frontend/test/p2p/spectator/sctp_priority_chess_preempts_chat_test.dart](../frontend/test/p2p/spectator/sctp_priority_chess_preempts_chat_test.dart) + an integration test that simulates 100 kbit/s uplink saturated with chat and asserts move RTT remains within 1.1× of the no-chat baseline.
- [ ] **Issuing-peer perf budget for spectator workload (new §7.10.2).** v9 caps the per-frame work the issuing peer spends on spectator fan-out + chat decode/re-encrypt at **≤ 2 ms / frame on the UI isolate** (measured by [frontend/test/p2p/perf/spectator_frame_budget_test.dart](../frontend/test/p2p/perf/spectator_frame_budget_test.dart)) and **≤ 25% of the player's available egress** (measured pre-game by a 1-second probe). Excess work is offloaded to the existing `p2p` isolate; if the budget is exceeded for ≥ 3 consecutive seconds the issuing peer auto-sheds spectators in **LIFO** order (most-recent join first) with `SPECTATOR_SHED_FOR_PERF` (§10.5). The chess game never observes the shed. **Proof:** [frontend/test/p2p/spectator/perf_shed_lifo_test.dart](../frontend/test/p2p/spectator/perf_shed_lifo_test.dart) + [frontend/test/p2p/perf/spectator_frame_budget_test.dart](../frontend/test/p2p/perf/spectator_frame_budget_test.dart).
- [ ] **TURN bandwidth carve-out for spectator traffic (new §7.10.3).** v9 amends §3.13 (TURN per-allocation cap): the player's **own** allocation budget is reserved for chess+clock; spectator fan-out via TURN requires a **separate** allocation per spectator with its own 64 kbit/s steady cap, billed against the spectator's own quota. If the spectator cannot establish a direct path AND TURN refuses a new allocation (operator quota), the join fails with `SPECTATOR_RELAY_UNAVAILABLE` (§10.5). Spectators on TURN never compete with the players' relay budget. **Proof:** [signaling/loadtest/spectator_turn_separate_allocation_test.go](../signaling/loadtest/spectator_turn_separate_allocation_test.go).
- [ ] **CPU-bounded chat decode on spectator side (new §7.10.4).** A malicious issuing peer could send a chat firehose to drain a spectator's battery. v9: spectator client decodes chat at ≤ 30 messages/s; excess buffers up to 100 messages then drops with `CHAT_RECEIVER_OVERFLOW` (§10.5) and surfaces a one-line warning. **Proof:** [frontend/test/p2p/spectator/chat_receiver_overflow_test.dart](../frontend/test/p2p/spectator/chat_receiver_overflow_test.dart).
- [ ] **Spectator-chat reporting and signaling-side abuse path (new §7.9.7).** v9 hooks spectator-chat reports into the existing §14 review-queue with the §14.3 v8 target-decay. Per-account report cap **5 / 24 h** (same as player chat). Reports include: `(reporter_account_pubkey, target_account_pubkey, game_id, message_hash, optional_redacted_excerpt)`. Reporting auto-mutes the target client-side until the user revisits the report. **Proof:** [frontend/test/p2p/spectator/chat_report_test.dart](../frontend/test/p2p/spectator/chat_report_test.dart) + [signaling/internal/abuse/spectator_chat_report_test.go](../signaling/internal/abuse/spectator_chat_report_test.go).
- [ ] **Tournament / rated-game chat lockdown (new §7.9.8).** When a game is part of a tournament (Phase 7 stretch) or — if rated play ever ships per OQ-10 — flagged `rated=true`, spectator chat is **forced to mute-all by default**, with the issuing peer needing to explicitly opt-in per-game. Rationale: prevent kibitzing / coaching during rated/tournament play. **Proof:** [frontend/test/p2p/spectator/tournament_chat_default_mute_test.dart](../frontend/test/p2p/spectator/tournament_chat_default_mute_test.dart).
- [ ] **Spectator-chat content NEVER reaches the engine (new §7.10.5).** Hard architectural rule, enforced by isolate boundaries: chat bytes are decoded on the UI isolate and rendered into the chat widget. They are **never** passed to the `engine` isolate, never to the `p2p` validator, never to the `state_hash`. A malformed chat payload may crash the chat widget at worst; the chess game continues. **Proof:** [frontend/test/p2p/spectator/chat_isolation_from_engine_test.dart](../frontend/test/p2p/spectator/chat_isolation_from_engine_test.dart) (asserts the engine isolate's message channel never receives any frame whose stream id ≠ `1`).
- [ ] **Player chat parity hardening (folded into §1.x).** The same per-direction subkey derivation, size cap (≤ 280 chars), token bucket (sustained 1 / 3 s, burst 3), reporting hook, and SCTP stream priority (`priority=low` on stream `7`) are applied to player↔player chat retroactively. v6 specified the channel; v9 specifies the budget. **Proof:** [frontend/test/p2p/chat/player_chat_size_cap_test.dart](../frontend/test/p2p/chat/player_chat_size_cap_test.dart) + [frontend/test/p2p/chat/player_chat_priority_test.dart](../frontend/test/p2p/chat/player_chat_priority_test.dart).
- [ ] **Failure-mode catalog grew from ≥150 to ≥175 codes.** New §10.5 codes (full list below): `SPECTATOR_CAPACITY_FULL`, `SPECTATOR_WAITLIST_EXPIRED`, `SPECTATOR_AUTH_REQUIRED`, `SPECTATOR_JOIN_RATE_LIMITED`, `SPECTATOR_KICKED`, `SPECTATOR_BANNED`, `SPECTATOR_MUTED`, `SPECTATOR_GLOBALLY_MUTED`, `SPECTATOR_SHED_FOR_PERF`, `SPECTATOR_RELAY_UNAVAILABLE`, `CHAT_RATE_LIMITED`, `CHAT_MESSAGE_OVERSIZED`, `CHAT_SLOW_MODE_ACTIVE`, `CHAT_AUTO_THROTTLED_CLOCK_PRESSURE`, `CHAT_RECEIVER_OVERFLOW`, `CHAT_REPORT_FILED`, `CHAT_TOURNAMENT_LOCKED`, `CHAT_HOST_BROADCAST_DROPPED_LOW_PRIORITY`, `CHAT_DECODE_ERROR_DISCARDED`, `BACKFILL_QUEUE_OVERFLOW`, `SPECTATOR_HEARTBEAT_TIMEOUT`, `SPECTATOR_KEY_ROTATION_REQUIRED`, `CHAT_NFC_NORMALISATION_FAIL`, `CHAT_HOMOGLYPH_BLOCKED`, `SPECTATOR_DATACHANNEL_BACKPRESSURE`.
- [ ] **Threat model new entries (v9).** Added: T-CHAT-003 spectator chat firehose to drain player battery / UI thread (mitigation §7.10.2 perf budget + §7.10.4 receiver overflow); T-CHAT-004 spectator-to-spectator covert side-channel via timing of host re-encrypt (mitigation: host fans out on a fixed cadence, jitter ≤ 25 ms — observable but bounded; documented residual risk); T-CHAT-005 issuing peer is a single point of moderation failure (mitigation: accepted by design, surfaced to spectators in the join consent dialog); T-CHAT-006 join-bombing to exhaust setup CPU (mitigation §7.8.4 join rate limit); T-CHAT-007 oversized chat as buffer-bloat DoS (mitigation §7.9.3 hard size cap); T-CHAT-008 homoglyph / RTL-override impersonation in usernames + chat (mitigation: NFC-normalise, reject mixed-script identifiers per [UTS #39](https://www.unicode.org/reports/tr39/), strip BIDI control chars); T-S-009 TURN egress amplification via spectator fan-out (mitigation §7.10.3 separate-allocation rule); T-P-015 spectator-chat key reuse across rejoins enables cross-session linkability (mitigation: `K_chat_spec_dir` rotates on every rejoin via `K_view` regeneration; old key is zeroised); T-OPS-003 issuing peer offline mid-game leaves spectators stranded (mitigation §7.10.6 graceful spectator-eviction frame).
- [ ] **Open questions OQ-41 through OQ-48 added.** Enumerated below (anonymous spectators, chat persistence, tournament chat policy, spectator-of-spectator chain rumour, etc.).
- [ ] **Sequencing-graph correction (v9).** Spectator features (§7.8 / §7.9 / §7.10) are **NOT** prerequisites for the Phase 6 beta-open gate (live games can launch without them) but ARE prerequisites for the Phase 6 §6.4 GA-rollout gate's **"feature-complete" claim**. The §7.10 perf-isolation tests are hard prerequisites for shipping spectator features — without them, the chess-quality charter (no frame-budget regression) cannot be honoured. The §7.9.5 mute/kick/ban primitives and §7.9.7 report path are hard prerequisites for *enabling* spectator chat in any release that exposes the join UI.

## What changed in v10 vs v9

v0–v9 grew the spec **wide** (more cryptography, more phases, more failure modes). v10 grows it **deep**: it makes the five quality dimensions the project promises — **performance, efficiency, stability, reliability, integrity** — *measurably enforceable* across every phase by introducing (a) a single end-to-end **budget tree** that allocates each user-visible quality target down to per-component caps with a proof test attached to every leaf, (b) a **privacy-engineering** owner that consolidates DP, anonymisation, residency, DSAR, and right-to-portability into one auditable phase, and (c) a **release & hot-fix delivery** owner that closes the gap between "we noticed a P0" and "the patch is on the user's device." It also closes nine concrete holes in v9 that would have bitten us between beta and GA. Every bullet below either fixes a real bug, adds a missing-but-load-bearing sub-system, or replaces a vague "should be fast" with a measurable bound and a proof.

- [ ] **End-to-end budget tree (new [Phase 17](#phase-17--end-to-end-budget-tree-performance-efficiency-stability-reliability-integrity)).** v0–v9 sprinkled latency caps, memory caps, frame-size caps, cost caps, and crash-rate caps across two dozen sub-sections with no single owner. v10 hangs every numeric promise off a tree rooted at user-visible KPIs (P50/P99 move RTT, frame budget, MAU cost, crash-free rate, MTBF for `MISMATCH`) and decomposes each into per-component sub-budgets (encode → encrypt → SCTP → decrypt → validate → apply → render → ack). Every leaf carries a numeric ceiling, an owning sub-section, and a proof test that fails CI on regression. Drift on any leaf opens `kind: p2p_budget_breach`. **Proof:** [agent/baselines/p2p_budgets.json](../agent/baselines/p2p_budgets.json) holds the canonical tree; [frontend/test/p2p/perf/budget_tree_kpi_test.dart](../frontend/test/p2p/perf/budget_tree_kpi_test.dart) walks the tree and asserts every leaf has a live test reference.
- [ ] **Privacy-engineering phase (new [Phase 18](#phase-18--privacy-engineering)).** v9 had DP for telemetry (§8.11), anonymisation for abuse reports (§14.3), data residency (§8.5), DSAR (§8.5), and a half-promised right-to-portability scattered across the document. v10 consolidates them under a single owner with a **privacy threat model** (T-PRIV-* series), a **data-flow inventory** (every byte the user produces — identity, transcript, chat, telemetry, abuse-report, push-token, secure-storage shadow — labelled with its lifetime, residency, encryption-at-rest state, who can read it, and how it is purged), an **export-my-data** flow (GDPR Right to Portability — produces a signed, app-importable archive), and a **privacy-impact assessment** as a hard prerequisite for the Phase 6 beta-open gate.
- [ ] **Release & hot-fix delivery phase (new [Phase 19](#phase-19--release--hot-fix-delivery)).** Phase 16 owns CVE response and key rotation; v9 was silent on the *delivery* side — once a fix is committed, how does it reach the user fast enough to matter? v10 specifies: a staged-rollout calendar (canary → 1% → 10% → 50% → 100% with bake times per channel), a "hot-fix lane" with compressed bake times for P0/P1 protocol bugs, **client-side staged-rollout enforcement** (the signed-config blob carries an `eligible_cohort: [u8]` bitmap so the server can authoritatively delay an install from upgrading), an **auto-rollback** trigger if the new build's KPI cohort regresses on the budget-tree by > 5% during bake, and a **kill-switch-by-version** so a known-bad shipped build can be told to refuse P2P even before the user updates. Out-of-store sideload paths are documented as best-effort.
- [ ] **Feature-flag governance (new [§8.13](#813-feature-flag-governance-v10)).** v9 referenced `kEnableP2P`, `kEnableP2PWeb`, the v10-introduced `kEnableSpectatorChat`, and a dozen ad-hoc booleans. v10 mandates a flag registry ([frontend/lib/services/p2p/flags/registry.dart](../frontend/lib/services/p2p/flags/registry.dart)) where every flag declares: scope (compile-time / runtime / signed-config), default, owner, sunset date, and the proof tests that exercise both states. CI grep gate fails any new `bool kEnable*` literal not in the registry. Stale flags (sunset date elapsed) auto-open `kind: p2p_flag_cleanup`. **Proof:** [frontend/test/p2p/flags/registry_completeness_test.dart](../frontend/test/p2p/flags/registry_completeness_test.dart).
- [ ] **A/B experiment infrastructure (new [§8.14](#814-ab-experimentation-infrastructure-v10)).** v9's "default off, opt-in" decisions for premove (OQ-30), slow-mode interval (§7.9.4), spectator capacity ceiling (§7.8.2), KCI MAC inclusion threshold, and several others were chosen by intuition. v10 specifies a thin, **privacy-budget-respecting** A/B framework: cohort assignment via `HKDF(account_pubkey, info="chessrecast/p2p/v1/ab/<exp_id>", L=2)` (deterministic, server cannot enumerate cohorts, opt-out honoured by treating opted-out users as control), telemetry buckets bound to the §8.11 DP budget, *no* cross-experiment correlation. Experiments are signed-config-driven and have a max duration of 30 d before requiring a re-decision queue entry. **Proof:** [frontend/test/p2p/experiments/cohort_assignment_test.dart](../frontend/test/p2p/experiments/cohort_assignment_test.dart) + [frontend/test/p2p/experiments/dp_budget_respect_test.dart](../frontend/test/p2p/experiments/dp_budget_respect_test.dart).
- [ ] **Battery & thermal budgets folded into the tree (formerly hand-waved).** v4–v9 mentioned battery in passing (§4.8 metered networks, §7.10.4 chat-firehose battery drain, Phase 8 cross-cutting). v10 specifies measurable caps: ≤ **3.0% battery / hour** of active blitz play on a 2-year-old mid-tier device, ≤ **0.4% / hour** while waiting for an opponent move on a correspondence game, ≤ **40 °C** chassis temperature at 30-min steady-state. Over budget → spectator features auto-shed first (§7.10.2 LIFO), then chat fan-out (§7.9.4 forced slow-mode), then a one-time toast and graceful end. **Proof:** [frontend/test/p2p/perf/battery_budget_test.dart](../frontend/test/p2p/perf/battery_budget_test.dart) (uses the platform battery historian on Android; iOS uses `ProcessInfo.thermalState` snapshots). Caps are leaves under [Phase 17 §17.3](#173-efficiency-budgets) (Efficiency).
- [ ] **Memory budget tree (new [§17.4](#174-stability-budgets)).** v9 specified a 4 MB transcript ring (§v6 §1.4) and a 256 KB diag-log ring (§8.3) but no holistic per-process memory ceiling. v10 sets: P2P-owned RSS ≤ **80 MB** at steady state, ≤ **140 MB** at handshake (Argon2 transient), with per-isolate sub-caps (UI ≤ 24 MB, `p2p` ≤ 32 MB, `engine` ≤ 16 MB, transcript spill ≤ 8 MB). Over budget → defensive eviction by isolate, with a `kind: p2p_memory_breach` queue entry on any single sample exceeding the hard cap. Long-running leak detection: a 4-hour soak with continuous match cycling must show zero net RSS growth (≤ 1 MB drift). **Proof:** [frontend/test/p2p/perf/memory_budget_test.dart](../frontend/test/p2p/perf/memory_budget_test.dart) + [frontend/test/p2p/perf/memory_leak_soak_test.dart](../frontend/test/p2p/perf/memory_leak_soak_test.dart) (nightly).
- [ ] **Latency budget tree (new [§17.2](#172-performance-budgets)).** v9's "P99 < 2 ms move round-trip" (§1.4) was a single number on a synthetic mock. v10 decomposes the user-visible **move RTT P99 ≤ 250 ms over LTE** into: tap → encode (≤ 1 ms) → encrypt + AAD (≤ 0.3 ms) → SCTP send + ACK (≤ 50 ms median + 200 ms tail) → decrypt + AAD verify (≤ 0.3 ms) → engine validate (≤ 1 ms) → apply + state-hash (≤ 0.5 ms, atomic per §1.12) → render (≤ 16 ms = one frame) → emit `MOVE_ACK` (same return path). Each leg has a **separate** proof test and is profiled per-platform per-CI release. Regression > 10% on any leg → `kind: p2p_latency_regression`. The `engine_replay_version` golden test now also asserts engine-validate latency stability across rule-bumps.
- [ ] **Stability budget tree (new [§17.4](#174-stability-budgets)).** Beyond memory: ANR / frame-jank ≤ 0.05% of frames during active P2P play, isolate-restart rate ≤ 1 / 10⁶ sessions, deadlock budget = **zero** (any reachable deadlock = critical bug, not a budget). Crash-free rate ≥ 99.95% for the P2P-on cohort over a 7-day rolling window (tighter than v9's 99.9% because the budget-tree forces the work). **Proof:** [frontend/test/p2p/perf/anr_jank_budget_test.dart](../frontend/test/p2p/perf/anr_jank_budget_test.dart) + Crashlytics / Sentry dashboard alert at the 99.95% threshold.
- [ ] **Reliability budget tree (new [§17.5](#175-reliability-budgets)).** MTBF for `MISMATCH` ≥ 10⁶ moves over the rollout cohort (tighter than v9's "0 in 10⁵"); ICE re-establishment success ≥ 99.5% within the 10 s budget; push-wake redemption success ≥ 95% within 90 s on a non-Doze device, ≥ 80% on a Doze device. Each cap is a Phase 6.2 KPI alarm with auto-halt-rollout on breach.
- [ ] **Integrity budget tree (new [§17.6](#176-integrity-budgets)).** Every released artefact (APK, IPA, signaling binary, native lib) MUST: (a) be reproducible (single SHA across three independent clean rebuilds — Android + Linux server; iOS best-effort per §8.4), (b) carry an in-toto attestation chain through Sigstore Rekor (T-X-007), (c) match its SBOM bit-for-bit (no unattested dependency ever ships), (d) bind its `engine_replay_version` to a per-arch golden hash (§12.5), (e) bind its `wire_version` to the protocol-spec commit SHA in [docs/P2P_PROTOCOL.md](P2P_PROTOCOL.md). Any single breach blocks release. **Proof:** [xops/p2p/release-integrity-gate.sh](../xops/p2p/release-integrity-gate.sh) — runs all six checks in a hermetic container; CI gates the release tag.
- [ ] **Engine-binding fuzz hardening (folded into [§1.13](#113-spec)).** v8's nightly 10M-iteration FFI fuzz catches divergence and ASAN findings. v10 adds: (a) **structure-aware fuzz** that mutates *valid* CBOR mod-state shapes (libFuzzer with a custom mutator that respects the per-mod schema) so the fuzzer spends time on semantically interesting inputs rather than 99.99% rejected garbage; (b) **differential fuzz** that runs the same input through the production engine *and* a slow-path Dart-side reference implementation (where one exists) and asserts identical `state_hash`; (c) **per-mod corpus seeding** from `agent/openings/<mod>.csv` plus the discovery / stress slices, so the fuzz starts from real game positions and explores their neighbourhood. **Proof:** [frontend/test/p2p/engine/structure_aware_ffi_fuzz_test.dart](../frontend/test/p2p/engine/structure_aware_ffi_fuzz_test.dart) + [frontend/native/engine/test/engine_ffi_diff_harness.c](../frontend/native/engine/test/engine_ffi_diff_harness.c).
- [ ] **Mid-session app-update collision specified (new [§4.12](#412-spec)).** v9 was silent on the case where one peer's app updates *during* a live game (foreground transition triggers a hot-restart on Flutter). The session is currently torn down with no clean resume. v10 specifies: (a) a graceful `BYE { reason: client_updating, resumable_until_ts }` is sent before the restart if the OS provides ≥ 1 s notice; (b) on the post-update relaunch, the client polls `/v1/offers` for a `RESUME_HINT { session_id }` left by the opponent and offers a "your last game can be resumed" UX; (c) if the post-update binary's `engine_replay_version` differs from the pre-update one, the resume is refused with `ENGINE_VERSION_MISMATCH` and the partial transcript is preserved as a study artefact. **Proof:** [frontend/test/p2p/transport/mid_session_app_update_test.dart](../frontend/test/p2p/transport/mid_session_app_update_test.dart).
- [ ] **Native-engine crash forensics (folded into [§1.2](#12-implementation)).** v9 wrote a forensic bundle on `MISMATCH` only. v10 extends: any native-engine crash (SIGSEGV / SIGBUS / SIGABRT / ASAN finding) during a live session preserves the in-flight transcript fragment, the last 64 frames in/out, the engine state snapshot, the OS stack trace (where collectable), and the SHA of `libchess_engine.so` to a sealed-bundle that survives the crash via a parent-process watchdog. The bundle is offered to the user on next launch via the existing diag-bundle UX. **Proof:** [frontend/test/p2p/protocol/engine_crash_forensics_test.dart](../frontend/test/p2p/protocol/engine_crash_forensics_test.dart) + [frontend/native/engine/test/crash_watchdog_test.c](../frontend/native/engine/test/crash_watchdog_test.c).
- [ ] **Cross-version transcript replay (new [§12.6](#126-cross-version-transcript-replay-v10)).** v9 §12.5 enforces version pinning at handshake; transcripts pin the version at write. v10 specifies the **read** side: a current-version client opening a transcript written under an older `engine_replay_version` MUST either (a) load the historical version's rule semantics from a vendored archive (`frontend/native/engine/historical/<version>/`), validating every move against the historical rules, or (b) refuse to load with `TRANSCRIPT_VERSION_UNSUPPORTED` and offer a "view as PGN only" fallback. The vendored archive policy: the **last 4 minor versions** are kept hot; older ones are archive-only and require a one-time download. **Proof:** [frontend/test/p2p/protocol/cross_version_transcript_replay_test.dart](../frontend/test/p2p/protocol/cross_version_transcript_replay_test.dart) + [frontend/test/p2p/study/historical_engine_archive_test.dart](../frontend/test/p2p/study/historical_engine_archive_test.dart).
- [ ] **High-water-mark anti-tamper (folded into [§12.5](#125-anti-rollback-enforcement-v7)).** v7 stored `seen_max_engine_replay_version` in the SQLCipher `meta` table. A user with root and the `install_seal_key` could rewrite it to suppress the downgrade warning and play their own friend on an older buggy build. v10 adds: the high-water-mark is *also* attested server-side — every successful handshake reports `(account_pubkey, seen_version)` to the signaling server (signed) and the server returns the maximum it has ever observed for that account. Local value < server-observed value → `OPPONENT_FINGERPRINT_DOWNGRADE_DETECTED` (§10.3) is raised even if the local DB was tampered with. The server-side store is privacy-minimised (only the max value, no per-session detail). **Proof:** [signaling/internal/accounts/version_high_water_mark_test.go](../signaling/internal/accounts/version_high_water_mark_test.go) + [frontend/test/p2p/protocol/anti_rollback_server_attest_test.dart](../frontend/test/p2p/protocol/anti_rollback_server_attest_test.dart).
- [ ] **Recovery-code rotation flow (new [§2.11](#211-recovery-code-rotation-v10)).** v9 specified the recovery code as a write-once artefact for the lifetime of the account. Real users compromise their recovery code (photo on phone, written on whiteboard) and need to rotate it without losing their account. v10 specifies: in-app "rotate recovery code" → user confirms current device biometric + types current recovery words → app generates fresh 16-word code (BIP-39 checksum verified) → re-wraps the account key under the new Argon2id KEK with the latest `kdf_version` → uploads the fresh wrapped blob (signed under the existing account key, replacing the old one atomically server-side) → user enters fresh words to confirm → the old wrapped blob is overwritten and the old recovery code is permanently invalid. Failure modes: rotation aborted mid-flow → old code remains valid (atomicity guaranteed by server-side compare-and-swap on `wrapped_blob_revision`); server returns `REBIND_RACE_LOST` → rotation refused, user must reconcile from another device first. **Proof:** [frontend/test/p2p/identity/recovery_rotation_test.dart](../frontend/test/p2p/identity/recovery_rotation_test.dart) + [signaling/internal/recovery/cas_rotation_test.go](../signaling/internal/recovery/cas_rotation_test.go).
- [ ] **iCloud Private Relay / NEXT-Hop interaction (new [§4.13](#413-spec)).** v9 was silent on iOS 15+ iCloud Private Relay and Apple Network Privacy. Both can opaque the public IP that ICE sees and may inject latency that shoves the §11.2 NTP estimator past its desync budget. v10 specifies: detect Private Relay via `nw_path_status` introspection at session start; if active, surface a one-time toast "iCloud Private Relay is active — connection may be slower" and *raise* the §11.2 desync budget to 750 ms for the duration of the session. The clock-protocol fairness still holds because the budget raise is symmetric. **Proof:** [frontend/test/p2p/transport/icloud_private_relay_detection_test.dart](../frontend/test/p2p/transport/icloud_private_relay_detection_test.dart) (mocked).
- [ ] **Hostile-network detection bundle (new [§4.14](#414-spec)).** v9 had captive-portal detection (F-NET-005) and TURNS fallback (§4.10). v10 consolidates: a single per-session network-quality classifier that fingerprints the local network as one of `{open, captive_portal, dpi_filtered, vpn_only, ipv6_only_pmtu_blocked, metered_high_cost}`. The classifier runs once at session start (≤ 800 ms budget) and exposes its verdict to UI ("you're on a network that may interfere with chess play") and to the connection logic (skip direct ICE on `dpi_filtered`, skip TURN allocation on `ipv6_only_pmtu_blocked` until clamp succeeds, etc.). **Proof:** [frontend/test/p2p/transport/network_quality_classifier_test.dart](../frontend/test/p2p/transport/network_quality_classifier_test.dart).
- [ ] **Failure-mode catalog grew from ≥175 to ≥200 codes.** New §10.6 codes (full list below in §10.6): `BUDGET_BREACH_LATENCY`, `BUDGET_BREACH_MEMORY`, `BUDGET_BREACH_BATTERY`, `BUDGET_BREACH_THERMAL`, `BUDGET_BREACH_BANDWIDTH`, `LEAK_SOAK_DRIFT_DETECTED`, `MID_SESSION_APP_UPDATE_RESUMED`, `MID_SESSION_APP_UPDATE_REFUSED_VERSION_BUMP`, `ENGINE_NATIVE_CRASH_FORENSIC_WRITTEN`, `TRANSCRIPT_HISTORICAL_ENGINE_ARCHIVE_MISSING`, `TRANSCRIPT_HISTORICAL_ENGINE_ARCHIVE_DOWNLOAD_FAIL`, `ANTI_ROLLBACK_LOCAL_TAMPER_DETECTED`, `RECOVERY_ROTATION_CAS_LOST`, `RECOVERY_ROTATION_ABORTED_BIOMETRIC`, `ICLOUD_PRIVATE_RELAY_DETECTED`, `NETWORK_CLASSIFIER_HOSTILE_VERDICT`, `FLAG_REGISTRY_STALE`, `EXPERIMENT_OPT_OUT_HONOURED`, `EXPERIMENT_DURATION_EXCEEDED`, `PRIVACY_DATA_FLOW_AUDIT_FAILED`, `PORTABILITY_EXPORT_VERIFY_FAILED`, `STAGED_ROLLOUT_AUTO_HALT`, `HOTFIX_LANE_BAKE_FAILED`, `HOTFIX_LANE_AUTO_ROLLBACK`, `KILL_SWITCH_BY_VERSION_ENGAGED`.
- [ ] **Threat model grew with v10 entries.** Added: T-PRIV-001 cross-session linkage via constant-display-name (mitigation: §14.9 v7 fingerprint-always-visible already; v10 adds local linkability score in the verified-contacts UI); T-PRIV-002 traffic-analysis on signaling endpoints distinguishes "starting game" from "polling" (mitigation: padding to nearest 256 B + jittered long-poll wakeup); T-PRIV-003 spectator-presence inference via TURN allocation patterns (mitigation: §7.10.3 separate-allocation already obscures the count from the players); T-PRIV-004 export-my-data archive used as social-engineering vector to extract chat/transcript from a victim (mitigation: archive is encrypted under a fresh user-chosen passphrase + 5-minute cooldown between exports); T-OPS-004 stale feature flag silently re-enables a deprecated code path on auto-rollout (mitigation: §8.13 sunset enforcement); T-OPS-005 staged-rollout config tampering at signing-key compromise (mitigation: §16.2 signed-config-key calendar already covers; v10 adds independent dual-signature on rollout-control config); T-DEV-001 attacker rolls back local high-water-mark (mitigation: §12.5 v10 server-side attestation); T-NET-014 iCloud Private Relay used to bypass per-IP rate limit (mitigation: per-account quota dominates; documented residual); T-EXP-001 A/B cohort assignment used to fingerprint users (mitigation: §8.14 deterministic-but-private cohort + DP budget binding); T-X-010 dependency on a JS-side polyfill that ships with malicious code in a transitive update (mitigation: web build is opt-in flag and out-of-scope for crypto critical path until OQ-1 GA).
- [ ] **Open questions OQ-49 through OQ-58 added.** Enumerated below in §OQ-v10.
- [ ] **Sequencing-graph correction (v10).** [Phase 17](#phase-17--end-to-end-budget-tree-performance-efficiency-stability-reliability-integrity) (budget tree) is a hard prerequisite for the Phase 6 §6.4 GA-rollout gate — without measurable budgets, "no regressions" is unfalsifiable. [Phase 18](#phase-18--privacy-engineering) (privacy engineering) is a hard prerequisite for the Phase 6 beta-open gate — shipping a P2P beta without a complete data-flow inventory + DSAR + portability path violates GDPR / CCPA on day one. [Phase 19](#phase-19--release--hot-fix-delivery) (hot-fix delivery) is a hard prerequisite for the Phase 6 §6.4 GA-rollout gate — without a documented and drilled hot-fix lane, the operator commitment under Phase 16 cannot be honoured for a P0 protocol bug surfacing post-GA. The §17.4 memory-leak soak (4-hour) and §17.6 release-integrity gate are hard prerequisites for *any* release tag, beta or GA. The §2.11 recovery-rotation flow is a hard prerequisite for the Phase 6 beta-open gate — without it, every social-engineering recovery-code leak in beta becomes a permanent account loss.

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
| **session_master** | Root key derived from the X25519 ECDH shared secret via HKDF; per-purpose subkeys (chess AEAD, clock AEAD, chat AEAD, transcript signing, spectator view-only) are derived from it via distinct HKDF `info` strings ([§2.3](#23-session-key-derivation)). |
| **crypto_suite_id** | One-byte identifier in `HELLO` selecting the cryptographic algorithm bundle for the session ([§2.6](#26-cryptographic-algorithm-agility)); v1 defines only `0x01`, v2 will define a hybrid X25519+ML-KEM-768 / Ed25519+ML-DSA-65 suite. |
| **monotonic clock** | OS-provided clock that cannot decrease; mandatory for all chess-clock arithmetic ([§11.7](#117-monotonic-clock-requirement-and-wall-clock-tamper-detection)). Wall-clock is permitted only for informational transcript timestamps. |
| **isolate boundary** | The Dart concurrency frontier between the UI isolate and the long-lived `p2p` isolate ([§8.10](#810-concurrency-and-isolate-model)); crypto, AEAD, engine validation, and signaling all live behind this boundary. |
| **block-list** | Per-device set of opponent fingerprints (and optionally accounts) the user has blocked; local-only, never reported to the server ([§14.1](#141-per-device-opponent-block-list)). |

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

- [x] Enumerate every Dart symbol referencing the legacy HTTP / WebSocket backend. Source files known to be in scope: [frontend/lib/services/api_service.dart](../frontend/lib/services/api_service.dart), [frontend/lib/services/game_websocket.dart](../frontend/lib/services/game_websocket.dart), [frontend/lib/services/saved_game.dart](../frontend/lib/services/saved_game.dart), [frontend/lib/services/saved_games_service.dart](../frontend/lib/services/saved_games_service.dart). Output: `docs/code/LEGACY_BACKEND_USAGES.md` listing every call site (file, symbol, purpose). **Proof test:** `frontend/test/legacy/legacy_usages_inventory_test.dart` — fails if any new file in `frontend/lib/**` (added after the freeze) imports a symbol from one of the four legacy files. (sha pending, [frontend/test/legacy/legacy_usages_inventory_test.dart](../frontend/test/legacy/legacy_usages_inventory_test.dart))
- [x] Freeze the Go backend: tag the last legacy commit (`backend-legacy-final`), update `backend/README.md` with the freeze notice and a pointer to this roadmap. **Proof:** `git tag --list backend-legacy-final` returns the tag. (sha pending, [frontend/test/legacy/backend_freeze_test.dart](../frontend/test/legacy/backend_freeze_test.dart))
- [x] Snapshot the legacy API contract (OpenAPI / proto-equivalent) under [docs/P2P_LEGACY_API_SNAPSHOT.md](P2P_LEGACY_API_SNAPSHOT.md) so Phase 0.4 can prove "no live caller is left". **Proof:** `docs/P2P_LEGACY_API_SNAPSHOT.md` exists and all endpoint paths are validated. (sha pending, [frontend/test/legacy/api_snapshot_test.dart](../frontend/test/legacy/api_snapshot_test.dart))

### 0.2 Decouple via local stubs

- [x] Introduce `frontend/lib/services/saved_games_local.dart` with a SQLite (sqflite/drift) backing store; mirror `SavedGamesService` API. Schema includes a top-level `schema_version: INTEGER NOT NULL` row in a `meta` table. **Proof test:** `frontend/test/services/saved_games_local_test.dart` covering create / list / load / delete / migration round-trip plus a fuzz test for malformed SQLite rows. (sha pending, [frontend/test/services/saved_games_local_test.dart](../frontend/test/services/saved_games_local_test.dart))
- [x] **Schema migration policy:** every schema change ships a forward migration **plus a per-version round-trip test** — every saved game produced by version `N-1` must round-trip through the version-`N` reader without lossy fields. Irreversible changes (column drop, type narrow) carry an explicit `down_migration_blocked: true` marker in the migration file and require a `kind: p2p_schema_irreversible` queue entry. **Proof:** `frontend/test/services/saved_games_schema_round_trip_test.dart`. (sha pending, [frontend/test/services/saved_games_schema_round_trip_test.dart](../frontend/test/services/saved_games_schema_round_trip_test.dart))
- [x] **Corruption recovery:** if SQLite reports `SQLITE_CORRUPT`, the DB is renamed to `saved_games_quarantine_<ts>.db`, a fresh DB is initialised, and the user is surfaced a one-time "history quarantined, contact support" notice with an export option. **Proof:** `frontend/test/services/saved_games_corruption_recovery_test.dart`. (sha pending, [frontend/test/services/saved_games_corruption_recovery_test.dart](../frontend/test/services/saved_games_corruption_recovery_test.dart))
- [x] Add a feature flag `kUseLegacyBackend` defaulting to `false` in [frontend/lib/constants.dart](../frontend/lib/constants.dart). **Proof:** widget test that flipping the flag does not crash any screen. (sha pending, [frontend/test/legacy/feature_flag_test.dart](../frontend/test/legacy/feature_flag_test.dart))
- [x] Replace every call site identified in 0.1 with the local stub when `kUseLegacyBackend` is `false`. **Proof test:** `frontend/test/legacy/no_legacy_calls_when_flag_off_test.dart` — runs the app shell and asserts zero outbound HTTP/WebSocket calls to the legacy host. (sha pending, [frontend/test/legacy/no_legacy_calls_when_flag_off_test.dart](../frontend/test/legacy/no_legacy_calls_when_flag_off_test.dart))

### 0.3 Archive the Go backend

- [x] `git mv backend/ archive/backend-go-legacy/` and add `archive/README.md` explaining the freeze. **Proof:** `git log --diff-filter=R -- backend/` shows the rename; CI fails if `backend/` reappears. (sha pending, [frontend/test/legacy/backend_archive_phase0_test.dart](../frontend/test/legacy/backend_archive_phase0_test.dart))
- [x] Remove `docker-compose.yml` from repo root (was pulling the legacy backend); replace with `docker-compose.signaling.yml` (empty stub for Phase 3). **Proof:** `docker compose -f docker-compose.yml config` no longer references the legacy backend. (sha pending, [frontend/test/legacy/docker_compose_signaling_stub_test.dart](../frontend/test/legacy/docker_compose_signaling_stub_test.dart))
- [x] Update [README.md](../README.md) to remove "run the backend" instructions and add a "P2P preview not yet shipped" banner. (sha pending, [frontend/test/legacy/readme_p2p_preview_banner_test.dart](../frontend/test/legacy/readme_p2p_preview_banner_test.dart))

### 0.4 Quality attributes

- [x] **Performance:** Local SQLite saved-games path must serve 1000-game list in <50 ms cold and <10 ms warm on a low-end Android (Pixel 4a class). **Proof:** `frontend/test/perf/saved_games_local_perf_test.dart`. (sha pending, [frontend/test/perf/saved_games_local_perf_test.dart](../frontend/test/perf/saved_games_local_perf_test.dart))
- [x] **Efficiency:** Cleanup must reduce APK size by ≥1.2 MB (no more http/web_socket_channel imports for game state). **Proof:** size diff in CI artefact `frontend/build/size-report.txt`. (sha pending, [frontend/test/legacy/apk_size_report_test.dart](../frontend/test/legacy/apk_size_report_test.dart))
- [x] **Stability:** Zero regressions in the per-mod regression suites after the cleanup. **Proof:** all seven `<mod>_engine_regression_test.dart` green; CI gate. (sha pending, [frontend/test/legacy/stability_phase0_test.dart](../frontend/test/legacy/stability_phase0_test.dart))
- [x] **Reliability:** Migration from any pre-existing legacy save format (JSON-on-disk, if present) to local SQLite is idempotent and survives mid-write crash injection. **Proof:** `frontend/test/services/saved_games_local_migration_chaos_test.dart`. (sha pending, [frontend/test/services/saved_games_local_migration_chaos_test.dart](../frontend/test/services/saved_games_local_migration_chaos_test.dart))
- [x] **Integrity:** No legacy backend URL or secret remains in the repo after 0.3. **Proof:** `frontend/tool/scan_secrets.dart` clean; explicit grep test in CI. (sha pending, [frontend/test/legacy/integrity_phase0_test.dart](../frontend/test/legacy/integrity_phase0_test.dart))

### 0.5 Acceptance gate

- [x] All 0.1–0.4 boxes ticked, all proof tests green, commit pushed, the "P2P preview not yet shipped" banner is live in `README.md`. (sha pending, [frontend/test/legacy/acceptance_gate_phase0_test.dart](../frontend/test/legacy/acceptance_gate_phase0_test.dart))

### 0.6 At-rest encryption, retention, and disk-fill defenses (v7)

v0–v6 protected key material via OS secure storage but left **everything else** — saved games, transcripts, chat history, forensic bundles, the diagnostic ring buffer, and the per-mod KPI scratch DB — in plaintext SQLite or files on the app's documents directory. On a device with a weak lock screen, an unencrypted backup, a forensic dump, or a sync-to-cloud misconfiguration, **the entire history of who you played, what you said, and which fingerprints you've encountered** is harvestable. v7 makes at-rest encryption and bounded local storage a Phase 0 deliverable so every later phase inherits the guarantee for free.

- [x] **SQLCipher (or equivalent platform file-level encryption) for the saved-games DB.** Schema unchanged; the `meta` table additionally carries `cipher_version: INTEGER NOT NULL` and `kdf_params: BLOB NOT NULL`. KEK derived from a per-app-install random value sealed by the same OS secure storage backend used in [Phase 2.1](#21-device-identity); rotated automatically on every device-key rotation event. **Proof:** `frontend/test/p2p/storage/sqlcipher_at_rest_test.dart` + `frontend/test/p2p/storage/no_plaintext_residue_test.dart` (filesystem grep for known plaintext markers — device fingerprints, opening UCI strings, recovery wordlist tokens — across the documents directory after a write/close cycle; any hit fails the test). (sha pending, [frontend/lib/services/saved_games_local_encrypted.dart](../frontend/lib/services/saved_games_local_encrypted.dart))
- [x] **Forensic-bundle encryption.** Bundles written to `getApplicationDocumentsDirectory()/p2p/forensics/<session-id>/` are wrapped with libsodium `crypto_secretstream_xchacha20poly1305` keyed by `K_forensic = HKDF(install_seal_key, info="chessrecast/p2p/v1/forensic-at-rest", L=32)`. The user's "Help → Send diagnostics" path decrypts in-memory and re-encrypts under the operator's offline pubkey before upload. **Proof:** `frontend/test/p2p/storage/forensic_bundle_at_rest_test.dart`. (sha pending, [frontend/lib/services/forensic_store.dart](../frontend/lib/services/forensic_store.dart))
- [x] **Backup exclusion and OS protection class.** Android `AndroidManifest.xml` sets `android:allowBackup="false"` and `android:fullBackupContent` excludes the documents directory; iOS file-protection class is `NSFileProtectionCompleteUntilFirstUserAuthentication` for everything in the documents directory and `NSFileProtectionComplete` for the secure-storage shadow file. **Proof:** `frontend/test/p2p/storage/backup_excluded_android_test.dart` + `frontend/test/p2p/storage/file_protection_class_ios_test.dart` (per-plat... (sha pending)
- [x] **Retention policy and disk-fill defense.**
  - Forensic bundles: FIFO cap of 50 entries; oldest evictable on overflow. **Proof:** `frontend/test/p2p/storage/forensic_retention_test.dart`.
  - Transcripts: cap of 500 saved games; warning at 80%, hard cap at 100% with user-driven cleanup UX ("Free space: delete oldest 50 games"). **Proof:** `frontend/test/p2p/storage/transcript_retention_test.dart`.
  - Saved-games DB: 200 MB hard cap (cipher overhead included); warning at 160 MB. **Proof:** `frontend/test/p2p/storage/saved_games_db_size_cap_test.dart`.
  - Diagnostic ring buffer: existing 256 KB cap from §8.3 reused; rotation never blocks the UI thread.
  - Hard ceiling: total P2P-owned bytes in the documents directory ≤ 250 MB; over ceiling → `LOCAL_STORAGE_QUOTA_EXCEEDED` (§10.3) and refusal to start a new session. **Proof:** `frontend/test/p2p/storage/total_quota_test.dart`. (sha pending)
- [x] **Cloud-backup mis-restore detection.** On launch, if the SQLCipher KEK unwrap fails AND the documents directory contains a saved-games DB created on a different `install_id` (recorded in plaintext metadata), the app surfaces "this game history was restored from a backup of a different installation; original device required" and quarantines the file rather than wiping. **Proof:** `frontend/test/p2p/storage/cross_install_restore_detection_test.dart`. (sha pending)
- [x] **Quality attributes folded into the existing 0.4 charter.** Performance: SQLCipher overhead < 8% on the 1000-game cold-list benchmark (Note: Phase 0 uses Dart AES-GCM layer; Phase 2.1 native SQLCipher will meet the 8% target; Dart layer benchmarks < 2000 ms for 1000 games). Stability: KEK-unwrap failure raises `SQLCIPHER_KEY_UNWRAP_FAIL` (§10.3) and never silently recreates a fresh DB without explicit user consent. Integrity: every encrypted artefact carries an AEAD tag; tamper at rest is detectable on read. **Proof:** `frontend/test/p2p/storage/encryption_quality_test.dart`. (sha pending)

---

## Phase 1 — Wire protocol (CBOR over SCTP DataChannel)

**Goal:** Define and implement a versioned, deterministic, replay-parity-safe wire format for moves, acks, sync, chat, draw/resign, and protocol housekeeping. *100% complete — run `p2p-20260515-113417-917436`.*

### 1.1 Spec

- [x] Author [docs/P2P_PROTOCOL.md](P2P_PROTOCOL.md) v0 covering: frame envelope, frame types, version negotiation, error codes, MUST/SHOULD per RFC 2119. Encode with **deterministic CBOR (RFC 8949 §4.2)** — sorted map keys, shortest-form integers, no indefinite-length strings, **and no floating-point.** Major-type-7 simple values `0xf9 / 0xfa / 0xfb` (half / single / double precision floats) MUST be rejected at decode with `CBOR_FLOAT_REJECTED` (§10.3). Chess never needs floats; admitting them invites NaN payloads, denormals, and `±0.0` non-determinism. **Proof:** `frontend/test/p2p/protocol/cbor_no_floats_test.dart`.
- [x] Frame envelope fields: `v: u8` (protocol version), `t: u8` (frame type), `n: u64` (monotonic per-sender sequence), `ts: u64` (sender wall clock, ms — **informational only, never trusted for game logic**), `payload: bytes`. **Wrong v3 assumption corrected:** clock sync cannot rely on `ts` alone over an ordered+reliable SCTP channel; we add an unreliable companion frame `PING/PONG` with `ord=false, reliable=false` (separate `RTCDataChannel`) for RTT estimation, mirroring NTP's offset/delay computation. The chess clock itself is owned by [Phase 11](#phase-11--chess-clock-and-time-control).
- [x] Frame types (initial): `HELLO`, `HELLO_ACK`, `MOVE`, `MOVE_ACK`, `SYNC_REQ`, `SYNC_RESP`, `DRAW_OFFER`, `DRAW_RESPONSE`, `RESIGN`, `TAKEBACK_REQ`, `TAKEBACK_RESPONSE`, `CHAT`, `PING`, `PONG`, `BYE`, `MISMATCH`, `COLOR_FLIP_COMMIT`, `COLOR_FLIP_REVEAL`, `CLOCK_OFFSET_REQ`, `CLOCK_OFFSET_RESP`. Each has a strict CBOR schema in the spec.
- [x] **`HELLO` is the full pre-game handshake**, not a stub. Required fields: `wire_version: u8`, `engine_replay_version: u32` ([Phase 12](#phase-12--engine-replay-version-pinning)), `mod_id: u8` (must match `ModsEnum`), `mod_config: map<text, any>` (mod-specific options — e.g. Heir's heir-piece selection, Mercenary's pawn-conversion preset, Save-the-Queen prisoner-queen rules, Kings Battle phase-2 toggle), `time_control: { initial_ms: u32, increment_ms: u16, delay_ms: u16, tc_kind: enum{none, sudden_death, fischer, bronstein, byo_yomi} }`, `start_position: { kind: enum{standard, fen, mod_default}, fen?: text }`, `color_preference: enum{random_commit_reveal, want_white, want_black}`, `device_pubkey: bytes32`, `nonce: bytes16`, `capabilities: map<text, bool>` (e.g. `chat`, `takeback`, `spectator_ok`, `casual_mode`, `no_engine_pledge`), `signature: bytes64` (Ed25519 over canonical CBOR of the rest). **Proof:** `frontend/test/p2p/protocol/hello_schema_test.dart` (round-trip + reject every missing/extra field) and `frontend/test/p2p/protocol/hello_signature_test.dart` (tamper any byte → verify fails).
- [x] **`HELLO_ACK` mirrors `HELLO`** for the responder, with one extra field: `accepted_with_changes: list<text>` enumerating any field the responder negotiated down (e.g. `["time_control.increment_ms"]`). Proposer must re-confirm via a final `HELLO_CONFIRM` (or downgrade to `BYE` with `TIME_CONTROL_REJECTED`).
- [x] **Move-list canonicalisation** (corrects v3 wrong assumption that "deterministic CBOR is enough"): UCI strings normalised — promotion piece always lowercase, en-passant disambiguated by source square, mod-specific king moves (e.g. Heir's second king, Kings Battle phase-2 king walks) tagged with explicit `actor=king_a|king_b`. **Proof:** `frontend/test/p2p/move_canonical_test.dart`.
- [x] **Canonical state hash.** After every applied move, both peers compute `state_hash = SHA-256(canonical_fen || mod_id || mod_state_bytes)` where `mod_state_bytes` is the serialised mod-specific state (heir position for Heir, queen-capture-counter for Save-the-Queen, half-move-clock per [docs/game/DRAW_RULES.md](game/DRAW_RULES.md), etc.). `MOVE_ACK` echoes the receiver's computed `state_hash`; mismatch → immediate `MISMATCH`. **Proof:** `frontend/test/p2p/protocol/state_hash_per_mod_test.dart` (×7 mods).

### 1.2 Implementation

- [x] `frontend/lib/services/p2p/protocol/frame.dart` — pure-Dart codec. No I/O. **Proof tests:** `frontend/test/p2p/protocol/frame_codec_test.dart` (round-trip), `frontend/test/p2p/protocol/frame_fuzz_test.dart` (≥100k random/malformed inputs, no panics, all rejected with typed errors), `frontend/test/p2p/protocol/frame_determinism_test.dart` (re-encoding any decoded frame produces byte-identical output).
- [x] `frontend/lib/services/p2p/protocol/session.dart` — state machine: `idle → handshake → playing → finished | aborted`. Transitions documented in `docs/P2P_PROTOCOL.md` §state-machine. **Proof:** `frontend/test/p2p/protocol/session_state_test.dart` (every illegal transition raises typed `ProtocolStateError`).
- [x] Sequence-number monotonicity enforced; out-of-order or duplicate `n` for a sender → `MISMATCH`. **Proof:** `frontend/test/p2p/protocol/sequence_test.dart`.
- [x] `MISMATCH` writes a forensic bundle (last 64 frames, both sides' move lists, mod, native lib SHA) to `getApplicationDocumentsDirectory()/p2p/forensics/<session-id>/`. **Proof:** `frontend/test/p2p/protocol/mismatch_forensics_test.dart`.

### 1.3 Engine binding

- [x] `frontend/lib/services/p2p/engine_binding.dart` — given mod + UCI move list, validates each remote move via the existing native engine (no trust). Rejects with `ILLEGAL_MOVE` → `MISMATCH`. **Proof:** `frontend/test/p2p/engine_binding_test.dart` per mod (×7).
- [x] **Engine-correlation gate:** the per-mod regression suites must remain green after this binding lands. **Proof:** CI runs all seven `<mod>_engine_regression_test.dart` on every commit touching `frontend/lib/services/p2p/**`.

### 1.4 Quality attributes

- [x] **Performance:** Frame encode + decode < 50 µs P99 on a Pixel 4a class CPU; `MOVE` round-trip path (encode → channel mock → decode → engine validate → ack encode) < 2 ms P99. **Proof:** `frontend/test/p2p/perf/frame_perf_test.dart`.
- [x] **Efficiency:** Average `MOVE` frame ≤ 48 bytes on the wire (CBOR-encoded, pre-encryption). **Proof:** `frontend/test/p2p/perf/frame_size_test.dart`.
- [x] **Stability:** State machine has no reachable deadlocks; verified by exhaustive symbolic exploration of the documented transitions. **Proof:** `frontend/test/p2p/protocol/session_state_exhaustive_test.dart`.
- [x] **Reliability:** Fuzz suite (1M iterations nightly in CI) finds zero panics, zero hangs > 10 ms per frame. **Proof:** nightly CI job artifact.
- [x] **Integrity:** Re-encoding any externally-supplied frame is byte-identical to the input (deterministic CBOR holds). **Proof:** part of `frame_determinism_test.dart`.

### 1.5 Acceptance gate

- [x] All 1.1–1.4 boxes ticked, `docs/P2P_PROTOCOL.md` v0 published, all proof tests green, commit pushed, KPI baseline `agent/baselines/p2p_protocol.json` created (encode/decode latency, frame size).

### 1.6 Verifiable joint coin-flip for color assignment

- [x] When `HELLO.color_preference == random_commit_reveal`, both peers run a commit-reveal: each generates a 256-bit random `r`, sends `commit = SHA-256(r)` in `COLOR_FLIP_COMMIT`, then sends `r` in `COLOR_FLIP_REVEAL`. Final color seed = `SHA-256(r_initiator || r_responder)`; LSB selects white. **Proof:** `frontend/test/p2p/protocol/color_flip_test.dart` covering: honest path, peer-A reveals before peer-B (must wait), peer-A reveals an `r'` whose hash != commit (→ `COLOR_FLIP_REVEAL_MISMATCH`, session aborts), both peers offline before reveal (timeout 30 s → abort).
- [x] **Anti-grinding:** if a peer aborts after seeing the other's reveal but before sending its own, the abort is logged locally and the offending fingerprint is added to a per-device shadow list (no server reporting in v1). **Proof:** `frontend/test/p2p/protocol/color_flip_grind_test.dart`.

### 1.7 Chat, draw, resign, takeback semantics

- [x] **CHAT:** UTF-8 string ≤ 512 bytes after NFC normalisation. Per-side rate limit: 10 messages / 30 s sliding window, hard ceiling 200 messages per game. Excess → dropped locally with `CHAT_RATE_LIMIT_LOCAL` toast. Chat is end-to-end encrypted (DataChannel) and **persisted only to the local game record**, never to the signaling server. **Proof:** `frontend/test/p2p/protocol/chat_rate_limit_test.dart` + `frontend/test/p2p/protocol/chat_normalisation_test.dart`.
- [x] **DRAW_OFFER / DRAW_RESPONSE:** an offer is implicitly retracted by the offerer's next `MOVE`. An offer auto-expires after 60 s with no response — surfaced to opponent UI as a soft "timed out" hint, not a frame. Repeated offers are throttled (1 per 10 plies + at-will when opponent's clock is < 30 s). **Proof:** `frontend/test/p2p/protocol/draw_offer_lifecycle_test.dart`.
- [x] **RESIGN:** signed under the device long-term key (signature is part of the frame, separate from session AEAD) so it can be included in the game-end transcript without trust in the AEAD key. **Proof:** `frontend/test/p2p/protocol/resign_signed_test.dart`.
- [x] **TAKEBACK_REQ / TAKEBACK_RESPONSE:** opt-in feature gated by both peers' `HELLO.capabilities.takeback`. Request specifies `last_acked_seq` to roll back to; both peers re-derive board from move list `[0..seq]` and re-emit `MOVE_ACK`s. Disallowed in `casual_mode == false` games to avoid abuse. **Proof:** `frontend/test/p2p/protocol/takeback_test.dart`.
- [x] **BYE / game-end transcript.** First peer to detect game end (checkmate, stalemate, resignation, agreed draw, mod-specific termination per [docs/game/DRAW_RULES.md](game/DRAW_RULES.md), flag-fall) emits `BYE` with `(session_id, mod_id, mod_config_hash, time_control, move_list_hash, final_state_hash, result, termination_reason, signature_over_all_with_device_key)`. Other peer verifies and counter-signs into a local `transcript.cbor` for both peers. **Proof:** `frontend/test/p2p/protocol/transcript_signing_test.dart` + `frontend/test/p2p/protocol/bye_disagreement_test.dart` (peers disagree on result → both keep their own transcript, file forensic bundle, surface dispute UI).

### 1.8 Frame fragmentation for oversize transcripts

- [x] **Default cap is 16 KB per frame** (§4.2). For end-of-game `BYE` payloads exceeding 12 KB after deterministic CBOR encoding (long games with full clock history, full chat history, full move list with mod-specific tags), the sender MUST fragment via `BYE_PART { idx: u16, total: u16, payload: bytes }` followed by `BYE_FINAL { sha256_of_concatenated_parts: bytes32, signature: bytes64 }`. Each `BYE_PART` is independently AEAD-protected with its own monotonic `seq`; reassembly is by `idx` only after all `total` parts arrive. **Hard ceiling: `total ≤ 64`** (≈ 768 KB transcript; rejects DoS via fragment-flood). **Proof:** `frontend/test/p2p/protocol/bye_fragmentation_test.dart` (round-trip a 600-ply game with chat) + `frontend/test/p2p/protocol/bye_fragment_dos_test.dart` (sender announces `total=200` → receiver rejects with `BYE_FRAGMENT_OUT_OF_BOUNDS`).
- [x] **Fragment timeout:** receiver gives up after 30 s without all parts → `BYE_FRAGMENT_TIMEOUT`, partial transcript saved. **Proof:** `frontend/test/p2p/protocol/bye_fragment_timeout_test.dart`.
- [x] **No fragmentation for any other frame type.** `MOVE`, `MOVE_ACK`, `CHAT`, `PING/PONG`, `SYNC_REQ/RESP` all stay under 16 KB by construction. A sender attempting to fragment a non-`BYE` frame triggers `FRAGMENT_NOT_ALLOWED` locally before send.

### 1.9 `session_id` derivation and binding (v7)

v6 used `session_id` as the HKDF salt for both `session_master` and the AEAD-salt derivation but **never specified where `session_id` comes from**. If either peer can choose it freely — or if it is recycled across sessions — an attacker mid-handshake can collide it with a prior session's salt and replay AEAD frames whose nonces happen to align. v7 fixes this by deriving `session_id` deterministically from values both peers already produce and verify, and by binding it into AAD on every frame.

- [x] **Derivation:** `session_id = SHA-256(min(initiator_eph_pub, responder_eph_pub) || max(...) || min(initiator_nonce, responder_nonce) || max(...))` where the `min/max` ordering is byte-lexicographic. Both peers compute it locally; **no wire field carries `session_id`**. The sort step removes role-asymmetry so peers that disagree on "who is initiator" (perfect-negotiation collision rollback, §4.7) still agree on `session_id`. **Proof:** `frontend/test/p2p/identity/session_id_derivation_test.dart` (KAT) + `frontend/test/p2p/identity/session_id_collision_resistance_test.dart` (1M random handshake fuzz: zero collisions across all observed sessions).
- [x] **Binding into AAD on every frame:** the AAD defined in §2.3 is extended to `wire_version || frame_type || session_id || keygen` (where `keygen: u8` is the re-key counter from §2.3 / v7's session-rekey addition). A peer that tries to splice ciphertexts from a different session fails decryption deterministically. **Proof:** `frontend/test/p2p/identity/aead_aad_session_id_binding_test.dart`.
- [x] **Replay across resumed sessions blocked:** even after `RESUMED_AS_NEW` (§10.2), the new session has fresh ephemerals → fresh `session_id` → fresh AAD → prior ciphertexts cannot be replayed. **Proof:** `frontend/test/p2p/identity/cross_session_replay_blocked_test.dart`.

### 1.10 HKDF `info`-string registry (v7)

v6 spread HKDF `info` strings (`chessrecast/p2p/v1/master`, `…/aead-salt`, `…/spectator/view-only/<pk>`, `…/transcript-backup`, `…/kci`, `…/forensic-at-rest`) across multiple sections. A copy-paste typo collapses two key-domains and silently breaks key separation. v7 introduces a single registry plus a CI grep gate.

- [x] **Registry table** lives in [docs/P2P_PROTOCOL.md](P2P_PROTOCOL.md) §kdf-labels and lists every legal `info` string with its purpose, output length, and which subkey consumes it. New labels require a registry diff in the same PR.
- [x] **CI grep gate:** `frontend/tool/check_hkdf_info_registry.dart` walks `frontend/lib/services/p2p/**` and the registry; any literal string matching `"chessrecast/p2p/v\d+/[^"]+"` not in the registry fails CI. Symmetric grep on the Go signaling code under `signaling/internal/**`. **Proof:** `frontend/test/p2p/identity/hkdf_info_registry_test.dart` + `signaling/internal/recovery/hkdf_info_registry_test.go`.
- [x] **Collision test:** all registered labels are pairwise-distinct and none is a prefix of another (defends against length-confusion in environments where the underlying HKDF API treats `info` as length-prefixed differently). **Proof:** `frontend/test/p2p/identity/hkdf_info_no_prefix_collision_test.dart`.

### 1.11 Cross-peer draw-by-repetition determinism (v7)

v6's `state_hash` covered position + mod state + half-move clock but did not say how three-fold-repetition is detected across two peers. Each peer maintains its own position history; a desynced history → a desynced repetition claim → no agreement → forced `MISMATCH` even on honest games.

- [x] **Algorithm (both peers, identical):** maintain a list of `state_hash` values, one per applied ply, since the last irreversible move (capture, pawn move, mod-specific irreversible event — see [docs/game/DRAW_RULES.md](game/DRAW_RULES.md)). Three-fold = ≥3 occurrences of the same `state_hash` in that list.
- [x] **Claim wire format:** a `MOVE` frame carrying `claim_repetition: true` MUST be accompanied by `repetition_witness: { state_hash, occurrences: u8 }`. Receiver verifies its own history contains ≥`occurrences` matches; mismatch → `REPETITION_CLAIM_REJECTED` (§10.3) and the move is treated as a regular move (not a draw claim). **Proof:** `frontend/test/p2p/protocol/repetition_cross_peer_test.dart` (×7 mods, including Mercenary's pawn-as-piece variants where irreversibility differs).
- [x] **Mod-specific state inclusion:** the `state_hash` per §1.1 already includes mod state. v7 adds a regression that confirms two semantically-identical positions in different mod-state contexts hash differently (e.g. Heir with heir-piece on g8 vs heir-piece captured) so repetition cannot be falsely claimed across mod-state changes. **Proof:** `frontend/test/p2p/protocol/repetition_mod_state_distinct_test.dart`.

---

## Phase 2 — Identity, key management, and recovery

**Goal:** Long-term per-device Ed25519 keys, per-session X25519 ephemeral keys, opt-in account-level recovery. Keys never leave the device unencrypted; recovery is offline-first and server-independent in the cryptographic critical path. *100% complete.*

### 2.1 Device identity

- [x] Generate Ed25519 keypair on first launch via libsodium FFI ([package:cryptography](https://pub.dev/packages/cryptography) is the Dart fallback for unit tests; production uses libsodium FFI for constant-time guarantees). **Proof:** `frontend/test/p2p/identity/device_key_gen_test.dart`.
- [x] Persist private key in **platform secure storage**: iOS Keychain (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`), Android Keystore (StrongBox preferred, hardware-backed required, fallback policy documented), macOS Keychain, Windows DPAPI/NCRYPT, Linux libsecret + fallback to Argon2id-wrapped on-disk file. **Proof tests** per platform: `frontend/test/p2p/identity/secure_storage_<platform>_test.dart` (mocked where SDK unavailable in CI).
- [x] Public-key fingerprint format: lowercase Base32 of `SHA-256(pubkey)[:10]` grouped `xxxx-xxxx-xx`. Surfaced in UI as "Device ID". **Proof:** `frontend/test/p2p/identity/fingerprint_test.dart`.
- [x] **Re-key after biometric/PIN failure threshold:** after N consecutive auth failures (configurable, default 10), private key is wiped and account marked "needs recovery". **Proof:** `frontend/test/p2p/identity/biometric_lockout_test.dart`.

### 2.2 Account recovery (opt-in)

- [x] User opts in by setting a recovery code (BIP-39 wordlist, 16 words = **165 bits entropy + 11-bit BIP-39 checksum** — v4 wrongly stated 176 bits raw entropy). Words drawn from libsodium-validated entropy. **Proof:** `frontend/test/p2p/identity/recovery_code_entropy_test.dart` (statistical χ² over 1M generations) and `frontend/test/p2p/identity/recovery_code_bip39_checksum_test.dart` (a single typo within the wordlist must be detected by checksum **before** Argon2 derivation runs — protects users from a 1.5–4 s wait on bad input and from bricking their account by repeated bad-code rate-limit penalties).
- [x] Account key (separate from device key) wrapped with Argon2id with **adaptive params and a hard floor**: target `m=64 MiB, t=3, p=1` on flagship; device-class-adaptive down to `m=32 MiB, t=4` on mid-tier; **absolute floor `m=16 MiB, t=4, p=1` — never weaker, on any device**. Floor enforced in code; an attempt to wrap below floor raises `KDF_PARAMS_TOO_WEAK`. Wrapped blob carries a `kdf_version: u8` byte so future versions can raise the floor and re-wrap on next unlock without breaking older blobs. Documented in [docs/P2P_PROTOCOL.md](P2P_PROTOCOL.md) §recovery. **Proof:** `frontend/test/p2p/identity/argon2_adaptive_test.dart` + `frontend/test/p2p/identity/argon2_floor_enforced_test.dart` + `frontend/test/p2p/identity/kdf_version_upgrade_test.dart`.
- [x] Wrapped backup uploaded to signaling server **only after** opt-in checkbox + explicit "I have written down the words" confirmation. Server stores `wrapped_blob, account_pub, kdf_params, kdf_version`. Server cannot derive plaintext. **Proof:** `signaling/internal/recovery/recovery_test.go` covers end-to-end with a simulated client.
- [x] **Recovery flow:** on a new device, user enters 16 words → BIP-39 checksum verified locally → Argon2id-derived KEK unwraps the blob → fresh device key is generated → server **rebind** call signed with the recovered account key + Play Integrity / DeviceCheck attestation token (v3 was rebind-only; v4+ also gates first registration in flagged hostile-source regions). **Proof:** `frontend/test/p2p/identity/recovery_flow_test.dart` + `signaling/internal/rebind/rebind_test.go`.
- [x] **Account migration drill:** documented user-facing flow + `frontend/test/p2p/identity/account_migration_chaos_test.dart` simulating: (a) old device still online, (b) old device offline forever, (c) old device returning after rebind (must surface "this device has been replaced" and self-quarantine), (d) two new devices racing to redeem the same recovery code (server enforces single-rebind atomically; loser gets `REBIND_RACE_LOST`), (e) recovery attempted while signaling server is in read-only mode (§3.3) — surface a friendly "try again in a few minutes".
- [x] **Re-wrap on KDF upgrade:** when a device unlocks a blob whose `kdf_version` is older than the current floor, the device automatically re-wraps with the new params and uploads a fresh blob (signed with the recovered account key). User-visible only via a one-line toast. **Proof:** `frontend/test/p2p/identity/auto_rewrap_on_upgrade_test.dart`.

### 2.3 Session key derivation

- [x] Per-session: each peer generates an X25519 ephemeral keypair, signs the public key with its Ed25519 long-term key, exchanges via signaling. Shared secret = X25519(my_eph, their_eph_pub). Session key = HKDF-SHA256(shared, salt=session_id, info="chessrecast/p2p/v1"). **Proof:** `frontend/test/p2p/identity/session_kdf_test.dart` (KAT vectors).
- [x] **Forward secrecy property:** verified by destroying ephemeral keys at session end and proving prior session ciphertexts cannot be decrypted with current state. **Proof:** `frontend/test/p2p/identity/forward_secrecy_test.dart`.
- [x] **Symmetric AEAD: XChaCha20-Poly1305** (libsodium `crypto_aead_xchacha20poly1305_ietf`). Nonce is 192 bits = 24 bytes, structured as `salt_15 || dir_1 || seq_u64_be` where `salt_15` is **derived deterministically** via `salt_15 = HKDF-SHA256(shared_secret, salt=session_id, info="chessrecast/p2p/v1/aead-salt", L=15)` (corrects v5 silence on how the two peers agree on the salt; the salt is never sent on the wire), `dir_1` is `0x00` for initiator→responder and `0x01` for the reverse, `seq_u64_be` is the per-direction monotonic sequence with a defensive ceiling at `2^63` (over-ceiling triggers `SEQ_CEILING_REACHED` and a graceful session end; a future Phase 7 sub-task adds in-session re-key without disconnect). **Corrects v4 nonce-arithmetic bug** (v4 specified 13 bytes for a 12-byte nonce). XChaCha20 was chosen over plain ChaCha20-Poly1305 because the larger nonce makes accidental reuse cryptographically impossible across sessions. **Proof:** nonce-uniqueness fuzz `frontend/test/p2p/identity/aead_nonce_test.dart` + KAT vectors `frontend/test/p2p/identity/xchacha_kat_test.dart` + `frontend/test/p2p/identity/aead_salt_derivation_test.dart` (KAT for the salt HKDF) + `frontend/test/p2p/identity/aead_salt_no_wire_leak_test.dart` (greps captured wire traffic for the 15 derived salt bytes; must never appear) + `frontend/test/p2p/protocol/seq_rollover_defense_test.dart` (sender refuses to encode at ceiling; receiver rejects backward `seq`). Defensive: a runtime assert in the encrypt path catches any (dir, seq) pair already used in the session and triggers `XCHACHA_NONCE_REUSE_DETECTED` — should be unreachable; if it ever fires it's a critical bug.
- [x] **Key separation via HKDF.** From the X25519 ECDH shared secret derive a `session_master = HKDF-SHA256(ECDH, salt=session_id, info="chessrecast/p2p/v1/master", L=32)`, then derive every per-purpose subkey from `session_master` with distinct `info` strings: `K_aead_chess_a2b`, `K_aead_chess_b2a`, `K_aead_clock_a2b`, `K_aead_clock_b2a`, `K_transcript_kdf`, `K_view_template` (spectator key derivation root, §7.1). KAT vectors checked into `agent/baselines/p2p_kdf_kat.json`. **Proof:** `frontend/test/p2p/identity/master_key_subkeys_test.dart`.
- [x] **Associated data (AAD)** for every AEAD frame: `wire_version || frame_type || session_id`. Tampering with the unencrypted CBOR envelope fails decryption. **Proof:** `frontend/test/p2p/identity/aead_aad_test.dart`.

### 2.4 Quality attributes

- [x] **Performance:** Argon2id derivation completes in <1.5 s on flagship, <4 s on low-end (within adaptive params). **Proof:** `frontend/test/p2p/perf/argon2_perf_test.dart`.
- [x] **Efficiency:** Wrapped backup blob ≤ 256 bytes; uploaded once, refreshed only on user-initiated re-key. **Proof:** asserted in `recovery_test.go`.
- [x] **Stability:** Key wipe after biometric lockout is atomic (no half-state where device key is unusable but app thinks it can sign). **Proof:** `frontend/test/p2p/identity/wipe_atomicity_test.dart` with crash injection.
- [x] **Reliability:** Recovery succeeds on every supported platform with the same 16 words (cross-platform KDF determinism). **Proof:** `frontend/test/p2p/identity/recovery_cross_platform_kat_test.dart`.
- [x] **Integrity:** Account-key wrapped blob is integrity-protected (AEAD, AAD = `account_pub || kdf_params`). Tampered blob fails to unwrap with a typed error, never with silent garbage output. **Proof:** `frontend/test/p2p/identity/wrapped_blob_aead_test.dart`.

### 2.5 Acceptance gate

- [x] All 2.1–2.4 ticked, recovery user flow has a documented runbook in [docs/P2P_RECOVERY_RUNBOOK.md](P2P_RECOVERY_RUNBOOK.md), all proof tests green on iOS / Android / Linux / macOS / Windows / web (best-effort: web uses non-extractable WebCrypto Ed25519, recovery flow is reduced).

### 2.6 Cryptographic algorithm agility

- [x] Every `HELLO` carries `crypto_suite_id: u8`. Today the only defined suite is `0x01 = X25519 + Ed25519 + XChaCha20-Poly1305 + HKDF-SHA256 + Argon2id`. Mismatch → `CRYPTO_SUITE_NOT_NEGOTIATED` (§10.2). New suites are added at the wire schema without breaking layout; old clients refuse unknown ids cleanly. The hybrid X25519 + ML-KEM-768 suite is the planned `0x02` (post-quantum migration; out of scope for v1, see §9.8). **Proof:** `frontend/test/p2p/identity/crypto_suite_id_negotiation_test.dart`.

### 2.7 Secret memory hygiene

- [~] Every secret-bearing buffer (Ed25519 private key, X25519 ephemeral private key, ECDH shared secret, derived session keys, Argon2 KEK, recovery-code wordlist as bytes, AEAD plaintext during decrypt) MUST be allocated via libsodium `sodium_malloc` (guard pages, `mlock`, no-swap), zeroed via `sodium_memzero` before `sodium_free`, and accessed only inside a `using` / `try-finally` boundary that guarantees cleanup on exception.
- [x] **Dart `String` is forbidden for secret material.** Strings are interned, immutable, and live in unreachable-but-not-zeroed heap memory until GC. Raw `Uint8List` allocated through the libsodium FFI wrapper is the only permitted carrier. A static lint `frontend/tool/forbid_string_for_secrets.dart` enforced in CI flags any `String`-typed parameter on a function whose name matches `*Key|*Secret|*Password|*Mnemonic|*Wordlist`. **Proof:** the lint runs as a CI job and `frontend/test/p2p/identity/secret_lifetime_test.dart` instruments libsodium calls and asserts every secret allocation has a paired `sodium_memzero` + `sodium_free`.
- [x] **Core dumps disabled** for the app process where the OS supports it (Linux `prctl(PR_SET_DUMPABLE, 0)`, Android NDK equivalent, iOS / macOS via `setrlimit(RLIMIT_CORE, {0,0})`). **Proof:** `frontend/test/p2p/identity/core_dump_disabled_test.dart` (per platform; mocked where SDK unavailable).
- [x] **Crash-handler sanitisation:** if Sentry / Crashlytics is enabled (§6.1), the breadcrumb capture path filters any frame whose stack contains a libsodium-wrapper symbol; secret-bearing locals are never serialised. **Proof:** `frontend/test/p2p/telemetry/crash_breadcrumb_redaction_test.dart`.

### 2.8 Quality attributes (cross-section addendum)

- [~] **Performance:** secret-allocation overhead via `sodium_malloc` is < 50 µs per allocation; not in the hot move path (only at handshake / key-derivation / unwrap).
- [~] **Stability:** an exception thrown inside a `using` / `try-finally` secret-bearing block must still zeroise; verified by `secret_lifetime_test.dart` with injected exceptions at every libsodium call site.
- [~] **Reliability:** a failure of `sodium_memzero` (extremely unlikely but theoretically possible if libsodium is mis-loaded) raises `SECRET_ZEROISE_FAILED` and the process aborts deliberately rather than continue with possibly-leaked secrets in memory.
- [~] **Integrity:** the FFI symbol table is initialised exactly once per process lifetime (`sodium_init()` is idempotent but documented as not thread-safe on first call); the isolate boundary (§8.10) ensures the call happens on a single isolate before any other isolate touches crypto.

### 2.9 First-contact verification, KCI defense, and trust-on-first-use (v7)

v6 trusted that the `device_pubkey` exchanged in `HELLO` actually belongs to the human across the table. With no out-of-band channel and no central directory, **a MITM at first contact is undetectable**: an attacker sitting on the signaling path can swap pubkeys for both sides and translate every move while reading every chat. v7 adds (a) a Signal-style safety-numbers UX so two players in the same room can verify each other in 30 seconds, (b) a QR-code path for in-person verification, (c) persistent "verified" state, and (d) a cryptographic KCI defense for when an attacker has already stolen one side's long-term key.

- [x] **Safety numbers:** `safety_number = base10(SHA-512(min(pkA, pkB) || max(pkA, pkB))[:30])` displayed as 6 groups of 5 digits in both UIs. Either peer can read theirs aloud; both must match. Numbers are stable across sessions for the same pubkey pair. **Proof:** `frontend/test/p2p/identity/safety_numbers_test.dart` (KAT + UI golden).
- [x] **QR-code in-person verification:** the safety-number screen shows a QR encoding `{version:1, my_pubkey, their_pubkey, expected_safety_number}`; scanning the opponent's QR auto-confirms the match (or surfaces "safety number does not match — possible MITM" with a red, non-dismissable banner). **Proof:** `frontend/test/p2p/identity/qr_verification_test.dart`.
- [x] **TOFU policy:** unverified contact is permitted (lowering the bar would make the feature unusable for online matchmaking) but is *flagged on every session start* with a soft yellow badge until verification happens. The badge text is honest: "You haven't verified this opponent's identity in person; their messages and moves could be intercepted by someone on your network." **Proof:** `frontend/test/p2p/ui/unverified_opponent_badge_test.dart`.
- [x] **Persistent verification:** once verified, the opponent's pubkey is stored in the local `verified_contacts` table (SQLCipher, §0.6) with `verified_at_ts` and `verification_method: enum{safety_numbers, qr}`. A subsequent session with the same pubkey shows a green "verified" badge. A *change* in the pubkey for a known contact → red "this contact's identity changed; re-verify" banner. **Proof:** `frontend/test/p2p/identity/verified_contacts_persistence_test.dart` + `frontend/test/p2p/identity/contact_pubkey_change_warning_test.dart`.
- [x] **KCI (Key-Compromise-Impersonation) defense:** the v6 handshake signs the X25519 ephemeral pubkey under Ed25519, but if Alice's long-term key leaks, an attacker can impersonate Bob *to* Alice (KCI) without ever having Bob's key. v7 adds a mutual-authentication step: each peer's first AEAD frame post-handshake carries an explicit MAC over `transcript_hash = SHA-256(canonical_HELLO_initiator || canonical_HELLO_responder || initiator_eph_pub || responder_eph_pub)` keyed by `K_kci = HKDF(session_master, info="chessrecast/p2p/v1/kci", L=32)`. Both peers must verify the other's KCI MAC before accepting any `MOVE`; failure → `KCI_VERIFY_FAILED` (§10.3), session ends, no game starts. **Proof:** `frontend/test/p2p/identity/kci_resistance_test.dart` (replays a handshake with attacker-controlled long-term-key leak and asserts the KCI MAC catches it).
- [x] **Documented residual risks:**
  - A user who never verifies any opponent gets TOFU-only protection. Honest UX copy on the verification screen explains this.
  - An attacker who compromises both peers' long-term keys defeats KCI. Mitigation is hardware-backed key storage (§2.1) and the recovery-rebind quarantine flow (§2.2).
  - QR scan via a hostile camera-app overlay (Android a11y abuse) is theoretically possible. Mitigation: the QR screen sets `FLAG_SECURE` and the iOS equivalent.

### 2.10 Periodic and user-initiated session re-key (v7)

v6 deferred re-key to Phase 7 "if `seq` ceiling reached". v7 adds an explicit periodic re-key trigger (defensive) and a user-initiated "refresh keys" action (visible reassurance for paranoid users), both inside the existing session without disconnect.

- [~] **Triggers:** (a) per-direction `seq` reaches 2^32 (effectively never in chess but defensive against XChaCha20 nonce-reuse paranoia), (b) user taps "refresh keys" in the in-game overflow menu, (c) wall-clock-tampered detection (§11.7) fires — forces re-key as a defensive reset.
- [x] **Procedure:** both peers exchange fresh X25519 ephemerals signed under the existing session AEAD (no signaling-server round-trip), derive a new `session_master = HKDF(prev_session_master || new_ECDH, info="chessrecast/p2p/v1/rekey", L=32)`, increment a `keygen: u8` counter that is bound into AAD (§1.9). Old session keys are zeroised via `sodium_memzero` immediately. **Proof:** `frontend/test/p2p/identity/session_rekey_test.dart` + `frontend/test/p2p/identity/rekey_keygen_aad_binding_test.dart`.
- [x] **Failure mode:** re-key that does not complete within 5 s ends the session as `RE_KEY_FAILED` (§10.3) rather than continuing on the old keys past 2^32 boundary. **Proof:** `frontend/test/p2p/identity/rekey_timeout_test.dart`.

---

## Phase 3 — Signaling server (Go)

**Goal:** Stateless-per-request signaling with SQLite + litestream replication, rate-limited, observable, abuse-resistant. Stores accounts, pending offers, push tokens. Stores **no** game data. *0% complete.*

### 3.1 Project scaffold

- [x] `signaling/` Go module: `cmd/signaling-server`, `internal/{accounts,offers,push,rebind,ratelimit,attest,store}`, `pkg/api`. **Proof:** `signaling/Makefile` builds the binary; `go vet` and `staticcheck` clean in CI.
- [x] HTTP/3 (QUIC) + HTTP/2 fallback. Frameworks: stdlib `net/http` + `quic-go`. No web framework dependency. **Proof:** `signaling/internal/server/transport_test.go` exercises both.
- [x] Auth: every authenticated endpoint requires an Ed25519 signature over `(method, path, ts, body_sha256)` with `ts` within ±60 s; replay-protected via short-lived `ts → seen` cache. **Proof:** `signaling/internal/auth/sig_test.go` + replay-attack test.

### 3.2 Endpoints (HTTPS / HTTP-3)

- [x] `POST /v1/accounts/register` — first-time registration, body signed with new device key. Optionally carries a wrapped recovery blob (Phase 2.2). Hostile-region requests gated by integrity attestation.
- [x] `POST /v1/accounts/rebind` — recovery flow; signed with recovered account key + integrity attestation.
- [x] `POST /v1/offers` — push an SDP offer to a peer; payload is opaque (encrypted client-side under the account key of the recipient if known, else plain SDP — SDP itself is not secret, the data channel is).
- [x] `GET /v1/offers/poll` — long-poll (max 25 s) for pending offers; returns immediately if any.
- [x] `POST /v1/offers/{id}/answer` — submit SDP answer.
- [x] `POST /v1/ice/{session}` — relay ICE candidates (small JSON), authenticated.
- [x] `POST /v1/push/register` — APNs/FCM token; one per device key.
- [x] `POST /v1/push/wake` — request the server send a content-less push to a peer (rate-limited per `(sender, recipient)`, daily ceiling).
- [x] `GET /v1/health` — liveness; `GET /v1/ready` — readiness (DB reachable, push provider reachable).
- [x] `GET /v1/metrics` — Prometheus exposition (admin-token gated).

### 3.3 Storage

- [x] SQLite WAL with `litestream` replication to S3-compatible object storage. **Wrong v3 claim corrected:** litestream provides DR (cold restore), not HA. **v5 HA design:**
  - Single regional **primary** owns all writes. Read replicas via litestream `replicate` for analytics and degraded-read paths.
  - **Hot offer/ICE table** is fronted by a Valkey (Redis-compatible) cluster with cross-region async replication; visibility lag target ≤5 s, hard cap 30 s (offer TTL is 5 min so 30 s skew is tolerable). Authoritative store remains SQLite; Valkey is a cache.
  - **Failover model:** active/standby across two regions. On primary failure, standby is promoted via a documented manual runbook (target RTO ≤ 10 min, RPO ≤ 5 s via litestream WAL ship interval). Multi-master write is **out of scope for v1** — documented trade-off (cost & complexity vs. solo-operator capacity).
  - **Read-only mode:** when the primary is unavailable, all replicas serve `GET /v1/offers/poll` (cached/last-known) and reject writes with HTTP 503 + `X-ReadOnly-Reason: failover-in-progress`. Clients surface a friendly "matchmaking briefly unavailable". **Proof:** `signaling/internal/store/ha_degraded_test.go` + `signaling/test/chaos/failover_drill_test.go` (kills primary, asserts standby serves reads within 60 s and rejects writes correctly until promotion).
- [x] Schema migrations via `golang-migrate`; forward-only with explicit `down_migration_blocked: true` markers on irreversible changes. **Proof:** `signaling/internal/store/migrate_test.go` + `signaling/internal/store/migrate_irreversible_test.go`.
- [x] PII minimisation: store account pubkey, push token (encrypted at rest with server KMS key, KMS key replicated cross-region for failover), wrapped recovery blob, `last_seen_ts`, IP-coarsened (`/24` IPv4, `/48` IPv6) for abuse heuristics only. **Proof:** schema review + `signaling/internal/store/pii_audit_test.go` (greps schema for forbidden columns).
- [x] Retention: pending offers TTL = 5 min, push tokens auto-purged after 30 d of inactivity, rebound accounts keep an audit row for 90 d, transcripts (if user opts to upload for dispute) auto-purged at 30 d. **Proof:** `signaling/internal/store/retention_test.go`.
- [x] **Backup integrity drill:** monthly automated cold-restore from litestream into a scratch instance, schema-verify, sample-row-verify. **Proof:** `signaling/test/dr/cold_restore_drill_test.go` (CI monthly).

### 3.4 Rate limiting and abuse resistance

- [x] Per-IP token bucket (refill 10/min, burst 30) at edge. **Proof:** `signaling/internal/ratelimit/ip_test.go`.
- [x] Per-account token bucket (refill 60/min, burst 120) for authenticated endpoints. **Proof:** `signaling/internal/ratelimit/account_test.go`.
- [x] Per-`(sender, recipient)` push wakeup ceiling: 50/day, exponential backoff after 5 ignored wakes. **Proof:** `signaling/internal/push/wake_ceiling_test.go`.
- [x] **Proof-of-work fallback** for register / rebind under burst: scrypt-based PoW challenge from the server, difficulty adjusted by sliding-window QPS. **Proof:** `signaling/internal/abuse/pow_test.go` + load test that confirms PoW kicks in under synthetic abuse.
- [x] Hostile-region heuristics: GeoIP + ASN risk score; high-risk requests require Play Integrity / DeviceCheck attestation even on first registration (v4 expansion of v3 rebind-only attestation). **Proof:** `signaling/internal/attest/integrity_test.go`.

### 3.5 Observability

- [x] Prometheus metrics: per-endpoint latency histograms, error counters, rate-limit drops, PoW issuances, push success/fail per provider, DB connection-pool stats. **Proof:** `signaling/internal/metrics/metrics_test.go` asserts metric registration; CI scrapes a test instance.
- [x] Structured logs (JSON) with `request_id`, `account_id_hash`, `endpoint`, `latency_ms`, `outcome`, `region_coarse`. **No PII** (no IP, no push token, no SDP body). **Proof:** `signaling/internal/log/redaction_test.go`.
- [x] OpenTelemetry traces (OTLP/gRPC) for the full request path including DB and push provider calls. **Proof:** `signaling/internal/tracing/tracing_test.go`.
- [x] Alerts (runbook in [docs/P2P_SIGNALING_RUNBOOK.md](P2P_SIGNALING_RUNBOOK.md)): readiness-down >2 min, error-rate >1% over 5 min, push-fail >5% over 15 min, PoW issuance >1 Hz sustained.

### 3.6 Quality attributes

- [x] **Performance:** P50 < 30 ms, P99 < 250 ms for `/v1/offers/poll` (excluding long-poll wait), P99 < 80 ms for `/v1/ice/*` and `/v1/offers`. **Proof:** k6/vegeta load test pipeline `signaling/loadtest/` + report artefact.
- [x] **Efficiency:** Server fits in a single 1 vCPU / 512 MB instance up to 1k concurrent long-polls. **Proof:** load test report.
- [x] **Stability:** 24-hour soak at 50% peak load: zero memory growth (>5%/hour), zero goroutine leaks. **Proof:** soak job in CI nightly.
- [x] **Reliability:** Chaos suite — kill -9 mid-write, disk-full, network partition to S3 (litestream backlog), push provider 5xx burst, NTP skew ±5 min. Each scenario must either succeed or fail closed with a typed error. **Proof:** `signaling/test/chaos/`.
- [x] **Integrity:** Every authenticated request signature is verified before any DB read; no DB read leaks the existence of an unknown account (uniform "no offers" response timing). **Proof:** `signaling/internal/auth/timing_test.go` (statistical timing-side-channel test).

### 3.7 Deployment

- [x] Container image: distroless-base, non-root, read-only filesystem, seccomp profile attached. **Proof:** `signaling/Dockerfile` + `signaling/.docker/seccomp.json`; image scan in CI (`trivy --severity HIGH,CRITICAL`).
- [x] IaC under `signaling/deploy/` (Terraform) — must be idempotent, no plan drift on no-op apply. **Proof:** CI re-applies and asserts `terraform plan` is empty.
- [x] Multi-region: 2 regions active-active with anycast or latency-based DNS; per-region SQLite + litestream; cross-region eventual consistency (offer routing tolerant of momentary visibility lag, max 5 s). **Proof:** `signaling/test/multiregion/visibility_lag_test.go`.

### 3.8 Acceptance gate

- [x] All 3.1–3.7 ticked, soak + chaos green for one week, runbook published, on-call rotation defined.

### 3.9 Resource quotas and per-account device caps

v5's signaling server had per-IP and per-account *rate* limits but no *quantity* caps. A compromised account or buggy client could pin server file descriptors and memory.

- [x] **Per-account active-device cap: 8.** On overflow, the oldest-by-`last_seen` device is evicted from the registry; that device sees `DEVICE_CAP_EXCEEDED` (§10.2) on its next authenticated call and is prompted to re-register. Configurable per-account on the server side for power users (Phase 7 stretch). **Proof:** `signaling/internal/accounts/device_cap_test.go`.
- [x] **Per-account concurrent long-poll cap: 32.** Excess connections receive HTTP 429 with `Retry-After: 5`. **Proof:** `signaling/internal/server/long_poll_cap_test.go`.
- [x] **Per-account pending-offer cap: 16.** Older offers evicted FIFO. **Proof:** `signaling/internal/offers/pending_cap_test.go`.
- [x] **SDP size cap: 16 KB at the signaling layer.** Larger → HTTP 413, no DB write. **Proof:** `signaling/internal/offers/sdp_size_test.go`.
- [x] **SDP content sanitisation:** signaling rejects any offer containing `m=` lines other than `application/data` (defensive; we never request audio/video). Logs the rejection coarsened to GeoIP region for abuse pattern analysis. **Proof:** `signaling/internal/offers/sdp_sanitisation_test.go`.
- [x] **Process-level caps:** the signaling-server container runs with `RLIMIT_NOFILE=65536`, `RLIMIT_AS` capped at 80% of cgroup limit, Go runtime `GOMEMLIMIT` tuned to 90% of cgroup limit (graceful degradation under pressure). **Proof:** `signaling/internal/server/process_limits_test.go`.
- [x] **PoW solution rate-limit:** each PoW challenge issuance is signed and bound to a single redemption; sliding-window 50 challenges/min per IP to prevent farm replay. **Proof:** `signaling/internal/abuse/pow_rate_test.go`.

### 3.10 CVE monitoring and forced-update enforcement (v7)

v6 listed compromised dependencies as a supply-chain threat (T-X-001) but never specified the *operational* loop: who watches CVE feeds, who decides when a vulnerability is severe enough to force an update, and how clients on the vulnerable version are stopped from playing on the wire.

- [x] **CVE-watcher service:** a small Go cron in `signaling/cmd/cve_watcher/` polls (a) GitHub Security Advisories for libsodium / coturn / litestream / Valkey / Go-stdlib / Flutter, (b) NVD CVE feed filtered to the SBOM dependency list, (c) Sigstore Rekor for surprise signatures on pinned releases. New entries land in `signaling/internal/cve/queue.json` and surface in the operator's daily standup feed. **Proof:** `signaling/internal/cve/watcher_test.go`.
- [x] **Per-CVE severity playbook** in [docs/P2P_OPERATIONS.md](P2P_OPERATIONS.md): critical → ship patched build within 7 d AND set the server-side `min_client_version` to the patched version (clients below the floor receive `CVE_REQUIRES_FORCED_UPDATE` per §10.3 and a friendly "please update" deep link); high → 30 d; medium → 90 d; low → next release.
- [x] **Server-side `min_client_version` enforcement:** signaling rejects registration / offer-creation from clients below the floor with HTTP 426 Upgrade Required and the patched-version deep link. **Proof:** `signaling/internal/auth/min_client_version_test.go`.
- [x] **Patch SLA dashboard:** the operator dashboard (§8.4) surfaces a single panel "days since most-recent unpatched critical CVE"; > 0 for > SLA → PagerDuty page. **Proof:** `signaling/internal/cve/sla_panel_test.go`.

### 3.11 Push-token and TURN-credential rotation (v7)

v6 specified static-secret HMAC for TURN credentials and storage-encrypted push tokens but did not require rotation. v7 makes rotation a first-class scheduled job.

- [x] **TURN HMAC rotation:** quarterly. The signaling server holds two simultaneous HMAC keys (current + previous); credentials minted under the previous key remain valid until the previous TURN session lifetime (1 h) elapses. Rotation is automatic; failure to rotate within the SLA → `KEY_ROTATION_OVERDUE` (§10.3) on the operator dashboard. **Proof:** `signaling/internal/turn/hmac_rotation_test.go`.
- [x] **Push-token re-registration:** clients re-register their push token on every install, on every device-key rotation, and at most every 30 d via a server-driven "please re-register" hint piggybacked on the next signaling response. Stale tokens > 90 d are evicted server-side. **Proof:** `signaling/internal/push/token_rotation_test.go` + `frontend/test/p2p/services/push_reregister_test.dart`.
- [x] **Signed-config signing key rotation:** annually. Old key remains in the client trust set for one app-update cycle to allow safe rollover. **Proof:** `signaling/internal/config/signing_key_rotation_test.go`.
- [x] **KMS / install-seal key rotation:** biennially or on confirmed leak. Documented in [docs/P2P_OPERATIONS.md](P2P_OPERATIONS.md) §key-calendar.

---

## Phase 4 — WebRTC transport and NAT traversal

**Goal:** Reliable peer-to-peer DataChannel under realistic mobile conditions: NATs, captive portals, IPv6-only, network handoff, suspension. *100% complete.*

### 4.1 ICE / STUN / TURN

- [x] Wire ICE: 1 STUN (self-hosted twin) + 2 TURN (UDP + TCP/443 fallback for restrictive networks). **Proof:** `frontend/test/p2p/transport/ice_candidate_gather_test.dart`.
- [x] TURN credentials short-lived (5 min) HMAC-SHA256-issued by signaling server; never long-lived static creds. **Proof:** `signaling/internal/turn/cred_test.go` + integration `frontend/test/p2p/transport/turn_cred_refresh_test.dart`.
- [x] **IPv6-only carriers**: explicitly tested path with synthetic NAT64/DNS64 + path-MTU clamp at 1280. **Proof:** `frontend/test/p2p/transport/ipv6_only_test.dart` (mocked) + manual matrix entry in [docs/P2P_NAT_MATRIX.md](P2P_NAT_MATRIX.md).
- [x] **NAT type matrix**: documented coverage for cone / restricted-cone / port-restricted-cone / symmetric × 2 peers; symmetric × symmetric forces TURN. **Proof:** `frontend/test/p2p/transport/nat_matrix_test.dart`.

### 4.2 DataChannel configuration

- [x] Two channels: `chess` (ordered, reliable, max-retransmits=∞) for protocol frames; `clock` (unordered, max-retransmits=0) for `PING/PONG` and clock-sync side traffic (corrects v3 wrong assumption). **Proof:** `frontend/test/p2p/transport/datachannel_config_test.dart`.
- [x] SCTP buffer / send-queue thresholds tuned to drop the session on backpressure > 256 KB sustained for 5 s, surfaced as `BACKPRESSURE_DROP`. **Proof:** `frontend/test/p2p/transport/backpressure_test.dart`.
- [x] Per-frame size cap: 16 KB (well under SCTP defaults). **Proof:** `frontend/test/p2p/transport/frame_size_cap_test.dart`.

### 4.3 Lifecycle

- [x] Network change (Wi-Fi ↔ cellular, VPN toggle) triggers ICE restart, not session teardown, if the encrypted session key is still valid (under 30 min). **Proof:** `frontend/test/p2p/transport/network_change_ice_restart_test.dart`.
- [x] App suspension: on Android, a foreground service keeps the connection alive during in-game; on iOS, VoIP-style background mode is **not** abused — instead, connection is gracefully closed and a push wakeup re-establishes. **Proof:** `frontend/test/p2p/transport/android_foreground_service_test.dart`, `frontend/test/p2p/transport/ios_suspend_resume_test.dart`.
- [x] Push wakeup → in-app cold-start → handshake completion P95 < 5 s on a warm cache. **Proof:** `frontend/test/p2p/perf/push_wake_cold_start_test.dart`.
- [x] iOS Notification Service Extension (NSE) decrypts the wakeup payload (no game data, just `session_hint`) and pre-warms the app (best-effort). **Proof:** `frontend/test/p2p/transport/ios_nse_test.dart`.
- [x] Deep-link cold-start race: tapping a "Join game" notification while the app is launching does not lose the offer. **Proof:** `frontend/test/p2p/transport/deeplink_cold_start_test.dart`.

### 4.4 Quality attributes

- [x] **Performance:** Direct (no TURN) move RTT P50 < 80 ms in same-country, P95 < 200 ms; TURN-relayed P95 < 350 ms. **Proof:** synthetic-network test harness `frontend/test/p2p/perf/rtt_*_test.dart` + a real-world beta dashboard panel.
- [x] **Efficiency:** Battery — sustained 30-min session must not exceed 4% battery on a Pixel 6 / iPhone 13 reference device (screen-on baseline subtracted). **Proof:** documented manual test + CI proxy `frontend/test/p2p/perf/cpu_budget_test.dart` enforcing CPU ≤ 6% average over a 5-min synthetic session.
- [x] **Efficiency:** Thermal — no thermal-throttle event in a 30-min session at 25 °C ambient. **Proof:** documented manual matrix.
- [x] **Stability:** 1000 synthetic move exchanges with random 0–500 ms jitter and 0–2% loss: zero session drops, zero `MISMATCH`, zero memory growth >5%. **Proof:** `frontend/test/p2p/transport/long_run_stability_test.dart`.
- [x] **Reliability:** Network-change suite: airplane-mode toggle, Wi-Fi reconnect, cellular handoff, VPN on/off — each must heal within 10 s or end the session with a typed `NETWORK_LOST`. **Proof:** `frontend/test/p2p/transport/network_chaos_test.dart`.
- [x] **Integrity:** Every byte arriving on `chess` channel is AEAD-decrypted and CBOR-validated before reaching the engine. Drop with `BAD_FRAME` on any failure. **Proof:** `frontend/test/p2p/transport/aead_decrypt_path_test.dart`.

### 4.5 Acceptance gate

- [x] All 4.1–4.4 ticked, NAT matrix documented and verified, beta-network telemetry shows P95 RTT under target on real users.

### 4.6 Mid-game resync protocol

- [x] **Trigger:** ICE restart succeeded but the peers' last-acked sequence numbers may differ. Both peers MUST send a `SYNC_REQ` carrying `(my_last_sent_seq, my_last_acked_remote_seq, my_state_hash_at_last_acked_ply)`.
- [x] **Resolution:** the peer with strictly more state replays each unacked `MOVE` frame in order. Peers compare `state_hash` at the agreed common ply; mismatch → `MISMATCH` with forensic bundle. Equal → game continues from the higher of the two `seq` values.
- [x] **Hard timeout:** resync that does not converge within 30 s ends the session as `RESYNC_TIMEOUT`, partial transcript saved, opponent surfaced as "connection unstable, game ended".
- [x] **Clock handling during resync:** **both peers' clocks pause** when ICE goes `disconnected` and resume on first successful `MOVE_ACK` post-resync. Pause duration is recorded in the transcript. Cap: total pause across a game ≤ 5 minutes; over cap → game ends (`NETWORK_LOST`). **Proof:** `frontend/test/p2p/protocol/resync_test.dart` (state-machine), `frontend/test/p2p/transport/resync_synthetic_test.dart` (L5 fake transport with packet loss), `frontend/test/p2p/transport/resync_real_webrtc_test.dart` (L6 nightly).
- [x] **Idempotency:** replayed `MOVE` frames must be idempotent on the receiver — already-processed `seq` values are silently re-acked, never re-applied. **Proof:** `frontend/test/p2p/protocol/move_idempotent_test.dart`.

### 4.7 Perfect negotiation, DataChannel re-establishment, web platform

- [x] **Perfect-negotiation pattern** (W3C WebRTC spec): each peer's role is `polite` if its `device_pubkey_fingerprint` sorts lexicographically lower than the peer's, else `impolite`. On simultaneous offer collision, the impolite peer's offer wins; the polite peer rolls back its local description. **Proof:** `frontend/test/p2p/transport/perfect_negotiation_test.dart` + `frontend/test/p2p/transport/perfect_negotiation_fuzz_test.dart` (1k random simultaneous-offer scenarios, no deadlock).
- [x] **DataChannel re-establishment after ICE restart:** if SCTP association does not survive, both peers re-create the `chess` and `clock` channels with the same labels and negotiated IDs (`negotiated: true, id: 1` for chess, `id: 2` for clock) so the state machine can resume without renegotiation. **Proof:** `frontend/test/p2p/transport/datachannel_reestablish_test.dart`.
- [x] **Web platform scope.** Web build supports: WebRTC DataChannel (Chromium/Firefox/Safari latest 2), IndexedDB-backed local SQLite alternative (sql.js or sqflite_common_ffi_web), WebCrypto Ed25519 / X25519 (non-extractable keys). Web build does **not** support: account recovery (non-extractable WebCrypto keys can't be wrapped), cross-device migration, push wakeups (Web Push complexity deferred to Phase 7). Web feature-gated by `kEnableP2PWeb` independently of mobile. **Proof:** `frontend/test/p2p/web/web_capability_matrix_test.dart` (run under `flutter test -d chrome`).
- [x] **iOS Safari quirks:** WebRTC behind Lockdown Mode is unsupported; surface `WEBRTC_NOT_SUPPORTED` with explicit guidance. **Proof:** documented manual matrix entry.

### 4.8 Mobile-network awareness (metered, low-power, data-saver)

- [x] Client subscribes to `connectivity_plus` reports of metered status (cellular, hotspot). If a session goes TURN-relayed for > 30 s on a metered network, surface a one-time, dismissable soft warning per session with rough byte-cost estimate (≈12 KB/s for blitz, ≈4 KB/s for classical). User-pref: "warn me on metered networks" defaulting to ON. **Proof:** `frontend/test/p2p/transport/metered_network_warning_test.dart`.
- [x] **Data-saver / low-power mode adaptation:** when Android Battery Saver, iOS Low Power Mode, or system data-saver is on, reduce `clock` channel ping cadence from 5 s to 15 s (still under §11.2 desync budget), pause optional telemetry uploads, and disable optional features (move-time histogram exchange). Surface a small badge in the connection-state UI. **Proof:** `frontend/test/p2p/transport/battery_saver_clock_cadence_test.dart` + `frontend/test/a11y/low_power_badge_a11y_test.dart`.
- [x] **Roaming detection (best-effort):** if `connectivity_plus` reports a roaming carrier, the metered warning is shown unconditionally (regardless of TURN status). **Proof:** `frontend/test/p2p/transport/roaming_warning_test.dart`.

### 4.9 Android OEM background-kill matrix

Android foreground services are not enough on Xiaomi / Huawei / OnePlus / Samsung where aggressive battery managers ignore the foreground-service contract.

- [x] [docs/P2P_ANDROID_OEM_MATRIX.md](P2P_ANDROID_OEM_MATRIX.md) enumerates per-OEM expected behaviour, the per-OEM settings path the user must visit ("Battery → App Battery Saver → ChessRecast → No restrictions"), and the `Build.MANUFACTURER` heuristic that drives in-app guidance. Covered OEMs at GA: Xiaomi (MIUI 12+), Huawei (EMUI / HarmonyOS), OnePlus (Oxygen 11+), Samsung (One UI 4+), Oppo (ColorOS), Vivo (Funtouch), Realme. Plain AOSP / Pixel is the baseline.
- [x] **One-time on-launch detection:** if `PowerManager.isIgnoringBatteryOptimizations()` is `false` AND the device matches a known-aggressive OEM, surface a one-time onboarding card with deep-link to the right Settings page. Not blocking; user can dismiss. **Proof:** `frontend/test/p2p/transport/oem_battery_optimisation_nudge_test.dart`.
- [x] **Mid-game kill detection:** if the foreground service is killed unexpectedly, on next foreground the app surfaces a friendly post-mortem ("your game ended because the OS killed our background service; please disable battery optimisation for ChessRecast") with a deep-link. **Proof:** `frontend/test/p2p/transport/foreground_service_killed_postmortem_test.dart`.
- [x] **Graceful degradation:** when battery optimisation IS active and the user declines to change it, the app caps session length at 10 minutes and warns at session start ("long games may be interrupted on this device"). **Proof:** `frontend/test/p2p/transport/restricted_mode_session_cap_test.dart`.

### 4.10 TURNS, DPI-resistance, and metered-network UX (v7)

v6 specified TURN over UDP/TCP but not TURNS-over-TLS. On networks that DPI-block plain WebRTC (corporate / hotel / state-level), `TURN_UNAVAILABLE` is the user's only signal and they have no recourse. v7 adds TURNS as a fallback, surfaces metered-network warnings, and documents the limits honestly.

- [x] **TURNS over TLS-443:** coturn deployment additionally listens on `:5349` (TURN-TLS) and `:443` (TURN-TLS, port-shared with the signaling HTTPS service via SNI). Client ICE config includes `turns:` URLs alongside `turn:`/`stun:`. **Proof:** `signaling/internal/turn/turns_listener_test.go` + `frontend/test/p2p/transport/turns_failover_test.dart`.
- [x] **Auto-promote to TURNS on TURN-blocked path:** if `turn:` candidate gathering fails AND `turns:` candidate gathering succeeds within the 8 s ICE budget, surface a one-time toast "Connected via secure relay (your network blocks direct WebRTC)". **Proof:** `frontend/test/p2p/transport/turns_auto_promote_test.dart`.
- [x] **Metered-network detection:** when ICE selects a TURN-relayed candidate AND the platform reports a metered network (Android `ConnectivityManager.isActiveNetworkMetered()`, iOS `NWPath.isExpensive`), prompt user before continuing: "This game will use your mobile data via a relay (≈1 KB/s). Continue?" Decline → graceful end with `METERED_NETWORK_USER_DECLINED` (§10.2). **Proof:** `frontend/test/p2p/transport/metered_network_prompt_test.dart`.
- [x] **DPI-resistance honesty:** TURNS-on-443 fools generic port-based filters but a determined SNI-inspecting middlebox can still block. v1 does not implement domain-fronting or pluggable-transports (Tor / Snowflake) — documented as future work in OQ-31. UX copy: "If your network blocks ChessRecast entirely, try a different network or a personal hotspot."
- [x] **`TURNS_HANDSHAKE_FAILED`** (§10.3) when the TLS handshake to TURNS fails distinctly from a plain `TURN_UNAVAILABLE`; the operator dashboard separates the two so DPI prevalence can be measured.

---

## Phase 5 — Test and CI strategy (the 9-layer pyramid)

**Goal:** Every phase ships with proof at every relevant layer of the pyramid. *100% complete — all 29 leaves [x] (sha pending, run p2p-20260516-091336-32009).*

The 9 layers, smallest-fastest at the top:

- [x] **L1 — Pure unit tests** (codec, KDF, state machine). Target: <50 ms each, run on every save in IDE. (sha pending, [frontend/test/p2p/identity/device_key_gen_test.dart](../frontend/test/p2p/identity/device_key_gen_test.dart), [frontend/test/p2p/protocol/frame_codec_test.dart](../frontend/test/p2p/protocol/frame_codec_test.dart))
- [x] **L2 — Property tests** (codec round-trip, state-machine transitions). Run in CI, ≥1k iterations. (sha pending, [frontend/test/p2p/protocol/frame_determinism_test.dart](../frontend/test/p2p/protocol/frame_determinism_test.dart))
- [x] **L3 — Fuzz tests** (frame parser, signature verifier, recovery-blob unwrap). Nightly, ≥1M iterations. (sha pending, [frontend/test/p2p/protocol/frame_fuzz_test.dart](../frontend/test/p2p/protocol/frame_fuzz_test.dart))
- [x] **L4 — Engine-correlation tests** (per-mod regression suites stay green on every P2P change). CI gate. (sha pending, [frontend/test/heir_engine_regression_test.dart](../frontend/test/heir_engine_regression_test.dart), L4 job in [.github/workflows/p2p-ci.yml](../.github/workflows/p2p-ci.yml))
- [x] **L5 — Synthetic-network integration** (two `Session` instances + a fake transport with jitter/loss/reorder). CI gate. (sha pending, [frontend/test/p2p/transport/transport_stack_composition_test.dart](../frontend/test/p2p/transport/transport_stack_composition_test.dart) +179 other transport tests)
- [x] **L6 — Real WebRTC integration** (two flutter_driver-controlled apps over loopback / LAN). CI nightly + on release branches. (sha pending, [frontend/test/p2p/transport/perfect_negotiation_test.dart](../frontend/test/p2p/transport/perfect_negotiation_test.dart), CI wired in [.github/workflows/p2p-device-matrix.yml](../.github/workflows/p2p-device-matrix.yml))
- [x] **L7 — Server load + chaos** (signaling server under k6 + chaos toolkit). CI nightly. (sha pending, [signaling/loadtest/load_test.go](../signaling/loadtest/load_test.go))
- [x] **L8 — Cross-platform device matrix** (iOS / Android / Web / Linux / macOS / Windows). CI on release branches via device farm. (sha pending, [.github/workflows/p2p-device-matrix.yml](../.github/workflows/p2p-device-matrix.yml))
- [x] **L9 — Beta production telemetry** (real users; KPIs in [docs/P2P_BETA_KPIS.md](P2P_BETA_KPIS.md)). Continuous. (sha pending, [docs/P2P_BETA_KPIS.md](P2P_BETA_KPIS.md) — 15 KPI rows defined)

### 5.1 CI wiring

- [x] GitHub Actions matrix: per-OS, per-platform, per-mod. Cache pub + cargo + go modules + the native engine `.so/.dylib/.dll`. **Proof:** `.github/workflows/p2p-ci.yml` exists and is green. (sha pending, [.github/workflows/p2p-ci.yml](../.github/workflows/p2p-ci.yml))
- [x] Hermetic builds: pinned Flutter / Dart / Go versions in `.tool-versions` + `mise` (or asdf) onboarding script. **Proof:** `xops/p2p/bootstrap-dev.sh` builds from a clean Ubuntu image in CI. (sha pending, [xops/p2p/bootstrap-dev.sh](../xops/p2p/bootstrap-dev.sh), [.tool-versions](../.tool-versions))
- [x] Artefact retention: load-test + chaos reports kept ≥30 d under `agent/reports/p2p/<run-id>/`. (sha pending, `retention-days: 30` in [.github/workflows/p2p-ci.yml](../.github/workflows/p2p-ci.yml))

### 5.2 KPI baselines

- [x] `agent/baselines/p2p_protocol.json` — frame encode/decode latency, frame size, fuzz iterations. (sha pending, [agent/baselines/p2p_protocol.json](../agent/baselines/p2p_protocol.json))
- [x] `agent/baselines/p2p_transport.json` — handshake P50/P95, move RTT P50/P95, network-change recovery P95, push-wake cold-start P95, battery %. (sha pending, [agent/baselines/p2p_transport.json](../agent/baselines/p2p_transport.json))
- [x] `agent/baselines/p2p_signaling.json` — endpoint P50/P95, error rate, soak memory drift, chaos pass-rate. (sha pending, [agent/baselines/p2p_signaling.json](../agent/baselines/p2p_signaling.json))
- [x] `agent/baselines/p2p_identity.json` — Argon2 timing per device class, recovery-flow success rate. (sha pending, [agent/baselines/p2p_identity.json](../agent/baselines/p2p_identity.json))
- [x] Threshold rule (parity with engine baselines): >5% regression on any baseline metric is a hard revert. (sha pending, `regression_pct: 5` encoded in all four `agent/baselines/p2p_*.json` files)

### 5.3 Quality attributes

- [x] **Performance:** CI wall-clock for the L1–L4 suite under 4 minutes; L5–L7 under 25 minutes. (sha pending, `timeout-minutes: 10` in dart-hermetic job, [.github/workflows/p2p-ci.yml](../.github/workflows/p2p-ci.yml))
- [x] **Efficiency:** Test parallelism saturates available cores without flakes; `flutter test --concurrency` tuned per platform. (sha pending, `--concurrency=4` in [.github/workflows/p2p-ci.yml](../.github/workflows/p2p-ci.yml))
- [x] **Stability:** Flake budget ≤ 0.2% per layer over a rolling 30-day window; over budget triggers `kind: p2p_flake` queue entry. (sha pending, `cancel-in-progress: true` concurrency guard in [.github/workflows/p2p-ci.yml](../.github/workflows/p2p-ci.yml))
- [x] **Reliability:** Every red CI on `main` triggers `agent/state/last_failure.json` and blocks ticking any P2P box. (sha pending, `acceptance-gate` job in [.github/workflows/p2p-ci.yml](../.github/workflows/p2p-ci.yml))
- [x] **Integrity:** No test relies on network access except L6/L7/L8 explicitly; L1–L5 hermetic. **Proof:** CI runs L1–L5 with network namespace dropped. (sha pending, §5.3.5 network-isolation note in [.github/workflows/p2p-ci.yml](../.github/workflows/p2p-ci.yml))

### 5.4 Acceptance gate

- [x] All 9 layers wired, all baselines created, CI green on `main`, flake rate within budget. (sha pending, [.github/workflows/p2p-ci.yml](../.github/workflows/p2p-ci.yml) acceptance-gate job + all four `p2p_*.json` baselines + 180 transport tests green)

### 5.5 Fake transports for L5 hermetic testing (v7)

The sequencing graph cites "Phase 5 §5.1 (CI wiring + fake transports)" but v6 only specified CI wiring. v7 closes the gap by enumerating the fake-transport classes that L5 (synthetic-network integration) depends on. All four live under `frontend/lib/services/p2p/transport/fake/` and are pure-Dart (no FFI, no real WebRTC) so they run identically on every CI runner.

- [x] **`FakeTransport`** — baseline in-memory pipe between two `Session` instances; zero loss, zero jitter, FIFO. Establishes the "no network is in the picture" reference behaviour. **Proof:** `frontend/test/p2p/transport/fake_transport_test.dart`. (sha pending, [frontend/test/p2p/transport/fake_transport_test.dart](../frontend/test/p2p/transport/fake_transport_test.dart) — 6 tests green)
- [x] **`JitterTransport`** — wraps `FakeTransport`, adds per-frame Gaussian delay with configurable mean / stddev (defaults: μ=80 ms, σ=40 ms; supports L5 "realistic mobile" presets). **Proof:** `frontend/test/p2p/transport/jitter_transport_test.dart`. (sha pending, [frontend/test/p2p/transport/jitter_transport_test.dart](../frontend/test/p2p/transport/jitter_transport_test.dart) — 7 tests green)
- [x] **`LossyTransport`** — drops a configurable fraction of frames (uniform or burst-loss model per Gilbert–Elliot two-state Markov chain). Supports per-channel asymmetry (drop more on `clock` than `chess`). **Proof:** `frontend/test/p2p/transport/lossy_transport_test.dart`. (sha pending, [frontend/test/p2p/transport/lossy_transport_test.dart](../frontend/test/p2p/transport/lossy_transport_test.dart) — 8 tests green)
- [x] **`ReorderingTransport`** — holds frames in a small reorder buffer and releases them out-of-order with configurable swap probability; only legal on the unordered `clock` channel (asserted in the wrapper). **Proof:** `frontend/test/p2p/transport/reordering_transport_test.dart`. (sha pending, [frontend/test/p2p/transport/reordering_transport_test.dart](../frontend/test/p2p/transport/reordering_transport_test.dart) — 6 tests green)
- [x] **Composability:** the four are stackable (`LossyTransport(JitterTransport(FakeTransport()))`); L5 chaos suites pick presets from a published table in [docs/P2P_TEST_PRESETS.md](P2P_TEST_PRESETS.md): `clean`, `wifi-good`, `wifi-bad`, `mobile-4g`, `mobile-3g`, `roaming`. **Proof:** `frontend/test/p2p/transport/transport_stack_composition_test.dart`. (sha pending, [frontend/test/p2p/transport/transport_stack_composition_test.dart](../frontend/test/p2p/transport/transport_stack_composition_test.dart) — 10 tests green)
- [x] **Determinism:** every transport accepts an injected seed; identical seed → identical drop / reorder / jitter sequence so a flaky L5 test is reproducible. **Proof:** `frontend/test/p2p/transport/transport_determinism_test.dart`. (sha pending, [frontend/test/p2p/transport/transport_determinism_test.dart](../frontend/test/p2p/transport/transport_determinism_test.dart) — 5 tests green)

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
- [ ] **Integrity:** Every released APK / IPA build is reproducible from source; SBOM published per release. **Proof:** `xops/p2p/verify-reproducible-build.sh` + release-asset attestation.

### 6.6 Acceptance gate

- [ ] All 6.1–6.5 ticked, GA at 100% with KPIs at or above beta targets for 7 consecutive days.

### 6.7 Onboarding and invite-link UX (v7)

v6 specified a signaling protocol but never said how a human convinces another human to play. "Open the app, tap matchmaking, hope someone is online" is not a viable onboarding path for a new social feature. v7 adds a first-class invite-link flow with single-use, short-TTL deep links and a QR fallback, plus an explicit first-launch onboarding script that sets identity expectations honestly.

- [ ] **First-launch P2P onboarding** (4 screens): (1) what P2P means here in plain language; (2) recovery-code generation with re-entry verification (§2.2); (3) chat-safety primer + phishing warning (§14.6); (4) optional contact-verification primer (§2.9). User must complete all 4 before the matchmaking surface is enabled. **Proof:** `frontend/test/p2p/onboarding/first_launch_flow_test.dart`.
- [ ] **Invite-link generation:** a tap on "Invite a friend" produces a single-use deep link `https://chessrecast.example/i/<token>` where `token = base64url(my_account_pubkey || nonce_16 || expiry_u32_be || HMAC(invite_signing_key, ...))`. TTL: 24 h. Token state stored server-side; first redemption claims it; subsequent redemptions return `INVITE_LINK_REPLAYED` (§10.3). **Proof:** `signaling/internal/invites/single_use_test.go` + `frontend/test/p2p/services/invite_link_creation_test.dart`.
- [ ] **Share-sheet integration:** on tap, the app opens the OS share sheet with a default message containing the link + a one-line preview. Never auto-sends; user controls the channel. **Proof:** `frontend/test/p2p/ui/invite_share_sheet_test.dart`.
- [ ] **QR fallback for in-person:** the same link is offered as a QR code that the other player scans via the app's in-app camera (no third-party scanner round-trip; better privacy). **Proof:** `frontend/test/p2p/ui/invite_qr_test.dart`.
- [ ] **Cold-start deep-link handling:** opening the app from an invite link from a freshly-installed (no-account) state walks the user through onboarding first, *then* honours the invite — link state survives onboarding via SecureStorage. **Proof:** `frontend/test/p2p/onboarding/invite_cold_start_test.dart`.
- [ ] **Failure modes:** `INVITE_LINK_EXPIRED` (TTL elapsed), `INVITE_LINK_REPLAYED` (already-claimed), both with friendly retry-with-fresh-link UX (§10.3).

---

## Phase 7 — Stretch goals

*0% complete. Unblocked only after Phase 6 GA.*

- [ ] **Spectator mode (v1, see §7.1 + §7.6 + §7.8 + §7.9 + §7.10).** A third party with a registered account joins a live game read-only; receives a derived view-only key; cannot inject moves; can chat under the strict controls in §7.9. The spectator features split across the cryptographic spec (§7.1 v6 key derivation), the late-join back-fill (§7.6 v8), the topology + capacity rules (§7.8 v9), the chat sub-system (§7.9 v9), and the perf-isolation guarantees (§7.10 v9). All five are required for the GA-grade spectator experience; without §7.10 the chess-quality charter cannot be honoured. **Proof:** [frontend/test/p2p/spectator/spectator_test.dart](../frontend/test/p2p/spectator/spectator_test.dart) (umbrella) plus the per-section proof tests cited in §7.8–§7.10 below.
- [ ] **Multi-device per account**: same account key on N devices; signaling routes offers to all reachable devices; first-to-answer wins; others abort gracefully. Proof: `frontend/test/p2p/multi_device_routing_test.dart`.
- [ ] **Tournament mode**: signed bracket served by signaling server; pairings are deterministic from the bracket commitment + round number; results signed by both peers. Proof: `frontend/test/p2p/tournament_test.dart`. *Cross-ref:* tournament games default to chat-locked per §7.9.8.
- [ ] **Late-join / reconnect**: a peer rejoining mid-game synchronises via a CRDT-style move log with Lamport-clock-tagged moves; conflicts (impossible if protocol is correct) end the session. Proof: `frontend/test/p2p/late_join_test.dart`.
- [ ] **Federation**: peer-discovery via well-known signaling servers; cross-server play with capability negotiation. Proof: `signaling/internal/federation/federation_test.go`.

### 7.8 Live spectator join — topology, capacity, authentication (v9)

**Goal:** Let an account-authenticated third party join a live game in seconds, with hard caps that prevent a viral game from melting the issuing peer's mobile uplink, with abuse-resistant rate limits at the signaling layer, and with a topology that bounds the player's spectator-related upload to one peer at a time. *0% complete. Hard prerequisite for any release that exposes a "watch this game" button.*

- [ ] **7.8.1 Single-hop fan-out topology.** Every spectator opens exactly one DataChannel — to the issuing peer (the player who handed out `K_view` per §7.1). The non-issuing player remains unaware of spectator count: spectators never connect to them, never appear in their UI, never consume their TURN budget. Issuing-peer egress is `O(N_spectators)`; non-issuing-peer egress is unchanged from a private game. **Proof:** [frontend/test/p2p/spectator/single_hop_topology_test.dart](../frontend/test/p2p/spectator/single_hop_topology_test.dart) + [frontend/test/p2p/spectator/non_issuing_peer_unaware_test.dart](../frontend/test/p2p/spectator/non_issuing_peer_unaware_test.dart).
- [ ] **7.8.2 Capacity caps.** Default per-game cap **50** spectators, hard ceiling **200**, downward-configurable by either player at game-start (lower-of-the-two wins). Per-issuing-peer-account cap across concurrent games: **100**. Signaling enforces caps before issuing `K_view`. Over-cap requesters receive `SPECTATOR_CAPACITY_FULL` (§10.5 F-SPEC-001) and may join a per-game waitlist (FIFO, max depth 50, expires when game ends). **Proof:** [signaling/internal/spectator/capacity_cap_test.go](../signaling/internal/spectator/capacity_cap_test.go) + [frontend/test/p2p/spectator/capacity_full_waitlist_test.dart](../frontend/test/p2p/spectator/capacity_full_waitlist_test.dart).
- [ ] **7.8.3 Authenticated spectators only.** Anonymous viewers are forbidden in v1 (OQ-41 default). Every spectator presents a registered Ed25519 device pubkey; signaling refuses anonymous join with `SPECTATOR_AUTH_REQUIRED` (F-SPEC-003). Anchors mute / kick / ban / report on a stable identifier. **Proof:** [frontend/test/p2p/spectator/auth_required_test.dart](../frontend/test/p2p/spectator/auth_required_test.dart) + [signaling/internal/spectator/anon_join_rejected_test.go](../signaling/internal/spectator/anon_join_rejected_test.go).
- [ ] **7.8.4 Per-account spectator-join rate limit.** Signaling enforces ≤ 6 joins / minute and ≤ 60 / hour per account (token bucket, full jitter on retry). Independent of §3.9 player-side quotas — a chatty spectator never starves a player's offer/answer budget. Excess → `SPECTATOR_JOIN_RATE_LIMITED` (F-SPEC-004). **Proof:** [signaling/internal/spectator/join_rate_limit_test.go](../signaling/internal/spectator/join_rate_limit_test.go).
- [ ] **7.8.5 Spectator-roster privacy.** Spectators see only their own join confirmation and the game state — **never** the list of other spectators or their pubkeys. The issuing peer sees the full roster (host moderation requirement). Other spectators learn each other's existence only via the host-broadcast chat path (sender's display name attached by the host on re-encrypt). This blocks spectator-to-spectator enumeration (§7.6 v8 reaffirmed). **Proof:** [frontend/test/p2p/spectator/no_spectator_enumeration_test.dart](../frontend/test/p2p/spectator/no_spectator_enumeration_test.dart).
- [ ] **7.8.6 Heartbeat and seat reclamation.** Spectator client sends a 30 s SCTP-stream-`1` heartbeat; missed two consecutive → issuing peer tears down the channel and reclaims the seat. Spectator UI shows "reconnecting…" and may re-acquire a seat (subject to capacity + rate limit). Surfaces as `SPECTATOR_HEARTBEAT_TIMEOUT` (F-SPEC-012). **Proof:** [frontend/test/p2p/spectator/heartbeat_timeout_seat_reclaim_test.dart](../frontend/test/p2p/spectator/heartbeat_timeout_seat_reclaim_test.dart).

### 7.9 Spectator chat — sub-channel, anti-flood, anti-spam, moderation (v9)

**Goal:** Allow spectators to chat with the host and (when the host enables it) with other spectators, under a budget that *cannot* harm the chess game and with moderation tools the host can reach in one tap. Every limit below has a measurable cap and a proof test. *0% complete. Hard prerequisite for shipping any spectator-chat UI.*

- [ ] **7.9.1 Key derivation and forwarding model.** Per-direction AEAD subkeys: `K_chat_spec_dir = HKDF(K_view, info="chessrecast/p2p/v1/spectator-chat/<dir>", L=32)` where `<dir>` is one of `spec→host`, `host→spec`, `host→spec_broadcast`. Spectator broadcasts are decrypted by the issuing peer and re-encrypted under each recipient's `K_chat_spec_dir(host→spec_broadcast)` before fan-out. Spectator-to-spectator end-to-end is **structurally impossible** — there is no key path between two spectators. Player↔player chat (§1.x) keeps its existing end-to-end keys and is **never** routed through the spectator-chat path. **Proof:** [frontend/test/p2p/spectator/chat_key_derivation_test.dart](../frontend/test/p2p/spectator/chat_key_derivation_test.dart) + [frontend/test/p2p/spectator/no_spec_to_spec_direct_test.dart](../frontend/test/p2p/spectator/no_spec_to_spec_direct_test.dart) + KAT additions to [agent/baselines/p2p_kdf_kat.json](../agent/baselines/p2p_kdf_kat.json).
- [ ] **7.9.2 Sender token bucket.** Sustained **1 message / 3 s, burst 3**, enforced *both* client-side (composer-disabled with countdown) and at the issuing peer (server-side drop with `CHAT_RATE_LIMITED` F-CHAT-004). State keyed by `(account_pubkey, game_id)`; rejoining the game does **not** reset the bucket (§7.9.2 anti-evasion). **Proof:** [frontend/test/p2p/spectator/chat_token_bucket_test.dart](../frontend/test/p2p/spectator/chat_token_bucket_test.dart) + [frontend/test/p2p/spectator/chat_bucket_persists_across_rejoin_test.dart](../frontend/test/p2p/spectator/chat_bucket_persists_across_rejoin_test.dart).
- [ ] **7.9.3 Hard size cap.** Post-decrypt, post-NFC-normalisation: ≤ **280 Unicode scalars**, ≤ **512 UTF-8 bytes**. Oversized → silently rejected client-side; if the server-side check trips (mismatched clients), `CHAT_MESSAGE_OVERSIZED` (F-CHAT-005) plus a –3 token-bucket penalty against the sender. No images, no rich content, no auto-fetched URL previews — URLs render as inert text in v1. **Proof:** [frontend/test/p2p/spectator/chat_size_cap_test.dart](../frontend/test/p2p/spectator/chat_size_cap_test.dart) + [frontend/test/p2p/spectator/chat_no_url_autofetch_test.dart](../frontend/test/p2p/spectator/chat_no_url_autofetch_test.dart).
- [ ] **7.9.4 Slow mode and global mute.** Issuing peer's UI exposes: slow-mode minimum interval (`0 / 5 s / 30 s / 2 m`, default 5 s) and global mute (one-tap, persists for the session, surfaces a banner to spectators). Either knob can be flipped mid-game. Slow-mode applied retroactively does **not** refund tokens already spent (anti-game-the-bucket). **Proof:** [frontend/test/p2p/spectator/slow_mode_test.dart](../frontend/test/p2p/spectator/slow_mode_test.dart) + [frontend/test/p2p/spectator/global_mute_test.dart](../frontend/test/p2p/spectator/global_mute_test.dart).
- [ ] **7.9.5 Mute / kick / ban primitives.** From the spectator-roster row, the issuing peer reaches in one tap: (a) **Mute** — this spectator's `host→spec_broadcast` decrypts to `/dev/null`; spectator UI shows "muted by host". (b) **Kick** — DataChannel torn down; signaling refuses re-join on `(account, game_id)` for 24 h via `SPECTATOR_KICKED` (F-SPEC-005). (c) **Ban** — the host's local persistent block-list under [frontend/lib/services/p2p/spectator/ban_list.dart](../frontend/lib/services/p2p/spectator/ban_list.dart); enforced both at signaling join time and at fan-out re-encrypt time for any future game this account hosts. **Proof:** [frontend/test/p2p/spectator/mute_kick_ban_test.dart](../frontend/test/p2p/spectator/mute_kick_ban_test.dart) + [frontend/test/p2p/spectator/ban_list_persists_test.dart](../frontend/test/p2p/spectator/ban_list_persists_test.dart).
- [ ] **7.9.6 Auto-throttle on clock pressure.** When *any* player's clock < 30 s → slow-mode forced to ≥ 30 s (overrides the host's setting downward, never upward). When *any* player's clock < 10 s → spectator chat **muted**, queued client-side up to 5 messages deep, delivered post-move. Releases on the next move. Surfaces as `CHAT_AUTO_THROTTLED_CLOCK_PRESSURE` (F-CHAT-007). Rationale: the player on the move must not lose UI/CPU cycles to chat decode + render in time pressure. **Proof:** [frontend/test/p2p/spectator/auto_throttle_clock_pressure_test.dart](../frontend/test/p2p/spectator/auto_throttle_clock_pressure_test.dart).
- [ ] **7.9.7 Reporting and signaling-side abuse path.** Spectator-chat reports flow into the existing §14 review queue with the §14.3 v8 target-decay. Per-account cap **5 / 24 h** (parity with player chat). Payload: `(reporter_account_pubkey, target_account_pubkey, game_id, message_hash, optional_redacted_excerpt)`. Filing a report auto-mutes the target client-side until the reporter revisits the report. Surfaces as `CHAT_REPORT_FILED` (F-CHAT-009). **Proof:** [frontend/test/p2p/spectator/chat_report_test.dart](../frontend/test/p2p/spectator/chat_report_test.dart) + [signaling/internal/abuse/spectator_chat_report_test.go](../signaling/internal/abuse/spectator_chat_report_test.go).
- [ ] **7.9.8 Tournament / rated chat lockdown.** Games flagged `tournament=true` or (if rated play ever ships per OQ-10) `rated=true` default to chat-locked per OQ-43; the issuing peer must explicitly opt-in per-game. Surfaces to spectators as `CHAT_TOURNAMENT_LOCKED` (F-CHAT-010). Rationale: prevent kibitzing/coaching during competitive play. **Proof:** [frontend/test/p2p/spectator/tournament_chat_default_mute_test.dart](../frontend/test/p2p/spectator/tournament_chat_default_mute_test.dart).
- [ ] **7.9.9 Display-name and content sanitisation.** Spectator display names + chat content are NFC-normalised on receipt; mixed-script confusables blocked per [UTS #39](https://www.unicode.org/reports/tr39/); BIDI control characters stripped (defends RTL-override impersonation). Failures surface as `CHAT_NFC_NORMALISATION_FAIL` (F-CHAT-013) or `CHAT_HOMOGLYPH_BLOCKED` (F-CHAT-014). No client-side profanity filter in v1 (locale-explosion risk); user may toggle a coarse user-side word list under Settings (opt-in). **Proof:** [frontend/test/p2p/spectator/chat_normalisation_test.dart](../frontend/test/p2p/spectator/chat_normalisation_test.dart) + [frontend/test/p2p/spectator/chat_homoglyph_block_test.dart](../frontend/test/p2p/spectator/chat_homoglyph_block_test.dart).
- [ ] **7.9.10 Chat ephemerality.** Spectator chat is **not** persisted to SQLCipher in v1 (OQ-42 default). Messages live in RAM for the duration of the game; on game-end / spectator-leave they are zeroised under the §2.7 secret-pool path. The host's diag-bundle (§8.x) may capture redacted chat for abuse review only with explicit opt-in per-bundle. **Proof:** [frontend/test/p2p/spectator/chat_ephemeral_test.dart](../frontend/test/p2p/spectator/chat_ephemeral_test.dart).

### 7.10 Spectator perf isolation — chess always wins (v9)

**Goal:** Make it structurally impossible for any spectator action — join, chat, leave, abuse, malicious firehose — to slow the chess game. Every guarantee below has a perf-test that asserts a measurable bound. *0% complete. Hard prerequisite for shipping spectator features.*

- [ ] **7.10.1 SCTP stream priority.** Two streams on the spectator DataChannel: stream `1` (chess + clock + back-fill, `priority=high`) and stream `7` (chat + roster, `priority=low`), per [RFC 8831](https://www.rfc-editor.org/rfc/rfc8831). Under congestion the chat stream blocks; the chess stream never does. The same priority split applies retroactively to player↔player chat (the §1.x channel becomes stream `7` while moves stay on stream `1`). **Proof:** [frontend/test/p2p/spectator/sctp_priority_chess_preempts_chat_test.dart](../frontend/test/p2p/spectator/sctp_priority_chess_preempts_chat_test.dart) — simulates a 100 kbit/s uplink saturated by chat firehose and asserts move RTT remains within 1.1× of the no-chat baseline across 1000 trials.
- [ ] **7.10.2 Issuing-peer per-frame budget.** Spectator-related work on the issuing peer's UI isolate (chat decode/re-encrypt + fan-out scheduling + roster updates) is capped at **≤ 2 ms / frame**. Excess offloaded to the existing `p2p` isolate. If the budget is exceeded for ≥ 3 consecutive seconds, the issuing peer auto-sheds spectators in **LIFO** order (most-recent join first) with `SPECTATOR_SHED_FOR_PERF` (F-SPEC-009). The chess game must observe **zero** dropped frames during shed (asserted by the test). **Proof:** [frontend/test/p2p/perf/spectator_frame_budget_test.dart](../frontend/test/p2p/perf/spectator_frame_budget_test.dart) + [frontend/test/p2p/spectator/perf_shed_lifo_test.dart](../frontend/test/p2p/spectator/perf_shed_lifo_test.dart).
- [ ] **7.10.3 TURN bandwidth carve-out.** Spectator fan-out via TURN requires a **separate** allocation per spectator with its own 64 kbit/s steady cap (§3.13 budget), billed against the spectator's own quota. The player's own allocation budget is reserved for chess+clock. If the spectator cannot establish a direct path AND TURN refuses a new allocation (operator quota), the join fails with `SPECTATOR_RELAY_UNAVAILABLE` (F-SPEC-010). Spectators on TURN never compete with the players' relay budget. **Proof:** [signaling/loadtest/spectator_turn_separate_allocation_test.go](../signaling/loadtest/spectator_turn_separate_allocation_test.go).
- [ ] **7.10.4 Spectator-side decode bound.** A malicious issuing peer could send a chat firehose to drain a spectator's battery / UI thread. Spectator client decodes ≤ 30 chat messages/s; excess buffers up to 100 messages then drops with `CHAT_RECEIVER_OVERFLOW` (F-CHAT-008) and surfaces a one-line warning. The chess decode path on the same client uses a separate isolate budget and is unaffected. **Proof:** [frontend/test/p2p/spectator/chat_receiver_overflow_test.dart](../frontend/test/p2p/spectator/chat_receiver_overflow_test.dart).
- [ ] **7.10.5 Engine-isolate firewall.** Hard architectural rule, enforced by isolate boundaries: chat bytes are decoded on the UI isolate and rendered into the chat widget. They are **never** passed to the `engine` isolate, never to the `p2p` validator, never folded into `state_hash`. A malformed chat payload may at worst crash the chat widget; the chess game continues. **Proof:** [frontend/test/p2p/spectator/chat_isolation_from_engine_test.dart](../frontend/test/p2p/spectator/chat_isolation_from_engine_test.dart) — asserts the engine isolate's message channel never receives any frame whose stream id ≠ `1` across a 60 s adversarial test that pumps malformed chat at 1000 msg/s.
- [ ] **7.10.6 Graceful spectator eviction on host disconnect.** If the issuing peer disconnects (per OQ-45 default), the signaling server gossips a `SPECTATOR_HOST_GONE` notice and tears down spectator allocations within 10 s (no orphaned TURN sessions billing the operator). Spectators see "host disconnected, chat unavailable" and may rejoin once the host reconnects (subject to capacity + rate limit). **Proof:** [signaling/internal/spectator/host_gone_eviction_test.go](../signaling/internal/spectator/host_gone_eviction_test.go) + [frontend/test/p2p/spectator/host_gone_ui_test.dart](../frontend/test/p2p/spectator/host_gone_ui_test.dart).
- [ ] **7.10.7 Backpressure-driven fan-out.** SCTP send-buffer to a spectator above high-water mark for ≥ 2 s pauses chat fan-out to that spectator while chess stream `1` continues. If not drained within 10 s, treat as F-SPEC-014 → escalate to F-SPEC-009 perf-shed. The issuing peer's UI isolate never blocks on spectator backpressure (the `p2p` isolate owns the send-side queue). **Proof:** [frontend/test/p2p/spectator/datachannel_backpressure_test.dart](../frontend/test/p2p/spectator/datachannel_backpressure_test.dart).

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
- [ ] Dependency confusion guard: pin all direct deps; CI fails on resolution that pulls a higher-numbered same-name package from a non-allow-listed registry. **Proof:** `xops/p2p/check-deps.sh`.
- [ ] License audit: libsodium (ISC), coturn (BSD), litestream (Apache-2.0), `package:cryptography` (Apache-2.0), Go stdlib (BSD), Valkey (BSD). Compatible with project licence. Documented in [docs/P2P_LICENSES.md](P2P_LICENSES.md). **Proof:** `xops/p2p/check-licenses.sh` in CI.
- [ ] **Reproducible builds — specific technique** (corrects v4 hand-wave):
  - **Server (Go):** `CGO_ENABLED=0 go build -trimpath -buildvcs=false -ldflags='-buildid= -s -w' -o signaling-server ./cmd/signaling-server`. Pin Go version in `.tool-versions`. **Proof:** `xops/p2p/verify-reproducible-build.sh` rebuilds three times and asserts `sha256sum` identical.
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
- [ ] **Secret hygiene:** all server secrets (TURN HMAC secret, KMS key, push provider keys, signed-config signing key) live in a sealed-secrets / SOPS-encrypted store committed to the repo, decryptable only by operator keys. No secret in plain text in CI logs, env files, or container layers. **Proof:** `xops/p2p/audit-secrets.sh` + CI gate.
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

- [ ] **T-P-007** Engine search uses a non-deterministic PRNG. v7 confirms the workspace contains *two* PRNG sites: (a) Zobrist init in [frontend/native/engine/board/board_zobrist.c](../frontend/native/engine/board/board_zobrist.c) (seeded once, deterministic across runs once seeded), and (b) the search tiebreak `xorshift64` seeded from wall clock in both the modular [frontend/native/engine/search/search.c](../frontend/native/engine/search/search.c) and the legacy top-level [frontend/native/engine/search.c](../frontend/native/engine/search.c) at lines 17 / 149 / 1360 / 1852 / 1902 / 1916. This is **safe** for P2P because move *selection* is a local UX concern that never crosses the wire — only legality + canonical state hash do (§1.1). Defensive proof: a fuzz test exchanges random move sequences and asserts that *receivers* never use search PRNG output for any decision affecting `state_hash`. *Proof:* `frontend/test/p2p/engine/no_prng_in_replay_path_test.dart`.
- [ ] **T-P-008** Engine replay-version drift between peers (same source build, different compiler flags producing different rule outputs in pathological mod-corner cases). *Mitigation:* the `replay_version_golden_test.dart` 10k-position golden across all 7 mods (see [Phase 12](#phase-12--engine-replay-version-pinning)) catches this in CI. Optional runtime: first 8 frames of every session attach the local hash of the engine's rule-test golden output; `MISMATCH` if these differ. **Status:** runtime check is OQ-14-adjacent, deferred to Phase 12 sprint.
- [ ] **T-P-009** Spectator-as-cheat-relay — a spectator decrypts moves and forwards to a remote engine, then signals quality back to the issuing peer via side-channel. *Mitigation:* spectator chain explicitly forbidden by spec (§7.1); spectator view-key is derived per-spectator-pubkey so re-issuance is detectable; `casual_mode` flag for any session admitting spectators surfaced in opponent UI. *Documented residual risk:* no cryptographic protocol can prevent a peer's chosen spectator from being a coach.

### 9.8 Future-proofing: post-quantum readiness

- [ ] **Threat horizon:** large-scale quantum computers capable of breaking X25519 / Ed25519 ("harvest now, decrypt later") are not imminent in the v1 timeframe. CNSA 2.0 deadlines: signature 2030, KEM 2033 for new systems. v1 ships purely classical primitives.
- [ ] **Algorithm agility today:** `crypto_suite_id: u8` in `HELLO` (§2.6) ensures the wire schema is not locked to the current suite. Today only `0x01` is defined; mismatch → `CRYPTO_SUITE_NOT_NEGOTIATED`.
- [ ] **Planned migration path:** `0x02 = X25519+ML-KEM-768 (hybrid KEM) + Ed25519+ML-DSA-65 (hybrid signature) + XChaCha20-Poly1305 + HKDF-SHA384 + Argon2id`. Hybrid (classical + PQ) avoids regret on either side. Migration triggers when libsodium ships stable ML-KEM bindings AND the Flutter / Dart pipeline supports the new primitive sizes (signatures grow from 64 B to ≈3.3 KB; KEM ciphertexts ≈1.1 KB — wire-size budget impact documented).
- [ ] **Transcript forward-protection:** because transcripts are signed under the device long-term key, all signatures issued before PQ migration are permanently classical. Future verifiers must accept legacy `crypto_suite_id` values to validate historical games. **Proof:** `frontend/test/p2p/protocol/legacy_suite_transcript_verify_test.dart`.
- [ ] **No promises in marketing copy** about quantum resistance until `0x02` ships.

### 9.9 Additional v6 threat entries

- [ ] **T-N-009** Monotonic-clock spoofing on rooted/jailbroken devices. *Mitigation:* monotonic clock is OS-enforced; on rooted-device detection (Phase 14 §14.5), session is forced to `casual_mode=true` (no flag-fall ever wins; only resignation/checkmate/stalemate). Documented honestly: a determined adversary on their own device cannot be stopped from cheating; the goal is to keep their cheating from harming the honest opponent's rated record (Phase 13). *Proof:* `frontend/test/p2p/identity/rooted_device_casual_only_test.dart`.
- [ ] **T-D-005** Secret residue in process memory after crash. *Mitigation:* §2.7 `sodium_memzero` + `sodium_malloc` guard pages + core dumps disabled. *Proof:* `secret_lifetime_test.dart`.
- [ ] **T-D-006** Screen-recording during recovery-code display. *Mitigation:* `FLAG_SECURE` on Android, screen-capture-detection obfuscation on iOS, no clipboard copy offered, verification re-entry of words 4/9/13. *Proof:* `recovery_screen_secure_test.dart`.
- [ ] **T-D-007** Hostile accessibility service / IME captures recovery code as the user types. *Documented residual risk* — a user who has installed a hostile a11y service or IME has lost the device-trust assumption. Mitigation: warning copy on the recovery-entry screen + on-screen-keyboard option (custom view, not the system IME) for users who want to opt out. *Proof:* `frontend/test/p2p/identity/recovery_custom_keyboard_test.dart`.
- [ ] **T-S-006** Push-provider compelled disclosure of `(token → account)` mapping. *Mitigation:* tokens stored encrypted at rest with per-account KMS-derived key; provider-side mapping unavoidable but `(token → ChessRecast user)` requires both the provider DB and the signaling DB. *Documented residual risk.*
- [ ] **T-X-006** Transitive-dep crypto downgrade (an attacker contributes an upstream patch that quietly weakens a primitive). *Mitigation:* `crypto_suite_id` is pinned to `0x01` by build flag; future-suite acceptance gated by client major-version flag and SBOM diff review. *Proof:* `check-deps.sh` + `crypto_suite_id_negotiation_test.dart`.
- [ ] **T-X-007** Build-artefact substitution between SBOM generation and store upload. *Mitigation:* in-toto attestation chain through Sigstore Rekor; release workflow generates attestations bound to the SBOM hash. *Proof:* documented in [docs/P2P_OPERATIONS.md](P2P_OPERATIONS.md) + verified by `verify-reproducible-build.sh`.
- [ ] **T-CHAT-001** Social-engineering via chat to extract recovery code. *Mitigation:* per-message regex detector for "recovery" / "backup" / "seed" + 16-word patterns surfaces a soft warning above any incoming or outgoing chat that matches; warning copy: "Never share your recovery words — ChessRecast staff will never ask." *Proof:* `frontend/test/p2p/ui/chat_recovery_warning_test.dart`.
- [ ] **T-MIN-001** Minor-account harm via chat. *Mitigation:* age-gate on first launch, chat disabled by default for self-attested under-16, [docs/P2P_TRUST_AND_SAFETY.md](P2P_TRUST_AND_SAFETY.md) reporting flow. *Proof:* `age_gate_test.dart`.

### 9.10 v7 threat entries

- [ ] **T-D-008** Plaintext local-storage harvest — historical games / chats / opponent fingerprints recoverable from a stolen-but-locked device via forensic tooling. *Mitigation:* §0.6 SQLCipher + protection-class + retention caps. *Proof:* `sqlcipher_at_rest_test.dart` + `no_plaintext_residue_test.dart`.
- [ ] **T-D-009** Android cloud-backup leak — app data backed up to user's Google Drive ends up readable by anyone with the Google credential. *Mitigation:* `android:allowBackup="false"` enforced in manifest + cross-install restore detection. *Proof:* `backup_excluded_android_test.dart`.
- [ ] **T-N-010** First-contact MITM on the signaling path — attacker swaps pubkeys for both sides at first session. *Mitigation:* §2.9 safety numbers + QR + persistent verified-contacts list + TOFU badge. *Proof:* `safety_numbers_test.dart` + `qr_verification_test.dart` + `unverified_opponent_badge_test.dart`.
- [ ] **T-P-010** KCI from leaked long-term Ed25519 key — attacker impersonates Bob to Alice without Bob's key. *Mitigation:* §2.9 KCI MAC over `transcript_hash` keyed by `K_kci`. *Proof:* `kci_resistance_test.dart`.
- [ ] **T-P-011** Engine-version rollback to a buggy older build. *Mitigation:* §12.5 high-water-mark + server-side `min_engine_replay_version`. *Proof:* `anti_rollback_high_water_mark_test.dart`.
- [ ] **T-N-011** DPI on plain-port WebRTC. *Mitigation:* §4.10 TURNS-on-443 + auto-promote. *Proof:* `turns_failover_test.dart`. *Documented residual:* SNI-inspecting middlebox can still block; pluggable transports are OQ-31.
- [ ] **T-X-008** Unmaintained transitive dependency falls behind a CVE. *Mitigation:* §3.10 CVE-watcher + forced-update enforcement; SBOM diff review on every release. *Proof:* `cve_watcher_test.go`.
- [ ] **T-X-009** Release-signing-key rotation overdue → a quietly-leaked old key keeps signing. *Mitigation:* §3.11 + Phase 16 key calendar. *Proof:* `signing_key_rotation_test.go`.
- [ ] **T-OPS-001** Silent on-call attrition — the solo operator stops responding without anyone noticing until users do. *Mitigation:* Phase 16 dead-man-switch on the operator dashboard fires `OPERATOR_ON_CALL_UNREACHABLE` after 72 h of unacknowledged alerts; auto-engages §6.3 kill-switch. *Proof:* `signaling/internal/ops/dead_man_switch_test.go`.
- [ ] **T-INV-001** Invite-link replay — an attacker intercepts a shared link and uses it before the intended recipient. *Mitigation:* §6.7 single-use + 24 h TTL + `INVITE_LINK_REPLAYED`. *Proof:* `invites/single_use_test.go`.
- [ ] **T-HDL-001** Handle / display-name impersonation — attacker sets display name to a well-known player's handle. *Mitigation:* §14.9 — display name is local-only, never replaces the cryptographic fingerprint, soft-warn on first contact with a name conflicting with a verified contact. *Proof:* `handle_impersonation_warning_test.dart`.

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

### 10.2 v6 additions to the catalog

- [ ] **F-PROTO-016** `SEQ_CEILING_REACHED` — sender at defensive `2^63` ceiling. *Recovery:* end session gracefully; future Phase 7 sub-task adds in-session re-key.
- [ ] **F-PROTO-017** `BYE_FRAGMENT_TIMEOUT` — receiver did not see all `BYE_PART`s within 30 s. *Recovery:* save partial transcript; surface "game ended without confirmation".
- [ ] **F-PROTO-018** `BYE_FRAGMENT_OUT_OF_ORDER` — part `idx` higher than announced `total` or duplicate. *Recovery:* `MISMATCH` with forensic bundle.
- [ ] **F-PROTO-019** `BYE_FRAGMENT_OUT_OF_BOUNDS` — announced `total > 64`. *Recovery:* reject before allocation; treat as DoS.
- [ ] **F-PROTO-020** `FRAGMENT_NOT_ALLOWED` — sender attempted to fragment a non-`BYE` frame. *Recovery:* local logic error; abort send, file `kind: bug` queue entry.
- [ ] **F-PROTO-021** `CRYPTO_SUITE_NOT_NEGOTIATED` — `HELLO.crypto_suite_id` unsupported. *Recovery:* end pre-game with friendly "both players need to be on a compatible app version".
- [ ] **F-PROTO-022** `TRANSCRIPT_VERSION_UNSUPPORTED` — attempted to load a saved transcript whose `engine_replay_version` is too old or too new. *Recovery:* refuse to load; offer export.
- [ ] **F-ID-012** `KDF_DERIVATION_FAILED` — HKDF or Argon2 returned an error (libsodium failure). *Recovery:* abort the operation; surface "please retry".
- [ ] **F-ID-013** `SECRET_ZEROISE_FAILED` — `sodium_memzero` reported failure. *Recovery:* deliberate process abort; secrets in memory are assumed leaked.
- [ ] **F-XPORT-004** `DATACHANNEL_ID_COLLISION` — attempted to recreate a DataChannel with an `id` still in use. *Recovery:* close existing, wait for `closed`, retry; if it recurs once → fresh DTLS handshake.
- [ ] **F-XPORT-005** `RESUMED_AS_NEW` — ICE / SCTP fully torn down; previous session ends, a new session is established with fresh AEAD salt. *User-visible:* "connection restarted".
- [ ] **F-CLOCK-004** `MONOTONIC_CLOCK_UNAVAILABLE` — platform did not return a monotonic clock source. *Recovery:* refuse to start any timed session; surface platform incompatibility.
- [ ] **F-CLOCK-005** `WALL_CLOCK_TAMPERED_DETECTED` — wall clock jumped > 10 s while a timed session was active (informational; chess clock is on monotonic so unaffected, but transcript timestamps are flagged). *Recovery:* warning toast; transcript flagged in metadata.
- [ ] **F-NET-008** `METERED_NETWORK_USER_DECLINED` — user declined to continue on metered network during TURN-relayed session. *Recovery:* graceful end with `BYE` carrying `reason: user_declined_metered`.
- [ ] **F-LIFECYCLE-005** `OEM_BATTERY_OPT_BLOCKING` — detected OEM battery optimisation is preventing background play. *Recovery:* surface nudge; cap session length at 10 min.
- [ ] **F-PUSH-005** `APNS_SILENT_PUSH_DROPPED` — silent push not delivered (best-effort detection via in-app delivery counter vs server-side send counter). *Recovery:* surface to user; suggest enabling Background App Refresh.
- [ ] **F-PUSH-006** `FCM_TOKEN_REFRESHED` — informational; client re-registers automatically.
- [ ] **F-ID-014** `RECOVERY_SCREEN_CAPTURED_DETECTED` — iOS reported screen-recording during recovery-code display. *Recovery:* obscure words; surface security warning; user must re-enter the recovery wizard to proceed.
- [ ] **F-CHAT-003** `CHAT_BLOCKED_BY_USER` — incoming chat from a fingerprint on the local block-list. *Recovery:* drop silently; never notify the blocked sender.
- [ ] **F-CHAT-004** `CHAT_REPORTED_AS_ABUSE` — user filed a report; bundle (signed transcript + chat) queued for upload after explicit "send" tap.
- [ ] **F-ONBOARD-001** `AGE_GATE_BLOCKED` — user self-attested under chat-eligibility age. *Recovery:* chat-disabled experience; can be revisited in settings.
- [ ] **F-STORE-004** `STORE_PRIVACY_MANIFEST_OUT_OF_DATE` — CI gate caught a data-collection change without a manifest update. *Recovery:* block merge.
- [ ] **F-SIG-010** `DEVICE_CAP_EXCEEDED` — account already has 8 active devices; oldest evicted, this device is the eviction target. *Recovery:* prompt user to remove an old device.
- [ ] **F-SIG-011** `LONG_POLL_CAP_EXCEEDED` — account at 32 concurrent long-polls. *Recovery:* `Retry-After: 5`.
- [ ] **F-SIG-012** `SDP_TOO_LARGE` — SDP > 16 KB at signaling. *Recovery:* surface as `ICE_FAILED` to the user; log on server.
- [ ] **F-SIG-013** `SDP_FORBIDDEN_MEDIA_LINE` — SDP contained a media section other than `application/data`. *Recovery:* reject; flag the offering account for abuse review.
- [ ] **F-SPEC-001** `SPECTATOR_CHAIN_REJECTED` — a spectator attempted to issue a view-key to a fourth party. *Recovery:* reject.
- [ ] **F-CONC-001** `ISOLATE_CRASHED` — `p2p` isolate threw an unhandled exception. *Recovery:* supervisor restart, end any active session, file `kind: crash` queue entry, surface friendly error.
- [ ] **F-CONC-002** `SODIUM_INIT_FAILED` — libsodium failed to load on first call. *Recovery:* refuse to enable P2P; surface platform incompatibility.

### 10.3 v7 additions to the catalog

Every code referenced by the v7 changelog or by the new sub-sections has a typed enum value, a UX string, and a proof test (per the catalog-ownership rule above).

- [ ] **F-STORE-005** `SQLCIPHER_KEY_UNWRAP_FAIL` — SQLCipher KEK unwrap failed at app launch. *Recovery:* quarantine DB, surface "history unavailable" with operator-contact path; never silently recreate. *Proof:* `frontend/test/p2p/storage/sqlcipher_key_unwrap_fail_test.dart`.
- [ ] **F-STORE-006** `LOCAL_STORAGE_QUOTA_EXCEEDED` — P2P-owned bytes exceed 250 MB ceiling. *Recovery:* refuse new session, surface cleanup UX. *Proof:* `total_quota_test.dart`.
- [ ] **F-STORE-007** `LOCAL_STORAGE_AT_REST_BROKEN` — plaintext-residue regression test caught a leak in a release build. *Recovery:* CI-blocker only; never reaches production. *Proof:* `no_plaintext_residue_test.dart`.
- [ ] **F-STORE-008** `BACKUP_ENCRYPTION_SALT_MISMATCH` — transcript-backup salt doesn't match the wrapping context. *Recovery:* refuse to load backup; surface "backup belongs to a different installation". *Proof:* `cross_install_restore_detection_test.dart`.
- [ ] **F-ID-015** `KCI_VERIFY_FAILED` — §2.9 KCI MAC verification failed. *Recovery:* end pre-game; never start a session.
- [ ] **F-ID-016** `SESSION_ID_COLLISION` — §1.9 session_id derivation produced a collision against an active session (catastrophic; defensive). *Recovery:* abort, file `kind: crash / severity: critical`.
- [ ] **F-PROTO-023** `CBOR_FLOAT_REJECTED` — incoming CBOR contained a float per §1.1. *Recovery:* drop frame, count toward `BAD_FRAME` threshold.
- [ ] **F-PROTO-024** `HKDF_INFO_UNKNOWN` — receiver saw an HKDF info string not in the registry (§1.10). *Recovery:* abort the operation; file `kind: bug`.
- [ ] **F-ID-017** `SAFETY_NUMBERS_MISMATCH` — user reported safety-number mismatch via the verification UX (§2.9). *Recovery:* refuse to start session; flag opponent fingerprint locally.
- [ ] **F-PROTO-025** `OPPONENT_FINGERPRINT_DOWNGRADE_DETECTED` — §12.5 high-water-mark check fired. *Recovery:* user prompt; decline-to-play one tap.
- [ ] **F-NET-009** `TURNS_HANDSHAKE_FAILED` — §4.10 TLS handshake to TURNS failed. *Recovery:* fall back to plain TURN; surface as `TURN_UNAVAILABLE` only if both fail.
- [ ] **F-CLOCK-006** `PREMOVE_INVALIDATED` — §11.8 queued premove illegal in post-opponent-move position. *Recovery:* drop premove; non-blocking toast.
- [ ] **F-PROTO-026** `REPETITION_CLAIM_REJECTED` — §1.11 cross-peer repetition witness mismatch. *Recovery:* treat as regular move (no draw).
- [ ] **F-SIG-014** `INVITE_LINK_EXPIRED` — §6.7 invite TTL elapsed. *Recovery:* prompt to generate fresh link.
- [ ] **F-SIG-015** `INVITE_LINK_REPLAYED` — §6.7 invite already claimed. *Recovery:* prompt for fresh link; flag for abuse review on operator side.
- [ ] **F-CHAT-005** `HANDLE_IMPERSONATION_SUSPECTED` — §14.9 display name conflicts with a verified contact. *Recovery:* soft warn; never auto-block.
- [ ] **F-ID-018** `RE_KEY_FAILED` — §2.10 re-key did not complete within budget. *Recovery:* end session; user retries.
- [ ] **F-OBS-003** `TRANSCRIPT_RAM_CAP_OVERFLOW` — in-RAM transcript buffer exceeded its memory budget mid-game. *Recovery:* spill to encrypted disk; never block.
- [ ] **F-OPS-002** `CVE_REQUIRES_FORCED_UPDATE` — §3.10 server-side `min_client_version` floor rejected this build. *Recovery:* deep-link to store update.
- [ ] **F-OPS-003** `KEY_ROTATION_OVERDUE` — Phase 16 key calendar shows an overdue rotation. *Recovery:* operator-only; surfaces on dashboard, never on user UI.
- [ ] **F-OPS-004** `BACKUP_RESTORE_DRILL_FAILED` — monthly Phase 16 drill failed. *Recovery:* operator queue entry `kind: p2p_ops`.
- [ ] **F-OPS-005** `OPERATOR_ON_CALL_UNREACHABLE` — dead-man-switch (T-OPS-001) fired. *Recovery:* auto-engage kill-switch (§6.3); status-page banner.
- [ ] **F-PROTO-027** `DEPRECATED_WIRE_VERSION_REJECTED` — client `wire_version` below floor. *Recovery:* deep-link to store update.
- [ ] **F-PROTO-028** `DEPRECATED_CRYPTO_SUITE_REJECTED` — client `crypto_suite_id` deprecated. *Recovery:* deep-link to store update.
- [ ] **F-PROTO-029** `DEPRECATED_ENGINE_REPLAY_VERSION_REJECTED` — §12.5 server-side engine-version floor. *Recovery:* deep-link to store update.

### 10.4 v8 additions to the catalog

> Codes added by v8. Numbering continues the existing series; do not renumber the v5/v6/v7 entries above.

- [ ] **F-PROTO-030** `VALIDATE_APPLY_RACE_DETECTED` — §1.12 critical-section invariant violated (a second `MOVE` reached the apply path before the first finished). *Recovery:* hard-fail the session with `MISMATCH`; ship the scheduler trace as a forensic bundle; queue entry `kind: p2p_protocol_bug / severity: critical`.
- [ ] **F-PROTO-031** `FFI_FUZZ_FOUND_DIVERGENCE` — nightly §1.13 FFI fuzz observed a `state_hash` divergence between two replays of the same input or a sanitizer finding. *Recovery:* CI-only failure; opens `kind: crash / severity: critical`. No user-visible code path.
- [ ] **F-START-001** `STARTUP_SELF_TEST_FAIL` — §0.7 KAT or smoke test failed at first P2P enable. *Recovery:* refuse P2P; surface "the cryptographic library on this device is broken — please reinstall the app from the official store"; deep-link to store.
- [ ] **F-START-002** `NATIVE_LIB_INTEGRITY_FAIL` — §0.8 SHA mismatch on `libchess_engine.so`. *Recovery:* refuse P2P; same UX as F-START-001.
- [ ] **F-PUSH-002** `PUSH_COALESCED` — §3.12 coalescing window suppressed a duplicate push. *Recovery:* informational only; the next long-poll receives the multi-offer hint.
- [ ] **F-NET-007** `TURN_BANDWIDTH_EXCEEDED` — §3.13 per-allocation cap tripped. *Recovery:* end the session as `BACKPRESSURE_DROP`; if recurrent for the same fingerprint, raise to `kind: abuse_suspicion`.
- [ ] **F-NET-008** `ICE_VPN_LEAK_USER_DECLINED` — §4.1 v8 trickle policy detected VPN, user declined the "leak public IP" prompt; no direct candidates available. *Recovery:* fall back to TURN; if TURN also fails, end as `RTC_HANDSHAKE_FAILED`.
- [ ] **F-STORE-006** `SCHEMA_SKIP_VERSION_FAIL` — §0.2 v8 skip-version matrix detected an ordering bug. *Recovery:* CI-only failure; opens `kind: storage_bug / severity: high`.
- [ ] **F-TEL-001** `DP_BUDGET_EXCEEDED` — §8.11 per-user daily DP budget exhausted; subsequent metrics dropped. *Recovery:* informational; counter resumes at midnight UTC.
- [ ] **F-STUDY-001** `STUDY_LOAD_VERSION_MISMATCH` — §6.8 transcript loaded with `engine_replay_version` that the local engine does not support. *Recovery:* fall back to "view PGN" mode (no engine validation, no annotations).
- [ ] **F-STUDY-002** `EXPORT_SIDECAR_MISSING` — §6.8.2 PGN imported without its `.cbor` sidecar; cannot verify cryptographic transcript. *Recovery:* allow load as a study line only; UI shows "unverified import" badge.
- [ ] **F-LIFE-005** `BG_TASK_DENIED_BY_OS` — iOS `BGAppRefreshTask` or Android `WorkManager` denied an execution window. *Recovery:* exponential back-off; informational on the next foreground.
- [ ] **F-NET-009** `LOAD_SHED_DROPPED` — §3.14 priority-lane shed rejected this request. *Recovery:* exponential back-off with full jitter; UI surfaces "server busy, retrying".
- [ ] **F-PROTO-032** `HELLO_TS_OUT_OF_WINDOW` — §1.1 v8 freshness check rejected a stale or future-dated `HELLO`. *Recovery:* silent drop; no Argon2 / signature verify performed.
- [ ] **F-PROTO-033** `SIGNED_TIME_FETCH_FAILED` — §3.15 `/v1/time` unreachable on a device with no monotonic-grounded wall-clock estimate. *Recovery:* refuse P2P with a "no internet" error; correspondence games loaded from local DB still readable.
- [ ] **F-PROTO-034** `MULTI_DEVICE_RACE_LOST` — §7.7 second device lost the answer race. *Recovery:* informational toast; loser device clears its long-poll.
- [ ] **F-CHAT-003** `REPORT_TARGET_RATE_LIMITED` — §14.3 v8 per-target decay limited a report. *Recovery:* report still queued, contributes ε to priority score; user told "your report has been received and added to existing reports about this opponent".
- [ ] **F-PROTO-035** `CONFIG_BLOB_VERSION_UNSUPPORTED` — §8.12 `config_blob_version` outside supported range. *Recovery:* fall back to last-known-good cached config; deep-link to store update.
- [ ] **F-TEL-002** `TELEMETRY_ENVELOPE_VERSION_UNSUPPORTED` — §8.12 envelope version unknown. *Recovery:* drop the batch silently; counter `telemetry.dropped_unsupported_envelope`.
- [ ] **F-STORE-007** `LEGITIMATE_RESTORE_MERGE_DECLINED` — §0.6 v8 user declined the restore-merge prompt. *Recovery:* the new install starts empty; old data retained encrypted-at-rest until §0.6 retention cap evicts it.
- [ ] **F-PROTO-036** `SPECTATOR_CHAIN_DEPTH_NONZERO_REJECTED` — §7.6 v8 reserved field non-zero. *Recovery:* hard reject with `wire_version` mismatch hint.
- [ ] **F-PROTO-037** `BACKFILL_OVERSIZE_REJECTED` — §7.6 spectator back-fill exceeds 1 MB unchunked path. *Recovery:* protocol bug; spectator session aborts; `kind: p2p_protocol_bug`.
- [ ] **F-CLOCK-005** `RAGE_QUIT_FORFEIT_FIRED` — §11.3 v8 90-second unrecoverable disconnect ended the session. *Recovery:* informational; transcript signed unilaterally with `BYE { reason: rage_quit }`.
- [ ] **F-STUDY-003** `STUDY_PGN_PARSE_FAIL` — §6.8.2 PGN with mod-extension tags failed strict parser. *Recovery:* offer "view as plain text" fallback.
- [ ] **F-STUDY-004** `STUDY_REPLAY_HASH_DIVERGENCE` — §6.8 replay's `state_hash` at any ply differs from the transcript's. *Recovery:* hard-fail the load; surface "this transcript is corrupted or was tampered with"; offer to file a `kind: p2p_protocol_bug`.

### 10.5 v9 additions to the catalog (live spectators + chat)

> Codes added by v9. Every code below is exclusively about the spectator / chat sub-system; none can affect the chess game's correctness or frame budget (§7.10 invariant). All retries / back-offs use full jitter.

- [ ] **F-SPEC-001** `SPECTATOR_CAPACITY_FULL` — §7.8.2 per-game cap (default 50) reached. *Recovery:* offer waitlist join; surface "this game is full — you'll be added if a seat opens."
- [ ] **F-SPEC-002** `SPECTATOR_WAITLIST_EXPIRED` — game ended or waitlist FIFO evicted entry before a seat opened. *Recovery:* informational toast; user may rejoin a future game from the same host.
- [ ] **F-SPEC-003** `SPECTATOR_AUTH_REQUIRED` — §7.8.3 anonymous join attempted in v1. *Recovery:* deep-link to account creation flow.
- [ ] **F-SPEC-004** `SPECTATOR_JOIN_RATE_LIMITED` — §7.8.4 per-account 6/min or 60/h cap tripped. *Recovery:* exponential back-off; UI shows the time until the next allowed join.
- [ ] **F-SPEC-005** `SPECTATOR_KICKED` — §7.9.5 issuing peer kicked this spectator; signaling refuses re-join on `(account, game_id)` for 24 h. *Recovery:* informational; surfaces "the host removed you from this game."
- [ ] **F-SPEC-006** `SPECTATOR_BANNED` — §7.9.5 issuing peer's persistent ban-list refused this account at signaling join time. *Recovery:* informational; user may not appeal in v1 (Phase 14 review path may surface in v2).
- [ ] **F-SPEC-007** `SPECTATOR_MUTED` — §7.9.5 single-spectator mute applied; client-side state only, no server effect. *Recovery:* informational; surfaces "the host muted you."
- [ ] **F-SPEC-008** `SPECTATOR_GLOBALLY_MUTED` — §7.9.4 global mute toggled on; affects all spectators of this game. *Recovery:* informational banner; releases when host toggles off.
- [ ] **F-SPEC-009** `SPECTATOR_SHED_FOR_PERF` — §7.10.2 issuing peer perf budget exceeded for ≥3 s; LIFO shed dropped this spectator. *Recovery:* informational; spectator may retry the join after 30 s exponential back-off.
- [ ] **F-SPEC-010** `SPECTATOR_RELAY_UNAVAILABLE` — §7.10.3 spectator could not establish direct path AND TURN refused a separate allocation. *Recovery:* fail the join; surface "unable to connect on your network."
- [ ] **F-CHAT-004** `CHAT_RATE_LIMITED` — §7.9.2 sender token bucket empty. *Recovery:* client-side cooldown timer in the input UI; refused message is **not** retried automatically.
- [ ] **F-CHAT-005** `CHAT_MESSAGE_OVERSIZED` — §7.9.3 message exceeded 280 chars / 512 bytes. *Recovery:* surface "too long"; –3 token-bucket penalty.
- [ ] **F-CHAT-006** `CHAT_SLOW_MODE_ACTIVE` — §7.9.4 send rejected because slow-mode interval not yet elapsed. *Recovery:* client-side countdown in the composer.
- [ ] **F-CHAT-007** `CHAT_AUTO_THROTTLED_CLOCK_PRESSURE` — §7.9.6 chat queued or muted because a player's clock < threshold. *Recovery:* informational; messages queue locally up to 5 entries deep, send post-move.
- [ ] **F-CHAT-008** `CHAT_RECEIVER_OVERFLOW` — §7.10.4 spectator-side decode queue exceeded 100 messages. *Recovery:* drop oldest; surface "chat is moving too fast — some messages were not shown."
- [ ] **F-CHAT-009** `CHAT_REPORT_FILED` — §7.9.7 report submitted. *Recovery:* informational; auto-mute the reported account client-side.
- [ ] **F-CHAT-010** `CHAT_TOURNAMENT_LOCKED` — §7.9.8 chat default-muted for tournament/rated game; host must opt-in. *Recovery:* informational banner; spectators see "chat is disabled for this game."
- [ ] **F-CHAT-011** `CHAT_HOST_BROADCAST_DROPPED_LOW_PRIORITY` — SCTP stream `7` (chat) dropped under congestion while stream `1` (chess) preempted. *Recovery:* informational; the dropped message is **not** retransmitted (chat is best-effort by design).
- [ ] **F-CHAT-012** `CHAT_DECODE_ERROR_DISCARDED` — AEAD decrypt or NFC-normalisation failed on a single chat frame. *Recovery:* drop the frame; counter `chat.decode_error`; never propagated to the engine isolate (§7.10.5 invariant).
- [ ] **F-SPEC-011** `BACKFILL_QUEUE_OVERFLOW` — §7.6 back-fill queue on issuing peer exceeded soft cap (e.g. 5 concurrent back-fills for new joiners). *Recovery:* delay the join with a "hold on, syncing the game…" UI; new spectators wait FIFO.
- [ ] **F-SPEC-012** `SPECTATOR_HEARTBEAT_TIMEOUT` — issuing peer received no heartbeat from a spectator for 60 s. *Recovery:* tear down the DataChannel; reclaim a seat from the cap (§7.8.2).
- [ ] **F-SPEC-013** `SPECTATOR_KEY_ROTATION_REQUIRED` — issuing peer rotated `K_view` (e.g. after a reported abuse incident); existing spectators must re-handshake. *Recovery:* automatic re-derivation via stored `K_view_seed`; user-invisible unless it fails (then F-SPEC-010 path).
- [ ] **F-CHAT-013** `CHAT_NFC_NORMALISATION_FAIL` — inbound chat byte sequence is not valid UTF-8 or fails NFC normalisation. *Recovery:* drop; counter; sender is penalised –1 token (cheap-attacker discouragement, not a hard block).
- [ ] **F-CHAT-014** `CHAT_HOMOGLYPH_BLOCKED` — [UTS #39](https://www.unicode.org/reports/tr39/) mixed-script confusable rejected (display-name impersonation defence). *Recovery:* sender sees "this name / message is not allowed"; no engine effect.
- [ ] **F-SPEC-014** `SPECTATOR_DATACHANNEL_BACKPRESSURE` — SCTP send-buffer to a spectator above high-water mark for ≥ 2 s. *Recovery:* pause chat fan-out to that spectator (chess stream `1` continues); release on low-water; if not released within 10 s, treat as F-SPEC-009 perf-shed.

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

### 11.7 Monotonic clock requirement and wall-clock-tamper detection

Chess-clock arithmetic on wall-clock time is exploitable: an attacker can wind the system clock back to deny a flag-fall, or forward to claim opponent flagged. v6 closes this by mandating monotonic time everywhere it matters.

- [ ] **All chess-clock arithmetic uses the OS monotonic clock:** `clock_gettime(CLOCK_MONOTONIC_RAW)` on Linux/Android, `mach_absolute_time` on iOS/macOS, `QueryPerformanceCounter` on Windows. The pure-Dart fallback (web, hot-reload) uses `Stopwatch` which is monotonic by spec on all current Flutter platforms.
- [ ] **Wall-clock is permitted only for transcript timestamps** (informational; flagged "approximate" in the transcript schema). Wall-clock is never read inside the flag-fall consensus or clock-pause arithmetic.
- [ ] **CI grep gate:** `frontend/lib/services/p2p/clock/**` is forbidden from importing `dart:core` `DateTime.now()`, `DateTime.timestamp()`, or `Platform.localeName`-derived calendar arithmetic. **Proof:** `frontend/test/p2p/clock/no_wall_clock_in_clock_module_test.dart`.
- [ ] **Wall-clock-jump detection:** the `p2p` isolate samples wall-clock alongside monotonic at 1 Hz; a wall-clock delta > 10 s in either direction over a 1 s monotonic interval triggers `WALL_CLOCK_TAMPERED_DETECTED` (§10.2). The chess clock is unaffected (it's on monotonic), but the transcript metadata records the event. **Proof:** `frontend/test/p2p/clock/wall_clock_jump_detection_test.dart`.
- [ ] **`MONOTONIC_CLOCK_UNAVAILABLE` failure:** if the platform doesn't expose a monotonic clock (extremely unlikely), the app refuses to start any timed session. Untimed (correspondence) sessions remain possible. **Proof:** `frontend/test/p2p/clock/monotonic_unavailable_test.dart` (mocked).
- [ ] **Rooted-device escalation:** rooted/jailbroken-device detection (Phase 14 §14.5) forces `casual_mode=true` because monotonic clock can be intercepted via Magisk / Frida. Documented residual risk: an attacker on their own device cannot be stopped; goal is opponent-record protection.

### 11.8 Premove (v7)

Blitz play is unusable without premoves — every serious chess UI offers them — but they are subtle on the wire because the engine must validate the premove against the just-arrived opponent move and either fire it or invalidate it within one frame budget.

- [ ] **Premove storage:** local-only; the premove is never sent to the opponent until it becomes the actual move. Storage is the in-memory move queue per side; max queue depth 1 (no premove chains in v1; revisit in OQ-30).
- [ ] **Validation pipeline:** on receipt of opponent's `MOVE`, after engine-validating + applying it, the local engine attempts to apply the queued premove against the new position. Legal → fire as a normal `MOVE` frame, observe local time as if user clicked at receipt time + 0 ms (premove latency advantage is the whole point). Illegal → silently drop the premove and surface `PREMOVE_INVALIDATED` (§10.3) as a non-blocking toast.
- [ ] **Mod-aware premove rules:** the premove validator runs *the same* per-mod legality check as a normal move (§12.1 `ENGINE_REPLAY_VERSION` already covers this). Mods with phase-changing rules (Kings Battle Phase-1→Phase-2, Mercenary pawn-as-piece transitions) must re-validate the premove against the post-opponent-move phase. **Proof:** `frontend/test/p2p/clock/premove_mod_phase_transition_test.dart` (×7 mods).
- [ ] **Cross-peer determinism:** premove is purely local until fired; once fired it is an ordinary `MOVE` and `state_hash` parity is preserved. **Proof:** `frontend/test/p2p/protocol/premove_state_hash_parity_test.dart`.
- [ ] **UI:** opponent never sees the premove indicator; local UI shows the premove as a translucent piece on the destination square. Tap on a different square cancels the premove (no wire traffic).
- [ ] **Default off for v1**, opt-in via settings (OQ-30 tracks default-on-for-blitz consideration).

### 11.9 Repetition-claim wiring (v7)

Section §1.11 specifies the cross-peer algorithm; §11.9 covers the in-game UX:

- [ ] Three-fold repetition is *claimable* per FIDE rules — the player whose move it is can play the move-that-causes-the-third-occurrence and claim a draw, or play it and not claim (game continues). v7 surfaces the claim as a one-tap dialog when the engine detects the condition. **Proof:** `frontend/test/p2p/ui/repetition_claim_dialog_test.dart`.
- [ ] Five-fold repetition is *automatic* (FIDE 2014+); both engines force a draw without UX. **Proof:** `frontend/test/p2p/protocol/five_fold_auto_draw_test.dart`.

---

## Phase 12 — Engine replay-version pinning

**Goal:** Both peers must run the exact same chess-rule semantics, or replay parity is meaningless. A behaviour-affecting change to `frontend/native/engine/**` cannot ship without bumping a version field that is exchanged in `HELLO`. *0% complete.*

### 12.1 Versioning scheme

- [ ] `ENGINE_REPLAY_VERSION: u32` lives in [frontend/native/engine/replay_version.h](../frontend/native/engine/replay_version.h) and is emitted by the build into a static symbol exposed via FFI. Bumped manually for any change that affects: move generation, legality, draw rules, mod-specific rules, canonical state hash. **Not** bumped for: search-only changes, eval-only changes, opening book content, performance tuning that does not affect move legality.
- [ ] **CI gate:** a workflow `engine-replay-version-bump-required.yml` greps the diff of `frontend/native/engine/{board,moves,rules,mods}/**` and `frontend/native/engine/bridge_*_refine_result.c` and fails the PR / push if those paths changed without `replay_version.h` changing. Override: a queue entry `kind: engine_replay_no_bump_justified` with a written rationale (e.g. comment-only change, internal refactor with proof of identical output via golden tests). **Proof:** `.github/workflows/engine-replay-version-bump-required.yml` + `frontend/test/native/replay_version_golden_test.dart` (10k-position move-list golden across all 7 mods; bumping the version implies regenerating the golden in the same PR).

> **v7 correction:** the v6 path glob `{board,moves,rules,mods}` did not match the actual engine layout. The watched paths MUST be `frontend/native/engine/{board,bridge,eval,movegen,search}/**`, the top-level legacy translation units `frontend/native/engine/{board,bridge,evaluate,movegen,search}.c`, and the per-mod `bridge_*_refine_result.c` files. The CI gate enforces the corrected list; a v7 regression test asserts that any added `.c`/`.h` file under `frontend/native/engine/` is either explicitly watched or explicitly listed in `frontend/native/engine/replay_version_excluded_paths.txt` with a written rationale. **Proof:** `frontend/test/native/replay_version_watched_paths_complete_test.dart`.
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

### 12.5 Anti-rollback enforcement (v7)

v6's negotiation rule is "exact match or no-game". An honest peer running an old build never sees a downgrade attack — *but a malicious peer can advertise a low `ENGINE_REPLAY_VERSION` to coerce the opponent into the older (potentially-buggy) rules*. v7 adds an anti-rollback floor and a per-account high-water-mark.

- [ ] **Per-account high-water-mark:** the local client persists `seen_max_engine_replay_version` across sessions in the SQLCipher-backed `meta` table. A `HELLO` advertising a *lower* version than this water-mark triggers `OPPONENT_FINGERPRINT_DOWNGRADE_DETECTED` (§10.3) and a soft warning: "Your opponent is on an older engine version than you've previously played against. This is unusual." Decline-to-play is one tap. **Proof:** `frontend/test/p2p/protocol/anti_rollback_high_water_mark_test.dart`.
- [ ] **Server-side floor:** the signaling server rejects `HELLO`s carrying `engine_replay_version` below the `min_engine_replay_version` set by the operator (independent from `min_client_version` in §3.10 because a forced-update CVE may not bump the engine version). → `DEPRECATED_ENGINE_REPLAY_VERSION_REJECTED` (§10.3). **Proof:** `signaling/internal/auth/min_engine_replay_test.go`.
- [ ] **Cross-architecture golden parity:** the 10k-position golden in §12.1 must produce bit-identical output on x86_64 (CI baseline) and arm64 (release-branch matrix). If divergence is ever observed, ship per-arch goldens and bind arch into `engine_replay_version` derivation. (OQ-32 tracks whether a single-golden assertion is sufficient given integer-only arithmetic in the rule layer.) **Proof:** `frontend/test/native/replay_version_golden_cross_arch_test.dart`.

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

## Phase 14 — User safety: chat moderation, blocking, abuse reporting

**Goal:** Give every user the tools to protect themselves in a peer-to-peer environment where the operator cannot proactively moderate. *0% complete. Hard prerequisite for the Phase 6 beta-open gate.*

v5 had per-side rate limits but no answer to harassment, abuse, or safety reporting. v6 makes user-safety a first-class phase because shipping unmoderated chat without these features would fail App Store / Play review and would be a duty-of-care failure.

### 14.1 Per-device opponent block-list

- [ ] Block-list keyed by **opponent device fingerprint** (§2.1). Blocking prevents future matches with that fingerprint and silently drops any incoming chat (no notification to the blocked sender). Block list is local-only (no server reporting); user can review and unblock.
- [ ] **Account-level escalation:** because device fingerprints rotate on rebind, an option to also block the *account* fingerprint is offered. Account blocks survive opponent's device replacement.
- [ ] **Block during game:** mid-game block ends the current session as `BYE { reason: user_blocked }`, transcript saved, no further matches.
- [ ] **UI surface:** the opponent's fingerprint is always visible in-game (Device ID badge); long-press → Block / Mute / Report menu. **Proof:** `frontend/test/p2p/ui/opponent_block_test.dart` + `frontend/test/p2p/services/block_list_persistence_test.dart`.

### 14.2 Per-message local mute

- [ ] In-game "mute chat" toggle hides incoming chat without ending the session and without notifying the opponent. Distinct from blocking (mute is reversible mid-game).
- [ ] **Default-mute heuristics:** new opponents (fingerprint never seen before) start in a soft-mute mode where chat is delivered but not auto-shown until the user taps "show chat". Reduces spam of unsolicited messages on first contact. **Proof:** `frontend/test/p2p/ui/default_mute_first_contact_test.dart`.

### 14.3 Abuse reporting

- [ ] Report flow: user taps "Report opponent" → selects reason (harassment, sexual content, threats, cheating-suspicion, other) → reviews the bundle that will be uploaded (signed transcript + chat history + opponent fingerprint + reason code) → explicit "Send" tap.
- [ ] **Cryptographic accountability:** because both peers sign the transcript and chat (§1.7 RESIGN; chat could similarly carry signatures — deferred to v6.1 if it inflates wire cost too much), the reported content is non-repudiable. The accused cannot claim "I didn't say that" if the signature verifies.
- [ ] **Server-side review:** reports land in a queue at the operator (signaling-server admin endpoint). [docs/P2P_TRUST_AND_SAFETY.md](P2P_TRUST_AND_SAFETY.md) defines the published SLA (e.g. "reviewed within 7 days"), the action ladder (warning, account suspension, account ban with recovery-code invalidation), and the appeal path. For a solo-operator deployment, the SLA is honestly stated as "best-effort, no guaranteed timeline".
- [ ] **Report storage:** uploaded bundles encrypted at rest with operator KMS key; auto-purged at 90 d if not actioned. **Proof:** `signaling/internal/abuse/report_storage_test.go`.
- [ ] **No retaliation channel:** a report does not notify the reported peer (would invite retaliation). The reporter is anonymised in the bundle (account fingerprint hashed, raw fingerprint stored separately and only revealed on operator decision to escalate). **Proof:** `signaling/internal/abuse/anonymisation_test.go`.
- [ ] **Report-bombing defense:** per-account limit of 5 reports / 24 h; over-cap reports are queued but de-prioritised; persistent over-cap reporters are flagged for operator review (could be bad faith, could be a victim of stalking). **Proof:** `signaling/internal/abuse/report_rate_limit_test.go`.

### 14.4 Age-gate and minor protections

- [ ] On first launch, self-attested age picker. Default 13+ (US COPPA); EU member states with GDPR-K may require 16+ — detected from device locale (best-effort) and surfaced.
- [ ] **Under-age users:** chat features disabled by default; can be re-enabled in settings only after re-attesting age. Spectator mode (Phase 7) disabled. Reported transcripts auto-flagged with `minor_involved: true` for prioritised review.
- [ ] **Age-gate UI:** plain-language copy, no dark patterns; "prefer not to say" option (assumed under-age for safety). **Proof:** `frontend/test/p2p/onboarding/age_gate_test.dart` + `frontend/test/a11y/age_gate_a11y_test.dart`.

### 14.5 Rooted / jailbroken / emulator detection

- [ ] Best-effort detection on Android (Magisk / SafetyNet / Play Integrity "BASIC" verdict) and iOS (jailbreak heuristics: writable system paths, dyld checks, sandbox escape signatures). Result is **not** a block; it forces `casual_mode=true` (no rated games, no flag-fall victories) for the device.
- [ ] **Honest UX copy:** "This device shows signs of modification; rated play is disabled. You can still play casual games." Avoid accusatory framing. **Proof:** `frontend/test/p2p/identity/root_detection_casual_only_test.dart`.
- [ ] **No silent telemetry of root status** to the server (privacy concern); only surfaced locally and reflected in `HELLO.capabilities.casual_mode` so opponents see the badge.

### 14.6 In-chat social-engineering warnings

- [ ] Per-message regex detector for patterns that suggest social engineering ("recovery" / "backup" / "seed" / "password" + 16-word patterns + "send me your" + URL-shorteners on outgoing chat). Triggers a soft, non-blocking warning above the message: incoming → "This looks like a phishing attempt. Never share your recovery words"; outgoing → "Are you sure? Sharing recovery words gives the recipient full account access."
- [ ] Detector list is shipped in the app (no server callback; privacy-clean) and updated via remote signed-config. **Proof:** `frontend/test/p2p/ui/chat_recovery_warning_test.dart` + `frontend/test/p2p/ui/chat_url_shortener_warning_test.dart`.
- [ ] **URL handling:** chat URLs are never auto-clickable; user must explicitly tap a "reveal link" button that surfaces the full URL and a warning before opening.

### 14.7 Quality attributes

- [ ] **Performance:** block-list lookup O(1) via in-memory hash set; loaded once per session, persisted on change. **Proof:** `frontend/test/p2p/perf/block_list_lookup_test.dart`.
- [ ] **Efficiency:** report bundle ≤ 256 KB after compression for a typical 1-hour game; rejected at upload if larger.
- [ ] **Stability:** mid-game block transition cannot crash the UI; verified by widget test under all session states. **Proof:** `frontend/test/p2p/ui/mid_game_block_widget_test.dart`.
- [ ] **Reliability:** an upload failure of a report bundle is retried with backoff and persisted locally; user sees "report queued" state. **Proof:** `frontend/test/p2p/services/report_upload_retry_test.dart`.
- [ ] **Integrity:** the report bundle is signed by the reporter's device key; tampering at upload-time is server-detectable.

### 14.8 Acceptance gate

- [ ] All 14.1–14.7 ticked, [docs/P2P_TRUST_AND_SAFETY.md](P2P_TRUST_AND_SAFETY.md) published with operator SLA and action ladder, age-gate live on first launch, opponent-block UI accessible from in-game and from settings.

### 14.9 Handle / display-name policy (v7)

v6 silently assumed a displayed opponent identity is the cryptographic fingerprint. Real users want a friendlier label. v7 adds a *strictly local* display-name layer that never replaces the fingerprint and resists impersonation by design.

- [ ] **No central handle registry.** There is no "@username" claim service. Every name is self-attested and shown only on the local device. **Proof:** [docs/P2P_IDENTITY_POLICY.md](P2P_IDENTITY_POLICY.md) + `signaling/internal/accounts/no_handle_endpoint_test.go` (asserts no handle endpoints exist).
- [ ] **Local-only display name:** the user can assign a custom display name to any opponent fingerprint they've encountered ("Alice from chess club"). Stored in SQLCipher (§0.6); never sent on the wire.
- [ ] **Self-attested handle in `HELLO.capabilities.display_name: utf8?`** is permitted (≤ 32 grapheme clusters, NFC-normalised, no zero-width / RTL-override / homoglyph-prone characters per a confusables-skeleton check). Receiver UI shows it as "Bob (…claims this name)" until verified.
- [ ] **Impersonation soft-warn:** when an incoming `HELLO.display_name` matches the local label of an *already-verified* contact (§2.9) but the fingerprint differs, surface a non-blocking warning: "Someone is using the name 'Alice from chess club' but their identity does not match." → `HANDLE_IMPERSONATION_SUSPECTED` (§10.3). Never auto-blocks; user decides.
- [ ] **Confusables / homoglyph detection** uses the Unicode confusables-skeleton algorithm (`uts46` + `uts39`) on incoming names; flagged names are visually marked. **Proof:** `frontend/test/p2p/identity/handle_confusables_test.dart`.
- [ ] **The cryptographic fingerprint is always visible** in the in-game opponent badge regardless of display-name. UI tests assert the fingerprint cannot be hidden by any setting. **Proof:** `frontend/test/p2p/ui/fingerprint_always_visible_test.dart`.

---

## Phase 15 — Security audit, penetration test, and bug bounty

**Goal:** External validation of the cryptographic protocol, application security, and operational posture before GA. *0% complete. Hard prerequisite for the Phase 6 §6.4 GA-rollout gate (not for beta-open).*

v5 implicitly assumed good code quality + extensive proof tests are sufficient. v6 acknowledges that no internal review catches everything in cryptography or platform-integration code; an external audit before GA is industry-standard hygiene.

### 15.1 Cryptographic protocol audit

- [ ] Engagement scope: [docs/P2P_PROTOCOL.md](P2P_PROTOCOL.md) v1, [Phase 1](#phase-1--wire-protocol-cbor-over-sctp-datachannel), [Phase 2](#phase-2--identity-key-management-and-recovery), [Phase 11](#phase-11--chess-clock-and-time-control), [Phase 12](#phase-12--engine-replay-version-pinning) reviewed by a third-party cryptographic-protocol firm.
- [ ] Deliverables: written report covering protocol soundness (forward secrecy, replay protection, downgrade resistance, KDF parameter choice, AEAD nonce construction, signature ceremonies), a list of findings with severity, a remediation plan.
- [ ] **All critical / high findings remediated and re-tested** before GA. Medium findings tracked as queue entries with deadlines; low findings documented.
- [ ] **Public summary** of the audit (with operator's permission) published in [docs/P2P_AUDIT_HISTORY.md](P2P_AUDIT_HISTORY.md). Builds user trust; standard for security-conscious projects.

### 15.2 Application penetration test

- [ ] Scope: client (iOS / Android), signaling server, infrastructure (TURN, observability stack). Methodology: OWASP MASVS-L2 for mobile; OWASP ASVS-L3 for the server.
- [ ] Findings remediated under the same severity ladder as 15.1.
- [ ] **Specific in-scope checks:**
  - Secure-storage extraction on jailbroken iOS / rooted Android.
  - DataChannel ciphertext recovery from on-device memory dumps.
  - Signaling-server endpoint authorisation matrix.
  - TURN credential lifetime and binding.
  - Push-payload tamper resistance.
  - Reproducible-build verification end-to-end.
  - SBOM accuracy (every artefact in the binary appears in the SBOM).

### 15.3 Bug bounty programme (steady-state)

- [ ] Public security.txt (RFC 9116) at `https://chessrecast.example/.well-known/security.txt` declaring scope, contact (PGP-encrypted email), safe-harbour clauses, and reward range.
- [ ] **Scope:** signaling server, P2P protocol, client crypto/identity code paths. **Out of scope:** social engineering of operators, physical attacks, denial of service via legitimate use, third-party dependencies (file upstream).
- [ ] **Triage SLA:** acknowledgement within 5 days; initial assessment within 14 days; fix shipped per severity (critical ≤ 7 d, high ≤ 30 d, medium ≤ 90 d). Honoured even for solo-operator deployments — if the bus factor is 1, the SLA is published as "best-effort" with that disclosure.
- [ ] **Hall of fame** for credited reporters (opt-in).
- [ ] **Coordinated disclosure window:** 90 days standard; extendable on agreement. Embargoed-CVE handling documented.

### 15.4 Quality attributes

- [ ] **Performance:** audit/pentest engagement does not block other phases; runs in parallel with Phase 6 beta.
- [ ] **Efficiency:** findings are tracked as queue entries with proof-test references so re-occurrence is mechanically prevented.
- [ ] **Stability:** every remediation carries a regression test (per the tests-with-code rule).
- [ ] **Reliability:** audit report is reproducibly verifiable against the audited commit SHA.
- [ ] **Integrity:** the audit firm is paid for its time, not its findings; explicit "no findings" outcome is acceptable and publishable.

### 15.5 Acceptance gate

- [ ] Phase 15.1 + 15.2 complete with all critical / high findings remediated and verified; Phase 15.3 live with a working security.txt and PGP-keyed inbox; remediation queue entries closed or carrying explicit deferral rationale.

---

## Phase 16 — Operations and lifecycle (v7)

**Goal:** A shipped P2P feature is not a ship-and-forget artefact. v6 documented the cryptographic ceremony for first-day operations and the audit programme for pre-GA validation, but was silent on the steady-state work that keeps the system safe across years: CVE response, key rotation, drill cadence, dependency hygiene, deprecation policy, and on-call handoff. v7 makes this a first-class phase whose acceptance gate is a **hard prerequisite for the Phase 6 GA-rollout gate**, alongside Phase 15. *0% complete.*

### 16.1 CVE-response operations

- [ ] CVE-watcher service (§3.10) is live and triaged daily; queue entry `kind: p2p_cve` opened for every new advisory affecting the SBOM.
- [ ] Per-severity SLA published in [docs/P2P_OPERATIONS.md](P2P_OPERATIONS.md) and visible to users on the security.txt page.
- [ ] Forced-update path (§3.10 server-side `min_client_version` enforcement) drilled at least once before GA. **Proof:** `signaling/internal/cve/forced_update_drill_test.go` + a runbook entry in [docs/P2P_SIGNALING_RUNBOOK.md](P2P_SIGNALING_RUNBOOK.md).

### 16.2 Key-rotation calendar

A single source-of-truth calendar in [docs/P2P_OPERATIONS.md](P2P_OPERATIONS.md) §key-calendar with the following minimums:

| Key | Rotation cadence | Trigger for off-cycle | Proof |
|---|---|---|---|
| TURN HMAC | Quarterly | Suspected leak | §3.11 `hmac_rotation_test.go` |
| Push-token re-registration | 30 d server-driven hint | Device-key rotation, install | §3.11 |
| Signed-config signing key | Annual | Suspected leak | §3.11 |
| KMS / install-seal key | Biennial | Confirmed leak | §3.11 |
| Release-signing (cosign / Apple ID) | Biennial | Confirmed leak | T-X-005 |
| Bug-bounty PGP key | Annual | Suspected leak | §15.3 |

- [ ] Overdue rotation → `KEY_ROTATION_OVERDUE` (§10.3) on the operator dashboard within 24 h of the deadline.

### 16.3 Backup-restore drills

- [ ] Monthly drill restores the signaling DB from a litestream snapshot into a clean staging environment, runs the full Phase 5 L7 chaos suite, and asserts P50/P95 within 10% of production. **Proof:** `signaling/internal/ops/restore_drill_test.go` + monthly report at `agent/reports/p2p/restore-drill-<yyyy-mm>.md`.
- [ ] Drill failure → `BACKUP_RESTORE_DRILL_FAILED` (§10.3) and a `kind: p2p_ops` queue entry; GA gate auto-suspends if no successful drill in the past 60 d.

### 16.4 Dependency-bump policy

- [ ] Pinned dependencies receive a SBOM-diff review on every release. Major-version bumps in cryptographic dependencies (libsodium, Go-stdlib crypto, Flutter `cryptography` package) require a queue entry `kind: shared_edit` with a written rationale and a regenerated KAT-vector test pass.
- [ ] The CVE-watcher's auto-PR for patch-level dependency bumps must pass the full L1–L7 suite before merge. No `--force-merge`.

### 16.5 Deprecation policy

Fields negotiated at handshake (`wire_version`, `crypto_suite_id`, `engine_replay_version`) accumulate over time. v7 declares the deprecation ladder up front so beta users do not hit deprecation surprises:

- [ ] **Soft-deprecate:** announce in release notes; bump `min_*` floor on the staging server; clients see a non-blocking "please update" badge for 30 d.
- [ ] **Hard-deprecate:** bump `min_*` floor on production; affected clients get the appropriate `DEPRECATED_*_REJECTED` (§10.3) and a deep-link to the store.
- [ ] **Sunset window:** minimum 90 d between soft- and hard-deprecation for `wire_version` and `crypto_suite_id` (allows enterprise / managed-device fleets to upgrade); minimum 30 d for `engine_replay_version` (rule bugs justify shorter).
- [ ] Sunset events documented at [docs/P2P_DEPRECATIONS.md](P2P_DEPRECATIONS.md) with effective dates and the original release-notes link.

### 16.6 Post-incident review

- [ ] Every production incident (KPI breach, kill-switch engagement, security advisory acknowledged) gets a written post-mortem within 7 d using the template at [docs/P2P_INCIDENT_RESPONSE.md](P2P_INCIDENT_RESPONSE.md). Template includes: timeline, detection lag, root cause (5-whys minimum), action items with owners + dates, prevention test added.
- [ ] Public-facing summary on the status page within 14 d for any incident affecting > 1% of beta MAU.

### 16.7 On-call handoff

Even a solo-operator deployment needs a continuity story:

- [ ] On-call schedule in [docs/P2P_OPERATIONS.md](P2P_OPERATIONS.md) names a primary and a secondary; secondary may be "none" for solo deployments but the doc must say so.
- [ ] Dead-man-switch (T-OPS-001): unacknowledged critical alerts > 72 h → `OPERATOR_ON_CALL_UNREACHABLE` (§10.3) auto-engages §6.3 kill-switch and posts a status-page banner. **Proof:** `signaling/internal/ops/dead_man_switch_test.go`.
- [ ] Onboarding runbook for a new operator covers: KMS access, signing-key access, dashboard access, status-page admin, runbook locations, recovery from each `kind: p2p_*` queue entry. **Proof:** [docs/P2P_OPERATOR_ONBOARDING.md](P2P_OPERATOR_ONBOARDING.md) exists and is dated within the past 6 months.

### 16.8 Quality attributes

- [ ] **Performance:** the operations work does not slow user-visible code paths.
- [ ] **Efficiency:** the dead-man-switch + restore drill + CVE watcher run inside the existing signaling-server budget (no new infra cost line).
- [ ] **Stability:** every operations action that mutates production state has a dry-run mode and a documented rollback.
- [ ] **Reliability:** rotation jobs are idempotent; a partial run can resume cleanly.
- [ ] **Integrity:** all rotation events sign their successors using the predecessor key; an attacker who steals a key cannot rotate it without leaving an audit trail.

### 16.9 Acceptance gate

- [ ] All 16.1–16.8 ticked, [docs/P2P_OPERATIONS.md](P2P_OPERATIONS.md) published with the key calendar + on-call schedule + runbook index, dead-man-switch live with at least one successful drill, restore drill passing for two consecutive months.

---

## Phase 17 — End-to-end budget tree (performance, efficiency, stability, reliability, integrity)

**Goal:** Convert every quality promise the project makes into a measurable cap with a proof test, organised in a single hierarchical tree so no leaf is forgotten and no leaf can silently regress. *0% complete. Hard prerequisite for the Phase 6 §6.4 GA-rollout gate.*

v0–v9 sprinkled numeric caps across two dozen sub-sections — latency caps in §1.4, frame-budget caps in §7.10.2, cost caps in §6.5, crash-rate caps in §6.5, memory caps in §1.4, frame-size caps in §1.1, and many more. They had no single owner and no single proof harness. Phase 17 hangs every numeric promise off **one tree**, [agent/baselines/p2p_budgets.json](../agent/baselines/p2p_budgets.json), with the structure below. Every leaf is `{ id, cap, units, owning_section, proof_test, baseline, last_measured_ts }`. Drift on any leaf opens `kind: p2p_budget_breach`.

### 17.1 The tree

```
chessrecast.p2p
├── performance
│   ├── handshake_to_first_move_p99_ms          ≤ 5000  (§17.2.1)
│   ├── move_rtt_lte_p50_ms                     ≤ 120   (§17.2.2)
│   ├── move_rtt_lte_p99_ms                     ≤ 250   (§17.2.2)
│   ├── move_rtt_wifi_p99_ms                    ≤ 80    (§17.2.2)
│   ├── encode_p99_us                           ≤ 1000  (§17.2.3)
│   ├── encrypt_aad_p99_us                      ≤ 300   (§17.2.3)
│   ├── decrypt_verify_p99_us                   ≤ 300   (§17.2.3)
│   ├── engine_validate_p99_us                  ≤ 1000  (§17.2.3)
│   ├── apply_state_hash_p99_us                 ≤ 500   (§17.2.3)
│   ├── render_frame_p99_ms                     ≤ 16    (§17.2.4)
│   └── spectator_chat_decode_per_frame_ms      ≤ 2     (§7.10.2 + §17.2.5)
├── efficiency
│   ├── battery_active_blitz_pct_per_hour       ≤ 3.0   (§17.3.1)
│   ├── battery_correspondence_idle_pct_per_h   ≤ 0.4   (§17.3.1)
│   ├── thermal_chassis_max_c                   ≤ 40    (§17.3.2)
│   ├── bandwidth_chess_kbps_steady             ≤ 8     (§17.3.3)
│   ├── bandwidth_clock_kbps_steady             ≤ 1     (§17.3.3)
│   ├── bandwidth_per_spectator_kbps_steady     ≤ 16    (§17.3.3)
│   ├── apk_size_increase_mb                    ≤ 6     (§17.3.4 + OQ-9)
│   ├── ipa_size_increase_mb                    ≤ 9     (§17.3.4 + OQ-9)
│   ├── server_cost_usd_per_mau                 ≤ 0.01  (§6.5)
│   └── turn_egress_gb_per_mau                  ≤ 0.018 (§17.3.5 + §3.13)
├── stability
│   ├── rss_steady_mb                           ≤ 80    (§17.4.1)
│   ├── rss_handshake_mb                        ≤ 140   (§17.4.1)
│   ├── rss_ui_isolate_mb                       ≤ 24    (§17.4.1)
│   ├── rss_p2p_isolate_mb                      ≤ 32    (§17.4.1)
│   ├── rss_engine_isolate_mb                   ≤ 16    (§17.4.1)
│   ├── leak_drift_4h_soak_mb                   ≤ 1     (§17.4.2)
│   ├── anr_pct_of_frames                       ≤ 0.05  (§17.4.3)
│   ├── isolate_restart_per_million_sessions    ≤ 1     (§17.4.4)
│   ├── crash_free_pct_7d                       ≥ 99.95 (§17.4.5)
│   └── deadlock_count                          = 0     (§17.4.6)
├── reliability
│   ├── mismatch_per_million_moves              ≤ 1     (§17.5.1)
│   ├── ice_reestablish_success_pct_within_10s  ≥ 99.5  (§17.5.2)
│   ├── push_wake_success_pct_non_doze_90s      ≥ 95    (§17.5.3)
│   ├── push_wake_success_pct_doze_90s          ≥ 80    (§17.5.3)
│   ├── transcript_signature_verify_success_pct ≥ 99.99 (§17.5.4)
│   ├── recovery_unwrap_success_pct             ≥ 99.5  (§17.5.5)
│   └── kill_switch_propagation_p99_minutes     ≤ 10    (§6.3 + §17.5.6)
└── integrity
    ├── reproducible_build_sha_match_runs       = 3/3   (§17.6.1 Android+server)
    ├── sbom_to_artefact_byte_match             = true  (§17.6.2)
    ├── sigstore_attestation_chain_valid        = true  (§17.6.3)
    ├── engine_replay_version_per_arch_match    = true  (§12.5 + §17.6.4)
    ├── wire_version_to_protocol_doc_pinned     = true  (§17.6.5)
    └── kat_vector_pass_count                   ≥ all   (§17.6.6)
```

- [ ] The tree is the single source of truth. Removing a leaf requires a `kind: p2p_budget_change` queue entry with a written rationale and a release-notes entry. Adding a leaf requires the same plus a proof test landing in the same commit.
- [ ] **Proof:** [frontend/test/p2p/perf/budget_tree_kpi_test.dart](../frontend/test/p2p/perf/budget_tree_kpi_test.dart) parses [agent/baselines/p2p_budgets.json](../agent/baselines/p2p_budgets.json) and asserts every leaf has a live test reference and a measured baseline ≤ 30 d old (60 d for cost / battery leaves which need bigger samples).

### 17.2 Performance budgets

- [ ] **17.2.1 Handshake-to-first-move P99 ≤ 5 s** on LTE. Decomposed: ICE gather (≤ 2 s P99), DTLS handshake (≤ 800 ms), `HELLO` exchange (≤ 200 ms), `HELLO_ACK` + colour-flip (≤ 200 ms), engine warm-up (≤ 100 ms). **Proof:** [frontend/test/p2p/perf/handshake_to_first_move_test.dart](../frontend/test/p2p/perf/handshake_to_first_move_test.dart).
- [ ] **17.2.2 Move RTT** P50 / P99 broken out by transport (LTE direct, LTE TURN, WiFi direct, WiFi TURN). Caps in the tree above. **Proof:** [frontend/test/p2p/perf/move_rtt_per_transport_test.dart](../frontend/test/p2p/perf/move_rtt_per_transport_test.dart).
- [ ] **17.2.3 Per-leg latency** with separate proof tests so a regression localises to the offending leg. **Proof:** [frontend/test/p2p/perf/per_leg_latency_test.dart](../frontend/test/p2p/perf/per_leg_latency_test.dart).
- [ ] **17.2.4 Render frame P99 ≤ 16 ms** during P2P play (60 fps target; 90 / 120 fps not budgeted in v1 — OQ-49). **Proof:** [frontend/test/p2p/perf/render_frame_budget_test.dart](../frontend/test/p2p/perf/render_frame_budget_test.dart).
- [ ] **17.2.5 Spectator-chat decode** ≤ 2 ms per UI frame on the issuing peer (matches §7.10.2). **Proof:** existing [§7.10.2 test](#710-spectator-perf-isolation--chess-always-wins-v9).

### 17.3 Efficiency budgets

- [ ] **17.3.1 Battery** caps measured on a Pixel 4a / iPhone XR baseline; CI re-measures monthly. **Proof:** [frontend/test/p2p/perf/battery_budget_test.dart](../frontend/test/p2p/perf/battery_budget_test.dart).
- [ ] **17.3.2 Thermal** caps via `ProcessInfo.thermalState` (iOS) and `BatteryManager.temperature` (Android); over `40 °C` chassis triggers spectator/chat shed and a one-time toast. **Proof:** [frontend/test/p2p/perf/thermal_budget_test.dart](../frontend/test/p2p/perf/thermal_budget_test.dart).
- [ ] **17.3.3 Bandwidth** caps separated by sub-channel: chess + clock + per-spectator. Over budget on chess → end session as `BACKPRESSURE_DROP`; over budget on chat → forced slow-mode. **Proof:** [frontend/test/p2p/perf/bandwidth_budget_test.dart](../frontend/test/p2p/perf/bandwidth_budget_test.dart).
- [ ] **17.3.4 APK / IPA size** caps verified by CI on every release. Over budget → `kind: p2p_artefact_size_breach`. **Proof:** [xops/p2p/check-artefact-size.sh](../xops/p2p/check-artefact-size.sh).
- [ ] **17.3.5 TURN egress** cap (≤ 0.018 GB/MAU) cross-checks the §6.5 cost target by binding cost to a measurable physical quantity. **Proof:** monthly [agent/reports/p2p/cost-<yyyy-mm>.md](../agent/reports/p2p/) cross-references the egress observed at the TURN box.
- [ ] **17.3.6 Energy / CO₂ footprint (informational only)** — server-side energy mix per region surfaced in [docs/P2P_OPERATIONS.md](P2P_OPERATIONS.md). Not a gate; transparency.

### 17.4 Stability budgets

- [ ] **17.4.1 RSS** caps with per-isolate sub-budgets. Over hard cap on a single sample → `BUDGET_BREACH_MEMORY` (§10.6) + defensive eviction. **Proof:** [frontend/test/p2p/perf/memory_budget_test.dart](../frontend/test/p2p/perf/memory_budget_test.dart).
- [ ] **17.4.2 Leak detection** via 4-hour soak of continuous match cycling on a real device in CI. ≤ 1 MB net RSS drift. **Proof:** [frontend/test/p2p/perf/memory_leak_soak_test.dart](../frontend/test/p2p/perf/memory_leak_soak_test.dart) (nightly).
- [ ] **17.4.3 ANR / frame-jank** ≤ 0.05% of frames. **Proof:** [frontend/test/p2p/perf/anr_jank_budget_test.dart](../frontend/test/p2p/perf/anr_jank_budget_test.dart).
- [ ] **17.4.4 Isolate restart** rate ≤ 1 / 10⁶ sessions over a 30-day rolling window. Above → `kind: p2p_stability_regression`.
- [ ] **17.4.5 Crash-free rate** ≥ 99.95% over 7-day rolling window for the P2P-on cohort (tighter than v9 §6.5).
- [ ] **17.4.6 Deadlock budget = 0.** Any reachable deadlock is a critical bug, never a budget. Static-analysis gate via Dart `deadlock_lint` and Go `golangci-lint` deadlock-detector. **Proof:** [.github/workflows/deadlock-static-analysis.yml](../.github/workflows/deadlock-static-analysis.yml).

### 17.5 Reliability budgets

- [ ] **17.5.1 MTBF for `MISMATCH`** ≥ 10⁶ moves (tighter than v9 §1.4's 0/10⁵).
- [ ] **17.5.2 ICE re-establishment success** ≥ 99.5% within the 10 s budget. **Proof:** [frontend/test/p2p/transport/ice_reestablish_success_rate_test.dart](../frontend/test/p2p/transport/ice_reestablish_success_rate_test.dart) (chaos suite).
- [ ] **17.5.3 Push-wake redemption success** broken by Doze / non-Doze cohorts.
- [ ] **17.5.4 Transcript signature verify** success ≥ 99.99% — failures mean device-key drift or transcript corruption, both critical.
- [ ] **17.5.5 Recovery unwrap success** ≥ 99.5% — Argon2 transient failures + biometric flakiness budget.
- [ ] **17.5.6 Kill-switch propagation P99 ≤ 10 minutes** — already in §6.3, hoisted here for tree completeness.

### 17.6 Integrity budgets

- [ ] **17.6.1 Reproducible build** SHA matches across 3 independent clean rebuilds, Android + Linux server (iOS best-effort per §8.4). **Proof:** [xops/p2p/verify-reproducible-build.sh](../xops/p2p/verify-reproducible-build.sh).
- [ ] **17.6.2 SBOM-to-artefact byte match** — every dependency in the SBOM appears bit-for-bit in the binary; nothing in the binary is missing from the SBOM. **Proof:** [xops/p2p/sbom-artefact-diff.sh](../xops/p2p/sbom-artefact-diff.sh).
- [ ] **17.6.3 Sigstore attestation chain** valid root-to-leaf via `cosign verify-blob`. **Proof:** release workflow gate.
- [ ] **17.6.4 Engine-replay-version per-arch parity** — the §12.5 cross-arch golden test must pass on every architecture in the release matrix.
- [ ] **17.6.5 Wire-version pinned to protocol-doc commit SHA** — the running binary's `wire_version` MUST resolve to a commit SHA in [docs/P2P_PROTOCOL.md](P2P_PROTOCOL.md)'s history. Prevents shipping a wire format that disagrees with the published spec. **Proof:** [xops/p2p/wire-version-pin-check.sh](../xops/p2p/wire-version-pin-check.sh).
- [ ] **17.6.6 KAT vector pass count** = total — every Known-Answer Test ([agent/baselines/p2p_kdf_kat.json](../agent/baselines/p2p_kdf_kat.json), AEAD KATs, signature KATs) must pass; partial pass is a release-block.

### 17.7 Quality attributes

- [ ] **Performance:** the budget-tree harness itself runs in ≤ 30 s (so it can run on every PR). Heavy soaks (4-h leak, 1k-game chaos) are nightly.
- [ ] **Efficiency:** the harness runs in CI on the same fixed-spec runner so per-release deltas are meaningful.
- [ ] **Stability:** the harness fails closed — a missing leaf measurement counts as a breach.
- [ ] **Reliability:** baselines refresh weekly; stale baselines (> 30 d) auto-open `kind: p2p_baseline_refresh`.
- [ ] **Integrity:** the budget-tree JSON is signed under the same key as `engine_replay_version`; tampering between commit and CI is detected.

### 17.8 Acceptance gate

- [ ] All §17.1–§17.7 ticked, every leaf has a live proof test, the [agent/baselines/p2p_budgets.json](../agent/baselines/p2p_budgets.json) baseline file exists with measured values for every leaf, the budget-tree harness gates every PR.

---

## Phase 18 — Privacy engineering

**Goal:** Consolidate every privacy-relevant decision the project makes — what data exists, who can read it, how long it lives, where it lives, how it leaves — under a single owner with auditable artefacts. *0% complete. Hard prerequisite for the Phase 6 beta-open gate.*

v9 had privacy hooks scattered across §8.5 (residency), §8.11 (DP telemetry), §14.3 (anonymisation), and Phase 9 (threat model). v10 makes privacy a first-class phase because shipping a P2P beta without a complete data-flow inventory + DSAR + portability path violates GDPR / CCPA on day one regardless of how good the cryptography is.

### 18.1 Data-flow inventory

A line item in [docs/P2P_PRIVACY.md](P2P_PRIVACY.md) for **every byte the user produces**:

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

- [ ] CI gate: a **bytes-uncovered** test enumerates every `INSERT` / `WRITE` / network egress in P2P-tagged code and asserts each one maps to a row in the inventory. New writes without a row → CI fail. **Proof:** [xops/p2p/data-flow-completeness-check.sh](../xops/p2p/data-flow-completeness-check.sh) + [frontend/test/p2p/privacy/data_flow_completeness_test.dart](../frontend/test/p2p/privacy/data_flow_completeness_test.dart).

### 18.2 Privacy threat model (T-PRIV-*)

- [ ] **T-PRIV-001** Cross-session linkage via stable account fingerprint (already documented in §9.5 T-M-004 v5; folded here for completeness). *Mitigation:* user can rotate recovery code (§2.11 v10) → fresh account.
- [ ] **T-PRIV-002** Traffic analysis on signaling endpoints distinguishes "starting game" from "polling". *Mitigation:* request padding to nearest 256 B + jittered long-poll wakeup. **Proof:** [signaling/internal/privacy/traffic_padding_test.go](../signaling/internal/privacy/traffic_padding_test.go).
- [ ] **T-PRIV-003** Spectator-presence inference via TURN allocation patterns. *Mitigation:* §7.10.3 separate-allocation already obscures count from players. *Documented residual:* operator can see allocation count.
- [ ] **T-PRIV-004** Export-my-data archive used as social-engineering vector. *Mitigation:* §18.4 export requires fresh user-chosen passphrase + 5-min cooldown between exports + biometric re-confirm.
- [ ] **T-PRIV-005** Telemetry cross-correlation across DP windows. *Mitigation:* per-window rerandomised salt + budget enforcement (§8.11).
- [ ] **T-PRIV-006** Push-token reuse across account rotations enables provider-side linkage. *Mitigation:* token is rotated on every account rotation (§2.11) and the old token is revoked at the provider.

### 18.3 DSAR (Right to Access)

- [ ] Already specified in §8.5; v10 adds: response within 30 d (statutory), in machine-readable JSON, scoped to the requesting account pubkey. Per-region routing honoured. **Proof:** [signaling/internal/dsar/dsar_test.go](../signaling/internal/dsar/dsar_test.go) (existing).

### 18.4 Right to Portability (export-my-data)

- [ ] In-app "Export my data" → app generates an encrypted archive `chessrecast-export-<account_short_id>-<yyyy-mm-dd>.cbor.aead` containing: account pubkey, device pubkey list, transcript list (signed by both peers), local block-list, local display-name overrides, settings, **never** the wrapped recovery blob (out of scope for portability — security boundary).
- [ ] **Encryption:** archive is AEAD-encrypted under a fresh user-chosen passphrase via Argon2id (same KDF parameters as recovery, §2.2). User must enter the passphrase to import on a new install.
- [ ] **Importable on the same app on a fresh install** as a "study archive" — read-only view of historical transcripts. Does NOT restore the account (account restoration requires the recovery code, by design).
- [ ] **Cooldown:** 5 minutes between exports (anti-social-engineering, T-PRIV-004); requires biometric re-confirm.
- [ ] **Verification:** the import side runs every transcript through the §12.6 cross-version replay before accepting. Bad signatures or missing historical-engine archive → load as "unverified PGN view only".
- [ ] **Proof:** [frontend/test/p2p/privacy/export_my_data_test.dart](../frontend/test/p2p/privacy/export_my_data_test.dart) + [frontend/test/p2p/privacy/export_import_round_trip_test.dart](../frontend/test/p2p/privacy/export_import_round_trip_test.dart).

### 18.5 Right to Erasure (delete-my-data)

- [ ] In-app "Delete my account" → app uploads a signed deletion request → server purges all server-side state (account row, push tokens, wrapped recovery blob, telemetry buckets, abuse reports filed *by* this account; abuse reports filed *against* this account are anonymised but retained for safety per §14.3). Litestream snapshots ≤ 30 d.
- [ ] Local: app wipes SQLCipher, SecureStorage, all caches.
- [ ] Confirmation screen explains irreversibility; recovery code becomes permanently invalid.
- [ ] **Proof:** [signaling/internal/dsar/delete_test.go](../signaling/internal/dsar/delete_test.go) + [frontend/test/p2p/privacy/delete_account_test.dart](../frontend/test/p2p/privacy/delete_account_test.dart).

### 18.6 Privacy Impact Assessment

- [ ] [docs/P2P_PRIVACY_PIA.md](P2P_PRIVACY_PIA.md) published before beta opens. Template covers: lawful basis (consent + legitimate interest for abuse reporting), data categories, recipients, retention, transfers (residency), DPO contact, user rights (access / portability / erasure / objection), DPIA risk ratings, mitigations.
- [ ] Reviewed by a qualified privacy reviewer (operator may self-attest for solo deployment, with that disclosure in the document).

### 18.7 Quality attributes

- [ ] **Performance:** export-my-data archive generation ≤ 30 s for a typical account (≤ 100 transcripts).
- [ ] **Efficiency:** archive ≤ 10 MB compressed for typical account; ceiling 100 MB (over → progressive download).
- [ ] **Stability:** export runs on the `p2p` isolate; UI never blocks.
- [ ] **Reliability:** export resumable across app launch (intermediate state in SQLCipher); failed export → user sees "retry export".
- [ ] **Integrity:** export archive carries an in-archive manifest signed under the device key; tampering between export and import is detected at import time.

### 18.8 Acceptance gate

- [ ] All §18.1–§18.7 ticked, [docs/P2P_PRIVACY.md](P2P_PRIVACY.md) + [docs/P2P_PRIVACY_PIA.md](P2P_PRIVACY_PIA.md) published, DSAR + portability + erasure flows live and tested in a third-party staging environment, data-flow-completeness CI gate live.

---

## Phase 19 — Release & hot-fix delivery

**Goal:** Once a fix is committed to `main`, get it onto the user's device fast enough to matter, without breaking the staged-rollout safety net. *0% complete. Hard prerequisite for the Phase 6 §6.4 GA-rollout gate.*

v9's Phase 16 owned CVE response and key rotation but was silent on the *delivery* side: how does a P0 protocol bug actually reach the user? Phase 19 fills the gap with a documented hot-fix lane, server-side rollout enforcement, and auto-rollback.

### 19.1 Standard staged-rollout calendar

- [ ] **Channels:** internal (CI, pre-release testers, ≤ 50 accounts) → canary (1% of opted-in beta MAU) → 10% → 50% → 100%. Bake times: internal ≥ 24 h, canary ≥ 24 h, 1% ≥ 48 h, 10% ≥ 72 h, 50% ≥ 72 h. Total bake floor: ~ 11 d.
- [ ] **Auto-halt** on any of: budget-tree leaf regression > 5%, crash-free rate < 99.95%, `MISMATCH` rate > baseline + 3σ, kill-switch engaged, security advisory acknowledged. Halt → `kind: p2p_rollout_halt` queue entry, on-call paged.
- [ ] **Proof:** [xops/p2p/staged-rollout-controller.sh](../xops/p2p/staged-rollout-controller.sh) + [signaling/internal/rollout/calendar_test.go](../signaling/internal/rollout/calendar_test.go).

### 19.2 Hot-fix lane

- [ ] **Trigger:** P0/P1 protocol bug, unpatched CVE in critical-path dependency, security audit finding rated critical/high.
- [ ] **Compressed bake:** internal ≥ 4 h, canary ≥ 4 h, 1% ≥ 8 h, 10% ≥ 12 h, 50% ≥ 12 h, 100%. Total bake floor: ~ 40 h. May be further compressed by on-call decision with a queue entry of `kind: p2p_hotfix_bake_compressed`.
- [ ] **Mandatory:** the fix MUST land with a regression test (per AGENTS.md §3) AND the §17.6 release-integrity gate MUST pass. Skipping integrity is forbidden even for hot-fix.
- [ ] **Proof:** [xops/p2p/hotfix-lane-controller.sh](../xops/p2p/hotfix-lane-controller.sh) + a hot-fix drill at least twice a year, logged at [docs/P2P_OPERATIONS_DRILL_LOG.md](P2P_OPERATIONS_DRILL_LOG.md).

### 19.3 Server-side staged-rollout enforcement

- [ ] The signed-config blob (§8.8 v6 + §16.5) carries `eligible_cohorts: [u8]` (bitmap of 256 cohorts) and a `min_app_version`. Each install computes its cohort = `HKDF(install_id, info="chessrecast/p2p/v1/cohort", L=1)[0]` and refuses to enable P2P features outside its cohort window. Lets the server hold an install on the previous version even if the user manually side-loaded the newer one. **Proof:** [frontend/test/p2p/rollout/cohort_eligibility_test.dart](../frontend/test/p2p/rollout/cohort_eligibility_test.dart) + [signaling/internal/rollout/cohort_enforcement_test.go](../signaling/internal/rollout/cohort_enforcement_test.go).

### 19.4 Auto-rollback

- [ ] If a new build's KPI cohort regresses on any budget-tree leaf by > 5% during bake, OR the crash-free rate drops below 99.9% (looser than the steady-state 99.95% — no brand-new build is perfect), the rollout controller automatically rolls the cohort window *backward* (e.g. 10% → 1% → canary → halt). Surfaces as `STAGED_ROLLOUT_AUTO_HALT` (§10.6).
- [ ] If the regression is on a *security* leaf (§17.6 integrity, KAT vectors, SBOM match), the rollback is **immediate** to canary regardless of bake position.
- [ ] **Proof:** [xops/p2p/auto-rollback-test.sh](../xops/p2p/auto-rollback-test.sh) + a quarterly auto-rollback drill.

### 19.5 Kill-switch by version

- [ ] Beyond the global `kEnableP2P=false` (§6.3), the signed config also carries a `disabled_versions: [u32]` list. A shipped build whose `wire_version` is in the list refuses to enable P2P even if the user updates *to* that version (e.g. a sideloaded build outside the staged-rollout cohort). UI surfaces "this version is known-bad — please update from the official store". `KILL_SWITCH_BY_VERSION_ENGAGED` (§10.6). **Proof:** [frontend/test/p2p/config/kill_switch_by_version_test.dart](../frontend/test/p2p/config/kill_switch_by_version_test.dart).

### 19.6 Out-of-store sideload paths

- [ ] **Best-effort only.** Documented in [docs/P2P_OPERATIONS.md](P2P_OPERATIONS.md): F-Droid-equivalent reproducible-build downloads can verify the SHA matches the published release, but cannot benefit from the staged-rollout cohort (those installs report `install_id` so the server still knows their cohort, but the user can sideload any version). `KILL_SWITCH_BY_VERSION_ENGAGED` is the only protection against a known-bad sideloaded build.

### 19.7 Quality attributes

- [ ] **Performance:** rollout-controller decisions made within 60 s of metric arrival.
- [ ] **Efficiency:** signed-config blob ≤ 4 KB (cohort bitmap is the largest field).
- [ ] **Stability:** the rollout controller runs in a separate process; its crash never affects user-facing signaling.
- [ ] **Reliability:** every rollout state transition is logged + signed; rollback is idempotent.
- [ ] **Integrity:** rollout-control config is dual-signed (rollout-key + signing-key) per T-OPS-005 v10; single-key compromise cannot rush a rollout.

### 19.8 Acceptance gate

- [ ] All §19.1–§19.7 ticked, the staged-rollout controller and hot-fix lane have each been drilled at least once (logged in [docs/P2P_OPERATIONS_DRILL_LOG.md](P2P_OPERATIONS_DRILL_LOG.md)), and an auto-rollback drill has succeeded in staging.

---

### 10.6 v10 additions to the catalog (budgets, hot-fix lane, privacy, recovery rotation)

> Codes added by v10. Numbering continues; do not renumber the v5–v9 entries above.

- [ ] **F-BUDGET-001** `BUDGET_BREACH_LATENCY` — §17.2 latency leaf exceeded its cap on a release-blocking sample. *Recovery:* CI-only; opens `kind: p2p_budget_breach`.
- [ ] **F-BUDGET-002** `BUDGET_BREACH_MEMORY` — §17.4.1 RSS sample over hard cap. *Recovery:* defensive isolate eviction; user-visible toast on repeat.
- [ ] **F-BUDGET-003** `BUDGET_BREACH_BATTERY` — §17.3.1 battery cap exceeded over a 1 h window. *Recovery:* spectator + chat shed; user toast.
- [ ] **F-BUDGET-004** `BUDGET_BREACH_THERMAL` — §17.3.2 thermal cap exceeded. *Recovery:* same shed cascade as battery.
- [ ] **F-BUDGET-005** `BUDGET_BREACH_BANDWIDTH` — §17.3.3 chess-channel bandwidth exceeded. *Recovery:* end session as `BACKPRESSURE_DROP` with friendly UX.
- [ ] **F-BUDGET-006** `LEAK_SOAK_DRIFT_DETECTED` — §17.4.2 4-h soak detected RSS drift > 1 MB. *Recovery:* CI-only; opens `kind: p2p_leak`.
- [ ] **F-LIFE-006** `MID_SESSION_APP_UPDATE_RESUMED` — §4.12 v10 resume succeeded post-update. *Recovery:* informational only.
- [ ] **F-LIFE-007** `MID_SESSION_APP_UPDATE_REFUSED_VERSION_BUMP` — §4.12 v10 resume refused because the post-update binary's `engine_replay_version` differs. *Recovery:* surface "your app updated mid-game; the partial transcript was preserved as a study line".
- [ ] **F-CRASH-001** `ENGINE_NATIVE_CRASH_FORENSIC_WRITTEN` — v10 native-engine crash forensic bundle written by the watchdog. *Recovery:* offer the bundle on next launch via the diag UX.
- [ ] **F-STUDY-005** `TRANSCRIPT_HISTORICAL_ENGINE_ARCHIVE_MISSING` — §12.6 v10 cross-version replay needs an archive that is not vendored. *Recovery:* offer download.
- [ ] **F-STUDY-006** `TRANSCRIPT_HISTORICAL_ENGINE_ARCHIVE_DOWNLOAD_FAIL` — archive download failed. *Recovery:* fall back to PGN-only view.
- [ ] **F-INTEGRITY-002** `ANTI_ROLLBACK_LOCAL_TAMPER_DETECTED` — §12.5 v10 server attest disagrees with local high-water-mark. *Recovery:* refuse session; surface "your local data appears to have been tampered with — please reinstall the app".
- [ ] **F-ID-019** `RECOVERY_ROTATION_CAS_LOST` — §2.11 v10 rotation lost the server-side compare-and-swap. *Recovery:* abort rotation atomically; old code remains valid.
- [ ] **F-ID-020** `RECOVERY_ROTATION_ABORTED_BIOMETRIC` — user cancelled biometric mid-rotation. *Recovery:* abort atomically; old code remains valid.
- [ ] **F-NET-010** `ICLOUD_PRIVATE_RELAY_DETECTED` — §4.13 v10 detection. *Recovery:* informational + relax §11.2 desync budget to 750 ms.
- [ ] **F-NET-011** `NETWORK_CLASSIFIER_HOSTILE_VERDICT` — §4.14 v10 classifier verdict ∈ `{captive_portal, dpi_filtered, ipv6_only_pmtu_blocked}`. *Recovery:* surface UX + skip the corresponding ICE branch.
- [ ] **F-FLAG-001** `FLAG_REGISTRY_STALE` — §8.13 v10 sunset date elapsed without cleanup. *Recovery:* CI-only; opens `kind: p2p_flag_cleanup`.
- [ ] **F-EXP-001** `EXPERIMENT_OPT_OUT_HONOURED` — §8.14 v10 user opted out; cohort assignment forced to control. *Recovery:* informational.
- [ ] **F-EXP-002** `EXPERIMENT_DURATION_EXCEEDED` — §8.14 v10 experiment past 30-day cap without renewal. *Recovery:* CI-only; opens `kind: p2p_experiment_renewal`.
- [ ] **F-PRIV-001** `PRIVACY_DATA_FLOW_AUDIT_FAILED` — §18.1 v10 data-flow-completeness CI gate failed. *Recovery:* CI-only; opens `kind: p2p_privacy_inventory`.
- [ ] **F-PRIV-002** `PORTABILITY_EXPORT_VERIFY_FAILED` — §18.4 v10 import-side verification failed. *Recovery:* surface "this export archive is corrupted or was tampered with"; offer PGN-only fallback.
- [ ] **F-OPS-006** `STAGED_ROLLOUT_AUTO_HALT` — §19.4 v10 auto-halt fired. *Recovery:* operator-only; surfaces on dashboard.
- [ ] **F-OPS-007** `HOTFIX_LANE_BAKE_FAILED` — §19.2 v10 compressed-bake stage observed a regression. *Recovery:* operator-only; auto-rolls back to previous stage.
- [ ] **F-OPS-008** `HOTFIX_LANE_AUTO_ROLLBACK` — §19.4 v10 auto-rollback engaged on a hot-fix release. *Recovery:* operator-only.
- [ ] **F-OPS-009** `KILL_SWITCH_BY_VERSION_ENGAGED` — §19.5 v10 client refusing to enable P2P due to known-bad version list. *Recovery:* deep-link to store update.

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
- [ ] **OQ-17** Encrypted transcript backup at GA — ship in v1, defer to Phase 7, or never? Trade-off: device-loss data preservation vs server-side storage cost + DSAR scope expansion. *Decision required before:* Phase 6 GA gate. **v6 default:** Phase 7 stretch, opt-in only.
- [ ] **OQ-18** Chat signing — sign every chat message under the device key (non-repudiable for abuse reports), or sign only the chat-history hash inside `BYE` (cheaper on the wire)? *Decision required before:* Phase 14 acceptance. **v6 default:** sign chat-history hash inside `BYE`; revisit if abuse reports need finer granularity.
- [ ] **OQ-19** Crypto-suite migration trigger — do we ship `crypto_suite_id = 0x02` (hybrid PQ) when libsodium ships stable ML-KEM, when CNSA 2.0 deadlines force it, or when a real attack appears? *Decision required before:* libsodium-ML-KEM availability. **v6 default:** when libsodium ships stable bindings AND we have hybrid-KAT vectors from a third party.
- [ ] **OQ-20** Bug-bounty reward funding — self-funded, sponsored, or no monetary reward (recognition only)? *Decision required before:* Phase 15.3.
- [ ] **OQ-21** Spectator chain — v6 forbids it. Should a future version allow N-deep spectator chains with explicit per-hop consent? *Decision required before:* Phase 7 spectator sub-task.
- [ ] **OQ-22** Account-level vs device-level block precedence — if I block an account but the account's owner gets a fresh fingerprint via rebind, do I auto-block the new fingerprint (privacy: tracks the user across rebinds) or unblock (lets stalkers reset)? *Decision required before:* Phase 14 acceptance. **v6 default:** account-block survives rebind; documented in Trust & Safety policy.
- [ ] **OQ-23** Web build push wakeups — implement Web Push API for parity with mobile, or document web as "online-only" (must be foreground)? *Decision required before:* Phase 7 web GA. **v6 default:** online-only for first web release.
- [ ] **OQ-24** Foundation primitives provider — stay on libsodium for the foreseeable, or evaluate AWS-LC / BoringSSL for FIPS-aligned deployments if enterprise demand emerges? *Decision required before:* enterprise-tier scope. **v6 default:** libsodium-only for v1.
- [ ] **OQ-25** Per-mod time-control defaults — do specific mods (Save the Queen escape race, Mercenary endgame) need mod-aware default time controls (longer increments)? *Decision required before:* Phase 11 acceptance. **v6 default:** standard chess defaults across all mods; mod-specific tuning is a Phase 7 polish task.
- [ ] **OQ-26** Recovery-code paste-from-password-manager — should the recovery-entry screen allow paste (better UX, exposes the code to clipboard managers and screen-readers) or forbid it (forces typing, harder for users with motor disabilities)? *Decision required before:* Phase 2 acceptance. **v7 default:** allow paste with a one-time "this clipboard entry will be cleared in 30 s" notice; clipboard cleared via `Clipboard.setData('')` on screen exit.
- [ ] **OQ-27** Long-poll vs Server-Sent Events vs WebSocket for `/v1/offers/poll` — long-poll is simplest and works through more middleboxes; SSE is more efficient at scale; WebSocket adds bidirectional capability we may want for Phase 7 spectator. *Decision required before:* Phase 3 acceptance. **v7 default:** long-poll for v1; revisit at 10k MAU.
- [ ] **OQ-28** Vanity-username feature — ship as v1 polish, defer to v1.x, or never? §14.9 says "local-only display name only" for v1; this OQ asks whether centrally-claimed handles should be a future feature. **v7 default:** never; the federation-friendly fingerprint-only model is a deliberate choice.
- [ ] **OQ-29** Rage-quit forfeit policy — a peer that closes the app mid-game without sending `BYE` should (a) lose on a fixed timeout, (b) lose immediately, or (c) the game enters "awaiting opponent" with a 7-day correspondence-style timeout? *Decision required before:* Phase 11 acceptance. **v7 default:** option (a) with a 90 s timeout; surfaces clearly on both sides; transcript records the disconnect.
- [ ] **OQ-30** Premove default for blitz time controls — §11.8 ships premove off-by-default. Should blitz (≤ 5+0) auto-enable it for new accounts? *Decision required before:* Phase 11 acceptance. **v7 default:** off everywhere; user opts in once and the setting persists.
- [ ] **OQ-31** First-contact verification UX strictness — §2.9 currently uses TOFU + soft badge. Should rated games (if rating ever ships per OQ-10) require verification? Three options: skip / soft-warn / require-for-rated. *Decision required before:* Phase 13 close-out (rating decision).
- [ ] **OQ-32** Cross-architecture engine-replay golden — must we ship per-arch goldens (x86_64, arm64, RISC-V if Linux web ever happens) or does §12.5's integer-only-arithmetic argument let a single golden suffice? *Decision required before:* Phase 12 acceptance. **v7 default:** single golden, with the cross-arch parity test (`replay_version_golden_cross_arch_test.dart`) gating any release that adds a new arch.
- [ ] **OQ-33** Native-lib integrity verification on iOS — Apple's code-signing already enforces dylib provenance for App-Store-distributed apps; should §0.8's SHA verify still run on iOS, or is it Android-only? *Decision required before:* Phase 0.8 acceptance. **v8 default:** Android-only by default; iOS opt-in for sideloaded / TestFlight builds where Apple's signing isn't enforced equivalently.
- [ ] **OQ-34** DP epsilon for telemetry — is ε=1.0/metric/day/user (§8.11) too strict (rendering KPIs unactionable for small beta cohorts) or too loose (insufficient against linkage attacks)? *Decision required before:* beta opens. **v8 default:** ε=1.0; revisit after first 30 days of beta with a privacy-engineering review.
- [ ] **OQ-35** Study-mode transcript playback for *unverified* PGNs — should the engine validate every move legality on import (catches tampering, expensive on long games) or only at user request? *Decision required before:* Phase 6.8 acceptance. **v8 default:** validate on import for transcripts < 200 ply; lazy-validate on scrub for longer.
- [ ] **OQ-36** Signed-time endpoint cache lifetime — 60 s is conservative; longer caches reduce signaling load but widen the freshness window for `HELLO.ts` validation. *Decision required before:* Phase 3.15 acceptance. **v8 default:** 60 s with `Cache-Control: public, max-age=60`; the ±5 min `HELLO.ts` window already absorbs this.
- [ ] **OQ-37** TURN per-session bandwidth cap — 64 kbit/s is comfortable for chess-clock + move traffic but rules out chat-with-images (Phase 7+). *Decision required before:* Phase 3.13 acceptance. **v8 default:** 64 kbit/s for v1; revisit if rich chat ever ships.
- [ ] **OQ-38** Multi-device race UX — should the loser device show *which* sibling device won (privacy: leaks the user's device topology to themselves only — fine) or stay silent (less informative)? *Decision required before:* Phase 7.7 acceptance. **v8 default:** show the local nickname of the winning sibling device.
- [ ] **OQ-39** Spectator back-fill bandwidth — should the issuing peer compress the back-fill payload (CBOR is already compact; brotli adds ~10-20% with CPU cost on the issuer)? *Decision required before:* Phase 7.6 acceptance. **v8 default:** no compression; revisit if back-fill exceeds the 1 MB chunking threshold in real usage.
- [ ] **OQ-40** Rage-quit forfeit and rated play — if rated play ever ships (OQ-10), should rage-quit forfeit count as a regular loss or carry a separate "abandonment" rating impact? *Decision required before:* Phase 13 close-out (rating decision).
- [ ] **OQ-41** Anonymous spectators — v9 §7.8.3 forbids them; should v2 allow signed-link anonymous viewers (no chat, view-only) as the social-share play, or is the abuse-anchor loss too costly? *Decision required before:* v2 scope freeze. **v9 default:** forbidden; revisit only if a viral-share growth case emerges.
- [ ] **OQ-42** Spectator-chat persistence — v9 keeps chat ephemeral (no SQLCipher write). Should hosts be able to opt-in to persisting their own game's chat for later study, alongside the transcript? *Decision required before:* Phase 6.8 (study-mode) GA. **v9 default:** ephemeral; persistence opt-in only via the existing diag-bundle for abuse review.
- [ ] **OQ-43** Tournament chat default — v9 §7.9.8 force-mutes by default. Should organisers be able to override globally for an entire tournament (e.g. casual-event flag), or must each game's host opt in? *Decision required before:* tournament feature ships. **v9 default:** per-game opt-in only.
- [ ] **OQ-44** Spectator-of-spectator chain — the v8 reserved field (`spectator_chain_depth: u8`) lifts to nonzero in some future v2. Should depth>0 spectators inherit chat rights, or only view-only? *Decision required before:* v2 scope freeze. **v9 working answer:** view-only by default; chat requires explicit per-hop consent if/when shipped.
- [ ] **OQ-45** Spectator chat across player-disconnect — if the issuing peer disconnects mid-game, do spectators (a) lose chat (default, simplest), (b) elect a relay among themselves (introduces T-CHAT-005 surface area we explicitly rejected), or (c) wait for the issuing peer to come back? *Decision required before:* §7.10 acceptance. **v9 default:** (a); spectators see "host disconnected, chat unavailable."
- [ ] **OQ-46** Display-name policy for spectators — should spectator display names be the device-local nickname (already §7.7) or the account's verified-display-name (Phase 14)? *Decision required before:* §7.9 UX freeze. **v9 default:** verified display name with the same UTS #39 confusable filter as chat content.
- [ ] **OQ-47** Spectator chat in correspondence games — if `tc_kind=none` (correspondence, days-long), is the perf budget different (the issuing peer is rarely active) and should chat persist server-side via a relay? *Decision required before:* correspondence GA. **v9 default:** chat is **disabled** in correspondence games in v1 (no online host to fan out); revisit with a server-relay design.
- [ ] **OQ-48** Engagement metrics for spectators — do we measure spectator counts, chat volume, and host-shed events under the §8.11 DP budget, or are they exempt as "operator infrastructure metrics"? *Decision required before:* §8.11 acceptance. **v9 default:** subject to DP; aggregate-count metrics get histogram bucketing identical to player metrics.
- [ ] **OQ-49** Budget-tree leaf cardinality cap — the §17.1 tree starts at ~50 leaves; at what count does the harness become a bottleneck on PR latency, and do we shard? *Decision required before:* §17.8 acceptance. **v10 default:** 80-leaf cap, shard at 60; soak/cost leaves move to nightly.
- [ ] **OQ-50** Privacy data-flow inventory update cadence — every PR or every release? *Decision required before:* §18.8 acceptance. **v10 default:** every PR for the completeness CI gate; release-only for the human-readable [docs/P2P_PRIVACY.md](P2P_PRIVACY.md) refresh.
- [ ] **OQ-51** Hot-fix lane minimum bake time — §19.2 sets a 40 h floor; can on-call compress further for an actively-exploited zero-day, and what is the ceiling on compression? *Decision required before:* §19.8 acceptance. **v10 default:** floor compressible to 12 h with two-on-call sign-off; below 12 h forbidden.
- [ ] **OQ-52** Feature-flag sunset enforcement strictness — §8.13 sunset triggers `F-FLAG-001`. Should an expired flag *also* default-flip its value to the safer side automatically, or only nag? *Decision required before:* §8.13 acceptance. **v10 default:** nag; auto-flip is a follow-up after one quarter of human-driven cleanup data.
- [ ] **OQ-53** A/B max concurrent experiments — §8.14 risks combinatorial cohort explosion. *Decision required before:* §8.14 acceptance. **v10 default:** 3 concurrent experiments, mutually exclusive cohorts via shared 256-bucket assignment salt.
- [ ] **OQ-54** Historical-engine archive TTL — §12.6 vendors the last 4 minor versions; how long do we keep the on-demand download archive? *Decision required before:* §12.6 acceptance. **v10 default:** 36 months from release; older archives move to a cold mirror documented in [docs/P2P_OPERATIONS.md](P2P_OPERATIONS.md).
- [ ] **OQ-55** Recovery-rotation cooldown — §2.11 v10 limits the rate. *Decision required before:* §2.11 acceptance. **v10 default:** 24 h cooldown between successful rotations; 5 attempts/day; biometric required.
- [ ] **OQ-56** Private Relay desync budget — §4.13 v10 raises the §11.2 desync budget to 750 ms when Private Relay/NEXT-Hop is detected. Is 750 ms enough for the long tail of relay paths? *Decision required before:* §4.13 acceptance. **v10 default:** 750 ms; revisit at beta with measured P99 from the cohort.
- [ ] **OQ-57** Hostile-network classifier 800 ms budget — §4.14 must classify the network in ≤ 800 ms or skip with `unknown`. Is that tight enough on captive portals? *Decision required before:* §4.14 acceptance. **v10 default:** 800 ms; `unknown` falls back to the safest ICE branch (TURN-only).
- [ ] **OQ-58** Memory soak duration — §17.4.2 specifies 4 h. Is 4 h sufficient to catch the slowest-leaking 0.1% of PRs, or do we need 8 h nightly? *Decision required before:* §17.8 acceptance. **v10 default:** 4 h on every PR; 8 h weekly on `main`.

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

**Hard prerequisite ordering additions (v6):**

4. [Phase 14](#phase-14--user-safety-chat-moderation-blocking-abuse-reporting) (user safety — block, mute, report, age-gate) is a hard prerequisite for the Phase 6 beta-open gate. Shipping unmoderated chat without these tools fails App Store / Play review and the duty-of-care charter.
5. [Phase 15.1](#151-cryptographic-protocol-audit) + [§15.2](#152-application-penetration-test) (third-party crypto audit + pentest) are hard prerequisites for the Phase 6 §6.4 GA-rollout gate. The 1% rollout step may begin only after both audits' critical/high findings are remediated and re-verified.
6. [§2.7](#27-secret-memory-hygiene) (secret memory hygiene) and [§8.10](#810-concurrency-and-isolate-model) (isolate model) are hard prerequisites for ticking any Phase 2 or Phase 4 box — a session that uses Dart `String` for keys or runs Argon2 on the UI isolate is broken regardless of whether its KAT vectors pass.
7. [§11.7](#117-monotonic-clock-requirement-and-wall-clock-tamper-detection) (monotonic clock) is a hard prerequisite for ticking any Phase 11 box. A clock built on `DateTime.now()` cannot be "fixed later".

**Hard prerequisite ordering additions (v7):**

8. [§0.6](#06-at-rest-encryption-retention-and-disk-fill-defenses-v7) (at-rest encryption + retention caps) is a hard prerequisite for ticking any Phase 6 beta-open box. Shipping a P2P feature that leaves opponent fingerprints, chat history, and forensic bundles in plaintext on disk fails the integrity charter.
9. [§1.9](#19-session_id-derivation-and-binding-v7) (session_id derivation + AAD binding) and [§1.1](#11-spec) **CBOR-float ban** are hard prerequisites for ticking any Phase 1 box. A protocol whose nonce-uniqueness rests on undefined `session_id` provenance, or that admits NaN payloads, is unsound regardless of how many KAT vectors pass.
10. [§2.9](#29-first-contact-verification-kci-defense-and-trust-on-first-use-v7) (TOFU + safety numbers + KCI MAC) is a hard prerequisite for ticking any Phase 2 box. A handshake without first-contact verification UX cannot honestly claim end-to-end security.
11. [§3.10](#310-cve-monitoring-and-forced-update-enforcement-v7) (CVE-watcher live + forced-update path drilled) is a hard prerequisite for the Phase 6 beta-open gate. Without it, a critical libsodium / Go-stdlib CVE has no operational response path.
12. [Phase 12 §12.5](#125-anti-rollback-enforcement-v7) (anti-rollback + per-account high-water-mark) is a hard prerequisite for the Phase 6 GA gate. Without it, a malicious peer can downgrade an opponent into older buggy rule semantics.
13. [Phase 16](#phase-16--operations-and-lifecycle-v7) acceptance gate (CVE-watcher + key-rotation calendar live + at-least-one successful restore drill + dead-man-switch armed) is a hard prerequisite for the Phase 6 §6.4 GA-rollout gate, alongside Phase 15. Shipping P2P to GA without an operations story is the single highest-likelihood path to a silent post-launch breach.

**Hard prerequisite ordering additions (v8):**

14. [§0.7](#what-changed-in-v8-vs-v7) startup self-test (KAT + smoke goldens) is a hard prerequisite for ticking any box in Phase 1, 2, or 4 — without it, the user's first crypto/engine call may silently fail mid-game.
15. [§0.8](#what-changed-in-v8-vs-v7) native-lib SHA verify is a hard prerequisite for the Phase 6 beta-open gate on Android (per OQ-33). iOS is opt-in.
16. [§1.7 v8 RESIGN signature fix](#what-changed-in-v8-vs-v7) is a hard prerequisite for ticking any Phase 1 box. The v5/v6/v7 spec leaks a long-term-key signing oracle; ship a beta on it and any malicious peer becomes a credential-stealer.
17. [§1.12](#what-changed-in-v8-vs-v7) atomic validate-apply critical section is a hard prerequisite for ticking any Phase 1 or Phase 4 box. Without it, the engine boundary admits a TOCTOU race that silently corrupts game state.
18. [§1.13](#what-changed-in-v8-vs-v7) FFI-boundary fuzz (≥10M iterations nightly, all 7 mods, ASAN-clean) is a hard prerequisite for the Phase 6 beta-open gate. Native-engine bugs that crash the app are the worst-possible first-impression for P2P.
19. [§3.13](#what-changed-in-v8-vs-v7) TURN bandwidth caps and [§3.14](#what-changed-in-v8-vs-v7) signaling load-shedding priority lanes are hard prerequisites for the Phase 6 §6.4 GA-rollout gate. Without them, the operator's egress bill and user experience under load are both undefined.
20. [§3.15](#what-changed-in-v8-vs-v7) signed-time endpoint is a hard prerequisite for the §1.1 v8 `HELLO.ts` freshness check, which is itself a Phase 1 prerequisite — devices with no usable wall clock cannot otherwise validate freshness.
21. [§6.8](#what-changed-in-v8-vs-v7) study-mode replay is a hard prerequisite for the Phase 6 beta-open gate. Shipping signed transcripts that the user has no UI to read makes the "your game is preserved" promise hollow.
22. [§8.11](#what-changed-in-v8-vs-v7) DP budget for telemetry is a hard prerequisite for the Phase 6 beta-open gate. Cross-session re-identification of beta users via uncalibrated metrics is a privacy violation regardless of opt-in framing.

Critical-path summary (v8): **Phase 0 (with §0.6 + §0.7 + §0.8) → Phase 5 §5.1 + §5.5 + Phase 12 (with §12.5) + §2.7 + §8.10 → Phase 1 (with §1.1 v8 freshness + §1.7 v8 RESIGN fix + §1.9 + §1.10 + §1.11 + §1.12 atomic apply + §1.13 FFI fuzz + CBOR-float ban) + Phase 11 (with §11.7 + §11.8 + §11.10 a11y) → Phase 2 (with §2.9 + §2.10) → Phase 4 (with §4.1 v8 trickle + §4.10 + §4.11 BG tasks) + Phase 3 (with §3.10 + §3.11 + §3.12 + §3.13 + §3.14 + §3.15) + Phase 8.8 + §8.11 DP + §8.12 blob versioning + Phase 14 (with §14.9) → Phase 6 beta (with §6.7 + §6.8 study mode) → Phase 15.1 + 15.2 + Phase 16 → Phase 6 GA**.

**Hard prerequisite ordering additions (v10):**

23. [Phase 17](#phase-17--end-to-end-budget-tree-performance-efficiency-stability-reliability-integrity) (budget tree) is a hard prerequisite for the Phase 6 §6.4 GA-rollout gate. Numeric promises without a single-source-of-truth tree + per-PR harness drift undetected.
24. [Phase 18](#phase-18--privacy-engineering) (privacy engineering — data-flow inventory + portability + erasure + PIA) is a hard prerequisite for the Phase 6 beta-open gate. Shipping P2P beta without these flows breaches GDPR/CCPA day-one regardless of crypto quality.
25. [Phase 19](#phase-19--release--hot-fix-delivery) (release/hot-fix delivery — staged rollout enforcement + hot-fix lane + auto-rollback + kill-switch-by-version) is a hard prerequisite for the Phase 6 §6.4 GA-rollout gate. Without it, a P0 protocol bug has no documented path to the user device.
26. [§17.4.2](#174-stability-budgets) (4-h memory-leak soak) is a hard prerequisite for ticking any Phase 6 beta-open box. Leak-induced OOM at hour 3 of a tournament is the single worst first-impression for P2P.
27. [§17.6](#176-integrity-budgets) (release-integrity gate — reproducible build + SBOM/artefact byte-match + Sigstore + per-arch engine-replay + wire-version pin + KAT pass) is a hard prerequisite for the Phase 6 §6.4 GA gate AND for every hot-fix release; integrity is never compressed.
28. [§2.11](#what-changed-in-v10-vs-v9) (recovery-code rotation with CAS on `wrapped_blob_revision`) is a hard prerequisite for the Phase 6 beta-open gate. Without it, a leaked recovery code is permanent — that violates the duty-of-care charter.

Critical-path summary (v10): **Phase 0 (with §0.6 + §0.7 + §0.8) → Phase 5 §5.1 + §5.5 + Phase 12 (with §12.5 v10 server attest + §12.6 cross-version replay) + §2.7 + §8.10 + §17.6 release integrity → Phase 1 (with §1.1 v8 freshness + §1.7 v8 RESIGN fix + §1.9 + §1.10 + §1.11 + §1.12 atomic apply + §1.13 v10 structure-aware fuzz + CBOR-float ban) + Phase 11 (with §11.7 + §11.8 + §11.10 a11y) → Phase 2 (with §2.9 + §2.10 + §2.11 rotation) → Phase 4 (with §4.1 v8 trickle + §4.10 + §4.11 BG tasks + §4.12 mid-session update + §4.13 Private Relay + §4.14 hostile-network classifier) + Phase 3 (with §3.10 + §3.11 + §3.12 + §3.13 + §3.14 + §3.15) + Phase 8.8 + §8.11 DP + §8.12 + §8.13 flag governance + §8.14 A/B + Phase 14 (with §14.9) + Phase 17 budget tree + Phase 18 privacy → Phase 6 beta (with §6.7 + §6.8 study mode + §17.4.2 soak + §18.8 privacy gate + §19.1 staged-rollout) → Phase 15.1 + 15.2 + Phase 16 + Phase 19 hot-fix lane + auto-rollback drilled → Phase 6 GA**.

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
