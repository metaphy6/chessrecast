# ♟️ ChessRecast

> **AI-powered chess variants — 12 original game mods, self-learning neural networks, and a full-stack mobile platform.**

ChessRecast reinvents chess with creative rule variants like Mercenary (king-like pawns), Heir (promotable kings), Truce (no-attack opening phase), and more. Each mode has its own dedicated AI trained via AlphaZero-style reinforcement learning, running on GPU-accelerated Docker containers with live streaming to a Flutter mobile app.

---

## 🎮 game mods

| Mode | Emoji | Description | Status |
|------|-------|-------------|--------|
| **Classic** | ♟️ | Standard chess | ✅ Active |
| **Mercenary** | ⚔️ | Pawns move & capture like kings | ✅ Active |
| **Heir** | 👑 | Pawns can promote to King; kings are capturable | ✅ Active |
| **Truce** | 🤝 | No captures until all pieces moved once | ✅ Active |
| **Friendly Fire** | 🔥 | Capture your own pieces (except kings) | ✅ Active |
| **Kings' Battle** | ⚔️👑 | Two-phase: only pawns/kings until King's Kill | ✅ Active |
| **Save the Queen** | 🛡️ | Queens start as prisoners on enemy side | ✅ Active |
| **Succession** | 🏰 | Two queens, race to promote pawn to King | ✅ Active |
| Coyote | 🐺 | Rook race to back rank | 🚧 Disabled |
| Snare | 🪤 | Knight entangle zones | 🚧 Disabled |
| Diamonds | 💎 | Bishop diamond-pattern captures | 🚧 Disabled |
| Secret Passage | 🚪 | King↔Rook teleport swaps | 🚧 Disabled |

> See [docs/project/GAME_MODS_DOCUMENTATION.md](docs/project/GAME_MODS_DOCUMENTATION.md) for full rules.

---

## 🏗️ Architecture

```
chessrecast/
├── 📱 frontend/          Flutter mobile app (Android / iOS / Web)
├── 🖥️  backend/           Go API server + PostgreSQL + Redis
├── 🧠 ai/                PyTorch AI training infrastructure
│   ├── docker/            Docker configs (per-mode compose files)
│   └── trainer/           Neural network, MCTS, training scripts
└── 📚 docs/              Project & AI documentation
```

### Tech Stack

| Layer | Technology |
|-------|-----------|
| **Mobile** | Flutter 3.x · Dart · GetX · TFLite |
| **Backend** | Go 1.21 · Gin · PostgreSQL 18 · Redis 8 · WebSocket |
| **AI** | PyTorch 2.1 · CUDA 12.1 · python-chess · MCTS |
| **Infra** | Docker · NVIDIA Container Toolkit · docker-compose |

---

