# 🗺 ROADMAP — chessrecast

> Single source of truth for sequenced work in this repository. Agents
> implement against this file phase-by-phase, drain every `[ ]` bullet in
> scope, append tracking rows, then stage.

## 📊 Status snapshot

Update with `make roadmap.status` (parses the `[ ]` / `[x]` boxes below).

| Phase | Description | Status |
|---|---|---|
| 0 | Framework + scaffold | ✅ done |
| 1–6 | P2P multiplayer | ✅ done |
| 7 | Stretch features | ✅ done |
| 8 | Chess engine improvements (ongoing) | 🔄 ongoing |

## 🧭 Guiding principles

- Smallest change that turns the test green.
- Tests move with code in the same commit.
- Reversible > impressive.
- One owner per phase; one tracking `run_id` per implementation pass.
- Chess-engine quality gate: see [`docs/project/ENGINE_RULES.md`](../project/ENGINE_RULES.md).

## 📑 Table of contents

- [Phase 0 — Foundation](#phase-0--foundation)
- [Phase 1–6 — P2P multiplayer](#phase-16--p2p-multiplayer)
- [Phase 7 — Stretch features](#phase-7--stretch-features)
- [Phase 8 — Chess engine improvements](#phase-8--chess-engine-improvements)
- [Appendix A — Tracking conventions](#appendix-a--tracking-conventions)
- [Appendix B — Definition of done](#appendix-b--definition-of-done)

---

## Phase 0 — Foundation

**Goal.** Repository skeleton, CI-equivalent local gates, framework scaffold.

**Scope id.** `phase-0`

### Bullets

- [x] Flutter + native chess engine (FFI) project structure.
- [x] Go signaling server scaffolded.
- [x] Makefile + xops scripts wired.
- [x] ai-vscode-basics scaffold installed (AGENTS.md, skills, agents, prompts).
- [x] Tracking model migrated to `docs/tracking/tracking.csv` (9-column).
- [x] Engine rules documented at `docs/project/ENGINE_RULES.md`.

---

## Phase 1–6 — P2P multiplayer

**Goal.** Full peer-to-peer multiplayer via WebRTC + signaling server.

**Scope id.** `phase-p2p`

**Reference.** [`docs/p2p/P2P_ROADMAP.md`](../p2p/P2P_ROADMAP.md) — all phase checkboxes live there.

### Bullets

- [x] Phase 1: signaling server (Go, WebSocket).
- [x] Phase 2: WebRTC peer connection (Flutter).
- [x] Phase 3: game state sync over data channel.
- [x] Phase 4: identity + KDF key derivation.
- [x] Phase 5: reconnect + reliability.
- [x] Phase 6: load test + production hardening.

---

## Phase 7 — Stretch features

**Goal.** Post-launch polish and community-facing features.

**Scope id.** `phase-7`

### Bullets

- [x] Opening book integration (`bots/openings/`).
- [x] P2P fair-play policy (`docs/p2p/P2P_FAIR_PLAY.md`).
- [x] GDPR / privacy checklist (`docs/p2p/P2P_GDPR_CHECKLIST.md`).
- [x] Android OEM matrix (`docs/p2p/P2P_ANDROID_OEM_MATRIX.md`).

---

## Phase 8 — Chess engine improvements

**Goal.** Continuously improve mod quality scores via the audit gate loop.

**Scope id.** `phase-8`

**Reference.** [`bots/queue.yaml`](../../bots/queue.yaml) — per-mod work items.
**Rules.** [`docs/project/ENGINE_RULES.md`](../project/ENGINE_RULES.md) — quality charter + audit gate.

### Active mods

- [ ] `heir` — improve game-quality score
- [ ] `friendly_fire` — improve game-quality score
- [ ] `kings_battle` — improve game-quality score
- [ ] `mercenary` — improve game-quality score
- [ ] `save_the_queen` — improve game-quality score
- [ ] `succession` — improve game-quality score
- [ ] `truce` — improve game-quality score

---

## Appendix A — Tracking conventions

Every agent action appends a row to [`docs/tracking/tracking.csv`](../tracking/tracking.csv)
via `xops/agent/tracking_append.sh`. Schema: `ts_utc, run_id, agent, scope,
action, status, summary, refs, commit_sha`. Run `make track.list` to inspect.

## Appendix B — Definition of done

A phase is done when:
1. All `[ ]` bullets in scope are ticked to `[x]`.
2. `make doctor` exits 0.
3. `make verify` exits 0 (or a clear note explains why it cannot run yet).
4. One tracking row with `action=commit, status=completed, commit_sha=pending`.
5. `git add -A` run; human runs `make git` to push.
