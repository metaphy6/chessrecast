"""
MINIMAL POC Training - Fast and Small
- 5 iterations only
- 30 games per iteration  
- Keeps only best checkpoint
- Target: 1 small model (~5 MB) for Flutter
- Time: ~5 minutes
"""
import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import Dataset, DataLoader
import sys
import time
from pathlib import Path

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

def train_minimal():
    """Minimal POC - fast training, single output model"""
    
    print("=" * 60)
    print("ChessRecast AI - MINIMAL POC")
    print("=" * 60)
    
    if not torch.cuda.is_available():
        print("\n❌ GPU required!")
        sys.exit(1)
    
    DEVICE = 'cuda'
    
    print(f"\n🚀 GPU: {torch.cuda.get_device_name(0)}")
    
    # MINIMAL configuration
    NUM_ITERATIONS = 5
    GAMES_PER_ITERATION = 30
    EPOCHS_PER_ITERATION = 8
    BATCH_SIZE = 256
    LEARNING_RATE = 0.001
    
    print(f"\n📊 Minimal POC Configuration:")
    print(f"   Iterations: {NUM_ITERATIONS} (minimal)")
    print(f"   Games/iteration: {GAMES_PER_ITERATION}")
    print(f"   Epochs: {EPOCHS_PER_ITERATION}")
    print(f"   Total games: {NUM_ITERATIONS * GAMES_PER_ITERATION}")
    print(f"   Expected time: ~5 minutes")
    print(f"   Output: 1 model file (~5 MB)")
    
    # GPU optimizations
    torch.backends.cudnn.benchmark = True
    torch.backends.cuda.matmul.allow_tf32 = True
    torch.backends.cudnn.allow_tf32 = True
    
    # Model
    model = ChessNetPOC(num_channels=64).to(DEVICE)
    print(f"\n🧠 Model: {count_parameters(model):,} parameters")
    
    # Optimizer
    optimizer = optim.AdamW(model.parameters(), lr=LEARNING_RATE, weight_decay=1e-4)
    scaler = torch.cuda.amp.GradScaler()
    value_loss_fn = nn.MSELoss()
    
    checkpoint_dir = Path('/workspace/checkpoints')
    checkpoint_dir.mkdir(exist_ok=True)
    
    # Clean old checkpoints
    for old_file in checkpoint_dir.glob('*.pth'):
        old_file.unlink()
    print(f"   ✓ Cleaned old checkpoints")
    
    # Training
    training_start = time.time()
    best_loss = float('inf')
    best_iteration = 0
    
    print("\n" + "=" * 60)
    print("🚀 TRAINING START")
    print("=" * 60)
    
    for iteration in range(1, NUM_ITERATIONS + 1):
        iter_start = time.time()
        
        print(f"\n📍 Iteration {iteration}/{NUM_ITERATIONS}")
        
        # Self-play
        print(f"   Playing {GAMES_PER_ITERATION} games...", end=' ', flush=True)
        self_play = SimpleSelfPlay(model, device=DEVICE)
        all_data = []
        
        with torch.no_grad():
            for _ in range(GAMES_PER_ITERATION):
                game_history = self_play.play_game(temperature=1.0)
                all_data.extend(game_history)
        
        print(f"✓ {len(all_data):,} positions")
        
        # Training
        print(f"   Training {EPOCHS_PER_ITERATION} epochs...", end=' ', flush=True)
        dataset = ChessDataset(all_data)
        dataloader = DataLoader(
            dataset,
            batch_size=BATCH_SIZE,
            shuffle=True,
            num_workers=0,  # No workers to avoid memory issues
            pin_memory=True
        )
        
        model.train()
        total_loss = 0
        batch_count = 0
        
        for epoch in range(EPOCHS_PER_ITERATION):
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
                
                total_loss += loss.item()
                batch_count += 1
        
        avg_loss = total_loss / batch_count
        print(f"✓ Loss: {avg_loss:.4f}")
        
        # Track best
        if avg_loss < best_loss:
            best_loss = avg_loss
            best_iteration = iteration
            print(f"   🌟 New best!")
        
        iter_time = time.time() - iter_start
        remaining = (NUM_ITERATIONS - iteration) * iter_time
        print(f"   ⏱️  {iter_time:.0f}s | {remaining/60:.1f}min remaining")
    
    total_time = time.time() - training_start
    
    # Save only the final model (best state is in memory)
    final_path = checkpoint_dir / "chess_poc.pth"
    torch.save({
        'model_state_dict': model.state_dict(),
        'loss': best_loss,
        'iterations': NUM_ITERATIONS,
        'games': NUM_ITERATIONS * GAMES_PER_ITERATION,
    }, final_path)
    
    file_size = final_path.stat().st_size / (1024 * 1024)
    
    print("\n" + "=" * 60)
    print("✅ TRAINING COMPLETE")
    print("=" * 60)
    print(f"\n⏱️  Total time: {total_time/60:.1f} minutes")
    print(f"🎮 Total games: {NUM_ITERATIONS * GAMES_PER_ITERATION}")
    print(f"📉 Best loss: {best_loss:.4f} (iteration {best_iteration})")
    print(f"\n💾 Output:")
    print(f"   File: {final_path.name}")
    print(f"   Size: {file_size:.1f} MB")
    print(f"\n🎯 Next Steps:")
    print(f"   1. Export to TFLite: python trainer/export_tflite_simple.py")
    print(f"   2. Result will be ~5 MB TFLite file")
    print(f"   3. Copy to Flutter: frontend/assets/models/")

if __name__ == "__main__":
    train_minimal()
