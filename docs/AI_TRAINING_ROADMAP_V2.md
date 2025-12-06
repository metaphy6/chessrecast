# ChessRecast AI Training Roadmap v2.0
**Self-Learning TFLite Agents with Distributed Training**

---

## 🎯 Vision

Train powerful chess agents (up to 3200+ Elo) using **distributed self-play** within a Docker Compose environment. Agents play against each other over the network, learn from experience, and continuously improve. Models are exported to TFLite and deployed to Flutter app for offline play with adaptive difficulty.

---

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    AI TRAINING CLUSTER (Docker)                  │
│                                                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │
│  │ Self-Play    │  │ Self-Play    │  │ Self-Play    │         │
│  │ Worker #1    │  │ Worker #2    │  │ Worker #N    │ (scale) │
│  │ - MCTS       │  │ - MCTS       │  │ - MCTS       │         │
│  │ - Neural Net │  │ - Neural Net │  │ - Neural Net │         │
│  │ - Generate   │  │ - Generate   │  │ - Generate   │         │
│  │   Games      │  │   Games      │  │   Games      │         │
│  └───────┬──────┘  └───────┬──────┘  └───────┬──────┘         │
│          │                  │                  │                │
│          └──────────────────┴──────────────────┘                │
│                            ↓                                    │
│                  ┌─────────────────────┐                        │
│                  │   Redis Queue       │                        │
│                  │  (Game Replays)     │                        │
│                  └──────────┬──────────┘                        │
│                            ↓                                    │
│                  ┌─────────────────────┐                        │
│                  │  Training Service   │                        │
│                  │  - PyTorch/TF GPU   │                        │
│                  │  - AlphaZero Loop   │                        │
│                  │  - Model Updates    │                        │
│                  └──────────┬──────────┘                        │
│                            ↓                                    │
│                  ┌─────────────────────┐                        │
│                  │   Model Registry    │                        │
│                  │  (Checkpoints)      │                        │
│                  └──────────┬──────────┘                        │
│                            ↓                                    │
│  ┌──────────────────────────────────────────────────────┐      │
│  │           Network Play / Agent Arena                  │      │
│  │  - Game Lobby Service (WebSocket)                    │      │
│  │  - Agent vs Agent matches (cross-container)          │      │
│  │  - Elo rating system                                 │      │
│  │  - Tournament orchestrator (gen_v1 vs gen_v2)        │      │
│  └──────────────────────────────────────────────────────┘      │
│                                                                  │
│  ┌──────────────────────────────────────────────────────┐      │
│  │          Monitoring Stack                             │      │
│  │  - TensorBoard (loss curves, Elo progression)        │      │
│  │  - Prometheus (metrics: games/sec, GPU usage)        │      │
│  │  - Grafana (dashboards)                              │      │
│  │  - WebSocket Metrics API → Flutter app console       │      │
│  └──────────────────────────────────────────────────────┘      │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
                              ↓ (export TFLite)
┌─────────────────────────────────────────────────────────────────┐
│                      FLUTTER APP                                 │
│  ┌──────────────────────────────────────────────────────┐      │
│  │  TFLite Model (5MB/20MB/50MB variants)              │      │
│  │  - Offline inference                                 │      │
│  │  - MCTS + Neural Net                                 │      │
│  │  - Adaptive difficulty (800-3200 Elo)               │      │
│  └──────────────────────────────────────────────────────┘      │
│  ┌──────────────────────────────────────────────────────┐      │
│  │  Multiplayer Features                                │      │
│  │  - Play vs Bot (local TFLite)                       │      │
│  │  - Watch agent vs agent (via WebSocket)             │      │
│  │  - Training progress viewer (live metrics)          │      │
│  └──────────────────────────────────────────────────────┘      │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📁 Project Structure

