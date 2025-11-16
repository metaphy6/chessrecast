# ChessRecast Backend - Getting Started Guide

## Initial Setup (First Time)

### 1. Install Prerequisites

**Required:**
- Go 1.21 or higher: https://golang.org/dl/
- Docker & Docker Compose: https://www.docker.com/products/docker-desktop/
- Git

**Optional (for local development without Docker):**
- PostgreSQL 15+
- Redis 7+

### 2. Clone and Setup

```powershell
# Navigate to backend directory
cd c:\code\Flutter\chessrecast\backend

# Initialize Go modules and download dependencies
go mod tidy

# This will download all required packages:
# - Gin (web framework)
# - Gorilla WebSocket  
# - Zap (logging)
# - Viper (configuration)
# - PostgreSQL driver
# - Redis client
# - UUID generator
# - JWT library
```

### 3. Configuration

```powershell
# Config file is already created at config/config.yaml
# Review and adjust settings if needed:
# - Database credentials
# - Redis connection
# - JWT secret (IMPORTANT: Change in production!)
# - AI settings
# - Rate limiting
```

## Running the Backend

### Option A: Docker Compose (Recommended)

```powershell
# Start all services (API, PostgreSQL, Redis)
docker-compose up -d

# View logs
docker-compose logs -f api

# Stop services
docker-compose down

# Rebuild after code changes
docker-compose up -d --build
```

The API will be available at: http://localhost:8080

### Option B: Local Development

```powershell
# 1. Start PostgreSQL and Redis (via Docker)
docker-compose up -d postgres redis

# 2. Run the API server locally
go run cmd/api/main.go

# Or build and run:
go build -o chessrecast-api.exe cmd/api/main.go
.\chessrecast-api.exe
```

## Testing the API

### Health Check

```powershell
# PowerShell
Invoke-WebRequest -Uri http://localhost:8080/health

# Or use curl (if installed)
curl http://localhost:8080/health
```

Expected response:
```json
{
  "status": "ok",
  "version": "1.0.0",
  "time": 1699200000
}
```

### Create a Game (Human vs Bot)

```powershell
$body = @{
    mode = "classic"
    bot_difficulty = 5
} | ConvertTo-Json

Invoke-WebRequest -Uri http://localhost:8080/api/v1/games `
    -Method POST `
    -ContentType "application/json" `
    -Body $body
```

Response:
```json
{
  "game_id": "uuid-here",
  "mode": "classic",
  "players": {
    "white": "guest_xyz",
    "black": "bot_abc"
  }
}
```

### Make a Move

```powershell
$gameId = "uuid-from-previous-response"
$body = @{
    from = "e2"
    to = "e4"
} | ConvertTo-Json

Invoke-WebRequest -Uri "http://localhost:8080/api/v1/games/$gameId/moves" `
    -Method POST `
    -ContentType "application/json" `
    -Body $body
```

### List Available Bots

```powershell
Invoke-WebRequest -Uri http://localhost:8080/api/v1/bots
```

Response shows bots from difficulty 1-10 with their ratings.

## Bot vs Bot Testing

To test game modes and watch bots play against each other:

```powershell
# Create bot vs bot game (modify handlers.go to support this)
$body = @{
    mode = "royal_pawns"
    white_bot = 7
    black_bot = 6
} | ConvertTo-Json

Invoke-WebRequest -Uri http://localhost:8080/api/v1/games `
    -Method POST `
    -ContentType "application/json" `
    -Body $body
```

## WebSocket Connection

For real-time game updates:

```javascript
// In browser console or Node.js
const ws = new WebSocket('ws://localhost:8080/api/v1/ws/game/GAME_ID?player_id=YOUR_ID');

ws.onmessage = (event) => {
  const update = JSON.parse(event.data);
  console.log('Game update:', update);
};
```

## Available Game Modes

Test each mode by changing the `mode` parameter:

- `classic` - Traditional chess
- `royal_pawns` - Pawns move like kings
- `other_side` - Rook racing game
- `heir` - Kings can be captured
- `truce` - Peaceful opening phase
- `snare` - Knight entanglement zones
- `diamonds` - Bishop diamond captures
- `teleport` - King-rook teleportation
- `friendly_fire` - Capture own pieces
- `kings_battle` - Locked pieces until king captures
- `save_the_queen` - Rescue imprisoned queens
- `save_the_king` - Promote pawns to kings

## AI Difficulty Levels

Test different bot strengths:

- **1-3**: Beginner (random moves, basic heuristics)
- **4-6**: Intermediate (minimax 3-4 ply)
- **7-8**: Advanced (minimax 5-6 ply, tactics)
- **9-10**: Expert (minimax 7-8 ply, deep strategy)

## Development Workflow

### Making Changes

```powershell
# 1. Edit code in internal/ or cmd/
# 2. Run tests
go test ./...

# 3. Format code
go fmt ./...

# 4. Check for issues
go vet ./...

# 5. Restart server
# If using Docker:
docker-compose restart api

# If running locally:
# Press Ctrl+C and run again:
go run cmd/api/main.go
```

### Adding New Features

1. **New Game Mode**: Edit `internal/engine/` files
2. **AI Improvements**: Edit `internal/ai/bot.go`
3. **New API Endpoint**: Edit `internal/api/handlers.go`
4. **Database Models**: Add to `internal/models/` (to be created)

### Debugging

```powershell
# Enable debug logging
# In config/config.yaml, change:
logging:
  level: debug

# View detailed logs
docker-compose logs -f api

# Or if running locally, logs appear in console
```

### Performance Profiling

```powershell
# CPU profiling
go test -cpuprofile=cpu.prof -bench=. ./internal/ai

# Memory profiling  
go test -memprofile=mem.prof -bench=. ./internal/engine

# Analyze profile
go tool pprof cpu.prof
```

## Troubleshooting

### Port Already in Use

```powershell
# Check what's using port 8080
netstat -ano | findstr :8080

# Kill the process or change port in config.yaml
```

### Database Connection Failed

```powershell
# Check if PostgreSQL is running
docker ps

# View PostgreSQL logs
docker logs chessrecast-db

# Connect to database manually
docker exec -it chessrecast-db psql -U chessrecast
```

### Module Import Errors

```powershell
# Refresh dependencies
go mod tidy
go mod download

# Clean module cache if needed
go clean -modcache
go mod download
```

## Next Steps

1. ✅ Backend is running
2. **Connect Flutter App**: Modify Flutter app to call these APIs
3. **Add Authentication**: Implement JWT tokens
4. **Add Database Persistence**: Store games, users, stats
5. **Implement Matchmaking**: Queue system for PvP
6. **Add Analysis Features**: Post-game analysis
7. **P2P Features**: Implement distributed hosting (Phase 2)

## API Documentation

Full API documentation will be available at:
- OpenAPI/Swagger: http://localhost:8080/swagger (to be added)
- Postman Collection: `docs/postman/` (to be created)

## Monitoring

Prometheus metrics available at:
- http://localhost:9090/metrics

Health endpoint:
- http://localhost:8080/health

## Production Deployment

Before deploying to production:

1. Change JWT secret in config
2. Enable TLS/HTTPS
3. Configure proper CORS origins
4. Set up database backups
5. Enable rate limiting
6. Add monitoring/alerting
7. Use environment variables for secrets
8. Set up CI/CD pipeline

## Support

For issues or questions:
- Check logs: `docker-compose logs api`
- Review config: `config/config.yaml`
- Read code comments in `internal/`
