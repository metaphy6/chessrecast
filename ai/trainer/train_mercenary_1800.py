"""
Mercenary Mode AI Training - Target 1800 ELO
Maximum GPU utilization with advanced training techniques.

Training Strategy:
- Mercenary mode: Pawns change color when captured
- Policy-guided MCTS with 100-200 simulations
- Larger network (128 channels, 10 residual blocks)
- Aggressive GPU batching (512-1024 batch size)
- Advanced techniques: curriculum learning, position diversity
- Expected: 1800 ELO after 200+ iterations
"""
import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import Dataset, DataLoader
import numpy as np
import sys
import time
import chess
from pathlib import Path
from tqdm import tqdm
import json
import subprocess
import threading

from neural_network_gpu import ChessNetPOC, count_parameters
from self_play_improved import ImprovedSelfPlay
from save_training_games import GameRecorder
from websocket_server import get_websocket_server

# GPU Monitoring
def get_gpu_utilization():
    """Get current GPU utilization percentage"""
    try:
        result = subprocess.run(
            ['nvidia-smi', '--query-gpu=utilization.gpu', '--format=csv,noheader,nounits'],
            capture_output=True, text=True, timeout=1
        )
        return int(result.stdout.strip())
    except:
        return -1

class GPUMonitor:
    """Background thread to monitor GPU utilization"""
    def __init__(self):
        self.running = False
        self.thread = None
        self.last_util = 0
    
    def start(self):
        self.running = True
        self.thread = threading.Thread(target=self._monitor, daemon=True)
        self.thread.start()
    
    def stop(self):
        self.running = False
        if self.thread:
            self.thread.join(timeout=2)
    
    def _monitor(self):
        while self.running:
            util = get_gpu_utilization()
            if util >= 0:
                self.last_util = util
            time.sleep(2)  # Update every 2 seconds
    
    def get_utilization(self):
        return self.last_util

# Mercenary rules now in separate module
from mercenary_rules import MercenaryBoard


class ChessDataset(Dataset):
    """Dataset for training with policy and value targets"""
    def __init__(self, game_history):
        self.data = game_history
    
    def __len__(self):
        return len(self.data)
    
    def __getitem__(self, idx):
        entry = self.data[idx]
        state = torch.from_numpy(entry['state']).float()
        policy = torch.from_numpy(entry['policy']).float()
        value = torch.tensor([entry['value']], dtype=torch.float32)
        return state, policy, value


def _save_game_from_history(recorder, game_history, iteration, game_num):
    """Convert game_history training data to GameRecorder format"""
    import json
    from pathlib import Path
    from datetime import datetime
    
    if not game_history:
        return
    
    # Reconstruct game from training history
    # Don't need to recreate board - just extract moves from history
    moves = []
    
    for i, entry in enumerate(game_history):
        if 'moves' in entry and entry['moves']:
            # Get the actual move played (need to reconstruct from policy/probs)
            legal_moves = entry['moves']
            move_probs = entry.get('move_probs', [])
            
            if len(move_probs) > 0:
                # The move played had highest probability after MCTS
                best_idx = np.argmax(move_probs)
                move = legal_moves[best_idx]
                
                # Record move data
                moves.append({
                    'number': i + 1,
                    'move': move.uci(),
                    'turn': 'white' if i % 2 == 0 else 'black',
                    'value': float(entry.get('value', 0.0)),
                    'top_3_moves': [
                        {'move': legal_moves[j].uci(), 'probability': float(move_probs[j])}
                        for j in np.argsort(move_probs)[-3:][::-1]
                    ] if len(move_probs) >= 3 else []
                })
    
    # Determine result from final value
    final_value = game_history[-1].get('value', 0.0)
    if final_value > 0.5:
        result = '1-0'  # White wins
    elif final_value < -0.5:
        result = '0-1'  # Black wins
    else:
        result = '1/2-1/2'  # Draw
    
    # Save to JSON
    game_data = {
        'metadata': {
            'iteration': iteration,
            'game_number': game_num,
            'mode': 'mercenary',
            'timestamp': datetime.now().isoformat(),
            'starting_fen': chess.Board().fen()
        },
        'moves': moves,
        'result': result,
        'total_moves': len(moves)
    }
    
    # Create output directory (in workspace which is mounted)
    output_dir = Path('data/training_games')
    output_dir.mkdir(parents=True, exist_ok=True)
    
    # Save file
    filename = f"game_{iteration:03d}_{game_num:03d}.json"
    filepath = output_dir / filename
    
    with open(filepath, 'w') as f:
        json.dump(game_data, f, indent=2)
    
    return filepath


