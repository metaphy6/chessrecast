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
    
    def ucb_score(self, parent_visits: int, c_puct: float = 1.5) -> float:
        """Upper Confidence Bound for Trees (UCT) score.
        c_puct=1.5 balances exploration/exploitation. Lower than AlphaZero's
        2.5 because our strong heuristic priors already guide search well;
        we need depth (exploitation) more than breadth (exploration).
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

            # ── Forced winning capture (classic chess AI) ──
            # Before burning 300 MCTS sims, check if there's a capture
            # that clearly wins material after all recaptures resolve.
            # If so, play it immediately — no search needed for the
            # obvious.  Policy target is set to one-hot on the capture
            # so the NN learns "this capture is always correct".
            forced, forced_score = self._find_winning_capture(game, legal_moves)
            if forced is not None:
                move_probs = np.zeros(len(legal_moves))
                for idx, m in enumerate(legal_moves):
                    if m == forced:
                        move_probs[idx] = 1.0
                        break
                chosen_move_idx = np.argmax(move_probs)
                chosen_move = forced
            else:
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
        # get_material_balance() returns (w-b)/39 in [-1,1].
        # Multiply by 39 to recover raw difference, then tanh(x*0.3) to
        # match the non-linear scale used in heuristic_eval().
        # Clipped at ±0.85 to keep draws below actual wins (±1.0).
        #   1 pawn up  → tanh(0.3) = 0.29   (noticeable)
        #   1 piece up → tanh(0.9) = 0.72   (strong)
        #   1 rook up  → tanh(1.5) = 0.91 → clipped 0.85
        if final_value == 0.0 and hasattr(game, 'get_material_balance'):
            material = game.get_material_balance()  # in [-1, 1], /39 normalized
            raw_diff = material * 39.0  # recover raw piece-value difference
            final_value = float(np.clip(math.tanh(raw_diff * 0.3), -0.85, 0.85))
        
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
        # Limit to top 20 moves — focuses search on promising branches
        # instead of spreading 150 sims across 35+ children.
        root = MCTSNode(prior=1.0, game_state=game)
        self._expand_node(root, legal_moves, add_noise=True, max_children=20)
        
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
                    # Prune to top 10 — forces deeper search instead of
                    # wider. 150 sims / 10 children = ~15 visits each,
                    # enabling depth 3-4 (vs depth 2 with 35 children).
                    if len(child_moves) > 10:
                        top_k = np.argsort(priors)[-10:]
                        child_moves = [child_moves[i] for i in top_k]
                        priors = [priors[i] for i in top_k]
                        total_p = sum(priors)
                        if total_p > 0:
                            priors = [p / total_p for p in priors]
                    for move, prior in zip(child_moves, priors):
                        node.children[move.uci()] = MCTSNode(prior=prior)
                    node.is_expanded = True
            
            # ── BACKUP: propagate value up the path ──
            # Each level alternates perspective (my value = -opponent's)
            for i, path_node in enumerate(reversed(search_path)):
                sign = 1 if i % 2 == 0 else -1
                path_node.update(sign * value)
        
        # Convert root children visit counts to move probabilities.
        # Pruned moves (not in root.children) get 0 visits → 0 probability,
        # which teaches the policy network those moves are bad.
        visit_counts = np.array([
            root.children[m.uci()].visit_count if m.uci() in root.children else 0
            for m in legal_moves])
        
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
                     add_noise: bool = False, max_children: int = 0):
        """Expand a node: evaluate with network, create child stubs.
        
        Children are created without game_state — that's set lazily when
        the child is first visited during SELECT.
        
        max_children: if > 0, only keep the top N moves by prior.
        This narrows the tree so simulations go deeper instead of wider.
        With 150 sims and 10 children, each gets ~15 visits → depth 3-4.
        With 150 sims and 35 children, each gets ~4 visits → depth 2.
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
        
        # Prune to top K moves by prior
        if max_children > 0 and len(legal_moves) > max_children:
            top_indices = np.argsort(priors)[-max_children:]
            moves_kept = [legal_moves[i] for i in top_indices]
            priors_kept = [priors[i] for i in top_indices]
            total = sum(priors_kept)
            if total > 0:
                priors_kept = [p / total for p in priors_kept]
        else:
            moves_kept = legal_moves
            priors_kept = priors
        
        for move, prior in zip(moves_kept, priors_kept):
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
                victim_val = 0.0

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

                # ── Compute destination info once ──
                attacker = board.piece_at(move.from_square)
                to_r = chess.square_rank(move.to_square)
                to_f = chess.square_file(move.to_square)

                # Scan 8 adjacent squares for enemy pawns (one pass,
                # reused by safe-capture, blunder avoidance, and check).
                dest_near_enemy_pawn = False
                for adr in range(-1, 2):
                    if dest_near_enemy_pawn:
                        break
                    for adf in range(-1, 2):
                        if adr == 0 and adf == 0:
                            continue
                        nr, nf = to_r + adr, to_f + adf
                        if 0 <= nr <= 7 and 0 <= nf <= 7:
                            adj = board.piece_at(chess.square(nf, nr))
                            if (adj and adj.color != moving_color
                                    and adj.piece_type == chess.PAWN):
                                dest_near_enemy_pawn = True
                                break

                # ── Safe-capture bonus ──
                # A capture where no enemy pawn defends the square is
                # almost certainly free material.  Give a huge boost so
                # MCTS pours simulations into verifying it.
                #   pawn×knight (undefended) → 3.0 * 0.20 = +0.60
                #   pawn×queen  (undefended) → 9.0 * 0.20 = +1.80
                # These dwarf the base network prior (~0.03), so MCTS
                # will always explore free captures first.
                if victim is not None and victim.piece_type != chess.KING:
                    if not dest_near_enemy_pawn:
                        bonus += victim_val * 0.20

                # ── Check bonus (lightweight) ──
                enemy_king_sq = board.king(not moving_color)
                if enemy_king_sq is not None and attacker:
                    gives_check = False
                    k_r = chess.square_rank(enemy_king_sq)
                    k_f = chess.square_file(enemy_king_sq)
                    dr = abs(to_r - k_r)
                    df = abs(to_f - k_f)
                    atype = attacker.piece_type
                    if atype == chess.PAWN:
                        gives_check = dr <= 1 and df <= 1 and (dr > 0 or df > 0)
                    elif atype == chess.KNIGHT:
                        gives_check = (dr == 2 and df == 1) or (dr == 1 and df == 2)
                    elif atype in (chess.BISHOP, chess.QUEEN) and dr == df and dr > 0:
                        gives_check = True
                    elif atype in (chess.ROOK, chess.QUEEN) and (dr == 0 or df == 0) and (dr + df) > 0:
                        gives_check = True
                    if gives_check:
                        bonus += 0.12

                # ── Blunder avoidance ──
                # Penalise moving a valuable piece next to an enemy pawn
                # (mercenary pawns attack all 8 adjacent squares).
                if (attacker and dest_near_enemy_pawn
                        and attacker.piece_type not in (chess.PAWN, chess.KING)):
                    my_val = PIECE_VAL.get(attacker.piece_type, 0.0)
                    cap_val = victim_val if victim else 0.0
                    net = cap_val - my_val
                    if net < -1.0:
                        bonus -= 0.35
                    elif net < 0:
                        bonus -= 0.12

                priors[i] = max(0.001, priors[i] + bonus)

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

    # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    #  QUIESCENCE SEARCH — the classic chess AI technique
    # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    #
    # Every strong chess engine (Stockfish, etc.) uses this: NEVER
    # evaluate a position where captures are available.  Instead,
    # play out all capture chains until the position is "quiet",
    # then evaluate.  This guarantees free captures are never missed.
    #
    # Without quiescence, MCTS might evaluate a position where our
    # queen hangs to a pawn as "equal" because the static eval
    # runs before the opponent captures it.  With quiescence, the
    # search plays pawn×queen automatically and evaluates the
    # resulting position (down a queen) correctly.

    _QS_PIECE_VAL = {
        chess.PAWN: 1, chess.KNIGHT: 3, chess.BISHOP: 3,
        chess.ROOK: 5, chess.QUEEN: 9,
    }

    def _get_heuristic_value(self, game_state) -> float:
        """Evaluate position using quiescence search.

        Plays out all capture sequences before evaluating, preventing
        tactical blindness.  This is what makes classic chess AIs strong
        at tactics — they never evaluate "noisy" positions.

        Returns value from side-to-move's perspective in [-1, 1].
        """
        return self._quiescence(game_state, alpha=-1.0, beta=1.0, depth=0)

    def _quiescence(self, game_state, alpha: float, beta: float,
                    depth: int) -> float:
        """Capture-only alpha-beta search (quiescence).

        At each node:
          1. "Stand pat" — evaluate statically.  If the eval already
             beats beta, the opponent would never allow this line
             (beta cutoff).  If it raises alpha, remember it.
          2. Generate all captures, ordered Most-Valuable-Victim first
             for maximum pruning.
          3. Recurse on each capture via negamax.
          4. Prune branches that can't beat alpha (delta pruning).

        Depth limit 6 keeps the branching bounded.  In practice
        alpha-beta prunes most branches, so ~5-15 nodes are visited
        per call.
        """
        stand_pat = self._raw_heuristic(game_state)

        if depth >= 6:
            return stand_pat

        if stand_pat >= beta:
            return beta            # Beta cutoff
        if stand_pat > alpha:
            alpha = stand_pat

        # ── Generate & sort captures (MVV ordering) ──
        captures = []
        for move in game_state.get_legal_moves():
            victim = game_state.board.piece_at(move.to_square)
            if victim and victim.piece_type != chess.KING:
                captures.append(
                    (self._QS_PIECE_VAL.get(victim.piece_type, 0), move))

        if not captures:
            return stand_pat      # Quiet position — eval is accurate

        captures.sort(reverse=True)  # Most valuable victim first

        for victim_val, move in captures:
            # Delta pruning: if capturing this piece can't possibly
            # raise alpha, skip it.  (stand_pat + victim_val < alpha)
            if stand_pat + victim_val / 9.0 + 0.05 < alpha:
                continue

            child = game_state.copy()
            child.make_move(move)
            # Negamax: opponent's score is the negative of ours
            score = -self._quiescence(child, -beta, -alpha, depth + 1)

            if score >= beta:
                return beta        # Beta cutoff
            if score > alpha:
                alpha = score

        return alpha

    def _raw_heuristic(self, game_state) -> float:
        """Static eval from side-to-move's perspective (no search)."""
        if hasattr(game_state, 'heuristic_eval'):
            raw = game_state.heuristic_eval()  # White's perspective
            if hasattr(game_state, 'board') and not game_state.board.turn:
                raw = -raw
            return raw
        if hasattr(game_state, 'get_material_balance'):
            raw = game_state.get_material_balance()
            if hasattr(game_state, 'board') and not game_state.board.turn:
                raw = -raw
            return raw
        return 0.0

    def _find_winning_capture(self, game_state,
                              legal_moves: List[chess.Move]):
        """Find a capture that clearly wins material after all recaptures.

        Uses quiescence search to verify the capture is sound.  If the
        best capture exceeds the stand-pat value by ≥ 0.15 (~half a pawn
        on the tanh scale), return it.  Otherwise return None.

        This is the "forced capture" mechanism: when there's a free piece
        on the board, the AI takes it immediately without burning 300
        MCTS simulations to re-discover the obvious.
        """
        stand_pat = self._quiescence(game_state, -1.0, 1.0, depth=0)

        best_move = None
        best_score = stand_pat

        for move in legal_moves:
            victim = game_state.board.piece_at(move.to_square)
            if not victim or victim.piece_type == chess.KING:
                continue
            child = game_state.copy()
            child.make_move(move)
            score = -self._quiescence(child, -1.0, 1.0, depth=0)
            if score > best_score:
                best_score = score
                best_move = move

        # Only force if the gain is significant
        if best_move and (best_score - stand_pat) >= 0.15:
            return best_move, best_score
        return None, 0.0
    
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
            # Light exploration for opening diversity only.
            # With strong heuristic priors, MCTS can tell good from bad,
            # so let it play its best move. Dirichlet noise at root still
            # injects diversity into the training data.
            #   temp 0.30 → visit_counts^3.3 → best move gets ~95%+
            #   temp 0.05 → visit_counts^20  → effectively argmax
            if move_count < 4:
                return 0.3
            else:
                return 0.05
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

