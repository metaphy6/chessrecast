# Quick Start Guide - Mercenary AI

## Simple Setup

### 1. Create configuration file (optional)
```bash
cd ai
cp .env.example .env
nano .env  # Edit settings
```

### 2. Start the AI
```bash
# With default settings (test mode, 0.3s delay)
sudo docker compose -f docker/docker-compose.mercenary.yml up

# Or with custom settings
TEST_MODE=true MOVE_DELAY=2.0 sudo docker compose -f docker/docker-compose.mercenary.yml up
```

### 3. Connect Flutter App
- Open app → "Watch Live Training"
- Enter: `10.0.2.2:8765` (Android emulator)
- Or: `localhost:8765` (desktop/web)

## Common Configurations

| Use Case | Command |
|----------|---------|
| **Slow demo** (easy to watch) | `TEST_MODE=true MOVE_DELAY=3.0 sudo docker compose -f docker/docker-compose.mercenary.yml up` |
| **Normal speed** (default) | `sudo docker compose -f docker/docker-compose.mercenary.yml up` |
| **Fast test** | `TEST_MODE=true MOVE_DELAY=0.1 sudo docker compose -f docker/docker-compose.mercenary.yml up` |
| **Full training** (GPU recommended) | `TEST_MODE=false sudo docker compose -f docker/docker-compose.mercenary.yml up` |

## Stop the AI
```bash
# Press Ctrl+C, then:
sudo docker compose -f docker/docker-compose.mercenary.yml down
```

## Using .env File (Recommended)

**ai/.env**:
```bash
TEST_MODE=true
MOVE_DELAY=2.0
```

Then just run:
```bash
sudo docker compose -f docker/docker-compose.mercenary.yml up
```

The settings from `.env` are automatically loaded!
