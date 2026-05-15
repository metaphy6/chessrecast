# Backend — Legacy Go Service (FROZEN)

> **⚠️ This directory is FROZEN.** The last active commit has been tagged
> `backend-legacy-final`.  No new feature work is permitted here.
>
> **Reason:** ChessRecast is migrating to a pure peer-to-peer architecture.
> See [docs/P2P_ROADMAP.md](../docs/P2P_ROADMAP.md) for the migration plan.

## Freeze status

| Property | Value |
|---|---|
| Freeze tag | `backend-legacy-final` |
| Frozen on | 2026-05-15 |
| Reason | P2P migration — see P2P Roadmap Phase 0 §0.1 |
| Phase archiving | Backend source will be moved to `archive/backend-go-legacy/` in Phase 0.3 |

## What this code does (historical)

This was the Go backend service providing:
- REST API at `/api/v1/` for game creation, move submission, and game retrieval.
- WebSocket endpoint at `/api/v1/ws/game/<id>` for real-time game updates.
- Guest authentication (ephemeral JWT tokens).
- In-memory game state with optional persistence.

## Migration path

| Legacy path | P2P replacement |
|---|---|
| HTTP `POST /api/v1/games` | Phase 3 signaling server / direct P2P via `HELLO` |
| WebSocket `/api/v1/ws/game/<id>` | Phase 1 wire protocol over WebRTC DataChannel |
| Saved-game persistence | Phase 0.2 local SQLite (`SavedGamesLocal`) |

## Building / running (DO NOT USE in production)

This service is provided for reference only. It will be archived in Phase 0.3.

```bash
cd backend
go run ./cmd/api
```

See `config/config.example.yaml` for configuration options.
