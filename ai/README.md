# ChessRecast AI Training

## Current Status
✅ Mercenary mode training active  
✅ Policy + MCTS self-play algorithm  
✅ GPU acceleration (RTX 4080)  
✅ Live WebSocket streaming for training viewer  

## Quick Start

### Start Mercenary Training
```powershell
cd ai/docker
docker-compose -f docker-compose.mercenary.yml up
```

**Configuration:**
- 200 iterations × 50 games × 150 MCTS simulations
- ~2-3 hours on RTX 4080
- Output: `checkpoints/mercenary_1800/` (35 MB per checkpoint)
- Expected: 1500-1800 Elo (Mercenary mode)

### Monitor Training (Live in Flutter app)
Connect the Live Training Viewer to `ws://localhost:8765` to watch games in real-time.

### Export to TFLite
```powershell
docker-compose -f docker-compose.mercenary.yml run --rm trainer \
    python trainer/export_mercenary_tflite.py
```

## File Structure

```
ai/
├── docker/
│   ├── docker-compose.mercenary.yml  # Production training
│   └── Dockerfile.trainer            # Docker build
├── trainer/
│   ├── train_mercenary_1800.py       # Main training script ⭐
│   ├── self_play_improved.py         # Policy + MCTS engine
│   ├── neural_network_gpu.py         # GPU-optimized model
│   ├── mercenary_rules.py            # Mercenary mode rules
│   ├── websocket_server.py           # Live streaming server
│   ├── export_mercenary_tflite.py    # TFLite export
│   ├── save_training_games.py        # Game recording
│   ├── analyze_training.py           # Checkpoint evaluation
│   ├── diagnose_mercenary.py         # Debug tool
│   ├── test_gpu.py                   # GPU detection test
│   ├── test_setup.py                 # Setup verification
│   └── test_improved_algorithm.py    # MCTS algorithm test
├── docs/
│   ├── ALGORITHM_FLOW_COMPARISON.md  # Algorithm docs
│   └── IMPROVED_ALGORITHM.md         # Technical details
├── MONITORING.md                      # Training monitoring guide
└── README.md                          # This file
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

See [`docs/IMPROVED_ALGORITHM.md`](docs/IMPROVED_ALGORITHM.md) for details.

## Hardware Requirements

- **GPU**: NVIDIA RTX 3080+ recommended
- **VRAM**: 8GB+ 
- **RAM**: 16GB+
- **Docker**: With NVIDIA Container Toolkit

## Output Files

```
ai/trainer/
├── checkpoints/mercenary_1800/
│   ├── best_model.pth           # Best performing model
│   ├── checkpoint_*.pth         # Iteration checkpoints
│   └── training_stats.json      # Training metrics
├── data/training_games/
│   └── game_*.json              # Recorded games
└── models/
    └── mercenary_1800.tflite    # Exported for Flutter
```
