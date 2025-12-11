"""
Simplified self-play for POC.
No MCTS - just use neural network policy directly (faster training).
"""
import torch
import chess
import random
import numpy as np
from game_rules import ChessGamePOC
from neural_network import ChessNetPOC

class SimpleSelfPlay:
    def __init__(self, model, device='cuda' if torch.cuda.is_available() else 'cpu'):
        self.model = model.to(device)
        self.model.eval()
        self.device = device
    
    def play_game(self, temperature=1.0):
        """
        Play one self-play game.
        Returns: List of (state, policy, value) tuples for training
        """
        game = ChessGamePOC()
        game_history = []
        
        while not game.is_game_over():
            # Get current state
            state_tensor = self._board_to_tensor(game)
            
            # Get legal moves
            legal_moves = game.get_legal_moves()
            if not legal_moves:
                break
            
            # Get policy from neural network
            with torch.no_grad():
                policy_logits, value = self.model(state_tensor)
            
            # Convert move indices to probabilities
            move_probs = self._get_move_probabilities(
                policy_logits[0], legal_moves, temperature
            )
            
            # Sample move
            move = random.choices(legal_moves, weights=move_probs)[0]
            
            # Store for training
            game_history.append({
                'state': state_tensor.cpu().numpy()[0],
                'policy': move_probs,
                'moves': legal_moves,
            })
            
            # Make move
            game.make_move(move)
        
        # Assign final values (1 = white won, -1 = black won, 0 = draw)
        result = game.get_result()
        if result == '1-0':
            final_value = 1.0
        elif result == '0-1':
            final_value = -1.0
        else:
            final_value = 0.0
        
        # Assign values alternating by turn
        for i, entry in enumerate(game_history):
            turn_multiplier = 1 if i % 2 == 0 else -1
            entry['value'] = final_value * turn_multiplier
        
        return game_history
    
    def _board_to_tensor(self, game):
        """Convert board to tensor"""
        board_array = game.get_board_tensor()
        # Transpose to (channels, height, width)
        tensor = torch.from_numpy(board_array).permute(2, 0, 1).unsqueeze(0)
        return tensor.to(self.device)
    
    def _get_move_probabilities(self, policy_logits, legal_moves, temperature):
        """Extract probabilities for legal moves only"""
        # Simplified: Just use uniform distribution for POC
        # In full version, would map moves to policy indices
        probs = [1.0 / len(legal_moves)] * len(legal_moves)
        return probs
