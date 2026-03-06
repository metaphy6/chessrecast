"""
Improved self-play with policy-guided move selection and MCTS-Lite.
Designed for ChessRecast custom game modes.
GPU-OPTIMIZED: Uses batched inference for high GPU utilization.
"""
import torch
import chess
import numpy as np
import math
from typing import List, Dict, Tuple, Optional
from game_rules import ChessGamePOC
from neural_network_gpu import ChessNetPOC
from concurrent.futures import ThreadPoolExecutor
import queue


class MCTSNode:
    """Lightweight MCTS node for policy-guided search"""
    def __init__(self, prior: float):
        self.prior = prior  # P(s,a) from policy network
        self.visit_count = 0
        self.total_value = 0.0
        self.mean_value = 0.0
    
    def ucb_score(self, parent_visits: int, c_puct: float = 1.5) -> float:
        """Upper Confidence Bound for Trees (UCT) score"""
        if self.visit_count == 0:
            return float('inf')  # Explore unvisited nodes first
        
        exploitation = self.mean_value
        exploration = c_puct * self.prior * math.sqrt(parent_visits) / (1 + self.visit_count)
        return exploitation + exploration
    
    def update(self, value: float):
        """Update statistics after simulation"""
        self.visit_count += 1
        self.total_value += value
        self.mean_value = self.total_value / self.visit_count