```
chessrecast/
├── ai/                              # NEW: AI training infrastructure
│   ├── trainer/                     # Model architecture & training
│   │   ├── models/
│   │   │   ├── policy_value_net.py  # ResNet architecture
│   │   │   ├── mcts.py               # Monte Carlo Tree Search
│   │   │   └── alphazero.py          # Training loop
│   │   ├── train.py                  # Main training script
│   │   ├── evaluate.py               # Elo tournament evaluation
│   │   └── requirements.txt
│   │
│   ├── selfplay/                    # Distributed self-play workers
│   │   ├── worker.py                 # Self-play game generator
│   │   ├── game_queue.py             # Redis queue interface
│   │   └── requirements.txt
│   │
│   ├── models/                      # Saved model checkpoints
│   │   ├── checkpoints/              # Training checkpoints
│   │   │   ├── gen_0001.pth
│   │   │   ├── gen_0002.pth
│   │   │   └── ...
│   │   └── tflite/                   # Exported TFLite models
│   │       ├── small_v1.tflite (5MB)
│   │       ├── medium_v1.tflite (20MB)
│   │       └── large_v1.tflite (50MB)
│   │
│   ├── data/                        # Training datasets
│   │   ├── replays/                  # Self-play game replays
│   │   ├── processed/                # Preprocessed training data
│   │   └── validation/               # Test set
│   │
│   ├── network_play/                # Agent arena & game lobby
│   │   ├── lobby_service.py          # WebSocket game lobby
│   │   ├── agent_client.py           # Connect agents to lobby
│   │   ├── elo_rating.py             # Rating system
│   │   └── tournament.py             # Agent tournaments
│   │
│   ├── monitoring/                  # Metrics & visualization
│   │   ├── metrics_collector.py      # Prometheus exporter
│   │   ├── tensorboard_logger.py     # TensorBoard integration
│   │   ├── websocket_api.py          # Stream to Flutter
│   │   └── dashboards/               # Grafana configs
│   │
│   ├── export/                      # Model conversion pipeline
│   │   ├── to_onnx.py                # PyTorch → ONNX
│   │   ├── to_tflite.py              # ONNX → TFLite
│   │   ├── quantize.py               # INT8 quantization
│   │   └── package.py                # Create metadata bundle
│   │
│   ├── validation/                  # Rule checking
│   │   ├── move_validator.py         # Legal move checker
│   │   ├── game_mode_rules.py        # 12 mode validators
│   │   └── replay_analyzer.py        # Detect illegal games
│   │
│   ├── docker/                      # Docker configuration
│   │   ├── Dockerfile.trainer        # GPU trainer image
│   │   ├── Dockerfile.worker         # Self-play worker image
│   │   ├── Dockerfile.lobby          # Network play service
│   │   └── docker-compose.yml        # Full stack
│   │
│   ├── scripts/                     # Utilities
│   │   ├── start_training.sh         # Quick start script
│   │   ├── scale_workers.sh          # Scale self-play workers
│   │   ├── export_model.sh           # Export to TFLite
│   │   └── run_tournament.sh         # Evaluate generations
│   │
│   ├── config/                      # Configuration files
│   │   ├── training_config.yaml      # Hyperparameters
│   │   ├── network_config.yaml       # Lobby settings
│   │   └── export_config.yaml        # Model variants
│   │
│   └── docs/                        # AI-specific docs
│       ├── TRAINING_GUIDE.md         # How to train models
│       ├── ARCHITECTURE.md           # Neural net design
│       ├── SCALING.md                # Distributed training
│       └── DEPLOYMENT.md             # TFLite integration
│
├── backend/                         # Existing Go backend
│   └── internal/
│       └── engine/
│           └── move_generator.go    # Rule validation (reuse)
│
├── frontend/                        # Flutter app
│   └── lib/
│       ├── services/
│       │   └── ai/                   # NEW: TFLite integration
│       │       ├── model_service.dart
│       │       ├── mcts_engine.dart
│       │       ├── bot_difficulty.dart
│       │       └── training_viewer.dart
│       └── ui/
│           └── screens/
│               ├── bot_game_screen.dart
│               └── training_console_screen.dart
│
└── docs/
    └── AI_TRAINING_ROADMAP_V2.md    # This file
```

