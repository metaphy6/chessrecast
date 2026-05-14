# ♟️ ChessRecast

> **Chess variants with a native C runtime engine, 8 original game modes, and a full-stack mobile platform.**

ChessRecast reinvents chess with creative rule variants like Mercenary (king-like pawns), Heir (promotable kings), Truce (no-attack opening phase), and more. The Flutter app now runs engine search through the native C engine in `frontend/native/engine`, while `frontend/lib/engine` is the Dart bridge and async wrapper layer around that runtime.

---

## 🎮 game mods

| Mod | Emoji | Description | Status |
|------|-------|-------------|--------|
| **Classic** | ♟️ | Standard chess | ✅ Active |
| **Mercenary** | ⚔️ | Pawns move & capture like kings | ✅ Active |
| **Heir** | 👑 | Pawns can promote to King; kings are capturable | ✅ Active |
| **Truce** | 🤝 | No captures until all pieces moved once | ✅ Active |
| **Friendly Fire** | 🔥 | Capture your own pieces (except kings) | ✅ Active |
| **Kings' Battle** | ⚔️👑 | Two-phase: only pawns/kings until King's Kill | ✅ Active |
| **Save the Queen** | 🛡️ | Queens start as prisoners on enemy side | ✅ Active |
| **Succession** | 🏰 | Two queens, race to promote pawn to King | ✅ Active |

> See [docs/game/GAME_MODS_DOCUMENTATION.md](docs/game/GAME_MODS_DOCUMENTATION.md) for full rules.

---

## 🏗️ Architecture

```
chessrecast/
├── 📱 frontend/          Flutter mobile app (Android / iOS / Web)
│   ├── lib/engine/        Native-engine bridge and async wrapper
│   └── native/engine/     C engine (alpha-beta, eval, heuristics)
├── 🖥️  backend/           Go API server + PostgreSQL + Redis (legacy)
├── 🌐 signaling/          Go P2P signalling server (in progress)
├── 🤖 agent/              Autonomous-loop state, queue, baselines, reports
├── 🔧 xops/               Operational scripts
│   ├── agent/             Safe-run, bootstrap, retry, p2p-tracking helpers
│   └── power/             Wake-lock scripts for overnight agent runs
└── 📚 docs/              Project documentation
```

Short note: Flutter runtime engine search is native-only. There is no Dart search fallback in the app runtime anymore.

### Tech Stack

| Layer | Technology |
|-------|------------|
| **Mobile** | Flutter 3.x · Dart · GetX |
| **Engine** | Native C engine · Alpha-Beta · Iterative Deepening · Transposition Tables |
| **Backend** | Go 1.21 · Gin · PostgreSQL 18 · Redis 8 · WebSocket |
| **Infra** | Docker · docker-compose |

---

