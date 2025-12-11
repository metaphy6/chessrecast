# ChessRecast AI System - Strategic Implementation Roadmap
**Version**: 2.0 - Strategic Planning Edition  
**Created**: December 11, 2025  
**Document Type**: Step-by-Step Implementation Plan  
**Target Audience**: AI Assistants, Developers, Project Managers

---

## 📖 How to Use This Document

This roadmap is designed for **ANY AI assistant or developer** to implement ChessRecast's AI system from scratch. 

**Structure:**
- Each phase has **specific steps** with clear deliverables
- Each step includes **expected outcomes** and success criteria
- Dependencies are explicitly stated
- Time estimates help with planning

**Follow this document linearly** - each phase builds on the previous one.

---

## 🎯 Project Vision

### What We're Building
Build 14 specialized AI chess agents for ChessRecast's custom game modes using self-learning reinforcement learning.

### Key Requirements
1. **Mobile-First**: Models must run on phones (5-20MB size limit)
2. **Self-Learning**: AI learns from self-play, no pre-existing datasets
3. **Distributed Training**: Starts on server (900-1200 Elo), improves on user devices (1200-2000 Elo)
4. **14 Specialized Models**: One per game mode (Classic, Heir, Snare, etc.)
5. **Blockchain Validated**: MOT blockchain proves training authenticity

### Hardware Constraints
- **Training Server**: RTX 4080 Mobile (12GB VRAM)
  - Can train one mode at a time
  - 3-5 days per mode for baseline training
- **User Devices**: Android/iOS phones with 2-8GB RAM
  - Must run inference in <100ms

---

## 🏗️ System Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    PHASE 1: SERVER TRAINING                      │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  RTX 4080 Mobile Server                                   │  │
│  │  • Train baseline models (900-1200 Elo)                   │  │
│  │  • Self-play reinforcement learning                       │  │
│  │  • 3-5 days per mode                                      │  │
│  │  • Export to TFLite (5-20MB)                              │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                                ↓
┌─────────────────────────────────────────────────────────────────┐
│                   PHASE 2: MOBILE DEPLOYMENT                     │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  Flutter App (Android/iOS)                                │  │
│  │  • Load TFLite models                                     │  │
│  │  • Run inference (<100ms per move)                        │  │
│  │  • User plays against 900-1200 Elo AI                     │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                                ↓
┌─────────────────────────────────────────────────────────────────┐
│                PHASE 3: DISTRIBUTED LEARNING (P2P)               │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐               │
│  │ User 1     │  │ User 2     │  │ User N     │               │
│  │ Device     │◄─┼─► Device   │◄─┼─► Device   │               │
│  │ • Training │  │  • Training │  │  • Training │               │
│  │ • Sharing  │  │  • Sharing  │  │  • Sharing  │               │
│  └────────────┘  └────────────┘  └────────────┘               │
│                        ↓                                         │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  MOT Blockchain                                           │  │
│  │  • Validate training contributions                        │  │
│  │  • Reward participants with MOTON                         │  │
│  │  • Track model ownership (sdata)                          │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📊 Phase Breakdown

### Phase 1: Foundation & Server Training
**Timeline**: 8 weeks  
**Goal**: Train baseline AI models on server, achieve 900-1200 Elo

### Phase 2: Mobile Integration
**Timeline**: 4 weeks  
**Goal**: Deploy AI to Flutter app, enable offline play

### Phase 3: P2P GameNet
**Timeline**: 6 weeks  
**Goal**: Enable distributed training across user devices

### Phase 4: Blockchain Integration
**Timeline**: 8 weeks  
**Goal**: Validate training with MOT blockchain, reward system

**Total Timeline**: 26 weeks (~6.5 months)

---

## 📅 PHASE 1: Foundation & Server Training (Weeks 1-8)

### Week 1: Project Setup & Infrastructure

#### Step 1.1: Set Up Training Environment
**Actions:**
1. Install Docker and Docker Compose on training server
2. Install NVIDIA drivers and CUDA toolkit (12.1+)
3. Verify GPU accessibility: `nvidia-smi` should show RTX 4080 Mobile
4. Create project directory structure:
   - `ai/trainer/` - Training code
   - `ai/docker/` - Docker configurations
   - `ai/models/checkpoints/` - Model storage
   - `ai/data/replays/` - Training game records

**Expected Outcomes:**
- ✅ Docker running successfully
- ✅ GPU accessible from Docker containers
- ✅ Directory structure created
- ✅ Can run `docker-compose up` without errors

**Validation:**
```bash
# These commands should work:
docker --version
nvidia-smi
docker run --rm --gpus all pytorch/pytorch:2.1.0-cuda12.1-cudnn8-runtime nvidia-smi
```

**Time Estimate**: 1 day

---

#### Step 1.2: Set Up Training Stack (Docker Compose)
**Actions:**
1. Create `docker-compose.yml` with services:
   - **Redis**: Message queue for self-play games
   - **PostgreSQL**: Store training metrics, Elo ratings
   - **MinIO**: S3-compatible storage for large model files
   - **Trainer**: GPU-enabled PyTorch container
   - **Workers**: CPU-only self-play workers (5 replicas)
   - **Prometheus**: Metrics collection
   - **Grafana**: Training dashboards

2. Create Docker network for inter-service communication
3. Configure volume mounts for persistent storage
4. Set up environment variables (database passwords, API keys)

**Expected Outcomes:**
- ✅ All services start successfully
- ✅ Services can communicate (Redis, PostgreSQL accessible)
- ✅ GPU visible in trainer container
- ✅ Prometheus collecting metrics
- ✅ Grafana dashboard accessible at `localhost:3000`

**Validation:**
```bash
docker-compose ps  # All services "Up"
docker-compose logs redis  # No errors
docker-compose exec trainer nvidia-smi  # GPU visible
curl localhost:3000  # Grafana responds
```

**Dependencies**: Step 1.1 complete

**Time Estimate**: 2 days

---

#### Step 1.3: Implement Game Rule Validators
**Actions:**
1. Create rule validator for each of the 14 game modes:
   - Classic Chess
   - Heir to the Throne
   - Royal Pawns
   - Snare
   - Entangled
   - Teleport
   - Truce
   - Divergence
   - Kings' Battle
   - Conversion
   - Rebellion
   - Royal Flush
   - Chess 960
   - Progressive Chess

2. For each mode, implement:
   - Legal move generator (all possible moves from a position)
   - Move validator (check if move is legal)
   - Game state evaluator (check for checkmate, stalemate, special wins)
   - Mode-specific rules (phase transitions, special pieces)

3. Write unit tests for each validator:
   - Test basic moves (pawn, knight, bishop, rook, queen, king)
   - Test captures
   - Test special moves (castling, en passant, promotion)
   - Test mode-specific mechanics

**Expected Outcomes:**
- ✅ 14 rule validator classes created
- ✅ Each validator passes all unit tests
- ✅ Can generate legal moves from any position
- ✅ Can detect wins/draws correctly
- ✅ Test coverage >90%

