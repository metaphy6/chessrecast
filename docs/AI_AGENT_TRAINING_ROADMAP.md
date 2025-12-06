# ChessRecast AI Agent Training Roadmap

**Version**: 1.0  
**Last Updated**: December 2025  
**Status**: Strategic Planning & Architecture Design  

---

## Executive Summary

This document provides a comprehensive roadmap for implementing a decentralized, self-learning AI agent system for ChessRecast that runs **on-device** in Flutter clients. Each user's phone becomes their bot, enabling offline gameplay while continuously improving through self-play as users interact with the app.

### Key Design Decisions

After extensive research, we recommend:

1. **Model Format**: **TFLite** (TensorFlow Lite) for Flutter deployment
2. **Architecture**: AlphaZero-style policy-value network with variant-specific heads
3. **Training**: Federated learning + on-device self-play
4. **Backend**: Centralized orchestration, distributed validation
5. **Monitoring**: Real-time performance tracking with automated retraining triggers

---

## Table of Contents

1. [Model Format Decision: TFLite vs ONNX](#1-model-format-decision-tflite-vs-onnx)
2. [System Architecture](#2-system-architecture)
3. [Neural Network Design](#3-neural-network-design)
4. [Training Pipeline](#4-training-pipeline)
5. [On-Device Learning](#5-on-device-learning)
6. [Backend Services](#6-backend-services)
7. [Rule Validation Agents](#7-rule-validation-agents)
8. [Monitoring & Logging](#8-monitoring--logging)
9. [Docker Deployment](#9-docker-deployment)
10. [Implementation Roadmap](#10-implementation-roadmap)
11. [Technical Specifications](#11-technical-specifications)

---

## 1. Model Format Decision: TFLite vs ONNX

### Comparison Matrix

| Feature | TFLite | ONNX Runtime |
|---------|--------|--------------|
| **Flutter Support** | ✅ Excellent (`tflite_flutter`) | ⚠️ Limited (requires FFI bindings) |
| **On-Device Training** | ✅ Native support | ❌ Inference only |
| **Model Size** | ✅ Highly optimized (quantization) | ⚠️ Larger models |
| **Mobile Performance** | ✅ GPU/NPU acceleration | ⚠️ CPU primarily |
| **Cross-Platform** | ✅ iOS, Android, Web | ✅ iOS, Android |
| **Quantization** | ✅ INT8, FP16, dynamic | ✅ INT8, FP16 |
| **Community** | ✅ Large, Google-backed | ✅ Microsoft-backed |
| **On-Device Fine-tuning** | ✅ Transfer learning API | ❌ Not designed for it |

### Decision: **TensorFlow Lite (TFLite)**

**Rationale**:
1. **On-device training is critical** for your use case → TFLite supports transfer learning and model updates on-device
2. **Better Flutter integration** → `tflite_flutter` plugin is mature and well-documented
3. **Smaller model sizes** → TFLite quantization reduces models to 2-4 MB (vs 8-12 MB for ONNX)
4. **Hardware acceleration** → TFLite leverages GPU delegates (Android/iOS) and Core ML (iOS)
5. **Federated learning support** → TensorFlow Federated (TFF) integrates seamlessly with TFLite

**ONNX Limitation**: While ONNX Runtime is excellent for inference, it **does not support on-device training** or model weight updates—a dealbreaker for your "train as you play" requirement.

---

## 2. System Architecture

### 2.1 Hybrid Edge-Cloud Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        FLUTTER CLIENTS                           │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  On-Device AI Agent (TFLite)                             │   │
│  │  ├─ Policy-Value Network (5 MB quantized)                │   │
│  │  ├─ MCTS Engine (Dart/C++)                               │   │
│  │  ├─ Local Game Storage (SQLite)                          │   │
│  │  ├─ Self-Play Worker (Background Isolate)                │   │
│  │  └─ Model Update Service                                 │   │
│  └──────────────────────────────────────────────────────────┘   │
│                           ↕ (Model sync, aggregation)            │
└─────────────────────────────────────────────────────────────────┘
                               ↓
┌─────────────────────────────────────────────────────────────────┐
│                      BACKEND SERVICES (Go)                        │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  Agent Orchestration Service                             │   │
│  │  ├─ Model Registry (PostgreSQL + MinIO)                  │   │
│  │  ├─ Federated Aggregation Server (TensorFlow Federated)  │   │
│  │  ├─ Game Lobby Manager (WebSocket)                       │   │
│  │  └─ Elo Rating System                                    │   │
│  └──────────────────────────────────────────────────────────┘   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  Rule Validation Agents (Go)                             │   │
│  │  ├─ Move Legality Checker                                │   │
│  │  ├─ Game Mode Validator (12 modes)                       │   │
│  │  ├─ Anti-Cheat Detector                                  │   │
│  │  └─ Replay Analyzer                                      │   │
│  └──────────────────────────────────────────────────────────┘   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  Monitoring & Logging (Prometheus + Grafana)             │   │
│  │  ├─ Model Performance Metrics                            │   │
│  │  ├─ Client Health Tracking                               │   │
│  │  ├─ Training Progress Dashboard                          │   │
│  │  └─ Anomaly Detection (Rule violations)                  │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                               ↓
┌─────────────────────────────────────────────────────────────────┐
│                   INFRASTRUCTURE (Docker)                        │
│  ├─ PostgreSQL (game logs, model versions, user data)          │
│  ├─ Redis (session management, real-time state)                │
│  ├─ MinIO (model weights, replays)                             │
│  ├─ Prometheus (metrics collection)                            │
│  ├─ Grafana (dashboards)                                       │
│  └─ Training Cluster (Optional: GPU workers for validation)    │
└─────────────────────────────────────────────────────────────────┘
```

### 2.2 Data Flow

```
User Plays Game → On-Device Agent Plays → Self-Play Training → Model Update
                                               ↓
                                    Local Model Improvement
                                               ↓
                            (Every 100 games or weekly sync)
                                               ↓
                          Upload Model Deltas to Backend
                                               ↓
                         Federated Aggregation Server
                                               ↓
                    Global Model Update (validated & aggregated)
                                               ↓
                      Push Updated Model to All Clients
```

---

## 3. Neural Network Design

### 3.1 AlphaZero-Inspired Architecture

**Base Model**: Policy-Value Network with Shared Backbone

```
Input: 8x8x18 Tensor (Board State)
    ├─ 12 planes: Piece positions (6 types × 2 colors)
    ├─ 2 planes: Castling rights
    ├─ 1 plane: En passant targets
    ├─ 1 plane: 50-move rule counter
    ├─ 1 plane: Game mode indicator
    └─ 1 plane: Move history (repetition)

Shared Backbone:
    ├─ Conv2D (64 filters, 3x3) + BatchNorm + ReLU
    ├─ ResNet Blocks (4 blocks, 64 channels each)
    └─ Output: 8x8x64 Feature Map

Policy Head (Move Prediction):
    ├─ Conv2D (32 filters, 1x1)
    ├─ Flatten
    ├─ Dense (1968 outputs) → All possible moves
    └─ Softmax → Move probabilities

Value Head (Position Evaluation):
    ├─ Conv2D (32 filters, 1x1)
    ├─ Flatten
    ├─ Dense (256) + ReLU
    ├─ Dense (1) + Tanh
    └─ Output: Win probability [-1, 1]

Model Size: ~5 MB (INT8 quantized), ~20 MB (FP32)
```

### 3.2 Variant-Specific Adaptations

For each of the 12 game modes, we use **multi-head architecture**:

- **Shared backbone** learns universal chess concepts
- **Mode-specific heads** learn variant rules (Heir, Truce, Snare, etc.)

```python
# Pseudo-architecture
class MultiModeChessNet:
    backbone = SharedResNetBackbone()
    
    policy_heads = {
        "classic": PolicyHead(),
        "heir": PolicyHead(),
        "truce": PolicyHead(),
        # ... 9 more modes
    }
    
    value_heads = {
        "classic": ValueHead(),
        "heir": ValueHead(),
        # ... 9 more modes
    }
    
    def forward(board_tensor, mode):
        features = backbone(board_tensor)
        policy = policy_heads[mode](features)
        value = value_heads[mode](features)
        return policy, value
```

**Training Strategy**: Transfer learning from Classic → Variants (curriculum learning)

---

## 4. Training Pipeline

### 4.1 Initial Model Training (Server-Side)

**Phase 1: Supervised Pre-training (2-3 weeks)**
1. Collect 50K high-quality games from online databases (Lichess, Chess.com)
2. Train policy network to imitate human moves
3. Train value network to predict game outcomes
4. Target: 45-55% move accuracy on test set

**Phase 2: Self-Play Reinforcement Learning (3-4 weeks)**
1. Run MCTS-guided self-play on GPU cluster (10K games/day)
2. Train on self-play data using PPO (Proximal Policy Optimization)
3. Iterate: play → train → evaluate → next generation
4. Target: 1500-1800 Elo rating per mode

**Phase 3: Variant Fine-Tuning (1-2 weeks per mode)**
1. Load pre-trained Classic model
2. Fine-tune mode-specific heads on variant data
3. Self-play for each mode
4. Deploy to clients

### 4.2 On-Device Training (Continuous)

**Federated Learning Workflow**:

```python
# Client-side (Flutter/Dart with TFLite)
def on_device_training():
    # User plays 10-20 games
    games = collect_local_games(limit=20)
    
    # Self-play training (background isolate)
    for game in games:
        # Extract positions, moves, outcomes
        training_data = extract_training_examples(game)
        
        # Fine-tune local model (transfer learning API)
        model.fit_incremental(
            training_data,
            epochs=1,  # Single pass
            batch_size=32
        )
    
    # Compute model delta (difference from baseline)
    model_delta = compute_delta(model, baseline_model)
    
    # Upload delta to server (compressed)
    if len(local_games) >= 100:  # Threshold
        upload_model_delta(model_delta)

# Server-side (Python with TensorFlow Federated)
def federated_aggregation():
    # Collect deltas from N clients
    client_deltas = fetch_client_updates(num_clients=100)
    
    # Federated averaging (weighted by game count)
    aggregated_model = federated_avg(client_deltas)
    
    # Validate model on held-out test set
    if validate_model(aggregated_model):
        # Push updated global model to all clients
        deploy_global_model(aggregated_model)
```

**Privacy**: Only model weights are shared, never raw game data (complies with GDPR)

---

## 5. On-Device Learning

### 5.1 TFLite Transfer Learning API

```dart
// lib/services/ai/on_device_trainer.dart
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:tflite_flutter_helper/tflite_flutter_helper.dart';

class OnDeviceTrainer {
  late Interpreter _interpreter;
  final String _modelPath = 'assets/models/chess_agent_v1.tflite';
  
  Future<void> initializeModel() async {
    _interpreter = await Interpreter.fromAsset(_modelPath);
  }
  
  /// Fine-tune model on local games
  Future<void> trainOnLocalGames(List<GameReplay> games) async {
    // Extract training examples
    final trainingData = _extractTrainingData(games);
    
    // Incremental training (using TFLite's transfer learning API)
    // Note: This requires a model with trainable layers
    for (var batch in trainingData.batches) {
      // Run inference to get current predictions
      final predictions = _interpreter.run(batch.inputs);
      
      // Compute loss
      final loss = _computeLoss(predictions, batch.labels);
      
      // Backprop & update weights (if supported by TFLite model)
      // Alternative: Send data to backend for training
      await _sendTrainingDataToBackend(batch);
    }
  }
  
  /// Self-play training loop (runs in background isolate)
  Future<void> backgroundSelfPlay(int numGames) async {
    for (int i = 0; i < numGames; i++) {
      // Play game against self using MCTS
      final game = await _playSelfPlayGame();
      
      // Store game for training
      await _storeGameForTraining(game);
      
      // Yield to UI thread
      await Future.delayed(Duration(milliseconds: 100));
    }
  }
  
  Future<GameReplay> _playSelfPlayGame() async {
    // Initialize board
    var board = ChessBoard.initial();
    final moves = <ChessMove>[];
    
    while (!board.gameStatus.isGameOver) {
      // MCTS search (200 simulations)
      final move = await _mctsSearch(board, simulations: 200);
      
      // Apply move
      board = board.executeMove(move);
      moves.add(move);
    }
    
    return GameReplay(moves: moves, outcome: board.gameStatus);
  }
  
  Future<ChessMove> _mctsSearch(ChessBoard board, {required int simulations}) async {
    // Monte Carlo Tree Search implementation
    final root = MCTSNode(board);
    
    for (int i = 0; i < simulations; i++) {
      // Selection
      var node = root.select();
      
      // Expansion
      if (!node.isFullyExpanded) {
        node = node.expand();
      }
      
      // Simulation (using neural net value head)
      final value = await _evaluatePosition(node.board);
      
      // Backpropagation
      node.backpropagate(value);
    }
    
    // Select best move
    return root.bestMove();
  }
  
  Future<double> _evaluatePosition(ChessBoard board) async {
    final inputTensor = _boardToTensor(board);
    final output = _interpreter.run(inputTensor);
    return output['value'][0]; // Value head output
  }
}
```

### 5.2 Background Training (Flutter Isolates)

```dart
// lib/services/ai/background_trainer.dart
import 'dart:isolate';

class BackgroundTrainer {
  Isolate? _trainingIsolate;
  
  /// Start background self-play training
  Future<void> startBackgroundTraining() async {
    _trainingIsolate = await Isolate.spawn(
      _trainingWorker,
      IsolateConfig(
        gamesPerSession: 10,
        trainingInterval: Duration(hours: 1),
      ),
    );
  }
  
  /// Background worker function
  static void _trainingWorker(IsolateConfig config) async {
    final trainer = OnDeviceTrainer();
    await trainer.initializeModel();
    
    while (true) {
      // Play self-play games
      await trainer.backgroundSelfPlay(config.gamesPerSession);
      
      // Wait for next training session
      await Future.delayed(config.trainingInterval);
    }
  }
  
  void stopBackgroundTraining() {
    _trainingIsolate?.kill(priority: Isolate.immediate);
    _trainingIsolate = null;
  }
}
```

---

## 6. Backend Services

### 6.1 Agent Orchestration Service (Go)

```go
// backend/cmd/agent-service/main.go
package main

import (
    "github.com/gin-gonic/gin"
    "chessrecast/internal/agent"
)

type AgentService struct {
    modelRegistry *agent.ModelRegistry
    lobbyManager  *agent.LobbyManager
    aggregator    *agent.FederatedAggregator
}

// Model Registry: Store and version control models
func (s *AgentService) RegisterModel(c *gin.Context) {
    var req agent.ModelUploadRequest
    c.BindJSON(&req)
    
    // Validate model format (TFLite)
    if !s.modelRegistry.ValidateModel(req.ModelData) {
        c.JSON(400, gin.H{"error": "Invalid TFLite model"})
        return
    }
    
    // Store in MinIO
    modelID := s.modelRegistry.StoreModel(req.ModelData, req.Metadata)
    
    c.JSON(201, gin.H{
        "model_id": modelID,
        "version": req.Metadata.Version,
    })
}

// Federated Aggregation: Collect client updates
func (s *AgentService) UploadModelDelta(c *gin.Context) {
    var delta agent.ModelDelta
    c.BindJSON(&delta)
    
    // Validate delta
    if !s.aggregator.ValidateDelta(delta) {
        c.JSON(400, gin.H{"error": "Invalid model delta"})
        return
    }
    
    // Store for aggregation
    s.aggregator.AddClientUpdate(delta)
    
    // Trigger aggregation if threshold met
    if s.aggregator.ReadyForAggregation() {
        go s.aggregator.PerformFederatedAveraging()
    }
    
    c.JSON(200, gin.H{"status": "delta received"})
}

// Game Lobby: Match players or assign bot opponents
func (s *AgentService) CreateGameLobby(c *gin.Context) {
    var req agent.LobbyRequest
    c.BindJSON(&req)
    
    lobby := s.lobbyManager.CreateLobby(req.GameMode, req.PlayerID)
    
    c.JSON(201, gin.H{
        "lobby_id": lobby.ID,
        "websocket_url": lobby.WebSocketURL,
    })
}
```

### 6.2 Model Registry (PostgreSQL Schema)

```sql
-- Store model versions and metadata
CREATE TABLE agent_models (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    version VARCHAR(20) NOT NULL,
    game_mode VARCHAR(50) NOT NULL,
    architecture VARCHAR(100) NOT NULL,
    
    -- Model metrics
    elo_rating INTEGER DEFAULT 1500,
    training_games INTEGER DEFAULT 0,
    win_rate DECIMAL(5,2),
    
    -- Storage
    model_path VARCHAR(500) NOT NULL, -- MinIO object URL
    model_size_mb DECIMAL(8,2),
    quantization VARCHAR(20), -- 'FP32', 'INT8', 'FP16'
    
    -- Metadata
    created_at TIMESTAMP DEFAULT NOW(),
    created_by VARCHAR(100),
    is_active BOOLEAN DEFAULT TRUE,
    
    UNIQUE(version, game_mode)
);

-- Track client training progress
CREATE TABLE client_training_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id VARCHAR(100) NOT NULL,
    model_version VARCHAR(20) NOT NULL,
    
    -- Training data
    games_trained INTEGER NOT NULL,
    training_duration_seconds INTEGER,
    avg_loss DECIMAL(10,6),
    
    -- Device info
    device_type VARCHAR(50), -- 'android', 'ios'
    os_version VARCHAR(20),
    
    timestamp TIMESTAMP DEFAULT NOW()
);

-- Federated aggregation queue
CREATE TABLE model_deltas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id VARCHAR(100) NOT NULL,
    base_model_version VARCHAR(20) NOT NULL,
    
    delta_data BYTEA NOT NULL, -- Compressed model weights diff
    delta_size_kb DECIMAL(10,2),
    num_training_games INTEGER,
    
    uploaded_at TIMESTAMP DEFAULT NOW(),
    aggregated BOOLEAN DEFAULT FALSE,
    aggregated_at TIMESTAMP
);
```

---

## 7. Rule Validation Agents

### 7.1 Move Legality Checker (Go)

```go
// backend/internal/validation/move_validator.go
package validation

type MoveValidator struct {
    engine *engine.ChessEngine
}

// ValidateMove checks if a move is legal according to game rules
func (v *MoveValidator) ValidateMove(gameState *engine.Board, move *engine.Move) ValidationResult {
    // Generate all legal moves for current position
    legalMoves := v.engine.GenerateLegalMoves(gameState)
    
    // Check if proposed move is in legal moves list
    isLegal := contains(legalMoves, move)
    
    if !isLegal {
        return ValidationResult{
            Valid: false,
            Reason: "Move violates game rules",
            RuleViolated: v.identifyRuleViolation(gameState, move),
        }
    }
    
    return ValidationResult{Valid: true}
}

// Game Mode Validator: Enforce mode-specific rules
func (v *MoveValidator) ValidateGameMode(gameState *engine.Board, move *engine.Move) error {
    switch gameState.Mode {
    case engine.Heir:
        return v.validateHeirMode(gameState, move)
    case engine.Truce:
        return v.validateTruceMode(gameState, move)
    case engine.Snare:
        return v.validateSnareMode(gameState, move)
    // ... 9 more modes
    default:
        return v.validateClassicMode(gameState, move)
    }
}

// Example: Truce mode validation
func (v *MoveValidator) validateTruceMode(board *engine.Board, move *engine.Move) error {
    // Check if truce is still active
    if board.TruceActive {
        // Verify no captures during truce
        if move.CapturedPiece != nil {
            return fmt.Errorf("Truce mode: Cannot capture during truce period")
        }
        
        // Check move count limit (3 moves per piece during truce)
        moveCount := board.PieceMoveCounter[move.Piece.Position]
        if moveCount >= 3 {
            return fmt.Errorf("Truce mode: Piece has reached 3-move limit during truce")
        }
    }
    
    return nil
}
```

### 7.2 Anti-Cheat Detector

```go
// backend/internal/validation/anticheat.go
package validation

type AntiCheatDetector struct {
    db *sql.DB
}

// DetectSuspiciousActivity analyzes gameplay patterns
func (d *AntiCheatDetector) DetectSuspiciousActivity(gameID string) []SuspiciousPattern {
    patterns := []SuspiciousPattern{}
    
    // Pattern 1: Impossibly fast moves (< 100ms consistently)
    if avgMoveTime := d.getAverageIMoveTime(gameID); avgMoveTime < 100 {
        patterns = append(patterns, SuspiciousPattern{
            Type: "FAST_MOVES",
            Severity: "HIGH",
            Details: fmt.Sprintf("Avg move time: %dms", avgMoveTime),
        })
    }
    
    // Pattern 2: Perfect play (accuracy > 98% for 50+ moves)
    if accuracy := d.calculateMoveAccuracy(gameID); accuracy > 98.0 {
        patterns = append(patterns, SuspiciousPattern{
            Type: "PERFECT_PLAY",
            Severity: "MEDIUM",
            Details: fmt.Sprintf("Accuracy: %.2f%%", accuracy),
        })
    }
    
    // Pattern 3: Client model modified (hash mismatch)
    if !d.verifyClientModel(gameID) {
        patterns = append(patterns, SuspiciousPattern{
            Type: "MODEL_TAMPERING",
            Severity: "CRITICAL",
            Details: "Client model hash doesn't match server",
        })
    }
    
    return patterns
}

// Verify client model hasn't been modified
func (d *AntiCheatDetector) verifyClientModel(gameID string) bool {
    // Get client's reported model hash
    clientHash := d.getClientModelHash(gameID)
    
    // Get expected hash from registry
    expectedHash := d.getExpectedModelHash(d.getModelVersion(gameID))
    
    return clientHash == expectedHash
}
```

---

## 8. Monitoring & Logging

### 8.1 Prometheus Metrics

```go
// backend/internal/monitoring/metrics.go
package monitoring

import (
    "github.com/prometheus/client_golang/prometheus"
)

var (
    // Model performance metrics
    ModelInferenceLatency = prometheus.NewHistogramVec(
        prometheus.HistogramOpts{
            Name: "chess_agent_inference_latency_ms",
            Help: "Model inference latency in milliseconds",
            Buckets: []float64{10, 50, 100, 200, 500, 1000},
        },
        []string{"model_version", "game_mode"},
    )
    
    ModelAccuracy = prometheus.NewGaugeVec(
        prometheus.GaugeOpts{
            Name: "chess_agent_move_accuracy",
            Help: "Percentage of moves matching expert play",
        },
        []string{"model_version", "game_mode", "elo_bracket"},
    )
    
    // Training metrics
    ClientTrainingGames = prometheus.NewCounterVec(
        prometheus.CounterOpts{
            Name: "chess_agent_training_games_total",
            Help: "Total number of games used for training",
        },
        []string{"client_id", "device_type"},
    )
    
    FederatedAggregations = prometheus.NewCounter(
        prometheus.CounterOpts{
            Name: "chess_agent_federated_aggregations_total",
            Help: "Total number of federated aggregation rounds",
        },
    )
    
    // Rule validation metrics
    RuleViolations = prometheus.NewCounterVec(
        prometheus.CounterOpts{
            Name: "chess_rule_violations_total",
            Help: "Total number of rule violations detected",
        },
        []string{"game_mode", "violation_type"},
    )
    
    // Game lobby metrics
    ActiveLobbies = prometheus.NewGauge(
        prometheus.GaugeOpts{
            Name: "chess_active_lobbies",
            Help: "Number of currently active game lobbies",
        },
    )
)

func init() {
    prometheus.MustRegister(
        ModelInferenceLatency,
        ModelAccuracy,
        ClientTrainingGames,
        FederatedAggregations,
        RuleViolations,
        ActiveLobbies,
    )
}
```

### 8.2 Grafana Dashboards

**Dashboard 1: Model Performance**
- Model inference latency (p50, p95, p99)
- Move accuracy by Elo bracket
- Win rate vs. baseline
- Model size and download time

**Dashboard 2: Training Progress**
- Total training games (global)
- Active training clients
- Federated aggregation frequency
- Model version timeline

**Dashboard 3: Rule Violations**
- Violations per game mode
- Violation types (illegal moves, cheating patterns)
- Top violating clients
- Automatic ban triggers

**Dashboard 4: System Health**
- Active lobbies
- WebSocket connections
- Database query latency
- MinIO storage usage

---

## 9. Docker Deployment

### 9.1 Docker Compose Configuration

```yaml
# docker-compose.yml
version: '3.8'

services:
  # Backend API (Go)
  agent-service:
    build: ./backend
    container_name: chess-agent-service
    ports:
      - "8080:8080"
    environment:
      - DB_HOST=postgres
      - REDIS_HOST=redis
      - MINIO_ENDPOINT=minio:9000
    depends_on:
      - postgres
      - redis
      - minio
    networks:
      - chessnet

  # Rule Validation Service (Go)
  validation-service:
    build: ./backend
    container_name: chess-validation-service
    command: ["./validation-service"]
    ports:
      - "8081:8081"
    environment:
      - DB_HOST=postgres
    depends_on:
      - postgres
    networks:
      - chessnet

  # Federated Aggregation Server (Python + TensorFlow)
  aggregation-server:
    build: ./ml/federated
    container_name: chess-aggregation-server
    ports:
      - "8082:8082"
    environment:
      - MINIO_ENDPOINT=minio:9000
      - DB_HOST=postgres
    volumes:
      - ./ml/models:/models
    depends_on:
      - postgres
      - minio
    networks:
      - chessnet

  # PostgreSQL Database
  postgres:
    image: postgres:15-alpine
    container_name: chess-postgres
    environment:
      POSTGRES_DB: chessrecast
      POSTGRES_USER: chess
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./backend/migrations:/docker-entrypoint-initdb.d
    ports:
      - "5432:5432"
    networks:
      - chessnet

  # Redis (Session Management)
  redis:
    image: redis:7-alpine
    container_name: chess-redis
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
    networks:
      - chessnet

  # MinIO (Model Storage)
  minio:
    image: minio/minio
    container_name: chess-minio
    command: server /data --console-address ":9001"
    environment:
      MINIO_ROOT_USER: ${MINIO_USER}
      MINIO_ROOT_PASSWORD: ${MINIO_PASSWORD}
    ports:
      - "9000:9000"
      - "9001:9001"
    volumes:
      - minio_data:/data
    networks:
      - chessnet

  # Prometheus (Metrics)
  prometheus:
    image: prom/prometheus:latest
    container_name: chess-prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
    ports:
      - "9090:9090"
    volumes:
      - ./monitoring/prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus
    networks:
      - chessnet

  # Grafana (Dashboards)
  grafana:
    image: grafana/grafana:latest
    container_name: chess-grafana
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_PASSWORD}
    volumes:
      - grafana_data:/var/lib/grafana
      - ./monitoring/grafana/dashboards:/etc/grafana/provisioning/dashboards
    depends_on:
      - prometheus
    networks:
      - chessnet

volumes:
  postgres_data:
  redis_data:
  minio_data:
  prometheus_data:
  grafana_data:

networks:
  chessnet:
    driver: bridge
```

### 9.2 Deployment Commands

```bash
# Build and start all services
docker-compose up -d

# View logs
docker-compose logs -f agent-service

# Scale validation service (multiple instances)
docker-compose up -d --scale validation-service=3

# Update specific service
docker-compose build agent-service
docker-compose up -d agent-service

# Stop all services
docker-compose down

# Full reset (WARNING: Deletes data)
docker-compose down -v
```

---

## 10. Implementation Roadmap

### Phase 1: Foundation (Weeks 1-4)

**Week 1-2: Backend Infrastructure**
- [ ] Set up Docker Compose environment
- [ ] Implement PostgreSQL schema
- [ ] Configure MinIO for model storage
- [ ] Create basic Go API endpoints
- [ ] Set up Prometheus + Grafana

**Week 3-4: Neural Network Training**
- [ ] Collect training data (Lichess database)
- [ ] Train baseline Classic mode model
- [ ] Convert model to TFLite format
- [ ] Validate model accuracy (target: 50%+)
- [ ] Deploy to MinIO model registry

### Phase 2: Client Integration (Weeks 5-8)

**Week 5-6: Flutter TFLite Integration**
- [ ] Install `tflite_flutter` plugin
- [ ] Implement model loading service
- [ ] Create inference wrapper (MCTS + neural net)
- [ ] Test offline gameplay
- [ ] Optimize inference latency (<200ms)

**Week 7-8: On-Device Training**
- [ ] Implement background self-play isolate
- [ ] Create local game storage (SQLite)
- [ ] Add model update mechanism
- [ ] Test incremental training
- [ ] Measure battery impact

### Phase 3: Rule Validation (Weeks 9-12)

**Week 9-10: Validation Agents**
- [ ] Implement move legality checker
- [ ] Create game mode validators (12 modes)
- [ ] Add anti-cheat detection
- [ ] Set up real-time validation pipeline

**Week 11-12: Integration Testing**
- [ ] Test all 12 game modes
- [ ] Validate rule enforcement
- [ ] Stress test validation service
- [ ] Tune false positive rates

### Phase 4: Federated Learning (Weeks 13-16)

**Week 13-14: Aggregation Server**
- [ ] Set up TensorFlow Federated server
- [ ] Implement model delta collection
- [ ] Create federated averaging algorithm
- [ ] Test with 10 simulated clients

**Week 15-16: Client Synchronization**
- [ ] Implement model upload from clients
- [ ] Add background sync service
- [ ] Create model versioning system
- [ ] Test global model updates

### Phase 5: Monitoring & Optimization (Weeks 17-20)

**Week 17-18: Observability**
- [ ] Configure Prometheus metrics
- [ ] Create Grafana dashboards
- [ ] Add alerting rules
- [ ] Implement log aggregation

**Week 19-20: Performance Tuning**
- [ ] Optimize model quantization
- [ ] Reduce inference latency
- [ ] Minimize network bandwidth
- [ ] Benchmark on low-end devices

### Phase 6: Variant Training (Weeks 21-32)

**Week 21-32: Train All Game Modes**
- [ ] Heir mode (2 weeks)
- [ ] Truce mode (2 weeks)
- [ ] Snare mode (2 weeks)
- [ ] Other 9 modes (6 weeks)
- [ ] Validate each mode's performance
- [ ] Deploy production models

### Phase 7: Production Launch (Weeks 33-36)

**Week 33-34: Beta Testing**
- [ ] Deploy to 100 beta testers
- [ ] Monitor crash reports
- [ ] Gather user feedback
- [ ] Fix critical bugs

**Week 35-36: Full Launch**
- [ ] Deploy to app stores
- [ ] Monitor server load
- [ ] Scale infrastructure
- [ ] Celebrate! 🎉

---

## 11. Technical Specifications

### 11.1 Model Specifications

| Metric | Value |
|--------|-------|
| **Input Shape** | (1, 8, 8, 18) |
| **Output Shape (Policy)** | (1, 1968) |
| **Output Shape (Value)** | (1, 1) |
| **Parameters** | ~500K (shared) + 50K (per mode) |
| **FP32 Size** | ~20 MB |
| **INT8 Size** | ~5 MB |
| **Inference Time (CPU)** | 150-300ms |
| **Inference Time (GPU)** | 30-80ms |
| **Training Time (100 games)** | 5-10 minutes |

### 11.2 Performance Targets

| Metric | Target | Critical |
|--------|--------|----------|
| **Model Accuracy** | 50-65% | 45% |
| **Elo Rating** | 1500-1800 | 1200 |
| **Inference Latency** | <200ms | <500ms |
| **Battery Impact** | <5% per hour | <10% |
| **Network Usage** | <50 MB per week | <200 MB |
| **Storage** | <100 MB total | <300 MB |

### 11.3 Scalability Targets

| Metric | Year 1 | Year 2 | Year 3 |
|--------|--------|--------|--------|
| **Active Users** | 10K | 100K | 1M |
| **Games/Day** | 50K | 500K | 5M |
| **Training Updates/Week** | 1K | 10K | 100K |
| **Server Cost/Month** | $500 | $2K | $10K |

---

## 12. Risks & Mitigation

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| **On-device training too slow** | High | Medium | Use lighter models, optimize TFLite ops, batch updates |
| **Battery drain** | High | Medium | Limit background training, use energy-efficient inference |
| **Network bandwidth** | Medium | Low | Compress model deltas, sync only on Wi-Fi |
| **Model cheating** | High | Low | Hash verification, server-side validation, replay analysis |
| **Poor model quality** | High | Medium | Extensive testing, staged rollout, fallback to previous version |
| **Federated aggregation fails** | Medium | Low | Distributed backup, Byzantine-robust averaging |
| **Rule violations not detected** | High | Low | Redundant validation, community reporting, manual review |

---

## 13. Success Metrics

### 13.1 Model Quality

- **Move Accuracy**: Target 55%+, Critical 45%+
- **Elo Rating**: Target 1500-1800, Critical 1200+
- **Win Rate vs. Random Bot**: Target 95%+
- **Win Rate vs. Minimax (Depth 4)**: Target 60%+

### 13.2 User Experience

- **Offline Gameplay**: 100% functional without network
- **Response Time**: <200ms per move
- **Crash Rate**: <0.1% of games
- **Battery Impact**: <5% per hour of active play

### 13.3 System Health

- **API Uptime**: 99.9%
- **Validation Accuracy**: 99.99% (false positive rate <0.01%)
- **Model Update Success Rate**: 95%+
- **Client Synchronization**: 90% of clients on latest model within 7 days

---

## 14. Cost Estimation

### 14.1 Infrastructure Costs (Year 1)

| Service | Monthly Cost | Annual Cost |
|---------|--------------|-------------|
| **Compute (Backend APIs)** | $200 | $2,400 |
| **Database (PostgreSQL)** | $50 | $600 |
| **Storage (MinIO)** | $30 | $360 |
| **Monitoring (Grafana Cloud)** | $20 | $240 |
| **GPU Training (Optional)** | $100 | $1,200 |
| **Bandwidth** | $50 | $600 |
| **Total** | **$450** | **$5,400** |

### 14.2 Development Costs

| Phase | Duration | Cost (Freelance) |
|-------|----------|------------------|
| **Backend Development** | 4 weeks | $8,000 |
| **ML Training Pipeline** | 4 weeks | $8,000 |
| **Flutter Integration** | 4 weeks | $8,000 |
| **Testing & QA** | 2 weeks | $4,000 |
| **Total** | **14 weeks** | **$28,000** |

---

## 15. Conclusion

This roadmap provides a comprehensive plan to build a decentralized, self-learning AI agent system for ChessRecast using TFLite for on-device training. Key highlights:

✅ **TFLite Selected** for superior on-device training support  
✅ **AlphaZero Architecture** for strong chess play  
✅ **Federated Learning** for privacy-preserving improvements  
✅ **Rule Validation Agents** for 12 game modes  
✅ **Docker Deployment** for easy local management  
✅ **Comprehensive Monitoring** with Prometheus + Grafana  

**Next Steps**:
1. Review and approve this roadmap
2. Set up development environment (Docker Compose)
3. Begin Phase 1: Backend infrastructure
4. Train baseline Classic mode model
5. Integrate TFLite into Flutter app

**Timeline**: 36 weeks (9 months) from start to production  
**Budget**: ~$35K (development + infrastructure)  
**Team**: 2-3 developers (1 ML, 1 Backend, 1 Flutter)

---

**Document Version**: 1.0  
**Last Updated**: December 2025  
**Status**: Ready for Implementation  
**Approval Required**: Yes ✅
