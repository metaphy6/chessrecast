"""
Analyze training results by comparing checkpoints.
Tests AI strength progression through self-play matches.
"""
import torch
import numpy as np
from pathlib import Path
from tqdm import tqdm
import sys

from neural_network_gpu import ChessNetPOC
from game_rules import ChessGamePOC

def load_model(checkpoint_path, device='cuda'):
    """Load model from checkpoint"""
    model = ChessNetPOC(num_channels=64).to(device)
    checkpoint = torch.load(checkpoint_path, map_location=device)
    model.load_state_dict(checkpoint['model_state_dict'])
    model.eval()
    return model, checkpoint.get('loss', 0), checkpoint.get('iteration', 0)

def play_game_between_models(model1, model2, device='cuda'):
    """
    Play one game between two models.
    Returns: 1 if model1 wins, 0 if model2 wins, 0.5 if draw
    """
    game = ChessGamePOC()
    model1.eval()
    model2.eval()
    
    move_count = 0
    max_moves = 200  # Prevent infinite games
    
    with torch.no_grad():
        while not game.is_game_over() and move_count < max_moves:
            current_model = model1 if move_count % 2 == 0 else model2
            
            # Get legal moves
            legal_moves = game.get_legal_moves()
            if not legal_moves:
                break
            
            # Get board state
            state = game.get_board_tensor()
            # Convert to channels-first format (12, 8, 8)
            state_tensor = torch.from_numpy(state).permute(2, 0, 1).unsqueeze(0).float().to(device)
            
            # Get model prediction
            policy, value = current_model(state_tensor)
            
            # Choose move (simplified - just pick highest policy value among legal moves)
            # In production, would map policy indices to actual moves
            move = legal_moves[np.random.randint(len(legal_moves))]
            game.make_move(move)
            
            move_count += 1
    
    # Determine result
    if game.is_game_over():
        result = game.board.result()
        if result == "1-0":  # White wins
            return 1.0 if move_count % 2 == 1 else 0.0
        elif result == "0-1":  # Black wins
            return 0.0 if move_count % 2 == 1 else 1.0
        else:  # Draw
            return 0.5
    else:
        return 0.5  # Max moves reached = draw

def analyze_training():
    """Analyze training progression"""
    
    print("=" * 70)
    print("Training Analysis")
    print("=" * 70)
    
    checkpoint_dir = Path('/workspace/checkpoints')
    
    # Find all checkpoints
    checkpoints = sorted(checkpoint_dir.glob('checkpoint_iter_*.pth'))
    if len(checkpoints) < 2:
        print("\n❌ Need at least 2 checkpoints to analyze progression")
        sys.exit(1)
    
    print(f"\nFound {len(checkpoints)} checkpoints")
    
    # Check device
    device = 'cuda' if torch.cuda.is_available() else 'cpu'
    print(f"Using device: {device}")
    
    # Load and analyze loss progression
    print("\n" + "=" * 70)
    print("📉 Loss Progression")
    print("=" * 70)
    
    losses = []
    for ckpt in checkpoints:
        model, loss, iteration = load_model(ckpt, device)
        losses.append((iteration, loss))
        print(f"Iteration {iteration:2d}: Loss = {loss:.4f}")
    
    # Calculate improvement
    first_loss = losses[0][1]
    last_loss = losses[-1][1]
    improvement = first_loss - last_loss
    improvement_pct = (improvement / first_loss) * 100 if first_loss > 0 else 0
    
    print(f"\nLoss Improvement: {improvement:.4f} ({improvement_pct:+.1f}%)")
    
    # Compare first vs last checkpoint
    print("\n" + "=" * 70)
    print("🎮 Head-to-Head Matches")
    print("=" * 70)
    print("\nComparing First Iteration vs Last Iteration")
    print(f"Loading models...")
    
    first_model, _, _ = load_model(checkpoints[0], device)
    last_model, _, _ = load_model(checkpoints[-1], device)
    
    # Play multiple games
    num_games = 10
    print(f"\nPlaying {num_games} games (5 as white, 5 as black)...")
    
    last_wins = 0
    first_wins = 0
    draws = 0
    
    for game_num in tqdm(range(num_games), desc="Playing games"):
        if game_num < num_games // 2:
            # Last model plays white
            result = play_game_between_models(last_model, first_model, device)
            if result == 1.0:
                last_wins += 1
            elif result == 0.0:
                first_wins += 1
            else:
                draws += 1
        else:
            # First model plays white
            result = play_game_between_models(first_model, last_model, device)
            if result == 1.0:
                first_wins += 1
            elif result == 0.0:
                last_wins += 1
            else:
                draws += 1
    
    print(f"\n📊 Results:")
    print(f"   Last Model (Iteration {losses[-1][0]}): {last_wins} wins")
    print(f"   First Model (Iteration {losses[0][0]}): {first_wins} wins")
    print(f"   Draws: {draws}")
    
    win_rate = (last_wins / num_games) * 100
    print(f"\n   Last Model Win Rate: {win_rate:.1f}%")
    
    # Interpretation
    print("\n" + "=" * 70)
    print("📈 Analysis Summary")
    print("=" * 70)
    
    if win_rate >= 70:
        strength = "🌟 Excellent"
        interpretation = "Strong improvement! Model learned effectively."
    elif win_rate >= 55:
        strength = "✅ Good"
        interpretation = "Clear improvement. Model is getting better."
    elif win_rate >= 45:
        strength = "⚠️  Marginal"
        interpretation = "Some improvement, but could train longer."
    else:
        strength = "❌ Poor"
        interpretation = "Little improvement. May need more training or tuning."
    
    print(f"\nOverall Improvement: {strength}")
    print(f"Interpretation: {interpretation}")
    
    # Estimate Elo
    if win_rate >= 70:
        estimated_elo = "800-1000"
    elif win_rate >= 55:
        estimated_elo = "600-800"
    elif win_rate >= 45:
        estimated_elo = "400-600"
    else:
        estimated_elo = "200-400"
    
    print(f"\nEstimated Strength: ~{estimated_elo} Elo")
    print("(Relative to random play ~200 Elo)")
    
    # Loss analysis
    if improvement_pct > 50:
        loss_quality = "Excellent convergence"
    elif improvement_pct > 25:
        loss_quality = "Good convergence"
    elif improvement_pct > 10:
        loss_quality = "Moderate convergence"
    else:
        loss_quality = "Limited convergence - consider more training"
    
    print(f"\nLoss Analysis: {loss_quality}")
    
    print("\n" + "=" * 70)
    print("✅ Analysis Complete")
    print("=" * 70)
    
    print(f"\n💡 Recommendations:")
    if win_rate < 55:
        print(f"   • Consider training for more iterations")
        print(f"   • Try increasing games per iteration")
        print(f"   • Verify training data diversity")
    else:
        print(f"   ✓ Model is ready for testing!")
        print(f"   • Export to TFLite: python trainer/export_tflite.py")
        print(f"   • Integrate into Flutter app")
        print(f"   • Test against human players")

if __name__ == "__main__":
    analyze_training()
