# AI Model Directory

This directory will contain the trained TFLite models.

## Current Status
🔥 **Training in progress!** - Improved algorithm with MCTS

**Configuration:**
- Algorithm: Policy-guided MCTS (50 simulations/move)
- Iterations: 8 × 40 games = 320 total games
- Expected time: 25-35 minutes
- Expected strength: 800-1200 Elo (strategic beginner)

**What's training:**
- ✅ Policy network (learns which moves are good)
- ✅ Value network (learns who's winning)
- ✅ MCTS lookahead (2-3 moves ahead)
- ✅ Temperature scheduling (exploration → exploitation)

## Monitor Progress

**Check training logs:**
```powershell
docker logs -f chessrecast-ai-poc
```

**Check GPU/CPU usage:**
```powershell
# GPU stats
nvidia-smi

# Container stats
docker stats chessrecast-ai-poc
```

**Note:** Self-play phase is CPU-bound (game simulation takes time). The GPU will be heavily used during training epochs after each batch of games is complete.

## After Training

**Copy PyTorch model:**
```powershell
docker cp chessrecast-ai-poc:/workspace/checkpoints/chess_improved_final.pth ./chess_improved_final.pth
```

**Copy all checkpoints (optional):**
```powershell
docker cp chessrecast-ai-poc:/workspace/checkpoints/ ./checkpoints/
```

## Expected Files
- `chess_improved_final.pth` - Trained model (~35 MB)
- `checkpoint_iter_*.pth` - Per-iteration checkpoints (optional)

## Integration Options

### Option 1: PyTorch Mobile (Recommended)
- Direct `.pth` → `.ptl` conversion
- Native performance
- ~10-15 MB after optimization
- Fast inference: 10-50ms per move

### Option 2: ONNX Runtime
- Cross-platform compatibility
- Similar size and performance
- Good fallback option

### Option 3: API-Based
- Keep model on server
- 0 MB on device
- Requires internet connection

See `ai/docs/IMPROVED_ALGORITHM.md` for details.
