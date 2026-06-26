# 📊 Project State Assessment — chessrecast

> **Date:** 2026-06-26 · **Author:** Copilot (agent assessment) · **Branch:** `main` @ `e08092d`
> **Scope:** Whole-repository health snapshot + prioritized next steps.
> Generated from a read-only inspection of source, docs, tracking, and the
> bot improvement queue. No code was changed to produce this report.

---

## 1. Executive summary

ChessRecast is in a **mature, broadly feature-complete** state. The three
product surfaces — the Flutter app + native C engine, the seven rule-variant
mods, and the Go WebRTC signaling server — are all implemented with strong
test coverage (a >1:1 test-to-source line ratio overall). The agent framework
(`make doctor`) is green and the working tree is clean.

The project is no longer in a "build the features" phase; it is in a
**"harden, reconcile, and verify"** phase. The highest-value work now is not
new features but: (a) closing the gap between *stated* gates and *actual*
gates, (b) reconciling documentation that has drifted from reality, and
(c) draining the small backlog of open engine-quality findings — including
one **critical**-severity tactical blunder.

| Dimension | State |
|---|---|
| Feature completeness | 🟢 High — P2P (Ph 1–7) + 7 mods shipped |
| Test coverage | 🟢 Strong — 323 Dart test files, 254 P2P tests |
| Framework health (`make doctor`) | 🟢 Passing |
| Engine quality backlog | 🟡 8 open items (1 critical, 1 high) |
| Documentation accuracy | 🟡 Drift between roadmaps + stale evidence paths |
| `make verify` coverage | 🔴 Does **not** run app/engine/Go tests |

---

## 2. What the project is

An **offline-first, open-source chess app** with novel rule variants and true
peer-to-peer multiplayer — no accounts, no central game server. (Source:
[docs/project/CHARTER.md](../project/CHARTER.md).)

- **Cross-platform Flutter app** embedding a native **C chess engine via FFI**.
- **Seven rule-variant mods**: `heir`, `friendly_fire`, `kings_battle`,
  `mercenary`, `save_the_queen`, `succession`, `truce`.
- **P2P multiplayer** over WebRTC data channels, brokered by a minimal **Go
  signaling server** that relays SDP/ICE only — game moves never transit it.
- A **bot-driven quality loop** (`bots/`) that autonomously audits and improves
  each mod against KPI baselines.

---

## 3. Component-by-component state

### 3.1 Native chess engine + mods (Phase 8 — ongoing)

| Metric | Value |
|---|---|
| C/H files | 45 |
| Engine LOC | ~13,962 |
| Eval mod files | 7 (+ `eval_common.c`, `eval_types.h`) |
| Baseline JSON snapshots | 20 in [bots/baselines/](../../bots/baselines/) |
| Queue entries | 106 total — **95 done**, 4 blocked, 4 failed, 3 example |

Mod isolation is well-architected: each mod's logic is confined to
`eval_<mod>.c` and per-mod `*_refine_result` blocks, with shared engine core
(`move_generator.c`, `board.c`, `types.c`) explicitly out-of-bounds per
[docs/project/ENGINE_RULES.md](../project/ENGINE_RULES.md). The audit gate
(regression test → castling policy → rule mechanics → widget → 50-game batch →
KPI delta < 5%) is rigorous and demonstrably enforced — the tracking log shows
patches **reverted** when KPIs regressed, which is exactly the discipline you
want.

Reference baseline (`heir`): `avgWorstMiss=50cp`, `maxWorstMiss=159cp`,
`blundersGte200cp=0`, `earlyKingMoves=7`, `castlingRightLosses=5`. Healthy.

### 3.2 P2P multiplayer (Phases 1–7 — shipped)

| Metric | Value |
|---|---|
| `lib/**/p2p` Dart files | 94 |
| `test/**/p2p` Dart files | 254 |
| Signaling Go files | 102 (~8,616 LOC) |
| Signaling internal packages | 24 (`auth`, `offers`, `turn`, `rebind`, `recovery`, `abuse`, `privacy`, `dsar`, `cve`, `federation`, `spectator`, `transcript`, …) |
| P2P design docs | 25 in [docs/p2p/](../p2p/) |