**Validation:**
```bash
python -m pytest ai/trainer/models/game_rules.py -v --cov
# Should show: 14 validators, 500+ tests passed, >90% coverage
```

**Dependencies**: None (can run in parallel with Docker setup)

**Time Estimate**: 3-4 days

---

### Week 2: Neural Network Architecture

#### Step 2.1: Implement Policy-Value Network
**Actions:**
1. Design neural network architecture:
   - **Input**: 18×8×8 tensor (board state encoding)
     - 12 planes: Piece positions (6 types × 2 colors)
     - 6 planes: Metadata (castling rights, game mode, phase, etc.)
   
   - **Backbone**: ResNet-style CNN
     - Initial convolution: 64 filters, 3×3 kernel
     - 4 residual blocks with skip connections
     - Batch normalization after each convolution
   
   - **Policy Head**: Predicts move probabilities
     - Convolution: 32 filters, 1×1 kernel
     - Flatten + Dense layer (1968 output neurons = max possible moves)
     - Softmax activation
   
   - **Value Head**: Predicts win probability
     - Convolution: 32 filters, 1×1 kernel
     - Flatten + Dense(256) + ReLU
     - Dense(1) + Tanh (output range: [-1, 1])

2. Create three model sizes:
   - **Small**: 32 channels, 2 residual blocks (~2M parameters, 5-8MB)
   - **Medium**: 64 channels, 4 residual blocks (~9M parameters, 10-15MB)
   - **Large**: 128 channels, 6 residual blocks (~35M parameters, 15-20MB)

3. Implement in PyTorch with GPU support

**Expected Outcomes:**
- ✅ Neural network class created (`ChessRecastNet`)
- ✅ Can run forward pass (input tensor → policy + value)
- ✅ Model fits in GPU memory (12GB VRAM sufficient for medium/large)
- ✅ Three size variants available
- ✅ Model summary shows correct parameter counts

**Validation:**
```python
# Test forward pass
model = ChessRecastNet(num_channels=64, num_res_blocks=4)  # Medium
input_tensor = torch.randn(32, 18, 8, 8)  # Batch of 32 boards
policy, value = model(input_tensor)
assert policy.shape == (32, 1968)
assert value.shape == (32, 1)
print(f"Parameters: {sum(p.numel() for p in model.parameters()):,}")
```

**Dependencies**: Step 1.1 complete (need GPU)

**Time Estimate**: 3 days

---

#### Step 2.2: Implement Board Encoder
**Actions:**
1. Create `BoardEncoder` class that converts game state to 18×8×8 tensor
2. Implement encoding for each plane:
   - **Planes 0-11**: Piece positions
     - 1.0 if piece present on square, 0.0 otherwise
     - Separate planes for each piece type and color
   
   - **Plane 12**: Castling rights and mode-specific rights
     - Mark squares with special status (1.0 = can castle, 0.0 = cannot)
   
   - **Plane 13**: En passant squares
     - Mark square where en passant capture is legal
   
   - **Plane 14**: Game mode indicator
     - Fill entire plane with normalized mode index (0.0-1.0)
   
   - **Plane 15**: Move counter (for 50-move rule)
     - Normalized value (0.0 = 0 moves, 1.0 = 100+ moves)
   
   - **Plane 16**: Current phase (for multi-phase modes)
     - Kings' Battle phases, Truce periods, etc.
   
   - **Plane 17**: Position repetition count
     - For threefold repetition detection

3. Implement reverse encoder (move index → chess move notation)

**Expected Outcomes:**
- ✅ Can encode any game state to tensor
- ✅ Encoding preserves all relevant information
- ✅ Can decode move indices back to moves
- ✅ Encoding is consistent (same position → same tensor)
- ✅ Validated with unit tests

**Validation:**
```python
# Test encoding/decoding
board = create_starting_position(ModesEnum.CLASSIC)
tensor = BoardEncoder.encode(board, ModesEnum.CLASSIC)
assert tensor.shape == (18, 8, 8)
assert 0.0 <= tensor.min() <= 1.0
assert tensor.max() <= 1.0

# Test specific pieces are encoded correctly
assert tensor[0, 1, 0] == 1.0  # White pawn at a2
assert tensor[11, 7, 4] == 1.0  # Black king at e8
```

**Dependencies**: Step 1.3 complete (need game rules)

**Time Estimate**: 2 days

---

### Week 3: Self-Play Engine

#### Step 3.1: Implement Monte Carlo Tree Search (MCTS)
**Actions:**
1. Implement MCTS algorithm:
   - **Selection**: Traverse tree using UCB1 formula
     - UCB1 = Q(node) + c * sqrt(ln(N(parent)) / N(node))
     - Q = average value, N = visit count, c = exploration constant
   
   - **Expansion**: Add new child node for unexplored move
   
   - **Evaluation**: Use neural network to get:
     - Policy (move probabilities)
     - Value (position evaluation)
   
   - **Backpropagation**: Update all nodes in path with game result

2. Configure MCTS parameters:
   - Simulations per move: 400 (adjustable)
   - Exploration constant (c): 1.4
   - Temperature (randomness): 1.0 for first 30 moves, 0.1 after
   - Dirichlet noise for exploration: α=0.3

3. Optimize performance:
   - Batch neural network evaluations (32 positions at once)
   - Cache tree between moves
   - Parallelize simulations (CPU workers)

**Expected Outcomes:**
- ✅ MCTS can select moves from any position
- ✅ Uses neural network for evaluation
- ✅ Explores promising moves more deeply
- ✅ Runtime: <3 seconds per move (400 simulations)
- ✅ Stronger than pure neural network (no MCTS)

**Validation:**
```python
# Test MCTS selects reasonable moves
board = create_starting_position(ModesEnum.CLASSIC)
model = ChessRecastNet()
mcts = MCTS(model, simulations=400)

move, policy = mcts.search(board)
assert move in get_legal_moves(board)  # Move is legal
assert policy.sum() ≈ 1.0  # Probabilities sum to 1

# Test MCTS finds mate-in-1
board_mate_in_1 = load_test_position("mate_in_1.fen")
move, _ = mcts.search(board_mate_in_1)
assert is_checkmate(board_mate_in_1.make_move(move))  # Found mate
```

**Dependencies**: Steps 2.1, 2.2 complete

**Time Estimate**: 4 days

---

#### Step 3.2: Implement Self-Play Game Generator
**Actions:**
1. Create self-play engine that:
   - Starts from initial position
   - Uses MCTS to select moves for both sides
   - Plays until game ends (checkmate, stalemate, draw)
   - Records game trajectory: [(position, policy, result), ...]
   
2. Add temperature control:
   - High temperature (1.0) for first 30 moves → explore openings
   - Low temperature (0.1) after move 30 → play best moves
   
3. Add game termination conditions:
   - Checkmate / stalemate (mode-specific win conditions)
   - 50-move rule (no captures or pawn moves)
   - Threefold repetition
   - Maximum moves (500 moves = draw)
   
