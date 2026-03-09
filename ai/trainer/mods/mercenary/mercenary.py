#!/usr/bin/env python3
"""
╔══════════════════════════════════════════════════════════════╗
║   ChessRecast — Mercenary Mod                                ║
║  Monolith: rules + board + training in one file              ║
╚══════════════════════════════════════════════════════════════╝

Mercenary mod:
  - Pawns move and capture like Kings (1 square any direction)
  - No en passant, no two-square initial move, no pawn promotion
  - Draw: K vs K, K+N vs K+N (no pawns), 100 half-move rule

Usage:
  python mercenary.py                    # Full GPU training
  python mercenary.py --test             # Random games (rule testing)
  python mercenary.py --test --delay 1   # Slow demo mode
"""
import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import DataLoader
import numpy as np
import chess
import sys
import os
import time
import random
import json
import argparse
from pathlib import Path
from typing import List, Optional

# Add trainer/ root to path so shared modules resolve
# mercenary.py lives in trainer/mods/mercenary/, so go up 2 levels
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

from network import ChessNetPOC, count_parameters
from selfplay import ImprovedSelfPlay
from utils import (
    GPUMonitor, ChessDataset,
    get_websocket_server, TrainingLogger
)


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  Mercenary Mod Rules
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class MercenaryMode:
    """
    Mercenary mod rule overrides.
    Pawns move and capture like Kings (1 square in any direction).
    No en passant, no two-square initial move, no pawn promotion.
    """

    def get_mode_name(self) -> str:
        return "mercenary"

    def get_pawn_moves(self, board: chess.Board, from_square: int) -> List[chess.Move]:
        """Generate pseudo-legal Mercenary pawn moves (king-like, 8 directions).

        Returns moves that respect basic movement rules (board bounds, friendly
        piece blocking, no king capture) but does NOT filter for king safety.
        The caller (MercenaryBoard.get_legal_moves) handles that using
        mercenary-aware attack detection.
        """
        moves = []
        piece = board.piece_at(from_square)
        if not piece or piece.piece_type != chess.PAWN:
            return moves

        rank = chess.square_rank(from_square)
        file = chess.square_file(from_square)

        for rank_offset, file_offset in [
            (-1, -1), (-1, 0), (-1, 1),
            ( 0, -1),          ( 0, 1),
            ( 1, -1), ( 1, 0), ( 1, 1),
        ]:
            new_rank = rank + rank_offset
            new_file = file + file_offset
            if not (0 <= new_rank <= 7 and 0 <= new_file <= 7):
                continue

            to_square = chess.square(new_file, new_rank)
            target_piece = board.piece_at(to_square)

            if target_piece is None:
                moves.append(chess.Move(from_square, to_square))
            elif target_piece.color != piece.color and target_piece.piece_type != chess.KING:
                moves.append(chess.Move(from_square, to_square))

        return moves

    @staticmethod
    def should_reset_fifty_move_counter(board: chess.Board, move: chess.Move) -> bool:
        """In Mercenary mod, only captures reset the counter (not pawn moves)."""
        return board.piece_at(move.to_square) is not None

    @staticmethod
    def get_draw_conditions() -> dict:
        return {'fifty_move_limit': 60, 'insufficient_material_rules': 'mercenary'}

    @staticmethod
    def filter_moves(board: chess.Board, moves: List[chess.Move]) -> List[chess.Move]:
        return moves

    @staticmethod
    def is_game_over_custom(board: chess.Board, legal_moves: List[chess.Move]) -> Optional[bool]:
        return None


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  Board with Mercenary Rules
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class MercenaryBoard:
    """Chess board implementing Mercenary mod rules."""

    def __init__(self):
        self.board = chess.Board()
        self.mode = MercenaryMode()
        self.fifty_move_counter = 0
        self.position_history: List[str] = []
        self._add_position_to_history()

    def reset(self):
        self.board.reset()
        self.fifty_move_counter = 0
        self.position_history = []
        self._add_position_to_history()

    def _add_position_to_history(self):
        self.position_history.append(self.board.fen().split()[0])

    def _is_threefold_repetition(self) -> bool:
        if len(self.position_history) < 3:
            return False
        return self.position_history.count(self.position_history[-1]) >= 3

    # ── Legal moves ───────────────────────────────────────────

    def get_legal_moves(self) -> List[chess.Move]:
        legal_moves = []
        for square in chess.SQUARES:
            piece = self.board.piece_at(square)
            if not piece or piece.color != self.board.turn:
                continue
            if piece.piece_type == chess.PAWN:
                pseudo_moves = self.mode.get_pawn_moves(self.board, square)
            else:
                pseudo_moves = self._get_pseudo_legal_moves_for_piece(square, piece)
            for move in pseudo_moves:
                target = self.board.piece_at(move.to_square)
                if target and target.piece_type == chess.KING:
                    continue
                if self._is_legal_considering_custom_attacks(move):
                    legal_moves.append(move)
        return self.mode.filter_moves(self.board, legal_moves)

    def _get_pseudo_legal_moves_for_piece(self, from_square: int, piece: chess.Piece) -> List[chess.Move]:
        moves = []

        if piece.piece_type == chess.KNIGHT:
            for dr, df in [(-2,-1),(-2,1),(-1,-2),(-1,2),(1,-2),(1,2),(2,-1),(2,1)]:
                to = self._offset_square(from_square, dr, df)
                if to is not None:
                    t = self.board.piece_at(to)
                    if t is None or t.color != piece.color:
                        moves.append(chess.Move(from_square, to))

        elif piece.piece_type == chess.KING:
            for dr, df in [(-1,-1),(-1,0),(-1,1),(0,-1),(0,1),(1,-1),(1,0),(1,1)]:
                to = self._offset_square(from_square, dr, df)
                if to is not None:
                    t = self.board.piece_at(to)
                    if t is None or t.color != piece.color:
                        moves.append(chess.Move(from_square, to))

        elif piece.piece_type in (chess.BISHOP, chess.ROOK, chess.QUEEN):
            directions = []
            if piece.piece_type in (chess.ROOK, chess.QUEEN):
                directions += [(0,1),(0,-1),(1,0),(-1,0)]
            if piece.piece_type in (chess.BISHOP, chess.QUEEN):
                directions += [(1,1),(1,-1),(-1,1),(-1,-1)]
            for dr, df in directions:
                for dist in range(1, 8):
                    to = self._offset_square(from_square, dr*dist, df*dist)
                    if to is None:
                        break
                    t = self.board.piece_at(to)
                    if t is None:
                        moves.append(chess.Move(from_square, to))
                    else:
                        if t.color != piece.color:
                            moves.append(chess.Move(from_square, to))
                        break
        return moves

    def _offset_square(self, square: int, rank_offset: int, file_offset: int) -> Optional[int]:
        nr = chess.square_rank(square) + rank_offset
        nf = chess.square_file(square) + file_offset
        if 0 <= nr <= 7 and 0 <= nf <= 7:
            return chess.square(nf, nr)
        return None

    def _is_legal_considering_custom_attacks(self, move: chess.Move) -> bool:
        moving_color = self.board.turn
        self.board.push(move)
        king_square = self.board.king(moving_color)
        if king_square is None:
            self.board.pop()
            return False
        for square in chess.SQUARES:
            piece = self.board.piece_at(square)
            if piece and piece.color != moving_color:
                if piece.piece_type == chess.PAWN:
                    if self._can_pawn_attack_square(square, king_square):
                        self.board.pop()
                        return False
                else:
                    for m in self._get_pseudo_legal_moves_for_piece(square, piece):
                        if m.to_square == king_square:
                            self.board.pop()
                            return False
        self.board.pop()
        return True

    @staticmethod
    def _can_pawn_attack_square(pawn_square: int, target_square: int) -> bool:
        """Mercenary: pawn attacks like a king (any adjacent square)."""
        rank_diff = abs(chess.square_rank(target_square) - chess.square_rank(pawn_square))
        file_diff = abs(chess.square_file(target_square) - chess.square_file(pawn_square))
        return rank_diff <= 1 and file_diff <= 1 and (rank_diff > 0 or file_diff > 0)

    # ── Make move ─────────────────────────────────────────────

    def make_move(self, move: chess.Move) -> bool:
        if move not in self.get_legal_moves():
            print(f"⚠️ Move {move.uci()} not in legal moves!")
            return False
        if self.mode.should_reset_fifty_move_counter(self.board, move):
            self.fifty_move_counter = 0
        else:
            self.fifty_move_counter += 1
        self.board.push(move)
        self._add_position_to_history()
        return True

    # ── Game over ─────────────────────────────────────────────

    def is_game_over(self) -> bool:
        if self.board.king(chess.WHITE) is None:
            print("🚨 CRITICAL ERROR: White king is missing!")
            return True
        if self.board.king(chess.BLACK) is None:
            print("🚨 CRITICAL ERROR: Black king is missing!")
            return True
        legal_moves = self.get_legal_moves()
        custom = self.mode.is_game_over_custom(self.board, legal_moves)
        if custom is not None:
            return custom
        if not legal_moves:
            return True
        draw = self.mode.get_draw_conditions()
        if self.fifty_move_counter >= draw['fifty_move_limit']:
            return True
        if self._is_threefold_repetition():
            return True
        if self._is_insufficient_material():
            return True
        return False

    def _is_insufficient_material(self) -> bool:
        pieces = [self.board.piece_at(sq) for sq in chess.SQUARES if self.board.piece_at(sq)]
        if len(pieces) == 2:
            return True
        if len(pieces) == 3:
            types = [p.piece_type for p in pieces]
            if chess.KNIGHT in types or chess.BISHOP in types:
                return True
        return False

    def get_result(self) -> str:
        if not self.is_game_over():
            return '*'
        legal_moves = self.get_legal_moves()
        if not legal_moves:
            if self._is_king_attacked(self.board.turn):
                # Side to move is in check with no legal moves = checkmate
                return '0-1' if self.board.turn == chess.WHITE else '1-0'
            return 'draw_stalemate'
        draw = self.mode.get_draw_conditions()
        if self.fifty_move_counter >= draw['fifty_move_limit']:
            return 'draw_fifty_move'
        if self._is_threefold_repetition():
            return 'draw_repetition'
        if self._is_insufficient_material():
            return 'draw_insufficient_material'
        return 'draw'

    def _is_king_attacked(self, color: bool) -> bool:
        """Check if the king of `color` is under attack using Mercenary rules.
        
        python-chess's board.is_check() doesn't know that pawns attack like
        kings in Mercenary mode, so we need our own check detection.
        """
        king_sq = self.board.king(color)
        if king_sq is None:
            return False
        enemy = not color
        for sq in chess.SQUARES:
            piece = self.board.piece_at(sq)
            if piece and piece.color == enemy:
                if piece.piece_type == chess.PAWN:
                    # Mercenary: pawn attacks all adjacent squares
                    if self._can_pawn_attack_square(sq, king_sq):
                        return True
                else:
                    for m in self._get_pseudo_legal_moves_for_piece(sq, piece):
                        if m.to_square == king_sq:
                            return True
        return False

    # ── Tensor / Copy ─────────────────────────────────────────

    def get_board_tensor(self) -> np.ndarray:
        """Board state as an (8, 8, 17) tensor for the neural network.

        Planes 0-11:  Piece positions (6 types x 2 colors, binary)
        Plane 12:     Side to move (1.0 = white, 0.0 = black)
        Plane 13:     Position repetition count (0.0/0.5/1.0)
        Plane 14:     Fifty-move counter, normalized (counter / 100)
        Plane 15:     White material, normalized (total / 39)
        Plane 16:     Black material, normalized (total / 39)

        The extra planes give the network awareness of whose turn it is,
        draw proximity, and material balance — all critical for learning
        strategy in Mercenary mode where checkmate is rare.
        """
        tensor = np.zeros((8, 8, 17), dtype=np.float32)
        plane_map = {chess.PAWN: 0, chess.KNIGHT: 1, chess.BISHOP: 2,
                     chess.ROOK: 3, chess.QUEEN: 4, chess.KING: 5}

        piece_values = {chess.PAWN: 1.0, chess.KNIGHT: 3.0, chess.BISHOP: 3.0,
                        chess.ROOK: 5.0, chess.QUEEN: 9.0}
        white_mat = 0.0
        black_mat = 0.0

        for sq in chess.SQUARES:
            p = self.board.piece_at(sq)
            if p:
                pl = plane_map[p.piece_type] + (6 if p.color == chess.BLACK else 0)
                tensor[chess.square_rank(sq), chess.square_file(sq), pl] = 1.0
                if p.piece_type != chess.KING:
                    val = piece_values.get(p.piece_type, 0.0)
                    if p.color == chess.WHITE:
                        white_mat += val
                    else:
                        black_mat += val

        # Plane 12: side to move
        if self.board.turn == chess.WHITE:
            tensor[:, :, 12] = 1.0

        # Plane 13: repetition count (0 = first, 0.5 = seen once, 1.0 = seen 2+)
        if self.position_history:
            rep = self.position_history.count(self.position_history[-1]) - 1
            tensor[:, :, 13] = min(rep / 2.0, 1.0)

        # Plane 14: fifty-move counter (normalized)
        tensor[:, :, 14] = self.fifty_move_counter / 100.0

        # Planes 15-16: material per side (normalized by starting total 39)
        tensor[:, :, 15] = white_mat / 39.0
        tensor[:, :, 16] = black_mat / 39.0

        return tensor

    def copy(self):
        nb = MercenaryBoard()
        nb.board = self.board.copy()
        nb.fifty_move_counter = self.fifty_move_counter
        nb.position_history = self.position_history.copy()
        return nb

    def fen(self) -> str:
        return self.board.fen()

    def get_material_balance(self) -> float:
        """Evaluate material balance from White's perspective.
        
        Returns a value in [-1, 1] where:
          +1.0 = White has overwhelming material advantage
          -1.0 = Black has overwhelming material advantage
           0.0 = Material is equal
        
        In Mercenary mode pawns are weaker (no promotion), so they're
        valued lower than standard chess. Piece values:
          Pawn=1, Knight=3, Bishop=3, Rook=5, Queen=9
        """
        piece_values = {
            chess.PAWN: 1.0,
            chess.KNIGHT: 3.0,
            chess.BISHOP: 3.0,
            chess.ROOK: 5.0,
            chess.QUEEN: 9.0,
        }
        white_material = 0.0
        black_material = 0.0
        for sq in chess.SQUARES:
            piece = self.board.piece_at(sq)
            if piece and piece.piece_type != chess.KING:
                val = piece_values.get(piece.piece_type, 0.0)
                if piece.color == chess.WHITE:
                    white_material += val
                else:
                    black_material += val
        
        total = white_material + black_material
        if total == 0:
            return 0.0
        # Normalize to [-1, 1] — divide by starting material (39 per side)
        return max(-1.0, min(1.0, (white_material - black_material) / 39.0))

    def heuristic_eval(self) -> float:
        """Fast handcrafted evaluation for bootstrapping MCTS.

        Returns value in [-1, 1] from White's perspective.
        Combines material balance, piece activity (central control),
        and king safety (pawn shield). This gives MCTS a usable value
        signal before the neural network has learned anything.

        Called thousands of times per game (every MCTS leaf), so must
        be fast — no legal-move generation.
        """
        PIECE_VAL = {
            chess.PAWN: 1.0, chess.KNIGHT: 3.0, chess.BISHOP: 3.0,
            chess.ROOK: 5.0, chess.QUEEN: 9.0,
        }
        # Central squares get a bonus for piece activity
        CENTER_BONUS = {}
        for sq in chess.SQUARES:
            r, f = chess.square_rank(sq), chess.square_file(sq)
            # Manhattan distance from center (3.5, 3.5)
            dist = abs(r - 3.5) + abs(f - 3.5)
            CENTER_BONUS[sq] = max(0, (3.5 - dist) / 3.5)  # 0..1

        w_mat = 0.0; b_mat = 0.0
        w_activity = 0.0; b_activity = 0.0
        w_king_sq = None; b_king_sq = None

        for sq in chess.SQUARES:
            p = self.board.piece_at(sq)
            if not p:
                continue
            if p.piece_type == chess.KING:
                if p.color == chess.WHITE:
                    w_king_sq = sq
                else:
                    b_king_sq = sq
                continue
            val = PIECE_VAL.get(p.piece_type, 0.0)
            bonus = CENTER_BONUS[sq] * 0.15  # Up to +0.15 per piece
            if p.color == chess.WHITE:
                w_mat += val
                w_activity += bonus
            else:
                b_mat += val
                b_activity += bonus

        # Material component (dominant — captures must matter)
        mat_score = (w_mat - b_mat) / 39.0  # [-1, 1]

        # Activity component (minor — encourages central play)
        act_score = (w_activity - b_activity) / 2.5  # roughly [-1, 1]

        # King safety: count friendly pawns adjacent to king
        w_shield = 0.0; b_shield = 0.0
        if w_king_sq is not None:
            for dr in [-1, 0, 1]:
                for df in [-1, 0, 1]:
                    if dr == 0 and df == 0:
                        continue
                    nr = chess.square_rank(w_king_sq) + dr
                    nf = chess.square_file(w_king_sq) + df
                    if 0 <= nr <= 7 and 0 <= nf <= 7:
                        adj = self.board.piece_at(chess.square(nf, nr))
                        if adj and adj.color == chess.WHITE and adj.piece_type == chess.PAWN:
                            w_shield += 1.0
        if b_king_sq is not None:
            for dr in [-1, 0, 1]:
                for df in [-1, 0, 1]:
                    if dr == 0 and df == 0:
                        continue
                    nr = chess.square_rank(b_king_sq) + dr
                    nf = chess.square_file(b_king_sq) + df
                    if 0 <= nr <= 7 and 0 <= nf <= 7:
                        adj = self.board.piece_at(chess.square(nf, nr))
                        if adj and adj.color == chess.BLACK and adj.piece_type == chess.PAWN:
                            b_shield += 1.0
        safety_score = (w_shield - b_shield) / 8.0  # [-1, 1]

        # Weighted combination: material >> activity > safety
        raw = 0.70 * mat_score + 0.20 * act_score + 0.10 * safety_score
        return max(-1.0, min(1.0, raw))



# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  Main Training / Test Loop
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

def train_mercenary(test_mode=False, move_delay=0.3):
    """Train Mercenary AI or run test games.

    Args:
        test_mode: If True, play random games without training (for testing rules)
        move_delay: Delay in seconds between moves (0.1-10, default 0.3)
    """

    log = TrainingLogger(mode='mercenary')

    log.banner(
        title='MERCENARY MOD',
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

    # Configuration
    if test_mode:
        NUM_ITERATIONS = 999999
        GAMES_PER_ITERATION = 1
        MCTS_SIMULATIONS = 0
        EPOCHS_PER_ITERATION = 0
        BATCH_SIZE = 1
        LEARNING_RATE = 0.0005
        NUM_WORKERS = 0
        log.config({'Mod': 'Test / Demo', 'Move delay': f'{move_delay}s'},
                   label='Test Mod Configuration')
    elif DEVICE == 'cpu':
        NUM_ITERATIONS = 50
        GAMES_PER_ITERATION = 10
        MCTS_SIMULATIONS = 20
        EPOCHS_PER_ITERATION = 5
        BATCH_SIZE = 32
        LEARNING_RATE = 0.001
        NUM_WORKERS = 0
        log.config({'Iterations': NUM_ITERATIONS,
                    'MCTS simulations': f'{MCTS_SIMULATIONS} (lighter)'},
                   label='CPU Training Configuration')
    else:
        NUM_ITERATIONS = 200
        GAMES_PER_ITERATION = 50
        MCTS_SIMULATIONS = 150
        EPOCHS_PER_ITERATION = 15
        BATCH_SIZE = 512
        LEARNING_RATE = 0.0005
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

    # GPU optimizations
    if DEVICE == 'cuda':
        torch.backends.cudnn.benchmark = True
        torch.backends.cuda.matmul.allow_tf32 = True
        torch.backends.cudnn.allow_tf32 = True
        torch.set_float32_matmul_precision('high')
        log.gpu_optimizations(['cuDNN benchmark', 'TensorFloat-32', 'High precision matmul'])

    # Neural Network
    if not test_mode:
        if DEVICE == 'cuda':
            model = ChessNetPOC(num_channels=128, num_res_blocks=10, input_channels=17).to(DEVICE)
            log.network_info(128, 10, count_parameters(model), DEVICE)
        else:
            model = ChessNetPOC(num_channels=64, num_res_blocks=4, input_channels=17).to(DEVICE)
            log.network_info(64, 4, count_parameters(model), DEVICE)
    else:
        model = None
        log.info('Test mod: No neural network (random moves)')

    # Optimizer
    if not test_mode:
        optimizer = optim.AdamW(model.parameters(), lr=LEARNING_RATE,
                                weight_decay=1e-4, betas=(0.9, 0.999))
        scheduler = optim.lr_scheduler.CosineAnnealingLR(
            optimizer, T_max=NUM_ITERATIONS, eta_min=1e-5)
        scaler = torch.cuda.amp.GradScaler() if DEVICE == 'cuda' else None
        policy_loss_fn = nn.CrossEntropyLoss()
        value_loss_fn = nn.MSELoss()
        log.info('AdamW + Cosine LR schedule + Mixed Precision')

    checkpoint_dir = Path('/workspace/checkpoints/mercenary')
    checkpoint_dir.mkdir(parents=True, exist_ok=True)

    gpu_monitor = GPUMonitor()
    gpu_monitor.start()
    log.info('GPU monitoring started')

    ws_server = get_websocket_server()
    log.info('WebSocket server started (ws://0.0.0.0:8765)')

    # ══════════════════════════════════════════════════════════
    #  TEST MODE
    # ══════════════════════════════════════════════════════════

    if test_mode:
        log.test_mode_banner(move_delay)
        game_num = 0

        try:
            while True:
                game_num += 1
                game = MercenaryBoard()
                move_count = 0

                ws_server.clear_validation_error()
                ws_server.start_game(1, game_num, mode='mercenary')
                log.test_game_start(game_num, game.board.fen())

                game_stopped_due_to_error = False

                while not game.is_game_over() and move_count < 200:
                    if ws_server.has_validation_error():
                        error = ws_server.last_validation_error
                        log.validation_error(
                            error.get('move_number', 0),
                            error.get('move_uci', ''),
                            error.get('error_message', ''))
                        game_stopped_due_to_error = True
                        break

                    legal_moves = game.get_legal_moves()
                    if not legal_moves:
                        break

                    move = random.choice(legal_moves)
                    turn_color = 'white' if game.board.turn else 'black'
                    move_success = game.make_move(move)

                    if not move_success:
                        log.critical_error(
                            f'Move {move.uci()} was in legal_moves but make_move rejected it!',
                            game.board.fen())
                        game_stopped_due_to_error = True
                        break

                    move_count += 1

                    if game.board.king(True) is None:
                        log.critical_error(f'White king missing after {move.uci()}!', game.board.fen())
                        game_stopped_due_to_error = True
                        break
                    if game.board.king(False) is None:
                        log.critical_error(f'Black king missing after {move.uci()}!', game.board.fen())
                        game_stopped_due_to_error = True
                        break

                    ws_server.send_move(
                        move_num=move_count, move_uci=move.uci(), turn=turn_color,
                        fen=game.board.fen(), value=0.0,
                        top_moves=[{'move': move.uci(), 'probability': 1.0}])

                    log.test_move(move_count, move.uci(), turn_color)
                    time.sleep(move_delay)

                if game_stopped_due_to_error:
                    ws_server.end_game('ERROR')
                    log.test_game_end(game_num, 'ERROR', move_count)
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

    # ══════════════════════════════════════════════════════════
    #  TRAINING MODE
    # ══════════════════════════════════════════════════════════

    training_start = time.time()
    metrics_history = []

    log.section('🚀', 'TRAINING MERCENARY AI')

    for iteration in range(1, NUM_ITERATIONS + 1):
        iter_start = time.time()

        gpu_util = gpu_monitor.get_utilization()
        log.iteration_start(iteration, NUM_ITERATIONS, gpu_util)

        temperature = max(0.5, 1.5 - (iteration / NUM_ITERATIONS) * 1.0)

        # ── Self-play ─────────────────────────────────────────
        log.self_play_header(GAMES_PER_ITERATION, MCTS_SIMULATIONS, temperature)

        # Heuristic weight: start high (trust handcrafted eval when NN is
        # random), decay linearly to near-zero as the network improves.
        # Iteration 1 → 0.80,  50 → 0.60,  100 → 0.40,  200 → 0.0
        heuristic_weight = max(0.0, 0.80 - 0.80 * ((iteration - 1) / max(1, NUM_ITERATIONS - 1)))

        self_play = ImprovedSelfPlay(
            model, device=DEVICE, num_simulations=MCTS_SIMULATIONS,
            batch_size=64, game_class=MercenaryBoard,
            heuristic_weight=heuristic_weight)

        all_data = []
        wins_white = 0
        wins_black = 0
        draws = 0

        with torch.no_grad():
            for game_num in range(GAMES_PER_ITERATION):
                _game_start = time.time()

                ws_server.clear_validation_error()
                ws_server.start_game(iteration, game_num + 1, mode='mercenary')

                game_history, game_result = self_play.play_game(
                    temperature_schedule='decay',
                    verbose=True,
                    ws_server=ws_server,
                    logger=log)
                all_data.extend(game_history)

                _game_elapsed = time.time() - _game_start
                hw_status = gpu_monitor.get_status_str()
                log.game_result(game_num + 1, GAMES_PER_ITERATION,
                                len(game_history), _game_elapsed,
                                hw_status=hw_status)

                if game_history:
                    if game_result == '1-0':
                        wins_white += 1
                    elif game_result == '0-1':
                        wins_black += 1
                    else:
                        draws += 1
                    ws_server.end_game(game_result)
                    log.training_game_end(game_num + 1, GAMES_PER_ITERATION,
                                          game_result, len(game_history))

                if (game_num + 1) % 10 == 0:
                    gpu_util = gpu_monitor.get_utilization()
                    log.games_progress(game_num + 1, GAMES_PER_ITERATION,
                                       len(all_data), wins_white, draws,
                                       wins_black, gpu_util)

        log.self_play_summary(len(all_data), wins_white, draws, wins_black)

        # ── Training ──────────────────────────────────────────
        log.training_header(EPOCHS_PER_ITERATION, BATCH_SIZE)
        dataset = ChessDataset(all_data)
        dataloader = DataLoader(
            dataset, batch_size=BATCH_SIZE, shuffle=True,
            num_workers=NUM_WORKERS, pin_memory=True,
            prefetch_factor=2 if NUM_WORKERS > 0 else None)

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
                with torch.cuda.amp.autocast():
                    pred_policy, pred_value = model(states)
                    policy_loss = policy_loss_fn(pred_policy, policies)
                    value_loss = value_loss_fn(pred_value, values)
                    loss = policy_loss + value_loss

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
                log.epoch_result(epoch + 1, EPOCHS_PER_ITERATION,
                                 total_loss, avg_policy_loss, avg_value_loss)

        scheduler.step()
        current_lr = scheduler.get_last_lr()[0]

        # Checkpoint
        checkpoint_name = ''
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

        metrics_history.append({
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
            'time_seconds': time.time() - iter_start,
        })

        log.iteration_summary(iteration, NUM_ITERATIONS,
                              epoch_losses[-1], current_lr, checkpoint_name)

    # ── Final save ────────────────────────────────────────────
    final_path = checkpoint_dir / 'mercenary_final.pth'
    torch.save(model.state_dict(), final_path)

    metrics_path = checkpoint_dir / 'training_metrics.json'
    with open(metrics_path, 'w') as f:
        json.dump(metrics_history, f, indent=2)

    log.save_final(str(final_path), str(metrics_path))
    log.training_complete((time.time() - training_start) / 3600)


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  CLI Entry Point
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='ChessRecast — Mercenary Mod AI')
    parser.add_argument('--test', action='store_true',
                        help='Random games for rule testing')
    parser.add_argument('--delay', type=float, default=0.3,
                        help='Move delay 0.1-10s (default 0.3)')
    args = parser.parse_args()
    train_mercenary(test_mode=args.test,
                    move_delay=max(0.1, min(10.0, args.delay)))
