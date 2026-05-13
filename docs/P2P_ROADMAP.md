# 🌐 ChessRecast — Peer-to-Peer Multiplayer Roadmap

> **Status:** 📝 Draft **v2 (revised)** · **Owner:** @serhatakbak · **Target release train:** post-engine-freeze
> **Companion docs:** [GAME_MODS_DOCUMENTATION](game/GAME_MODS_DOCUMENTATION.md) · [DRAW_RULES](game/DRAW_RULES.md) · [AGENTS.md](../AGENTS.md) · [.github/copilot-instructions.md](../.github/copilot-instructions.md)
>
> **What changed in v2** (vs Draft v1)
>
> 1. ❌ Removed wrong assumption that "WebRTC ordered + reliable + signed JSON < 512 B" alone delivers tournament-grade latency. Replaced with a layered latency budget per-phase, CBOR/varint framing, and an **explicit pre-warmed ICE pair + keep-alive** model.
> 2. ⏰ **Clocks are now an explicit subsystem.** Wall-clock `client_ts_ms` is treated as untrusted hint only; the authoritative timer is monotonic + NTP-anchored, exchanged at handshake and re-anchored periodically. The "lower wins" tiebreak from v1 is preserved as the *defensive* path, not the *normal* path.
> 3. 🎮 **Mod-specific message catalog** added — Heir, Friendly Fire, Kings Battle, Mercenary, Save the Queen, Succession, Truce all need bespoke envelope subtypes (heir-pick, hire-choice, escape-route, truce-call, promotion-to-king, etc.). v1 silently assumed `from/to/promo` was enough.
> 4. ♟️ **Game-flow primitives added**: pre-game ready handshake, premove, takeback offer, draw offer, resign, abort, opponent-disconnect adjudication policy with explicit grace windows per time control.
> 5. 📱 **Mobile reality calibrated**: iOS WebRTC backgrounding, VoIP push for invite delivery (APNs / FCM high-priority), Android Doze, OS-level network change (Wi-Fi ↔ cellular), CGNAT/symmetric-NAT TURN fallout, mDNS-host-candidate breakage on older Android.
> 6. 🛡️ **Abuse/cheat/anti-tamper expanded**: per-pubkey + per-IP + per-/24 token buckets (CGNAT-safe), engine-correlation report harness reused from `agent/reports/`, premove-flood detection, mouse-slip vs intent classification, signed build attestation lite (apk-hash gossip), key rotation & revocation list.
> 7. 🧪 **Proof-test matrix expanded** to 7 layers (unit / property / component / integration / E2E-emulator / chaos / soak) with named scenarios and pass criteria. Per-mod conformance suite added.
> 8. 🧱 **Server hardening**: graceful drain, blue/green, structured shutdown, idempotent invite redemption, signaling fuzz harness, server-side replay-cache for nonces.
> 9. 🧹 **Phase 0 adds proof-of-cleanup tests** (`git grep` assertions in CI, dead-code analyzer, archived-folder lint).
> 10. 📊 **KPI tables per phase** (not only Phase 5) with thresholds wired into the same baselines/queue mechanism the engine uses, so a `kind: p2p_regression` task is filed automatically.
> 11. 🌍 **Hosting / region / disaster-recovery section** added. Single-region beta is fine, but the protocol must be region-agnostic from day 1 to avoid migration pain later.
> 12. 🔐 **GDPR / data-subject deletion**, store-policy disclosures, kill-switch & forced-upgrade flows added.
> 13. 🪪 **Lightweight stats-recovery account** added in Phase 2 (revised v2.1). The original "no central account ever" stance was wrong: losing a phone meant losing ELO, W/L/D, and game history. The protocol now ships an *opt-in but recommended* server-side account holding only the **bare-minimum stats blob** (per-mod ELO, played/wins/losses/draws, account age, last-seen, optional cosmetic handle) keyed by `device_id_pub`, with two recovery paths — **always-issued recovery codes** + **optional verified email** — neither of which gives the server access to game content, private keys, or move logs.

---

## 🎯 Mission

Ship **two-player online play** for all seven Chess Recast mods with:

- 🤝 **True P2P gameplay** — moves flow over a WebRTC SCTP `RTCDataChannel`; no server in the hot path of moves.
- 🛰️ **One small signaling/ops server** — SDP/ICE relay, lobby/matchmaking, in-app feedback & issue reports, TURN credential vending, kill-switch & forced-upgrade broadcast, optional opt-in stats. **That is the complete server feature set.**
- ⏱️ **Tournament-grade latency**, with explicit per-leg budgets:
  - Local (same NAT, same Wi-Fi): `p50 ≤ 25 ms`, `p95 ≤ 60 ms`.
  - Intra-region direct (host candidate): `p50 ≤ 60 ms`, `p95 ≤ 150 ms`.
  - Intra-region srflx (server-reflexive): `p50 ≤ 90 ms`, `p95 ≤ 220 ms`.
  - Inter-region or TURN-relayed: `p50 ≤ 180 ms`, `p95 ≤ 400 ms` (UI must surface a "relayed" badge here).
  - Hard ceiling for *acceptable* play at any tier: `p99 ≤ 600 ms` one-way; above that we flag the game as `degraded` and offer a draw.
- 🛡️ **Security by default** — DTLS 1.2+ on the data channel, every move signed (Ed25519), hash-chained log, replay-resistant by `(game_id, ply)` uniqueness + nonce cache, signed handshake pinning of opponent pubkey.
- 👤 **Pseudonymous, P2P-leaning identity** — per-install Ed25519 device keypair (sole signing authority for moves) **plus** an *opt-in but recommended* lightweight server-side **stats-recovery account** that holds only ELO, W/L/D, played count, account age, last-seen, and the user's cosmetic handle. Two recovery paths: **always-issued one-time recovery codes** (offline-capable) + **optional verified email** (network-capable). The server **never** holds private keys, move logs, or anything that could let it impersonate a player in-game (§2.2).
- 🧪 **Reproducible local sim** — two Android emulators on one workstation playing a clean rated game across **all 7 mods**, verifiable in CI, with chaos-net injected (loss / latency / disconnect / NAT-rebind).
- 📵 **Survives a flaky phone** — mid-game suspend, network swap, app-kill-and-relaunch all resume cleanly within 30 s or hand off to a deterministic adjudication.

---

## 🧭 Guiding principles

