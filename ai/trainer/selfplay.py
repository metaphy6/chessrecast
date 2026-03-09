"""
Self-play engine with policy-guided MCTS tree search.
Designed for ChessRecast custom game mods.
"""
import torch
import chess
import numpy as np
import math
from typing import List, Dict, Optional
from network import ChessNetPOC


class MCTSNode:
    """MCTS tree node for multi-level search.
    
    Each node represents a game position in the search tree. Children
    are created when a node is expanded, with game states assigned lazily
    on first visit to avoid copying boards for unvisited branches.
    """
    __slots__ = ['prior', 'visit_count', 'total_value', 'mean_value',
                 'children', 'game_state', 'is_expanded']
    
    def __init__(self, prior: float, game_state=None):
        self.prior = prior
        self.visit_count = 0
        self.total_value = 0.0
        self.mean_value = 0.0
        self.children = {}        # move_uci -> MCTSNode
        self.game_state = game_state  # Set at root; lazy for children
        self.is_expanded = False
    
    def ucb_score(self, parent_visits: int, c_puct: float = 2.5) -> float:
        """Upper Confidence Bound for Trees (UCT) score.
        c_puct=2.5 encourages broader exploration, critical for Mercenary
        mode where the branching factor is high.
        """
        if self.visit_count == 0:
            return float('inf')
        exploitation = self.mean_value
        exploration = c_puct * self.prior * math.sqrt(parent_visits) / (1 + self.visit_count)
        return exploitation + exploration
    
    def update(self, value: float):
        """Update statistics after a simulation passes through this node."""
        self.visit_count += 1
        self.total_value += value
        self.mean_value = self.total_value / self.visit_count
    
    def select_child(self):
        """Select child with highest UCB score. Returns (move_uci, child)."""
        pv = self.visit_count
        return max(self.children.items(), key=lambda kv: kv[1].ucb_score(pv))


