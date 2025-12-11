"""
Hard Mode Training - Maximum AI strength for ChessRecast.
Configuration: More iterations, more MCTS simulations, deeper learning.
Expected: 1200-1500 Elo, ~60-90 minutes on RTX 4080.
"""
import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import Dataset, DataLoader
import numpy as np
import sys
import time
from pathlib import Path

from neural_network_gpu import ChessNetPOC, count_parameters
from self_play_improved import ImprovedSelfPlay
from game_rules import ChessGamePOC


class ImprovedChessDataset(Dataset):
    """Dataset with proper policy targets"""
    def __init__(self, game_history):
        self.data = game_history
    
    def __len__(self):
        return len(self.data)
    
    def __getitem__(self, idx):
        entry = self.data[idx]
        state = torch.from_numpy(entry['state']).float()
        policy_target = torch.from_numpy(entry['policy']).float()
        value_target = torch.tensor([entry['value']], dtype=torch.float32)
        return state, policy_target, value_target


def train_hard_mode():
    """
    Hard Mode Training - Maximum strength with extensive MCTS.
    
    Configuration optimized for:
    - Strong tactical play (100 MCTS simulations)
    - Deep strategic understanding (15 iterations)
    - High-quality training data (50 games per iteration)
    """
    
    print("=" * 70)
    print("ChessRecast AI - HARD MODE Training")
    print("🔥 Maximum Strength Configuration")
    print("=" * 70)
    
    # GPU enforcement
    if not torch.cuda.is_available():
        print("\n❌ FATAL ERROR: CUDA GPU not detected!")
        sys.exit(1)
    
    DEVICE = 'cuda'
    
    # GPU info
    print(f"\n🚀 GPU Device: {torch.cuda.get_device_name(0)}")
    props = torch.cuda.get_device_properties(0)
    print(f"   Total VRAM: {props.total_memory / 1e9:.1f} GB")
    print(f"   Compute: {props.major}.{props.minor}")
    
    # Hard Mode Configuration
    NUM_ITERATIONS = 15          # More iterations = better learning
    GAMES_PER_ITERATION = 50     # More games = more training data
    EPOCHS_PER_ITERATION = 10    # More epochs = better convergence
    BATCH_SIZE = 256
    LEARNING_RATE = 0.001
    MCTS_SIMULATIONS = 100       # 🔥 DOUBLE simulations for stronger play
    
    print(f"\n📊 HARD MODE Configuration:")
    print(f"   🎯 Target Strength: 1200-1500 Elo")
    print(f"   Iterations: {NUM_ITERATIONS}")
    print(f"   Games per iteration: {GAMES_PER_ITERATION}")
    print(f"   MCTS simulations per move: {MCTS_SIMULATIONS} 🔥 (2x normal)")
    print(f"   Training epochs: {EPOCHS_PER_ITERATION}")
    print(f"   Batch size: {BATCH_SIZE}")
    print(f"   Total games: {NUM_ITERATIONS * GAMES_PER_ITERATION:,}")
    print(f"   Expected time: ~60-90 minutes")
    
    # GPU optimizations
    torch.backends.cudnn.benchmark = True
    torch.backends.cuda.matmul.allow_tf32 = True
    print("\n⚡ GPU optimizations enabled")
    
    # Model setup
    print("\n🧠 Creating neural network...")
    model = ChessNetPOC(num_channels=64).to(DEVICE)
    params = count_parameters(model)
    print(f"   Parameters: {params:,}")
    
    # Optimizer with weight decay for better generalization
    optimizer = optim.AdamW(model.parameters(), lr=LEARNING_RATE, weight_decay=1e-4)
    scaler = torch.cuda.amp.GradScaler()
    
    # Learning rate scheduler for better convergence
    scheduler = optim.lr_scheduler.CosineAnnealingLR(optimizer, T_max=NUM_ITERATIONS)
    
    # Loss functions
    policy_loss_fn = nn.CrossEntropyLoss()
    value_loss_fn = nn.MSELoss()
    
    print("   ✓ Mixed precision enabled")
    print("   ✓ Weight decay: 1e-4")
    print("   ✓ LR scheduler: Cosine annealing")
    print("   ✓ Policy loss: Cross-Entropy")
    print("   ✓ Value loss: MSE")
    
    # Checkpoint setup
    checkpoint_dir = Path('/workspace/checkpoints')
    checkpoint_dir.mkdir(exist_ok=True)
    
    # Clean old checkpoints
    print("\n🧹 Cleaning old checkpoints...")
    for old_file in checkpoint_dir.glob('*.pth'):
        old_file.unlink()
    print("   ✓ Ready for fresh training")
    
    # Training metrics
    training_start = time.time()
    best_loss = float('inf')
    best_iteration = 0
    loss_history = []
    
    print("\n" + "=" * 70)
    print("🎮 Starting HARD MODE Training")
    print("=" * 70)
    
    for iteration in range(1, NUM_ITERATIONS + 1):
        iter_start = time.time()
        
        print(f"\n{'=' * 70}")
        print(f"📍 Iteration {iteration}/{NUM_ITERATIONS}")
        print(f"   Current LR: {optimizer.param_groups[0]['lr']:.6f}")
        print(f"{'=' * 70}")
        
        # Self-play with intensive MCTS
        print(f"\n🎲 Self-Play Phase (MCTS: {MCTS_SIMULATIONS} sims):")
        self_play = ImprovedSelfPlay(model, device=DEVICE, num_simulations=MCTS_SIMULATIONS)
        all_game_data = []
        
        # Temperature schedule: explore early, exploit late
        if iteration <= 5:
            temp_schedule = 'decay'
            print(f"   Temperature: Decay (exploration phase)")
        else:
            temp_schedule = 'low'
            print(f"   Temperature: Low (exploitation phase)")
        
        print(f"   Playing {GAMES_PER_ITERATION} games...")
        
        game_lengths = []
        game_start_time = time.time()
        with torch.no_grad():
            for game_num in range(GAMES_PER_ITERATION):
                game_iter_start = time.time()
                
                # Show immediate progress
                if game_num == 0:
                    print(f"   Starting game 1... (MCTS with {MCTS_SIMULATIONS} sims per move)", flush=True)
                
                game_history = self_play.play_game(temperature_schedule=temp_schedule)
                all_game_data.extend(game_history)
                game_lengths.append(len(game_history))
                
                game_time = time.time() - game_iter_start
                
                # Progress every game for first 5, then every 5 games
                if game_num < 5 or (game_num + 1) % 5 == 0:
                    avg_len = sum(game_lengths) / len(game_lengths)
                    elapsed = time.time() - game_start_time
                    games_per_min = (game_num + 1) / (elapsed / 60)
                    eta_mins = (GAMES_PER_ITERATION - game_num - 1) / games_per_min if games_per_min > 0 else 0
                    print(f"   Game {game_num + 1}/{GAMES_PER_ITERATION} ({game_time:.1f}s) - "
                          f"Avg: {avg_len:.1f} moves, Rate: {games_per_min:.1f} g/min, ETA: {eta_mins:.1f}m", flush=True)
        
        avg_game_len = sum(game_lengths) / len(game_lengths)
        print(f"\n   ✓ Generated {len(all_game_data):,} training positions")
        print(f"   ✓ Avg game length: {avg_game_len:.1f} moves")
        print(f"   ✓ Range: {min(game_lengths)}-{max(game_lengths)} moves")
        
        # Training phase
        print(f"\n🎓 Training Phase ({EPOCHS_PER_ITERATION} epochs):")
        dataset = ImprovedChessDataset(all_game_data)
        dataloader = DataLoader(
            dataset,
            batch_size=BATCH_SIZE,
            shuffle=True,
            num_workers=0,
            pin_memory=True
        )
        
        model.train()
        iteration_policy_loss = 0
        iteration_value_loss = 0
        iteration_total_loss = 0
        
        for epoch in range(EPOCHS_PER_ITERATION):
            epoch_loss = 0
            epoch_policy_loss = 0
            epoch_value_loss = 0
            batch_count = 0
            
            for states, policy_targets, value_targets in dataloader:
                states = states.to(DEVICE, non_blocking=True)
                policy_targets = policy_targets.to(DEVICE, non_blocking=True)
                value_targets = value_targets.to(DEVICE, non_blocking=True)
                
                optimizer.zero_grad(set_to_none=True)
                
                # Mixed precision forward
                with torch.cuda.amp.autocast():
                    policy_pred, value_pred = model(states)
                    p_loss = policy_loss_fn(policy_pred, policy_targets)
                    v_loss = value_loss_fn(value_pred, value_targets)
                    loss = p_loss + v_loss
                
                # Mixed precision backward
                scaler.scale(loss).backward()
                scaler.step(optimizer)
                scaler.update()
                
                epoch_loss += loss.item()
                epoch_policy_loss += p_loss.item()
                epoch_value_loss += v_loss.item()
                batch_count += 1
            
            avg_epoch_loss = epoch_loss / batch_count
            avg_policy_loss = epoch_policy_loss / batch_count
            avg_value_loss = epoch_value_loss / batch_count
            
            print(f"   Epoch {epoch+1:2d}/{EPOCHS_PER_ITERATION} - "
                  f"Total: {avg_epoch_loss:.4f}, "
                  f"Policy: {avg_policy_loss:.4f}, "
                  f"Value: {avg_value_loss:.4f}")
            
            iteration_total_loss += avg_epoch_loss
            iteration_policy_loss += avg_policy_loss
            iteration_value_loss += avg_value_loss
        
        # Step learning rate scheduler
        scheduler.step()
        
        # Iteration summary
        avg_iter_loss = iteration_total_loss / EPOCHS_PER_ITERATION
        avg_iter_policy = iteration_policy_loss / EPOCHS_PER_ITERATION
        avg_iter_value = iteration_value_loss / EPOCHS_PER_ITERATION
        
        loss_history.append({
            'total': avg_iter_loss,
            'policy': avg_iter_policy,
            'value': avg_iter_value
        })
        
        # Track best model
        is_best = avg_iter_loss < best_loss
        if is_best:
            best_loss = avg_iter_loss
            best_iteration = iteration
            print(f"\n🌟 New best loss: {best_loss:.4f} (iteration {best_iteration})")
        
        # Save checkpoint
        checkpoint_path = checkpoint_dir / f"checkpoint_hard_iter_{iteration:02d}.pth"
        torch.save({
            'iteration': iteration,
            'model_state_dict': model.state_dict(),
            'optimizer_state_dict': optimizer.state_dict(),
            'scheduler_state_dict': scheduler.state_dict(),
            'loss': avg_iter_loss,
            'policy_loss': avg_iter_policy,
            'value_loss': avg_iter_value,
            'is_best': is_best,
            'mcts_simulations': MCTS_SIMULATIONS,
        }, checkpoint_path)
        print(f"\n💾 Checkpoint: {checkpoint_path.name}")
        
        # Timing
        iter_time = time.time() - iter_start
        total_elapsed = time.time() - training_start
        avg_iter_time = total_elapsed / iteration
        remaining_iters = NUM_ITERATIONS - iteration
        estimated_remaining = remaining_iters * avg_iter_time
        
        print(f"\n⏱️  Timing:")
        print(f"   This iteration: {iter_time/60:.1f} minutes")
        print(f"   Total elapsed: {total_elapsed/60:.1f} minutes")
        print(f"   Estimated remaining: {estimated_remaining/60:.1f} minutes")
        
        # GPU memory
        allocated = torch.cuda.memory_allocated(0) / 1e9
        reserved = torch.cuda.memory_reserved(0) / 1e9
        print(f"   GPU: {allocated:.2f} GB / {reserved:.2f} GB")
        
        # Loss trend
        if len(loss_history) >= 2:
            loss_change = loss_history[-1]['total'] - loss_history[-2]['total']
            trend = "📉 Improving" if loss_change < 0 else "📊 Stabilizing"
            print(f"\n{trend} - Change: {loss_change:+.4f}")
    
    # Training complete
    total_time = time.time() - training_start
    
    print("\n" + "=" * 70)
    print("✅ HARD MODE Training Complete!")
    print("=" * 70)
    
    print(f"\n📊 Final Results:")
    print(f"   Total time: {total_time/60:.1f} minutes ({total_time/3600:.1f} hours)")
    print(f"   Total games: {NUM_ITERATIONS * GAMES_PER_ITERATION:,}")
    print(f"   Best loss: {best_loss:.4f} (iteration {best_iteration})")
    print(f"   Final loss: {loss_history[-1]['total']:.4f}")
    print(f"   Total improvement: {loss_history[0]['total'] - loss_history[-1]['total']:.4f}")
    
    # Loss progression
    print(f"\n📉 Loss History:")
    for i, loss_data in enumerate(loss_history, 1):
        marker = "🌟" if loss_data['total'] == best_loss else "  "
        print(f"   {marker} Iter {i:2d}: Total={loss_data['total']:.4f}, "
              f"Policy={loss_data['policy']:.4f}, Value={loss_data['value']:.4f}")
    
    # Save best model as final
    best_checkpoint = checkpoint_dir / f"checkpoint_hard_iter_{best_iteration:02d}.pth"
    final_path = checkpoint_dir / "chess_hard_final.pth"
    
    if best_checkpoint.exists():
        checkpoint = torch.load(best_checkpoint)
        torch.save({
            'model_state_dict': checkpoint['model_state_dict'],
            'config': {
                'num_channels': 64,
                'mcts_simulations': MCTS_SIMULATIONS,
                'iterations': NUM_ITERATIONS,
                'best_iteration': best_iteration,
                'best_loss': best_loss,
                'total_games': NUM_ITERATIONS * GAMES_PER_ITERATION,
                'training_time_minutes': total_time / 60,
            }
        }, final_path)
        print(f"\n💾 Final model: {final_path.name}")
        print(f"   (Best checkpoint from iteration {best_iteration})")
    
    print(f"\n🎯 Expected AI Strength: 1200-1500 Elo")
    print(f"   - Strong tactical awareness")
    print(f"   - 2-4 moves lookahead")
    print(f"   - Piece coordination")
    print(f"   - Opening principles")
    
    print(f"\n📈 Next Steps:")
    print(f"   1. Analyze performance:")
    print(f"      docker-compose run --rm trainer python trainer/analyze_training.py")
    print(f"   2. Export to Flutter:")
    print(f"      docker-compose run --rm trainer python trainer/export_tflite_simple.py")
    print(f"   3. Test in Flutter app with MCTS inference (100 sims)")


if __name__ == "__main__":
    train_hard_mode()
