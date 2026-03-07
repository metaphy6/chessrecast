# Mercenary Mod AI Training

Auto-detects GPU/CPU and provides flexible training and testing modes.

## Features

- ✅ **Auto GPU/CPU Detection**: Automatically uses GPU if available, falls back to CPU
- ✅ **Test Mode**: Play random games without training for rule testing
- ✅ **Adjustable Speed**: Set move delay from 0.1 to 10 seconds
- ✅ **WebSocket Streaming**: Live game viewing on port 8765

## Usage

### Test Mode (Random Games)

Play random Mercenary games with adjustable speed:

```bash
# Default: 0.3s delay
python mods/train_mercenary.py --test

# 1 second per move (good for watching)
python mods/train_mercenary.py --test --delay 1.0

# 5 seconds per move (slow demo)
python mods/train_mercenary.py --test --delay 5.0
```

### Training Mode

Full neural network training:

```bash
# Auto-detects GPU/CPU
python mods/train_mercenary.py

# GPU: ~6-10 hours for High ELO
# CPU: Much longer but functional
```

## Docker Usage

### Quick Start (Recommended)

1. **Configure settings** (optional):
   ```bash
   cd ai/docker/mods/mercenary
   # Edit .env to set TEST_MODE and MOVE_DELAY
   ```

2. **Start container**:
   ```bash
   docker compose up
   ```

### Configuration Options

Edit `.env` file or set environment variables:

```bash
# Test Mode with 1s delay (default)
TEST_MODE=true MOVE_DELAY=1.0

# Fast Test Mode
TEST_MODE=true MOVE_DELAY=0.3

# Slow demo (5s per move)
TEST_MODE=true MOVE_DELAY=5.0

# Full training mode
TEST_MODE=false MOVE_DELAY=0.3
```

### One-Line Commands

```bash
cd ai/docker/mods/mercenary

# Test Mode with 2s delay
TEST_MODE=true MOVE_DELAY=2.0 docker compose up

# Training mode
TEST_MODE=false docker compose up
```

### Test Mode (Default)

```bash
cd ai/docker/mods/mercenary
docker compose up
```

Edit `.env` to change delay:
```env
TEST_MODE=true
MOVE_DELAY=2.0
```

### Training Mode

```bash
cd ai/docker/mods/mercenary
docker compose run --rm mercenary-trainer python mods/train_mercenary.py
```

### Direct Docker Run

```bash
# Test Mode with 1s delay
sudo docker run -p 8765:8765 -v $(pwd)/trainer:/workspace docker-mercenary-trainer:latest python mods/train_mercenary.py --test --delay 1.0

# Training mode
sudo docker run -p 8765:8765 -v $(pwd)/trainer:/workspace docker-mercenary-trainer:latest python mods/train_mercenary.py
```

## Connect Flutter App

1. Open Flutter app → "Watch Live Training"
2. Connect to:
   - **Android Emulator**: `10.0.2.2:8765`
   - **Desktop/Web**: `localhost:8765`
   - **Real Device**: `<your-ip>:8765`

## Device Detection

The script automatically:
- Uses **CUDA/GPU** if available (fast training)
- Falls back to **CPU** if no GPU (slower but works)
- Adjusts batch sizes and network complexity accordingly

## Performance

| Mode | Device | Speed | Purpose |
|------|--------|-------|---------|
| Test | CPU | Real-time | Rule testing, demos |
| Test | GPU | Real-time | Rule testing, demos |
| Train | CPU | ~Hours per iteration | Basic training |
| Train | GPU | ~Minutes per iteration | Full High ELO training |
