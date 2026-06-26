# ChessRecast — P2P Fair-Play Policy

> **Phase 13 scope declaration.** This document states what the pure peer-to-peer
> architecture of ChessRecast **can** and **cannot** do with respect to fair play
> and cheat detection. It is intentionally honest: users deserve to know the
> limits before they play.

## What we cannot do

### External-engine assistance

A player using an external engine (e.g. running Stockfish in another window and
copying moves) **cannot be detected by ChessRecast's peer-to-peer architecture**.
There is no central observer — no server that watches move quality across sessions.
This is a fundamental property of the dumb-signaling design: the signaling server
sees only ICE offers and never sees a single chess move.

**Our position:** ChessRecast is a casual play platform. We make no claim of
anti-cheat enforcement. The first-launch disclosure reads:

> **Casual play — no anti-cheat enforcement.** ChessRecast is a peer-to-peer chess
> game. There is no server observing move quality. Treat every game as a friendly,
> unrated match.

### Rating system

A rating system similarly requires either a central observer (which contradicts the
dumb-signaling principle) or a federated trust network capable of aggregating
game results with cryptographic guarantees. Neither is in scope for v1.

This is tracked as **OQ-10** in the project's open questions list. If a future
federated rating service ships (see Phase 7 and §13.3 of the roadmap), it would
subscribe to both peers' signed transcripts — with explicit consent — to run
aggregate cheat detection (centipawn-loss outlier detection, time-control anomaly
detection). That future path remains open by design: transcripts are signed and
carry `engine_replay_version` so they are auditable.

## What we can offer (partial mitigations)

The following features are **opt-in, informational, and non-accusatory**. They
hint at engine assistance but never accuse. They cannot end a game or restrict a
player.

### No-engine pledge (`no_engine_pledge` in `HELLO`)

A player can set a soft pledge in their `HELLO.capabilities.no_engine_pledge`
field before a game starts. The opponent's UI will show:

> *Opponent has pledged not to use engine assistance.*

This is a gentleman's agreement. It is not cryptographically enforceable; a
dishonest player can pledge and still cheat. The flag exists to surface the social
norm and make expectations explicit.

### Move-time histogram (opt-in, mutual)

When both peers opt in (`HELLO.capabilities.histogram_ok: true`), each peer shares
its per-move think-time histogram at game end. Suspiciously low variance combined
with high-quality moves may hint at engine assistance — but this is left entirely
to the player's judgment. The UI never displays an accusation.

**Integrity guarantee:** the displayed histogram is computed from the **local
clock** — each peer measures how long it waited for the opponent's move. The
opponent cannot forge or suppress the histogram shown to the other side.

### Casual / Friend mode (`casual_mode: true` in `HELLO`)

When both peers set `casual_mode=true` (typically after mutual QR-code
contact-graph verification), the session enables takebacks and disables histogram
sharing. This is the natural mode for in-person friendly games where the social
contract replaces the need for informational tools.

## Future federated-rating door

If Phase 7 federation ever ships, a third-party rating service could, with both
peers' consent, subscribe to signed game transcripts and run aggregate cheat
detection (CPL outlier detection, time-control anomaly detection). This is tracked
as **OQ-10**. The cryptographic transcript design (signed move lists,
`engine_replay_version` pinning, game-end `BYE` signing) is forward-compatible
with such a service.

## Quality attributes

- **Performance / Efficiency:** the pledge, histogram, and casual-mode features
  are UI-surface only. They carry no per-move runtime cost and do not affect engine
  evaluation or move latency.
- **Stability:** these features are informational. They can never end a game,
  trigger a forfeit, or cause a `MISMATCH`. A failure to share a histogram at
  game end is a silent no-op.
- **Reliability:** this document accurately reflects what is and is not
  enforceable. No guarantees of cheat detection are made or implied.
- **Integrity:** histogram data shown to a peer is derived exclusively from that
  peer's own local clock measurements, not from the opponent's self-report. An
  opponent cannot inflate or suppress the timing data that the other side sees.

## Acceptance gate (Phase 13.5)

- This document (`docs/p2p/P2P_FAIR_PLAY.md`) is the primary artifact of Phase 13.
- The UI displays the casual-play disclosure on first P2P launch.
- All proof tests under `frontend/test/p2p/anti_cheat/` must be green.

---

*Last updated: Phase 13 implementation. See `docs/p2p/P2P_ROADMAP.md` §Phase 13 for
the full leaf checklist and acceptance criteria.*
