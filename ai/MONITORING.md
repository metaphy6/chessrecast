# Training Monitoring Commands

## Watch Live Progress
```powershell
# Follow training logs in real-time
docker logs -f chessrecast-ai-poc

# Check last 30 lines
docker logs --tail 30 chessrecast-ai-poc

# Check with timestamps
docker logs -f --timestamps chessrecast-ai-poc
```

## Check Resource Usage
```powershell
# GPU utilization
nvidia-smi

# Container CPU/Memory
docker stats chessrecast-ai-poc

# Both together (refresh every 2 seconds)
while ($true) { 
    Clear-Host
    Write-Host "=== GPU Status ===" -ForegroundColor Cyan
    nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu --format=csv
    Write-Host "`n=== Container Stats ===" -ForegroundColor Cyan
    docker stats --no-stream chessrecast-ai-poc
    Write-Host "`n=== Latest Log ===" -ForegroundColor Cyan
    docker logs --tail 3 chessrecast-ai-poc
    Start-Sleep -Seconds 2
}
```

## What You'll See

### Self-Play Phase (CPU-bound)
```
🎲 Self-Play Phase (with MCTS-Lite):
   Temperature: decay, MCTS: 50 sims/move
   Playing 40 games:
      Starting game (MCTS: 50 sims/move).......... 76 moves, result: 0-1
   [1/40] 8.9s/game, avg: 8.9s, ETA: 5.8m
      Starting game (MCTS: 50 sims/move)...... 54 moves, result: 1/2-1/2
      Starting game (MCTS: 50 sims/move)......... 83 moves, result: 1-0
   [5/40] 7.2s/game, avg: 7.8s, ETA: 4.6m
```

**Dots:** Each `.` = 10 moves (shows it's running)
**Timing:** Per-game time, average, and ETA
**GPU Usage:** Low (1-5%) - normal during self-play

### Training Phase (GPU-bound)
```
🎓 Training Phase:
   Epoch  1/8 - Total: 2.3456, Policy: 2.2134, Value: 0.0891
   Epoch  2/8 - Total: 1.8234, Policy: 1.7323, Value: 0.0745
   Epoch  3/8 - Total: 1.5421, Policy: 1.4566, Value: 0.0632
   ...
```

**GPU Usage:** High (80-100%) - heavy neural network training

## Current Training Details

**Configuration:**
- Algorithm: Policy-guided MCTS (50 sims/move)
- Games: 8 iterations × 40 games = 320 total
- Expected time: ~25-35 minutes
- Expected strength: 800-1200 Elo

**Timeline:**
- Self-play: ~6 minutes per iteration (40 games × 9s/game)
- Training: ~2 minutes per iteration (8 epochs)
- Total per iteration: ~8 minutes
- Full training: ~64 minutes (8 iterations)

**Progress Pattern:**
```
Iteration 1: Self-play 6m → Training 2m → Checkpoint saved
Iteration 2: Self-play 5.5m → Training 2m → Checkpoint saved
...
Iteration 8: Self-play 5m → Training 2m → Final model saved
```

## Stop Training
```powershell
docker stop chessrecast-ai-poc
```

## After Training

**Get trained model:**
```powershell
docker cp chessrecast-ai-poc:/workspace/checkpoints/chess_improved_final.pth ./chess_improved_final.pth
```

**Check model size:**
```powershell
docker exec chessrecast-ai-poc ls -lh /workspace/checkpoints/
```
