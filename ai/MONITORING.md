# Training Monitoring Commands

## Watch Live Progress
```powershell
# Follow training logs in real-time
docker logs -f chessrecast-mercenary-trainer

# Check last 30 lines
docker logs --tail 30 chessrecast-mercenary-trainer

# Check with timestamps
docker logs -f --timestamps chessrecast-mercenary-trainer
```

## Live Training Viewer (Flutter App)
The training broadcasts all games via WebSocket on port 8765:
1. Open the Live Training Viewer in the Flutter app
2. Connect to `10.0.2.2:8765` (Android emulator) or `localhost:8765` (desktop)
3. Watch games play in real-time with move values

## Check Resource Usage
```powershell
# GPU utilization
nvidia-smi

# Container CPU/Memory
docker stats chessrecast-mercenary-trainer

# Both together (refresh every 2 seconds)
while ($true) { 
    Clear-Host
    Write-Host "=== GPU Status ===" -ForegroundColor Cyan
    nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu --format=csv
    Write-Host "`n=== Container Stats ===" -ForegroundColor Cyan
    docker stats --no-stream chessrecast-mercenary-trainer
    Write-Host "`n=== Latest Log ===" -ForegroundColor Cyan
    docker logs --tail 3 chessrecast-mercenary-trainer
    Start-Sleep -Seconds 2
}
```

## What You'll See

### Self-Play Phase
```
🎲 Self-Play Phase (with MCTS-Lite):
   Temperature: decay, MCTS: 150 sims/move
   Playing 50 games:
   [1/50] 8.9s/game, avg: 8.9s, ETA: 7.3m
   [5/50] 7.2s/game, avg: 7.8s, ETA: 5.8m
```

**GPU Usage:** Low (1-10%) during self-play - CPU-bound phase

### Training Phase
```
🎓 Training Phase:
   Epoch  1/8 - Total: 2.3456, Policy: 2.2134, Value: 0.0891
   Epoch  2/8 - Total: 1.8234, Policy: 1.7323, Value: 0.0745
   ...
```

**GPU Usage:** High (80-100%) during training

### Expected Progress
- **Per iteration:** ~5-10 minutes
- **Total (200 iterations):** ~2-3 hours
- **Checkpoint saves:** Every iteration to `checkpoints/mercenary_1800/`