def train_mercenary_1800():
    """Train Mercenary AI to 1800 ELO"""
    
    print("=" * 80)
    print("ChessRecast AI - MERCENARY MODE - TARGET 1800 ELO")
    print("=" * 80)
    
    if not torch.cuda.is_available():
        print("\n❌ GPU required for this training!")
        sys.exit(1)
    
    DEVICE = 'cuda'
    
    # GPU info
    print(f"\n🚀 GPU: {torch.cuda.get_device_name(0)}")
    props = torch.cuda.get_device_properties(0)
    total_vram = props.total_memory / 1e9
    print(f"   Total VRAM: {total_vram:.1f} GB")
    
    # AGGRESSIVE 1800 ELO Configuration
    NUM_ITERATIONS = 200  # More iterations for stronger play
    GAMES_PER_ITERATION = 50  # More diverse training data
    MCTS_SIMULATIONS = 150  # Stronger lookahead (100-200 for 1800)
    EPOCHS_PER_ITERATION = 15  # Deep learning on each batch
    BATCH_SIZE = 512  # Max GPU utilization
    LEARNING_RATE = 0.0005  # Lower LR for stability at higher ELO
    NUM_WORKERS = 2
    
    print(f"\n⚡ 1800 ELO Training Configuration:")
    print(f"   Iterations: {NUM_ITERATIONS} (extended for strength)")
    print(f"   Games/iteration: {GAMES_PER_ITERATION}")
    print(f"   MCTS simulations: {MCTS_SIMULATIONS} (strong lookahead)")
    print(f"   Epochs/iteration: {EPOCHS_PER_ITERATION}")
    print(f"   Batch size: {BATCH_SIZE}")
    print(f"   Learning rate: {LEARNING_RATE}")
    print(f"   Total games: {NUM_ITERATIONS * GAMES_PER_ITERATION:,}")
    print(f"   Expected time: 6-10 hours (RTX 4080)")
    print(f"   Target: 1800 ELO")
    
    # Enable ALL GPU optimizations
    print("\n🔥 GPU Optimizations...")
    torch.backends.cudnn.benchmark = True
    torch.backends.cuda.matmul.allow_tf32 = True
    torch.backends.cudnn.allow_tf32 = True
    torch.set_float32_matmul_precision('high')
    print("   ✓ cuDNN benchmark")
    print("   ✓ TensorFloat-32")
    print("   ✓ High precision matmul")
    
    # Larger network for 1800 ELO
    print("\n🧠 Neural Network (Large - 1800 ELO)...")
    model = ChessNetPOC(num_channels=128, num_res_blocks=10).to(DEVICE)
    print(f"   Channels: 128 (vs 64 for beginner)")
    print(f"   Residual blocks: 10 (vs 2 for beginner)")
    print(f"   Parameters: {count_parameters(model):,}")
    print("   ✓ Large network for strong play")
    
    # Optimizer with weight decay
    optimizer = optim.AdamW(
        model.parameters(),
        lr=LEARNING_RATE,
        weight_decay=1e-4,
        betas=(0.9, 0.999)
    )
    scheduler = optim.lr_scheduler.CosineAnnealingLR(
        optimizer,
        T_max=NUM_ITERATIONS,
        eta_min=1e-5
    )
    
    scaler = torch.cuda.amp.GradScaler()
    policy_loss_fn = nn.CrossEntropyLoss()
    value_loss_fn = nn.MSELoss()
    print("   ✓ AdamW + Cosine LR schedule + Mixed Precision")
    
    checkpoint_dir = Path('/workspace/checkpoints/mercenary_1800')
    checkpoint_dir.mkdir(parents=True, exist_ok=True)
    
    # Start GPU monitoring
    gpu_monitor = GPUMonitor()
    gpu_monitor.start()
    print("   ✓ GPU monitoring started")
    
    # Start WebSocket server for live game streaming
    ws_server = get_websocket_server()
    print("   ✓ WebSocket server started (ws://0.0.0.0:8765)")
    
    # Training metrics
    training_start = time.time()
    metrics_history = []
    
    print("\n" + "=" * 80)
    print("🚀 TRAINING MERCENARY AI TO 1800 ELO")
    print("=" * 80)
    
    for iteration in range(1, NUM_ITERATIONS + 1):
        iter_start = time.time()
        
        print(f"\n{'=' * 80}")
        gpu_util = gpu_monitor.get_utilization()
        gpu_info = f" [GPU: {gpu_util}%]" if gpu_util >= 0 else ""
        print(f"📍 Iteration {iteration}/{NUM_ITERATIONS}{gpu_info}")
        print(f"{'=' * 80}")
        
        # Temperature schedule: Start high, decay to low
        # High temperature = exploration, Low = exploitation
        temperature = max(0.5, 1.5 - (iteration / NUM_ITERATIONS) * 1.0)
        
        # Self-play with policy-guided MCTS using MERCENARY RULES
        print(f"\n🎲 Self-Play: {GAMES_PER_ITERATION} games (MCTS: {MCTS_SIMULATIONS} sims, T={temperature:.2f})")
        self_play = ImprovedSelfPlay(
            model,
            device=DEVICE,
            num_simulations=MCTS_SIMULATIONS,
            batch_size=64,  # Batch inference for speed
            game_class=MercenaryBoard  # USE CORRECT MERCENARY RULES!
        )
        
        all_data = []
        wins_white = 0
        wins_black = 0
        draws = 0
        
        # Record first 10 games of first 10 iterations for visualization
        game_recorder = GameRecorder() if iteration <= 10 else None
        
        with torch.no_grad():
            for game_num in range(GAMES_PER_ITERATION):
                # Enable detailed logging for first game of first 3 iterations
                log_this_game = (iteration <= 3 and game_num == 0)
                
                # Record games for viewer (first 10 games per iteration for first 10 iterations)
                should_record = game_recorder and game_num < 10
                
                # WebSocket: broadcast ALL games for continuous live viewing
                ws_server.start_game(iteration, game_num + 1, mode='mercenary')
                
                if should_record:
                    game_recorder.start_game(iteration, game_num + 1, mode='mercenary')
                
                game_history = self_play.play_game(
                    temperature_schedule='decay',
                    verbose=(game_num % 10 == 0),
                    log_moves=log_this_game,
                    ws_server=ws_server  # Stream ALL games continuously
                )
                all_data.extend(game_history)
                
                # WebSocket: broadcast game end
                if game_history:
                    final_value = game_history[-1]['value']
                    if final_value > 0.5:
                        result = '1-0'
                    elif final_value < -0.5:
                        result = '0-1'
                    else:
                        result = '1/2-1/2'
                    ws_server.end_game(result)
                
                # Save game for visualization
                if should_record and game_history:
                    _save_game_from_history(game_recorder, game_history, iteration, game_num + 1)
                
                # Track results
                if game_history:
                    final_value = game_history[-1]['value']
                    if final_value > 0.5:
                        wins_white += 1
                    elif final_value < -0.5:
                        wins_black += 1
                    else:
                        draws += 1
                
                if (game_num + 1) % 10 == 0:
                    gpu_util = gpu_monitor.get_utilization()
                    gpu_info = f" [GPU: {gpu_util}%]" if gpu_util >= 0 else ""
                    print(f"   {game_num + 1}/{GAMES_PER_ITERATION} | "
                          f"Positions: {len(all_data):,} | "
                          f"W:{wins_white} D:{draws} B:{wins_black}{gpu_info}", flush=True)
        
        print(f"   ✓ Generated {len(all_data):,} training positions")
        print(f"   ✓ Results: W:{wins_white} D:{draws} B:{wins_black}")
        
        # Report saved games
        if game_recorder:
            print(f"   ✓ Saved 10 games to trainer/data/training_games/ for viewer")
        
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
        epoch_losses = []
        
        for epoch in range(EPOCHS_PER_ITERATION):
            policy_loss_sum = 0
            value_loss_sum = 0
            batches = 0
            
            for states, policies, values in dataloader:
                states = states.to(DEVICE, non_blocking=True)
                policies = policies.to(DEVICE, non_blocking=True)
                values = values.to(DEVICE, non_blocking=True)
                
                optimizer.zero_grad(set_to_none=True)
                
                # Mixed precision forward pass
                with torch.cuda.amp.autocast():
                    pred_policy, pred_value = model(states)
                    
                    # Policy loss (cross-entropy with target distribution)
                    policy_loss = policy_loss_fn(pred_policy, policies)
                    
                    # Value loss (MSE)
                    value_loss = value_loss_fn(pred_value, values)
                    
                    # Combined loss (balanced)
                    loss = policy_loss + value_loss
                
                # Backward with gradient scaling
                scaler.scale(loss).backward()
                scaler.unscale_(optimizer)
                torch.nn.utils.clip_grad_norm_(model.parameters(), 1.0)
                scaler.step(optimizer)
                scaler.update()
                
                policy_loss_sum += policy_loss.item()
                value_loss_sum += value_loss.item()
                batches += 1
            
            avg_policy_loss = policy_loss_sum / batches
            avg_value_loss = value_loss_sum / batches
            total_loss = avg_policy_loss + avg_value_loss
            epoch_losses.append(total_loss)
            
            if (epoch + 1) % 3 == 0 or epoch == EPOCHS_PER_ITERATION - 1:
                print(f"   Epoch {epoch + 1}/{EPOCHS_PER_ITERATION}: "
                      f"Loss={total_loss:.4f} (Policy={avg_policy_loss:.4f}, Value={avg_value_loss:.4f})")
        
        # Update learning rate
        scheduler.step()
        current_lr = scheduler.get_last_lr()[0]
        
        # Save checkpoint every 10 iterations
        if iteration % 10 == 0:
            checkpoint_path = checkpoint_dir / f'mercenary_1800_iter{iteration}.pth'
            torch.save({
                'iteration': iteration,
                'model_state_dict': model.state_dict(),
                'optimizer_state_dict': optimizer.state_dict(),
                'scheduler_state_dict': scheduler.state_dict(),
                'loss': epoch_losses[-1],
            }, checkpoint_path)
            print(f"   ✓ Saved checkpoint: {checkpoint_path.name}")
        
        # Metrics
        iter_time = time.time() - iter_start
        total_time = time.time() - training_start
        eta = (total_time / iteration) * (NUM_ITERATIONS - iteration)
        
        metrics = {
            'iteration': iteration,
            'loss': epoch_losses[-1],
            'policy_loss': avg_policy_loss,
            'value_loss': avg_value_loss,
            'learning_rate': current_lr,
            'temperature': temperature,
            'positions': len(all_data),
            'wins_white': wins_white,
            'wins_black': wins_black,
            'draws': draws,
            'time_seconds': iter_time
        }
        metrics_history.append(metrics)
        
        print(f"\n   📊 Iteration Summary:")
        print(f"      Time: {iter_time:.1f}s | LR: {current_lr:.6f}")
        print(f"      ETA: {eta/3600:.1f}h ({(total_time/3600):.1f}h elapsed)")
    
    # Final save
    print("\n" + "=" * 80)
    print("💾 SAVING FINAL MODEL")
    print("=" * 80)
    
    final_path = checkpoint_dir / 'mercenary_1800_final.pth'
    torch.save(model.state_dict(), final_path)
    print(f"✓ Model saved: {final_path}")
    
    # Save metrics
    metrics_path = checkpoint_dir / 'training_metrics.json'
    with open(metrics_path, 'w') as f:
        json.dump(metrics_history, f, indent=2)
    print(f"✓ Metrics saved: {metrics_path}")
    
    total_hours = (time.time() - training_start) / 3600
    print(f"\n🏁 Training complete! Total time: {total_hours:.2f} hours")
    print(f"🎯 Expected strength: ~1800 ELO (Mercenary mode)")


if __name__ == "__main__":
    train_mercenary_1800()
