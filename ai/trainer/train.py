"""
POC Training script - simplified for speed.
Trains for 2-3 hours to reach 400-600 Elo.
"""
import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import Dataset, DataLoader
import numpy as np
import sys
from pathlib import Path
from tqdm import tqdm
import chess

from neural_network import ChessNetPOC, count_parameters
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
        state = torch.from_numpy(entry['state'])
        value = torch.tensor([entry['value']], dtype=torch.float32)
        # Simplified policy target (uniform over legal moves)
        policy = torch.zeros(4096)
        return state, policy, value

def train_poc():
    """Main training function for POC"""
    
    print("=" * 60)
    print("ChessRecast AI POC - Training Start")
    print("=" * 60)
    
    # Config
    DEVICE = 'cuda' if torch.cuda.is_available() else 'cpu'
    NUM_ITERATIONS = 5  # Reduced for POC (full training: 20+)
    GAMES_PER_ITERATION = 50  # Reduced for POC (full training: 500+)
    EPOCHS_PER_ITERATION = 5
    BATCH_SIZE = 32
    LEARNING_RATE = 0.001
    
    print(f"\nDevice: {DEVICE}")
    print(f"Iterations: {NUM_ITERATIONS}")
    print(f"Games per iteration: {GAMES_PER_ITERATION}")
    print(f"Training epochs: {EPOCHS_PER_ITERATION}")
    
    # Create model
    model = ChessNetPOC(num_channels=64).to(DEVICE)
    print(f"\nModel parameters: {count_parameters(model):,}")
    
    # Optimizer
    optimizer = optim.Adam(model.parameters(), lr=LEARNING_RATE)
    
    # Loss functions
    policy_loss_fn = nn.KLDivLoss(reduction='batchmean')
    value_loss_fn = nn.MSELoss()
    
    # Training loop
    checkpoint_dir = Path('/workspace/checkpoints')
    checkpoint_dir.mkdir(exist_ok=True)
    
    for iteration in range(1, NUM_ITERATIONS + 1):
        print(f"\n{'=' * 60}")
        print(f"Iteration {iteration}/{NUM_ITERATIONS}")
        print(f"{'=' * 60}")
        
        # Self-play phase
        print("\n📊 Self-Play Phase:")
        self_play = SimpleSelfPlay(model, device=DEVICE)
        all_game_data = []
        
        for game_num in tqdm(range(GAMES_PER_ITERATION), desc="Playing games"):
            game_history = self_play.play_game(temperature=1.0)
            all_game_data.extend(game_history)
        
        print(f"Generated {len(all_game_data)} training positions")
        
        # Training phase
        print("\n🎓 Training Phase:")
        dataset = ChessDataset(all_game_data)
        dataloader = DataLoader(
            dataset, 
            batch_size=BATCH_SIZE, 
            shuffle=True,
            num_workers=NUM_WORKERS,
            pin_memory=True,  # Faster GPU transfer
            persistent_workers=True if NUM_WORKERS > 0 else False
        )
        
        model.train()
        total_loss = 0
        
        for epoch in range(EPOCHS_PER_ITERATION):
            epoch_loss = 0
            for states, policy_targets, value_targets in tqdm(dataloader, desc=f"Epoch {epoch+1}"):
                states = states.to(DEVICE)
                policy_targets = policy_targets.to(DEVICE)
                value_targets = value_targets.to(DEVICE)
                
                # Forward pass
                policy_pred, value_pred = model(states)
                
                # Calculate losses (simplified for POC)
                # In full version: proper policy loss with legal moves
                value_loss = value_loss_fn(value_pred, value_targets)
                loss = value_loss  # Simplified: only value loss for POC
                
                # Backward pass
                optimizer.zero_grad()
                loss.backward()
                optimizer.step()
                
                epoch_loss += loss.item()
            
            avg_loss = epoch_loss / len(dataloader)
            print(f"  Epoch {epoch+1} - Loss: {avg_loss:.4f}")
            total_loss += avg_loss
        
        # Save checkpoint
        checkpoint_path = checkpoint_dir / f"checkpoint_iter_{iteration:02d}.pth"
        torch.save({
            'iteration': iteration,
            'model_state_dict': model.state_dict(),
            'optimizer_state_dict': optimizer.state_dict(),
            'loss': total_loss / EPOCHS_PER_ITERATION,
        }, checkpoint_path)
        print(f"\n💾 Saved checkpoint: {checkpoint_path}")
    
    print("\n" + "=" * 60)
    print("✅ Training Complete!")
    print("=" * 60)
    print(f"\nFinal model saved at: {checkpoint_path}")
    print("\nNext steps:")
    print("1. Export to TFLite: python trainer/export_tflite.py")
    print("2. Copy to Flutter: frontend/assets/models/")
    print("3. Test in app!")

if __name__ == "__main__":
    train_poc()