This is the most elaborately engineered surface. The git history confirms real,
sequenced delivery through Phase 17 (`feat(p2p-17): end-to-end budget tree`,
`feat(p2p-14): chat moderation/blocking`, `feat(p2p-12): engine replay-version
pinning`, etc.). The signaling server has production-grade concerns already
broken out into packages (rate-limiting, abuse, CVE watch, DSAR/privacy,
attestation). Crypto design is mature (XChaCha20-Poly1305, HKDF-derived session
salt, Argon2id floor, BIP-39 checksum).

### 3.3 Flutter frontend

| Metric | Value |
|---|---|
| `lib/` Dart files | 163 (~27,668 LOC) |
| `test/` Dart files | 323 (~32,240 LOC) |
| Test-to-source LOC ratio | ~1.16 : 1 |

Coverage is strong in absolute and relative terms. The FFI-only boundary (Dart
never calls chess logic directly) is a clean architectural rule.

### 3.4 Agent framework / tooling

`make doctor` passes all checks (scripts present + executable, all JSON configs
parse, tracking header correct, skill links resolve). Tracking, session
bootstrap, and CodeGraph integration are wired. Working tree is clean and the
last failure breadcrumb is marked resolved.

---

## 4. Open issues & risks

### 4.1 Engine-quality backlog (8 open items)

| Severity | ID | Status | Summary |
|---|---|---|---|
| 🔴 critical | `save_the_queen-tactics-game23-e6d7-blunder-20260507` | failed | `e6xf7` override fixed Gate 1–3 but Gate 4 regressed catastrophically (GAME 23 → +983 cp). Reverted. **Still open.** |
| 🟠 high | `shared-opening-book-native-scaffold` | failed | Combined regression gate failed ≥3 assertions across Friendly Fire + Truce; reverted. |
| 🟠 high | `save_the_queen-tactics-game18-qd1c2-blunder-20260507` | failed | Replay override regressed `earlyKingMoves` > 5%. *(Note: a later `…-rediscovery-20260508` task passed on r4 per the state log — verify whether this row is now stale.)* |
| 🟡 med | `mercenary-corpus-stress-pawn-development` | failed | Stress corpus exceeded KPI thresholds (castling retention). Needs curation favoring castling while keeping ≥30% stress coverage. |
| 🟡 med | `shared-search-quiescence-king-discipline` | blocked | Evidence artifact missing; cannot justify a shared-search change. |
| ⚪ — | `shared-kings-battle-discovery-runtime-budget-20260430` | blocked | — |
| ⚪ — | `shared-opening-book-move-order-priors` | blocked | — |
| ⚪ — | `p2p-phase0-archive-backend-shared-edit-20260515` | blocked | — |

Several historically "failed" items were later **closed as not-reproduced** on
re-probe, so the first action for each should be a fresh reproduction probe
before any code change.

### 4.2 Documentation drift (low-effort, high-clarity fixes)

1. **P2P roadmap banner is stale.** [docs/p2p/P2P_ROADMAP.md](../p2p/P2P_ROADMAP.md)
   still opens with `🟥 0% shipped — every checkbox in this document is empty`,
   yet it contains **725 `[x]`** boxes and the git log shows P2P shipped through
   Phase 17. The banner directly contradicts reality and should be updated.
2. **Stale evidence paths.** The `agent/` directory was migrated to `bots/`
   (commit `8205a80`), but [bots/queue.yaml](../../bots/queue.yaml) and the
   state log still reference `agent/reports/...` paths that no longer resolve.
   Many other evidence files live in `/tmp/agent-runs/` (ephemeral, already
   gone). Audit traceability is degraded.
3. **Eval filename mismatch.** [docs/tracking/context.md](../tracking/context.md)
   references `eval_save_the_queen.c`; the actual file is `eval_save_queen.c`.
