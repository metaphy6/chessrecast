"""
GPU-Optimized POC Training script with performance enhancements.
- Enforces GPU requirement
- Mixed precision training (FP16)
- Optimized data loading
- TensorCore utilization
"""
import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import Dataset, DataLoader
import numpy as np
import sys
from pathlib import Path
from tqdm import tqdm

from neural_network_gpu import ChessNetPOC, count_parameters
from self_play import SimpleSelfPlay
from game_rules import ChessGamePOC

class ChessDataset(Dataset):
    """Dataset from self-play games"""
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

def train_poc_gpu():
    """GPU-optimized training function"""
    
    print("=" * 70)
    print("ChessRecast AI POC - GPU-Accelerated Training")
    print("=" * 70)
    
    # ========== GPU ENFORCEMENT ==========
    if not torch.cuda.is_available():
        print("\n❌ FATAL ERROR: CUDA GPU not detected!")
        print("\nThis training requires a NVIDIA GPU with CUDA support.")
        print("\nPlease ensure:")
        print("  1. NVIDIA GPU drivers are installed")
        print("  2. Docker Desktop has GPU support enabled")
        print("  3. NVIDIA Container Toolkit is installed")
        print("  4. Docker compose file has 'runtime: nvidia' configured")
        print("\nRun: nvidia-smi (to verify GPU)")
        sys.exit(1)
    
    DEVICE = 'cuda'
    
    # ========== GPU INFO ==========
    print(f"\n🚀 GPU Device: {torch.cuda.get_device_name(0)}")
    props = torch.cuda.get_device_properties(0)
    print(f"   Compute Capability: {props.major}.{props.minor}")
    print(f"   Total VRAM: {props.total_memory / 1e9:.1f} GB")
    print(f"   Available VRAM: {torch.cuda.memory_allocated(0) / 1e9:.2f} GB")
    
    # ========== CONFIGURATION ==========
    NUM_ITERATIONS = 5
    GAMES_PER_ITERATION = 50
    EPOCHS_PER_ITERATION = 5
    BATCH_SIZE = 64  # Larger batch for GPU
    LEARNING_RATE = 0.001
    NUM_WORKERS = 4  # Parallel data loading
    
    print(f"\n📊 Training Configuration:")
    print(f"   Iterations: {NUM_ITERATIONS}")
    print(f"   Games per iteration: {GAMES_PER_ITERATION}")
    print(f"   Training epochs: {EPOCHS_PER_ITERATION}")
    print(f"   Batch size: {BATCH_SIZE}")
    print(f"   Learning rate: {LEARNING_RATE}")
    print(f"   Data workers: {NUM_WORKERS}")
    
    # ========== GPU OPTIMIZATIONS ==========
    print("\n⚡ Enabling GPU optimizations...")
    torch.backends.cudnn.benchmark = True  # Auto-tune kernels
    torch.backends.cuda.matmul.allow_tf32 = True  # TensorFloat-32
    torch.backends.cudnn.allow_tf32 = True
    print("   ✓ cuDNN benchmark mode")
    print("   ✓ TensorFloat-32 enabled")
    
    # ========== MODEL SETUP ==========
    print("\n🧠 Creating neural network...")
    model = ChessNetPOC(num_channels=64).to(DEVICE)
    params = count_parameters(model)
    print(f"   Parameters: {params:,}")
    print(f"   Memory: ~{params * 4 / 1e6:.1f} MB")
    
    # ========== OPTIMIZER & MIXED PRECISION ==========
    optimizer = optim.Adam(model.parameters(), lr=LEARNING_RATE)
    scaler = torch.cuda.amp.GradScaler()  # Mixed precision training
    value_loss_fn = nn.MSELoss()
    print("   ✓ Adam optimizer")
    print("   ✓ Mixed precision (FP16) enabled")
    
    # ========== CHECKPOINT SETUP ==========
    checkpoint_dir = Path('/workspace/checkpoints')
    checkpoint_dir.mkdir(exist_ok=True)
    
    # ========== TRAINING LOOP ==========
    print("\n" + "=" * 70)
    print("🎮 Starting Training Loop")
    print("=" * 70)
    
    for iteration in range(1, NUM_ITERATIONS + 1):
        print(f"\n{'=' * 70}")
        print(f"📍 Iteration {iteration}/{NUM_ITERATIONS}")
        print(f"{'=' * 70}")
        
        # ===== SELF-PLAY PHASE =====
        print("\n🎲 Self-Play Phase:")
        self_play = SimpleSelfPlay(model, device=DEVICE)
        all_game_data = []
        
        with torch.no_grad():  # No gradients during self-play
            for game_num in tqdm(range(GAMES_PER_ITERATION), desc="Games"):
                game_history = self_play.play_game(temperature=1.0)
                all_game_data.extend(game_history)
        
        print(f"   Generated {len(all_game_data):,} training positions")
        
        # ===== TRAINING PHASE =====
        print("\n🎓 Training Phase:")
        dataset = ChessDataset(all_game_data)
        dataloader = DataLoader(
            dataset,
            batch_size=BATCH_SIZE,
            shuffle=True,
            num_workers=NUM_WORKERS,
            pin_memory=True,  # Faster CPU->GPU transfer
            persistent_workers=True if NUM_WORKERS > 0 else False,
            prefetch_factor=2 if NUM_WORKERS > 0 else None
        )
        
        model.train()
        iteration_loss = 0
        
        for epoch in range(EPOCHS_PER_ITERATION):
            epoch_loss = 0
            batch_count = 0
            
            pbar = tqdm(dataloader, desc=f"Epoch {epoch+1}/{EPOCHS_PER_ITERATION}")
            for states, policy_targets, value_targets in pbar:
                # Non-blocking transfer to GPU
                states = states.to(DEVICE, non_blocking=True)
                value_targets = value_targets.to(DEVICE, non_blocking=True)
                
                # Clear gradients (set_to_none is faster)
                optimizer.zero_grad(set_to_none=True)
                
                # ===== MIXED PRECISION FORWARD PASS =====
                with torch.cuda.amp.autocast():
                    policy_pred, value_pred = model(states)
                    loss = value_loss_fn(value_pred, value_targets)
                
                # ===== MIXED PRECISION BACKWARD PASS =====
                scaler.scale(loss).backward()
                scaler.step(optimizer)
                scaler.update()
                
                epoch_loss += loss.item()
                batch_count += 1
                
                # Update progress bar
                pbar.set_postfix({'loss': f'{loss.item():.4f}'})
            
            avg_epoch_loss = epoch_loss / batch_count
            print(f"   Epoch {epoch+1} - Avg Loss: {avg_epoch_loss:.4f}")
            iteration_loss += avg_epoch_loss
        
        avg_iteration_loss = iteration_loss / EPOCHS_PER_ITERATION
        
        # ===== SAVE CHECKPOINT =====
        checkpoint_path = checkpoint_dir / f"checkpoint_iter_{iteration}.pth"
        torch.save({
            'iteration': iteration,
            'model_state_dict': model.state_dict(),
            'optimizer_state_dict': optimizer.state_dict(),
            'scaler_state_dict': scaler.state_dict(),
            'loss': avg_iteration_loss,
        }, checkpoint_path)
        print(f"\n💾 Checkpoint saved: {checkpoint_path}")
        print(f"   Iteration loss: {avg_iteration_loss:.4f}")
        
        # ===== GPU MEMORY STATUS =====
        allocated = torch.cuda.memory_allocated(0) / 1e9
        reserved = torch.cuda.memory_reserved(0) / 1e9
        print(f"\n📊 GPU Memory: {allocated:.2f} GB allocated, {reserved:.2f} GB reserved")
    
    # ========== TRAINING COMPLETE ==========
    print("\n" + "=" * 70)
    print("✅ Training Complete!")
    print("=" * 70)
    
    # Save final model
    final_path = checkpoint_dir / "chess_classic_poc.pth"
    torch.save({
        'model_state_dict': model.state_dict(),
        'config': {
            'num_channels': 64,
            'iterations': NUM_ITERATIONS,
            'games_per_iteration': GAMES_PER_ITERATION,
        }
    }, final_path)
    print(f"\n💾 Final model saved: {final_path}")
    print(f"\nNext steps:")
    print(f"  1. Export to TFLite: python trainer/export_tflite.py")
    print(f"  2. Copy to Flutter: docker cp chessrecast-ai-poc:/workspace/checkpoints/chess_classic_poc.tflite frontend/assets/models/")
    print(f"  3. Test in app: flutter run")

if __name__ == "__main__":
    train_poc_gpu()