---

## 🐳 Docker Compose Setup

### `ai/docker/docker-compose.yml`

```yaml
version: '3.8'

services:
  # Redis: Game queue for self-play
  redis:
    image: redis:7-alpine
    container_name: chess-redis
    ports:
      - "6379:6379"
    networks:
      - ai-net

  # PostgreSQL: Game storage & Elo ratings
  postgres:
    image: postgres:15-alpine
    container_name: chess-postgres
    environment:
      POSTGRES_DB: chess_ai
      POSTGRES_USER: trainer
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"
    networks:
      - ai-net

  # Training Service (GPU required)
  trainer:
    build:
      context: ..
      dockerfile: docker/Dockerfile.trainer
    container_name: chess-trainer
    runtime: nvidia  # Requires nvidia-docker
    environment:
      - CUDA_VISIBLE_DEVICES=0
      - REDIS_HOST=redis
      - POSTGRES_HOST=postgres
      - TENSORBOARD_PORT=6006
    volumes:
      - ../models:/app/models
      - ../data:/app/data
      - tensorboard_logs:/app/logs
    ports:
      - "6006:6006"  # TensorBoard
    depends_on:
      - redis
      - postgres
    networks:
      - ai-net

  # Self-Play Workers (Scalable)
  selfplay-worker:
    build:
      context: ..
      dockerfile: docker/Dockerfile.worker
    environment:
      - REDIS_HOST=redis
      - MODEL_PATH=/app/models/checkpoints/latest.pth
      - MCTS_SIMULATIONS=400
    volumes:
      - ../models:/app/models:ro
    depends_on:
      - redis
      - trainer
    networks:
      - ai-net
    deploy:
      replicas: 5  # Scale with: docker-compose up --scale selfplay-worker=10

  # Game Lobby Service (Network Play)
  lobby:
    build:
      context: ..
      dockerfile: docker/Dockerfile.lobby
    container_name: chess-lobby
    environment:
      - POSTGRES_HOST=postgres
      - WEBSOCKET_PORT=8765
    ports:
      - "8765:8765"  # WebSocket
      - "8080:8080"  # HTTP API
    depends_on:
      - postgres
    networks:
      - ai-net

  # Prometheus: Metrics collection
  prometheus:
    image: prom/prometheus:latest
    container_name: chess-prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
    volumes:
      - ../monitoring/prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus
    ports:
      - "9090:9090"
    networks:
      - ai-net

  # Grafana: Dashboards
  grafana:
    image: grafana/grafana:latest
    container_name: chess-grafana
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_PASSWORD}
    volumes:
      - ../monitoring/dashboards:/etc/grafana/provisioning/dashboards
      - grafana_data:/var/lib/grafana
    ports:
      - "3000:3000"
    depends_on:
      - prometheus
    networks:
      - ai-net

  # TensorBoard: Training visualization
  tensorboard:
    image: tensorflow/tensorflow:latest
    container_name: chess-tensorboard
    command: tensorboard --logdir=/logs --host=0.0.0.0
    volumes:
      - tensorboard_logs:/logs
    ports:
      - "6007:6006"
    networks:
      - ai-net

  # Metrics API: Stream to Flutter
  metrics-api:
    build:
      context: ..
      dockerfile: docker/Dockerfile.metrics
    container_name: chess-metrics-api
    environment:
      - PROMETHEUS_HOST=prometheus
      - WEBSOCKET_PORT=8766
    ports:
      - "8766:8766"  # WebSocket for Flutter
    depends_on:
      - prometheus
    networks:
      - ai-net

volumes:
  postgres_data:
  prometheus_data:
  grafana_data:
  tensorboard_logs:

networks:
  ai-net:
    driver: bridge
```

---

## 🚀 Quick Start

### 1. **Setup Environment**

