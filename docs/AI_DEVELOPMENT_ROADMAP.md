# ChessRecast AI Development Roadmap
**Version**: 1.0  
**Created**: December 11, 2025  
**Status**: Implementation-Ready Technical Specification

---

## 🎯 Executive Summary

This document provides a complete, actionable roadmap for building **self-learning chess AI agents** for ChessRecast's 14 custom game modes. The AI system uses:
- **TensorFlow Lite** models (5-20MB) running on-device in Flutter
- **Self-play reinforcement learning** (no pre-existing datasets)
- **P2P GameNet** for distributed training and model sharing
- **Target Elo**: 900-2000 per game mode
- **On-device learning** while users play (opt-in)

---

## 📋 Table of Contents

1. [AI Model Selection & Architecture](#1-ai-model-selection--architecture)
2. [Training Infrastructure](#2-training-infrastructure)
3. [Flutter Integration (On-Device AI)](#3-flutter-integration-on-device-ai)
4. [P2P GameNet Architecture](#4-p2p-gamenet-architecture)
5. [Self-Learning Mechanism](#5-self-learning-mechanism)
6. [Implementation Roadmap](#6-implementation-roadmap)
7. [Technical Specifications](#7-technical-specifications)

---

## 1. AI Model Selection & Architecture

### 1.1 Model Architecture Decision

After analyzing requirements (mobile deployment, 900-2000 Elo, 14 custom modes, self-learning), the optimal architecture is:

**Selected Architecture: Custom Lightweight Policy-Value Network (AlphaZero-style)**

| Aspect | Decision | Rationale |
|--------|----------|-----------|
| **Base Model** | Custom ResNet-style CNN | Pre-trained models (LLMs) don't exist for custom chess variants |
| **Model Format** | TensorFlow Lite (TFLite) | Best Flutter support, on-device training, GPU acceleration |
| **Model Size** | 5-20 MB (quantized INT8/FP16) | Mobile-friendly, fast inference (<50ms per move) |
| **Architecture Style** | Policy-Value Network | Single model outputs both move probabilities + position evaluation |
| **Training Method** | Self-Play Reinforcement Learning | No datasets exist for custom modes (Heir, Snare, Truce, etc.) |
| **Search Algorithm** | Monte Carlo Tree Search (MCTS) | Proven for chess variants, mobile-compatible |

**Why NOT use pre-trained models from Hugging Face:**
- ❌ No existing models for custom chess variants (Heir, Royal Pawns, Snare, etc.)
- ❌ LLMs (GPT-4, Llama, etc.) are too large (>1GB) and too slow for real-time chess
- ❌ Standard chess engines (Stockfish, Leela) don't understand custom rules
- ✅ Custom training is the ONLY viable path for your unique game modes

### 1.2 Neural Network Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                   INPUT: Board State (8x8x18)                    │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │ 12 planes: Piece positions (6 types × 2 colors)          │  │
│  │  2 planes: Castling/special rights (mode-specific)        │  │
│  │  1 plane:  En passant / move history                      │  │
│  │  1 plane:  Game mode indicator (Classic=0, Heir=1, ...)   │  │
│  │  1 plane:  Move counter (for 50-move rule)                │  │
│  │  1 plane:  Current phase (Kings' Battle, Truce phases)    │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                                ↓
┌─────────────────────────────────────────────────────────────────┐
│                    SHARED BACKBONE (ResNet)                      │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │ Conv2D (64 filters, 3×3) + BatchNorm + ReLU              │  │
│  │                         ↓                                  │  │
│  │ ResNet Block #1 (64 channels)  ───┐                       │  │
│  │ ResNet Block #2 (64 channels)  ───┤ Skip Connections     │  │
│  │ ResNet Block #3 (64 channels)  ───┤                       │  │
│  │ ResNet Block #4 (64 channels)  ───┘                       │  │
│  │                         ↓                                  │  │
│  │ Output: 8×8×64 Feature Map                                │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                                ↓
                    ┌───────────┴───────────┐
                    ↓                       ↓
┌────────────────────────────────┐  ┌────────────────────────────┐
│     POLICY HEAD (Move Pred)    │  │   VALUE HEAD (Eval Score)  │
│  ┌──────────────────────────┐  │  │  ┌──────────────────────┐  │
│  │ Conv2D (32 filters, 1×1) │  │  │  │ Conv2D (32, 1×1)     │  │
│  │         ↓                 │  │  │  │         ↓             │  │
│  │ Flatten                   │  │  │  │ Flatten              │  │
│  │         ↓                 │  │  │  │         ↓             │  │
│  │ Dense(1968) *move types   │  │  │  │ Dense(256) + ReLU    │  │
│  │         ↓                 │  │  │  │         ↓             │  │
│  │ Softmax                   │  │  │  │ Dense(1) + Tanh      │  │
│  │         ↓                 │  │  │  │         ↓             │  │
│  │ Output: Move Probs        │  │  │  │ Output: [-1, 1]      │  │
│  │ (probability for each     │  │  │  │ (-1=lose, +1=win)    │  │
│  │  possible move)           │  │  │  │                       │  │
│  └──────────────────────────┘  │  │  └──────────────────────┘  │
└────────────────────────────────┘  └────────────────────────────┘

* 1968 moves = 64 squares × 73 move types (queen moves + knight moves + 
  underpromotions + special moves like teleport, entangle, etc.)
```

**Model Sizes:**
- **Small** (5-8 MB): 32 filters, 2 ResNet blocks → 900-1200 Elo
- **Medium** (10-15 MB): 64 filters, 4 ResNet blocks → 1200-1600 Elo
- **Large** (15-20 MB): 128 filters, 6 ResNet blocks → 1600-2000 Elo

### 1.3 Multi-Mode Strategy

**Mode-Specific Fine-Tuning:**
- Train **base Classic mode model** first (transfer learning baseline)
- Fine-tune 13 separate heads for each variant mode
- Share backbone weights (universal chess understanding)
- Mode-specific heads learn variant rules (Heir king mechanics, Snare entanglement, etc.)

```python
# Model structure
class ChessRecastModel:
    backbone: SharedResNetBackbone  # Shared across all modes
    
    policy_heads: Dict[GameMode, PolicyHead] = {
        "classic": PolicyHead(),
        "heir": PolicyHead(),        # Learns king-as-regular-piece
        "snare": PolicyHead(),       # Learns knight entangle zones
        "truce": PolicyHead(),       # Learns phase transitions
        # ... 11 more modes
    }
    
    value_heads: Dict[GameMode, ValueHead] = {
        "classic": ValueHead(),
        "heir": ValueHead(),
        # ... etc
    }
```

---

## 2. Training Infrastructure

### 2.1 Training Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                  TRAINING CLUSTER (Docker Compose)              │
│                                                                 │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐           │
│  │ Self-Play    │  │ Self-Play    │  │ Self-Play    │           │
│  │ Worker #1    │  │ Worker #2    │  │ Worker #N    │ (scale)   │
│  │              │  │              │  │              │           │
│  │ - MCTS       │  │ - MCTS       │  │ - MCTS       │           │
│  │ - Neural Net │  │ - Neural Net │  │ - Neural Net │           │
│  │ - Play Games │  │ - Play Games │  │ - Play Games │           │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘           │
│         │                  │                  │                 │
│         └──────────────────┴──────────────────┘                 │
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
│                  │  - PostgreSQL       │                        │
│                  │  - MinIO (S3-like)  │                        │
│                  └──────────┬──────────┘                        │
│                            ↓                                    │
│                  ┌─────────────────────┐                        │
│                  │  Export Pipeline    │                        │
│                  │  PyTorch → TFLite   │                        │
│                  └─────────────────────┘                        │
└─────────────────────────────────────────────────────────────────┘
```

## 3. Flutter Integration (On-Device AI)

### 3.1 TFLite Integration Architecture

```dart
// lib/services/ai/tflite_model_service.dart
import 'package:tflite_flutter/tflite_flutter.dart';

class ChessAIService {
  late Interpreter _interpreter;
  final String modelPath = 'assets/models/chess_medium_v1.tflite';
  
  // Initialize TFLite model
  Future<void> initialize() async {
    _interpreter = await Interpreter.fromAsset(modelPath);
    
    // Enable GPU acceleration if available
    final gpuDelegate = GpuDelegateV2();
    _interpreter.allocateTensors();
  }
  
  // Get AI move suggestion
  Future<ChessMove> getBestMove(
    ChessBoard board,
    GameMode mode,
    int mcts_simulations,
  ) async {
    // Run MCTS with neural network evaluation
    final mcts = MonteCarloTreeSearch(
      evaluator: _evaluatePosition,
      simulations: mcts_simulations,
    );
    
    return await mcts.search(board, mode);
  }
  
  // Neural network evaluation
  Future<(List<double> moveProbabilities, double winProbability)> 
  _evaluatePosition(ChessBoard board, GameMode mode) async {
    // Convert board to input tensor (8×8×18)
    final inputTensor = _boardToTensor(board, mode);
    
    // Run inference
    final outputPolicy = List.filled(1968, 0.0);
    final outputValue = List.filled(1, 0.0);
    
    _interpreter.runForMultipleInputs(
      [inputTensor],
      {0: outputPolicy, 1: outputValue},
    );
    
    return (outputPolicy, outputValue[0]);
  }
  
  Float32List _boardToTensor(ChessBoard board, GameMode mode) {
    final tensor = Float32List(8 * 8 * 18);
    
    // Encode piece positions (12 planes)
    for (int row = 0; row < 8; row++) {
      for (int col = 0; col < 8; col++) {
        final piece = board.getPieceAt(row, col);
        if (piece != null) {
          final planeIndex = _pieceToPlaneIndex(piece);
          tensor[(planeIndex * 64) + (row * 8 + col)] = 1.0;
        }
      }
    }
    
    // Encode game mode (plane 12)
    final modeIndex = mode.index;
    for (int i = 0; i < 64; i++) {
      tensor[(12 * 64) + i] = modeIndex.toDouble() / 14.0;
    }
    
    // Encode castling rights, en passant, move counter, etc.
    // ... (planes 13-17)
    
    return tensor;
  }
}
```

### 3.2 MCTS Implementation

```dart
// lib/services/ai/mcts_engine.dart
class MonteCarloTreeSearch {
  final Function evaluator;
  final int simulations;
  
  MonteCarloTreeSearch({
    required this.evaluator,
    required this.simulations,
  });
  
  Future<ChessMove> search(ChessBoard board, GameMode mode) async {
    final root = MCTSNode(board: board, mode: mode);
    
    // Run simulations
    for (int i = 0; i < simulations; i++) {
      // Selection: traverse tree using UCB1
      MCTSNode node = root;
      while (node.isFullyExpanded && !node.isTerminal) {
        node = node.selectChildUCB();
      }
      
      // Expansion: add new child node
      if (!node.isTerminal && !node.isFullyExpanded) {
        node = node.expand();
      }
      
      // Evaluation: neural network prediction
      final (moveProbabilities, winProbability) = 
        await evaluator(node.board, mode);
      
      // Backpropagation: update visit counts and values
      node.backpropagate(winProbability);
    }
    
    // Select best move (highest visit count)
    return root.getMostVisitedMove();
  }
}

class MCTSNode {
  final ChessBoard board;
  final GameMode mode;
  MCTSNode? parent;
  List<MCTSNode> children = [];
  
  int visitCount = 0;
  double totalValue = 0.0;
  
  // UCB1 (Upper Confidence Bound) selection
  MCTSNode selectChildUCB() {
    return children.reduce((a, b) {
      final ucbA = a.getUCB(parent: this);
      final ucbB = b.getUCB(parent: this);
      return ucbA > ucbB ? a : b;
    });
  }
  
  double getUCB({required MCTSNode parent}) {
    if (visitCount == 0) return double.infinity;
    
    final exploitation = totalValue / visitCount;
    final exploration = sqrt(2 * log(parent.visitCount) / visitCount);
    
    return exploitation + exploration;
  }
  
  void backpropagate(double value) {
    visitCount++;
    totalValue += value;
    if (parent != null) {
      parent!.backpropagate(-value);  // Flip value for opponent
    }
  }
}
```

### 3.3 Difficulty Levels (900-2000 Elo)

```dart
// Map difficulty to MCTS simulations
class BotDifficulty {
  static int getSimulations(int eloRating) {
    if (eloRating < 1000) return 50;      // ~900 Elo: 0.5s think time
    if (eloRating < 1200) return 100;     // ~1100 Elo: 1s
    if (eloRating < 1400) return 200;     // ~1300 Elo: 2s
    if (eloRating < 1600) return 400;     // ~1500 Elo: 4s
    if (eloRating < 1800) return 800;     // ~1700 Elo: 8s
    return 1600;                          // ~2000 Elo: 16s
  }
  
  // User-facing difficulty selector
  static int getDifficultyLevel(int eloRating) {
    return ((eloRating - 900) / 110).round().clamp(1, 10);
  }
}
```

---

## 4. P2P GameNet Architecture

### 4.1 GameNet Overview

**GameNet** is a peer-to-peer network where:
- Users' devices share AI training data and model improvements
- Each user stores their AI model locally (encrypted with their private key)
- Models can be optionally shared with other users (consent-based)
- Training only happens when connected to GameNet (incentivized)
- Your home server acts as initial bootstrap node
```
┌─────────────────────────────────────────────────────────────────┐
│                         GAMENET (P2P Layer)                      │
│                                                                  │
│  ┌──────────┐      ┌──────────┐      ┌──────────┐             │
│  │ User A   │◄────►│ User B   │◄────►│ User C   │             │
│  │ (Android)│      │ (iOS)    │      │ (Desktop)│             │
│  │ Local AI │      │ Local AI │      │ Local AI │             │
│  └────┬─────┘      └────┬─────┘      └────┬─────┘             │
│       │                 │                 │                    │
│       │  ┌──────────────┴─────────────┐   │                    │
│       └─►│   Your Bootstrap Server    │◄──┘                    │
│          │   (Home Server + Router)   │                        │
│          │   - Peer discovery         │                        │
│          │   - Match coordinator      │                        │
│          │   - Training data relay    │                        │
│          └────────────┬───────────────┘                        │
│                       ↕                                         │
│          ┌─────────────────────────────┐                        │
│          │  MOT Blockchain (Lightweight)│                       │
│          │  - Auth tokens (sdata)      │                       │
│          │  - Move validation proofs   │                       │
│          │  - Reward distribution      │                       │
│          │  - NFT registry             │                       │
│          └─────────────────────────────┘                        │
### 4.2 Model Storage: Local + Optional Sharing

**Storage Strategy:**
- Each user's AI model is stored **locally on their device** (encrypted)
- Models are NOT distributed across the network by default
- Users can **optionally share** their trained models with others (consent-based)
- Model sharing happens via **direct peer-to-peer transfer** (not distributed storage)

```dart
// lib/services/ai/local_model_storage.dart
import 'package:cryptography/cryptography.dart';
import 'package:path_provider/path_provider.dart';

class LocalModelStorage {
  final AesGcm encryption = AesGcm.with256bits();
  
  /// Save user's AI model locally (encrypted)
  Future<void> saveModel(
    Uint8List modelBytes,
    String userPrivateKey,
    ModesEnum mode,
  ) async {
    // Step 1: Encrypt model with user's private key
    final secretKey = await _deriveKey(userPrivateKey);
    final encryptedBox = await encryption.encrypt(
      modelBytes,
      secretKey: secretKey,
    );
    
    // Step 2: Save to local storage
    final dir = await getApplicationDocumentsDirectory();
    final modelPath = '${dir.path}/models/${mode.name}_encrypted.bin';
    final file = File(modelPath);
    await file.create(recursive: true);
    
    // Save encrypted data + nonce
    final combined = Uint8List.fromList([
      ...encryptedBox.nonce,
      ...encryptedBox.cipherText,
    ]);
    await file.writeAsBytes(combined);
    
    print('✅ Model saved locally (encrypted): $modelPath');
  }
  
  /// Load user's AI model from local storage
  Future<Uint8List?> loadModel(
    String userPrivateKey,
    ModesEnum mode,
  ) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final modelPath = '${dir.path}/models/${mode.name}_encrypted.bin';
      final file = File(modelPath);
      
      if (!await file.exists()) {
        return null; // No local model yet
      }
      
      // Read encrypted data
      final combined = await file.readAsBytes();
      final nonce = combined.sublist(0, 12);
      final cipherText = combined.sublist(12);
      
      // Decrypt with user's key
      final secretKey = await _deriveKey(userPrivateKey);
      final decrypted = await encryption.decrypt(
        SecretBox(cipherText, nonce: nonce),
        secretKey: secretKey,
      );
      
      return Uint8List.fromList(decrypted);
    } catch (e) {
      print('❌ Failed to load local model: $e');
      return null;
    }
  }
  
  /// Share model with another user (direct P2P transfer)
  Future<void> shareModelWithPeer(
    String peerId,
    ModesEnum mode,
    String userPrivateKey,
  ) async {
    // Step 1: Load and decrypt model
    final modelBytes = await loadModel(userPrivateKey, mode);
    if (modelBytes == null) return;
    
    // Step 2: Send directly to peer via WebSocket
    await GameNetConnection().sendModelToPeer(peerId, modelBytes);
    
    print('✅ Model shared with peer: $peerId');
  }
  
  Future<SecretKey> _deriveKey(String userPrivateKey) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: 100000,
      bits: 256,
    );
    
    return await pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(userPrivateKey)),
      nonce: utf8.encode('chessrecast_salt'),
    );
  }
}
```   nonce: fixedSalt,  // User-specific salt
    );
  }
}
```

### 4.3 P2P Heartbeat & Connection Management

**Challenge:** Keep users connected to GameNet to enable training

**Solution:** WebSocket heartbeat + peer discovery

```dart
// lib/services/p2p/gamenet_connection.dart
class GameNetConnection {
  WebSocketChannel? _channel;
  Timer? _heartbeatTimer;
  bool isConnected = false;
  
  // Connect to GameNet hub
  Future<void> connect(String userPublicKey) async {
    final url = 'wss://gamenet.chessrecast.com/ws?user=$userPublicKey';
    _channel = WebSocketChannel.connect(Uri.parse(url));
    
    // Listen for messages
    _channel!.stream.listen(
      _handleMessage,
      onDone: _handleDisconnect,
      onError: _handleError,
    );
    
    // Start heartbeat (every 30 seconds)
    _heartbeatTimer = Timer.periodic(
      Duration(seconds: 30),
      (_) => _sendHeartbeat(),
    );
    
    isConnected = true;
  }
  
  void _sendHeartbeat() {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode({
        'type': 'heartbeat',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'training_progress': _getTrainingProgress(),
      }));
    }
  }
  
  void _handleMessage(dynamic message) {
    final data = jsonDecode(message);
    
    switch (data['type']) {
      case 'training_request':
        // Another user wants to play against your bot
        _handleTrainingRequest(data);
        break;
      case 'model_update':
        // New model version available
        _handleModelUpdate(data);
        break;
      case 'reward':
        // You earned MOTon rewards
        _handleReward(data);
        break;
    }
  }
  
  Map<String, dynamic> _getTrainingProgress() {
    return {
      'games_played': _gamesPlayed,
      'hours_connected': _hoursConnected,
      'elo_rating': _currentElo,
      'model_version': _modelVersion,
    };
  }
  
  void disconnect() {
    _heartbeatTimer?.cancel();
    _channel?.sink.close();
    isConnected = false;
  }
}
```

### 4.4 Peer Discovery (Platform-Specific APIs)

```dart
// lib/services/p2p/peer_discovery.dart
import 'package:flutter/services.dart';

class PeerDiscovery {
  static const platform = MethodChannel('com.chessrecast/p2p');
  
  // Discover nearby peers (Android: Nearby Connections, iOS: MultipeerConnectivity)
  Future<List<Peer>> discoverNearbyPeers() async {
    if (Platform.isAndroid) {
      return await _discoverAndroid();
    } else if (Platform.isIOS) {
      return await _discoverIOS();
    } else {
      // Desktop: fallback to WebSocket discovery
      return await _discoverWebSocket();
    }
  }
  
  Future<List<Peer>> _discoverAndroid() async {
    // Call native Android Nearby Connections API
    final peers = await platform.invokeMethod('discoverNearby', {
      'serviceId': 'com.chessrecast.gamenet',
      'strategy': 'P2P_CLUSTER',  // WiFi Direct + Bluetooth
    });
    
    return (peers as List).map((p) => Peer.fromJson(p)).toList();
  }
  
  Future<List<Peer>> _discoverIOS() async {
    // Call native iOS MultipeerConnectivity framework
    final peers = await platform.invokeMethod('discoverMultipeer', {
      'serviceType': 'chessrecast-ai',
      'peerID': Get.find<UserController>().userID,
    });
    
    return (peers as List).map((p) => Peer.fromJson(p)).toList();
  }
}
```

---

## 5. Self-Learning Mechanism

### 5.1 On-Device Training Flow

```
User Plays Game → Game Data Collected → Model Fine-Tuning (Optional)
                                               ↓
                                      Upload to GameNet
                                               ↓
                                    Federated Aggregation
                                               ↓
                                    Global Model Update
                                               ↓
                                  Push to All Connected Users
```

### 5.2 Training While Playing

```dart
// lib/services/ai/online_training_service.dart
class OnlineTrainingService {
  final GameNetConnection gamenet;
  final ModelStorageService storage;
  final List<GameReplay> _trainingQueue = [];
  
  // Collect game data for training
  Future<void> onGameFinished(GameReplay game) async {
    // Step 1: Store game locally
    _trainingQueue.add(game);
    
    // Step 2: If connected to GameNet, upload training data
    if (gamenet.isConnected && _trainingQueue.length >= 10) {
      await _uploadTrainingData();
    }
    
    // Step 3: Trigger on-device fine-tuning (optional, every 50 games)
    if (_trainingQueue.length >= 50) {
      await _fineTuneLocalModel();
    }
  }
  
  Future<void> _uploadTrainingData() async {
    final batch = _trainingQueue.take(10).toList();
    
    // Extract positions and outcomes
    final trainingExamples = [];
    for (final game in batch) {
      for (final position in game.positions) {
        trainingExamples.add({
          'board_fen': position.fen,
          'move': position.move,
          'outcome': game.result,  // +1 (win), 0 (draw), -1 (loss)
        });
      }
    }
    
    // Upload to GameNet (encrypted)
    await gamenet.sendTrainingData(trainingExamples);
    
    // Clear uploaded games
    _trainingQueue.removeRange(0, 10);
  }
  
  Future<void> _fineTuneLocalModel() async {
    // Note: TFLite doesn't support full training on mobile
    // Instead, we collect data and send to server for retraining
    // Server returns updated model which we download
    
    print("📊 Collected 50 games, requesting model update...");
    
    final response = await gamenet.requestModelUpdate(
      games: _trainingQueue,
      currentModelVersion: _currentModelVersion,
    );
    
    if (response['new_model_available']) {
      print("✅ New model available, downloading...");
      final newModel = await storage.downloadModel(
        response['model_cid'],
        userPrivateKey,
      );
      
      // Load new model
      await _loadModel(newModel);
      _currentModelVersion = response['model_version'];
    }
  }
}
```

### 5.3 Federated Learning (Privacy-Preserving)

```python
# backend/ai/federated/aggregator.py
class FederatedAggregator:
    """
    Aggregates model updates from multiple users without seeing raw game data
    """
    
    def aggregate_updates(self, client_updates: List[ModelDelta]) -> Model:
        """
        Federated Averaging (FedAvg) algorithm
        """
        # Step 1: Collect model deltas from N clients
        # Each client sends: (model_weights_diff, num_games_played)
        
        total_games = sum(update.num_games for update in client_updates)
        
        # Step 2: Weighted average of model updates
        aggregated_weights = {}
        for layer_name in client_updates[0].weights.keys():
            weighted_sum = np.zeros_like(client_updates[0].weights[layer_name])
            
            for update in client_updates:
                weight = update.num_games / total_games
                weighted_sum += weight * update.weights[layer_name]
### Phase 1: Foundation (Weeks 1-4)

**Goal:** Basic AI working in Flutter (using your RTX 4080 Mobile)

| Week | Task | Deliverable |
|------|------|-------------|
| 1 | Set up training on your laptop (Docker + GPU) | Self-play workers running on RTX 4080 |
| 2 | Implement neural network architecture (PyTorch) | Model training for Classic mode |
| 3 | Train initial Classic mode model (900-1200 Elo) | First TFLite model (5-8MB) |
| 4 | Integrate TFLite in Flutter + MCTS | Bot vs Human gameplay working |

**Success Criteria:**
- ✅ User can play against bot in Classic mode
- ✅ Bot plays at 900-1000 Elo level (initial)
- ✅ Move response time < 2 seconds
- ✅ Training logging shows AI improvement
- ✅ Sanity checks: Bot doesn't make illegal moves, understands basic tactics
## 6. Implementation Roadmap
### Phase 2: Multi-Mode Training (Weeks 5-8)

**Goal:** Train all 14 game modes (sequentially on your GPU)

| Week | Task | Deliverable |
|------|------|-------------|
| 5 | Train 3 modes: Heir, Royal Pawns, Diamonds | 3 mode models (900-1000 Elo) |
| 6 | Train 4 modes: Kings' Battle, Truce, Teleport, Other Side | 4 mode models |
| 7 | Train 4 modes: Snare, Save Queen, Save King, Friendly Fire | 4 mode models |
| 8 | Train remaining 3 modes + validation | All 14 modes complete |

**Success Criteria:**
- ✅ All 14 modes have 900-1200 Elo baseline bots
- ✅ Models exported to TFLite (5-12MB each)
- ✅ Flutter app can switch between modes
- ✅ Training logs show consistent improvement per mode
- ✅ Sanity checks pass for all mode-specific rules mode
- ✅ Bot plays at 900-1200 Elo level
- ✅ Move response time < 2 seconds

---

### Phase 2: Multi-Mode Training (Weeks 5-10)

**Goal:** Train all 14 game modes

| Week | Task | Deliverable |
|------|------|-------------|
| 5-6 | Train Heir, Royal Pawns, Diamonds modes | 3 mode models |
| 7-8 | Train Kings' Battle, Truce, Teleport, Other Side | 4 mode models |
| 9-10 | Train Snare, Save the Queen, Save the King, Friendly Fire | 4 mode models |

**Success Criteria:**
- ✅ All 14 modes have 900-1600 Elo bots
- ✅ Models exported to TFLite (10-15MB each)
- ✅ Flutter app can switch between modes

---

### Phase 3: P2P GameNet (Weeks 11-14)

**Goal:** Enable distributed training network

| Week | Task | Deliverable |
|------|------|-------------|
| 11 | IPFS integration + model encryption | Model upload/download working |
| 12 | WebSocket heartbeat + peer discovery | GameNet connection stable |
| 13 | On-device training data collection | Games uploaded to GameNet |
| 14 | Federated aggregation backend | Model updates pushed to users |

**Success Criteria:**
- ✅ Users can connect to GameNet
- ✅ Models stored privately in IPFS
- ✅ Training data collected and aggregated

---

### Phase 4: Self-Learning & Optimization (Weeks 15-16)

**Goal:** Enable continuous improvement

| Week | Task | Deliverable |
|------|------|-------------|
| 15 | Implement model update pipeline | Users receive improved models |
| 16 | Optimize model sizes (INT8 quantization) | Models reduced to 5-8MB |

**Success Criteria:**
- ✅ Models improve over time (Elo increases)
- ✅ User AI improves through gameplay
- ✅ Models optimized for mobile performance

---

## 7. Technical Specifications

### 7.1 Performance Requirements

| Metric | Target | Measurement |
|--------|--------|-------------|
| Move response time | < 2 seconds | 50th percentile |
| Move response time (max) | < 5 seconds | 95th percentile |
| Memory usage | < 200 MB | During gameplay |
| Model size | 5-20 MB | Compressed TFLite |
| Elo rating | 900-2000 | Per game mode |
| Inference time | < 50ms | Neural network only (no MCTS) |

### 7.2 Model Quantization

```python
# Export model to TFLite with quantization
import tensorflow as tf

def export_to_tflite(pytorch_model, output_path):
    # Step 1: Convert PyTorch → ONNX → TensorFlow
    onnx_model = convert_to_onnx(pytorch_model)
    tf_model = onnx_to_tf(onnx_model)
    
    # Step 2: Quantize to INT8 (reduces size by 4x)
    converter = tf.lite.TFLiteConverter.from_keras_model(tf_model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    converter.target_spec.supported_types = [tf.int8]
    
    # Step 3: Export
    tflite_model = converter.convert()
    with open(output_path, 'wb') as f:
        f.write(tflite_model)
    
    print(f"✅ Model exported: {len(tflite_model) / 1024 / 1024:.1f} MB")
```

### 7.3 Testing & Validation

```python
# Elo rating system for bot evaluation
def calculate_elo_rating(model_a, model_b, num_games=100):
    """
    Play N games between two models and calculate Elo rating difference
    """
    wins_a = 0
    wins_b = 0
    draws = 0
    
    for _ in range(num_games):
        result = play_game(model_a, model_b)
        if result == 1:
            wins_a += 1
        elif result == -1:
            wins_b += 1
        else:
            draws += 1
    
    # Calculate Elo rating change
    expected_score_a = 1 / (1 + 10 ** ((elo_b - elo_a) / 400))
    actual_score_a = (wins_a + 0.5 * draws) / num_games
    
    elo_change = 32 * (actual_score_a - expected_score_a)
    
    return elo_a + elo_change
```

---

## 📊 Summary

### What We're Building

1. **Custom AI models** (not pre-trained) for 14 unique chess variants
2. **Self-play training** (no external datasets needed)
3. **TFLite models** (5-20MB) running on-device in Flutter
4. **900-2000 Elo** bots per game mode
5. **P2P GameNet** for distributed training and model sharing
6. **On-device learning** (users improve their AI through play)

### Key Technologies

- **Training**: PyTorch + Docker Compose + Redis
- **Mobile**: Flutter + TFLite + MCTS (Dart)
- **P2P**: IPFS + WebSocket + Platform-specific APIs (Nearby Connections, MultipeerConnectivity)
- **Storage**: PostgreSQL + MinIO (S3-like)

### Timeline

- **Phase 1** (4 weeks): Basic AI working
- **Phase 2** (6 weeks): All 14 modes trained
- **Phase 3** (4 weeks): P2P GameNet operational
- **Phase 4** (2 weeks): Self-learning & optimization
- **Total**: ~16 weeks (4 months)

---

## 🚀 Next Steps

1. **Set up training infrastructure** (Docker Compose)
2. **Implement neural network** (PyTorch)
3. **Train first Classic mode model**
4. **Integrate TFLite in Flutter**
5. **Deploy P2P GameNet**

**Ready to proceed?** I can now create detailed implementation guides for each phase.
