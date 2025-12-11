"""
Quick test to verify the training setup works.
This runs 1 iteration with 2 games to test everything quickly.
"""
import torch
import sys
from pathlib import Path

print("=" * 60)
print("ChessRecast AI POC - Quick Test")
print("=" * 60)
print()

# Check imports
print("✓ Checking imports...")
try:
    from neural_network import ChessNetPOC, count_parameters
    from self_play import SimpleSelfPlay
    from game_rules import ChessGamePOC
    print("✅ All imports successful")
except Exception as e:
    print(f"❌ Import error: {e}")
    sys.exit(1)

print()

# Check device
device = 'cuda' if torch.cuda.is_available() else 'cpu'
print(f"✓ Device: {device}")
if device == 'cuda':
    print(f"  GPU: {torch.cuda.get_device_name(0)}")
    print(f"  VRAM: {torch.cuda.get_device_properties(0).total_memory / 1e9:.1f} GB")

print()

# Test model creation
print("✓ Creating neural network...")
try:
    model = ChessNetPOC(num_channels=64).to(device)
    params = count_parameters(model)
    print(f"✅ Model created: {params:,} parameters")
except Exception as e:
    print(f"❌ Model creation error: {e}")
    sys.exit(1)

print()

# Test forward pass
print("✓ Testing forward pass...")
try:
    test_input = torch.randn(1, 12, 8, 8).to(device)
    policy, value = model(test_input)
    print(f"✅ Forward pass successful")
    print(f"  Policy shape: {policy.shape}")
    print(f"  Value shape: {value.shape}")
except Exception as e:
    print(f"❌ Forward pass error: {e}")
    sys.exit(1)

print()

# Test game rules
print("✓ Testing game rules...")
try:
    game = ChessGamePOC()
    legal_moves = game.get_legal_moves()
    print(f"✅ Game rules working")
    print(f"  Starting position legal moves: {len(legal_moves)}")
    
    # Test board encoding
    tensor = game.get_board_tensor()
    print(f"  Board tensor shape: {tensor.shape}")
except Exception as e:
    print(f"❌ Game rules error: {e}")
    sys.exit(1)

print()

# Test self-play (1 quick game)
print("✓ Testing self-play (1 game)...")
try:
    self_play = SimpleSelfPlay(model, device=device)
    game_history = self_play.play_game(temperature=1.0)
    print(f"✅ Self-play successful")
    print(f"  Game length: {len(game_history)} positions")
    print(f"  Sample data keys: {list(game_history[0].keys())}")
except Exception as e:
    print(f"❌ Self-play error: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)

print()

# Check checkpoint directory
print("✓ Checking checkpoint directory...")
checkpoint_dir = Path('/workspace/checkpoints')
checkpoint_dir.mkdir(exist_ok=True)
if checkpoint_dir.exists():
    print(f"✅ Checkpoint directory ready: {checkpoint_dir}")
else:
    print(f"❌ Could not create checkpoint directory")
    sys.exit(1)

print()
print("=" * 60)
print("✅ ALL TESTS PASSED!")
print("=" * 60)
print()
print("Your training environment is ready.")
print("Run the full training with:")
print("  docker-compose -f docker-compose.poc.yml up")
print()