```bash
cd chessrecast/ai
cp config/training_config.example.yaml config/training_config.yaml
# Edit config with your hyperparameters

# Set environment variables
export DB_PASSWORD="secure_password"
export GRAFANA_PASSWORD="admin_password"
```

### 2. **Start Training Cluster**

```bash
# Build and start all services
docker-compose -f docker/docker-compose.yml up -d

# Scale self-play workers to 10
docker-compose -f docker/docker-compose.yml up -d --scale selfplay-worker=10

# Monitor logs
docker-compose -f docker/docker-compose.yml logs -f trainer
```

### 3. **Monitor Training Progress**

- **TensorBoard**: http://localhost:6006 (loss curves, Elo progression)
- **Grafana**: http://localhost:3000 (system metrics, games/sec)
- **Prometheus**: http://localhost:9090 (raw metrics)
- **Flutter Console**: Connect to ws://localhost:8766 (live stream)

### 4. **Export Model to TFLite**

```bash
# After training reaches target Elo
docker exec chess-trainer python /app/export/to_tflite.py \
  --checkpoint models/checkpoints/gen_0050.pth \
  --output models/tflite/medium_v1.tflite \
  --quantize int8

# Copy to Flutter assets
cp ai/models/tflite/medium_v1.tflite frontend/assets/models/
```

---

## 🧠 Training Pipeline Details

### Phase 1: Self-Play Generation

```python
# ai/selfplay/worker.py
class SelfPlayWorker:
    def __init__(self, model_path, mcts_simulations=400):
        self.model = load_model(model_path)
        self.mcts = MCTS(self.model, simulations=mcts_simulations)
        self.queue = RedisQueue('game_replays')
    
    def run(self):
        while True:
            game = self.play_game()
            self.queue.push(game)
    
    def play_game(self):
        board = ChessBoard()
        states, policies, values = [], [], []
        
        while not board.is_game_over():
            # MCTS search
            move, policy = self.mcts.search(board)
            
            # Store training example
            states.append(board.state())
            policies.append(policy)
            
            # Execute move
            board.push(move)
        
        # Game outcome (-1, 0, 1)
        outcome = board.result()
        
        # Assign value to each position
        for i in range(len(states)):
            values.append(outcome if i % 2 == 0 else -outcome)
        
        return {
            'states': states,
            'policies': policies,
            'values': values,
            'game_mode': board.mode,
        }
```

### Phase 2: Training Loop (AlphaZero)

```python
# ai/trainer/train.py
class AlphaZeroTrainer:
    def __init__(self):
        self.model = PolicyValueNet(blocks=10, channels=256)
        self.optimizer = torch.optim.Adam(self.model.parameters())
        self.queue = RedisQueue('game_replays')
        self.replay_buffer = []
    
    def train(self):
        generation = 0
        
        while True:
            # Collect games from self-play workers
            self.collect_games(num_games=1000)
            
            # Train on collected data
            for epoch in range(10):
                loss = self.train_epoch()
                log_metric('train/loss', loss)
            
            # Save checkpoint
            save_model(self.model, f'gen_{generation:04d}.pth')
            
            # Evaluate against previous best
            elo_gain = evaluate_elo(self.model, prev_best)
            log_metric('eval/elo', elo_gain)
            
            # Push updated model to workers
            broadcast_model(self.model)
            
            generation += 1
    
    def train_epoch(self):
        batch = sample(self.replay_buffer, batch_size=256)
        
        states = torch.tensor([s['state'] for s in batch])
        target_policies = torch.tensor([s['policy'] for s in batch])
        target_values = torch.tensor([s['value'] for s in batch])
        
        # Forward pass
        pred_policies, pred_values = self.model(states)
        
        # Compute loss
        policy_loss = cross_entropy(pred_policies, target_policies)
        value_loss = mse_loss(pred_values, target_values)
        total_loss = policy_loss + value_loss
        
        # Backward pass
        self.optimizer.zero_grad()
        total_loss.backward()
        self.optimizer.step()
        
        return total_loss.item()
```

