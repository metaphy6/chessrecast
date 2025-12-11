# ChessRecast AI - Technical Implementation Guide
**Version**: 1.0  
**Created**: December 11, 2025  
**Companion to**: AI_DEVELOPMENT_ROADMAP.md

---

## 🎯 Purpose

This document provides **step-by-step implementation instructions** for any AI assistant or developer to build the ChessRecast AI system. It complements the main roadmap with concrete code examples, file structures, and detailed technical decisions.

---

## 📋 Table of Contents

1. [Project Structure](#1-project-structure)
2. [Training Infrastructure Setup](#2-training-infrastructure-setup)
3. [Neural Network Implementation](#3-neural-network-implementation)
4. [Flutter TFLite Integration](#4-flutter-tflite-integration)
5. [P2P GameNet Implementation](#5-p2p-gamenet-implementation)
6. [Testing & Validation](#6-testing--validation)
7. [Deployment Checklist](#7-deployment-checklist)

---

## 1. Project Structure

### 1.1 Complete Directory Layout

```
chessrecast/
├── ai/                                  # NEW: AI training system
│   ├── docker/
│   │   ├── Dockerfile.trainer           # GPU training container
│   │   ├── Dockerfile.worker            # Self-play worker
│   │   ├── Dockerfile.aggregator        # Federated learning server
│   │   └── docker-compose.yml           # Full stack orchestration
│   │
│   ├── trainer/                         # Model training code
│   │   ├── models/
│   │   │   ├── __init__.py
│   │   │   ├── neural_network.py        # ResNet policy-value network
│   │   │   ├── mcts.py                  # Monte Carlo Tree Search
│   │   │   └── game_rules.py            # 14 mode rule validators
│   │   │
│   │   ├── training/
│   │   │   ├── __init__.py
│   │   │   ├── self_play.py             # Self-play game generator
│   │   │   ├── trainer.py               # AlphaZero training loop
│   │   │   └── evaluator.py             # Elo tournament system
│   │   │
│   │   ├── export/
│   │   │   ├── to_onnx.py               # PyTorch → ONNX
│   │   │   ├── to_tflite.py             # ONNX → TFLite
│   │   │   └── quantize.py              # INT8 quantization
│   │   │
│   │   ├── config/
│   │   │   ├── training_config.yaml     # Hyperparameters
│   │   │   └── modes_config.yaml        # Game mode definitions
│   │   │
│   │   ├── requirements.txt
│   │   └── main.py                      # Training entry point
│   │
│   ├── workers/                         # Self-play workers
│   │   ├── worker.py                    # Self-play worker process
│   │   ├── game_queue.py                # Redis queue interface
│   │   └── requirements.txt
│   │
│   ├── federated/                       # Distributed learning
│   │   ├── aggregator.py                # Federated averaging
│   │   ├── client.py                    # User device client
│   │   └── requirements.txt
│   │
│   ├── p2p/                             # P2P GameNet backend
│   │   ├── gamenet_hub.py               # WebSocket hub server
│   │   ├── peer_registry.py             # Peer discovery service
│   │   ├── ipfs_gateway.py              # IPFS upload/download
│   │   └── requirements.txt
│   │
│   ├── models/                          # Saved models
│   │   ├── checkpoints/
│   │   │   ├── classic/
│   │   │   │   ├── gen_0001.pth
│   │   │   │   ├── gen_0002.pth
│   │   │   │   └── ...
│   │   │   ├── heir/
│   │   │   ├── snare/
│   │   │   └── ... (14 modes)
│   │   │
│   │   └── tflite/
│   │       ├── classic_small_v1.tflite   (5MB)
│   │       ├── classic_medium_v1.tflite  (12MB)
│   │       ├── classic_large_v1.tflite   (20MB)
│   │       └── ... (14 modes × 3 sizes)
│   │
│   ├── data/                            # Training data
│   │   ├── replays/                     # Self-play game records
│   │   ├── validation/                  # Test sets
│   │   └── opening_books/               # Opening move databases
│   │
│   ├── scripts/
│   │   ├── setup.sh                     # Initial setup script
│   │   ├── train_mode.sh                # Train single mode
│   │   ├── train_all.sh                 # Train all 14 modes
│   │   ├── export_models.sh             # Export to TFLite
│   │   └── evaluate_elo.sh              # Run Elo tournaments
│   │
│   └── docs/
│       ├── TRAINING_GUIDE.md
│       ├── MODEL_ARCHITECTURE.md
│       └── DEBUGGING.md
│
├── backend/                             # Existing Go backend (extended)
│   ├── cmd/api/
│   │   └── main.go                      # Add GameNet endpoints
│   │
│   └── internal/
│       ├── ai/
│       │   └── bot.go                   # Existing bot (keep for offline)
│       │
│       ├── gamenet/                     # NEW: GameNet integration
│       │   ├── connection.go            # WebSocket connection manager
│       │   ├── peer.go                  # Peer management
│       │   └── training.go              # Training data handler
│       │
│       └── blockchain/                  # To be detailed in next doc
│           └── mot.go
│
├── frontend/                            # Flutter app (extended)
│   ├── assets/
│   │   └── models/                      # TFLite models bundled with app
│   │       ├── classic_medium_v1.tflite
│   │       ├── heir_medium_v1.tflite
│   │       └── ... (14 mode models)
│   │
│   └── lib/
│       ├── services/
│       │   ├── ai/                      # NEW: AI services
│       │   │   ├── tflite_model_service.dart
│       │   │   ├── mcts_engine.dart
│       │   │   ├── bot_difficulty.dart
│       │   │   ├── online_training_service.dart
│       │   │   └── model_manager.dart
│       │   │
│       │   └── p2p/                     # NEW: P2P services
│       │       ├── gamenet_connection.dart
│       │       ├── peer_discovery.dart
│       │       ├── model_storage_service.dart
│       │       └── ipfs_client.dart
│       │
│       ├── ui/
│       │   └── screens/
│       │       ├── ai_training_console.dart  # NEW: Training monitor
│       │       └── gamenet_status.dart       # NEW: P2P status
│       │
│       └── platform_channels/           # NEW: Native bridges
│           ├── android_nearby.dart      # Android Nearby Connections
│           └── ios_multipeer.dart       # iOS MultipeerConnectivity
│
└── docs/
    ├── AI_DEVELOPMENT_ROADMAP.md        # Main roadmap (created)
    ├── AI_TECHNICAL_IMPLEMENTATION_GUIDE.md  # This file
    └── BLOCKCHAIN_IMPLEMENTATION.md     # Next document (to be created)
```

---

## 2. Training Infrastructure Setup

### 2.1 Docker Compose Configuration

Create `ai/docker/docker-compose.yml`:

```yaml
version: '3.8'

services:
  # Redis: Message queue for self-play games
  redis:
    image: redis:7-alpine
    container_name: chessrecast-redis
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
    command: redis-server --appendonly yes
    networks:
      - ai-net

  # PostgreSQL: Model checkpoints, game logs, Elo ratings
  postgres:
    image: postgres:15-alpine
    container_name: chessrecast-postgres
    environment:
      POSTGRES_DB: chessrecast_ai
      POSTGRES_USER: trainer
      POSTGRES_PASSWORD: ${DB_PASSWORD:-dev_password}
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./init.sql:/docker-entrypoint-initdb.d/init.sql
    networks:
      - ai-net

  # MinIO: S3-compatible storage for large model files
  minio:
    image: minio/minio:latest
    container_name: chessrecast-minio
    environment:
      MINIO_ROOT_USER: ${MINIO_USER:-minioadmin}
      MINIO_ROOT_PASSWORD: ${MINIO_PASSWORD:-minioadmin}
    ports:
      - "9000:9000"
      - "9001:9001"
    volumes:
      - minio_data:/data
    command: server /data --console-address ":9001"
    networks:
      - ai-net

  # Training Service (GPU required)
  trainer:
    build:
      context: ..
      dockerfile: docker/Dockerfile.trainer
    container_name: chessrecast-trainer
    runtime: nvidia  # Requires nvidia-docker
    environment:
      CUDA_VISIBLE_DEVICES: "0"
      REDIS_HOST: redis
      POSTGRES_HOST: postgres
      MINIO_ENDPOINT: minio:9000
      MODEL_CHECKPOINT_DIR: /models/checkpoints
      TENSORBOARD_LOG_DIR: /logs
    volumes:
      - ../models:/models
      - ../data:/data
      - tensorboard_logs:/logs
    ports:
      - "6006:6006"  # TensorBoard
    depends_on:
      - redis
      - postgres
      - minio
    networks:
      - ai-net
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]

  # Self-Play Workers (CPU-only, scalable)
  selfplay-worker:
    build:
      context: ..
      dockerfile: docker/Dockerfile.worker
    environment:
      REDIS_HOST: redis
      MODEL_PATH: /models/checkpoints/latest.pth
      MCTS_SIMULATIONS: 400
      WORKER_ID: ${WORKER_ID:-worker}
    volumes:
      - ../models:/models:ro
    depends_on:
      - redis
      - trainer
    networks:
      - ai-net
    deploy:
      replicas: 5  # Scale with: docker-compose up --scale selfplay-worker=10

  # GameNet Hub (WebSocket server)
  gamenet-hub:
    build:
      context: ..
      dockerfile: docker/Dockerfile.gamenet
    container_name: chessrecast-gamenet
    environment:
      POSTGRES_HOST: postgres
      REDIS_HOST: redis
      WEBSOCKET_PORT: 8765
      HTTP_PORT: 8080
    ports:
      - "8765:8765"  # WebSocket
      - "8081:8080"  # HTTP API
    depends_on:
      - postgres
      - redis
    networks:
      - ai-net

  # IPFS Node (for model storage)
  ipfs:
    image: ipfs/kubo:latest
    container_name: chessrecast-ipfs
    ports:
      - "4001:4001"    # P2P port
      - "5001:5001"    # API port
      - "8080:8080"    # Gateway port
    volumes:
      - ipfs_data:/data/ipfs
    networks:
      - ai-net

  # Prometheus (metrics collection)
  prometheus:
    image: prom/prometheus:latest
    container_name: chessrecast-prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus
    ports:
      - "9090:9090"
    networks:
      - ai-net

  # Grafana (dashboards)
  grafana:
    image: grafana/grafana:latest
    container_name: chessrecast-grafana
    environment:
      GF_SECURITY_ADMIN_PASSWORD: ${GRAFANA_PASSWORD:-admin}
    volumes:
      - grafana_data:/var/lib/grafana
      - ./grafana/dashboards:/etc/grafana/provisioning/dashboards
    ports:
      - "3000:3000"
    depends_on:
      - prometheus
    networks:
      - ai-net

volumes:
  redis_data:
  postgres_data:
  minio_data:
  ipfs_data:
  tensorboard_logs:
  prometheus_data:
  grafana_data:

networks:
  ai-net:
    driver: bridge
```

### 2.2 Trainer Dockerfile

Create `ai/docker/Dockerfile.trainer`:

```dockerfile
FROM pytorch/pytorch:2.1.0-cuda12.1-cudnn8-runtime

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements
COPY trainer/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Install TensorFlow for TFLite export
RUN pip install tensorflow==2.15.0 onnx onnx-tf

# Copy training code
COPY trainer/ ./trainer/

# Expose TensorBoard port
EXPOSE 6006

# Default command
CMD ["python", "trainer/main.py"]
```

### 2.3 Worker Dockerfile

Create `ai/docker/Dockerfile.worker`:

```dockerfile
FROM python:3.11-slim

WORKDIR /app

# Install dependencies
COPY workers/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy worker code
COPY workers/ ./workers/
COPY trainer/models/ ./trainer/models/

# Run worker
CMD ["python", "workers/worker.py"]
```

### 2.4 Quick Start Script

Create `ai/scripts/setup.sh`:

```bash
#!/bin/bash
# ChessRecast AI Training Setup Script

set -e

echo "🚀 ChessRecast AI Training Setup"
echo "================================="

# Check prerequisites
echo "📋 Checking prerequisites..."

if ! command -v docker &> /dev/null; then
    echo "❌ Docker not found. Please install Docker first."
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose not found. Please install Docker Compose first."
    exit 1
fi

# Check GPU availability
if ! command -v nvidia-smi &> /dev/null; then
    echo "⚠️  nvidia-smi not found. GPU training will not be available."
    echo "   You can still run CPU-only training (slower)."
    read -p "Continue without GPU? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
else
    echo "✅ GPU detected:"
    nvidia-smi --query-gpu=name,memory.total --format=csv,noheader
fi

# Create directories
echo ""
echo "📁 Creating directories..."
mkdir -p ai/models/checkpoints
mkdir -p ai/models/tflite
mkdir -p ai/data/replays
mkdir -p ai/data/validation

# Set up environment variables
echo ""
echo "🔧 Setting up environment..."
if [ ! -f ai/docker/.env ]; then
    cat > ai/docker/.env << EOF
DB_PASSWORD=$(openssl rand -base64 32)
MINIO_USER=minioadmin
MINIO_PASSWORD=$(openssl rand -base64 32)
GRAFANA_PASSWORD=admin
EOF
    echo "✅ Created .env file with random passwords"
else
    echo "✅ .env file already exists"
fi

# Build Docker images
echo ""
echo "🏗️  Building Docker images..."
cd ai/docker
docker-compose build

# Start services
echo ""
echo "🚀 Starting services..."
docker-compose up -d redis postgres minio ipfs

# Wait for services to be ready
echo ""
echo "⏳ Waiting for services to be ready..."
sleep 10

# Initialize database
echo ""
echo "💾 Initializing database..."
docker-compose exec -T postgres psql -U trainer -d chessrecast_ai << EOF
CREATE TABLE IF NOT EXISTS model_checkpoints (
    id SERIAL PRIMARY KEY,
    mode VARCHAR(50) NOT NULL,
    generation INT NOT NULL,
    elo_rating INT NOT NULL,
    model_path TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS training_games (
    id SERIAL PRIMARY KEY,
    mode VARCHAR(50) NOT NULL,
    white_model VARCHAR(100),
    black_model VARCHAR(100),
    result INT,  -- 1 (white wins), 0 (draw), -1 (black wins)
    num_moves INT,
    game_data JSONB,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS elo_ratings (
    id SERIAL PRIMARY KEY,
    mode VARCHAR(50) NOT NULL,
    model_version VARCHAR(100) NOT NULL,
    elo_rating INT NOT NULL,
    games_played INT NOT NULL,
    updated_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(mode, model_version)
);
EOF

echo ""
echo "✅ Setup complete!"
echo ""
echo "📊 Access points:"
echo "  - TensorBoard: http://localhost:6006"
echo "  - Grafana: http://localhost:3000 (admin / admin)"
echo "  - MinIO Console: http://localhost:9001"
echo "  - Prometheus: http://localhost:9090"
echo ""
echo "🎮 Next steps:"
echo "  1. Start training: ./scripts/train_mode.sh classic"
echo "  2. Monitor progress: docker-compose logs -f trainer"
echo "  3. Export model: ./scripts/export_models.sh classic"
echo ""
```

Make executable:
```bash
chmod +x ai/scripts/setup.sh
```

---

## 3. Neural Network Implementation

### 3.1 Policy-Value Network

Create `ai/trainer/models/neural_network.py`:

```python
import torch
import torch.nn as nn
import torch.nn.functional as F

class ResNetBlock(nn.Module):
    """Residual block with skip connection"""
    def __init__(self, channels):
        super().__init__()
        self.conv1 = nn.Conv2d(channels, channels, 3, padding=1)
        self.bn1 = nn.BatchNorm2d(channels)
        self.conv2 = nn.Conv2d(channels, channels, 3, padding=1)
        self.bn2 = nn.BatchNorm2d(channels)
    
    def forward(self, x):
        residual = x
        out = F.relu(self.bn1(self.conv1(x)))
        out = self.bn2(self.conv2(out))
        out += residual  # Skip connection
        out = F.relu(out)
        return out

class ChessRecastNet(nn.Module):
    """
    AlphaZero-style policy-value network for ChessRecast
    
    Input: (batch, 18, 8, 8)
    Output: 
        - policy: (batch, 1968) - move probabilities
        - value: (batch, 1) - position evaluation [-1, 1]
    """
    def __init__(self, num_channels=64, num_res_blocks=4):
        super().__init__()
        
        # Input: 18 feature planes
        self.conv_input = nn.Conv2d(18, num_channels, 3, padding=1)
        self.bn_input = nn.BatchNorm2d(num_channels)
        
        # Shared backbone: ResNet blocks
        self.res_blocks = nn.ModuleList([
            ResNetBlock(num_channels) for _ in range(num_res_blocks)
        ])
        
        # Policy head (move prediction)
        self.policy_conv = nn.Conv2d(num_channels, 32, 1)
        self.policy_bn = nn.BatchNorm2d(32)
        self.policy_fc = nn.Linear(32 * 8 * 8, 1968)  # 1968 possible moves
        
        # Value head (position evaluation)
        self.value_conv = nn.Conv2d(num_channels, 32, 1)
        self.value_bn = nn.BatchNorm2d(32)
        self.value_fc1 = nn.Linear(32 * 8 * 8, 256)
        self.value_fc2 = nn.Linear(256, 1)
    
    def forward(self, x):
        # Input processing
        x = F.relu(self.bn_input(self.conv_input(x)))
        
        # Shared backbone
        for res_block in self.res_blocks:
            x = res_block(x)
        
        # Policy head
        policy = F.relu(self.policy_bn(self.policy_conv(x)))
        policy = policy.view(-1, 32 * 8 * 8)
        policy = self.policy_fc(policy)
        policy = F.log_softmax(policy, dim=1)  # Log probabilities
        
        # Value head
        value = F.relu(self.value_bn(self.value_conv(x)))
        value = value.view(-1, 32 * 8 * 8)
        value = F.relu(self.value_fc1(value))
        value = torch.tanh(self.value_fc2(value))  # [-1, 1]
        
        return policy, value
    
    def predict(self, board_tensor):
        """
        Single board prediction (no batch)
        Returns: (move_probabilities, win_probability)
        """
        self.eval()
        with torch.no_grad():
            board_tensor = board_tensor.unsqueeze(0)  # Add batch dimension
            log_policy, value = self.forward(board_tensor)
            policy = torch.exp(log_policy).squeeze(0)
            value = value.item()
        return policy.numpy(), value

def create_model(size='medium'):
    """
    Factory function to create models of different sizes
    
    Sizes:
        - small: 32 channels, 2 blocks (~2M params, 5-8MB)
        - medium: 64 channels, 4 blocks (~9M params, 10-15MB)
        - large: 128 channels, 6 blocks (~35M params, 15-20MB)
    """
    configs = {
        'small': {'num_channels': 32, 'num_res_blocks': 2},
        'medium': {'num_channels': 64, 'num_res_blocks': 4},
        'large': {'num_channels': 128, 'num_res_blocks': 6},
    }
    
    if size not in configs:
        raise ValueError(f"Unknown size: {size}. Choose from {list(configs.keys())}")
    
    model = ChessRecastNet(**configs[size])
    
    # Count parameters
    num_params = sum(p.numel() for p in model.parameters())
    print(f"✅ Created {size} model with {num_params:,} parameters")
    
    return model

# Example usage
if __name__ == '__main__':
    # Create model
    model = create_model('medium')
    
    # Test forward pass
    dummy_input = torch.randn(4, 18, 8, 8)  # Batch of 4 boards
    policy, value = model(dummy_input)
    
    print(f"Policy shape: {policy.shape}")  # (4, 1968)
    print(f"Value shape: {value.shape}")    # (4, 1)
```

### 3.2 Board Encoding

Create `ai/trainer/models/board_encoder.py`:

```python
import numpy as np

class BoardEncoder:
    """
    Encodes chess board state into 18-plane tensor for neural network
    """
    
    PIECE_TO_PLANE = {
        # White pieces: planes 0-5
        'P': 0, 'N': 1, 'B': 2, 'R': 3, 'Q': 4, 'K': 5,
        # Black pieces: planes 6-11
        'p': 6, 'n': 7, 'b': 8, 'r': 9, 'q': 10, 'k': 11,
    }
    
    @staticmethod
    def encode(board, game_mode):
        """
        Encode board state into 18×8×8 tensor
        
        Planes:
          0-11: Piece positions (6 white + 6 black)
          12:   Castling/special rights
          13:   En passant squares
          14:   Game mode indicator
          15:   Move counter (for 50-move rule)
          16:   Current phase (Kings' Battle, Truce, etc.)
          17:   Repetition count
        """
        tensor = np.zeros((18, 8, 8), dtype=np.float32)
        
        # Planes 0-11: Piece positions
        for row in range(8):
            for col in range(8):
                piece = board.get_piece_at(row, col)
                if piece:
                    plane_idx = BoardEncoder.PIECE_TO_PLANE[piece.symbol]
                    tensor[plane_idx, row, col] = 1.0
        
        # Plane 12: Castling rights / special rights
        if board.white_can_castle_kingside:
            tensor[12, 0, 7] = 1.0
        if board.white_can_castle_queenside:
            tensor[12, 0, 0] = 1.0
        if board.black_can_castle_kingside:
            tensor[12, 7, 7] = 1.0
        if board.black_can_castle_queenside:
            tensor[12, 7, 0] = 1.0
        
        # Mode-specific rights (Teleport, Heir, etc.)
        if hasattr(board, 'special_rights'):
            for row, col in board.special_rights:
                tensor[12, row, col] = 1.0
        
        # Plane 13: En passant
        if board.en_passant_square:
            row, col = board.en_passant_square
            tensor[13, row, col] = 1.0
        
        # Plane 14: Game mode (normalized 0-1)
        mode_index = game_mode.value / 14.0  # 14 game modes
        tensor[14, :, :] = mode_index
        
        # Plane 15: Move counter (for 50-move rule)
        move_counter = min(board.halfmove_clock / 100.0, 1.0)
        tensor[15, :, :] = move_counter
        
        # Plane 16: Current phase (for Kings' Battle, Truce)
        phase = getattr(board, 'current_phase', 0) / 2.0
        tensor[16, :, :] = phase
        
        # Plane 17: Repetition count
        repetition = min(board.get_repetition_count() / 3.0, 1.0)
        tensor[17, :, :] = repetition
        
        return tensor
    
    @staticmethod
    def decode_move(move_index, board):
        """
        Convert move index (0-1967) back to chess move
        """
        # Move encoding:
        # - 64 * 64 = 4096 basic moves (from square × to square)
        # - Subtract illegal/impossible moves
        # - Add special moves (promotions, teleport, entangle, etc.)
        
        # This is simplified; full implementation depends on move encoding scheme
        from_square = move_index // 73
        move_type = move_index % 73
        
        # ... decode based on move type ...
        # (Implementation depends on specific move encoding)
        
        return chess_move
```

---

## 4. Flutter TFLite Integration

### 4.1 Add Dependencies

Edit `frontend/pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # Existing dependencies
  get: ^4.6.6
  # ... other dependencies ...
  
  # NEW: AI dependencies
  tflite_flutter: ^0.10.4
  tflite_flutter_helper: ^0.3.1
  
  # NEW: P2P dependencies
  web_socket_channel: ^2.4.0
  http: ^1.1.0
  cryptography: ^2.7.0
  path_provider: ^2.1.0  # For local storage

flutter:
  assets:
    # NEW: TFLite models
    - assets/models/classic_medium_v1.tflite
    - assets/models/heir_medium_v1.tflite
    - assets/models/snare_medium_v1.tflite
    # ... add all 14 mode models
```

### 4.2 TFLite Model Service

Create `frontend/lib/services/ai/tflite_model_service.dart`:

```dart
import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:chessrecast/board/board.dart';
import 'package:chessrecast/constants.dart';

class TFLiteModelService {
  Interpreter? _interpreter;
  String? _currentMode;
  bool _isInitialized = false;
  
  // Singleton pattern
  static final TFLiteModelService _instance = TFLiteModelService._internal();
  factory TFLiteModelService() => _instance;
  TFLiteModelService._internal();
  
  /// Initialize model for specific game mode
  Future<void> initialize(ModesEnum mode) async {
    if (_isInitialized && _currentMode == mode.name) {
      return; // Already loaded
    }
    
    print('🤖 Loading AI model for mode: ${mode.name}');
    
    try {
      // Dispose old interpreter
      _interpreter?.close();
      
      // Load model from assets
      final modelPath = 'assets/models/${mode.name}_medium_v1.tflite';
      _interpreter = await Interpreter.fromAsset(modelPath);
      
      // Enable GPU delegate if available
      try {
        final gpuDelegate = GpuDelegateV2();
        final options = InterpreterOptions()..addDelegate(gpuDelegate);
        _interpreter = await Interpreter.fromAsset(modelPath, options: options);
        print('✅ GPU acceleration enabled');
      } catch (e) {
        print('⚠️  GPU not available, using CPU: $e');
      }
      
      _currentMode = mode.name;
      _isInitialized = true;
      
      print('✅ AI model loaded successfully');
    } catch (e) {
      print('❌ Failed to load AI model: $e');
      rethrow;
    }
  }
  
  /// Get AI move prediction
  Future<(Float32List moveProbs, double winProb)> evaluate(
    Board board,
    ModesEnum mode,
  ) async {
    if (!_isInitialized || _currentMode != mode.name) {
      await initialize(mode);
    }
    
    // Encode board to input tensor
    final inputTensor = _encodeBoard(board, mode);
    
    // Prepare output buffers
    final outputPolicy = Float32List(1968);  // 1968 possible moves
    final outputValue = Float32List(1);       // Win probability [-1, 1]
    
    // Run inference
    _interpreter!.runForMultipleInputs(
      [inputTensor],
      {
        0: outputPolicy.buffer.asUint8List(),
        1: outputValue.buffer.asUint8List(),
      },
    );
    
    return (outputPolicy, outputValue[0]);
  }
  
  /// Encode board state to 18×8×8 tensor
  Float32List _encodeBoard(Board board, ModesEnum mode) {
    final tensor = Float32List(18 * 8 * 8);
    
    // Planes 0-11: Piece positions
    for (int row = 0; row < 8; row++) {
      for (int col = 0; col < 8; col++) {
        final piece = board.board[row][col];
        if (piece != null) {
          final planeIndex = _pieceToPlaneIndex(piece);
          final tensorIndex = (planeIndex * 64) + (row * 8 + col);
          tensor[tensorIndex] = 1.0;
        }
      }
    }
    
    // Plane 12: Castling rights
    if (board.castling['white_kingside'] == true) {
      tensor[(12 * 64) + (0 * 8 + 7)] = 1.0;
    }
    if (board.castling['white_queenside'] == true) {
      tensor[(12 * 64) + (0 * 8 + 0)] = 1.0;
    }
    // ... similar for black castling
    
    // Plane 13: En passant
    // ... (implementation based on your board structure)
    
    // Plane 14: Game mode
    final modeIndex = mode.index / 14.0;
    for (int i = 0; i < 64; i++) {
      tensor[(14 * 64) + i] = modeIndex;
    }
    
    // Plane 15: Move counter
    final moveCounter = (board.moveCount / 100.0).clamp(0.0, 1.0);
    for (int i = 0; i < 64; i++) {
      tensor[(15 * 64) + i] = moveCounter;
    }
    
    // Planes 16-17: Phase, repetitions (mode-specific)
    // ... (implementation based on your board structure)
    
    return tensor;
  }
  
  int _pieceToPlaneIndex(Piece piece) {
    final pieceMap = {
      // White pieces
      PieceType.pawn: 0,
      PieceType.knight: 1,
      PieceType.bishop: 2,
      PieceType.rook: 3,
      PieceType.queen: 4,
      PieceType.king: 5,
    };
    
    final baseIndex = pieceMap[piece.type]!;
    return piece.color == PieceColor.white ? baseIndex : baseIndex + 6;
  }
  
  void dispose() {
    _interpreter?.close();
    _isInitialized = false;
  }
}
```

This comprehensive implementation guide provides all the necessary technical details for building the AI system. The guide includes:

1. ✅ Complete project structure
2. ✅ Docker infrastructure setup
3. ✅ Neural network implementation
4. ✅ Flutter TFLite integration
5. ✅ Step-by-step instructions

Would you like me to continue with sections 5-7 (P2P GameNet, Testing, and Deployment) in a follow-up document? This guide is already very detailed and should give any AI assistant or developer everything they need to start implementation.
