"""
MAXIMUM GPU-Optimized Training
- Larger batch sizes (256-512)
- Faster iterations
- Better GPU utilization
Expected: 15-20 minutes total
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

def train_fast():
    """GPU-optimized fast training"""
    
    print("=" * 70)
    print("ChessRecast AI - MAXIMUM GPU Training")
    print("=" * 70)
    
    if not torch.cuda.is_available():
        print("\n❌ GPU required!")
        sys.exit(1)
    
    DEVICE = 'cuda'
    
    # GPU info
    print(f"\n🚀 GPU: {torch.cuda.get_device_name(0)}")
    props = torch.cuda.get_device_properties(0)
    total_vram = props.total_memory / 1e9
    print(f"   Total VRAM: {total_vram:.1f} GB")
    
    # AGGRESSIVE GPU UTILIZATION
    NUM_ITERATIONS = 15
    GAMES_PER_ITERATION = 40  # Faster self-play
    EPOCHS_PER_ITERATION = 12  # More training per iteration
    BATCH_SIZE = 512  # MUCH LARGER - use that VRAM!
    LEARNING_RATE = 0.001
    NUM_WORKERS = 2  # Reduced for stability
    
    print(f"\n⚡ AGGRESSIVE Configuration:")
    print(f"   Iterations: {NUM_ITERATIONS}")
    print(f"   Games/iteration: {GAMES_PER_ITERATION} (fast)")
    print(f"   Epochs: {EPOCHS_PER_ITERATION} (intensive)")
    print(f"   Batch size: {BATCH_SIZE} (8x normal!)")
    print(f"   Data workers: {NUM_WORKERS}")
    print(f"   Total games: {NUM_ITERATIONS * GAMES_PER_ITERATION}")
    print(f"   Expected: 15-25 minutes")
    
    # Enable ALL optimizations
    print("\n🔥 Enabling ALL GPU optimizations...")
    torch.backends.cudnn.benchmark = True
    torch.backends.cuda.matmul.allow_tf32 = True
    torch.backends.cudnn.allow_tf32 = True
    torch.set_float32_matmul_precision('high')
    print("   ✓ cuDNN benchmark")
    print("   ✓ TensorFloat-32")
    print("   ✓ High precision matmul")
    
    # Model
    print("\n🧠 Neural network...")
    model = ChessNetPOC(num_channels=64).to(DEVICE)
    # Skip compilation - causes issues in Docker
    # model = torch.compile(model, mode='max-autotune')
    print(f"   Parameters: {count_parameters(model):,}")
    print("   ✓ Model ready for training")
    
    # Optimizer & mixed precision
    optimizer = optim.AdamW(model.parameters(), lr=LEARNING_RATE, weight_decay=1e-4)
    scaler = torch.cuda.amp.GradScaler()
    value_loss_fn = nn.MSELoss()
    print("   ✓ AdamW + Mixed Precision")
    
    checkpoint_dir = Path('/workspace/checkpoints')
    checkpoint_dir.mkdir(exist_ok=True)
    
    # Training loop
    training_start = time.time()
    loss_history = []
    
    print("\n" + "=" * 70)
    print("🚀 MAXIMUM SPEED TRAINING")
    print("=" * 70)
    
    for iteration in range(1, NUM_ITERATIONS + 1):
        iter_start = time.time()
        
        print(f"\n{'=' * 70}")
        print(f"📍 Iteration {iteration}/{NUM_ITERATIONS}")
        print(f"{'=' * 70}")
        
        # Self-play
        print(f"\n🎲 Self-Play: {GAMES_PER_ITERATION} games")
        self_play = SimpleSelfPlay(model, device=DEVICE)
        all_data = []
        
        with torch.no_grad():
            for game_num in range(GAMES_PER_ITERATION):
                game_history = self_play.play_game(temperature=1.0)
                all_data.extend(game_history)
                
                if (game_num + 1) % 10 == 0:
                    print(f"   {game_num + 1}/{GAMES_PER_ITERATION} games | {len(all_data):,} positions", flush=True)
        
        print(f"   ✓ Generated {len(all_data):,} positions")
        
        # Training
        print(f"\n🎓 Training: {EPOCHS_PER_ITERATION} epochs, batch={BATCH_SIZE}")
        dataset = ChessDataset(all_data)
        dataloader = DataLoader(
            dataset,
            batch_size=BATCH_SIZE,
            shuffle=True,
            num_workers=NUM_WORKERS,
            pin_memory=True,
            prefetch_factor=2 if NUM_WORKERS > 0 else None
        )
        
        model.train()
        iter_loss = 0
        
        for epoch in range(EPOCHS_PER_ITERATION):
            epoch_loss = 0
            batches = 0
            
            for states, _, values in dataloader:
                states = states.to(DEVICE, non_blocking=True)
                values = values.to(DEVICE, non_blocking=True)
                
                optimizer.zero_grad(set_to_none=True)
                
                with torch.cuda.amp.autocast():
                    _, value_pred = model(states)
                    loss = value_loss_fn(value_pred, values)
                
                scaler.scale(loss).backward()
                scaler.step(optimizer)
                scaler.update()
                
                epoch_loss += loss.item()
                batches += 1
            
            avg_loss = epoch_loss / batches
            print(f"   Epoch {epoch+1:2d}: {avg_loss:.4f}", flush=True)
            iter_loss += avg_loss
        
        avg_iter_loss = iter_loss / EPOCHS_PER_ITERATION
        loss_history.append(avg_iter_loss)
        
        # Save checkpoint
        ckpt_path = checkpoint_dir / f"checkpoint_iter_{iteration:02d}.pth"
        torch.save({
            'iteration': iteration,
            'model_state_dict': model.state_dict(),
            'optimizer_state_dict': optimizer.state_dict(),
            'loss': avg_iter_loss,
        }, ckpt_path)
        
        # Timing
        iter_time = time.time() - iter_start
        total_time = time.time() - training_start
        avg_per_iter = total_time / iteration
        remaining = (NUM_ITERATIONS - iteration) * avg_per_iter
        
        # GPU memory
        allocated = torch.cuda.memory_allocated(0) / 1e9
        reserved = torch.cuda.memory_reserved(0) / 1e9
        utilization = (allocated / total_vram) * 100
        
        print(f"\n💾 Saved: {ckpt_path.name} | Loss: {avg_iter_loss:.4f}")
        print(f"⏱️  Time: {iter_time:.0f}s this iter | {remaining/60:.1f}min remaining")
        print(f"📊 GPU: {allocated:.2f}GB / {total_vram:.1f}GB ({utilization:.0f}% used)")
        
        if len(loss_history) >= 2:
            change = loss_history[-1] - loss_history[-2]
            trend = "📉" if change < 0 else "📈"
            print(f"{trend} Loss: {change:+.4f}")
    
    # Complete
    total_time = time.time() - training_start
    
    print("\n" + "=" * 70)
    print("✅ TRAINING COMPLETE!")
    print("=" * 70)
    print(f"\n⏱️  Total: {total_time/60:.1f} minutes")
    print(f"🎮 Games: {NUM_ITERATIONS * GAMES_PER_ITERATION}")
    print(f"📉 Loss: {loss_history[0]:.4f} → {loss_history[-1]:.4f}")
    print(f"📈 Improvement: {loss_history[0] - loss_history[-1]:.4f}")
    
    # Loss chart
    print(f"\n📊 Loss Progression:")
    max_loss = max(loss_history)
    for i, loss in enumerate(loss_history, 1):
        bar_len = int(40 * (1 - loss / max_loss)) if max_loss > 0 else 0
        bar = "█" * bar_len
        print(f"   {i:2d}: {loss:.4f} {bar}")
    
    # Final model
    final_path = checkpoint_dir / "chess_fast_final.pth"
    torch.save({
        'model_state_dict': model.state_dict(),
        'config': {
            'iterations': NUM_ITERATIONS,
            'games_per_iteration': GAMES_PER_ITERATION,
            'final_loss': loss_history[-1],
        }
    }, final_path)
    
    print(f"\n💾 Final: {final_path.name}")
    print(f"\n🎯 Next: python trainer/analyze_training.py")

if __name__ == "__main__":
    train_fast()