### Phase 3: Network Play (Agent Arena)

```python
# ai/network_play/lobby_service.py
class GameLobby:
    def __init__(self):
        self.agents = {}
        self.matches = []
        self.elo_system = EloRating()
    
    async def on_agent_connect(self, websocket, agent_id):
        self.agents[agent_id] = {
            'ws': websocket,
            'elo': get_elo(agent_id),
            'generation': get_generation(agent_id),
        }
        
        # Match with opponent
        opponent = self.find_opponent(agent_id)
        if opponent:
            await self.start_match(agent_id, opponent)
    
    async def start_match(self, white_id, black_id):
        board = ChessBoard()
        
        while not board.is_game_over():
            current_player = white_id if board.turn else black_id
            
            # Request move from agent
            move = await self.request_move(current_player, board)
            
            # Validate move
            if not validate_move(board, move):
                log_violation(current_player, move)
                return
            
            board.push(move)
        
        # Update Elo ratings
        outcome = board.result()
        self.elo_system.update_ratings(white_id, black_id, outcome)
        
        # Store game
        store_game(white_id, black_id, board.moves, outcome)
```

---

## 📊 Monitoring & Metrics

### TensorBoard Metrics

- **Training**:
  - `train/policy_loss`: Policy network loss
  - `train/value_loss`: Value network loss
  - `train/total_loss`: Combined loss
  - `train/learning_rate`: Current LR

- **Evaluation**:
  - `eval/elo`: Current model Elo rating
  - `eval/elo_gain`: Improvement over previous generation
  - `eval/move_accuracy`: % of moves matching expert play
  - `eval/win_rate`: Win rate vs. baseline

- **Self-Play**:
  - `selfplay/games_per_hour`: Training data generation rate
  - `selfplay/avg_game_length`: Average moves per game
  - `selfplay/mcts_simulations`: MCTS search depth

### Prometheus Metrics

```python
# ai/monitoring/metrics_collector.py
from prometheus_client import Counter, Histogram, Gauge

games_generated = Counter('chess_selfplay_games_total', 'Total games generated')
training_loss = Gauge('chess_training_loss', 'Current training loss')
model_elo = Gauge('chess_model_elo', 'Current model Elo rating')
gpu_utilization = Gauge('chess_gpu_utilization_percent', 'GPU usage')
games_per_second = Gauge('chess_games_per_second', 'Game generation rate')
```

### Grafana Dashboards

1. **Training Overview**
   - Loss curves (real-time)
   - Elo progression timeline
   - Training throughput (games/hour)

2. **System Health**
   - GPU utilization
   - Memory usage
   - CPU load per worker

3. **Agent Performance**
   - Win rates by generation
   - Move accuracy distribution
   - Elo rating leaderboard

4. **Network Play**
   - Active matches
   - Games played per agent
   - Cross-generation matchups

---

## 🎮 Flutter Integration

### 1. Install TFLite Plugin

```yaml
# frontend/pubspec.yaml
dependencies:
  tflite_flutter: ^0.10.0
  tflite_flutter_helper: ^0.3.1
```

### 2. Model Service

```dart
// lib/services/ai/model_service.dart
class AIModelService {
  late Interpreter _interpreter;
  
  Future<void> loadModel(String modelPath) async {
    _interpreter = await Interpreter.fromAsset(modelPath);
  }
  
  Future<(List<double>, double)> predict(List<double> boardState) async {
    // Input: 8x8x18 board representation
    var input = boardState.reshape([1, 8, 8, 18]);
    
    // Output: policy (move probabilities), value (position score)
    var outputPolicy = List.filled(1968, 0.0).reshape([1, 1968]);
    var outputValue = List.filled(1, 0.0).reshape([1, 1]);
    
    _interpreter.runForMultipleInputs(
      [input],
      {0: outputPolicy, 1: outputValue},
    );
    
    return (outputPolicy[0], outputValue[0][0]);
  }
}
```

### 3. MCTS Engine

