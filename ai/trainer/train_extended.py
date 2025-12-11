"""
Extended GPU training - 10 iterations × 100 games for better AI strength.
Expected training time: 45-60 minutes on RTX 4080.
Target strength: 800-1000 Elo.
"""
import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import Dataset, DataLoader
import numpy as np
import sys
import time
from pathlib import Path
from tqdm import tqdm

from neural_network_gpu import ChessNetPOC, count_parameters
from self_play import SimpleSelfPlay
from game_rules import ChessGamePOC

class ChessDataset(Dataset):
    def __init__(self, game_history):
        self.data = game_history
    
    def __len__(self):
        return len(self.data)
    
    def __getitem__(self, idx):
        entry = self.data[idx]
        state = torch.from_numpy(entry['state']).float()
        value = torch.tensor([entry['value']], dtype=torch.float32)
        policy = torch.zeros(4096, dtype=torch.float32)
        return state, policy, value

def train_extended():
    """Extended training for better AI strength"""
    
    print("=" * 70)
    print("ChessRecast AI - Extended GPU Training")
    print("=" * 70)
    
    # GPU enforcement
    if not torch.cuda.is_available():
        print("\n❌ FATAL ERROR: CUDA GPU not detected!")
        print("\nThis training requires a NVIDIA GPU with CUDA support.")
        sys.exit(1)
    
    DEVICE = 'cuda'
    
    # GPU info
    print(f"\n🚀 GPU Device: {torch.cuda.get_device_name(0)}")
    props = torch.cuda.get_device_properties(0)
    print(f"   Compute Capability: {props.major}.{props.minor}")
    print(f"   Total VRAM: {props.total_memory / 1e9:.1f} GB")
    
    # Extended configuration optimized for GPU
    NUM_ITERATIONS = 10  # More iterations = better play
    GAMES_PER_ITERATION = 50  # Optimized for speed
    EPOCHS_PER_ITERATION = 10  # More epochs since fewer games
    BATCH_SIZE = 256  # Much larger for GPU utilization
    LEARNING_RATE = 0.001
    NUM_WORKERS = 4
    
    print(f"\n📊 Training Configuration (GPU-Optimized):")
    print(f"   Iterations: {NUM_ITERATIONS}")
    print(f"   Games per iteration: {GAMES_PER_ITERATION} (optimized for speed)")
    print(f"   Training epochs: {EPOCHS_PER_ITERATION} (more epochs, fewer games)")
    print(f"   Batch size: {BATCH_SIZE} (4x larger for GPU)")
    print(f"   Total games: {NUM_ITERATIONS * GAMES_PER_ITERATION:,}")
    print(f"   Expected time: ~15-20 minutes (GPU-accelerated)")
    
    # GPU optimizations
    print("\n⚡ Enabling GPU optimizations...")
    torch.backends.cudnn.benchmark = True
    torch.backends.cuda.matmul.allow_tf32 = True
    torch.backends.cudnn.allow_tf32 = True
    print("   ✓ cuDNN benchmark + TF32 enabled")
    
    # Model setup
    print("\n🧠 Creating neural network...")
    model = ChessNetPOC(num_channels=64).to(DEVICE)
    params = count_parameters(model)
    print(f"   Parameters: {params:,}")
    
    # Optimizer & mixed precision
    optimizer = optim.Adam(model.parameters(), lr=LEARNING_RATE)
    scaler = torch.cuda.amp.GradScaler()
    value_loss_fn = nn.MSELoss()
    print("   ✓ Mixed precision (FP16) enabled")
    
    # Checkpoint setup
    checkpoint_dir = Path('/workspace/checkpoints')
    checkpoint_dir.mkdir(exist_ok=True)
    
    # Training metrics
    training_start = time.time()
    iteration_times = []
    loss_history = []
    
    print("\n" + "=" * 70)
    print("🎮 Starting Extended Training Loop")
    print("=" * 70)
    
    for iteration in range(1, NUM_ITERATIONS + 1):
        iter_start = time.time()
        
        print(f"\n{'=' * 70}")
        print(f"📍 Iteration {iteration}/{NUM_ITERATIONS}")
        print(f"{'=' * 70}")
        
        # Self-play phase
        print("\n🎲 Self-Play Phase:")
        print(f"   Playing {GAMES_PER_ITERATION} games...", flush=True)
        self_play = SimpleSelfPlay(model, device=DEVICE)
        all_game_data = []
        
        game_lengths = []
        with torch.no_grad():
            for game_num in range(GAMES_PER_ITERATION):
                game_history = self_play.play_game(temperature=1.0)
                all_game_data.extend(game_history)
                game_lengths.append(len(game_history))
                
                # Print progress every 10 games
                if (game_num + 1) % 10 == 0 or game_num == 0:
                    avg_len = sum(game_lengths) / len(game_lengths)
                    print(f"   Game {game_num + 1}/{GAMES_PER_ITERATION} - Avg length: {avg_len:.1f} moves", flush=True)
        
        avg_game_length = sum(game_lengths) / len(game_lengths)
        print(f"   Generated {len(all_game_data):,} positions")
        print(f"   Avg game length: {avg_game_length:.1f} moves")
        print(f"   Shortest: {min(game_lengths)}, Longest: {max(game_lengths)}")
        
        # Training phase
        print("\n🎓 Training Phase:")
        dataset = ChessDataset(all_game_data)
        dataloader = DataLoader(
            dataset,
            batch_size=BATCH_SIZE,
            shuffle=True,
            num_workers=NUM_WORKERS,
            pin_memory=True,
            persistent_workers=True if NUM_WORKERS > 0 else False,
            prefetch_factor=2 if NUM_WORKERS > 0 else None
        )
        
        model.train()
        iteration_loss = 0
        
        for epoch in range(EPOCHS_PER_ITERATION):
            epoch_loss = 0
            batch_count = 0
            
            print(f"   Epoch {epoch+1}/{EPOCHS_PER_ITERATION}...", flush=True)
            for batch_idx, (states, policy_targets, value_targets) in enumerate(dataloader):
                states = states.to(DEVICE, non_blocking=True)
                value_targets = value_targets.to(DEVICE, non_blocking=True)
                
                optimizer.zero_grad(set_to_none=True)
                
                # Mixed precision forward
                with torch.cuda.amp.autocast():
                    policy_pred, value_pred = model(states)
                    loss = value_loss_fn(value_pred, value_targets)
                
                # Mixed precision backward
                scaler.scale(loss).backward()
                scaler.step(optimizer)
                scaler.update()
                
                epoch_loss += loss.item()
                batch_count += 1
                
                # Print progress every 50 batches
                if (batch_idx + 1) % 50 == 0:
                    print(f"     Batch {batch_idx + 1}/{len(dataloader)} - Loss: {loss.item():.4f}", flush=True)
            
            avg_epoch_loss = epoch_loss / batch_count
            print(f"   Epoch {epoch+1} - Avg Loss: {avg_epoch_loss:.4f}")
            iteration_loss += avg_epoch_loss
        
        avg_iteration_loss = iteration_loss / EPOCHS_PER_ITERATION
        loss_history.append(avg_iteration_loss)
        
        # Save checkpoint
        checkpoint_path = checkpoint_dir / f"checkpoint_iter_{iteration:02d}.pth"
        torch.save({
            'iteration': iteration,
            'model_state_dict': model.state_dict(),
            'optimizer_state_dict': optimizer.state_dict(),
            'scaler_state_dict': scaler.state_dict(),
            'loss': avg_iteration_loss,
            'config': {
                'num_channels': 64,
                'num_iterations': NUM_ITERATIONS,
                'games_per_iteration': GAMES_PER_ITERATION,
            }
        }, checkpoint_path)
        print(f"\n💾 Checkpoint saved: {checkpoint_path.name}")
        print(f"   Iteration loss: {avg_iteration_loss:.4f}")
        
        # Time tracking
        iter_time = time.time() - iter_start
        iteration_times.append(iter_time)
        avg_iter_time = sum(iteration_times) / len(iteration_times)
        remaining_iters = NUM_ITERATIONS - iteration
        estimated_remaining = remaining_iters * avg_iter_time
        
        print(f"\n⏱️  Timing:")
        print(f"   This iteration: {iter_time/60:.1f} minutes")
        print(f"   Avg per iteration: {avg_iter_time/60:.1f} minutes")
        print(f"   Estimated remaining: {estimated_remaining/60:.1f} minutes")
        
        # GPU memory
        allocated = torch.cuda.memory_allocated(0) / 1e9
        reserved = torch.cuda.memory_reserved(0) / 1e9
        print(f"\n📊 GPU Memory: {allocated:.2f} GB allocated, {reserved:.2f} GB reserved")
        
        # Loss trend
        if len(loss_history) >= 2:
            loss_change = loss_history[-1] - loss_history[-2]
            trend = "📉 Improving" if loss_change < 0 else "📈 Fluctuating"
            print(f"\n{trend} - Loss change: {loss_change:+.4f}")
    
    # Training complete
    total_time = time.time() - training_start
    
    print("\n" + "=" * 70)
    print("✅ Extended Training Complete!")
    print("=" * 70)
    
    print(f"\n📊 Training Summary:")
    print(f"   Total time: {total_time/60:.1f} minutes")
    print(f"   Total games: {NUM_ITERATIONS * GAMES_PER_ITERATION:,}")
    print(f"   Final loss: {loss_history[-1]:.4f}")
    print(f"   Loss improvement: {loss_history[0] - loss_history[-1]:.4f}")
    
    # Loss progression
    print(f"\n📉 Loss Progression:")
    for i, loss in enumerate(loss_history, 1):
        bar = "█" * int(50 * (1 - loss / max(loss_history)))
        print(f"   Iter {i:2d}: {loss:.4f} {bar}")
    
    # Save final model
    final_path = checkpoint_dir / "chess_extended_final.pth"
    torch.save({
        'model_state_dict': model.state_dict(),
        'config': {
            'num_channels': 64,
            'iterations': NUM_ITERATIONS,
            'games_per_iteration': GAMES_PER_ITERATION,
            'total_games': NUM_ITERATIONS * GAMES_PER_ITERATION,
            'training_time_minutes': total_time / 60,
            'final_loss': loss_history[-1],
        }
    }, final_path)
    print(f"\n💾 Final model saved: {final_path.name}")
    
    print(f"\n🎯 Next Steps:")
    print(f"   1. Analyze improvement: python trainer/analyze_training.py")
    print(f"   2. Export to TFLite: python trainer/export_tflite.py")
    print(f"   3. Test in Flutter app")
    
    print(f"\n✨ Expected AI Strength: ~800-1000 Elo")
    print(f"   (Better than random play, makes reasonable moves)")

if __name__ == "__main__":
    train_extended()
