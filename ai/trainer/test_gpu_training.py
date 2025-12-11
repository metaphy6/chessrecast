"""
Mini GPU training test - 1 iteration, 3 games.
Tests the complete GPU-accelerated training pipeline.
"""
import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import Dataset, DataLoader
import sys
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

def main():
    print("=" * 60)
    print("Mini GPU Training Test")
    print("=" * 60)
    
    # GPU enforcement
    if not torch.cuda.is_available():
        print("\n❌ GPU not available!")
        sys.exit(1)
    
    DEVICE = 'cuda'
    print(f"\n🚀 GPU: {torch.cuda.get_device_name(0)}")
    print(f"   VRAM: {torch.cuda.get_device_properties(0).total_memory / 1e9:.1f} GB")
    
    # Enable optimizations
    torch.backends.cudnn.benchmark = True
    torch.backends.cuda.matmul.allow_tf32 = True
    print("   ✓ Optimizations enabled")
    
    # Create model
    model = ChessNetPOC(num_channels=64).to(DEVICE)
    print(f"\n🧠 Model: {count_parameters(model):,} parameters")
    
    # Optimizer & mixed precision
    optimizer = optim.Adam(model.parameters(), lr=0.001)
    scaler = torch.cuda.amp.GradScaler()
    loss_fn = nn.MSELoss()
    print("   ✓ Mixed precision enabled")
    
    # Self-play
    print("\n🎲 Playing 3 games...")
    self_play = SimpleSelfPlay(model, device=DEVICE)
    all_data = []
    
    with torch.no_grad():
        for i in range(3):
            game_history = self_play.play_game(temperature=1.0)
            all_data.extend(game_history)
            print(f"   Game {i+1}: {len(game_history)} positions")
    
    print(f"\n   Total: {len(all_data)} positions")
    
    # Training
    print("\n🎓 Training 2 epochs...")
    dataset = ChessDataset(all_data)
    dataloader = DataLoader(dataset, batch_size=32, shuffle=True, pin_memory=True)
    
    model.train()
    for epoch in range(2):
        epoch_loss = 0
        for states, _, values in tqdm(dataloader, desc=f"Epoch {epoch+1}"):
            states = states.to(DEVICE, non_blocking=True)
            values = values.to(DEVICE, non_blocking=True)
            
            optimizer.zero_grad(set_to_none=True)
            
            with torch.cuda.amp.autocast():
                _, value_pred = model(states)
                loss = loss_fn(value_pred, values)
            
            scaler.scale(loss).backward()
            scaler.step(optimizer)
            scaler.update()
            
            epoch_loss += loss.item()
        
        print(f"   Epoch {epoch+1} Loss: {epoch_loss / len(dataloader):.4f}")
    
    # Save checkpoint
    checkpoint_dir = Path('/workspace/checkpoints')
    checkpoint_dir.mkdir(exist_ok=True)
    checkpoint_path = checkpoint_dir / "mini_gpu_test.pth"
    torch.save({'model_state_dict': model.state_dict()}, checkpoint_path)
    
    print(f"\n💾 Saved: {checkpoint_path}")
    print(f"📊 GPU Memory: {torch.cuda.memory_allocated(0) / 1e9:.2f} GB")
    
    print("\n" + "=" * 60)
    print("✅ GPU Training Test Complete!")
    print("=" * 60)
    print("\nReady for full training:")
    print("  docker-compose -f docker-compose.poc.yml up")

if __name__ == "__main__":
    main()
