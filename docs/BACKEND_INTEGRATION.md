# ChessRecast Backend Integration Guide

## Overview

ChessRecast now includes a complete **Go backend** with:
- ♟️ **Chess Engine**: All 12 game modes with full move validation
- 🤖 **AI Bots**: 10 difficulty levels (1=Beginner → 10=Master) using minimax with alpha-beta pruning
- 🌐 **Multiplayer**: Real-time WebSocket support for online play
- 🐳 **Docker**: Complete containerized setup with PostgreSQL and Redis

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Flutter Frontend                         │
│  ┌────────────┐  ┌─────────────┐  ┌──────────────────┐     │
│  │ UI Layer   │→ │   Services  │→ │ OnlineController │     │
│  │  - Home    │  │ - ApiService│  │  - Game State    │     │
│  │  - BotSel  │  │ - WebSocket │  │  - Move Sync     │     │
│  └────────────┘  └─────────────┘  └──────────────────┘     │
└────────────┬────────────────────────────────┬───────────────┘
             │ HTTP/REST                       │ WebSocket
             ▼                                 ▼
┌─────────────────────────────────────────────────────────────┐
│                      Go Backend API                          │
│  ┌─────────────┐  ┌──────────────┐  ┌──────────────────┐   │
│  │ API Handlers│→ │ Game Service │→ │  Chess Engine    │   │
│  │  - Auth     │  │  - Sessions  │  │  - Move Gen      │   │
│  │  - Games    │  │  - Broadcasting│ │  - 12 Modes     │   │
│  │  - Moves    │  └──────────────┘  └──────────────────┘   │
│  │  - Bots     │         ↓                                  │
│  └─────────────┘  ┌──────────────┐                         │
│                   │   AI Bot      │                         │
│                   │  - Minimax    │                         │
│                   │  - 10 Levels  │                         │
│                   └──────────────┘                         │
└─────────────────────────────────────────────────────────────┘
             │                                 │
             ▼                                 ▼
      ┌─────────────┐                  ┌─────────────┐
      │ PostgreSQL  │                  │   Redis     │
      │  (Games DB) │                  │  (Sessions) │
      └─────────────┘                  └─────────────┘
```

## Quick Start

### 1. Start the Backend

Using Docker (Recommended):
```bash
cd backend
docker-compose up -d
```

This starts:
- 🐳 **API Server**: `localhost:8080`
- 🗄️ **PostgreSQL**: `localhost:5432`
- 📦 **Redis**: `localhost:6379`

Without Docker:
```bash
cd backend
go build -o chessrecast-api.exe cmd/api/main.go
./chessrecast-api.exe
```

### 2. Run the Flutter App

```bash
flutter run
```

### 3. Play Online

1. Launch the app
2. Tap **🌐 Play Online vs Bot**
3. Select:
   - **Difficulty**: 1-10 slider
   - **Game Mode**: Any of the 12 modes
4. Tap **Start Game**
5. Play against the backend AI!

## How It Works

### User Flow

```
Home Page
    ↓ Tap "Play Online vs Bot"
Bot Selection
    ↓ Choose difficulty & mode
API Service
    ↓ loginAsGuest() → Get auth token
    ↓ createGame() → Create game with bot
WebSocket
    ↓ connect() → Real-time updates
Game Board
    ↓ User makes move
OnlineController
    ↓ makeMoveOnline()
API Service
    ↓ makeMove() → Send to backend
Backend Engine
    ↓ Validate & apply move
    ↓ Bot calculates response
    ↓ Broadcast update via WebSocket
WebSocket
    ↓ onGameUpdate()
Game Board Updates
```

### Key Components

#### 1. **ApiService** (`lib/services/api_service.dart`)
- REST API client for backend communication
- Endpoints:
  - `POST /auth/guest` - Guest login
  - `POST /games` - Create game
  - `GET /games/:id` - Get game state
  - `POST /games/:id/moves` - Make move
  - `GET /bots` - List available bots (1-10)
  - `POST /bots/:id/challenge` - Challenge specific bot

#### 2. **GameWebSocket** (`lib/services/game_websocket.dart`)
- WebSocket client for real-time updates
- Event types:
  - `game_state` - Full board state
  - `move_made` - Opponent moved
  - `game_over` - Game ended
  - `player_joined/left` - Multiplayer events

#### 3. **OnlineController** (`lib/management/online_controller.dart`)
- Extends base `Controller`
- Manages online game state
- Synchronizes moves with backend
- Handles WebSocket events
- Converts between Flutter board representation and backend FEN

## Backend Features

### AI Difficulty Levels

| Level | Description | Search Depth | Strategy |
|-------|-------------|--------------|----------|
| 1-2   | Beginner    | 1-2 ply      | Random moves, basic captures |
| 3-4   | Easy        | 2-3 ply      | Material advantage |
| 5-6   | Intermediate| 3-4 ply      | Positional play |
| 7-8   | Advanced    | 4-5 ply      | Strategic planning |
| 9-10  | Master      | 5-6 ply      | Deep analysis, alpha-beta pruning |

### Game Modes Supported

All 12 modes work online:
1. ♟️ **Classic** - Standard chess
2. 👑 **Royal Pawns** - Pawns move like kings
3. 🏰 **Other Side** - Race rooks to back rank
4. 👨‍👦 **Heir** - Capturable kings, pawn→king promotion
5. 🤝 **Truce** - No attacks until all pieces moved
6. 🕷️ **Snare** - Knight entangle zones
7. 💎 **Diamonds** - Bishop diamond captures
8. 🔄 **Teleport** - King-rook swap
9. 🎯 **Friendly Fire** - Capture own pieces
10. ⚔️ **Kings' Battle** - Only kings & pawns initially
11. 👸 **Save the Queen** - Rescue imprisoned queens
12. 🤴 **Save the King** - Promote pawn to king

## API Endpoints

### Authentication
```http
POST /api/v1/auth/guest
Response: { "token": "...", "user_id": "...", "username": "Guest_..." }
```

### Games
```http
# Create game
POST /api/v1/games
Body: { "mode": "classic", "bot_difficulty": 5 }
Response: Game ID