4. Implement game queue system:
   - Self-play workers generate games
   - Push game data to Redis queue
   - Trainer consumes games for training

**Expected Outcomes:**
- ✅ Can generate complete self-play games
- ✅ Games follow legal rules
- ✅ Games terminate correctly (no infinite loops)
- ✅ Game data includes positions, policies, and final result
- ✅ Redis queue successfully transfers games to trainer

**Validation:**
```python
# Generate 10 self-play games
model = ChessRecastNet()
generator = SelfPlayGenerator(model, mcts_simulations=400)

games = []
for i in range(10):
    game = generator.play_game(ModesEnum.CLASSIC)
    games.append(game)
    print(f"Game {i+1}: {len(game.moves)} moves, Result: {game.result}")

# Verify games are valid
assert all(len(g.moves) > 0 for g in games)
assert all(g.result in ['white_wins', 'black_wins', 'draw'] for g in games)
assert all(len(g.positions) == len(g.policies) for g in games)
```

**Dependencies**: Step 3.1 complete

**Time Estimate**: 3 days

---

### Week 4: Training Loop

#### Step 4.1: Implement AlphaZero Training Algorithm
**Actions:**
1. Implement training loop:
   ```
   Initialize neural network with random weights
   
   For generation = 1 to N:
       1. Self-Play Phase (3-4 hours):
          - Generate 10,000 games using current model
          - Store games in replay buffer
          
       2. Training Phase (4-6 hours):
          - Sample mini-batches (2048 games)
          - Compute loss:
              Loss = (z - v)² - π·log(p) + c·||θ||²
              where:
                z = actual game result (-1, 0, +1)
                v = network's value prediction
                π = MCTS policy
                p = network's policy prediction
                c = L2 regularization weight
          - Update weights with SGD/Adam
          - Train for 1000 iterations
          
       3. Evaluation Phase (1-2 hours):
          - Pit new model vs old model (100 games)
          - If new model wins >55%:
              Replace old model with new model
              Save checkpoint
          - Else:
              Discard new model, keep training old model
          
       4. Elo Calculation:
          - Play tournament against previous generations
          - Update Elo rating
          - Target: 900-1200 Elo after 15-20 generations
   ```

2. Implement experience replay:
   - Store last 500,000 positions in circular buffer
   - Sample uniformly for training (prevents overfitting to recent games)
   
3. Add training monitoring:
   - Log loss curves (policy loss, value loss, total loss)
   - Log Elo progression
   - Log games played, win/loss/draw rates
   - Send metrics to Prometheus

**Expected Outcomes:**
- ✅ Training loop runs without errors
- ✅ Loss decreases over time
- ✅ Model improves (beats previous generation)
- ✅ Elo rating increases generation-to-generation
- ✅ Checkpoints saved every generation
- ✅ Can resume training from checkpoint

**Validation:**
```python
# Start training
trainer = AlphaZeroTrainer(
    model=ChessRecastNet(),
    mode=ModesEnum.CLASSIC,
    generations=20,
)

trainer.train()

# After training:
assert trainer.current_generation == 20
assert trainer.final_elo >= 900  # Reached minimum target
assert os.path.exists(f"models/checkpoints/classic/gen_0020.pth")

# Verify model improved
gen_1_model = load_checkpoint("classic/gen_0001.pth")
gen_20_model = load_checkpoint("classic/gen_0020.pth")
win_rate = evaluate_matchup(gen_20_model, gen_1_model, games=100)
assert win_rate >= 0.80  # Gen 20 beats Gen 1 at least 80% of time
```

**Dependencies**: Steps 3.1, 3.2 complete

**Time Estimate**: 5 days (including debugging)

---

#### Step 4.2: Implement Sanity Checks & Validation
**Actions:**
1. Add real-time validation during training:
   - **Illegal Move Detection**: If model suggests illegal move, log warning
   - **Basic Tactics Test**: Test if model finds mate-in-1, captures free pieces
   - **Mode-Specific Rules**: Verify model respects custom mechanics
   
2. Create validation test suite:
   - 100 tactical puzzles (mate-in-1, mate-in-2, forks, pins)
   - 50 mode-specific scenarios (Heir succession, Snare placement, etc.)
   - 30 endgame positions (K+Q vs K, K+R vs K, K+P vs K)
   
3. Run validation every 5 generations:
   - Log puzzle solve rate
   - Compare to baseline (random moves, minimax bot)
   - Stop training if performance degrades

**Expected Outcomes:**
- ✅ Model never suggests illegal moves
- ✅ Solves >70% of mate-in-1 puzzles by generation 10
- ✅ Solves >90% of mate-in-1 puzzles by generation 20
- ✅ Respects mode-specific rules (no illegal Heir succession, etc.)
- ✅ Validation metrics tracked in Grafana dashboard

**Validation:**
```python
# Run sanity checks after training
validator = SanityCheckValidator(mode=ModesEnum.CLASSIC)
model = load_checkpoint("classic/gen_0020.pth")

results = validator.run_all_tests(model)
print(f"Mate-in-1 solve rate: {results['mate_in_1']}%")
print(f"Captures free piece: {results['free_captures']}%")
print(f"Illegal move attempts: {results['illegal_moves']}")

assert results['mate_in_1'] >= 90  # >90% accuracy
assert results['illegal_moves'] == 0  # No illegal moves
```

**Dependencies**: Step 4.1 complete

**Time Estimate**: 2 days

---

### Week 5: First Model Training (Classic Mode)

#### Step 5.1: Train Classic Chess AI
**Actions:**
1. Start full training run for Classic chess:
   - Model size: Medium (64 channels, 4 residual blocks)
   - Target Elo: 900-1000
   - Generations: 20-25
   - Estimated time: 3-4 days on RTX 4080 Mobile
   
2. Monitor training progress:
   - Check Grafana dashboard every 6 hours
   - Verify loss is decreasing
   - Verify Elo is increasing
   - Check GPU utilization (should be 90-100%)
   
3. If training stalls:
   - Adjust learning rate (try 0.001, 0.0001)
   - Increase MCTS simulations (try 600, 800)
   - Add more exploration (increase temperature)

**Expected Outcomes:**
- ✅ Training completes in 3-5 days
- ✅ Final Elo: 900-1000
- ✅ Model checkpoint saved
- ✅ No crashes or errors during training
- ✅ Loss converges (no longer decreasing significantly)

**Validation:**
```bash
# Check final results
python evaluate_elo.py --model models/checkpoints/classic/final.pth

# Expected output:
# Elo Rating: 950 (±30)
# Games Played: 200
# Win Rate vs Random: 98%
# Win Rate vs Minimax(5): 65%
```

**Dependencies**: Steps 4.1, 4.2 complete

**Time Estimate**: 4-5 days (mostly waiting for training)

---

### Weeks 6-8: Train Remaining 13 Modes