1. 🥇 **Engine-quality bar carries over.** Every gate in [.github/copilot-instructions.md](../.github/copilot-instructions.md) → *Hard rules → 4* still applies. Multiplayer code lives under `frontend/lib/services/p2p/**` and `frontend/test/p2p/**` (per-area allow-list update in §0.5).
2. 🪶 **Server is replaceable.** The signaling server is a thin, mostly-stateless HTTP+WebSocket service. If it dies for an hour, in-progress games keep playing (data channel is direct). New games and reconnect-via-restart need it; in-game moves do not.
3. 🔐 **Trust the cryptography, not the server.** Moves are signed with the player's per-device key; the server never sees move content. Even malicious servers cannot rewrite a game. The stats-recovery account (§2.2) is a *separate, smaller* trust boundary: a compromised server could falsify stats but **cannot** sign moves, decrypt game logs, or impersonate a player in a live lobby.
4. 🧱 **Deterministic, versioned protocol.** Move envelopes are versioned, schema-validated, canonicalized via [RFC 8785 JCS](https://www.rfc-editor.org/rfc/rfc8785) before signing, and replayable from the on-disk game log — same harness as `agent/reports/`. Wire format is **CBOR (RFC 8949)** with a JSON debug shadow; the JSON shadow is gated behind a debug flag and never affects the signature.
5. 🧮 **Clocks are first-class.** Wall clocks lie; monotonic clocks drift; only the synchronized exchange of both, anchored by an authenticated handshake, can be trusted. Any disagreement must have a deterministic resolution that *cannot benefit a cheater*.
6. 🎮 **Every mod is on the wire from day 1.** No mod is "added later" — the protocol's mod-message catalog (§1.4) covers all 7 from v1, even if the UI for some is built incrementally.
7. 🧹 **One legacy cleanup, then forward only.** The Go [`backend/`](../backend/) is archived in Phase 0; no new features land there. The new signaling server is a fresh tree (`signaling/`).
8. 🚦 **Feature flags + kill switch from day 1.** Every networked feature ships behind a server-broadcast flag so we can disable a broken codepath in minutes, not in a 1.5-day app-store review.
9. 📈 **Every phase has a KPI table** with a baselines file and a `kind: p2p_regression` queue contract — same gating discipline as the engine.

---

## 🗂️ Phase 0 — Cleanup, foundations & proof-of-cleanup 🧹

> **Goal:** Repo is unambiguously "P2P era" before any new code lands, *and CI proves it stays that way*.

### 0.1 📦 Archive the deprecated Go backend

- Move [`backend/`](../backend/) → `archive/backend-go-legacy/`. Add `archive/backend-go-legacy/README.md` explaining: *deprecated, kept for git history & possible reference, do not extend*.
- Update [README.md](../README.md), [AGENTS.md](../AGENTS.md) discoverability index, [.github/copilot-instructions.md](../.github/copilot-instructions.md) *Project shape* section, and [docs/coding/ai/automation.md](coding/ai/automation.md) to reflect the move.
- Remove `backend/` from any CI workflows (`.github/workflows/**`) and from VS Code tasks.
- 🔒 Add `archive/.frozen` marker file + a CI lint that fails if any commit modifies files under `archive/**` without the commit message containing `archive-touch:` (rare, by-design escape hatch).

### 0.2 🧽 Flutter cleanup of legacy backend wiring

Files to touch (Phase-0 allow-list):

- 🔥 Delete: [`frontend/lib/services/api_service.dart`](../frontend/lib/services/api_service.dart), [`frontend/lib/services/game_websocket.dart`](../frontend/lib/services/game_websocket.dart).
- ✂️ Strip backend calls from:
  - [`frontend/lib/ui/online_bot_vs_bot_page.dart`](../frontend/lib/ui/online_bot_vs_bot_page.dart) → see §0.3 for fate decision.
  - [`frontend/lib/ui/bot_selection_page.dart`](../frontend/lib/ui/bot_selection_page.dart) → drop the "play against backend AI" copy.
  - [`frontend/lib/analytics/custom/custom_board_setup.dart`](../frontend/lib/analytics/custom/custom_board_setup.dart) → drop the `"Backend server is not reachable"` paths; analytics stays fully on-device.
- 🧪 Remove/relocate tests that mock `ApiService` / `GameWebSocket`. Anything proving on-device behavior stays; anything asserting backend round-trips moves to `archive/`.
- 🏷️ Replace the comment in [`frontend/lib/mods/enums.dart`](../frontend/lib/mods/enums.dart) (`Convert enum name to snake_case for backend API`) with `… for wire/serialization`.
- 🧯 Audit `pubspec.yaml` for now-unused dependencies (`http`, `web_socket_channel`) and either remove them or note them as P2P-future.

### 0.3 🧭 Decide the fate of "online bot vs bot"

- **Option A (recommended ✅):** rename to **"Self-play sandbox"**, run two engine instances on-device. Zero network. Useful as a debug/teaching tool and as the basis for the *engine-correlation report* anti-cheat in §6.4.
- **Option B:** delete entirely.
- Decision logged in this doc + an entry in [agent/queue.yaml](../agent/queue.yaml) of `kind: shared_edit` since it touches shared UI.

### 0.4 🛡️ Proof-of-cleanup tests (new in v2)

A new test file `frontend/test/cleanup/legacy_backend_cleanup_test.dart` enforces, on every PR:

- `git grep -nE "ApiService|GameWebSocket|10\.0\.2\.2:8080"` returns **zero** hits outside `archive/`.
- `package:http` and `package:web_socket_channel` are not imported outside `frontend/lib/services/p2p/**` (until Phase 4 unlocks them).
- No file under `frontend/lib/**` references the symbol `ApiService`.
- Static check: `archive/**` is not imported from `frontend/lib/**`.

These checks are tiny `Process.run('git', …)` + `dart analyze` shells; they run as a normal Flutter test and gate every commit. **This is what "proof of cleanup" means** — without these the cleanup will rot within a sprint.

### 0.5 📋 Per-area allow-list addition for P2P work

Add to [.github/copilot-instructions.md](../.github/copilot-instructions.md) *Per-area source allow-list*:

| Area  | Allowed paths |
|---|---|
| `p2p` | `frontend/lib/services/p2p/**`, `frontend/test/p2p/**`, `frontend/tool/p2p/**`, `signaling/**`, `docs/signaling/**`, `scripts/p2p/**`, `agent/baselines/p2p.json` |

Touching `frontend/lib/services/p2p/protocol/**` after Phase 1 closes requires a `kind: shared_edit` (protocol breaking change — see §1.7).

### 0.6 ✅ Definition of done for Phase 0

- All §0.4 tests green on `main` for 3 consecutive CI runs.
- App builds and all existing engine/UI tests pass.
- New section "Multiplayer (P2P)" placeholder appears in the in-app *About* / *Settings* screen, marked **Coming soon 🚧**, hidden behind a `--dart-define=ENABLE_P2P_PREVIEW=true` flag.
- `agent/baselines/p2p.json` skeleton committed (all KPIs at `null`, populated as later phases ship).

---

## 🏛️ Phase 1 — Architecture & protocol design 🧠

> **Goal:** Lock the wire format, message catalog, and topology before writing any networking code. **Breaking changes after Phase 1 closes require a `kind: shared_edit` queue entry.**

### 1.1 🗺️ Topology diagram

```
        ┌──────────────────────────────────────────┐
        │   Signaling / Ops API (single binary)    │
        │  · /v1/lobby           (WSS)             │
        │  · /v1/turn-credentials                  │
        │  · /v1/feedback   /v1/issues             │
        │  · /v1/version    /v1/health  /v1/flags  │
        │  · /v1/push-token (APNs/FCM)             │
        └─────────────┬────────────────────────────┘
                      │  WSS (control plane only, ≤ 8 KB frames)
        ┌─────────────┴────────────────────────────┐
        │                                          │
   📱 Player A ◀── WebRTC SCTP DataChannel (DTLS) ──▶ 📱 Player B
        │                                                  │
        ├──── STUN (free public + self-hosted backup) ─────┤
        └──── TURN/TURNS (self-hosted coturn,              │
              short-lived HMAC creds) ─── ~5–15 % of games ┘
```

- ✋ Server **never** sees move content in the happy path.
- 🛰️ **STUN**: 2 self-hosted + 1 public fallback. **TURN**: self-hosted coturn with short-lived HMAC credentials (TTL ≤ 5 min).
- 📨 **Push delivery for invites** (APNs / FCM high-priority data push) — required for invite delivery when the recipient app is backgrounded; otherwise iOS Doze / Android Doze will silently swallow lobby messages.

### 1.2 🧾 Wire format & framing

- **Encoding:** **CBOR (RFC 8949)** with deterministic encoding rules (sorted keys, definite lengths). Average envelope ≈ 180–260 B, p99 < 480 B → always single SCTP MTU.
- **Debug shadow:** Each envelope can be re-rendered as JCS-canonicalized JSON for human inspection; the JSON form is **never signed and never sent on the wire** (signature is over CBOR canonical bytes).
- **Hashing:** **BLAKE3-256** for the prev-envelope hash chain; **SHA-256** for `engine_hash` (matches `cmake` artifact hashes the engine team already emits).
- **Signatures:** **Ed25519** over the CBOR canonical byte string of the envelope minus the `sig` field.
- **Framing on DataChannel:** SCTP messages are already framed; no further framing needed, but a 2-byte big-endian `wire_version` prefix lets us cleanly add a v2 wire later.

### 1.3 🧾 Move envelope (v1, **locked at end of Phase 1**)

```cbor
{
  "v":              1,                   // wire/protocol version
  "type":           "move",              // see §1.4 for full catalog
  "game_id":        h'0190…' (uuidv7),
  "ply":            17,
  "from":           "e2",
  "to":             "e4",
  "promo":          null,                // "q"|"r"|"b"|"n"|"k"(succession)|null
  "mod":            "save_the_queen",
  "mod_payload":    { … }                // mod-specific extension; see §1.4
  "rules_version":  3,                   // mod ruleset version (independent of engine_hash)
  "engine_hash":    h'…' (sha256, 32 B), // BUILD identity, not strength
  "client_ts_ms":   1736459123456,       // wall clock, advisory only
  "client_mono_ms": 4823501,             // monotonic clock since handshake
  "remaining_ms":   178300,              // sender's clock after this move
  "increment_ms":   2000,                // time-control increment applied
  "nonce":          h'…' (16 B random),  // anti-replay
  "prev_hash":      h'…' (blake3, 32 B), // hash chain
  "sig":            h'…' (ed25519, 64 B) // over canonical CBOR sans `sig`
}
```

Total typical size: **≈ 220 B** binary. Worst case (with `mod_payload`): **< 480 B**.

### 1.4 🎮 Mod-specific message catalog (new in v2)

The protocol's `type` field is a closed enum. Every mod gets at least one bespoke message; some need multiple. **All 7 mods are on the wire from day 1 of Phase 1**, even if the UI ships incrementally.

| `type`                  | Direction      | Payload                                          | Mod(s)                |
|-------------------------|----------------|--------------------------------------------------|-----------------------|
| `move`                  | bidirectional  | as §1.3                                          | all                   |
| `premove_set`           | bidirectional  | `{ply_target, from, to, promo}`                  | all (UX, optional)    |
| `premove_cancel`        | bidirectional  | `{ply_target}`                                   | all (UX, optional)    |
| `draw_offer`            | bidirectional  | `{at_ply}`                                       | all                   |
| `draw_accept`           | bidirectional  | `{at_ply}`                                       | all                   |
| `draw_decline`          | bidirectional  | `{at_ply}`                                       | all                   |
| `resign`                | bidirectional  | `{at_ply, reason?}`                              | all                   |
| `takeback_offer`        | bidirectional  | `{plies}` (≤ 2)                                  | all (config-gated)    |
| `takeback_accept`       | bidirectional  | `{plies}`                                        | all                   |
| `abort_request`         | bidirectional  | `{at_ply, reason}` (only allowed plies ≤ 2)      | all                   |
| `flag_claim`            | bidirectional  | `{at_ply}` (timeout adjudication)                | all                   |
| `heir_pick`             | mover only     | `{square}` (post-king-capture heir selection)    | heir                  |
| `friendly_fire_intent`  | mover only     | `{ack: true}` confirmed self-capture             | friendly_fire         |
| `kings_battle_phase`    | mover only     | `{phase: 1\|2, trigger_ply}`                     | kings_battle          |
| `mercenary_hire`        | mover only     | `{pawn_square, role: "n"\|"b"\|"r"}`             | mercenary             |
| `stq_escape`            | mover only     | `{queen_from, queen_to, escape_route_id}`        | save_the_queen        |
| `succession_promote`    | mover only     | `{pawn_square, to_king: true}`                   | succession            |
| `truce_call`            | bidirectional  | `{at_ply, duration_plies}`                       | truce                 |
| `truce_accept`          | bidirectional  | `{at_ply}`                                       | truce                 |
| `truce_decline`         | bidirectional  | `{at_ply}`                                       | truce                 |
| `clock_resync`          | bidirectional  | `{mono_a, mono_b, wall_a, wall_b, rtt_samples}`  | all                   |
| `hello`                 | bidirectional  | handshake (see §1.5)                             | all                   |
| `bye`                   | bidirectional  | `{reason}` (graceful close)                      | all                   |
| `ping` / `pong`         | bidirectional  | `{seq, ts_mono}`                                 | all                   |
| `engine_corr_optin`     | bidirectional  | `{accept: bool, share_pgn: bool}` (post-game)    | all                   |

Mod-payload examples for `move`:

- **heir** `move`: `mod_payload: {captured_king: "e8" | null}`
- **friendly_fire** `move`: `mod_payload: {self_capture: true | false}`
- **kings_battle** `move`: `mod_payload: {phase: 1 | 2}`
- **mercenary** `move`: `mod_payload: {acts_as: "p" | "n" | "b" | "r"}`
- **save_the_queen** `move`: `mod_payload: {queen_safety_window: int}`
- **succession** `move`: `mod_payload: {king_count: 1|2, last_king_pawn_promo: bool}`
- **truce** `move`: `mod_payload: {truce_active: bool, truce_remaining: int}`

The receiver **always re-validates** the move locally against its own engine; `mod_payload` is a hint for UI/animation, never a forcing rule.

### 1.5 🤝 Handshake (`hello`)

1. Both peers exchange a signed `hello`:
   ```
   { v, type: "hello", game_id, side: "w"|"b", chosen_mod, time_control,
     rules_version, engine_hash, peer_pub: <ed25519 pub>,
     mono_t0_ms, wall_t0_ms, rtt_probe_seq: [...], apk_attestation: {...},
     supported_types: [...], min_wire_version, max_wire_version, sig }
   ```
2. Each peer verifies the opponent's signature against the **public key learned during the lobby pairing** (see §2.2). A signature mismatch aborts the game with code `HELLO_PUBKEY_MISMATCH`.
3. Both peers compare `engine_hash` and `rules_version`. Mismatch ⇒ user sees `Engine version differs — please update both apps`. The game is **not started**; this is a hard refusal, not a warning.
4. The `supported_types` arrays are intersected — features the other peer doesn't support (e.g. premove on an old client) are disabled in UI before move 1.
5. Five `ping`/`pong` round-trips bootstrap the clock model (§1.6).
6. The first `move` envelope's `prev_hash` is the BLAKE3 of the initiator's `hello`.

### 1.6 ⏱️ Clock model (rewritten in v2)

The v1 model ("authoritative clock = local board, lower wins") is preserved as a **defensive fallback** but is no longer the *normal* path because it was exploitable: a malicious client could under-report `remaining_ms` to "win" the tiebreak after deliberately stalling.

The v2 model:

- Each peer maintains:
  - **`mono_clock`** — `Stopwatch`-style monotonic clock, started at `hello`. Cannot be manipulated by the user changing the device clock.
  - **`wall_clock`** — system wall clock; advisory only.
- At handshake, both peers exchange `(mono_t0, wall_t0)` and 5 ping/pong round-trips. From those we derive:
  - `rtt_median`, `rtt_p95`, `clock_skew_ms = wall_a − wall_b − adjusted_offset`.
- During the game:
  - On send, the mover sets `client_mono_ms = mono_clock.elapsed`, `client_ts_ms = wall_clock.now`, and `remaining_ms = local_remaining`.
  - On receive, the opponent computes `expected_remaining = previous_remaining − (local_mono_now − last_received_mono) + increment` and compares.
  - If the gap exceeds `max(80 ms, 1.5 × rtt_p95)`, a `clock_resync` is triggered. Two consecutive resyncs that *worsen* the gap → `degraded_clock` UI state, draw offered automatically.
- **`flag_claim`**: only the *non-mover* can claim the flag, and only after `remaining_ms ≤ 0` per the receiver's reconstruction. The flagged peer can dispute with their own monotonic evidence; if the dispute logs reconcile via the on-disk hash chain, the dispute wins. Otherwise the claim wins. **The server is never the arbiter** — the canonical record is the signed log.

### 1.7 🔁 Reconnection model

State machine (revised — see §4.3 for the full implementation):

```
Idle → Signaling → ICEGather → Connected → Handshake → InGame
                                                ↑          │
                                                │      drop│
                                                │          ▼
                                                │      ICERestart  (≤ 30 s)
                                                │          │
                                                │  success │  fail
                                                │ ◀────────┘──────┐
                                                │                  ▼
                                                │           PausedOffline
                                                │                  │
                                                │       grace expires (per time control)
                                                │                  ▼
                                                │           AdjudicateAbandon
                                                │                  │
                                                ▼                  ▼
                                            GameEnd           GameEnd(forfeit/draw)
```

Grace windows:

| Time control | ICE-restart window | Paused-offline grace | Outcome on expiry |
|---|---|---|---|
| Bullet (≤ 1 m)        | 8 s   | 20 s   | offline player flagged |
| Blitz (3 m – 5 m)     | 15 s  | 60 s   | offline player flagged |
| Rapid (10 m – 30 m)   | 30 s  | 5 min  | offline player flagged |
| Classical (> 30 m)    | 60 s  | 15 min | adjudicated draw if material balanced; otherwise forfeit |

After ICE-restart success, both peers exchange `prev_hash` of their last sent and last received envelope; the trailing peer requests a **hash-chained delta replay** from the leading peer. Replay verifies signatures end-to-end; any mismatch ends the game in dispute, logged for review.

### 1.8 🧰 Protocol tooling

- 📐 Schemas live in `frontend/lib/services/p2p/protocol/` as Dart classes + `*_schema.cbor.cddl` (CDDL — RFC 8610 — the standard schema language for CBOR).
- 🧪 **Golden tests** in `frontend/test/p2p/protocol/` exercise canonicalization & signature determinism cross-platform (Android x86_64, Android arm64, iOS sim, Linux desktop, Web canvas).
- 🧪 **Property tests** (`package:glados`) over the envelope codec: round-trip CBOR encode/decode, signature verify, hash-chain integrity under random insertion/deletion/reordering.
- 🧪 **Fuzz harness** (`frontend/tool/p2p/fuzz_protocol.dart`) using `package:dart_fuzzer` over the decoder; nightly run gated. Crashes auto-file `kind: crash / severity: critical`.
- 🪞 A small Dart CLI in `frontend/tool/p2p/`:
  - `replay_log.dart` — replays a stored game log against the engine to verify legality (reuses audit-batch infrastructure).
  - `inspect_envelope.dart` — pretty-prints CBOR envelopes for debugging.
  - `diff_logs.dart` — diffs two peers' logs for a disputed game.

### 1.9 📊 Phase 1 KPIs (`agent/baselines/p2p.json`)

```jsonc
{
  "phase1": {
    "envelope_size_p99_bytes":   { "value": null, "threshold": 480 },
    "encode_decode_us_p95":      { "value": null, "threshold": 250 },
    "sign_us_p95":               { "value": null, "threshold": 1500 },
    "verify_us_p95":             { "value": null, "threshold": 2000 },
    "fuzz_crashes_per_1m_iter":  { "value": null, "threshold": 0    }
  }
}
```

### 1.10 ✅ Definition of done for Phase 1

- Protocol document committed (this section + `frontend/lib/services/p2p/protocol/README.md` + CDDL schemas).
- Schemas + golden tests + property tests + first 1 M fuzz iterations green.
- Phase-1 KPIs measured on a developer device and committed to `agent/baselines/p2p.json`.
- A queue entry of `kind: shared_edit` is required for any future protocol-breaking change. Wire-version bump policy: additive (new optional fields) does not bump `v`; renames or removals do.

---

## 🪪 Phase 2 — Identity, recovery account, key management & attestation 🔐

> **Goal:** Players can prove "this move came from the same device that started the game" *and* recover their stats / handle / friends list when the phone is lost or wiped — without giving the server the power to impersonate them in-game.

### 2.0 🧭 Two-layer identity model (rewritten in v2.1)

The original draft conflated two things: the cryptographic identity that signs moves and the long-lived identity that owns stats. We now separate them.

| Layer                    | Lives on…                       | Owns…                                                                          | Lost when…                              | Recovers via…                                              |
|--------------------------|---------------------------------|--------------------------------------------------------------------------------|-----------------------------------------|------------------------------------------------------------|
| **Device key** (§2.1)    | Device only (hardware keystore) | Move signing, lobby pairing, opponent pubkey pin                               | Phone is lost, wiped, or factory-reset  | **Cannot be recovered** by design — a new key is minted; the **account** (below) re-binds it. |
| **Stats account** (§2.2) | Server (encrypted, minimal)     | ELO, W/L/D, played count, handle, account age, last-seen, friends list (§7)    | Never, as long as the user has *one* of: recovery codes, verified email, or any device still bound | Recovery codes (always) **or** verified email magic-link (if user opted in) |

The **device key signs moves**. The **account holds stats**. The two are linked by a signed binding stored on the server (§2.2.4). Losing the phone loses the *device key* but not the *account*; recovery rebinds a fresh device key to the existing account, and the user's stats / handle / friends survive intact.

### 2.1 🆔 Device key (the move-signing layer)

- On first launch the app generates an **Ed25519 keypair** (`device_id_pub`, `device_id_priv`) using a CSPRNG (`Random.secure`).
- Private key is stored in `flutter_secure_storage` (Android Keystore / iOS Keychain backed). On Android the key is wrapped by a hardware-backed key when available (`StrongBox` if present).
- 🪪 Public key fingerprint → **`DeviceId`** (e.g. `dev_4f3a…b2`). The legacy term `PlayerId` is now reserved for the *account-level* identifier (§2.2.1).
- Optional **display handle** (3–24 chars, NFKC-normalized, validated client-side, cosmetic only) is stored both locally and in the account; broadcast in the lobby; **never authoritative**.
- 🔁 **Local encrypted backup blob** (still supported): passphrase-protected, Argon2id-derived key, libsodium `secretbox`. Contains the device private key + handle + settings + game-history index. This is now the *power-user* recovery path (offline, server-independent). The *normal* recovery path is the account flow in §2.2.
- 🔁 **Key rotation:**
  - User can mint a new device keypair at any time. The old keypair signs a `key_rotation` certificate naming the new pubkey; both keys are accepted for in-flight games until those games end.
  - Rotation is also issued automatically every time a fresh device is bound to an existing account (§2.2.4) — the account always points at exactly one *active* device key, with up to 4 historical keys retained for the in-flight overlap window.
  - Old games remain attributed to the old key (immutable history).
- 📛 **Revocation:**
  - User can publish a `key_revoked` certificate, signed by the old key, optionally counter-signed by the new key. The signaling server publishes the revocation list (`/v1/revocations`); peers refuse new lobbies from revoked keys.
  - If the private key is *lost* (no signing possible), the user authenticates to their **account** (§2.2) and triggers a server-mediated revocation: the account marks the lost device key revoked and binds a fresh one, signed by the new device. A key thief still has a small window — see §2.2.5 for mitigation.

### 2.2 🪪 Stats-recovery account (new in v2.1)

> **Design principle:** the smallest possible server-held record that lets a user keep their ELO and stats across phones, with zero ability for the server (or anyone who steals its database) to forge moves, read game content, or impersonate a player in a live lobby.

#### 2.2.1 What the server stores (the **bare minimum**)

One row per account, in the signaling server's SQLite store, schema versioned:

```sql
CREATE TABLE accounts (
  player_id            BLOB PRIMARY KEY,        -- 16 B random; the durable account ID
  active_device_pub    BLOB NOT NULL,           -- current device Ed25519 pubkey (32 B)
  prior_device_pubs    BLOB,                    -- CBOR array of up to 4 historical pubkeys
  handle               TEXT,                    -- cosmetic, NFKC-normalized, ≤ 24 chars
  created_at           INTEGER NOT NULL,        -- unix seconds
  last_seen_at         INTEGER NOT NULL,
  recovery_email_hash  BLOB,                    -- nullable; HMAC-SHA256(server_pepper, lower(email))
  recovery_email_verified_at INTEGER,           -- nullable
  recovery_code_hashes BLOB NOT NULL,           -- CBOR array of 10 × Argon2id hashes
  recovery_codes_used  INTEGER NOT NULL DEFAULT 0,
  binding_sig          BLOB NOT NULL,           -- Ed25519 sig of (player_id || active_device_pub) by active device key
  schema_v             INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE account_stats (
  player_id  BLOB NOT NULL,
  mod        TEXT NOT NULL,                     -- one of the 7 mods, or 'overall'
  elo        INTEGER NOT NULL DEFAULT 1200,     -- Glicko-2 rating ×1; rd/sigma in separate cols
  rd         INTEGER NOT NULL DEFAULT 350,      -- Glicko-2 rating deviation
  sigma_e6   INTEGER NOT NULL DEFAULT 60000,    -- Glicko-2 volatility ×1e6
  played     INTEGER NOT NULL DEFAULT 0,
  wins       INTEGER NOT NULL DEFAULT 0,
  losses     INTEGER NOT NULL DEFAULT 0,
  draws      INTEGER NOT NULL DEFAULT 0,
  forfeits   INTEGER NOT NULL DEFAULT 0,        -- separate from losses for fairness analytics
  last_played_at INTEGER,
  PRIMARY KEY (player_id, mod)
);
```

**That is the entire account record.** Specifically, the server does **not** store: move content, PGNs, opening choice, opponent identity per game (only aggregates), private keys, anything about the user's device beyond the pubkey, or anything that lets it answer the question "what did this user play in their last game?".

*Why Glicko-2 not classic ELO?* Same compute cost, much better at handling sporadic players (typical mobile audience). The schema is identical in shape to ELO — just with `rd` and `sigma_e6` columns the rating engine uses.

#### 2.2.2 Account creation

- New install ⇒ device key minted (§2.1) ⇒ app shows a **3-screen onboarding**:
  1. *"Want to keep your stats if you switch phones?"* (Yes / Skip — Skip = no account, device-only mode).
  2. *"Save these 10 recovery codes."* — 10 × 6-char Crockford-base32 codes (`AB12-CD34`-style, ≈ 30 bits each). The user is prompted to screenshot **or** print **or** copy to a password manager. The first code must be re-entered on the next screen to prove the user actually saved them.
  3. *"Add a recovery email? (optional, recommended)"* — if entered, the server sends a magic-link verification; account is usable immediately, recovery via email is gated on verification.
- Server-side, on `POST /v1/accounts`:
  - Body: `{ device_pub, handle?, email_optin?, recovery_code_hashes[10], binding_sig }`.
  - Server generates `player_id`, persists row, returns `{player_id, recovery_codes_remaining: 10}`.
  - Server **never sees the recovery codes themselves**, only their Argon2id hashes (`m=64MB, t=3, p=1`).
  - Email, if provided, is hashed with a server-side pepper before storage; the plaintext email is held only in a verification queue with a 24-hour TTL, then dropped.

#### 2.2.3 Stats updates

- After every completed game (resign / mate / flag / agreed draw), each peer calls `POST /v1/stats/update` with a **co-signed game-result envelope**:
  ```
  { player_id_a, player_id_b, mod, time_control, result: "a_wins"|"b_wins"|"draw",
    final_ply, game_id, sig_a, sig_b }
  ```
- The server updates Glicko-2 ratings only when **both peers** submit the *same* envelope (signatures match, both signed the same `result`). One-sided submissions are queued for 30 minutes; if the other side never submits, the result is dropped (no ELO change). This makes it impossible for one peer to fake a win.
- Disconnect-adjudicated outcomes (§1.7 grace expiry) are signed by the surviving peer **and** by the signaling server's witness key (the server saw the disconnect on the lobby side); two sigs ≥ one peer sig.
- Spam mitigation: per-pubkey rate limit on stats submissions (max 60 per hour, generous; bullet-spam counter tracked separately).

#### 2.2.4 Binding a fresh device to an existing account (the recovery flow)

**Path A — recovery codes (works offline-capable, no email needed):**

1. User taps *"I have an account, restore it"* on a fresh install.
2. Enters their player handle (or `player_id` from a screenshot) **plus one unused recovery code**.
3. App generates a new device keypair locally and signs a `device_rebind` request:
   ```
   { player_id, recovery_code, new_device_pub, new_device_sig }
   ```
4. Server: looks up account, Argon2id-verifies the code against `recovery_code_hashes`, marks that code consumed (`recovery_codes_used++`), rotates `active_device_pub` ← `new_device_pub` (old key moved to `prior_device_pubs`), publishes a `key_rotation` cert to `/v1/revocations`, returns the account row.
5. User is in. Stats restored. Old device key revoked.

**Path B — verified email (requires the user opted in at creation):**

1. User enters their email address.
2. Server sends a magic link (`https://signaling/v1/recover?token=…`, 15-min TTL, single-use).
3. Tapping the link in the app proves possession of the email; same `device_rebind` flow as above runs.

**Recovery codes regenerate** automatically once `recovery_codes_used ≥ 8` (next time the user is online); the app shows the new codes and asks the user to re-save. We never run a user out of codes silently.

**Path C — power-user (offline, server-down):** the local encrypted backup blob (§2.1) restores the device key directly without contacting the server. Stats sync resumes when the server is reachable again.

#### 2.2.5 Stolen-phone race & mitigation

The attack: phone stolen, thief unlocks it, *then* you wipe-and-restore on a new phone. There is a window where two devices both think they're "active".

Mitigations, in order of strength:

- **Hardware-backed keystore** (the default on modern Android/iOS): the thief cannot extract the device private key without bypassing the OS lock screen. This is the front line.
- **Account-level lock** via *"Mark phone lost"* in the in-app web flow (`/v1/accounts/lock`, requires recovery code or email) — sets `active_device_pub = NULL` on the account; in-flight games are paused, no new games can start until a fresh device binds.
- **Last-seen alert**: when a device rebinds, the previously active device receives an `account_rebound` notification (via push and on next app foreground) showing the timestamp / approx-region of the new bind. If the user did not initiate it, they can lock the account from the new device or from any other signed-in device.
- **Per-bind cooldown**: after a `device_rebind`, the new device cannot trigger another rebind for 24 hours unless the user enters a *second* recovery code.

#### 2.2.6 What the server still does **not** see, even with an account

- Move content, PGNs, opening choice (still strictly P2P).
- Per-game opponent identity (only the co-signed result envelope, which is intentionally aggregable but not browseable per-user).
- Email plaintext after verification (only a peppered hash).
- Recovery code plaintext (only Argon2id hashes).
- Device location beyond IP (and IPs are still purged after 7 days per §3.3).

A server-side breach reveals: pubkeys, handles, peppered email hashes, Argon2id'd recovery code hashes, ELO/W/L/D. **It does not reveal:** any move played, any ability to sign moves, any ability to read a user's email, or any ability to brute-force recovery codes in a usable timeframe (Argon2id m=64MB, t=3 over a 30-bit code = years of GPU-time per account at offline-attack rates).

#### 2.2.7 Server endpoints (added to §3.2)

| Method | Path                       | Purpose                                                          |
|--------|----------------------------|------------------------------------------------------------------|
| `POST` | `/v1/accounts`             | Create account (body in §2.2.2)                                  |
| `GET`  | `/v1/accounts/me`          | Fetch own account row (auth: signature by active device key)     |
| `POST` | `/v1/accounts/rebind`      | Bind fresh device via recovery code or verified-email magic link |
| `POST` | `/v1/accounts/lock`        | Mark phone lost; clears `active_device_pub`                      |
| `POST` | `/v1/accounts/email`       | Add or change recovery email (re-verification required)          |
| `DELETE` | `/v1/accounts/me`        | GDPR delete (drops account row + stats; pubkeys retained on game-result envelopes for 90 d for dispute window, then anonymized) |
| `POST` | `/v1/stats/update`         | Co-signed game-result envelope (§2.2.3)                          |
| `GET`  | `/v1/stats/me`             | Fetch own per-mod stats                                          |
| `GET`  | `/v1/stats/lookup`         | Fetch a *single* opponent's per-mod ELO + played count *only* (handle + ELO + played; nothing else) — used in the lobby to show "Opponent rating" |
| `POST` | `/v1/accounts/recovery-codes/regenerate` | Mint a fresh batch of 10; old hashes invalidated immediately |

All of the above require a signed nonce challenge by the `active_device_pub` **or** an unconsumed recovery code (rebind / lock paths only).

### 2.3 🤝 Pairing & handshake

1. Player A creates a lobby → server returns short **invite code** (Crockford-base32, 6 chars + 2-char checksum, ~30 bits effective entropy, single-use, 5 min TTL). A QR code is also generated.
2. Player B enters the code (or scans the QR) → both peers exchange **public keys + SDP offers** through the signaling server. If both peers have stats accounts (§2.2), the server attaches each peer's `{handle, per-mod ELO, played}` row from `/v1/stats/lookup` so the lobby UI can show "Opponent rating" before the game starts.
3. Each peer **verifies the opponent's first SDP message is signed by the pubkey advertised at lobby join**. MITM by the signaling server is detected here. A failed verification aborts pairing with `PAIRING_PUBKEY_MISMATCH`.
4. After ICE connection, the **first data-channel message is the `hello` handshake** (§1.5).
5. Optional **out-of-band fingerprint check**: both apps display a 6-word **PGP-style fingerprint** of the pinned opponent key. Users who care can verify out-of-band (in person, on a call).

### 2.4 🛡️ Server-side trust boundary (revised)

- The signaling server learns:
  - `device_id_pub` and (for accounts) `player_id`, `handle`, peppered `recovery_email_hash`, Argon2id'd `recovery_code_hashes`, per-mod `{elo, played, wins, losses, draws}`, account `created_at` / `last_seen_at`.
  - **IP** (necessarily, for ICE), invite code activity, lobby presence, push tokens (only if user enables push), feedback/issue payloads.
  - Co-signed game-*result* envelopes (winner / draw / mod / time-control / final-ply / game_id) — see §2.2.3.
- The server does **not** learn: move content, individual move times, opening choice, PGN, per-game opponent (only aggregated), private keys, recovery code plaintext, email plaintext after verification, mod played per game (only that *some* game on mod X happened).
- 📜 Privacy notice (`docs/signaling/PRIVACY.md`) enumerates exactly the above and is linked from in-app *About* + the App Store privacy declaration.

### 2.5 🚦 Rate limiting & abuse

- Server enforces token buckets at three independent scopes (CGNAT-aware):
  - per-`device_id_pub` and per-`player_id` (tight),
  - per-IP (medium),
  - per-/24 IPv4 or /48 IPv6 (loose).
- Why three? Because mobile carriers route many legitimate users through a single IP (CGNAT). A per-IP-only limiter would lock out an entire neighborhood after one abuser.
- 3 strikes (invalid signatures, spam, malformed payloads) → exponential backoff (1 m → 5 m → 1 h → 24 h), persisted in server SQLite.
- **Recovery-code brute-force lockout:** 5 wrong codes against the same `player_id` within 1 h ⇒ recovery via codes is locked for 24 h (email path still works); 20 within 24 h ⇒ account is auto-locked and the owner is notified by email if available.
- **Email-recovery flood guard:** max 3 magic-link sends per `recovery_email_hash` per hour.
- 🚫 No password storage anywhere — recovery is by code or magic link only, so there is no password-leak surface area.

### 2.6 🛡️ Attestation lite (new in v2)

We can't cryptographically prove the running APK is unmodified (this is OSS), but we can make modification *visible*:

- At `hello`, both clients exchange the SHA-256 of their installed APK / IPA bundle (`apk_attestation`).
- The signaling server publishes the **canonical hashes** of the latest published builds at `/v1/version`.
- Mismatch ⇒ a yellow "modified-build opponent" badge in the UI. Game proceeds; the user decides.
- This is **not** anti-cheat; it's a trust-but-verify signal.

### 2.7 🧪 Phase 2 proof tests

Device-key layer:

- `frontend/test/p2p/identity/keypair_lifecycle_test.dart` — generate, sign, verify, persist across app restart.
- `frontend/test/p2p/identity/backup_restore_test.dart` — round-trip encrypted backup with passphrase, including wrong-passphrase rejection.
- `frontend/test/p2p/identity/key_rotation_test.dart` — old/new key both accepted during overlap, old key rejected after rotation cert is acknowledged.
- `frontend/test/p2p/identity/revocation_test.dart` — revoked key cannot start a new lobby.
- `frontend/test/p2p/identity/cross_platform_backup_test.dart` — Android-generated backup restores on iOS sim and vice versa (CI matrix).

Account layer (new in v2.1):

- `frontend/test/p2p/account/create_account_test.dart` — onboarding generates 10 codes, server stores only Argon2id hashes; raw codes never appear in any persisted log.
- `frontend/test/p2p/account/rebind_with_code_test.dart` — fresh install + recovery code restores stats; old device key is revoked; consumed code cannot be reused.
- `frontend/test/p2p/account/rebind_with_email_test.dart` — magic-link flow on Android + iOS sim, including expired-token rejection and replay rejection.
- `frontend/test/p2p/account/cooldown_test.dart` — second rebind within 24 h requires a *second* code.
- `frontend/test/p2p/account/stats_cosign_test.dart` — stats only update when both peers submit matching result envelopes; one-sided submissions expire.
- `frontend/test/p2p/account/lost_phone_lock_test.dart` — `/v1/accounts/lock` pauses in-flight games and blocks new lobby creation until rebind.
- `frontend/test/p2p/account/recovery_code_lockout_test.dart` — 5 wrong codes locks the code path for 24 h; email path still works.
- `frontend/test/p2p/account/regenerate_codes_test.dart` — codes regenerate at usage ≥ 8; old hashes invalidated immediately.
- `frontend/test/p2p/account/gdpr_delete_test.dart` — `DELETE /v1/accounts/me` clears the account + stats; pubkey retained on co-signed result envelopes for 90 d then anonymized.
- `frontend/test/p2p/account/server_breach_simulation_test.dart` — given a leaked DB dump, assert recovery codes cannot be brute-forced under a fixed compute budget within target time.
- `signaling/internal/accounts/*_test.go` — server-side unit + integration coverage of all `/v1/accounts/**` endpoints.

### 2.8 📊 Phase 2 KPIs (`agent/baselines/p2p.json`)

```jsonc
{
  "phase2": {
    "account_create_p95_ms":           { "value": null, "threshold": 400  },
    "rebind_with_code_p95_ms":         { "value": null, "threshold": 800  },
    "stats_update_p95_ms":             { "value": null, "threshold": 250  },
    "recovery_code_argon2id_ms":       { "value": null, "threshold": 350  }, // tuned target on a 2 vCPU server
    "account_table_size_bytes_p99":    { "value": null, "threshold": 2048 },
    "recovery_codes_loss_pct_30d":     { "value": null, "threshold": 2.0  }, // % of accounts that exhausted all codes without regenerating
    "orphaned_account_pct_30d":        { "value": null, "threshold": 5.0  }  // % of accounts with no `last_seen_at` update in 30 d (helps tune retention)
  }
}
```

### 2.9 ✅ Definition of done for Phase 2

- All §2.7 device-key tests + account tests green on Android + iOS sim + Linux desktop.
- Threat-model checklist (§9, including the new account-layer entries) reviewed and signed off.
- `docs/signaling/PRIVACY.md` first draft committed, with explicit *"What is in your account"* and *"What is **not** in your account"* sections.
- Phase-2 KPIs measured on a staging server and committed to `agent/baselines/p2p.json`.
- Recovery-flow UX walked through end-to-end on a real Android *and* a real iOS device by at least two reviewers (one of whom should *not* be the implementer).

---

## 🛰️ Phase 3 — Signaling & ops server 🌐

> **Goal:** One small service. Boring tech. Easy to operate. Replaceable. **Survives a deploy without dropping in-flight pairings.**

### 3.1 🧱 Tech choice

- **Language:** **Go** (preferred — fits prior backend experience; tiny single-binary; great net stack). TypeScript is a fallback only if the team's bandwidth shifts.
- **Storage:** **SQLite (WAL mode)** for: lobbies, invite codes, rate-limit buckets, feedback, issue reports, revocation list, push tokens, **accounts + stats + recovery hashes** (§2.2.1). Move to PostgreSQL only when DAU > 5 k (formal trigger; not a guess) **or** when account-table row count > 250 k (whichever first).
- **Hosting:** single VPS or a managed container (Fly.io / Render / Hetzner). HTTPS via Caddy/Traefik with auto-cert. **At least one warm standby** in the same region from day 1; multi-region pushed to Phase 7 but **the protocol is region-agnostic from day 1**.
- **Observability:** structured JSON logs → file + stdout; Prometheus `/metrics` endpoint; uptime ping; OpenTelemetry traces optional.
- **Secrets:** read at boot from env vars *or* a `secrets/*.age` directory; never committed. Rotation procedure documented in `docs/signaling/RUNBOOK.md`.

### 3.2 🌍 Endpoints (v1)

| Method | Path                       | Purpose                                                         | Auth                            |
|--------|----------------------------|-----------------------------------------------------------------|---------------------------------|
| `GET`  | `/v1/health`               | Liveness                                                        | none                            |
| `GET`  | `/v1/ready`                | Readiness (DB + TURN reachable)                                 | none                            |
| `GET`  | `/v1/version`              | Server build, min-supported client, canonical APK/IPA hashes    | none                            |
| `GET`  | `/v1/flags`                | Feature flags + kill switches (cached 60 s by client)           | none                            |
| `WS`   | `/v1/lobby`                | Create/join lobby, exchange SDP/ICE                             | signed nonce challenge          |
| `POST` | `/v1/turn-credentials`     | Vend short-lived TURN HMAC creds (TTL ≤ 5 m)                    | signed nonce challenge          |
| `POST` | `/v1/feedback`             | In-app feedback (text + optional log tail)                      | signed envelope, rate-limited   |
| `POST` | `/v1/issues`               | Bug report (text + redacted device info)                        | signed envelope, rate-limited   |
| `POST` | `/v1/push-token`           | Register APNs/FCM token for invite delivery                     | signed envelope                 |
| `GET`  | `/v1/revocations`          | Revocation list (delta + full snapshot, ETag)                   | none (public)                   |
| `POST` | `/v1/report-player`        | Abuse / cheat report (signed, rate-limited, requires evidence)  | signed envelope                 |
| `POST` | `/v1/engine-corr-submit`   | Opt-in post-game PGN for engine-correlation analysis (§6.4)     | signed envelope                 |
| `POST` | `/v1/accounts`             | Create stats-recovery account (§2.2.2)                          | signed envelope                 |
| `GET`  | `/v1/accounts/me`          | Fetch own account row                                            | signed envelope by active device |
| `POST` | `/v1/accounts/rebind`      | Bind fresh device via recovery code or magic link (§2.2.4)      | recovery code OR magic-link token |
| `POST` | `/v1/accounts/lock`        | Mark phone lost; clears `active_device_pub` (§2.2.5)            | recovery code OR signed envelope |
| `POST` | `/v1/accounts/email`       | Add / change recovery email (re-verification required)          | signed envelope                 |
| `DELETE` | `/v1/accounts/me`        | GDPR delete                                                      | signed envelope                 |
| `POST` | `/v1/accounts/recovery-codes/regenerate` | Mint fresh batch of 10 codes                       | signed envelope                 |
| `POST` | `/v1/stats/update`         | Co-signed game-result envelope (§2.2.3)                          | both-peer signatures            |
| `GET`  | `/v1/stats/me`             | Fetch own per-mod stats                                         | signed envelope                 |
| `GET`  | `/v1/stats/lookup`         | Single-opponent `{handle, ELO, played}` lookup                  | signed envelope                 |
| `GET`  | `/v1/leaderboard`          | (Phase 7) optional opt-in stats                                 | signed envelope                 |

### 3.3 🔐 Server hardening checklist

- [ ] HTTPS only (HSTS, TLS 1.3 min, OCSP stapling).
- [ ] Strict CORS (only the app's WebView origin, if any).
- [ ] Body size cap: 64 KB (feedback/issues), 8 KB (lobby messages), 16 KB (engine-corr submit).
- [ ] Per-IP + per-/24 + per-pubkey token buckets (§2.4).
- [ ] Signature verification middleware on every authenticated route, with **nonce replay cache** (5 min window).
- [ ] Logs scrubbed for IPs after 7 days (configurable; documented in PRIVACY.md).
- [ ] Backups (SQLite snapshot to encrypted offsite storage) nightly; restore drill quarterly.
- [ ] Single binary, distroless container, read-only FS, non-root user, no shell.
- [ ] **Graceful drain on SIGTERM:** stop accepting new lobbies, hand off active lobbies to standby via state replication or invalidate them with a clear error code (`LOBBY_DRAINING`, client retries on standby).
- [ ] **Blue/green deploys** with traffic shift via the load balancer; never deploy by replacing the live container in place.
- [ ] **Idempotent invite redemption:** redeeming the same code twice from the same `device_id_pub` returns the same lobby state; from a different pubkey returns `INVITE_TAKEN`.
- [ ] **Server-side fuzz harness** for the WS protocol *and* all `/v1/accounts/**` + `/v1/stats/**` handlers (`go-fuzz` on every PR).
- [ ] **Chaos tests** on the server (kill the DB mid-request, drop network mid-WS) — see §5.5.
- [ ] **Account-table at-rest encryption**: SQLite database file lives on a per-host LUKS-encrypted volume; backups are encrypted with `age` before leaving the host. Recovery code hashes are Argon2id (m=64MB, t=3, p=1); email hashes are HMAC-SHA256 with a server-side pepper rotated yearly.
- [ ] **Recovery-code pepper + Argon2id parameters** version-stamped per account row so we can rotate parameters without invalidating existing codes.

### 3.4 📁 Repo layout

```
signaling/
  cmd/server/main.go
  internal/lobby/…
  internal/feedback/…
  internal/turn/…
  internal/identity/        ← Ed25519 verify helpers
  internal/flags/           ← feature flags & kill switch
  internal/revocations/
  internal/push/            ← APNs + FCM clients
  internal/ratelimit/
  internal/observability/
  migrations/
  fuzz/                     ← go-fuzz corpora & targets
  Dockerfile
  README.md
  Makefile
docs/signaling/
  RUNBOOK.md                ← deploy, rollback, on-call
  PRIVACY.md                ← what we collect, retention, deletion
  SECURITY.md               ← responsible-disclosure contact
  THREAT_MODEL.md           ← canonical version of §9
  KILL_SWITCH.md            ← how to disable a broken feature in < 5 min
```

### 3.5 📊 Phase 3 KPIs (`agent/baselines/p2p.json`)

```jsonc
{
  "phase3": {
    "lobby_create_p95_ms":          { "value": null, "threshold": 200  },
    "lobby_join_p95_ms":            { "value": null, "threshold": 250  },
    "ws_uptime_pct_30d":            { "value": null, "threshold": 99.5 },
    "deploy_drain_drops_pct":       { "value": null, "threshold": 0.1  },
    "fuzz_crashes_per_1m_iter":     { "value": null, "threshold": 0    },
    "rate_limit_false_positive_pct":{ "value": null, "threshold": 0.5  }
  }
}
```

### 3.6 ✅ Definition of done for Phase 3

- `make run` boots the server with an in-memory DB.
- `make test` runs unit + integration tests with **≥ 85 %** coverage on `internal/`.
- `make fuzz` runs 1 M iterations clean.
- A staging instance is reachable from a dev phone.
- Drain-on-SIGTERM verified by chaos test (no client sees `WS dropped` during a deploy).
- Runbook + privacy notice + security contact pages live.

---

## 📡 Phase 4 — WebRTC data channel in Flutter 🧩

> **Goal:** Two phones playing, with reconnection that survives the elevator-test, the airplane-mode-toggle, and the iOS-background-suspend.

### 4.1 📦 Dependencies

- `flutter_webrtc` — battle-tested WebRTC bindings.
- `web_socket_channel` — signaling transport.
- `cryptography` (Dart) **and** `libsodium` FFI — Ed25519 sign/verify (Dart for portability, libsodium for hot path on mobile).
- `flutter_secure_storage` — key persistence.
- `cbor` — CBOR codec.
- `firebase_messaging` (Android) + `flutter_apns` (iOS) — push delivery for invites.

### 4.2 🧱 Module layout

```
frontend/lib/services/p2p/
  identity/           ← keypair, signing, backup, rotation, revocation
  signaling/          ← WS client, lobby protocol, feature-flag fetch
  transport/          ← WebRTC PeerConnection + DataChannel wrapper, backpressure
  protocol/           ← envelope schema, codecs, hash chain, JCS, CBOR, CDDL
  game_session/       ← orchestrates: handshake → moves → reconnect → end
  clock/              ← monotonic clock, NTP-anchored skew, flag adjudication
  diagnostics/        ← latency probes, connection-quality metrics, dev overlay
  push/               ← APNs/FCM token registration & receipt
  persistence/        ← on-disk game log, resume-after-app-kill
  ui_glue/            ← state-machine bindings, premove, takeback, draw, resign
frontend/test/p2p/
  protocol/
  transport/          ← uses fake_signaling + loopback peer
  game_session/
  identity/
  clock/
  persistence/
  chaos/              ← mocked-network failure injectors
```

### 4.3 🧪 Connection state machine (full)

```
Idle ─create/join─▶ Signaling ─SDP/ICE─▶ ICEGather ─candidates─▶ Connecting
                                                                      │
                                                                ICE ok│
                                                                      ▼
                                                                  Handshake ─verify─▶ ReadyCheck
                                                                      │                  │
                                                                fail/MITM            both peers ready
                                                                      ▼                  ▼
                                                                  Aborted              InGame ◀──────┐
                                                                                          │           │
                                                                                  drop / netchg / bg │
                                                                                          ▼           │
                                                                                    ICERestart        │
                                                                                          │           │
                                                                                 success / replay     │
                                                                                          └───────────┘
                                                                                          │
                                                                                fail (window expires)
                                                                                          ▼
                                                                                  PausedOffline
                                                                                          │
                                                                              grace expires (§1.7)
                                                                                          ▼
                                                                                  AdjudicateAbandon ─▶ GameEnd
```

Implemented as a sealed-class `P2pState` (Dart 3 patterns + exhaustive switch). Every state has:

- a per-state widget overlay (so the user always knows what's happening),
- a per-state allowed-message-type whitelist (defense in depth),
- a per-state timeout with a deterministic next-state transition.

### 4.4 ⏱️ Latency engineering checklist

- [ ] ✅ DataChannel `ordered: true`, `maxRetransmits: null` (reliable). Move messages are tiny — no need for unreliable mode.
- [ ] ✅ **Pre-warm** one ICE candidate pair before showing the lobby "Ready" button (parallel ICE gather).
- [ ] ✅ Filter out **mDNS host candidates** on Android API ≤ 28 (known to break on certain OEMs).
- [ ] ✅ Tune SCTP: `setBufferedAmountLowThreshold` to 16 KB; pause sends when `bufferedAmount > 64 KB`; UI shows `slow link` badge.
- [ ] ✅ Keep envelopes < **480 B** so they always fit in one MTU on every common link MTU (1280 is the IPv6 minimum; SCTP overhead ≈ 30 B; DTLS overhead ≈ 30 B).
- [ ] ✅ Send → render → confirm round-trip instrumented; `p50`, `p95`, `p99` exposed in the dev overlay and in `agent/baselines/p2p.json`.
- [ ] ✅ TURN fallback measured: target **< 15 %** of games need TURN globally, **< 5 %** intra-region. Above the threshold ⇒ investigate ICE config, file `kind: p2p_regression`.
- [ ] ✅ **Adaptive ping cadence**: 5 s when stable, 1 s when RTT variance > 50 ms, off when backgrounded (rely on OS keep-alive).

### 4.5 📱 Mobile reality (new in v2)

iOS and Android both make WebRTC interesting.

#### iOS

- WebRTC sockets do **not** survive app backgrounding for more than ~30 s (no real-time-VoIP entitlement = no PushKit). Mitigations:
  - For invite delivery: **APNs high-priority data push** + a notification the user taps to bring the app foreground.
  - For mid-game suspend: persist game state (§4.7), show a "tap to resume" notification on backgrounding, treat resume as `ICERestart`.
  - We do **not** request the VoIP entitlement (App Store reviewers reject games using it). Documented in `docs/signaling/RUNBOOK.md` so we don't relitigate this.
- Disable the iOS "Low Data Mode" path: detect via `NWPathMonitor`, surface to user, allow them to opt in to a degraded mode.

#### Android

- Doze + App Standby will kill the WS and DataChannel within 5 min of backgrounding. Same mitigation: persist + push-resume.
- FCM high-priority data push for invite delivery (FCM `priority: high` + `data` payload, not `notification`, to avoid Android's notification rate limits).
- Network-change detection via `connectivity_plus` (`onConnectivityChanged`); on a Wi-Fi ↔ cellular swap, immediately trigger ICE restart **proactively** rather than waiting for the data channel to die.

#### Both

- Battery: keep-alive cadence drops to OS default when the screen is off and the user is on the move clock (no UI updates needed).
- Audio focus / phone call interruption: pause the game clock for the local player (signed `pause_request` to opponent, opponent must accept; auto-resume after 30 s).

### 4.6 🛡️ Anti-cheat / integrity (engine-side)

- 🧠 Each peer **independently runs the rules engine** — illegal moves are rejected locally; the network is **untrusted input** even from a signed peer.
- 🚨 Persistent invalid-move attempts → log, end game with `OPPONENT_PROTOCOL_VIOLATION`, file an issue automatically with the offending envelope.
- 🧨 **Premove flood detection**: > 4 premove sets per ply ⇒ rate-limited; > 12 per game ⇒ logged.
- 🖱️ **Mouse-slip vs intent**: client-side, a move executed within 200 ms of a touch-down without a confirmation tap (configurable) gets a 1-s undo window. This is local UX only; the wire never sees the slip.
- 🧮 **Engine-correlation report** (Phase 6+): post-game, opt-in, the user submits the PGN to `/v1/engine-corr-submit`. The server runs a depth-12 analysis against the submitted line and flags suspiciously perfect play above a per-mod threshold (reuses the audit-batch infrastructure from `agent/reports/`).
- 🔁 **Replay protection**: `(game_id, ply, nonce)` is unique; receiver caches last 64 nonces per game.
- 🪪 **Pubkey pinning**: opponent's pubkey is pinned at handshake; subsequent envelopes signed by a different key → `OPPONENT_KEY_CHANGED` abort.

### 4.7 💾 Persistence & resume-after-app-kill (new in v2)

- Every sent and received envelope is appended to a per-game log file (`<docs>/p2p/games/<game_id>.cbor.log`), `fsync`'d before the UI advances.
- On app launch, if any log is unfinished and within its grace window, the app offers **Resume game** in the lobby. Resume reconnects via the signaling server using the persisted `game_id` and rejoins as the same `device_id_pub`.
- Logs are **encrypted at rest** under a subkey derived from the device key (Argon2id from a long-lived random salt).
- Logs older than 30 days are auto-archived to a compressed tarball; user can export or delete from Settings.
- The same logs feed the engine-correlation report and the `replay_log.dart` debugging tool.

### 4.8 🧪 Phase 4 proof tests

- `frontend/test/p2p/transport/loopback_basic_test.dart` — two in-process peers, full handshake + 20 plies, no network.
- `frontend/test/p2p/transport/backpressure_test.dart` — flood the DataChannel, assert `bufferedAmountLowThreshold` triggers and UI surfaces the slow-link badge.
- `frontend/test/p2p/game_session/all_mods_smoke_test.dart` — 7-mod scripted game, asserts each mod's bespoke message types appear in the log.
- `frontend/test/p2p/game_session/reconnect_test.dart` — kill the data channel mid-game, restart within window, verify hash-chain replay.
- `frontend/test/p2p/game_session/abandon_test.dart` — exceed grace window, verify adjudication outcome per time control.
- `frontend/test/p2p/clock/skew_test.dart` — simulate a 2-s wall-clock jump on one peer, verify monotonic path saves the day.
- `frontend/test/p2p/clock/flag_dispute_test.dart` — flagged peer disputes with hash-chained evidence, verify dispute wins.
- `frontend/test/p2p/persistence/resume_test.dart` — kill app, relaunch, resume game.
- `frontend/test/p2p/persistence/encryption_test.dart` — log file is unreadable without the device key.

### 4.9 📊 Phase 4 KPIs

```jsonc
{
  "phase4": {
    "p50_move_latency_local_ms":   { "value": null, "threshold": 25  },
    "p95_move_latency_local_ms":   { "value": null, "threshold": 60  },
    "p95_move_latency_intra_ms":   { "value": null, "threshold": 150 },
    "p95_move_latency_relayed_ms": { "value": null, "threshold": 400 },
    "reconnect_success_rate":      { "value": null, "threshold": 0.97 },
    "ice_restart_success_rate":    { "value": null, "threshold": 0.92 },
    "turn_fallback_rate_global":   { "value": null, "threshold": 0.15 },
    "turn_fallback_rate_intra":    { "value": null, "threshold": 0.05 },
    "abort_rate":                  { "value": null, "threshold": 0.005 },
    "resume_after_kill_success":   { "value": null, "threshold": 0.95 },
    "battery_drain_per_hour_pct":  { "value": null, "threshold": 8    }
  }
}
```

### 4.10 ✅ Definition of done for Phase 4

- Two emulators on the same workstation can play a complete game across **all 7 mods**, each exercising its bespoke message types.
- Forced disconnect (`adb shell svc wifi disable && sleep 10 && adb shell svc wifi enable`) recovers within 15 s and the move log replays cleanly.
- iOS sim survives 60 s background → foreground with game intact.
- All Phase-4 tests green; no regressions in engine gates.
- Phase-4 KPIs measured and committed.

---

## 🧪 Phase 5 — Test, simulation & CI strategy 🤖

> **Goal:** Prove the system works without humans in the loop, across all 7 mods, under hostile network conditions.

### 5.1 🧪 Test pyramid (7 layers)

| # | Layer       | Where                                     | What it covers                                         |
|---|-------------|-------------------------------------------|--------------------------------------------------------|
| 1 | 🟢 Unit      | `frontend/test/p2p/{protocol,identity,clock}/` | Codec, signing, hash chain, key backup, monotonic time. |
| 2 | 🟡 Property  | `frontend/test/p2p/protocol/` (`glados`)  | Round-trip codec, hash-chain integrity under permutation. |
| 3 | 🟠 Component | `frontend/test/p2p/transport/`            | DataChannel wrapper with loopback signaling + 2 in-process peers. |
| 4 | 🔵 Integration | `frontend/test/p2p/game_session/`        | Full handshake → mod-specific scripted game → graceful end. |
| 5 | 🔴 E2E (emu) | `scripts/p2p/run_two_emulator_match.sh`   | Two AVDs play a real game over loopback signaling.     |
| 6 | 🌪️ Chaos    | `scripts/p2p/chaos.sh`                    | tc-netem packet loss / 200 ms latency / one-side disconnect / NAT rebind. |
| 7 | 🕒 Soak      | `scripts/p2p/soak.sh`                     | 3-hour rapid game, 24-hour idle-lobby, leak detection. |
| 8 | ⚫ Server    | `signaling/internal/**/*_test.go` + `fuzz/` | Lobby logic, signature middleware, rate limits, fuzz. |

### 5.2 🌪️ Chaos scenarios (named, not "etc.")

The `scripts/p2p/chaos.sh` driver runs these named scenarios; each has a deterministic pass criterion:

| Scenario                         | Injection                                             | Pass criterion                                  |
|----------------------------------|-------------------------------------------------------|-------------------------------------------------|
| `loss-1pct`                      | 1 % uniform packet loss                               | game completes, p95 ≤ 200 ms                    |
| `loss-5pct`                      | 5 % uniform                                           | game completes, p95 ≤ 400 ms                    |
| `loss-burst-20pct-200ms`         | 20 % loss in 200 ms bursts every 10 s                 | game completes, ≤ 1 ICE restart                 |
| `latency-200ms`                  | 200 ms one-way latency                                | clock model holds, no false flags               |
| `latency-jitter-100±50ms`        | jitter                                                | adaptive ping kicks in, UI shows badge          |
| `bandwidth-throttle-64kbps`      | extreme throttle                                      | game completes (envelopes are tiny)             |
| `disconnect-then-reconnect-10s`  | drop one peer's network for 10 s                      | ICE restart succeeds                            |
| `disconnect-then-reconnect-45s`  | drop for 45 s (past blitz grace)                      | adjudication fires correctly                    |
| `nat-rebind`                     | rebind one peer's NAT mid-game                        | ICE restart succeeds                            |
| `wifi-to-cellular-swap`          | Android only; swap network mid-game                   | proactive ICE restart, no game loss             |
| `signaling-server-restart`       | restart server during in-game                         | in-game peers unaffected                        |
| `signaling-server-deploy-drain`  | blue/green deploy mid-lobby-create                    | client retries on standby, no user-visible drop |
| `clock-skew-2s-jump`             | one peer's wall clock jumps 2 s                       | monotonic path holds, no false flag             |
| `clock-skew-malicious-underflag` | one peer reports false low `remaining_ms`             | flag dispute wins via hash-chained evidence     |
| `mitm-server-rewrite-sdp`        | server rewrites SDP                                   | handshake `PAIRING_PUBKEY_MISMATCH` aborts      |
| `replay-old-envelope`            | replay an envelope from earlier ply                   | nonce cache rejects                             |
| `corrupt-envelope-bitflip`       | flip 1 bit in a signed envelope                       | signature fails, game continues with retransmit |

### 5.3 🧰 Local simulation environment

A new top-level script set under `scripts/p2p/`:

- `bootstrap.sh` — installs (with confirmation per AGENTS.md §4): `adb`, `tc` (netem), the signaling server's deps. Starts:
  - 🛰️ Local signaling server (`make run` in `signaling/`) on `localhost:8787`.
  - 🧱 Local `coturn` in Docker on `localhost:3478` with a static dev secret.
  - 📨 Local FCM/APNs **stub** server (Node tiny mock) for invite-push tests.
- `run_two_emulator_match.sh <mod> <time-control>`:
  1. Boots two named AVDs (`avd_p2p_a`, `avd_p2p_b`) if not running.
  2. `flutter install` the debug APK on both, with `--dart-define=SIGNALING_URL=ws://10.0.2.2:8787/v1/lobby` and `--dart-define=TURN_URL=turn:10.0.2.2:3478`.
  3. Drives both apps via [`integration_test`](https://pub.dev/packages/integration_test) + [`patrol`](https://pub.dev/packages/patrol):
     - Create lobby on A → read invite code from screen.
     - Join lobby on B with that code.
     - Play a scripted opening (reuses `agent/openings/<mod>.csv` line 1).
     - Let on-device engines (skill-capped) play out 30 plies.
     - Assert game completes, both clients show identical PGN, hash chain validates, all expected mod-specific message types appear.
  4. Tears down emulators (or leaves them up via `--keep`).
- `run_all_mods.sh <time-control>` — runs `run_two_emulator_match.sh` for all 7 mods sequentially, each with its own report under `agent/reports/_p2p/<run-id>/<mod>/`.
- `chaos.sh <scenario>` — wraps the above with `tc qdisc` rules.
- `soak.sh <hours>` — runs a long game with periodic memory snapshots (`adb shell dumpsys meminfo`) + a leak threshold (≤ 5 MB growth per hour after warmup).

> 💡 The same scripts double as the **demo for stakeholders**: run `run_all_mods.sh 30s` on screen-share, watch two phones play all 7 mods.

### 5.4 🧯 CI

- 🟢 Layers 1–4 (unit / property / component / integration) run on every PR (existing Flutter test workflow + a new p2p job).
- ⚫ Server tests + fuzz (1 M iters) run in their own job (`signaling/`).
- 🔴 Layer 5 (E2E emulator) runs **nightly** on a self-hosted runner; emulators are heavy for hosted CI. Failures auto-open a `kind: p2p_regression` queue entry.
- 🌪️ Layer 6 (chaos) runs **weekly** for the full matrix; the `loss-1pct` and `disconnect-then-reconnect-10s` scenarios run nightly.
- 🕒 Layer 7 (soak) runs **weekly**; the 3-hour rapid game gates a release tag.
- 📲 **Optional (Phase 6+):** Firebase Test Lab matrix run on real devices for the top-10 Android handsets pre-release. Skipped in v1 to avoid GCP cost; revisit at beta.

### 5.5 📊 Phase 5 / cross-phase KPIs

`agent/baselines/p2p.json` is regenerated weekly. New `kind: p2p_regression` triggers when any KPI breaches its threshold, gated identically to engine KPIs.

### 5.6 ✅ Definition of done for Phase 5

- `scripts/p2p/run_all_mods.sh 1m` exits 0 on a clean checkout (after `bootstrap.sh`).
- Nightly CI green for **7 consecutive days** before declaring P2P beta.
- Weekly chaos matrix green for **3 consecutive weeks** before declaring P2P GA.

---

## 🚀 Phase 6 — Beta, telemetry, kill-switch & release 📣

> **Goal:** Ship to a small allow-list, learn, iterate. Be able to disable any feature in < 5 minutes without an app-store round-trip.

### 6.1 🧪 Closed beta

- 50–100 invitees via TestFlight + Google Play internal testing track.
- In-app feedback button wired to `POST /v1/feedback`.
- Crash & connection-quality reports auto-attach the redacted last 200 lines of the on-device log (user must confirm each submission — **no silent telemetry**).

### 6.2 🚦 Feature flags & kill switch

- `/v1/flags` returns a CBOR map of flag-name → bool/string. The client polls every 60 s while online (and on app foreground).
- Flags include:
  - `p2p_enabled` (master kill),
  - `mod_<name>_enabled` (per-mod kill),
  - `premove_enabled`, `takeback_enabled`, `engine_corr_optin_enabled`,
  - `min_supported_client_build` (forced upgrade — see §6.3),
  - `turn_required_regions` (force TURN in known-broken networks).
- Flags are signed by the server's long-term key; client verifies the signature before applying. This prevents a hijacked DNS from disabling features.
- Documented operational procedure in `docs/signaling/KILL_SWITCH.md`: who can flip, how to verify, how to roll back.

### 6.3 ⏫ Forced upgrade flow

- `min_supported_client_build` < installed build ⇒ app shows a non-dismissible "Update required" dialog with deep-links to the App Store / Play Store.
- Used when a wire-incompatible protocol fix ships, or a security advisory hits.
- We commit to never raising `min_supported_client_build` more aggressively than 14 days behind the latest release, except for security incidents.

### 6.4 🔍 Engine-correlation report (anti-cheat, opt-in)

- Post-game, both players see "Submit this game for an engine review (anonymous)" with a link to PRIVACY.md.
- On opt-in, the **PGN only** (no identifying metadata beyond pubkey hash) is uploaded.
- Server runs a depth-12 audit-batch-style analysis against the submitted PGN per mod and writes a verdict to `agent/reports/_p2p_corr/`.
- Verdicts above the per-mod threshold are reviewed manually before any user-facing action (suspension is a human decision in v1; automated bans are out of scope).

### 6.5 🚩 In-app player report

- A single-tap "Report player" surfaces in the post-game screen.
- Required: a reason (cheating / harassment / disconnect-abuse / other) + the pubkey hash of the opponent.
- Optional: free-text note + auto-attached redacted last-game log.
- Reports go to `POST /v1/report-player`. Three reports against the same pubkey within 7 days raise an internal flag for review.

### 6.6 📊 What we measure (server-side, anonymized)

- Lobby creation rate, invite redemption rate, time-to-first-move.
- ICE candidate-pair type distribution (host / srflx / relay).
- Reconnection frequency & success.
- Per-mod completion rate.
- Forced-upgrade adoption curve.

### 6.7 🚫 What we don't measure

- Move content. Outcomes. Player handles. Geographic location beyond the IP needed for ICE (and that's purged after 7 days per §3.3).

### 6.8 🪪 Public release checklist

- [ ] Privacy notice ([docs/signaling/PRIVACY.md](signaling/PRIVACY.md)) reviewed and linked from in-app *About*.
- [ ] App-store submission updated to declare networking + microphone-not-used + camera-not-used + push-notification usage rationale.
- [ ] Signaling server has runbook + on-call expectations documented.
- [ ] Kill-switch verified end-to-end against staging.
- [ ] All Phase-0..5 *Definition of done* boxes checked.
- [ ] One full week of green nightly CI **and** three weeks of green weekly chaos.
- [ ] 3-hour soak test green on both Android and iOS reference devices.
- [ ] GDPR data-export (`Settings → Export my data`) and deletion (`Settings → Delete my data`) flows implemented and tested.
- [ ] Responsible-disclosure contact published (`docs/signaling/SECURITY.md`).

---

## 🔭 Phase 7 — Stretch goals (post-1.0) ✨

- 🌍 **Multi-region signaling + geo-TURN selection** (latency-based candidate ordering).
- 🏆 Optional **ELO / Glicko-2 ratings** (opt-in; published only with consent; per-mod separate ratings).
- 🎫 **Tournament brackets** (server-managed pairing only; play stays P2P).
- 👀 **Spectator mode** — signed read-only relay through the ops server, with a 30-s delay to discourage live coaching.
- 🤝 **Friends list** backed by exchanged public keys, attached to the optional stats account (§2.2) so it survives device loss; for users without an account, the list lives only in the local encrypted backup blob.
- 🔄 **Cross-device identity migration** via QR code + signed transfer envelope.
- 🤖 **Open matchmaking** queues (with moderation surface — careful, this is a chunky scope).
- 🧠 **Automated engine-correlation flagging** with human-in-the-loop review.
- 🌐 **Server-relayed reconnect** for users behind double-NAT where ICE restart fails repeatedly.

---

## 🛡️ Security threat model (expanded in v2)

| # | Threat                                                | Mitigation                                                                                                |
|---|-------------------------------------------------------|-----------------------------------------------------------------------------------------------------------|
| 1 | Signaling server MITM swaps SDP                       | First SDP signed by long-term key; opponent verifies before answer.                                       |
| 2 | Replay of past moves                                  | `(game_id, ply, nonce)` uniqueness + 64-nonce per-game cache + hash chain.                                 |
| 3 | Spoofed move from non-peer                            | Every envelope signed; receiver pins opponent pubkey at handshake.                                         |
| 4 | Engine-rule mismatch (different mod versions)         | `engine_hash` + `rules_version` exchanged at handshake; mismatch refuses game.                             |
| 5 | TURN credential abuse                                 | Short-lived HMAC creds (≤ 5 min), per-pubkey + per-IP + per-/24 rate limits.                              |
| 6 | DoS on signaling server                               | 3-tier token bucket; CDN/WAF in front of HTTPS; body-size caps.                                           |
| 7 | Stolen device → identity theft                        | Hardware-backed keystore where available; user can revoke + rotate; old games remain attributed to old key.|
| 8 | Cheating with engine assistance                       | Per-mod independent rule validation + opt-in engine-correlation report.                                    |
| 9 | Privacy leakage via logs                              | IP retention 7 days; logs scrubbed; no move content stored server-side.                                    |
| 10 | Wall-clock manipulation                              | Monotonic clock authoritative; wall clock advisory; flag-claim adjudicated via signed log, not server.    |
| 11 | Premove flood / DataChannel exhaustion               | Backpressure + premove rate limit + per-state allowed-message whitelist.                                   |
| 12 | Modified-build opponent (silent rule change)         | Attestation lite (apk hash gossip); UI badge; engine_hash mismatch refuses game.                          |
| 13 | Server-published flag tampering (DNS hijack)         | Flags signed by server's long-term key; client verifies before apply.                                      |
| 14 | Replay attack on signaling endpoints                 | Server-side nonce cache (5 min) on every signed request.                                                   |
| 15 | Push-token leakage → spam push to user               | Push tokens signed-on-register; per-pubkey rate limit on push send; user can revoke from Settings.        |
| 16 | Game-log exfiltration from a stolen unlocked phone   | Logs encrypted at rest under device-key-derived subkey.                                                    |
| 17 | Symmetric-NAT / CGNAT preventing direct connection   | TURN relay fallback; clearly badged in UI; not treated as failure.                                         |
| 18 | iOS background suspension mid-move                   | Persist + push-resume; ICE restart on foreground; grace window protects the suspended player.             |
| 19 | Lost-passphrase, lost-key recovery (account opted in)| Recovery codes (always issued) + optional verified email (§2.2.4); device key revoked on rebind.          |
| 20 | Lost-passphrase, lost-key recovery (no account)      | No server-side reset; user is told this loud and clear; new identity is the documented path.              |
| 21 | Compromised maintainer publishes malicious build     | Reproducible-build effort tracked as a Phase-7 stretch; APK hash gossip alerts users to unexpected hash.  |
| 22 | Server-side breach leaks account DB                  | Recovery codes Argon2id-hashed (m=64MB, t=3); emails peppered + HMAC'd; ELO/W/L/D leak is acceptable but no impersonation possible (no private keys stored). On detection: rotate pepper, force email re-verification, post advisory. |
| 23 | Stolen phone, then user wipes-and-restores           | Hardware-backed keystore + `/v1/accounts/lock` + per-bind 24-h cooldown + `account_rebound` push notice (§2.2.5). |
| 24 | Recovery-code brute force                            | Argon2id at 64 MB / t=3 raises offline cost; server-side 5-wrong-in-1-h lockout for online attempts; account auto-lock at 20 wrong / 24 h. |
| 25 | Magic-link interception (email account compromise)   | Magic-link tokens are 15-min single-use; rebind triggers a `key_rotation` cert + push notice to any prior active device; user can lock the account from the prior device if they still have it. |
| 26 | Stats forgery (one peer claims a fake win)           | `/v1/stats/update` requires **both** peers' signatures over the same result envelope; disconnect adjudication co-signed by the server's witness key. |
| 27 | Reuse of consumed recovery code                      | `recovery_codes_used` counter + per-code consumption flag; verification rejects consumed codes; codes regenerate at ≥ 8 used. |
| 28 | Server lies about a peer's ELO in `/v1/stats/lookup` | Lookup is advisory UX only ("Opponent rating: 1480"); no in-game decision depends on it. Future Phase-7: each stats row is signed by the server's long-term key + a sliding Merkle root the user can verify. |

---

## 🧱 Failure-mode catalog (new in v2)

Every failure has a code, a UI string, and a recovery action. Codes are stable (semver-bumped only).

| Code                              | Where surfaces      | Recovery                                  |
|-----------------------------------|---------------------|-------------------------------------------|
| `LOBBY_FULL`                      | Lobby create        | Retry later                               |
| `INVITE_EXPIRED`                  | Lobby join          | Ask host to re-share                      |
| `INVITE_TAKEN`                    | Lobby join          | Different player already redeemed; ask host |
| `PAIRING_PUBKEY_MISMATCH`         | Lobby join          | Abort; surface MITM warning               |
| `HELLO_PUBKEY_MISMATCH`           | Handshake           | Abort                                     |
| `ENGINE_HASH_MISMATCH`            | Handshake           | Both update                               |
| `RULES_VERSION_MISMATCH`          | Handshake           | Both update                               |
| `ICE_GATHER_TIMEOUT`              | Connecting          | Retry with TURN forced                    |
| `ICE_RESTART_FAILED`              | InGame → reconnect  | Move to PausedOffline                     |
| `OPPONENT_PROTOCOL_VIOLATION`     | InGame              | End game; auto file issue                 |
| `OPPONENT_KEY_CHANGED`            | InGame              | Abort                                     |
| `CLOCK_RESYNC_FAILED`             | InGame              | Offer draw                                |
| `FLAG_CLAIM_DISPUTED_LOST`        | Flag claim          | Game continues for the other peer         |
| `LOBBY_DRAINING`                  | Lobby create        | Retry on standby                          |
| `RATE_LIMITED`                    | Any signaling call  | Backoff per `Retry-After`                 |
| `REVOKED_KEY`                     | Lobby create        | Generate new identity                     |
| `MIN_CLIENT_BUILD`                | Any                 | Forced upgrade dialog                     |
| `P2P_DISABLED_BY_FLAG`            | App start           | Read-only mode + notice                   |
| `ACCOUNT_NOT_FOUND`               | Account lookup      | Offer create-account flow                 |
| `ACCOUNT_LOCKED`                  | Any account op      | Show recovery flow (code or email)        |
| `RECOVERY_CODE_INVALID`           | Rebind              | Try a different code; if 5 wrong → wait 24 h |
| `RECOVERY_CODE_LOCKOUT`           | Rebind              | Use email magic link or wait 24 h         |
| `RECOVERY_CODES_EXHAUSTED`        | Rebind              | Use email magic link; if no email → cannot recover |
| `RECOVERY_EMAIL_NOT_VERIFIED`     | Rebind              | Verify email first                        |
| `MAGIC_LINK_EXPIRED`              | Rebind              | Re-request magic link                     |
| `MAGIC_LINK_REUSED`               | Rebind              | Re-request; previous link is consumed     |
| `REBIND_COOLDOWN_ACTIVE`          | Rebind              | Wait 24 h or enter a second recovery code |
| `STATS_RESULT_MISMATCH`           | `/v1/stats/update`  | Both peers must submit matching envelopes; auto-retry on next foreground |
| `STATS_SUBMIT_RATE_LIMITED`       | `/v1/stats/update`  | Backoff per `Retry-After`                 |

---

## 🧭 Open questions (must be answered before Phase 3 ships)

1. ❓ **Hosting region(s) for v1?** Single region for beta (probably EU-Central given the maintainer's location); multi-region pushed to Phase 7. Confirm before Phase 3 close.
2. ❓ **Anonymous lobbies vs invite-only at v1?** Recommend invite-only at v1 to dodge moderation work. Confirmed by Phase 2 close.
3. ❓ **Push provider funding model.** APNs is free; FCM is free. Bandwidth on TURN relay is not — set a monthly budget and a hard cutoff in `/v1/turn-credentials`.
4. ❓ **Reproducible-build commitment** — defer to Phase 7 or commit to it for v1 to support attestation? Defer recommended.
5. ❓ **Web build of the Flutter app** — does P2P need to work in browser? If yes, `flutter_webrtc`'s web bindings change the keystore story (browsers don't have hardware key storage). Recommend "mobile-only at v1, web tracked as Phase-7 stretch."

---

## 📅 Sequencing (gated by green tests, not calendar)

```
P0 Cleanup ──► P1 Protocol ──► P2 Identity ──► P3 Server ──► P4 WebRTC ──► P5 Sim/CI ──► P6 Beta ──► P7 Stretch
                          │                              │              │
                          └────── golden + property tests ┴── shared ───┘
                                  unblock P2/P4 in parallel
```

P1 and P2 can be developed in parallel after P0; P3 and P4 unblock as soon as P1's protocol is locked. P5 work begins as soon as the first P4 happy-path passes locally. **A phase is "done" only when its KPI table is populated and its DoD checklist is fully checked.**

---

## 📚 References & follow-ups

- WebRTC primer: <https://webrtc.org/getting-started/overview>
- `flutter_webrtc` docs: <https://pub.dev/packages/flutter_webrtc>
- coturn config: <https://github.com/coturn/coturn>
- Ed25519 in Dart: <https://pub.dev/packages/cryptography>
- CBOR (RFC 8949): <https://www.rfc-editor.org/rfc/rfc8949>
- CDDL (RFC 8610): <https://www.rfc-editor.org/rfc/rfc8610>
- JCS (RFC 8785): <https://www.rfc-editor.org/rfc/rfc8785>
- BLAKE3: <https://github.com/BLAKE3-team/BLAKE3>
- Will spawn follow-up docs:
  - `docs/signaling/RUNBOOK.md` (Phase 3)
  - `docs/signaling/PRIVACY.md` (Phase 3)
  - `docs/signaling/SECURITY.md` (Phase 3)
  - `docs/signaling/THREAT_MODEL.md` (Phase 3)
  - `docs/signaling/KILL_SWITCH.md` (Phase 6)
  - `frontend/lib/services/p2p/protocol/README.md` (Phase 1)
  - `archive/backend-go-legacy/README.md` (Phase 0)

---

> _"Ship the thinnest server you can defend, encrypt everything else, sign every move, time it on a monotonic clock, and let two phones do the talking."_ 🤝♟️
