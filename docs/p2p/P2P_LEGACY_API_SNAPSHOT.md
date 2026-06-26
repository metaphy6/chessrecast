# P2P Legacy API Snapshot

> **Purpose:** This document captures the complete HTTP REST and WebSocket contract
> of the legacy ChessRecast Go backend so that Phase 0.4 of the P2P Roadmap can
> prove "no live caller is left."  It is a read-only reference — do not add new
> endpoints to this file unless they were already present in the frozen codebase
> (tag `backend-legacy-final`).

See [P2P_ROADMAP.md](P2P_ROADMAP.md) §0.1 for context.

---

## Base URLs

| Transport | URL |
|---|---|
| REST (desktop / web / iOS) | `http://localhost:8080/api/v1` |
| REST (Android emulator) | `http://10.0.2.2:8080/api/v1` |
| WebSocket (desktop / web / iOS) | `ws://localhost:8080/api/v1/ws` |
| WebSocket (Android emulator) | `ws://10.0.2.2:8080/api/v1/ws` |

---

## REST Endpoints

### Authentication

#### `POST /auth/guest`

Obtain an ephemeral guest JWT token.

**Request body:** none

**Response 200:**
```json
{
  "token": "<jwt>",
  "user_id": "<uuid>"
}
```

---

### Games

#### `POST /games`

Create a new game.

**Request headers:** `Authorization: Bearer <token>` (optional)

**Request body:**
```json
{
  "mode": "classic | mercenary | heir | ...",
  "bot_difficulty": 1,
  "opponent_id": "<uuid>"
}
```
`bot_difficulty` (1–10) and `opponent_id` are mutually exclusive; omit both for a local AI game.

**Response 201:**
```json
{
  "game_id": "<uuid>",
  "player_id": "<uuid>"
}
```

---

#### `GET /games`

List all active games visible to the caller.

**Request headers:** `Authorization: Bearer <token>` (optional)

**Response 200:**
```json
{
  "games": [
    { "game_id": "<uuid>", "mode": "...", "status": "active | finished", "..." : "..." }
  ]
}
```

---

#### `GET /games/{id}`

Retrieve current game state.

**Path param:** `id` — game UUID

**Request headers:** `Authorization: Bearer <token>` (optional)

**Response 200:**
```json
{
  "game_id": "<uuid>",
  "fen": "<FEN string>",
  "move_log": ["e2e4", "e7e5"],
  "status": "active | finished",
  "result": "white | black | draw | null"
}
```

---

#### `POST /games/{id}/moves`

Submit a move.

**Path param:** `id` — game UUID

**Request headers:** `Authorization: Bearer <token>` (optional)

**Request body:**
```json
{
  "from": "e2",
  "to": "e4",
  "promotion": "queen",
  "player_id": "<uuid>"
}
```
`promotion` and `player_id` are optional.

**Response 200:** updated game state (same shape as `GET /games/{id}`).

---

#### `POST /games/{id}/resign`

Resign from a game.

**Path param:** `id` — game UUID

**Request headers:** `Authorization: Bearer <token>` (optional)

**Response 200:** empty body on success.

---

#### `DELETE /games/{id}`

Abandon a game (soft-delete; equivalent to forfeit).

**Path param:** `id` — game UUID

**Request headers:** `Authorization: Bearer <token>` (optional)

**Response 200:** empty body on success.

---

### Bots

#### `GET /bots`

List available AI bot profiles.

**Response 200:**
```json
{
  "bots": [
    { "id": "<uuid>", "name": "...", "difficulty": 1 }
  ]
}
```

---

## WebSocket Endpoint

### `ws://…/api/v1/ws/game/{id}?player_id={player_id}`

Persistent connection for real-time game-state push.

**Path param:** `{id}` — game UUID  
**Query param:** `player_id` — the connecting player's UUID (obtained from `POST /games` or `POST /auth/guest`)

**Incoming messages (server → client):**
```json
{
  "type": "game_update",
  "game": { "...": "same shape as GET /games/{id}" }
}
```

**Outgoing messages (client → server):**  
Not formally specified in the legacy client; all mutations go through REST.

**Reconnect policy (legacy client):**  
Up to 10 attempts with exponential back-off.  The `GameWebSocket` class (`frontend/lib/services/game_websocket.dart`) manages this.

---

## Dart call-site summary

The table below maps every legacy API call site to the endpoint it uses. It is the
companion to [`LEGACY_BACKEND_USAGES.md`](LEGACY_BACKEND_USAGES.md).

| Call site | Endpoint(s) |
|---|---|
| `frontend/lib/management/online_controller.dart` | `POST /auth/guest`, `POST /games`, `POST /games/{id}/moves`, `POST /games/{id}/resign`, `GET /games/{id}`, WebSocket |
| `frontend/lib/ui/online_bot_vs_bot_page.dart` | `GET /bots`, `POST /games` |
| `frontend/lib/analytics/custom/custom_board_setup.dart` | `POST /games` (or board setup variant) |

---

## P2P replacement mapping

| Legacy endpoint | P2P replacement (Phase) |
|---|---|
| `POST /auth/guest` | Phase 3 signaling: peer identity via local UUID + HELLO handshake |
| `POST /games` | Phase 3: game session initiated via signaling server or direct offer |
| `GET /games/{id}` | Phase 1: full game state transmitted over DataChannel on connect |
| `POST /games/{id}/moves` | Phase 1: `MOVE` message over DataChannel |
| `POST /games/{id}/resign` | Phase 1: `RESIGN` message over DataChannel |
| `DELETE /games/{id}` | Phase 1: peer disconnect / `ABANDON` message |
| `GET /bots` | Not applicable — bots are local engine calls (no server needed) |
| WebSocket push | Phase 1: DataChannel replaces WebSocket entirely |