class ImprovedSelfPlay:
    """
    Policy-guided self-play with MCTS-Lite.
    GPU-OPTIMIZED: Batched inference for 80-100% GPU utilization.
    
    Key improvements over SimpleSelfPlay:
    1. Uses neural network policy to guide move selection
    2. MCTS-Lite for lookahead (configurable simulations)
    3. Temperature scheduling (exploration → exploitation)
    4. Proper move probability tracking for policy learning
    5. BATCHED INFERENCE: Evaluate multiple positions at once on GPU
    """
    
    def __init__(self, model, device='cuda', num_simulations=50, batch_size=64, game_class=None):
        """
        Args:
            model: ChessNetPOC neural network
            device: 'cuda' or 'cpu'
            num_simulations: MCTS simulations per move (50 = fast, 200 = strong)
            batch_size: Number of positions to evaluate at once on GPU
            game_class: Custom game rules class (defaults to ChessGamePOC)
        """
        self.model = model.to(device)
        self.model.eval()
        self.device = device
        self.num_simulations = num_simulations
        self.batch_size = batch_size
        self.game_class = game_class if game_class else ChessGamePOC
        self._pending_states = []  # Buffer for batch inference
        self._pending_results = []
    
    def play_game(self, temperature_schedule: str = 'decay', verbose: bool = False, 
                  log_moves: bool = False, save_pgn: str = None, ws_server=None) -> List[Dict]:
        """
        Play one self-play game with policy-guided MCTS.
        
        Args:
            temperature_schedule: 
                - 'decay': Start at 1.0, decay to 0.1 (exploration → exploitation)
                - 'constant': Fixed at 1.0 (more random)
                - 'low': Fixed at 0.1 (more deterministic)
            verbose: If True, print progress during game
            log_moves: If True, log detailed move information
            save_pgn: If provided, save game to this PGN file path
            ws_server: WebSocket server for live streaming (optional)
        
        Returns:
            List of training examples with proper policy targets
        """
        game = self.game_class()  # Use custom game class (e.g., MercenaryGameRules)
        game_history = []
        move_count = 0
        move_log = []  # Detailed move information for debugging
        
        if verbose:
            print(f"      Starting game (MCTS: {self.num_simulations} sims/move)...", end='', flush=True)
        
        if log_moves:
            print(f"\n{'='*60}")
            print(f"🎮 DETAILED GAME LOG (MCTS: {self.num_simulations} sims)")
            print(f"{'='*60}")
        
        while not game.is_game_over():
            # Get current state
            state_tensor = self._board_to_tensor(game)
            
            # Get legal moves
            legal_moves = game.get_legal_moves()
            if not legal_moves:
                break
            
            # Temperature for this move
            temperature = self._get_temperature(move_count, temperature_schedule)
            
            # Run MCTS to get improved move probabilities
            move_probs = self._mcts_search(game, legal_moves, temperature)
            
            # Sample move based on improved probabilities
            chosen_move_idx = np.random.choice(len(legal_moves), p=move_probs)
            chosen_move = legal_moves[chosen_move_idx]
            
            # Broadcast move via WebSocket if server available
            if ws_server:
                turn = 'white' if move_count % 2 == 0 else 'black'
                top_3_indices = np.argsort(move_probs)[-3:][::-1]
                top_moves = [
                    {'move': legal_moves[i].uci(), 'probability': float(move_probs[i])}
                    for i in top_3_indices
                ]
                
                # Get value estimate for current position
                with torch.no_grad():
                    _, value = self.model(state_tensor)
                    position_value = value.item()
                
                ws_server.send_move(
                    move_num=move_count + 1,
                    move_uci=chosen_move.uci(),
                    turn=turn,
                    fen=game.board.fen() if hasattr(game, 'board') else '',
                    value=position_value,
                    top_moves=top_moves
                )
            
            # Store training example
            game_history.append({
                'state': state_tensor.cpu().numpy()[0],  # (12, 8, 8)
                'policy': self._moves_to_policy_target(legal_moves, move_probs),  # (4096,)
                'moves': legal_moves,
                'move_probs': move_probs,
            })
            
            # Make move
            game.make_move(chosen_move)
            move_count += 1
            
            # Show progress every 10 moves
            if verbose and move_count % 10 == 0:
                print(f".", end='', flush=True)
        
        if verbose:
            result = game.get_result()
            print(f" {move_count} moves, result: {result}", flush=True)
        
        # Assign game outcome values
        result = game.get_result()
        final_value = self._parse_result(result)
        
        # Assign values from perspective of each player
        for i, entry in enumerate(game_history):
            # Alternate perspective: white's turn = positive, black's = negative
            turn_multiplier = 1 if i % 2 == 0 else -1
            entry['value'] = final_value * turn_multiplier
        
        return game_history
    
    def _mcts_search(self, game: ChessGamePOC, legal_moves: List[chess.Move], 
                     temperature: float) -> np.ndarray:
        """
        MCTS-Lite with BATCHED GPU inference.
        Collects all positions to evaluate, then runs single batched inference.
        
        Returns:
            Probability distribution over legal_moves
        """
        # Initialize MCTS tree
        move_nodes = {}  # move -> MCTSNode
        
        # Get neural network policy and value for root
        state_tensor = self._board_to_tensor(game)
        with torch.no_grad():
            policy_logits, root_value = self.model(state_tensor)
        
        # Extract priors for legal moves
        priors = self._get_move_priors(policy_logits[0], legal_moves)
        
        for move, prior in zip(legal_moves, priors):
            move_nodes[move.uci()] = MCTSNode(prior)
        
        # BATCHED MCTS: Collect all positions first, then batch evaluate
        # Process in batches of self.batch_size simulations
        remaining_sims = self.num_simulations
        
        while remaining_sims > 0:
            batch_count = min(remaining_sims, self.batch_size)
            remaining_sims -= batch_count
            
            # Collect positions for this batch
            positions_to_eval = []  # (move_uci, game_copy, state_tensor)
            terminal_results = []   # (move_uci, value) for terminal positions
            
            for _ in range(batch_count):
                # Select move with highest UCB score
                parent_visits = sum(node.visit_count for node in move_nodes.values())
                best_move_uci = max(
                    move_nodes.keys(),
                    key=lambda m: move_nodes[m].ucb_score(parent_visits + 1)
                )
                best_move = chess.Move.from_uci(best_move_uci)
                
                # Simulate move using the correct game class
                game_copy = game.copy()
                game_copy.make_move(best_move)
                
                if game_copy.is_game_over():
                    # Terminal: use actual result
                    result = game_copy.get_result()
                    value = self._parse_result(result)
                    terminal_results.append((best_move_uci, value))
                else:
                    # Non-terminal: queue for batch evaluation
                    next_state = self._board_to_tensor(game_copy)
                    positions_to_eval.append((best_move_uci, next_state))
            
            # BATCHED GPU INFERENCE for non-terminal positions
            if positions_to_eval:
                # Stack all states into single batch tensor
                batch_states = torch.cat([s for _, s in positions_to_eval], dim=0)
                
                with torch.no_grad():
                    _, batch_values = self.model(batch_states)
                
                # Distribute results back
                for i, (move_uci, _) in enumerate(positions_to_eval):
                    value = batch_values[i].item()
                    move_nodes[move_uci].update(-value)
            
            # Process terminal results
            for move_uci, value in terminal_results:
                move_nodes[move_uci].update(-value)
        
        # Convert visit counts to probabilities with temperature
        visit_counts = np.array([move_nodes[m.uci()].visit_count for m in legal_moves])
        
        if temperature == 0:
            # Deterministic: pick most visited
            probs = np.zeros(len(legal_moves))
            probs[np.argmax(visit_counts)] = 1.0
        else:
            # Stochastic: visits^(1/T) 
            counts_temp = visit_counts ** (1.0 / temperature)
            probs = counts_temp / counts_temp.sum()
        
        return probs
    
    def _get_move_priors(self, policy_logits: torch.Tensor, 
                         legal_moves: List[chess.Move]) -> List[float]:
        """
        Extract policy network priors for legal moves.
        
        Policy logits shape: (4096,) representing all possible moves
        Move encoding: from_square * 64 + to_square (simplified)
        """
        priors = []
        move_indices = []
        
        for move in legal_moves:
            # Simplified move encoding: from_square * 64 + to_square
            from_sq = move.from_square
            to_sq = move.to_square
            move_idx = from_sq * 64 + to_sq
            move_indices.append(move_idx)
        
        # Extract logits for legal moves only
        move_logits = policy_logits[move_indices].cpu().numpy()
        
        # Softmax to get probabilities
        exp_logits = np.exp(move_logits - np.max(move_logits))  # Numerical stability
        priors = exp_logits / exp_logits.sum()
        
        return priors.tolist()
    
    def _moves_to_policy_target(self, legal_moves: List[chess.Move], 
                                move_probs: np.ndarray) -> np.ndarray:
        """
        Convert move probabilities to full policy target (4096,).
        
        Returns:
            policy_target with improved probabilities for legal moves, 0 elsewhere
        """
        policy_target = np.zeros(4096, dtype=np.float32)
        
        for move, prob in zip(legal_moves, move_probs):
            from_sq = move.from_square
            to_sq = move.to_square
            move_idx = from_sq * 64 + to_sq
            policy_target[move_idx] = prob
        
        return policy_target
    
    def _board_to_tensor(self, game: ChessGamePOC) -> torch.Tensor:
        """Convert board to tensor (1, 12, 8, 8)"""
        board_array = game.get_board_tensor()
        tensor = torch.from_numpy(board_array).permute(2, 0, 1).unsqueeze(0)
        return tensor.to(self.device).float()
    
    def _get_temperature(self, move_count: int, schedule: str) -> float:
        """
        Temperature controls exploration vs exploitation.
        
        High temperature (1.0) = explore more (random-ish moves)
        Low temperature (0.1) = exploit more (best moves)
        """
        if schedule == 'constant':
            return 1.0
        elif schedule == 'low':
            return 0.1
        elif schedule == 'decay':
            # Decay from 1.0 to 0.1 over first 30 moves
            if move_count < 30:
                return max(0.1, 1.0 - move_count * 0.03)
            else:
                return 0.1
        else:
            return 1.0
    
    def _parse_result(self, result: str) -> float:
        """Convert game result to value"""
        if result == '1-0':
            return 1.0  # White won
        elif result == '0-1':
            return -1.0  # Black won
        else:
            return 0.0  # Draw


