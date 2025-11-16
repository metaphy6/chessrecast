# ChessRecast Backend

A high-performance, scalable Go backend for ChessRecast - supporting multiple chess variants, AI opponents, and real-time multiplayer.

## 🏗️ Architecture

```
backend/
├── cmd/
│   ├── api/          # HTTP/WebSocket API server
│   ├── worker/       # Background jobs (AI games, analysis)
│   └── migrate/      # Database migrations
├── internal/
│   ├── engine/       # Chess engine (move generation, validation)
│   ├── ai/           # AI bot implementation
│   ├── game/         # Game session management
│   ├── player/       # Player/user management
│   ├── matchmaking/  # Queue & matching logic
│   ├── analysis/     # Game analysis & statistics
│   └── common/       # Shared utilities
├── pkg/
│   └── api/          # Public API contracts (protobuf/OpenAPI)
├── config/           # Configuration files
├── deployments/      # Docker, k8s manifests
└── tests/            # Integration tests
```

## 🚀 Features

### Phase 1 (Current)
- ✅ Chess engine supporting all 12 game modes
- ✅ AI bots with difficulty 1-10
- ✅ Bot vs Bot gameplay for testing
- ✅ Human vs Bot gameplay
- ✅ Real-time multiplayer (WebSocket)
- ✅ RESTful API

### Phase 2 (Future)
- 🔄 P2P game hosting with economic incentives
- 🔄 Witness-based move validation
- 🔄 Coin economy system
- 🔄 Advanced matchmaking (ELO, preferences)
- 🔄 Game analysis & recommendations
- 🔄 Tournament system
- 🔄 Blockchain integration for rewards

## 🛠️ Tech Stack

- **Language**: Go 1.21+
- **HTTP Framework**: Gin (fast, middleware-rich)
- **WebSocket**: gorilla/websocket
- **Database**: PostgreSQL 15+ (persistent data)
- **Cache**: Redis 7+ (sessions, game state)
- **Message Queue**: Redis Streams (future: Kafka)
- **Monitoring**: Prometheus + Grafana
- **Logging**: Zap (structured logging)
- **Auth**: JWT tokens

## 🎮 Supported Game Modes

1. **Classic Chess** - Traditional FIDE rules
2. **Royal Pawns** - Pawns move like kings
3. **Other Side** - Rook racing game
4. **Heir** - Kings can be captured
5. **Truce** - Peaceful opening phase
6. **Snare** - Knight entanglement zones
7. **Diamonds** - Bishop diamond captures
8. **Teleport** - King-rook teleportation
9. **Friendly Fire** - Capture own pieces
10. **Kings' Battle** - Locked pieces until king captures
11. **Save the Queen** - Rescue imprisoned queens
12. **Save the King** - Promote pawns to kings

## 🎯 AI Difficulty Levels

- **1-3**: Beginner - Random moves with basic heuristics
- **4-6**: Intermediate - Minimax 2-4 ply, positional evaluation
- **7-8**: Advanced - Minimax 5-6 ply, opening book, tactics
- **9-10**: Expert - Minimax 7-8 ply, endgame tables, deep strategy

## 📡 API Design

### REST Endpoints
```
POST   /api/v1/auth/guest          # Guest login
POST   /api/v1/auth/register        # Register user
POST   /api/v1/auth/login           # Login

GET    /api/v1/games                # List active games
POST   /api/v1/games                # Create new game
GET    /api/v1/games/:id            # Get game state
POST   /api/v1/games/:id/moves      # Make a move
DELETE /api/v1/games/:id            # Resign/abandon

POST   /api/v1/matchmaking/queue    # Join matchmaking
DELETE /api/v1/matchmaking/queue    # Leave queue

GET    /api/v1/bots                 # List available bots
POST   /api/v1/bots/challenge       # Challenge a bot

POST   /api/v1/analysis/games/:id   # Analyze completed game
GET    /api/v1/stats/player/:id     # Player statistics
```

### WebSocket
```
WS /api/v1/ws/game/:id

Messages:
-> move: { from, to, promotion }
<- game_update: { state, lastMove, player }
<- game_over: { winner, reason }
<- error: { message }
```

## 🏃 Quick Start

### Prerequisites
- Go 1.21+
- Docker & Docker Compose
- PostgreSQL 15+ (or use Docker)
- Redis 7+ (or use Docker)

### Development Setup

```bash
# Clone repository
cd backend

# Install dependencies
go mod download

# Setup config
cp config/config.example.yaml config/config.yaml

# Run with Docker Compose (recommended)
docker-compose up -d

# Or run locally
go run cmd/api/main.go

# Run tests
go test ./...
```

### Environment Variables
```bash
DATABASE_URL=postgres://user:pass@localhost:5432/chessrecast
REDIS_URL=redis://localhost:6379
JWT_SECRET=your-secret-key
PORT=8080
LOG_LEVEL=info
```

## 📊 Performance Targets

- **Latency**: < 50ms p99 for move validation
- **Throughput**: 10,000+ concurrent games
- **AI Response**: < 2s for difficulty 7-8
- **Memory**: < 100MB per 1000 games
- **Scalability**: Horizontal scaling via load balancer

## 🔐 Security

- JWT-based authentication
- Rate limiting per IP/user
- Input validation & sanitization
- CORS configuration
- Encrypted connections (TLS)
- Move validation server-side
- Anti-cheat measures (future)

## 📝 Code Standards

- **Clean Architecture**: Domain-driven design
- **Error Handling**: Explicit error returns, no panics
- **Testing**: Unit tests (80%+ coverage), integration tests
- **Documentation**: GoDoc comments, API specs
- **Formatting**: `gofmt`, `golangci-lint`

## 🤝 Contributing

1. Follow Go best practices
2. Write tests for new features
3. Update documentation
4. Use conventional commits
5. Keep functions small and focused

## 📄 License

Proprietary - ChessRecast Project