## 🚀 Quick Start

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) (3.x+)
- [Go](https://go.dev/dl/) (1.21+)
- [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- [Android Studio](https://developer.android.com/studio) (emulator) or a physical device

---

### 📱 1. Flutter App

```bash
cd frontend
flutter pub get
flutter run
```

**Run on Android emulator** (VS Code task available):
```bash
# Start emulator (or use VS Code task: start-emulator-Pixel9ProXL)
emulator -avd Pixel9ProXL

# Run the app
cd frontend
flutter run
```

**Build APK:**
```bash
cd frontend
flutter build apk --release
```

---

### 🖥️ 2. Go Backend

The backend runs via Docker Compose — PostgreSQL, Redis, and the API server all start together:

```bash
cd backend
docker compose up -d --build
```

This starts:
- **API server** → `http://localhost:8080` (REST + WebSocket)
- **Metrics** → `http://localhost:9090`
- **PostgreSQL** → `localhost:5432` (main DB)
- **PostgreSQL Logs** → `localhost:5433` (game logs DB)
- **Redis** → `localhost:6379`

**Stop everything:**
```bash
cd backend
docker compose down
```

> VS Code tasks are also available: `Backend: Start Docker Compose`, `Backend: Stop Docker Compose`, etc.

---

## 📱 Frontend Structure

```
frontend/lib/
├── main.dart                       # App entry point
├── routes.dart                     # GetX route definitions
├── bindings.dart                   # Dependency injection
├── constants.dart                  # App-wide constants
├── mods/                           # game mod definitions
│   ├── mods.dart                   # Barrel exports
│   ├── enums.dart                  # ModsEnum (all mode metadata)
│   ├── cache.dart                  # Singleton mode instances
│   ├── ruleset.dart                # Base ruleset for mode-specific rules
│   ├── mercenary.dart              # Mercenary rules
│   └── ...                         # One file per mode
├── board/                          # Chess board engine
│   ├── board.dart                  # ChessBoard state
│   ├── piece.dart                  # ChessPiece
│   ├── pieces/                     # Piece types & colors
│   ├── moves/                      # Move generation, validation, execution
│   └── utils/                      # FEN export, helpers
├── management/                     # Game controllers
│   ├── controller.dart             # Main game controller (GetX)
│   ├── online_controller.dart      # WebSocket online play
│   ├── watch_engine_controller.dart # Engine Lab auto-play controller
│   ├── orchestrator.dart           # Mod-aware move orchestration
│   └── options.dart                # Game setup options
├── engine/                         # Native-engine bridge layer
│   ├── native.dart                 # FFI bindings and runtime loading
│   ├── engine.dart                 # Public async API (Isolate.run)
│   ├── search_result.dart          # Search result DTO
│   └── score_utils.dart            # Shared mate-score helpers for tests/tooling
├── analytics/                      # Game analysis
│   └── custom/                     # Custom board setup
├── services/                       # External services
│   ├── api_service.dart            # REST API client
│   └── game_websocket.dart         # WebSocket client
└── ui/                             # Screens & widgets
    ├── start.dart                  # Home screen
    ├── game_page.dart              # Chess game screen
    ├── game_mod_selection.dart     # Mod picker
    ├── play_options.dart            # Play type selection
    ├── watch_engine_page.dart       # Engine Lab (watch engine play)
    ├── bot_selection_page.dart      # Online bot setup (Go backend)
    └── online_bot_vs_bot_page.dart  # Online bot spectator
```

---

## 🖥️ Backend Structure

```
backend/
├── docker-compose.yml              # PostgreSQL + Redis + API
├── Dockerfile                      # Go API build
├── go.mod
├── cmd/api/                        # API entry point + routes + handlers
│   ├── main.go
│   ├── routes.go
│   ├── handlers.go
│   └── ws.go                       # WebSocket handling
├── config/                         # Config files
├── internal/
│   ├── ai/                         # AI integration
│   ├── engine/                     # Chess engine (Go)
│   ├── game/                       # Game session management
│   └── storage/                    # PostgreSQL + Redis
```

**API:** `http://localhost:8080` — REST endpoints + WebSocket at `/ws`  
**Databases:** Main app DB (`:5432`) + Game logs DB (`:5433`)

---

## 📚 Documentation

| Document | Description |
|----------|-------------|
| [docs/game/GAME_MODS_DOCUMENTATION.md](docs/game/GAME_MODS_DOCUMENTATION.md) | Full rules for all 8 game mods |
| [docs/game/DRAW_RULES.md](docs/game/DRAW_RULES.md) | Draw rules (50-move, stalemate, Mercenary variant) |
| [docs/P2P_ROADMAP.md](docs/P2P_ROADMAP.md) | P2P GameNet implementation roadmap (20 phases) |
| [docs/coding/ai/p2p_implementation.md](docs/coding/ai/p2p_implementation.md) | AI agent harness for P2P implementation |
| [docs/coding/ai/automation.md](docs/coding/ai/automation.md) | AI automation roadmap |
| [docs/code/BUILD_ARTIFACTS_MANAGEMENT.md](docs/code/BUILD_ARTIFACTS_MANAGEMENT.md) | Native engine build & artifact management |
| [docs/code/NATIVE_ENGINE_PLATFORM_AUDIT.md](docs/code/NATIVE_ENGINE_PLATFORM_AUDIT.md) | Platform support audit for the native C engine |
| [AGENTS.md](AGENTS.md) | AI coding assistant rulebook |

---

## ⚙️ VS Code Tasks

Pre-configured tasks in `.vscode/tasks.json`:

| Task | Description |
|------|-------------|
| `start-emulator-Pixel9ProXL` | Launch Android emulator |
| `Backend: Start Docker Compose` | Start Go API + DB + Redis |
| `Backend: Stop Docker Compose` | Stop backend services |
| `Backend: Restart Docker Compose` | Restart backend services |
| `Backend: View Docker Logs` | Tail backend logs |
| `Frontend: Rebuild Native Engine` | Rebuild the native C engine (`cmake --build build/native/linux`) |

---

## 🛠️ Development Workflow

```bash
# 1. Start backend
cd backend && docker compose up -d --build
# 2. Build native C engine
cd frontend && cmake --build build/native/linux
# 3. Start emulator (or use VS Code task: start-emulator-Pixel9ProXL)
emulator -avd Pixel9ProXL
# 4. Run Flutter app
cd frontend && flutter run
# 5. (Optional) overnight agent session
./xops/power/agent-session-start.sh
```

---

## 🔮 Roadmap

- [x] 8 active game mods with full Dart logic
- [x] Go backend with PostgreSQL, Redis, WebSocket
- [x] Native runtime C chess engine with Dart FFI bridge
- [x] 5 engine difficulty levels (Easy → Maximum)
- [x] Engine Lab UI (watch engine self-play with live stats)
- [x] AI agent harness (`agent/`, `xops/agent/`) for autonomous engine improvement
- [ ] P2P distributed network (GameNet) — see [docs/P2P_ROADMAP.md](docs/P2P_ROADMAP.md)
- [ ] Quantum-resistant blockchain (MOT) for validation
- [ ] NFT system for game replays
- [ ] Token economics with play-to-earn rewards

---

## 📄 License

Private repository. All rights reserved.
