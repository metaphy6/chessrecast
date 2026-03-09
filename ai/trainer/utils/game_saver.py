#!/usr/bin/env python3
"""
Game saving utilities for training visualization.

Saves games in JSON format for the Flutter viewer to analyze.
"""

import json
import numpy as np
from pathlib import Path
from datetime import datetime


def save_game_from_history(recorder, game_history, iteration, game_num, mode='mercenary', output_dir='data/training_games'):
    """
    Save a game from self-play history to JSON format.
    
    Creates a JSON file compatible with the Flutter game viewer, including:
        - Move sequence with UCI notation
        - Position evaluations
        - Top move candidates with probabilities
        - Game metadata (iteration, mode, timestamp)
    
    Args:
        recorder: GameRecorder instance (can be None)
        game_history: List of game states with moves, probabilities, and values
        iteration: Training iteration number
        game_num: Game number within the iteration
        mode: Game mode name (e.g., 'mercenary', 'heir', 'classic')
        output_dir: Directory to save game files (default: 'data/training_games')
    
    Returns:
        Path: Path to the saved JSON file, or None if game_history is empty
    
    Usage:
        filepath = save_game_from_history(
            recorder, game_history, 
            iteration=5, game_num=3, 
            mode='mercenary'
        )
    """
    if not game_history:
        return None
    
    moves = []
    for i, entry in enumerate(game_history):
        if 'moves' in entry and entry['moves']:
            legal_moves = entry['moves']
            move_probs = entry.get('move_probs', [])
            
            if len(move_probs) > 0:
                best_idx = np.argmax(move_probs)
                move = legal_moves[best_idx]
                
                # Build move record
                move_record = {
                    'number': i + 1,
                    'move': move.uci(),
                    'turn': 'white' if i % 2 == 0 else 'black',
                    'value': float(entry.get('value', 0.0)),
                }
                
                # Add top 3 move candidates if available
                if len(move_probs) >= 3:
                    top_3_indices = np.argsort(move_probs)[-3:][::-1]
                    move_record['top_3_moves'] = [
                        {
                            'move': legal_moves[j].uci(),
                            'probability': float(move_probs[j])
                        }
                        for j in top_3_indices
                    ]
                else:
                    move_record['top_3_moves'] = []
                
                moves.append(move_record)
    
    # Determine game result from final value
    final_value = game_history[-1].get('value', 0.0)
    if final_value > 0.5:
        result = '1-0'  # White wins
    elif final_value < -0.5:
        result = '0-1'  # Black wins
    else:
        result = '1/2-1/2'  # Draw
    
    # Create output directory
    output_path = Path(output_dir)
    output_path.mkdir(parents=True, exist_ok=True)
    
    # Generate filename
    filepath = output_path / f"game_{iteration:03d}_{game_num:03d}.json"
    
    # Build game record
    game_data = {
        'metadata': {
            'iteration': iteration,
            'game_number': game_num,
            'mode': mode,
            'timestamp': datetime.now().isoformat(),
            'starting_fen': 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1'  # Standard starting position
        },
        'moves': moves,
        'result': result,
        'total_moves': len(moves)
    }
    
    # Save to file
    with open(filepath, 'w') as f:
        json.dump(game_data, f, indent=2)
    
    return filepath