```dart
// lib/services/ai/mcts_engine.dart
class MCTSEngine {
  final AIModelService model;
  final int simulations;
  
  MCTSEngine(this.model, {this.simulations = 400});
  
  Future<ChessMove> search(ChessBoard board) async {
    var root = MCTSNode(board);
    
    for (int i = 0; i < simulations; i++) {
      var node = root.select();
      var (policy, value) = await model.predict(node.board.state());
      node.expand(policy);
      node.backpropagate(value);
    }
    
    return root.bestMove();
  }
}
```

### 4. Bot Difficulty Manager

```dart
// lib/services/ai/bot_difficulty.dart
class BotDifficulty {
  static const beginner = BotConfig(
    eloTarget: 800,
    mctsSimulations: 10,
    temperature: 1.5,
    modelPath: 'assets/models/small_v1.tflite',
  );
  
  static const intermediate = BotConfig(
    eloTarget: 1500,
    mctsSimulations: 100,
    temperature: 0.8,
    modelPath: 'assets/models/medium_v1.tflite',
  );
  
  static const expert = BotConfig(
    eloTarget: 2500,
    mctsSimulations: 400,
    temperature: 0.3,
    modelPath: 'assets/models/large_v1.tflite',
  );
  
  static const grandmaster = BotConfig(
    eloTarget: 3200,
    mctsSimulations: 800,
    temperature: 0.1,
    modelPath: 'assets/models/large_v1.tflite',
  );
}
```

### 5. Training Progress Viewer

```dart
// lib/services/ai/training_viewer.dart
class TrainingViewer extends StatefulWidget {
  @override
  _TrainingViewerState createState() => _TrainingViewerState();
}

class _TrainingViewerState extends State<TrainingViewer> {
  late WebSocketChannel _channel;
  Map<String, dynamic> _metrics = {};
  
  @override
  void initState() {
    super.initState();
    // Connect to metrics API
    _channel = WebSocketChannel.connect(
      Uri.parse('ws://localhost:8766/metrics/stream'),
    );
    
    _channel.stream.listen((data) {
      setState(() {
        _metrics = jsonDecode(data);
      });
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('AI Training Console')),
      body: Column(
        children: [
          // Elo progression chart
          LineChart(
            data: _metrics['elo_history'] ?? [],
            title: 'Model Elo Over Time',
          ),
          
          // Current metrics
          MetricCard(
            label: 'Current Elo',
            value: _metrics['current_elo']?.toString() ?? '--',
          ),
          MetricCard(
            label: 'Training Loss',
            value: _metrics['train_loss']?.toStringAsFixed(4) ?? '--',
          ),
          MetricCard(
            label: 'Games Generated',
            value: _metrics['total_games']?.toString() ?? '--',
          ),
          MetricCard(
            label: 'Generation',
            value: _metrics['generation']?.toString() ?? '--',
          ),
          
          // Live agent game viewer
          Expanded(
            child: AgentGameViewer(
              gameStream: _channel.stream.map((d) => jsonDecode(d)['live_game']),
            ),
          ),
        ],
      ),
    );
  }
}
```

---

## 📈 Model Variants & Export

### Model Size Trade-offs

| Variant | Size | Elo | Inference (CPU) | Inference (GPU) | Use Case |
|---------|------|-----|-----------------|-----------------|----------|
| **Small** | 5 MB | 1800 | 30ms | 10ms | Casual players, quick games |
| **Medium** | 20 MB | 2600 | 100ms | 30ms | Most players, balanced |
| **Large** | 50 MB | 3200 | 300ms | 80ms | Strong players, analysis |

### Export Pipeline

```bash
# ai/export/to_tflite.py
python export/to_tflite.py \
  --checkpoint models/checkpoints/gen_0100.pth \
  --output models/tflite/medium_v1.tflite \
  --blocks 8 \
  --channels 256 \
  --quantize int8 \
  --metadata '{"elo": 2600, "generation": 100, "training_games": 1000000}'

# Package for Flutter
python export/package.py \
  --model models/tflite/medium_v1.tflite \
  --output frontend/assets/models/medium_v1.bundle
```

