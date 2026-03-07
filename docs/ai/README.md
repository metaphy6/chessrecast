# ChessRecast AI Training

## Current Status
✅ Mercenary mode training active  
✅ Policy + MCTS self-play algorithm  
✅ GPU acceleration (RTX 4080)  
✅ Live WebSocket streaming for training viewer  

## Quick Start

### Start Mercenary Training
```bash
cd ai/trainer
python mods/train_mercenary.py
```

**Configuration:**
- 200 iterations × 50 games × 150 MCTS simulations
- ~6-10 hours on RTX 4080
- Output: `checkpoints/mercenary/` (35 MB per checkpoint)
- Auto-detects GPU (CUDA)

### Monitor Training (Live in Flutter app)
Connect the Live Training Viewer to `ws://localhost:8765` to watch games in real-time.

### Export to TFLite
```powershell
cd ai/docker/mods/mercenary
docker compose run --rm mercenary-trainer python tools/export.py
```

## File Structure

```
ai/
├── docker/                               # Docker infrastructure
│   ├── Dockerfile                        # Shared dynamic Dockerfile (ARG TRAIN_SCRIPT)
│   └── mods/                             # Per-mode Docker Compose configs
│       ├── mercenary/                    # ⚔️  Mercenary mode
│       │   ├── docker-compose.yml
│       │   └── .env
│       ├── heir/                         # 👑 Heir mode
│       │   ├── docker-compose.yml
│       │   └── .env
│       ├── truce/                        # 🤝 Truce mode
│       │   ├── docker-compose.yml
│       │   └── .env
│       ├── friendly-fire/                # 🔥 Friendly Fire mode
│       │   ├── docker-compose.yml
│       │   └── .env
│       ├── kings-battle/                 # ⚔️👑 Kings Battle mode
│       │   ├── docker-compose.yml
│       │   └── .env
│       ├── save-the-queen/               # 🛡️  Save The Queen mode
│       │   ├── docker-compose.yml
│       │   └── .env
│       ├── succession/                   # 🏰 Succession mode
│       │   ├── docker-compose.yml
│       │   └── .env
│       └── classic/                      # ♟️  Classic mode
│           ├── docker-compose.yml
│           └── .env
├── trainer/
│   ├── network.py                    # Neural network (CPU/GPU)
│   ├── selfplay.py                   # Policy + MCTS engine
│   ├── rules.py                      # Base chess game wrapper
│   ├── requirements.txt              # Python dependencies (local dev)
│   ├── mods/                         # Game Mod implementations + training scripts
│   │   ├── base.py                   # GameMod base class
│   │   ├── mercenary.py              # Mercenary mode rules
│   │   ├── train_mercenary.py        # Mercenary training script ⭐
│   │   └── README.md                 # How to add new modes
│   └── tools/                        # Helper utilities
│       ├── logger.py                 # Pretty console output (emoji/ANSI)
│       ├── server.py                 # WebSocket live streaming server
│       ├── recorder.py               # Game recording for visualization
│       └── export.py                 # TFLite export for Flutter
└── (docs in docs/ai/)
    ├── QUICKSTART.md                  # Quick setup guide
    └── README_MERCENARY.md            # Mercenary mode details
```

## Algorithm

Uses **Policy-guided MCTS** (Monte Carlo Tree Search):

| Feature | Value |
|---------|-------|
| MCTS Simulations | 150 per move |
| Exploration Constant | 1.4 |
| Policy Temperature | 1.0 (exploration) |
| Dirichlet Noise | α=0.3, ε=0.25 |
| Training | Cross-entropy (policy) + MSE (value) |

See [IMPROVED_ALGORITHM.md](IMPROVED_ALGORITHM.md) for details.

## Hardware Requirements

- **GPU**: NVIDIA RTX 3080+ recommended
- **VRAM**: 8GB+ 
- **RAM**: 16GB+
- **Docker**: With NVIDIA Container Toolkit

## Output Files

```
ai/trainer/
├── checkpoints/mercenary/
│   ├── best_model.pth           # Best performing model
│   ├── checkpoint_*.pth         # Iteration checkpoints
│   └── training_stats.json      # Training metrics
├── data/training_games/
│   └── game_*.json              # Recorded games
└── models/
    └── mercenary.tflite         # Exported for Flutter
```
