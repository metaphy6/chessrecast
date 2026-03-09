"""
Mercenary Mod AI Training
Maximum GPU utilization with advanced training techniques.

Training Strategy:
- Mercenary mode: Pawns change color when captured
- Policy-guided MCTS with 100-200 simulations
- Larger network (128 channels, 10 residual blocks)
- Aggressive GPU batching (512-1024 batch size)
- Advanced techniques: curriculum learning, position diversity
"""
import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import Dataset, DataLoader
import numpy as np
import sys
import os
import time
import chess
import random
from pathlib import Path
from tqdm import tqdm
import json
import subprocess
import threading

# Add trainer/ root to path so all modules resolve correctly
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from network import ChessNetPOC, count_parameters
from selfplay import ImprovedSelfPlay
from tools.recorder import GameRecorder
from tools.server import get_websocket_server
from tools.logger import TrainingLogger

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

# Mercenary rules
from mods.mercenary import MercenaryBoard


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


def train_mercenary(test_mode=False, move_delay=0.3):
    """Train Mercenary AI
    
    Args:
        test_mode: If True, play random games without training (for testing rules)
        move_delay: Delay in seconds between moves (1-10, default 0.3)
    """
    
    log = TrainingLogger(mode='mercenary')

    log.banner(
        title='MERCENARY MODE',
        subtitle='Maximum GPU utilization with advanced training techniques',
        test_mode=test_mode
    )

    # Auto-detect GPU/CPU
    if torch.cuda.is_available():
        DEVICE = 'cuda'
        gpu_name = torch.cuda.get_device_name(0)
        total_vram = torch.cuda.get_device_properties(0).total_memory / 1e9
        log.device_info('cuda', gpu_name, total_vram)
    else:
        DEVICE = 'cpu'
        log.device_info('cpu')
        if not test_mode:
            log.warn('Training will be slower but functional')
    
    # Configuration based on mode and device
    if test_mode:
        # Test mode: Simple random games for rule testing
        NUM_ITERATIONS = 999999  # Infinite
        GAMES_PER_ITERATION = 1
        MCTS_SIMULATIONS = 0  # Random moves
        EPOCHS_PER_ITERATION = 0
        BATCH_SIZE = 1
        LEARNING_RATE = 0.0005
        NUM_WORKERS = 0
        log.config({'Mod': 'Test / Demo', 'Move delay': f'{move_delay}s'}, label='Test Mod Configuration')
    elif DEVICE == 'cpu':
        # CPU mode: Reduced settings
        NUM_ITERATIONS = 50
        GAMES_PER_ITERATION = 10
        MCTS_SIMULATIONS = 20  # Reduced for CPU
        EPOCHS_PER_ITERATION = 5
        BATCH_SIZE = 32
        LEARNING_RATE = 0.001
        NUM_WORKERS = 0
        log.config({'Iterations': NUM_ITERATIONS, 'MCTS simulations': f'{MCTS_SIMULATIONS} (lighter)'}, label='CPU Training Configuration')
    else:
        # Full GPU Training Configuration
        NUM_ITERATIONS = 200  # More iterations for stronger play
        GAMES_PER_ITERATION = 50  # More diverse training data
        MCTS_SIMULATIONS = 150  # Stronger lookahead (100-200)
        EPOCHS_PER_ITERATION = 15  # Deep learning on each batch
        BATCH_SIZE = 512  # Max GPU utilization
        LEARNING_RATE = 0.0005  # Lower LR for stability at higher ELO
        NUM_WORKERS = 2
    
    if not test_mode:
        config_params = {
            'Iterations': NUM_ITERATIONS,
            'Games/iteration': GAMES_PER_ITERATION,
            'MCTS simulations': MCTS_SIMULATIONS,
            'Epochs/iteration': EPOCHS_PER_ITERATION,
            'Batch size': BATCH_SIZE,
            'Learning rate': LEARNING_RATE,
            'Total games': f'{NUM_ITERATIONS * GAMES_PER_ITERATION:,}',
        }
        if DEVICE == 'cuda':
            config_params['Expected time'] = '6-10 hours (RTX 4080)'
        config_params['Target'] = 'High ELO'
        log.config(config_params)
    
    # Enable GPU optimizations if available
    if DEVICE == 'cuda':
        torch.backends.cudnn.benchmark = True
        torch.backends.cuda.matmul.allow_tf32 = True
        torch.backends.cudnn.allow_tf32 = True
        torch.set_float32_matmul_precision('high')
        log.gpu_optimizations(['cuDNN benchmark', 'TensorFloat-32', 'High precision matmul'])
    
    # Neural Network (skip in test mode)
    if not test_mode:
        if DEVICE == 'cuda':
            model = ChessNetPOC(num_channels=128, num_res_blocks=10).to(DEVICE)
            log.network_info(128, 10, count_parameters(model), DEVICE)
        else:
            model = ChessNetPOC(num_channels=64, num_res_blocks=4).to(DEVICE)
            log.network_info(64, 4, count_parameters(model), DEVICE)
    else:
        model = None
        log.info('Test mode: No neural network (random moves)')
    
    # Optimizer with weight decay (skip in test mode)
    if not test_mode:
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
        
        scaler = torch.cuda.amp.GradScaler() if DEVICE == 'cuda' else None
        policy_loss_fn = nn.CrossEntropyLoss()
        value_loss_fn = nn.MSELoss()
        log.info('AdamW + Cosine LR schedule + Mixed Precision')
    
    checkpoint_dir = Path('/workspace/checkpoints/mercenary')
    checkpoint_dir.mkdir(parents=True, exist_ok=True)
    
    # Start GPU monitoring
    gpu_monitor = GPUMonitor()
    gpu_monitor.start()
    log.info('GPU monitoring started')
    
    # Start WebSocket server for live game streaming
    ws_server = get_websocket_server()
    log.info('WebSocket server started (ws://0.0.0.0:8765)')
    
    # TEST MODE: Play random games without training
    if test_mode:
        log.test_mode_banner(move_delay)
        
        import random
        game_num = 0
        
        try:
            while True:
                game_num += 1
                game = MercenaryBoard()
                move_count = 0
                
                # Clear any previous validation errors
                ws_server.clear_validation_error()
                
                # Broadcast game start
                ws_server.start_game(1, game_num, mode='mercenary')
                log.test_game_start(game_num, game.board.fen())
                
                game_stopped_due_to_error = False
                
                while not game.is_game_over() and move_count < 200:
                    # Check for validation errors from Flutter client
                    if ws_server.has_validation_error():
                        error = ws_server.last_validation_error
                        log.validation_error(
                            error.get('move_number', 0),
                            error.get('move_uci', ''),
                            error.get('error_message', '')
                        )
                        game_stopped_due_to_error = True
                        break
                    
                    legal_moves = game.get_legal_moves()
                    
                    if not legal_moves:
                        break
                    
                    # Random move selection
                    move = random.choice(legal_moves)
                    
                    # Determine if pawn move
                    piece = game.board.piece_at(move.from_square)
                    is_pawn = piece and piece.piece_type == 1
                    
                    # Get the color making the move BEFORE making it
                    turn_color = 'white' if game.board.turn else 'black'
                    
                    # Try to make the move
                    move_success = game.make_move(move)
                    
                    if not move_success:
                        log.critical_error(
                            f'Move {move.uci()} was in legal_moves but make_move rejected it!',
                            game.board.fen()
                        )
                        game_stopped_due_to_error = True
                        break
                    
                    move_count += 1
                    
                    # CRITICAL: Verify both kings are still on the board
                    white_king = game.board.king(True)  # chess.WHITE = True
                    black_king = game.board.king(False)  # chess.BLACK = False
                    
                    if white_king is None:
                        log.critical_error(
                            f'White king captured/missing after move {move.uci()}!',
                            game.board.fen()
                        )
                        game_stopped_due_to_error = True
                        break
                    
                    if black_king is None:
                        log.critical_error(
                            f'Black king captured/missing after move {move.uci()}!',
                            game.board.fen()
                        )
                        game_stopped_due_to_error = True
                        break
                    
                    # Broadcast move
                    ws_server.send_move(
                        move_num=move_count,
                        move_uci=move.uci(),
                        turn=turn_color,
                        fen=game.board.fen(),
                        value=0.0,
                        top_moves=[{'move': move.uci(), 'probability': 1.0}]
                    )
                    
                    if move_count % 10 == 0:
                        log.test_move(move_count, move.uci(), turn_color)
                    
                    # Apply move delay
                    time.sleep(move_delay)
                
                # Game ended
                if game_stopped_due_to_error:
                    result = 'ERROR'
                    ws_server.end_game(result)
                    log.test_game_end(game_num, result, move_count)
                    time.sleep(10)
                else:
                    result = game.get_result()
                    ws_server.end_game(result)
                    log.test_game_end(game_num, result, move_count)
                    time.sleep(3)
                
        except KeyboardInterrupt:
            log.warn('Stopping test mode...')
            gpu_monitor.stop()
            return
    
    # Training metrics
    training_start = time.time()
    metrics_history = []
    
    log.section('\ud83d\ude80', 'TRAINING MERCENARY AI')
    
    for iteration in range(1, NUM_ITERATIONS + 1):
        iter_start = time.time()
        
        gpu_util = gpu_monitor.get_utilization()
        log.iteration_start(iteration, NUM_ITERATIONS, gpu_util)
        
        # Temperature schedule: Start high, decay to low
        # High temperature = exploration, Low = exploitation
        temperature = max(0.5, 1.5 - (iteration / NUM_ITERATIONS) * 1.0)
        
        # Self-play with policy-guided MCTS using MERCENARY RULES
        log.self_play_header(GAMES_PER_ITERATION, MCTS_SIMULATIONS, temperature)
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
        
        import time as _time
        with torch.no_grad():
            for game_num in range(GAMES_PER_ITERATION):
                _game_start_time = _time.time()
                # Enable detailed logging for first game of first 3 iterations
                log_this_game = (iteration <= 3 and game_num == 0)
                
                # Record games for viewer (first 10 games per iteration for first 10 iterations)
                should_record = game_recorder and game_num < 10
                
                # WebSocket: broadcast ALL games for continuous live viewing
                ws_server.clear_validation_error()  # Reset error counter per game
                ws_server.start_game(iteration, game_num + 1, mode='mercenary')
                
                if should_record:
                    game_recorder.start_game(iteration, game_num + 1, mode='mercenary')
                
                game_history = self_play.play_game(
                    temperature_schedule='decay',
                    verbose=True,  # Always show progress for every game
                    log_moves=log_this_game,
                    ws_server=ws_server  # Stream ALL games continuously
                )
                all_data.extend(game_history)
                
                # Print game completion with timing
                _game_elapsed = _time.time() - _game_start_time
                _moves = len(game_history)
                log.game_result(game_num + 1, GAMES_PER_ITERATION, _moves, _game_elapsed)
                
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
                    log.games_progress(game_num + 1, GAMES_PER_ITERATION, len(all_data),
                                       wins_white, draws, wins_black, gpu_util)
        
        recorded = 10 if game_recorder else 0
        log.self_play_summary(len(all_data), wins_white, draws, wins_black, recorded)
        
        # Training
        log.training_header(EPOCHS_PER_ITERATION, BATCH_SIZE)
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
                log.epoch_result(epoch + 1, EPOCHS_PER_ITERATION, total_loss, avg_policy_loss, avg_value_loss)
        
        # Update learning rate
        scheduler.step()
        current_lr = scheduler.get_last_lr()[0]
        
        # Save checkpoint every 10 iterations
        if iteration % 10 == 0:
            checkpoint_path = checkpoint_dir / f'mercenary_iter{iteration}.pth'
            torch.save({
                'iteration': iteration,
                'model_state_dict': model.state_dict(),
                'optimizer_state_dict': optimizer.state_dict(),
                'scheduler_state_dict': scheduler.state_dict(),
                'loss': epoch_losses[-1],
            }, checkpoint_path)
            checkpoint_name = checkpoint_path.name
        else:
            checkpoint_name = ''
        
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
        
        log.iteration_summary(iteration, NUM_ITERATIONS, epoch_losses[-1], current_lr, checkpoint_name)
    
    # Final save
    final_path = checkpoint_dir / 'mercenary_final.pth'
    torch.save(model.state_dict(), final_path)
    
    # Save metrics
    metrics_path = checkpoint_dir / 'training_metrics.json'
    with open(metrics_path, 'w') as f:
        json.dump(metrics_history, f, indent=2)
    
    log.save_final(str(final_path), str(metrics_path))
    
    total_hours = (time.time() - training_start) / 3600
    log.training_complete(total_hours)


if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description='Train or test Mercenary AI')
    parser.add_argument('--test', action='store_true', help='Test mode: play random games without training')
    parser.add_argument('--delay', type=float, default=0.3, help='Move delay in seconds (0.1-10, default 0.3)')
    
    args = parser.parse_args()
    
    # Validate delay
    move_delay = max(0.1, min(10.0, args.delay))
    
    train_mercenary(test_mode=args.test, move_delay=move_delay)

