# Quick Start Guide - Mercenary AI Training

## Setup

### 1. Install Dependencies
```bash
cd ai/trainer
pip install -r requirements.txt
```

### 2. Verify GPU (Optional)
```bash
python -c "import torch; print('CUDA:', torch.cuda.is_available()); print('GPU:', torch.cuda.get_device_name(0) if torch.cuda.is_available() else 'CPU')"
```

## Start Training

### Full Training Mod (6-10 hours on RTX 4080)
```bash
cd ai/trainer
python mods/train_mercenary.py
```

### Test Mod (Watch AI Play - Configurable Delays)

**Recommended for watching (1.5s per move):**
```bash
python mods/train_mercenary.py --test --delay 1.5
```

**Slow demo (5s per move):**
```bash
python mods/train_mercenary.py --test --delay 5.0
```

**Fast test (0.3s per move):**
```bash
python mods/train_mercenary.py --test --delay 0.3
```

## Watch in Flutter App

1. Start training in test mode: `python mods/train_mercenary.py --test --delay 1.5`
2. Open ChessRecast Flutter app
3. Go to "Watch Live Training"
4. Connect to `localhost:8765`
5. Watch AI play with **real-time move validation**!

**The Flutter app validates every move** against the actual game logic (Mercenary mode) and reports errors back to Python instantly if there are any discrepancies.

## Running via Docker

See the per-mode compose files in `ai/docker/mods/<mode>/`.

## Configuration

Edit `mods/train_mercenary.py` to customize:
- `NUM_ITERATIONS`: Training iterations (default: 200)
- `GAMES_PER_ITERATION`: Games per iteration (default: 50)
- `MCTS_SIMULATIONS`: Simulations per move (default: 150)
- `BATCH_SIZE`: GPU batch size (default: 512)

## Outputs

- **Models**: `ai/trainer/checkpoints/mercenary/`
- **Training Games**: `ai/trainer/data/training_games/`
- **WebSocket**: `ws://localhost:8765`

## Docker Alternative

```bash
cd ai/docker/mods/mercenary
docker compose up
```

Configure via environment variables:
```bash
TEST_MODE=true MOVE_DELAY=1.5 docker compose up
```
