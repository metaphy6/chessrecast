# 🗳 Decision log — chessrecast

Append-only log of meta-decisions. Code-level architectural decisions go in [`../design/`](../design/) as ADRs.

## Rules

- **Append-only.** Reversing a decision = a new row referencing the prior one.
- **One line per decision.** Anything longer becomes an ADR in `docs/design/`.
- **Owner is a real person**, not a team.

| # | Date | Decision | Context | Consequence |
|---|---|---|---|---|
| 0001 | 2024-01 | Native C chess engine via Flutter FFI | Dart is too slow for deep search; WASM too limited for multi-platform. | Engine code is platform-native C; Flutter loads it as a shared library. All engine work is in `frontend/native/`. |
| 0002 | 2024-01 | Single-binary signaling server in Go | Minimal operational footprint; Go concurrency handles many WebSocket rooms cheaply. | Signaling is stateless, in-memory only. No DB. Room state lost on restart. |
| 0003 | 2024-03 | WebRTC P2P — no central game relay | Privacy requirement: the server must never see game moves. | All game traffic flows over the WebRTC data channel. Signaling server relays SDP/ICE only. |
| 0004 | 2024-06 | Seven chess mod variants | Differentiation from standard chess apps; drives the autonomous improvement loop. | Each mod has isolated eval C file, baseline, opening slices. New mods follow the same pattern. |
| 0005 | 2025-01 | Agent-driven mod quality loop (`bots/`) | Manual audit of 50+ games per mod per change is too slow. | The `chess-mod-improver` agent runs audit batches autonomously; humans review queue entries and cherry-pick fixes. |
| 0006 | 2025-04 | Adopt ai-vscode-basics scaffold | Standardize agent operating rules, tracking, and skills across all AI assistants. | AGENTS.md is the master rulebook; vendor entry points (CLAUDE.md, GEMINI.md, etc.) delegate to it. Tracking via 9-column CSV. |
| 0007 | 2025-06 | Rename `agent/` → `bots/` | The original `agent/` name was ambiguous (scaffold also has `xops/agent/`). `bots/` clearly names the chess bot improvement loop. | All references updated. State files migrated to `docs/tracking/state/`. |
| 0008 | 2025-06 | P2P docs gathered under `docs/p2p/` | 25 P2P-specific documents were cluttering the `docs/` root. | All `P2P_*.md` files live in `docs/p2p/`. Cross-references updated. |