class ImprovedSelfPlay:
    """
    Policy-guided self-play with multi-level MCTS tree search.
    
    Key features:
    1. Uses neural network policy to guide move selection
    2. Multi-level MCTS tree search (typically depth 3-6)
    3. Temperature scheduling (exploration → exploitation)
    4. Proper move probability tracking for policy learning
    5. MVV-LVA tactical priors for bootstrapping early training
    6. Dirichlet noise at root for game diversity
    7. Heuristic-blended value to bootstrap MCTS before NN learns
    """
    
    def __init__(self, model, device='cuda', num_simulations=50, batch_size=64,
                 game_class=None, heuristic_weight=0.7):
        """
        Args:
            model: ChessNetPOC neural network
            device: 'cuda' or 'cpu'
            num_simulations: MCTS simulations per move (50 = fast, 200 = strong)
            batch_size: Number of positions to evaluate at once on GPU
            game_class: Game board class (must implement get_legal_moves, make_move, 
                        is_game_over, get_result, get_board_tensor, copy,
                        heuristic_eval)
            heuristic_weight: 0.0-1.0, how much to trust the handcrafted eval
                              vs the neural network value.  Start high (~0.7),
                              decay toward 0.0 as the network improves.
        """
        if game_class is None:
            raise ValueError("game_class is required — pass your mod's Board class")
        self.model = model.to(device)
        self.model.eval()
        self.device = device
        self.num_simulations = num_simulations
        self.batch_size = batch_size
        self.game_class = game_class
        self.heuristic_weight = heuristic_weight
    
    def play_game(self, temperature_schedule: str = 'decay', verbose: bool = False, 
                  save_pgn: str = None, ws_server=None,
                  logger=None) -> tuple:
        """
        Play one self-play game with policy-guided MCTS.
        
        Args:
            temperature_schedule: 
                - 'decay': Start at 1.0, decay to 0.25 (exploration → exploitation)
                - 'constant': Fixed at 1.0 (more random)
                - 'low': Fixed at 0.25 (more deterministic)
            verbose: If True, print progress during game
            save_pgn: If provided, save game to this PGN file path
            ws_server: WebSocket server for live streaming (optional)
        
        Returns:
            (game_history, result) — training examples and game result string
        """
        game = self.game_class()  # Use custom game class (e.g., MercenaryGameRules)
        game_history = []
        move_count = 0
        move_log = []  # Detailed move information for debugging
        
        if verbose and not logger:
            print(f"      Starting game (MCTS: {self.num_simulations} sims/move)...", flush=True)
        
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
            
            # Store training example
            game_history.append({
                'state': state_tensor.cpu().numpy()[0],  # (C, 8, 8)
                'policy': self._moves_to_policy_target(legal_moves, move_probs),  # (4096,)
                'moves': legal_moves,
                'move_probs': move_probs,
            })
            
            # Get turn color BEFORE making the move
            turn = 'white' if game.board.turn else 'black' if hasattr(game, 'board') else ('white' if move_count % 2 == 0 else 'black')
            
            # Make move
            game.make_move(chosen_move)
            move_count += 1

            # Log every move via structured logger
            if logger:
                with torch.no_grad():
                    _, value = self.model(state_tensor)
                    mv_value = value.item()
                logger.training_move(move_count, chosen_move.uci(), turn, mv_value)
            
            # Broadcast move via WebSocket AFTER making the move (FEN must reflect post-move state)
            if ws_server:
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
                    move_num=move_count,
                    move_uci=chosen_move.uci(),
                    turn=turn,
                    fen=game.board.fen() if hasattr(game, 'board') else '',
                    value=position_value,
                    top_moves=top_moves
                )
            
            # Show progress every 10 moves (only when no logger)
            if verbose and not logger and move_count % 10 == 0:
                print(f"      ... {move_count} moves", flush=True)
        
        # Log game completion
        result = game.get_result()
        if logger:
            logger.game_done(move_count, result)
        elif verbose:
            print(f"      Done: {move_count} moves, result: {result}", flush=True)
        
        # Assign game outcome values
        final_value = self._parse_result(result)
        
        # For draws, use material balance as a learning signal so the network
        # learns that having more material is good even when games end in draws.
        # This is critical for Mercenary mode where checkmate is rare.
        #
        # Raw balance uses /39 normalization — too gentle for learning.
        # Amplify so a real advantage produces a strong gradient signal:
        #   1 pawn up  → ~0.09    (noticeable)
        #   1 piece up → ~0.27    (clear advantage)
        #   1 rook up  → ~0.45    (strong)
        #   1 queen up → ~0.81    (near-decisive)
        # Clipped at ±0.85 to keep draws below actual wins (±1.0).
        if final_value == 0.0 and hasattr(game, 'get_material_balance'):
            material = game.get_material_balance()
            final_value = float(np.clip(material * 3.5, -0.85, 0.85))
        
        # Assign values from perspective of each player
        for i, entry in enumerate(game_history):
            # Alternate perspective: white's turn = positive, black's = negative
            turn_multiplier = 1 if i % 2 == 0 else -1
            entry['value'] = final_value * turn_multiplier
        
        return game_history, result
    
    def _mcts_search(self, game, legal_moves: List[chess.Move], 
                     temperature: float) -> np.ndarray:
        """
        Multi-level MCTS tree search.
        
        Builds a search tree several moves deep via 4 phases per simulation:
          1. SELECT  — walk down the tree via UCB until hitting a leaf
          2. EXPAND  — add children for all legal moves at the leaf
          3. EVALUATE — get neural network value for the leaf position
          4. BACKUP  — propagate the value back up the search path
        
        With 150 simulations the tree typically reaches depth 3-6 along the
        principal variation, enabling basic tactical awareness (captures,
        threats, piece safety).
        
        Returns:
            Probability distribution over legal_moves
        """
        # Create and expand root node
        root = MCTSNode(prior=1.0, game_state=game)
        self._expand_node(root, legal_moves, add_noise=True)
        
        for _ in range(self.num_simulations):
            node = root
            search_path = [node]
            
            # ── SELECT: traverse tree following UCB ──
            while node.is_expanded and node.children:
                move_uci, child = node.select_child()
                # Lazily create game state on first visit
                if child.game_state is None:
                    child.game_state = node.game_state.copy()
                    child.game_state.make_move(chess.Move.from_uci(move_uci))
                node = child
                search_path.append(node)
            
            # ── EVALUATE ──
            if node.game_state.is_game_over():
                value = self._parse_result(node.game_state.get_result())
            else:
                state_tensor = self._board_to_tensor(node.game_state)
                with torch.no_grad():
                    policy_logits, value_tensor = self.model(state_tensor)
                nn_value = value_tensor.item()

                # Blend neural network value with handcrafted heuristic.
                # The NN is random early on, so heuristic_weight starts high
                # and decays over training iterations. The heuristic knows
                # that capturing a queen is good and losing one is bad —
                # exactly the signal MCTS needs to pick non-random moves.
                heuristic_value = self._get_heuristic_value(node.game_state)
                hw = self.heuristic_weight
                value = hw * heuristic_value + (1.0 - hw) * nn_value
                
                # ── EXPAND leaf node ──
                child_moves = node.game_state.get_legal_moves()
                if child_moves:
                    priors = self._get_move_priors(
                        policy_logits[0], child_moves, node.game_state)
                    for move, prior in zip(child_moves, priors):
                        node.children[move.uci()] = MCTSNode(prior=prior)
                    node.is_expanded = True
            
            # ── BACKUP: propagate value up the path ──
            # Each level alternates perspective (my value = -opponent's)
            for i, path_node in enumerate(reversed(search_path)):
                sign = 1 if i % 2 == 0 else -1
                path_node.update(sign * value)
        
        # Convert root children visit counts to move probabilities
        visit_counts = np.array([
            root.children[m.uci()].visit_count for m in legal_moves])
        
        if temperature == 0:
            probs = np.zeros(len(legal_moves))
            probs[np.argmax(visit_counts)] = 1.0
        else:
            counts_temp = visit_counts ** (1.0 / temperature)
            total = counts_temp.sum()
            if total == 0:
                probs = np.ones(len(legal_moves)) / len(legal_moves)
            else:
                probs = counts_temp / total
        
        return probs
    
    def _expand_node(self, node: 'MCTSNode', legal_moves: List[chess.Move],
                     add_noise: bool = False):
        """Expand a node: evaluate with network, create child stubs.
        
        Children are created without game_state — that's set lazily when
        the child is first visited during SELECT. This avoids copying the
        board for all ~30 legal moves when only a few will be explored.
        """
        state_tensor = self._board_to_tensor(node.game_state)
        with torch.no_grad():
            policy_logits, _ = self.model(state_tensor)
        
        priors = self._get_move_priors(
            policy_logits[0], legal_moves, node.game_state)
        
        # Dirichlet noise at root for exploration diversity (AlphaZero)
        if add_noise and len(legal_moves) > 0:
            noise = np.random.dirichlet([0.3] * len(legal_moves))
            priors = [0.75 * p + 0.25 * n for p, n in zip(priors, noise)]
        
        for move, prior in zip(legal_moves, priors):
            node.children[move.uci()] = MCTSNode(prior=prior)
        node.is_expanded = True
    
    def _get_move_priors(self, policy_logits: torch.Tensor, 
                         legal_moves: List[chess.Move],
                         game_state=None) -> List[float]:
        """
        Extract policy network priors for legal moves, with MVV-LVA bonus.
        
        Policy logits shape: (4096,) representing all possible moves.
        Move encoding: from_square * 64 + to_square
        
        MVV-LVA (Most Valuable Victim – Least Valuable Attacker):
        Strongly boosts captures where a cheap piece takes an expensive one.
        This makes MCTS immediately explore "pawn takes queen" before the
        neural network has learned anything about piece values.
        
        Check bonus: Moves that give check are tactically important and
        get a prior boost so MCTS explores them early.
        """
        move_indices = []
        for move in legal_moves:
            move_indices.append(move.from_square * 64 + move.to_square)
        
        # Extract logits for legal moves only
        move_logits = policy_logits[move_indices].cpu().numpy()
        
        # Softmax to get probabilities
        exp_logits = np.exp(move_logits - np.max(move_logits))
        priors = (exp_logits / exp_logits.sum()).tolist()
        
        # MVV-LVA + check bonus: strong tactical signal for bootstrapping.
        if game_state is not None and hasattr(game_state, 'board'):
            PIECE_VAL = {
                chess.PAWN: 1.0, chess.KNIGHT: 3.0, chess.BISHOP: 3.0,
                chess.ROOK: 5.0, chess.QUEEN: 9.0, chess.KING: 0.0,
            }
            # Attacker discount: cheaper attacker → bigger bonus
            ATTACKER_DISCOUNT = {
                chess.PAWN: 1.0, chess.KNIGHT: 0.7, chess.BISHOP: 0.7,
                chess.ROOK: 0.5, chess.QUEEN: 0.3, chess.KING: 0.3,
            }
            board = game_state.board
            moving_color = board.turn

            for i, move in enumerate(legal_moves):
                bonus = 0.0

                # ── MVV-LVA capture bonus ──
                victim = board.piece_at(move.to_square)
                if victim is not None and victim.piece_type != chess.KING:
                    attacker = board.piece_at(move.from_square)
                    victim_val = PIECE_VAL.get(victim.piece_type, 0.0)
                    atk_discount = ATTACKER_DISCOUNT.get(
                        attacker.piece_type, 0.5) if attacker else 0.5
                    # Scale: pawn takes queen → 9.0 * 1.0 * 0.06 = 0.54
                    # queen takes pawn → 1.0 * 0.3 * 0.06 = 0.018
                    bonus += victim_val * atk_discount * 0.06

                # ── Check bonus (lightweight) ──
                # Check if the moved piece directly threatens the enemy king
                # from its destination square. Fast per-piece-type geometry
                # check — no board push/pop needed.
                enemy_king_sq = board.king(not moving_color)
                if enemy_king_sq is not None:
                    attacker = board.piece_at(move.from_square)
                    if attacker:
                        gives_check = False
                        to_r = chess.square_rank(move.to_square)
                        to_f = chess.square_file(move.to_square)
                        k_r = chess.square_rank(enemy_king_sq)
                        k_f = chess.square_file(enemy_king_sq)
                        dr = abs(to_r - k_r)
                        df = abs(to_f - k_f)
                        atype = attacker.piece_type
                        if atype == chess.PAWN:
                            # Mercenary pawn: king-like attack (adjacent)
                            gives_check = dr <= 1 and df <= 1 and (dr > 0 or df > 0)
                        elif atype == chess.KNIGHT:
                            gives_check = (dr == 2 and df == 1) or (dr == 1 and df == 2)
                        elif atype in (chess.BISHOP, chess.QUEEN) and dr == df and dr > 0:
                            gives_check = True  # Diagonal alignment (approximate)
                        elif atype in (chess.ROOK, chess.QUEEN) and (dr == 0 or df == 0) and (dr + df) > 0:
                            gives_check = True  # Rank/file alignment (approximate)
                        if gives_check:
                            bonus += 0.12

                priors[i] += bonus

            total = sum(priors)
            if total > 0:
                priors = [p / total for p in priors]
        
        return priors
    
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
    
    def _board_to_tensor(self, game) -> torch.Tensor:
        """Convert board to tensor (1, C, 8, 8) where C = game's channel count."""
        board_array = game.get_board_tensor()
        tensor = torch.from_numpy(board_array).permute(2, 0, 1).unsqueeze(0)
        return tensor.to(self.device).float()

    def _get_heuristic_value(self, game_state) -> float:
        """Get handcrafted evaluation from the game state.

        Returns value from the *current side to move*'s perspective, which
        is what MCTS expects (positive = good for the player whose turn it
        is at this node).
        """
        if hasattr(game_state, 'heuristic_eval'):
            raw = game_state.heuristic_eval()  # White's perspective
            # Flip if it's Black's turn
            if hasattr(game_state, 'board') and not game_state.board.turn:
                raw = -raw
            return raw
        # Fallback: material balance only
        if hasattr(game_state, 'get_material_balance'):
            raw = game_state.get_material_balance()
            if hasattr(game_state, 'board') and not game_state.board.turn:
                raw = -raw
            return raw
        return 0.0
    
    def _get_temperature(self, move_count: int, schedule: str) -> float:
        """
        Temperature controls exploration vs exploitation.
        
        High temperature (1.0) = explore more (random-ish moves)
        Low temperature (0.2) = exploit more (best moves)
        
        The 'decay' schedule keeps high temperature for the first 8 moves
        to generate diverse opening positions, then drops quickly so the
        rest of the game uses MCTS's actual judgment.  With the heuristic-
        blended value, MCTS can now tell good from bad positions, so low
        temperature produces noticeably better play.
        """
        if schedule == 'constant':
            return 1.0
        elif schedule == 'low':
            return 0.2
        elif schedule == 'decay':
            # Broad exploration for opening diversity
            if move_count < 8:
                return 1.0
            # Quick decay to exploitation
            elif move_count < 20:
                return max(0.2, 1.0 - (move_count - 8) * 0.067)
            else:
                return 0.2
        else:
            return 1.0
    
    def _parse_result(self, result: str) -> float:
        """Convert game result to value"""
        if result == '1-0':
            return 1.0  # White won
        elif result == '0-1':
            return -1.0  # Black won
        elif 'draw' in result or result == '1/2-1/2' or result == '*':
            return 0.0  # Draw
        else:
            return 0.0  # Unknown → treat as draw