## 🚀 Quick Start

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) (3.x+)
- [Go](https://go.dev/dl/) (1.21+)
- [Docker Desktop](https://www.docker.com/products/docker-desktop/) with NVIDIA Container Toolkit (for GPU training)
- [Android Studio](https://developer.android.com/studio) (emulator) or a physical device
- Python 3.10+ with CUDA (for local AI training without Docker)

---

### 📱 1. Flutter App

```powershell
cd frontend
flutter pub get
flutter run
```

**Run on Android emulator** (VS Code task available):
```powershell
# Start emulator (or use VS Code task: start-emulator-Pixel9ProXL)
emulator -avd Pixel9ProXL

# Run the app
cd frontend
flutter run
```

**Build APK:**
```powershell
cd frontend
flutter build apk --release
```

---

### 🖥️ 2. Go Backend

The backend runs via Docker Compose — PostgreSQL, Redis, and the API server all start together:

```powershell
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
```powershell
cd backend
docker compose down
```

> VS Code tasks are also available: `Backend: Start Docker Compose`, `Backend: Stop Docker Compose`, etc.

---

### 🧠 3. AI Training (Docker — Recommended)

Each game mod has its own Docker Compose config. Training uses GPU acceleration with NVIDIA Container Toolkit.

**Start Mercenary training:**
```powershell
cd ai/docker/mods/mercenary
docker compose up --build
```

**Test mode** (watch AI play random games with live WebSocket streaming):
```powershell
cd ai/docker/mods/mercenary
# Edit .env: TEST_MODE=true, MOVE_DELAY=1.5
docker compose up --build
```

**Other modes:**
```powershell
cd ai/docker/mods/heir          # 👑 Heir mode
cd ai/docker/mods/truce         # 🤝 Truce mode
cd ai/docker/mods/friendly-fire # 🔥 Friendly Fire
cd ai/docker/mods/kings-battle  # ⚔️👑 Kings' Battle
cd ai/docker/mods/save-the-queen # 🛡️ Save the Queen
cd ai/docker/mods/succession    # 🏰 Succession
cd ai/docker/mods/classic       # ♟️ Classic
# Then: docker compose up --build
```

**Local training (without Docker):**
```powershell
cd ai/trainer
pip install -r requirements.txt
python mods/train_mercenary.py           # Full training
python mods/train_mercenary.py --test    # Test mode
python mods/train_mercenary.py --test --delay 1.5  # Slow demo
```

---

### 📺 4. Watch Live Training in Flutter App

1. Start training in test mode (Docker or local)
2. Open ChessRecast → **Watch Live Training**
3. Connect to the WebSocket:
   - **Android emulator:** `10.0.2.2:8765`
   - **Desktop / Web:** `localhost:8765`
   - **Physical device:** `<your-lan-ip>:8765`

The app validates every move against Flutter's game logic in real-time and reports discrepancies back to the Python trainer.

---

## 🧠 AI System

### Algorithm

AlphaZero-style **Policy-guided MCTS** (Monte Carlo Tree Search):

| Parameter | Value |
|-----------|-------|
| Architecture | ResNet (128 channels, 10 residual blocks, 11.9M params) |
| MCTS Simulations | 150 per move |
| Exploration Constant (c_puct) | 1.4 |
| Dirichlet Noise | α=0.3, ε=0.25 |
| Policy Loss | Cross-entropy |
| Value Loss | MSE |
| Training | 200 iterations × 50 games × 150 MCTS sims |

### Hardware

| Component | Recommended | Minimum |
|-----------|-------------|---------|
| GPU | NVIDIA RTX 4080+ | RTX 3080 |
| VRAM | 12 GB+ | 8 GB |
| RAM | 32 GB | 16 GB |
| Training Time | ~6-10 hours/mode (RTX 4080) | Longer on CPU |

### File Structure

```
ai/
├── docker/
│   ├── Dockerfile                  # Universal (ARG TRAIN_SCRIPT)
│   └── mods/                       # Per-mode docker-compose configs
│       ├── mercenary/
│       ├── heir/
│       ├── truce/
│       ├── friendly-fire/
│       ├── kings-battle/
│       ├── save-the-queen/
│       ├── succession/
│       └── classic/
└── trainer/
    ├── network.py                  # Neural network (ResNet, CPU/GPU)
    ├── selfplay.py                 # MCTS self-play engine
    ├── rules.py                    # Base chess game wrapper
    ├── requirements.txt
    ├── mods/                       # game mod rules + training scripts
    │   ├── base.py                 # GameMod base class
    │   ├── mercenary.py            # Mercenary rules
    │   └── train_mercenary.py      # Training entry point
    └── tools/                      # Utilities
        ├── logger.py               # Pretty ANSI console output
        ├── server.py               # WebSocket live streaming
        ├── recorder.py             # Game recording for viewer
        └── export.py               # TFLite export for Flutter
```

> See [docs/ai/README.md](docs/ai/README.md) for detailed AI documentation.

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
│   ├── mods_enum.dart              # ModsEnum (all mode metadata)
│   ├── mods_cache.dart             # Singleton mode instances
│   ├── game_mod.dart              # Base GameMod class
│   ├── mercenary.dart              # Mercenary rules (Dart)
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
│   ├── orchestrator.dart           # Mode-aware move orchestration
│   └── options.dart                # Game setup options
├── analytics/                      # Game analysis
│   ├── ai/                         # AI player + manager
│   └── custom/                     # Custom board setup
├── services/                       # External services
│   ├── ai_service.dart             # TFLite AI inference
│   ├── api_service.dart            # REST API client
│   └── game_websocket.dart         # WebSocket client
└── ui/                             # Screens & widgets
    ├── start.dart                  # Home screen
    ├── game_page.dart              # Chess game screen
    ├── game_mod_selection.dart     # Mode picker
    ├── play_options.dart            # Play type selection
    ├── ai_setup.dart                # AI game configuration
    ├── training_viewer.dart         # Saved training game viewer
    ├── live_training_viewer.dart    # Real-time training stream
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
| [docs/ai/README.md](docs/ai/README.md) | AI training overview, file structure, algorithm |
| [docs/ai/QUICKSTART.md](docs/ai/QUICKSTART.md) | Quick start guide for Mercenary training |
| [docs/ai/README_MERCENARY.md](docs/ai/README_MERCENARY.md) | Mercenary mode training details |
| [docs/ai/IMPROVED_ALGORITHM.md](docs/ai/IMPROVED_ALGORITHM.md) | Policy-guided MCTS algorithm design |
| [docs/ai/ALGORITHM_FLOW_COMPARISON.md](docs/ai/ALGORITHM_FLOW_COMPARISON.md) | Old vs improved algorithm comparison |
| [docs/project/GAME_MODS_DOCUMENTATION.md](docs/project/GAME_MODS_DOCUMENTATION.md) | Full rules for all 12 game mods |
| [docs/project/MASTER_IMPLEMENTATION_PLAN.md](docs/project/MASTER_IMPLEMENTATION_PLAN.md) | Project roadmap & phases |
| [docs/code/docker-commands.md](docs/code/docker-commands.md) | Docker volume & cleanup commands |
| [docs/code/db-commands.md](docs/code/db-commands.md) | Database access & query reference |

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

---

## 🛠️ Development Workflow

```
1.  Start backend          →  cd backend && docker compose up -d --build
2.  Start emulator         →  VS Code task or: emulator -avd Pixel9ProXL
3.  Run Flutter app        →  cd frontend && flutter run
4.  (Optional) AI training →  cd ai/docker/mods/mercenary && docker compose up
5.  (Optional) Live viewer →  In app: Watch Live Training → connect ws
```

---

## 🔮 Roadmap

- [x] 8 active game mods with full Dart logic
- [x] Go backend with PostgreSQL, Redis, WebSocket
- [x] AlphaZero-style MCTS training pipeline
- [x] GPU-accelerated Docker training (per-mode)
- [x] Live training viewer (WebSocket → Flutter)
- [x] TFLite model export for on-device inference
- [ ] Train all 8 active modes to 1200+ Elo
- [ ] P2P distributed training network (GameNet)
- [ ] Quantum-resistant blockchain (MOT) for validation
- [ ] NFT system for game replays
- [ ] Token economics with play-to-earn rewards

> See [docs/project/MASTER_IMPLEMENTATION_PLAN.md](docs/project/MASTER_IMPLEMENTATION_PLAN.md) for the full timeline.

---

## 📄 License

Private repository. All rights reserved.
