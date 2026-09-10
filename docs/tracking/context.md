# 🧠 docs/tracking/context.md — shared project context pack

> **This file is the single place for project-specific overrides.**
> All vendor entry points (`CLAUDE.md`, `CONVENTIONS.md`,
> `.github/copilot-instructions.md`) reference this file.

---

## Project identity

- **Name**: chessrecast
- **One-liner**: Offline-first chess app with novel rule variants and WebRTC peer-to-peer multiplayer
- **Primary languages**: Dart (Flutter), C (chess engine), Go (signaling server)
- **Stack**: Flutter app + native C chess engine (FFI) + Go WebSocket/WebRTC signaling server
- **Repo**: `github.com/metaphy6/chessrecast` (private)

## Key paths

| Concern | Path |
|---|---|
| Master rulebook | `AGENTS.md` |
| Project plan | `docs/planning/ROADMAP.md` |
| Architecture | `docs/code/ARCHITECTURE.md` |
| Charter | `docs/project/CHARTER.md` |
| Glossary | `docs/project/GLOSSARY.md` |
| Decision log | `docs/project/DECISION_LOG.md` |
| Engine rules | `docs/project/ENGINE_RULES.md` |
| P2P docs | `docs/p2p/` (25 documents) |
| P2P roadmap | `docs/p2p/P2P_ROADMAP.md` |
| Tracking log | `docs/tracking/tracking.csv` |
| Skills library | `.agents/skills/` |
| Ops scripts | `xops/` |
| Bot improvement loop | `bots/` (queue, baselines, openings, reports) |
| Flutter app | `frontend/` |
| C chess engine | `frontend/native/` |
| Go signaling server | `signaling/` |

## Active context

All seven chess mods (`heir`, `friendly_fire`, `kings_battle`, `mercenary`, `save_the_queen`, `succession`, `truce`) and P2P multiplayer (Phases 1–6) are complete. Ongoing work is chess engine quality improvement via the bot loop (`bots/queue.yaml`).

## Project-specific conventions

- **Mod isolation**: each mod's logic lives entirely in `frontend/native/engine/eval/eval_<mod>.c`. Shared engine files (`move_generator.c`, `board.c`, `types.c`) must never contain mod-specific code.
- **Engine via FFI only**: never call chess logic from Dart directly — always go through the FFI bridge in `frontend/lib/`.
- **Baselines are immutable**: never edit `bots/baselines/<mod>.json` by hand. Only the bot loop writes baselines after a successful audit run.
- **Opening slices are stable**: the fixed gate slice (`bots/openings/<mod>.csv`, 50 lines) changes only via a `kind: corpus_curation` queue entry + immediate baseline refresh.
- **P2P is server-free for game moves**: the Go signaling server relays SDP/ICE only; no game state ever passes through it.
- **Tracking rows use Conventional Commits**: `summary` column must match `type(scope): description` — enforced by `tracking_append.sh` (exit 65 on violation).
- **Tests move with code**: every behavior change ships its test in the same staged set. Silencing or weakening a test to make a gate pass is forbidden.

## Out-of-scope / do not touch

- `frontend/native/engine/move_generator.c`, `board.c`, `types.c` — shared engine core. Changes here affect all mods and require a full re-audit of every mod.
- `signaling/` — production signaling server. Changes here need ops review (see `docs/p2p/P2P_OPERATIONS.md`).
- `bots/baselines/` — never hand-edit. Managed by the bot loop only.
- `docs/tracking/state/` — runtime agent state. Never commit `log.jsonl`, `current.json`, `checkpoint.json`, or `usage.json`.

## External service dependencies

| Service | Env var | Notes |
|---|---|---|
| STUN server | `STUN_URL` | Defaults to `stun:stun.l.google.com:19302` in dev |
| Signaling server | `SIGNALING_URL` | WebSocket URL; self-hosted Go server |
| TURN server (optional) | `TURN_URL`, `TURN_USERNAME`, `TURN_CREDENTIAL` | Only needed for symmetric NAT |

## Agent quick-reference

```bash
make help                          # all targets
make doctor                        # sanity-check framework install
make git.dry                       # preview pending commits (read-only)
make git                           # commit + push (human runs this)
make track.add SUMMARY="feat(heir): improve castle heuristic"
make skills.find TAG=chess         # search skill library
make roadmap.status                # roadmap checkbox progress

# Run bot improvement loop (VS Code Copilot Chat, Agent mode):
# /improve-mod   → pick a mod, agent audits + fixes + commits

# Bootstrap a session:
xops/agent/session-bootstrap.sh
```

## Chess mod quick-reference

| Mod | C eval file | What's special |
|---|---|---|
| `heir` | `eval_heir.c` | Two kings per side; second king cannot die |
| `friendly_fire` | `eval_friendly_fire.c` | Pieces can capture their own side |
| `kings_battle` | `eval_kings_battle.c` | Kings can move into check; survive by escaping |
| `mercenary` | `eval_mercenary.c` | Pieces switch sides when certain conditions are met |
| `save_the_queen` | `eval_save_the_queen.c` | Queen is a liability; losing her wins the game |
| `succession` | `eval_succession.c` | When the king dies, a piece is promoted to king |
| `truce` | `eval_truce.c` | Repetitions are enforced as draws; avoid them |