4. **Phase 8 checkbox semantics.** [docs/planning/ROADMAP.md](../planning/ROADMAP.md)
   lists all 7 mods as `[ ]` under Phase 8 while the queue reports 0 pending /
   95 done — the representation of "ongoing" work is ambiguous.

### 4.3 `make verify` does not verify the product (highest-impact gap)

`make verify` currently delegates only to `make test`, which runs the **xops
framework's own bash tests** — not `flutter test`, not the C engine tests, not
`go test ./...`. Yet CHARTER success criterion #3 states *"The Flutter app
builds reproducibly on all six platforms with `make verify`."* There is a real
gap between the stated quality gate and what the gate actually executes. A green
`make verify` today does **not** imply the app or engine is green.

### 4.4 README is still a scaffold stub

[README.md](../../README.md) still contains the template placeholder
(*"Describe what this project does in one sentence"*) and a generic quickstart.
For an open-source project (a stated goal), the front door does not yet explain
how to build the app, the native engine, or run the signaling server.

---

## 5. Suggested next steps (prioritized)

### P0 — Reconcile gates & truth-in-docs (small, high leverage)

1. **Make `verify` real.** Add a `verify.full` (or extend `verify`) that runs
   `flutter test`, the native engine build (`cmake --build build/native/linux`
   first — see repo memory), and `go test ./...` for signaling. Gate the audit
   batch separately given its runtime. This closes §4.3 and backs CHARTER #3.
2. **Fix the P2P roadmap banner** and reconcile it with the actual `[x]` state
   (§4.2.1).
3. **Re-anchor evidence paths** `agent/reports/** → bots/reports/**` in
   `queue.yaml`; for missing artifacts, mark the item `blocked: evidence-missing`
   rather than leaving a dangling path (§4.2.2).
4. **Fix the `eval_save_queen.c` reference** in `context.md` (§4.2.3).

### P1 — Drain the engine backlog

5. **Re-probe each failed/blocked item** to confirm it still reproduces at
   baseline settings *before* attempting a fix (matches the project's own
   not-reproduced precedent).
6. **Prioritize the critical STQ `game23-e6d7` blunder.** A +983 cp Gate-4
   regression on a narrow override means the override is too blunt — pursue a
   replay-scoped fix consistent with the `game18` resolution recorded on
   2026-05-08, and verify the GAME 23 follow-up node (mirrors the repo-memory
   note about replay-sensitive STQ branches).
7. **Mercenary corpus curation** favoring castling retention while preserving
   ≥30% stress coverage.

### P2 — Open-source readiness & CI

8. **Write a real README** with per-surface build/run instructions (Flutter app,
   native FFI engine, signaling server) and a contributor on-ramp.
9. **Add CI** (e.g. GitHub Actions) mirroring the local gates. The repo already
   has the gate *structure*; a CI wire-up would catch regressions the local
   honor-system gates can miss — and P2P_ROADMAP itself flags CI as a
   prerequisite for ticking boxes.
10. **Persist audit reports** out of `/tmp/agent-runs/` into `bots/reports/` so
    every queue entry's evidence survives the session that produced it.

---

## 6. Bottom line

The build is solid and the engineering discipline (revert-on-regression, tests
move with code, mod isolation) is genuinely good. The risk is not in the code —
it is in the **gap between what the gates claim and what they check**, and in
**documentation that has drifted ahead of/behind reality**. Spend the next
cycle making `make verify` tell the truth, reconciling the roadmaps, and
clearing the eight open engine findings (the critical STQ blunder first). That
converts a feature-complete project into a *verifiably* feature-complete one.

---

### Appendix — methodology

Read-only inspection on 2026-06-26: `session-bootstrap.sh`, `make doctor`,
source/test line counts, `bots/queue.yaml` status tally, `bots/baselines/`,
`docs/planning/ROADMAP.md`, `docs/p2p/P2P_ROADMAP.md`, `docs/project/CHARTER.md`,
`docs/project/ENGINE_RULES.md`, `docs/tracking/context.md`, `Makefile`, and
`git log`. No files other than this report were modified.