#### Step 6.1: Sequential Training for All Modes
**Actions:**
For each of the remaining 13 modes (in priority order):
1. Heir to the Throne
2. Snare
3. Entangled
4. Teleport
5. Royal Pawns
6. Truce
7. Divergence
8. Kings' Battle
9. Conversion
10. Rebellion
11. Royal Flush
12. Chess 960
13. Progressive Chess

**Per Mode:**
1. Configure mode-specific parameters (if needed)
2. Start training (same process as Classic)
3. Monitor for 3-5 days
4. Validate final model:
   - Elo ≥ 900
   - Sanity checks pass
   - Mode-specific rules respected
5. Save checkpoint and move to next mode

**Expected Outcomes:**
- ✅ 14 models total (1 per mode)
- ✅ Each model achieves 900+ Elo
- ✅ All models pass sanity checks
- ✅ Total training time: ~8 weeks (sequential, one at a time)

**Validation:**
```bash
# After all training complete:
for mode in classic heir snare entangled teleport ...; do
    python evaluate_elo.py --mode $mode
done

# All modes should show Elo ≥ 900
```

**Dependencies**: Step 5.1 complete (Classic trained as template)

**Time Estimate**: 6-8 weeks (3-5 days per mode × 13 modes)

---

### Phase 1 Summary

**Deliverables:**
✅ 14 trained PyTorch models (900-1200 Elo each)  
✅ Training infrastructure (Docker Compose stack)  
✅ Monitoring dashboards (Grafana)  
✅ Validation test suite  
✅ Checkpoints saved and versioned  

**Success Criteria:**
✅ Each model reaches 900+ Elo  
✅ Models respect game rules (no illegal moves)  
✅ Training reproducible (can retrain from scratch)  
✅ Infrastructure stable (no crashes during training)  

**Next Phase:**
Export models to TFLite and integrate into Flutter app.

---

## 📱 PHASE 2: Mobile Integration (Weeks 9-12)

### Week 9: Model Export & Optimization

#### Step 9.1: Convert PyTorch Models to TFLite
**Actions:**
1. For each of the 14 trained models:
   - Export PyTorch → ONNX format
   - Convert ONNX → TensorFlow SavedModel
   - Convert TensorFlow → TFLite
   
2. Apply optimization:
   - **INT8 Quantization**: Reduce model size by 4x
     - Original: 40MB (FP32) → 10MB (INT8)
     - Slight accuracy loss (<5% Elo)
   - **Dynamic range quantization**: Balance size vs accuracy
   - Test multiple quantization strategies, pick best
   
3. Validate TFLite models:
   - Run same test positions as PyTorch
   - Verify outputs match (within rounding error)
   - Measure inference time on target devices

**Expected Outcomes:**
- ✅ 14 TFLite models created
- ✅ Model sizes: 5-8MB (small), 10-15MB (medium), 15-20MB (large)
- ✅ Accuracy preserved (Elo loss <5%)
- ✅ Inference time <100ms per position on mid-range phone

**Validation:**
```python
# Test TFLite model matches PyTorch
pytorch_model = load_pytorch_model("classic/final.pth")
tflite_model = load_tflite_model("classic_medium_v1.tflite")

test_positions = load_test_positions(100)
for position in test_positions:
    pytorch_policy, pytorch_value = pytorch_model.predict(position)
    tflite_policy, tflite_value = tflite_model.predict(position)
    
    # Check outputs are similar
    assert np.allclose(pytorch_policy, tflite_policy, atol=0.05)
    assert abs(pytorch_value - tflite_value) < 0.05

print("✅ TFLite model matches PyTorch model")
```

**Dependencies**: Phase 1 complete (all models trained)

**Time Estimate**: 3-4 days

---

### Week 10: Flutter Service Implementation

#### Step 10.1: Create TFLite Model Service
**Actions:**
1. Add dependencies to Flutter project:
   - `tflite_flutter: ^0.10.4`
   - `tflite_flutter_helper: ^0.3.1`
   