# Get game state
GET /api/v1/games/:id
Response: { "id": "...", "fen": "...", "status": "...", ... }

# Make move
POST /api/v1/games/:id/moves
Body: { "from": "e2", "to": "e4", "promotion": null }
Response: Updated game state
```

### Bots
```http
# List bots
GET /api/v1/bots
Response: [{ "id": 1, "name": "Bot Level 1", "difficulty": 1 }, ...]

# Challenge bot
POST /api/v1/bots/:id/challenge
Body: { "mode": "classic" }
Response: Game ID
```

## Configuration

### Backend URL

**Default**: `http://localhost:8080/api/v1`

To change:
1. Edit `lib/services/api_service.dart`:
```dart
class ApiService {
  static const String baseUrl = 'http://YOUR_SERVER:8080/api/v1';
  // ...
}
```

2. Edit `lib/services/game_websocket.dart`:
```dart
class GameWebSocket {
  static const String wsBaseUrl = 'ws://YOUR_SERVER:8080/api/v1/ws';
  // ...
}
```

### Android Emulator

Use `10.0.2.2` instead of `localhost`:
- REST: `http://10.0.2.2:8080/api/v1`
- WebSocket: `ws://10.0.2.2:8080/api/v1/ws`

## Testing

### 1. Test Backend Health
```bash
curl http://localhost:8080/health
# Expected: {"status":"ok","timestamp":"..."}
```

### 2. Test Guest Login
```bash
curl -X POST http://localhost:8080/api/v1/auth/guest
# Expected: {"token":"...","user_id":"...","username":"Guest_..."}
```

### 3. Test Bot List
```bash
curl http://localhost:8080/api/v1/bots
# Expected: [{"id":1,"name":"Bot Level 1","difficulty":1},...]
```

### 4. Play in Flutter
1. Run backend: `docker-compose up -d`
2. Run Flutter: `flutter run`
3. Tap "Play Online vs Bot"
4. Select difficulty 5, Classic mode
5. Make moves and verify bot responds
6. Check logs:
   - Flutter: Look for `📤 Sending move` and `✅ Move accepted`
   - Backend: `docker-compose logs -f api`

## Troubleshooting

### Connection Failed
**Issue**: `Backend server is not reachable`

**Solutions**:
1. Check backend is running: `docker ps`
2. Test health endpoint: `curl http://localhost:8080/health`
3. Check firewall settings
4. For Android emulator, use `10.0.2.2` instead of `localhost`

### WebSocket Connection Issues
**Issue**: `WebSocket: Connection error`

**Solutions**:
1. Verify game ID is valid
2. Check WebSocket URL in `game_websocket.dart`
3. Ensure backend WebSocket endpoint is working:
   ```bash
   docker-compose logs -f api | grep WebSocket
   ```

### Move Rejected
**Issue**: `Move failed: Invalid move`

**Solutions**:
1. Verify move is legal for the game mode
2. Check it's your turn
3. Ensure positions are in algebraic notation (e.g., `e2`, `e4`)
4. Check backend logs for validation errors

## Development

### Running Backend Locally (No Docker)

1. Install dependencies:
```bash
cd backend
go mod download
```

2. Start PostgreSQL and Redis (or use Docker for these)

3. Configure environment:
```bash
export DATABASE_URL="postgres://user:pass@localhost:5432/chessrecast"
export REDIS_URL="redis://localhost:6379"
```

4. Run:
```bash
go run cmd/api/main.go
```

### Backend Logs

View real-time logs:
```bash
docker-compose logs -f api
```

### Database Access

Connect to PostgreSQL:
```bash
docker exec -it backend-postgres-1 psql -U chessuser -d chessrecast
```

## Future Enhancements

- [ ] Human vs Human multiplayer
- [ ] Matchmaking system
- [ ] Game history and replay
- [ ] User accounts (not just guest)
- [ ] Leaderboards
- [ ] Tournament mode
- [ ] Chat system
- [ ] Move hints from backend
- [ ] Opening book integration
- [ ] Endgame tablebase

## File Structure

```
lib/
├── services/
│   ├── api_service.dart       # REST API client
│   └── game_websocket.dart    # WebSocket client
├── management/
│   ├── controller.dart         # Base controller (offline)
│   └── online_controller.dart  # Online controller (extends base)
├── ui/
│   ├── start.dart             # Home page with online button
│   └── bot_selection_page.dart # Bot difficulty & mode selector
└── routes.dart                # App routing

backend/
├── cmd/api/main.go            # Server entry point
├── internal/
│   ├── engine/                # Chess engine (12 game modes)
│   ├── ai/                    # AI bot implementation
│   ├── game/                  # Game session management
│   └── api/                   # HTTP/WebSocket handlers
├── config/config.yaml         # Configuration
├── docker-compose.yml         # Docker services
└── Dockerfile                 # API container
```

## Support

For issues or questions:
1. Check backend logs: `docker-compose logs -f api`
2. Enable Flutter debug logging: `printDebug` calls
3. Review `backend/IMPLEMENTATION_SUMMARY.md` for backend details
4. Check `backend/FLUTTER_INTEGRATION.md` for integration notes

---

**Status**: ✅ Fully Integrated & Ready to Play!

The backend is production-ready with all 12 game modes, 10 difficulty levels, and real-time multiplayer support. Play, test, and enjoy! 🎉
