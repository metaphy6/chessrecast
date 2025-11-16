# ChessRecast

**Novel chess with the same board, same pieces, but with 12 new game modes!**

## 🎮 Features

- ♟️ **12 Unique Game Modes** - Classic, Royal Pawns, Other Side, Heir, Truce, Snare, Diamonds, Teleport, Friendly Fire, Kings' Battle, Save the Queen, Save the King
- 🤖 **AI Bots** - 10 difficulty levels (Beginner to Master)
- 🌐 **Online Play** - Real-time multiplayer with backend integration
- 📊 **Bot vs Bot** - Watch AI battles and analyze strategies
- 🎨 **Beautiful UI** - Material Design with multiple board themes
- ⚡ **Performance Optimized** - Smooth 60fps gameplay

## 🚀 Quick Start

### Run Locally (Offline Mode)

```bash
flutter run
```

### Play Online (With Backend)

1. **Start Backend**:
```bash
cd backend
docker-compose up -d
```

2. **Run Flutter App**:
```bash
flutter run
```

3. **Play**: Tap "🌐 Play Online vs Bot" on home screen

See [Backend Integration Guide](docs/BACKEND_INTEGRATION.md) for complete setup.

## 🏗️ Architecture

### Frontend (Flutter)
- **Engine**: Complete chess logic for 12 game modes
- **AI**: Local bot for offline play
- **UI**: Optimized board rendering with gesture handling
- **Services**: REST API + WebSocket for online play

### Backend (Go) - NEW! 🎉
- **Chess Engine**: All 12 game modes with move validation
- **AI Bots**: Minimax with alpha-beta pruning (10 levels)
- **Multiplayer**: Real-time WebSocket communication
- **Infrastructure**: Docker, PostgreSQL, Redis

## 📖 Documentation

- [Backend Integration Guide](docs/BACKEND_INTEGRATION.md) - **START HERE** for online play
- [Backend Implementation](backend/IMPLEMENTATION_SUMMARY.md) - Backend architecture details
- [Performance Optimizations](docs/PERFORMANCE_OPTIMIZATIONS_COMPLETE.md)
- [Game Modes](docs/project/roadmap.md)

## 🎯 Game Modes

1. **Classic** - Traditional chess
2. **Royal Pawns** - Pawns move like kings
3. **Other Side** - Race rooks to opponent's back rank
4. **Heir** - Capturable kings with pawn promotion
5. **Truce** - No attacks until all pieces moved
6. **Snare** - Knight entangle zones trap pieces
7. **Diamonds** - Bishops capture in diamond pattern
8. **Teleport** - King and rook can swap positions
9. **Friendly Fire** - Capture your own pieces
10. **Kings' Battle** - Kings and pawns only until first kill
11. **Save the Queen** - Rescue imprisoned queens
12. **Save the King** - Promote pawn to king

## 🧪 Development

### Create Project (Already Done)

```dart
flutter create --org chess.recast --project-name chessrecast \
--description "Novel chess with the same board, same pieces but with new rules!" \
--platforms android,ios,web,windows,macos,linux \
--template app chessrecast
```

### Run Emulator

```bash
flutter run -d emulator-5554
```

### Build Backend

```bash
cd backend
go build -o chessrecast-api.exe cmd/api/main.go
```

## 🛠️ Tech Stack

### Frontend
- **Flutter** 3.x
- **GetX** - State management
- **Custom Chess Engine** - 12 game modes
- **HTTP + WebSocket** - Backend communication

### Backend
- **Go** 1.21+
- **Gin** - Web framework
- **PostgreSQL** - Game storage
- **Redis** - Session management
- **Docker** - Containerization

## 📊 Testing

### Test Backend
```bash
curl http://localhost:8080/health
```

### Test API
```bash
curl -X POST http://localhost:8080/api/v1/auth/guest
```

### Run Flutter Tests
```bash
flutter test
```

## 🤝 Contributing

Contributions welcome! Areas of interest:
- New game modes
- UI/UX improvements
- Performance optimizations
- Backend features (matchmaking, tournaments)

## 📄 License

See LICENSE file

---

**Status**: ✅ Fully playable with online backend integration!