class GameModeRewards:
    """
    Custom reward shaping for ChessRecast game modes.
    Add mode-specific bonuses to encourage strategic play.
    """
    
    @staticmethod
    def apply_mode_bonus(game_history: List[Dict], mode: str) -> List[Dict]:
        """
        Apply mode-specific reward bonuses to training examples.
        
        Args:
            game_history: Standard training examples from play_game()
            mode: 'diamonds', 'friendly_fire', 'kings_battle', etc.
        
        Returns:
            Modified game_history with adjusted values
        """
        if mode == 'other_side':
            return GameModeRewards._other_side_rewards(game_history)
        elif mode == 'kings_battle':
            return GameModeRewards._kings_battle_rewards(game_history)
        # elif mode == 'diamonds':  # DISABLED MODE
        #     return GameModeRewards._diamonds_rewards(game_history)
        else:
            return game_history  # No modification for classic mode
    
    @staticmethod
    def _other_side_rewards(game_history: List[Dict]) -> List[Dict]:
        """
        Other Side Mode: Reward rook advancement toward opponent's back rank.
        """
        # TODO: Implement when game_rules supports mode-specific features
        # For now, return unchanged
        return game_history
    
    @staticmethod
    def _kings_battle_rewards(game_history: List[Dict]) -> List[Dict]:
        """
        Kings' Battle Mode: Reward "King's Kill" trigger and pawn promotions.
        """
        # TODO: Implement when game_rules supports mode tracking
        return game_history
    
    @staticmethod
    def _diamonds_rewards(game_history: List[Dict]) -> List[Dict]:
        """
        Diamonds Mode: Reward bishop positioning for diamond captures.
        """
        # TODO: Implement when game_rules exposes piece positions
        return game_history
