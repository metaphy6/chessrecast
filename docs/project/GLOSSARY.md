# 📖 Glossary — chessrecast

Domain terms used across this repo. Alphabetic.

## Chess / engine

| Term | Meaning |
|---|---|
| Audit batch | A run of N games (typically 50) over a fixed opening slice, used to measure mod quality KPIs. |
| Blunder | A move whose evaluation drops by more than the `blunder_threshold_cp` (default 200 cp). Blunders are the primary quality gate signal. |
| Centipawn (cp) | Unit of chess evaluation: 100 cp ≈ one pawn of advantage. Negative = Black is better. |
| Corpus curation | The process of revising an opening slice (`bots/openings/<mod>.csv`). Requires a `kind: corpus_curation` queue entry and immediate baseline refresh. |
| Discovery slice | `bots/openings/<mod>_discovery.csv` — ~100 rotating opening positions used to find new issues. Refreshed periodically. |
| Eval hook | A C function (`eval_<mod>.c`) called by the shared engine to apply mod-specific evaluation adjustments. |
| FEN | Forsyth-Edwards Notation — a compact string encoding a chess position. The engine uses FEN as its primary position representation. |
| Fixed gate slice | `bots/openings/<mod>.csv` — exactly 50 stable positions used by every audit batch and baseline computation. |
| Gate | A quality checkpoint. A mod passes a gate when its KPI delta vs the stored baseline is within tolerance and no blunder exceeds the threshold. |
| KPI | Key Performance Indicator for a mod. Tracked in `bots/baselines/<mod>.json`. Primary KPIs: `avgWorstMiss_cp`, `maxWorstMiss_cp`, `earlyKingMoves`, `castlingRightLosses`, `kingExposureIndex_avg`. |
| Mod | A chess rule variant. Current mods: `heir`, `friendly_fire`, `kings_battle`, `mercenary`, `save_the_queen`, `succession`, `truce`. Each mod has its own eval file, baseline, opening slices, and queue entries. |
| Opening | The initial sequence of moves leading to the starting position for an audit game. Stored as a semicolon-separated move string in the opening CSV. |
| Plies | Half-moves. A game of `max_plies=12` plays 6 full moves. The engine audit uses shallow search (typically 4–12 plies). |
| Stress slice | `bots/openings/<mod>_stress.csv` — ~30 adversarial positions designed to expose known failure modes. |

## P2P / networking

| Term | Meaning |
|---|---|
| Data channel | A WebRTC SCTP data channel used to send game moves between peers. All game traffic flows through this channel after the handshake. |
| DTLS | Datagram TLS — the encryption layer used by WebRTC data channels. |
| ICE | Interactive Connectivity Establishment — the protocol that finds the best network path between peers. |
| ICE candidate | A network address/port pair that a peer advertises during ICE negotiation. |
| KDF | Key Derivation Function. Used in `bots/baselines/p2p_kdf_kat.json` to derive session keys from a shared secret. |
| MoveFrame | The CBOR-encoded message type for a game move sent over the data channel. Defined in `frontend/lib/services/p2p/protocol/frame.dart`. |
| NAT traversal | The process of establishing a direct connection between two peers behind NAT using STUN and ICE. |
| Room | A temporary in-memory pairing slot on the signaling server. Identified by a short random token. |
| RTT | Round-Trip Time — the latency for a move to travel from one peer and a response to return. P2P budget: < 200 ms (LAN), < 500 ms (WAN). |
| SDP | Session Description Protocol — describes the media capabilities and network parameters exchanged during WebRTC setup. |
| Signaling | The out-of-band channel (WebSocket to the Go server) used to exchange SDP and ICE candidates before the WebRTC connection opens. |
| STUN | Session Traversal Utilities for NAT — a server that tells a peer its public IP/port. |
| TURN | Traversal Using Relays around NAT — a relay server for peers that cannot connect directly. |

## Agent framework

| Term | Meaning |
|---|---|
| Action | The type of event recorded in a tracking row. Values: `commit`, `note`, `revert`, `block`, `test`. |
| Baseline | A JSON file (`bots/baselines/<mod>.json`) recording the last-known-good KPI values for a mod. The audit gate compares against this. |
| Checkpoint | `docs/tracking/state/checkpoint.json` — written when a session is interrupted mid-task, enabling safe resume. |
| Queue entry | A YAML object in `bots/queue.yaml` describing a pending improvement task. Fields: `id`, `mod`, `status`, `kind`, `phase`, `severity`, `evidence`, `notes`. |
| Run | A single agent invocation identified by a `run_id` (format: `<scope>-<timestamp>-<nonce>`). |
| Scope | The named slice of work an agent is touching (e.g., `phase-0`, `heir`, `p2p-signaling`). |
| Staged | A terminal task state: gates passed, changes added with `git add -A`, awaiting `make git`. |
| Tracking row | One line in `docs/tracking/tracking.csv` recording an agent action. Schema: `ts_utc, run_id, agent, scope, action, status, summary, refs, commit_sha`. |