2. Create `TFLiteModelService` class:
   - **Initialization**: Load model from assets
   - **GPU Acceleration**: Enable GPU delegate if available
   - **Inference**: Run prediction on board position
   - **Caching**: Keep models in memory (don't reload every time)
   
3. Implement board encoding (Flutter version):
   - Convert `Board` object to Float32List (18×8×8 tensor)
   - Match Python encoding exactly
   
4. Implement move decoding:
   - Convert model output (1968 move probabilities) to list of legal moves
   - Sort moves by probability
   - Return top move or probability distribution

**Expected Outcomes:**
- ✅ Can load TFLite models in Flutter
- ✅ Can run inference (<100ms per move)
- ✅ GPU acceleration works on supported devices
- ✅ Encoding matches Python version (same output for same input)

**Validation:**
```dart
// Test model loading and inference
await TFLiteModelService().initialize(ModesEnum.classic);

final board = Board.fromStartingPosition();
final (moveProbs, winProb) = await TFLiteModelService().evaluate(
  board,
  ModesEnum.classic,
);

expect(moveProbs.length, 1968);
expect(moveProbs.reduce((a, b) => a + b), closeTo(1.0, 0.01));
expect(winProb, inRange(-1.0, 1.0));
print("✅ TFLite inference working in Flutter");
```

**Dependencies**: Step 9.1 complete

**Time Estimate**: 3 days

---

#### Step 10.2: Implement MCTS Engine in Flutter
**Actions:**
1. Port MCTS algorithm to Dart:
   - Same logic as Python version
   - Use TFLite model for evaluation
   - Optimize for mobile (fewer simulations: 50-200)
   
2. Add difficulty levels:
   - **Easy**: 50 MCTS simulations (~500ms)
   - **Medium**: 100 simulations (~1s)
   - **Hard**: 200 simulations (~2s)
   - **Expert**: 400 simulations (~4s)
   
3. Implement move selection:
   - **Deterministic mode**: Always pick highest probability move
   - **Stochastic mode**: Sample from probability distribution
   
4. Add time management:
   - Limit thinking time (configurable)
   - Early exit if one move clearly best

5. **Resource-Efficient Learning Strategy**:
   Since each bot node should be "somewhat stupid initially but learn continuously":
   
   **Initial State**:
   - Ship with **small models** (2-5MB, ~500-700 Elo) in app
   - These are "base bots" - not strong, but understand rules
   - Minimal resources: Fast inference (<100ms), low RAM (<50MB)
   
   **Continuous Learning on Host Device**:
   - When user opts in to "Train AI while I play":
     - Bot observes user games (human vs human, human vs bot)
     - Collects game replays in local database
     - Every 100 games OR when device idle + charging:
       - Run lightweight training (fine-tuning, not full training)
       - Update policy head weights (value head stays frozen)
       - Keep model size constant (no growth)
     - Result: Bot adapts to user's play style over weeks/months
   
   **Learning from GameNet** (P2P network):
   - When connected to GameNet (user consents):
     - Download training data from other users' bots
     - Filter for games matching current Elo range (±200)
     - Run training in background (low priority thread)
     - Gradual improvement: 700 Elo → 900 Elo → 1200 Elo over months
   
   **Resource Constraints**:
   - Training uses <10% CPU (low priority)
   - Only train when battery >50% or charging
   - Pause training if user opens app (UX priority)
   - Delete old training data after use (disk space)
   
   **Validator Role Evolution**:
   - Initially: Bot too weak to be validator (Elo <900)
   - After 3-6 months learning: Reaches 900+ Elo → eligible as validator
   - Can then earn MOTON by validating games
   - Stronger bot = more validator selections = more rewards
   
   **Intelligence Growth Timeline**:
   - **Week 1**: 500-700 Elo (basic understanding)
   - **Month 3**: 900-1000 Elo (can be validator)
   - **Month 6**: 1200-1400 Elo (strong amateur)
   - **Year 1**: 1400-1600 Elo (advanced player)
   - **Year 2+**: 1600-2000 Elo (expert level)
   
   **Key Principle**: "Some level of stupid but with knowledge"
   - Bots aren't pre-trained geniuses (like Stockfish)
   - They start weak and grow with their owner
   - Learning is organic, gradual, resource-efficient
   - Becomes personal AI partner over time

**Expected Outcomes:**
- ✅ MCTS engine works in Flutter
- ✅ Can select moves in <3 seconds (hard difficulty)
- ✅ Plays stronger than pure neural network
- ✅ Difficulty levels feel different to users
- ✅ Bots start weak (~500-700 Elo) and improve gradually
- ✅ On-device learning uses minimal resources (<10% CPU, idle only)
- ✅ Can learn from GameNet without overwhelming device

**Validation:**
```dart
// Test MCTS selects good moves
final model = await TFLiteModelService().initialize(ModesEnum.classic);
final mcts = MCTSEngine(model, simulations: 100);

final board = Board.fromFEN("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq -");
final move = await mcts.selectMove(board);

expect(move, isIn(board.getLegalMoves()));
print("Selected move: ${move.notation}");
```

**Dependencies**: Step 10.1 complete

**Time Estimate**: 4 days

---

### Week 11: UI Integration

#### Step 11.1: Integrate AI into Game UI
**Actions:**
1. Update game controller to support AI moves:
   - When AI turn, call `MCTSEngine.selectMove()`
   - Show "AI thinking..." indicator
   - Animate AI move on board
   
2. Add AI opponent selection screen:
   - Choose difficulty (Easy/Medium/Hard/Expert)
   - Choose AI color (play as white/black)
   - Show estimated AI Elo rating
   
3. Add game analysis features:
   - Show AI evaluation bar (win probability)
   - Suggest best move (hint button)
   - Show move probabilities (debug mode)
   
4. Handle edge cases:
   - AI resigns if position is hopeless (eval < -0.95)
   - Draw offers (if eval ≈ 0.00 for 10+ moves)
   - Timeout handling (if AI takes too long)

**Expected Outcomes:**
- ✅ Can play complete games against AI
- ✅ AI moves are legal and reasonable
- ✅ UI responsive (doesn't freeze during AI thinking)
- ✅ Game analysis features work correctly

**Validation:**
```dart
// Play 10 complete games
for (int i = 0; i < 10; i++) {
  final game = GameSession(
    mode: ModesEnum.classic,
    whitePlayer: HumanPlayer(),
    blackPlayer: AIPlayer(difficulty: Difficulty.medium),
  );
  
  await game.play();
  
  expect(game.isFinished, true);
  expect(game.result, isIn(['white_wins', 'black_wins', 'draw']));
  print("Game $i: ${game.moveCount} moves, ${game.result}");
}
```

**Dependencies**: Steps 10.1, 10.2 complete

**Time Estimate**: 4 days

---

### Week 12: Testing & Polish

#### Step 12.1: End-to-End Testing
**Actions:**
1. Manual testing:
   - Play 20+ games per mode (14 modes × 20 = 280 games)
   - Test all difficulty levels
   - Test on multiple devices (low-end, mid-range, high-end)
   
2. Performance testing:
   - Measure inference time per device
   - Measure memory usage
   - Measure battery impact
   - Test with background apps running
   
3. Edge case testing:
   - Forced updates during AI turn
   - App suspension/resume mid-game
   - Airplane mode (offline play)
   - Low battery mode
   
4. Bug fixing:
   - Fix any crashes
   - Fix illegal moves (if any)
   - Fix UI glitches
   - Optimize slow code paths

**Expected Outcomes:**
- ✅ No crashes during gameplay
- ✅ AI never makes illegal moves
- ✅ Performance acceptable on target devices
- ✅ Games save/resume correctly
- ✅ All edge cases handled gracefully

**Validation:**
```
Run 1000 automated test games across all modes:
- No crashes: ✅
- No illegal moves: ✅
- Average inference time: 75ms
- Memory usage: <300MB
- Battery drain: <5%/hour
```

**Dependencies**: Step 11.1 complete

**Time Estimate**: 5-7 days

---

### Phase 2 Summary

**Deliverables:**
✅ 14 TFLite models deployed in Flutter app  
✅ MCTS engine running on mobile  
✅ Playable AI opponents (4 difficulty levels)  
✅ Game analysis features  
✅ Offline play fully functional  

**Success Criteria:**
✅ Inference <100ms on mid-range phones  
✅ AI plays legal moves 100% of time  
✅ Users can play complete games offline  
✅ No crashes or performance issues  

**Next Phase:**
Build P2P GameNet for distributed training.

---

## 🌐 PHASE 3: P2P GameNet (Weeks 13-18)

### Week 13: GameNet Architecture Design

#### Step 13.1: Design P2P Network Protocol
**Actions:**
1. Define network topology:
   - **Bootstrap Server**: Your home server (initial peer discovery)
   - **Mesh Network**: Direct peer-to-peer connections
   - **No Central Server**: After bootstrapping, fully decentralized
   
2. Design communication protocol:
   - **WebSocket**: Real-time bidirectional communication
   - **Heartbeat**: Every 30 seconds (detect dead peers)
   - **Message Types**:
     - `PEER_DISCOVER`: Find other online peers
     - `TRAINING_REQUEST`: Request training data
     - `TRAINING_RESPONSE`: Send training games
     - `MODEL_SHARE`: Share improved model
     - `BLOCKCHAIN_SYNC`: Sync MOT blockchain state
   
3. Define data structures:
   - `PeerInfo`: {id, publicKey, address, lastSeen, elo, trainingContributions}
   - `TrainingData`: {gameReplays, modelUpdates, timestamp, signature}
   - `ModelMetadata`: {modeId, generation, elo, sdataHash, ownerPublicKey}
   
4. Security considerations:
   - All data signed with private keys (prevent spoofing)
   - Training data validated before use (no poisoning attacks)
   - Rate limiting (prevent spam/DDoS)

**Expected Outcomes:**
- ✅ Network protocol fully specified
- ✅ Message formats documented
- ✅ Security measures defined
- ✅ Can explain architecture to any developer

**Validation:**
Create design document with:
- Network topology diagram
- Message flow diagrams
- Data structure specifications
- Security threat model

**Dependencies**: None (pure planning)

**Time Estimate**: 3 days

---

### Week 14-15: Bootstrap Server Implementation

#### Step 14.1: Implement GameNet WebSocket Server
**Actions:**
1. Create WebSocket server (Go):
   - Listen on port 8765
   - Handle connections from peers
   - Maintain active peer registry
   - Forward messages between peers
   
2. Implement peer discovery:
   - New peer connects → broadcasts `PEER_JOIN` to all
   - Existing peers respond with `PEER_INFO`
   - Server maintains peer list in Redis
   
3. Implement heartbeat system:
   - Clients send heartbeat every 30 seconds
   - Server marks peers as offline after 60 seconds silence
   - Broadcasts `PEER_LEAVE` when peer disconnects
   
4. Add monitoring:
   - Track active peer count
   - Track messages sent/received
   - Log to Prometheus

**Expected Outcomes:**
- ✅ WebSocket server running on bootstrap server
- ✅ Peers can connect and discover each other
- ✅ Heartbeat keeps peer list up-to-date
- ✅ Can handle 1000+ concurrent connections

**Validation:**
```bash
# Start server
docker-compose up gamenet-hub

# Test with WebSocket client
wscat -c ws://localhost:8765

# Send heartbeat
> {"type": "HEARTBEAT", "peerId": "test_peer_1"}

# Server responds with peer list
< {"type": "PEER_LIST", "peers": [...]}
```

**Dependencies**: Step 13.1 complete

**Time Estimate**: 4 days

---

#### Step 14.2: Implement Training Data Exchange
**Actions:**
1. Create training data protocol:
   - Peer requests training data: `TRAINING_REQUEST`
   - Server finds peers with relevant data
   - Peers send data directly (peer-to-peer)
   
2. Implement data validation:
   - Verify game replays are legal (re-run move sequence)
   - Check signatures (authenticate sender)
   - Reject invalid/corrupted data
   
3. Implement storage:
   - Store received training data locally (encrypted)
   - Maintain database of available data per peer
   - Clean up old data (>30 days)
   
4. Add privacy controls:
   - Users opt-in to data sharing
   - Can choose which modes to share
   - Can delete shared data anytime

**Expected Outcomes:**
- ✅ Peers can request training data
- ✅ Data is validated before acceptance
- ✅ Invalid data rejected
- ✅ User privacy respected (opt-in model)

**Validation:**
```
Test training data exchange:
1. Peer A generates 100 training games
2. Peer B requests training data for Classic mode
3. Peer A sends games to Peer B
4. Peer B validates games (all legal moves)
5. Peer B stores games locally
✅ Success: 100 games transferred and validated
```

**Dependencies**: Step 14.1 complete

**Time Estimate**: 5 days

---

### Week 16: Flutter P2P Integration

#### Step 16.1: Implement GameNet Client in Flutter
**Actions:**
1. Create `GameNetService` class:
   - Connect to bootstrap server
   - Send/receive WebSocket messages
   - Maintain peer list
   - Handle disconnections/reconnections
   
2. Implement peer discovery:
   - On app startup, connect to bootstrap server
   - Fetch list of active peers
   - Establish direct connections to nearby peers
   
3. Platform-specific P2P:
   - **Android**: Use Nearby Connections API
   - **iOS**: Use MultipeerConnectivity framework
   - **Fallback**: WebSocket via bootstrap server
   
4. Add UI indicators:
   - Show connection status (online/offline)
   - Show peer count
   - Show training contributions (uploaded/downloaded games)

**Expected Outcomes:**
- ✅ Flutter app connects to GameNet
- ✅ Can discover other peers
- ✅ Connection status visible in UI
- ✅ Handles network changes gracefully (WiFi → cellular)

**Validation:**
```dart
// Test GameNet connection
await GameNetService().connect();

expect(GameNetService().isConnected, true);
expect(GameNetService().peerCount, greaterThan(0));

print("Connected to ${GameNetService().peerCount} peers");
```

**Dependencies**: Steps 14.1, 14.2 complete

**Time Estimate**: 5 days

---

#### Step 16.2: Implement Local Model Storage & Continuous Learning
**Actions:**
1. Replace IPFS with local encrypted storage:
   - Store models in app's local directory
   - Encrypt with AES-256-GCM using user's private key
   - Filenames: `{mode}_{generation}_{sdataHash}.tflite.enc`
   
2. Create `LocalModelStorage` class:
   ```
   Methods:
   - saveModel(modelBytes, userPrivateKey, mode) → sdataHash
   - loadModel(userPrivateKey, mode) → modelBytes
   - shareModelWithPeer(peerId, mode, userPrivateKey) → sends encrypted model
   - receiveModelFromPeer(peerData, userPrivateKey) → validates and stores
   ```
   
3. Implement model versioning:
   - Track generation number
   - Keep last 3 generations (auto-delete old)
   - Tag models with Elo rating
   
4. Add consent-based sharing:
   - User chooses which models to share
   - Can revoke sharing anytime
   - Shared models still encrypted (recipient needs key)

5. **Implement On-Device Continuous Learning**:
   **Goal**: Bots start "somewhat stupid" but learn continuously on user's device
   
   **Learning Engine** (`ContinuousLearningService`):
   ```dart
   class ContinuousLearningService {
     // Resource monitoring
     bool canTrain() {
       return battery > 50% &&
              !appInForeground &&
              cpuUsage < 80% &&
              freeRAM > 1GB;
     }
     
     // Lightweight training
     Future<void> trainFromLocalGames() async {
       if (!canTrain()) return;
       
       // 1. Load recent games (last 100)
       final games = await GameDatabase.getRecentGames(limit: 100);
       
       // 2. Extract training positions
       final trainingData = extractPositions(games);
       
       // 3. Fine-tune policy head only (value head frozen)
       final model = await TFLiteModelService().loadModel();
       await fineTunePolicyHead(model, trainingData, epochs: 3);
       
       // 4. Save updated model
       await LocalModelStorage.saveModel(model, generation: currentGen + 1);
       
       // 5. Test if model improved
       final oldElo = await estimateElo(oldModel);
       final newElo = await estimateElo(newModel);
       
       if (newElo > oldElo) {
         print("✅ Model improved: $oldElo → $newElo");
       } else {
         print("⚠️ Model didn't improve, reverting");
         await LocalModelStorage.revertToLastVersion();
       }
     }
     
     // Learn from GameNet
     Future<void> trainFromNetworkGames() async {
       if (!canTrain()) return;
       
       // 1. Request training data from peers
       final games = await GameNetService.requestTrainingData(
         mode: ModesEnum.classic,
         eloRange: [currentElo - 200, currentElo + 200],
         limit: 500,
       );
       
       // 2. Validate games (check for illegal moves)
       final validGames = games.where((g) => g.isValid()).toList();
       
       // 3. Fine-tune model
       await fineTunePolicyHead(model, validGames, epochs: 5);
       
       // 4. Save and test
       // (same as above)
     }
     
     // Training scheduler
     void scheduleTraining() {
       // Every 100 games OR once per week when idle
       Timer.periodic(Duration(hours: 6), (_) {
         if (localGamesCount >= 100 || daysSinceLastTraining >= 7) {
           if (canTrain()) {
             trainFromLocalGames();
           }
         }
       });
     }
   }
   ```
   
   **Resource Constraints**:
   - Training runs in background isolate (separate thread)
   - Low priority: OS can pause/kill if needed
   - Max CPU: 10% (don't heat up device)
   - Only when battery >50% or charging
   - Pause if user opens app
   - Max training duration: 30 minutes per session
   
   **Progressive Intelligence Growth**:
   - **Initial bot** (shipped with app): 500-700 Elo
     - Understands rules
     - Makes legal moves
     - Some basic tactics
     - Fast inference (~50-100ms)
   
   - **After 100 games** (Week 2-4): 700-800 Elo
     - Adapts to user's opening style
     - Learns common patterns
     - Better move selection
   
   - **After 1000 games** (Month 3): 900-1000 Elo
     - Eligible as validator (can earn MOTON)
     - Recognizes tactical motifs
     - Decent positional play
   
   - **After 5000 games** (Month 6-12): 1200-1400 Elo
     - Strong amateur level
     - Good endgame knowledge
     - Can analyze games
   
   - **After 10000 games** (Year 1-2): 1600-2000 Elo
     - Expert level
     - Deep strategic understanding
     - Personalized to owner's style
   
   **Why This Works**:
   - Start small: Low initial resource cost
   - Learn gradually: Continuous improvement over months
   - Organic growth: Bot becomes personal AI companion
   - Validator incentive: Better bot → more earnings
   - User sees progress: Motivates continued use

**Expected Outcomes:**
- ✅ Models stored locally (not in cloud)
- ✅ Encryption protects user models
- ✅ Bots start weak (~500-700 Elo) and improve gradually
- ✅ On-device learning respects resource constraints
- ✅ Can learn from both local games and GameNet
- ✅ Model intelligence grows organically over months
- ✅ Eventually strong enough to be validator (earn MOTON)
- ✅ Can share models peer-to-peer
- ✅ User controls sharing preferences

**Validation:**
```dart
// Test local storage
final storage = LocalModelStorage();

// Save model
final modelBytes = await File('classic_v1.tflite').readAsBytes();
final sdataHash = await storage.saveModel(
  modelBytes,
  userPrivateKey: myPrivateKey,
  mode: ModesEnum.classic,
);

// Load model
final loadedBytes = await storage.loadModel(
  userPrivateKey: myPrivateKey,
  mode: ModesEnum.classic,
);

expect(loadedBytes, equals(modelBytes));
print("✅ Local storage working");
```

**Dependencies**: Step 16.1 complete

**Time Estimate**: 3 days

---

### Week 17: On-Device Training

#### Step 17.1: Implement Incremental Training
**Actions:**
1. Enable on-device model updates:
   - User plays games → generate training data
   - Periodically (every 50 games), fine-tune model
   - Update only last layers (transfer learning)
   
2. Implement training pipeline:
   - Collect user games (positions, moves, results)
   - Encode as training examples
   - Fine-tune model with small learning rate (0.0001)
   - Validate updated model (play vs old model)
   - If win rate >55%, replace old model
   
3. Add federated learning:
   - Download training data from peers
   - Combine with local data
   - Train collaboratively (everyone's models improve)
   
4. Resource management:
   - Train only when charging + WiFi
   - Limit CPU/battery usage
   - Pause training if user opens app

**Expected Outcomes:**
- ✅ Models improve through user games
- ✅ Training doesn't drain battery
- ✅ Models improve faster with more peers (federated learning)
- ✅ User games stay private (only encrypted aggregates shared)

**Validation:**
```dart
// Test on-device training
final initialModel = await loadModel(ModesEnum.classic);
final initialElo = await evaluateElo(initialModel);

// Simulate 100 user games
final games = await simulateGames(count: 100);
await OnDeviceTrainer().train(games, model: initialModel);

final updatedModel = await loadModel(ModesEnum.classic);
final updatedElo = await evaluateElo(updatedModel);

expect(updatedElo, greaterThan(initialElo));
print("Elo improved: $initialElo → $updatedElo");
```

**Dependencies**: Step 16.2 complete

**Time Estimate**: 7 days (complex feature)

---

### Week 18: Testing & Optimization

#### Step 18.1: P2P Network Testing
**Actions:**
1. Simulate multi-peer network:
   - Run 10-20 Flutter instances (emulators + real devices)
   - Verify all peers discover each other
   - Test training data exchange
   - Test model sharing
   
2. Test failure scenarios:
   - Peer disconnects mid-transfer
   - Network switches (WiFi → cellular)
   - Bootstrap server offline (mesh continues?)
   - Malicious peer sends invalid data
   
3. Performance testing:
   - Measure data transfer speed
   - Measure training time with federated data
   - Measure network overhead (bandwidth usage)
   
4. Optimize:
   - Compress training data (zlib, gzip)
   - Batch messages (reduce overhead)
   - Optimize encryption (use hardware acceleration)

**Expected Outcomes:**
- ✅ Network remains stable with 100+ peers
- ✅ Handles failures gracefully
- ✅ Data transfer efficient (<10MB/day per user)
- ✅ Federated training improves models faster than solo

**Validation:**
```
Multi-peer test results:
- Peers: 20
- Games shared: 2000
- Models exchanged: 40
- Average Elo improvement: +50 (vs solo training: +20)
- Network uptime: 99.8%
- Failed transfers: 2/2000 (0.1%)
✅ P2P network stable and efficient
```

**Dependencies**: Step 17.1 complete

**Time Estimate**: 5 days

---

### Phase 3 Summary

**Deliverables:**
✅ Bootstrap server (WebSocket hub)  
✅ P2P peer discovery and communication  
✅ Training data exchange (peer-to-peer)  
✅ Local encrypted model storage  
✅ On-device incremental training  
✅ Federated learning across peers  

**Success Criteria:**
✅ Network scales to 100+ peers  
✅ Training data shared efficiently  
✅ Models improve through distributed learning  
✅ User privacy maintained (encryption + opt-in)  
✅ No central server dependency after bootstrap  

**Next Phase:**
Integrate MOT blockchain for validation and rewards.

---

## ⛓️ PHASE 4: Blockchain Integration (Weeks 19-26)

**Note**: This phase is detailed in separate document: `BLOCKCHAIN_MOT_IMPLEMENTATION.md`

### High-Level Overview

**Weeks 19-20: Quantum-Proof Cryptography**
- Implement CRYSTALS-Dilithium key generation
- Set up secure key storage (Flutter Secure Storage)
- Test signature/verification performance

**Weeks 21-22: MOT Blockchain Core**
- Implement block structure and validation
- Create transaction system
- Set up genesis block (you as founder)

**Weeks 23-24: sdata & NFT Systems**
- Implement sdata authentication for AI models
- Create private NFT system for game replays
- Integrate with P2P GameNet

**Weeks 25-26: Tokenomics & Rewards**
- Implement MOTON emission schedule
- Create pyramid reward system
- Set up move validation and rewards

**Expected Outcomes:**
✅ MOT blockchain operational  
✅ Training contributions validated on-chain  
✅ MOTON rewards distributed fairly  
✅ sdata proves AI model ownership  
✅ Private NFTs for game replays  

---

## 📊 Overall Project Summary

### Total Timeline: 26 Weeks (6.5 Months)

**Phase 1 (Weeks 1-8)**: Server training → 14 AI models at 900-1200 Elo  
**Phase 2 (Weeks 9-12)**: Mobile deployment → Offline play ready  
**Phase 3 (Weeks 13-18)**: P2P network → Distributed learning active  
**Phase 4 (Weeks 19-26)**: Blockchain → Rewards & validation live  

### Key Success Metrics

| Metric | Target | Validation |
|--------|--------|------------|
| AI Models Trained | 14 (one per mode) | All modes have trained models |
| Server Training Elo | 900-1200 | Tournament validation |
| Mobile Inference Time | <100ms | Tested on mid-range phones |
| Model Size | 5-20MB | Check file sizes |
| Distributed Training | 1200-2000 Elo | Elo improvement after P2P |
| P2P Network Peers | 100+ at launch | Monitor bootstrap server |
| Blockchain TPS | 100 transactions/block | Load testing |
| MOTON Distribution | Fair (time-spent > pyramid) | Economics simulation |

### Risk Mitigation

**Risk**: Training takes longer than expected (>5 days per mode)  
**Mitigation**: Use smaller models (32 channels), reduce generations (15 instead of 20)

**Risk**: Mobile performance too slow (>100ms inference)  
**Mitigation**: More aggressive quantization (INT8), reduce MCTS simulations

**Risk**: P2P network doesn't scale (too slow)  
**Mitigation**: Keep bootstrap server as relay, add CDN for popular models

**Risk**: Blockchain bloat (storage >10GB in first year)  
**Mitigation**: Increase block time (20s instead of 10s), prune old blocks

### Monitoring & Observability

**Training Phase:**
- Grafana dashboards: Loss curves, Elo progression, games/hour
- Prometheus alerts: GPU utilization, training crashes
- Daily Elo tournaments: Validate model improvements

**Mobile Phase:**
- Firebase Analytics: Crash reports, performance metrics
- In-app metrics: Inference time, memory usage, battery drain
- User feedback: Survey Elo estimates vs actual performance

**P2P Phase:**
- Bootstrap server metrics: Peer count, message volume, uptime
- Peer health: Active peers, data shared, network latency
- Training contribution tracking: Games shared per user

**Blockchain Phase:**
- Block explorer: View blocks, transactions, balances
- Network health: Node count, consensus time, fork detection
- Economics dashboard: MOTON supply, distribution, Gini coefficient

---

## 🎓 Knowledge Transfer

### For Future AI Assistants

When you read this document in a future session, you should be able to:

1. **Understand the Architecture**: Why each decision was made
2. **Identify Current Phase**: Match codebase state to roadmap phase
3. **Continue Implementation**: Pick up where previous session left off
4. **Validate Progress**: Use success criteria to verify work
5. **Debug Issues**: Reference expected outcomes to diagnose problems

### Key Files to Check

```
Phase 1 Complete?
- ai/models/checkpoints/ → Contains 14 model directories
- ai/models/tflite/ → Empty (not exported yet)

Phase 2 Complete?
- frontend/assets/models/ → Contains 14 .tflite files
- frontend/lib/services/ai/tflite_model_service.dart → Exists

Phase 3 Complete?
- backend/internal/gamenet/ → Exists
- frontend/lib/services/p2p/gamenet_connection.dart → Exists

Phase 4 Complete?
- backend/internal/blockchain/mot.go → Exists
- frontend/lib/services/blockchain/ → Exists
```

### Common Issues & Solutions

**Issue**: Training loss not decreasing  
**Debug**: Check learning rate (try 0.001, 0.0001, 0.00001), check data (illegal moves?), check GPU (running?)

**Issue**: Model makes illegal moves  
**Debug**: Check board encoding (match Python?), check move decoder, add illegal move filter

**Issue**: Mobile inference too slow  
**Debug**: Profile with Flutter DevTools, enable GPU delegate, reduce model size, cache models

**Issue**: P2P peers not discovering each other  
**Debug**: Check firewall (port 8765 open?), check bootstrap server (running?), check WebSocket connection

**Issue**: Blockchain transactions rejected  
**Debug**: Check signature (private key correct?), check nonce (sequential?), check balance (enough MOTON?)

---

## 🚀 Getting Started

**For an AI assistant reading this document:**

1. **Determine Current Phase**: 
   - Read this document fully
   - Check which files exist in the codebase
   - Match to phase completion criteria
   
2. **Find Next Step**:
   - Locate current phase section
   - Find first uncompleted step
   - Read dependencies (all complete?)
   
3. **Execute Step**:
   - Follow actions listed
   - Validate expected outcomes
   - Mark step complete when criteria met
   
4. **Verify & Continue**:
   - Run validation commands
   - Check success criteria
   - Move to next step

**Example Session Start:**

```
AI Assistant: "I'm reading AI_IMPLEMENTATION_ROADMAP_V2.md..."

Checking Phase 1 completion:
- ai/models/checkpoints/classic/ exists ✅
- ai/models/checkpoints/heir/ exists ✅
- ... (checking all 14 modes)
- All 14 modes trained ✅

Phase 1: COMPLETE

Checking Phase 2 completion:
- frontend/assets/models/classic_medium_v1.tflite NOT FOUND ❌

Phase 2: IN PROGRESS
Next Step: 9.1 - Convert PyTorch Models to TFLite
Dependencies: Phase 1 complete ✅

Beginning Step 9.1...
```

---

## 📝 Document Maintenance

**When to Update This Document:**
- Architecture changes (e.g., switch from IPFS to local storage)
- Timeline changes (e.g., training takes 7 days instead of 4)
- New requirements discovered (e.g., need sanity checks)
- Hardware constraints change (e.g., upgrade to RTX 4090)

**Version History:**
- v1.0: Initial roadmap with IPFS storage
- v2.0: Updated for local storage, RTX 4080 Mobile, sanity checks (this version)

---

**END OF ROADMAP**

Any AI assistant should now be able to implement ChessRecast's AI system by following this document step-by-step. Each phase builds on previous work, and success criteria ensure quality at every stage.