---

## 🎯 Success Metrics

### Training Goals

- **Generation 1-10**: Bootstrap from random play → 1000 Elo
- **Generation 11-30**: Tactical play → 1800 Elo
- **Generation 31-60**: Strategic play → 2400 Elo
- **Generation 61-100**: Expert play → 2800 Elo
- **Generation 100+**: Grandmaster → 3200+ Elo

### Performance Targets

- **Training throughput**: 10K+ games/day (with 10 workers)
- **Elo gain per generation**: +50-100 Elo
- **Model accuracy**: 60%+ move accuracy vs. expert games
- **Inference latency**: <200ms on mobile devices
- **Training cost**: <$500/month (GPU hours)

---

## 🔄 Continuous Improvement

### Automated Retraining

```python
# ai/scripts/auto_retrain.py
def check_and_retrain():
    current_elo = get_current_elo()
    
    # Trigger retraining if:
    # 1. New user games available (>10K games)
    # 2. Model performance degraded (Elo drop)
    # 3. Scheduled monthly update
    
    if should_retrain():
        # Start training pipeline
        start_training()
        
        # Wait for completion
        wait_for_training()
        
        # Evaluate new model
        new_elo = evaluate_new_model()
        
        # Deploy if better
        if new_elo > current_elo + 30:
            deploy_to_production()
            notify_flutter_app()
```

---

## 🚀 Implementation Timeline

### Week 1-2: Infrastructure Setup
- ✅ Create `ai/` folder structure
- ✅ Write Dockerfiles and docker-compose.yml
- ✅ Set up Redis, PostgreSQL, Prometheus, Grafana
- ✅ Test container orchestration

### Week 3-4: Self-Play System
- ✅ Implement MCTS algorithm
- ✅ Create self-play worker
- ✅ Build game queue (Redis)
- ✅ Scale testing (10+ workers)

### Week 5-6: Training Pipeline
- ✅ Define neural network architecture
- ✅ Implement AlphaZero training loop
- ✅ Add TensorBoard logging
- ✅ Test on small dataset

### Week 7-8: Network Play
- ✅ Build game lobby service
- ✅ Implement agent-vs-agent matches
- ✅ Add Elo rating system
- ✅ Tournament orchestration

### Week 9-10: Monitoring
- ✅ Prometheus metrics exporter
- ✅ Grafana dashboards
- ✅ WebSocket API for Flutter
- ✅ Real-time metrics streaming

### Week 11-12: Model Export
- ✅ PyTorch → ONNX → TFLite pipeline
- ✅ INT8 quantization
- ✅ Model variants (small/medium/large)
- ✅ Metadata packaging

### Week 13-14: Flutter Integration
- ✅ TFLite plugin setup
- ✅ Model loading service
- ✅ MCTS engine in Dart
- ✅ Bot difficulty selector

### Week 15-16: Multiplayer Features
- ✅ "Play vs Bot" UI
- ✅ Watch agent matches (spectate)
- ✅ Training console screen
- ✅ Live metrics viewer

### Week 17-18: Training Execution
- ✅ Generate initial training data
- ✅ Train for 50-100 generations
- ✅ Monitor Elo progression
- ✅ Validate model quality

### Week 19-20: Testing & Optimization
- ✅ End-to-end testing
- ✅ Performance optimization
- ✅ Model fine-tuning
- ✅ Documentation

---

## 📝 Next Steps

1. **Scaffold `ai/` folder structure** (Task #1)
2. **Create Docker Compose environment** (Task #2)
3. **Implement self-play worker** (Task #3)
4. **Build training pipeline** (Task #4)
5. **Start first training run** (Week 17)

---

**Status**: Ready to implement  
**Estimated Effort**: 20 weeks (5 months)  
**Team Size**: 1-2 developers  
**Budget**: ~$3K (GPU compute + infrastructure)
