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
  python mercenary.py --test --delay 1   # Slow demo mode (default 0.05s)
"""
import math
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
#  Piece-Square Tables (PST) — positional guidance for heuristic
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Indexed by square (a1=0 .. h8=63), values in centipawns.
# White uses table directly; Black mirrors rank: (7-r)*8+f.
# These give the heuristic a gradient for quiet positions so
# "knight on d4" scores higher than "knight on a1".

_KNIGHT_PST = [
    -50, -40, -30, -30, -30, -30, -40, -50,
    -40, -20,   0,   5,   5,   0, -20, -40,
    -30,   0,  10,  15,  15,  10,   0, -30,
    -30,   5,  15,  20,  20,  15,   5, -30,
    -30,   0,  15,  20,  20,  15,   0, -30,
    -30,   5,  10,  15,  15,  10,   5, -30,
    -40, -20,   0,   5,   5,   0, -20, -40,
    -50, -40, -30, -30, -30, -30, -40, -50,
]

_BISHOP_PST = [
    -20, -10, -10, -10, -10, -10, -10, -20,
    -10,   5,   0,   0,   0,   0,   5, -10,
    -10,  10,  10,  10,  10,  10,  10, -10,
    -10,   0,  10,  15,  15,  10,   0, -10,
    -10,   5,   5,  10,  10,   5,   5, -10,
    -10,   0,   5,  10,  10,   5,   0, -10,
    -10,   0,   0,   0,   0,   0,   0, -10,
    -20, -10, -10, -10, -10, -10, -10, -20,
]

_ROOK_PST = [
      0,   0,   0,   5,   5,   0,   0,   0,
     -5,   0,   0,   0,   0,   0,   0,  -5,
     -5,   0,   0,   0,   0,   0,   0,  -5,
     -5,   0,   0,   0,   0,   0,   0,  -5,
     -5,   0,   0,   0,   0,   0,   0,  -5,
     -5,   0,   0,   0,   0,   0,   0,  -5,
      5,  10,  10,  10,  10,  10,  10,   5,
      0,   0,   0,   5,   5,   0,   0,   0,
]

_QUEEN_PST = [
    -20, -10, -10,  -5,  -5, -10, -10, -20,
    -10,   0,   5,   0,   0,   0,   0, -10,
    -10,   5,   5,   5,   5,   5,   0, -10,
      0,   0,   5,   5,   5,   5,   0,  -5,
     -5,   0,   5,   5,   5,   5,   0,  -5,
    -10,   0,   5,   5,   5,   5,   0, -10,
    -10,   0,   0,   0,   0,   0,   0, -10,
    -20, -10, -10,  -5,  -5, -10, -10, -20,
]

# Mercenary pawns: centrality-focused (NO promotion — rank 7/8 useless)
# Pawns move like kings, so central = more useful squares.
# Peak at ranks 4-5, symmetric drop toward edges.
_PAWN_PST = [
      0,   0,   0,   0,   0,   0,   0,   0,
      5,   8,  12,  15,  15,  12,   8,   5,
      8,  14,  20,  24,  24,  20,  14,   8,
     10,  18,  25,  30,  30,  25,  18,  10,
     12,  20,  26,  30,  30,  26,  20,  12,
      8,  14,  20,  24,  24,  20,  14,   8,
      3,   5,   8,  10,  10,   8,   5,   3,
      0,   0,   0,   0,   0,   0,   0,   0,
]

# King: safe in corners (middlegame), central (endgame)
_KING_MG_PST = [
     20,  30,  10,   0,   0,  10,  30,  20,
     20,  20,   0,   0,   0,   0,  20,  20,
    -10, -20, -20, -20, -20, -20, -20, -10,
    -20, -30, -30, -40, -40, -30, -30, -20,
    -30, -40, -40, -50, -50, -40, -40, -30,
    -30, -40, -40, -50, -50, -40, -40, -30,
    -30, -40, -40, -50, -50, -40, -40, -30,
    -30, -40, -40, -50, -50, -40, -40, -30,
]

_KING_EG_PST = [
    -50, -30, -30, -30, -30, -30, -30, -50,
    -30, -30,   0,   0,   0,   0, -30, -30,
    -30, -10,  20,  30,  30,  20, -10, -30,
    -30, -10,  30,  40,  40,  30, -10, -30,
    -30, -10,  30,  40,  40,  30, -10, -30,
    -30, -10,  20,  30,  30,  20, -10, -30,
    -30, -20, -10,   0,   0, -10, -20, -30,
    -50, -40, -30, -20, -20, -30, -40, -50,
]

_PST_MAP = {
    chess.KNIGHT: _KNIGHT_PST,
    chess.BISHOP: _BISHOP_PST,
    chess.ROOK: _ROOK_PST,
    chess.QUEEN: _QUEEN_PST,
    chess.PAWN: _PAWN_PST,
}

# Pawn positional value by rank (index 0 = rank 1, 7 = rank 8).
# White's perspective.  Peaks at center ranks (4-5), drops at edges.
# No promotion in Mercenary — rank 7/8 pawns have reduced mobility.
_PAWN_RANK_VALUE = [0.00, 0.10, 0.30, 0.60, 0.85, 1.00, 0.55, 0.15]


def _soft_clamp(x):
    """Clamp to (-1, 1) without saturation.

    Below |0.9|: identity (no change to existing eval behavior).
    Above |0.9|: exponential compression toward +/-1.0 that preserves
    ordering — a better raw score always produces a higher output.

    This prevents MCTS from becoming blind when one side has an
    overwhelming advantage: without this, all positions clamp to
    identical +/-1.0, making every move look equally good.
    """
    if abs(x) <= 0.9:
        return x
    sign = 1.0 if x > 0 else -1.0
    excess = abs(x) - 0.9
    return sign * (0.9 + 0.1 * (1.0 - math.exp(-excess * 3.0)))


def _pst_score(piece_type, sq, color):
    """Lookup PST value in centipawns (positive = good for that color)."""
    pst = _PST_MAP.get(piece_type)
    if pst is None:
        return 0
    r, f = chess.square_rank(sq), chess.square_file(sq)
    if color == chess.BLACK:
        r = 7 - r
    return pst[r * 8 + f]


def _king_pst_score(sq, color, total_material):
    """King PST with middlegame/endgame interpolation (centipawns)."""
    r, f = chess.square_rank(sq), chess.square_file(sq)
    if color == chess.BLACK:
        r = 7 - r
    idx = r * 8 + f
    # Smooth transition: full MG at 40 material, full EG at 10
    eg_w = max(0.0, min(1.0, (40.0 - total_material) / 30.0))
    return _KING_MG_PST[idx] * (1.0 - eg_w) + _KING_EG_PST[idx] * eg_w


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
        return {'fifty_move_limit': 100, 'insufficient_material_rules': 'mercenary'}

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
        kr = chess.square_rank(king_square)
        kf = chess.square_file(king_square)
        in_check = False
        for square in chess.SQUARES:
            piece = self.board.piece_at(square)
            if not piece or piece.color == moving_color:
                continue
            pr = chess.square_rank(square)
            pf = chess.square_file(square)
            pt = piece.piece_type
            if pt == chess.PAWN or pt == chess.KING:
                # Both attack all adjacent squares in Mercenary
                if abs(pr - kr) <= 1 and abs(pf - kf) <= 1 and (pr != kr or pf != kf):
                    in_check = True
                    break
            elif pt == chess.KNIGHT:
                dr, df = abs(pr - kr), abs(pf - kf)
                if (dr == 2 and df == 1) or (dr == 1 and df == 2):
                    in_check = True
                    break
            else:
                # Slider (bishop/rook/queen): ray check without generating moves
                dr = kr - pr
                df = kf - pf
                # Rook/Queen: same rank or file
                can_rook = (pt == chess.ROOK or pt == chess.QUEEN) and (dr == 0 or df == 0)
                # Bishop/Queen: same diagonal
                can_bishop = (pt == chess.BISHOP or pt == chess.QUEEN) and abs(dr) == abs(df)
                if not (can_rook or can_bishop):
                    continue
                # Check ray is clear
                step_r = (1 if dr > 0 else -1) if dr != 0 else 0
                step_f = (1 if df > 0 else -1) if df != 0 else 0
                cr, cf = pr + step_r, pf + step_f
                clear = True
                while cr != kr or cf != kf:
                    if self.board.piece_at(chess.square(cf, cr)) is not None:
                        clear = False
                        break
                    cr += step_r
                    cf += step_f
                if clear:
                    in_check = True
                    break
        self.board.pop()
        return not in_check

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

    def make_move_unchecked(self, move: chess.Move):
        """Push move without legality check (fast path for MCTS/QS).

        ONLY call when the move was already validated by get_legal_moves().
        Saves ~2ms per call by skipping redundant legal move generation.
        """
        if self.mode.should_reset_fifty_move_counter(self.board, move):
            self.fifty_move_counter = 0
        else:
            self.fifty_move_counter += 1
        self.board.push(move)
        self._add_position_to_history()

    # ── Game over ─────────────────────────────────────────────

    def is_game_over(self) -> bool:
        if self.board.king(chess.WHITE) is None:
            print("🚨 CRITICAL ERROR: White king is missing!")
            return True
        if self.board.king(chess.BLACK) is None:
            print("🚨 CRITICAL ERROR: Black king is missing!")
            return True
        # Check cheap draw conditions BEFORE expensive legal-move gen
        draw = self.mode.get_draw_conditions()
        if self.fifty_move_counter >= draw['fifty_move_limit']:
            return True
        if self._is_threefold_repetition():
            return True
        if self._is_insufficient_material():
            return True
        legal_moves = self.get_legal_moves()
        custom = self.mode.is_game_over_custom(self.board, legal_moves)
        if custom is not None:
            return custom
        if not legal_moves:
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
        
        Uses direct distance/ray checks instead of generating all moves.
        """
        king_sq = self.board.king(color)
        if king_sq is None:
            return False
        kr = chess.square_rank(king_sq)
        kf = chess.square_file(king_sq)
        enemy = not color
        for sq in chess.SQUARES:
            piece = self.board.piece_at(sq)
            if not piece or piece.color != enemy:
                continue
            pr = chess.square_rank(sq)
            pf = chess.square_file(sq)
            pt = piece.piece_type
            if pt == chess.PAWN or pt == chess.KING:
                if abs(pr - kr) <= 1 and abs(pf - kf) <= 1 and (pr != kr or pf != kf):
                    return True
            elif pt == chess.KNIGHT:
                dr, df = abs(pr - kr), abs(pf - kf)
                if (dr == 2 and df == 1) or (dr == 1 and df == 2):
                    return True
            else:
                dr = kr - pr
                df = kf - pf
                can_rook = (pt == chess.ROOK or pt == chess.QUEEN) and (dr == 0 or df == 0)
                can_bishop = (pt == chess.BISHOP or pt == chess.QUEEN) and abs(dr) == abs(df)
                if not (can_rook or can_bishop):
                    continue
                step_r = (1 if dr > 0 else -1) if dr != 0 else 0
                step_f = (1 if df > 0 else -1) if df != 0 else 0
                cr, cf = pr + step_r, pf + step_f
                clear = True
                while cr != kr or cf != kf:
                    if self.board.piece_at(chess.square(cf, cr)) is not None:
                        clear = False
                        break
                    cr += step_r
                    cf += step_f
                if clear:
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
        Components:
          1. Material balance  (tanh-scaled, dominant weight)
          2. Hanging pieces    (attacked by cheaper enemy)
          3. Piece mobility    (more legal moves = better position)
          4. Piece placement   (PST — positional quality of each piece)
          5. King safety       (pawn shield around king)
          6. Repetition penalty (break move cycles)
          7. Endgame king chase / centralisation
          8. Pawn positioning + connectivity (NO promotion)
          9. Territorial control  (pieces on opponent's side)
         10. Fifty-move draw pressure (urgency to capture/push)
         11. Decisive advantage (extra bonus when far ahead)
        """
        PIECE_VAL = {
            chess.PAWN: 1.0, chess.KNIGHT: 3.0, chess.BISHOP: 3.0,
            chess.ROOK: 5.0, chess.QUEEN: 9.0,
        }

        w_mat = 0.0; b_mat = 0.0
        w_pst = 0.0; b_pst = 0.0
        w_king_sq = None; b_king_sq = None
        pieces = []  # (square, piece_type, color, value, rank, file)
        w_pawn_advance = 0.0; b_pawn_advance = 0.0

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
            r = chess.square_rank(sq)
            f = chess.square_file(sq)
            pieces.append((sq, p.piece_type, p.color, val, r, f))
            if p.color == chess.WHITE:
                w_mat += val
                w_pst += _pst_score(p.piece_type, sq, chess.WHITE)
                if p.piece_type == chess.PAWN:
                    w_pawn_advance += _PAWN_RANK_VALUE[r]
            else:
                b_mat += val
                b_pst += _pst_score(p.piece_type, sq, chess.BLACK)
                if p.piece_type == chess.PAWN:
                    b_pawn_advance += _PAWN_RANK_VALUE[7 - r]

        # ── 1. Material balance (non-linear) ──
        mat_score = math.tanh((w_mat - b_mat) * 0.3)

        # ── Decisive advantage ──
        # When one side has >= 5 pawns worth of material advantage
        # (a piece + pawns), the position is nearly won.  Push the
        # eval toward +/-0.70 but NOT to 1.0 — leave headroom for
        # mating-quality signals so MCTS can differentiate "winning
        # but shuffling" from "about to checkmate".
        #   5 ahead → +0.08,  9 ahead → +0.12,  15+ → +0.15
        mat_diff_raw = w_mat - b_mat
        decisive_bonus = 0.0
        if abs(mat_diff_raw) >= 5.0:
            decisive_bonus = min(0.15, 0.08 + (abs(mat_diff_raw) - 5.0) * 0.02)
            if mat_diff_raw < 0:
                decisive_bonus = -decisive_bonus

        # ── 2. Hanging pieces ──
        piece_at_sq = {}
        for sq, ptype, color, val, r, f in pieces:
            piece_at_sq[sq] = (ptype, color, val)
        if w_king_sq is not None:
            piece_at_sq[w_king_sq] = (chess.KING, chess.WHITE, 0.0)
        if b_king_sq is not None:
            piece_at_sq[b_king_sq] = (chess.KING, chess.BLACK, 0.0)

        w_hanging = 0.0; b_hanging = 0.0
        for sq, ptype, color, val, r, f in pieces:
            if val <= 1.0:
                continue
            cheapest_attacker = 99.0
            # Adjacent: pawn or king attacks (Mercenary)
            for dr in range(-1, 2):
                for df in range(-1, 2):
                    if dr == 0 and df == 0:
                        continue
                    nr, nf = r + dr, f + df
                    if 0 <= nr <= 7 and 0 <= nf <= 7:
                        asq = chess.square(nf, nr)
                        if asq in piece_at_sq:
                            at, ac, av = piece_at_sq[asq]
                            if ac != color and at == chess.PAWN:
                                cheapest_attacker = min(cheapest_attacker, 1.0)
                            elif ac != color and at == chess.KING:
                                cheapest_attacker = min(cheapest_attacker, 0.0)
            # Knight attacks
            for kdr, kdf in [(-2,-1),(-2,1),(-1,-2),(-1,2),
                             (1,-2),(1,2),(2,-1),(2,1)]:
                nr, nf = r + kdr, f + kdf
                if 0 <= nr <= 7 and 0 <= nf <= 7:
                    asq = chess.square(nf, nr)
                    if asq in piece_at_sq:
                        at, ac, av = piece_at_sq[asq]
                        if ac != color and at == chess.KNIGHT:
                            cheapest_attacker = min(cheapest_attacker, 3.0)
            # Slider attacks (bishop, rook, queen)
            if cheapest_attacker > 3.0:
                for esq, ept, ec, ev, er, ef in pieces:
                    if ec == color:
                        continue
                    if ept not in (chess.BISHOP, chess.ROOK, chess.QUEEN):
                        continue
                    ddr = r - er
                    ddf = f - ef
                    can_rook = ept in (chess.ROOK, chess.QUEEN) and (
                        ddr == 0 or ddf == 0) and (ddr != 0 or ddf != 0)
                    can_bishop = ept in (chess.BISHOP, chess.QUEEN) and (
                        abs(ddr) == abs(ddf) and ddr != 0)
                    if not (can_rook or can_bishop):
                        continue
                    sr = (1 if ddr > 0 else -1) if ddr != 0 else 0
                    sf = (1 if ddf > 0 else -1) if ddf != 0 else 0
                    cr, cf = er + sr, ef + sf
                    clear = True
                    while cr != r or cf != f:
                        bsq = chess.square(cf, cr)
                        if bsq in piece_at_sq:
                            clear = False
                            break
                        cr += sr; cf += sf
                    if clear:
                        cheapest_attacker = min(cheapest_attacker, ev)
                        if cheapest_attacker <= 3.0:
                            break
            if cheapest_attacker < val:
                loss = val - cheapest_attacker
                if color == chess.WHITE:
                    w_hanging += loss
                else:
                    b_hanging += loss
        threat_score = (b_hanging - w_hanging) / 16.0

        # ── 3. Piece mobility (fast square counting) ──
        # Count reachable squares for each side WITHOUT creating
        # Move objects.  Directly counts destination squares via
        # ray-casting for sliders and jump tables for knights/kings.
        # This is ~3-5x faster than _get_pseudo_legal_moves_for_piece().
        w_mobility = 0; b_mobility = 0
        for sq, ptype, color, val, r, f in pieces:
            if ptype == chess.PAWN or ptype == chess.KING:
                continue
            count = 0
            if ptype == chess.KNIGHT:
                for kdr, kdf in ((-2,-1),(-2,1),(-1,-2),(-1,2),
                                 (1,-2),(1,2),(2,-1),(2,1)):
                    nr, nf = r + kdr, f + kdf
                    if 0 <= nr <= 7 and 0 <= nf <= 7:
                        asq = chess.square(nf, nr)
                        if asq not in piece_at_sq or piece_at_sq[asq][1] != color:
                            count += 1
            elif ptype == chess.BISHOP:
                for dr, df in ((1,1),(1,-1),(-1,1),(-1,-1)):
                    nr, nf = r + dr, f + df
                    while 0 <= nr <= 7 and 0 <= nf <= 7:
                        asq = chess.square(nf, nr)
                        if asq in piece_at_sq:
                            if piece_at_sq[asq][1] != color:
                                count += 1
                            break
                        count += 1
                        nr += dr; nf += df
            elif ptype == chess.ROOK:
                for dr, df in ((0,1),(0,-1),(1,0),(-1,0)):
                    nr, nf = r + dr, f + df
                    while 0 <= nr <= 7 and 0 <= nf <= 7:
                        asq = chess.square(nf, nr)
                        if asq in piece_at_sq:
                            if piece_at_sq[asq][1] != color:
                                count += 1
                            break
                        count += 1
                        nr += dr; nf += df
            elif ptype == chess.QUEEN:
                for dr, df in ((0,1),(0,-1),(1,0),(-1,0),
                               (1,1),(1,-1),(-1,1),(-1,-1)):
                    nr, nf = r + dr, f + df
                    while 0 <= nr <= 7 and 0 <= nf <= 7:
                        asq = chess.square(nf, nr)
                        if asq in piece_at_sq:
                            if piece_at_sq[asq][1] != color:
                                count += 1
                            break
                        count += 1
                        nr += dr; nf += df
            if color == chess.WHITE:
                w_mobility += count
            else:
                b_mobility += count
        # Normalize: typical total mobility is ~30-50 per side
        mobility_score = math.tanh((w_mobility - b_mobility) * 0.05)

        # ── 4. Piece placement (PST) ──
        # Add king PST (interpolated middlegame/endgame)
        total_mat_for_pst = w_mat + b_mat
        if w_king_sq is not None:
            w_pst += _king_pst_score(w_king_sq, chess.WHITE, total_mat_for_pst)
        if b_king_sq is not None:
            b_pst += _king_pst_score(b_king_sq, chess.BLACK, total_mat_for_pst)
        # Normalize: max realistic difference ~200-300 centipawns
        placement_score = math.tanh((w_pst - b_pst) / 150.0)

        # ── 5. King safety (pawn shield) ──
        w_shield = 0.0; b_shield = 0.0
        for ksq, kcolor in [(w_king_sq, chess.WHITE), (b_king_sq, chess.BLACK)]:
            if ksq is None:
                continue
            kr, kf = chess.square_rank(ksq), chess.square_file(ksq)
            count = 0.0
            for dr in range(-1, 2):
                for df in range(-1, 2):
                    if dr == 0 and df == 0:
                        continue
                    nr, nf = kr + dr, kf + df
                    if 0 <= nr <= 7 and 0 <= nf <= 7:
                        asq = chess.square(nf, nr)
                        if asq in piece_at_sq:
                            at, ac, av = piece_at_sq[asq]
                            if ac == kcolor and at == chess.PAWN:
                                count += 1.0
            if kcolor == chess.WHITE:
                w_shield = count
            else:
                b_shield = count
        safety_score = (w_shield - b_shield) / 8.0

        # ── 6. Repetition penalty ──
        # Without this the AI shuffles pieces back and forth forever
        # because repeated positions score identically.  Penalise the
        # side to move so the search prefers novel positions.
        rep_penalty = 0.0
        if self.position_history:
            fen_key = self.board.fen().split()[0]
            rep_count = 0
            for h in self.position_history:
                if h == fen_key:
                    rep_count += 1
            # Current position is already in history, so count - 1
            # gives the number of PREVIOUS occurrences.
            rep_count = max(0, rep_count - 1)
            if rep_count >= 4:
                rep_penalty = -0.80  # Slam the brakes on 5-fold+
            elif rep_count >= 3:
                rep_penalty = -0.65  # Very strongly discourage 4-fold
            elif rep_count >= 2:
                rep_penalty = -0.50  # Strongly discourage 3-fold
            elif rep_count >= 1:
                rep_penalty = -0.25  # Discourage 2-fold
            # When one side is winning, repeating is even worse —
            # it wastes turns toward the fifty-move draw.  Even a
            # single-pawn advantage (mat_adv=1) should trigger
            # scaling, since K+P vs K is winning in Mercenary.
            mat_adv_rep = abs(w_mat - b_mat)
            stm_winning = ((w_mat > b_mat and self.board.turn)
                           or (b_mat > w_mat and not self.board.turn))
            if stm_winning and mat_adv_rep >= 1.0 and rep_penalty < 0:
                rep_penalty *= min(2.5, 1.0 + mat_adv_rep / 5.0)
            # Penalty is from the side-to-move’s perspective.
            # Convert to White’s perspective for the combined score.
            if not self.board.turn:  # Black to move
                rep_penalty = -rep_penalty

        # ── 7. Endgame king chase ──
        # When one side is ahead in material and pieces are few,
        # drive the losing king toward the corner (where checkmate
        # is easier) and bring our king closer to the enemy king.
        # In equal endgames, centralise both kings (central king
        # controls more squares and supports pawn advances).
        chase_score = 0.0
        total_mat = w_mat + b_mat
        if total_mat <= 20.0 and w_king_sq is not None and b_king_sq is not None:
            mat_diff = w_mat - b_mat
            if abs(mat_diff) >= 1.0:  # Any material advantage
                # Determine which side is ahead
                if mat_diff > 0:
                    winner_king = w_king_sq
                    loser_king = b_king_sq
                    sign = 1.0
                else:
                    winner_king = b_king_sq
                    loser_king = w_king_sq
                    sign = -1.0
                # Push loser king to corner: distance from center
                lr = chess.square_rank(loser_king)
                lf = chess.square_file(loser_king)
                corner_dist = max(abs(lr - 3.5), abs(lf - 3.5))  # 0.5 to 3.5
                corner_bonus = corner_dist / 3.5  # 0 to 1 (1 = in corner)
                # Bring winner king closer to loser king
                wr = chess.square_rank(winner_king)
                wf = chess.square_file(winner_king)
                king_dist = abs(wr - lr) + abs(wf - lf)  # 1 to 14
                proximity_bonus = (14 - king_dist) / 14.0  # 0 to 1
                # Scale by advantage magnitude — stronger for bare-king
                # endgames where conversion is the sole objective.
                loser_c_chase = chess.BLACK if mat_diff > 0 else chess.WHITE
                bare_king = not any(
                    c == loser_c_chase and pt != chess.KING
                    for _, pt, c, _, _, _ in pieces)
                if bare_king and total_mat <= 10.0:
                    advantage = min(abs(mat_diff) / 3.0, 1.0)
                else:
                    advantage = min(abs(mat_diff) / 9.0, 1.0)
                chase_score = sign * advantage * (
                    0.15 * corner_bonus + 0.15 * proximity_bonus)
            else:
                # Equal-ish endgame: reward king centralisation for both
                # sides.  A centralised king is always useful — it can
                # support pawn advances and cut off the opponent's king.
                if w_king_sq is not None:
                    wr = chess.square_rank(w_king_sq)
                    wf = chess.square_file(w_king_sq)
                    w_central = max(0.0, (3.5 - max(abs(wr - 3.5), abs(wf - 3.5))) / 3.5)
                else:
                    w_central = 0.0
                if b_king_sq is not None:
                    br = chess.square_rank(b_king_sq)
                    bf = chess.square_file(b_king_sq)
                    b_central = max(0.0, (3.5 - max(abs(br - 3.5), abs(bf - 3.5))) / 3.5)
                else:
                    b_central = 0.0
                chase_score = 0.08 * (w_central - b_central)

            # King-pawn proximity: in endgames the king should escort
            # its own pawns.  This prevents the enemy king from just
            # walking up and eating unprotected pawns.
            if total_mat <= 15.0:
                w_kp = 0.0; b_kp = 0.0
                for sq, pt, color, val, r, f in pieces:
                    if pt != chess.PAWN:
                        continue
                    if color == chess.WHITE and w_king_sq is not None:
                        kd = (abs(chess.square_rank(w_king_sq) - r)
                              + abs(chess.square_file(w_king_sq) - f))
                        w_kp += max(0.0, (7 - kd)) / 7.0
                    elif color == chess.BLACK and b_king_sq is not None:
                        kd = (abs(chess.square_rank(b_king_sq) - r)
                              + abs(chess.square_file(b_king_sq) - f))
                        b_kp += max(0.0, (7 - kd)) / 7.0
                chase_score += 0.08 * (w_kp - b_kp)

            # ── Pawn-to-enemy-king proximity (Mercenary mating aid) ──
            # In Mercenary, pawns attack all 8 adjacent squares —
            # a pawn adjacent to the enemy king delivers check.
            # K+P can checkmate (pawn checks, king covers escapes).
            # Reward advancing our pawn toward the enemy king when
            # we have material advantage (guides the mating pattern).
            if total_mat <= 10.0 and abs(w_mat - b_mat) >= 1.0:
                pawn_ek = 0.0
                enemy_k = b_king_sq if w_mat > b_mat else w_king_sq
                pawn_side = chess.WHITE if w_mat > b_mat else chess.BLACK
                my_king = w_king_sq if pawn_side == chess.WHITE else b_king_sq
                if enemy_k is not None:
                    ekr = chess.square_rank(enemy_k)
                    ekf = chess.square_file(enemy_k)
                    for sq, pt, color, val, r, f in pieces:
                        if pt == chess.PAWN and color == pawn_side:
                            pdist = max(abs(r - ekr), abs(f - ekf))
                            if pdist <= 1:
                                # Adjacent to enemy king — checking!
                                # Only reward if defended (king/pawn
                                # nearby) so the enemy can't just eat it.
                                defended = False
                                if my_king is not None:
                                    mkr = chess.square_rank(my_king)
                                    mkf = chess.square_file(my_king)
                                    if max(abs(r - mkr), abs(f - mkf)) <= 1:
                                        defended = True
                                if not defended:
                                    for s2, p2, c2, _, r2, f2 in pieces:
                                        if p2 == chess.PAWN and c2 == pawn_side and s2 != sq:
                                            if max(abs(r - r2), abs(f - f2)) <= 1:
                                                defended = True; break
                                if defended:
                                    pawn_ek += 1.0   # Check + defended!
                                # else: undefended — no bonus (will be captured)
                            elif pdist == 2:
                                pawn_ek += 0.4   # Close — one move away
                            elif pdist <= 4:
                                pawn_ek += 0.15  # Approaching
                    psign = 1.0 if pawn_side == chess.WHITE else -1.0
                    chase_score += psign * 0.12 * pawn_ek

            # ── Rook vs pawn endgame: line up rook against enemy pawns ──
            # In R+K vs K+P, the rook must attack the pawn from the
            # same rank/file (from a distance, not adjacent to the
            # defending king).  Also reward the rook cutting off the
            # enemy king on a rank (restricting king movement).
            if total_mat <= 15.0:
                for sq, pt, color, val, r, f in pieces:
                    if pt != chess.ROOK:
                        continue
                    rook_bonus = 0.0
                    # Check if rook lines up with any enemy pawn
                    for esq, ept, ecol, ev, er, ef in pieces:
                        if ept == chess.PAWN and ecol != color:
                            if f == ef:  # Same file
                                rook_bonus += 0.06
                            if r == er:  # Same rank
                                rook_bonus += 0.03
                    # Rook cutting off enemy king by rank
                    enemy_k = b_king_sq if color == chess.WHITE else w_king_sq
                    if enemy_k is not None:
                        ek_r = chess.square_rank(enemy_k)
                        # Rook between kings = cutting off
                        my_k = w_king_sq if color == chess.WHITE else b_king_sq
                        if my_k is not None:
                            mk_r = chess.square_rank(my_k)
                            if min(mk_r, ek_r) < r < max(mk_r, ek_r):
                                rook_bonus += 0.05  # Rook cuts off enemy king
                    if color == chess.WHITE:
                        chase_score += rook_bonus
                    else:
                        chase_score -= rook_bonus

            # ── King restriction (mating net) ──
            # In winning endgames the key to checkmate is restricting
            # the enemy king's escape squares.  Count how many squares
            # the loser's king can safely move to (not attacked by
            # winner's pieces), and reward positions where that number
            # is small.  This gives MCTS a gradient to push toward
            # mating configurations instead of shuffling.
            #
            # Also reward rooks/queens that share a rank or file with
            # the enemy king from distance > 1 (they control that line,
            # boxing the king in).  In Mercenary, rooks adjacent to the
            # king get captured, so distance > 1 is essential.
            if abs(mat_diff) >= 1.0:
                if mat_diff > 0:
                    loser_k = b_king_sq
                    winner_c = chess.WHITE
                    rsign = 1.0
                else:
                    loser_k = w_king_sq
                    winner_c = chess.BLACK
                    rsign = -1.0
                if loser_k is not None:
                    lk_r = chess.square_rank(loser_k)
                    lk_f = chess.square_file(loser_k)
                    # Collect winner piece positions for attack checks
                    winner_pieces = []
                    for sq, pt, c, v, r, f in pieces:
                        if c == winner_c:
                            winner_pieces.append((sq, pt, r, f))
                    winner_k = w_king_sq if winner_c == chess.WHITE else b_king_sq

                    # Count king escape squares that are NOT attacked
                    # by winner's pieces.
                    safe_escapes = 0
                    total_adj = 0
                    for dr in range(-1, 2):
                        for df in range(-1, 2):
                            if dr == 0 and df == 0:
                                continue
                            nr, nf = lk_r + dr, lk_f + df
                            if not (0 <= nr <= 7 and 0 <= nf <= 7):
                                continue
                            sq = chess.square(nf, nr)
                            # Blocked by own piece (can't move there)
                            if sq in piece_at_sq:
                                _, pc, _ = piece_at_sq[sq]
                                if pc != winner_c:
                                    continue  # Loser's own piece blocks
                            total_adj += 1
                            # Check if attacked by winner king
                            attacked = False
                            if winner_k is not None:
                                wk_r = chess.square_rank(winner_k)
                                wk_f = chess.square_file(winner_k)
                                if max(abs(nr - wk_r), abs(nf - wk_f)) <= 1:
                                    attacked = True
                            # Check winner pieces
                            if not attacked:
                                for _, wpt, wr, wf in winner_pieces:
                                    if wpt == chess.PAWN:
                                        if max(abs(nr - wr), abs(nf - wf)) <= 1:
                                            attacked = True; break
                                    elif wpt == chess.KNIGHT:
                                        ddr = abs(nr - wr)
                                        ddf = abs(nf - wf)
                                        if (ddr == 2 and ddf == 1) or (ddr == 1 and ddf == 2):
                                            attacked = True; break
                                    elif wpt in (chess.ROOK, chess.QUEEN):
                                        ddr = abs(nr - wr)
                                        ddf = abs(nf - wf)
                                        if ddr == 0 or ddf == 0:
                                            # Same rank or file — check clear path
                                            clear = True
                                            if ddr == 0 and ddf > 0:
                                                step = 1 if wf < nf else -1
                                                cf = wf + step
                                                while cf != nf:
                                                    csq = chess.square(cf, nr)
                                                    if csq in piece_at_sq:
                                                        clear = False; break
                                                    cf += step
                                            elif ddf == 0 and ddr > 0:
                                                step = 1 if wr < nr else -1
                                                cr = wr + step
                                                while cr != nr:
                                                    csq = chess.square(nf, cr)
                                                    if csq in piece_at_sq:
                                                        clear = False; break
                                                    cr += step
                                            if clear:
                                                attacked = True; break
                                    if not attacked and wpt in (chess.BISHOP, chess.QUEEN):
                                        ddr = abs(nr - wr)
                                        ddf = abs(nf - wf)
                                        if ddr == ddf and ddr > 0:
                                            clear = True
                                            sr = 1 if wr < nr else -1
                                            sf = 1 if wf < nf else -1
                                            cr, cf = wr + sr, wf + sf
                                            while cr != nr:
                                                csq = chess.square(cf, cr)
                                                if csq in piece_at_sq:
                                                    clear = False; break
                                                cr += sr; cf += sf
                                            if clear:
                                                attacked = True; break
                            if not attacked:
                                safe_escapes += 1

                    # Restriction: fewer safe escapes = closer to mate.
                    # BUT: if safe_escapes is 0 and the loser's king is
                    # NOT in check, this is stalemate (draw) — terrible
                    # for the winning side!  Penalise instead of reward.
                    loser_color = chess.BLACK if winner_c == chess.WHITE else chess.WHITE
                    loser_has_pieces = any(
                        c == loser_color and pt != chess.KING
                        for _, pt, c, _, _, _ in pieces)
                    loser_in_check = self._is_king_attacked(loser_color)
                    if safe_escapes == 0 and not loser_in_check and not loser_has_pieces:
                        # Stalemate! The winning side trapped the king
                        # without checkmating — this is a draw.
                        chase_score += rsign * (-0.80)
                    elif safe_escapes <= 1 and not loser_in_check and not loser_has_pieces:
                        # One move from stalemate — proceed with extreme
                        # caution.  Don't reward restriction here.
                        chase_score += rsign * (-0.30)
                    else:
                        max_esc = max(total_adj, 1)
                        restriction = 1.0 - safe_escapes / max_esc
                        if not loser_has_pieces and total_mat <= 10.0:
                            adv_scale = min(abs(mat_diff) / 3.0, 1.0)
                        else:
                            adv_scale = min(abs(mat_diff) / 9.0, 1.0)
                        chase_score += rsign * adv_scale * 0.30 * restriction

        # ── 8. Pawn positioning + connectivity ──
        # In Mercenary there is NO pawn promotion, so pawns can never
        # become queens.  Pawn value comes from:
        #   - Centrality (more squares to move/attack)
        #   - Territorial pressure (on enemy half)
        #   - Connectivity (adjacent pawns protect each other)
        # "Passed pawns" still matter slightly — an unopposed pawn
        # has freedom to maneuver — but NOT because it can promote.
        pawn_advance_score = 0.0
        n_pawns = max(1, sum(1 for _, pt, _, _, _, _ in pieces if pt == chess.PAWN))
        if n_pawns > 0:
            pawn_advance_score = (w_pawn_advance - b_pawn_advance) / max(n_pawns, 4)
        # Passed pawn bonus (flat — no rank scaling since no promotion)
        # A pawn with no enemy pawn on adjacent files ahead of it
        # has more freedom to maneuver.  Small flat bonus.
        passed_pawn_score = 0.0
        w_pawn_files = set(); b_pawn_files = set()
        w_pawn_ranks = {}; b_pawn_ranks = {}
        for sq, pt, color, val, r, f in pieces:
            if pt == chess.PAWN:
                if color == chess.WHITE:
                    w_pawn_files.add(f)
                    w_pawn_ranks.setdefault(f, []).append(r)
                else:
                    b_pawn_files.add(f)
                    b_pawn_ranks.setdefault(f, []).append(r)
        # White passed pawns: no black pawn on same or adjacent files
        # at same rank or higher
        for f, ranks in w_pawn_ranks.items():
            for r in ranks:
                is_passed = True
                for adj_f in range(max(0, f - 1), min(8, f + 2)):
                    if adj_f in b_pawn_ranks:
                        for br in b_pawn_ranks[adj_f]:
                            if br >= r:
                                is_passed = False
                                break
                    if not is_passed:
                        break
                if is_passed:
                    passed_pawn_score += 0.15  # Flat: free to maneuver
        # Black passed pawns
        for f, ranks in b_pawn_ranks.items():
            for r in ranks:
                is_passed = True
                for adj_f in range(max(0, f - 1), min(8, f + 2)):
                    if adj_f in w_pawn_ranks:
                        for wr in w_pawn_ranks[adj_f]:
                            if wr <= r:
                                is_passed = False
                                break
                    if not is_passed:
                        break
                if is_passed:
                    passed_pawn_score -= 0.15

        # Pawn connectivity (Mercenary-specific)
        # Pawns attack all 8 adjacent squares (like kings), so
        # adjacent friendly pawns protect each other.  Connected
        # pawn clusters are very hard to break through.
        w_connected = 0; b_connected = 0
        for sq, pt, color, val, r, f in pieces:
            if pt != chess.PAWN:
                continue
            for dr in range(-1, 2):
                for df in range(-1, 2):
                    if dr == 0 and df == 0:
                        continue
                    nr, nf = r + dr, f + df
                    if 0 <= nr <= 7 and 0 <= nf <= 7:
                        nsq = chess.square(nf, nr)
                        np_ = self.board.piece_at(nsq)
                        if (np_ and np_.piece_type == chess.PAWN
                                and np_.color == color):
                            if color == chess.WHITE:
                                w_connected += 1
                            else:
                                b_connected += 1
                            break  # One neighbor enough per pawn
                else:
                    continue
                break
        pawn_connectivity = 0.02 * (w_connected - b_connected)

        # ── 9. Territorial control ──
        # Pieces on the opponent's half of the board exert pressure.
        # This differentiates quiet moves that all score similarly
        # on material/threats/mobility — a knight on rank 6 is better
        # than one on rank 2 even if both have the same mobility.
        w_territory = 0.0; b_territory = 0.0
        for sq, pt, color, val, r, f in pieces:
            if color == chess.WHITE and r >= 4:  # White piece on Black's side
                w_territory += (r - 3) * 0.04 * val / 3.0
            elif color == chess.BLACK and r <= 3:  # Black piece on White's side
                b_territory += (4 - r) * 0.04 * val / 3.0
        territory_score = (w_territory - b_territory)

        # ── 10. Fifty-move draw pressure (asymmetric) ──
        # The WINNING side should feel urgent pressure to make
        # progress (captures, pawn moves) as the counter grows.
        # The LOSING side is happy with a draw, so less pressure.
        # This prevents the winning side from shuffling to a draw.
        draw_pressure = 0.0
        draw_limit = self.mode.get_draw_conditions()['fifty_move_limit']
        if self.fifty_move_counter > 3:
            # Scale 0→1 over 3..draw_limit (e.g. 3..100)
            progress = min(1.0, (self.fifty_move_counter - 3)
                           / max(1, draw_limit - 3))
            base_pressure = -0.60 * progress
            # Determine who's ahead
            mat_diff = w_mat - b_mat
            stm_ahead = (mat_diff > 0.5 and self.board.turn) or (
                         mat_diff < -0.5 and not self.board.turn)
            if stm_ahead:
                # Winning side: EXTRA pressure to break the shuffle
                draw_pressure = base_pressure * 2.0
            else:
                draw_pressure = base_pressure
            if not self.board.turn:
                draw_pressure = -draw_pressure

        # ── Weighted combination ──
        # Material is the dominant signal (0.40) — being up a piece
        # matters more than anything.  PST placement (0.12) gives
        # quiet-position differentiation.  Decisive bonus pushes
        # winning positions firmly toward ±1.0.
        raw = (0.40 * mat_score
             + 0.14 * threat_score
             + 0.12 * mobility_score
             + 0.12 * placement_score
             + 0.03 * safety_score
             + 0.05 * pawn_advance_score
             + 0.05 * passed_pawn_score
             + 0.03 * territory_score
             + rep_penalty
             + chase_score
             + draw_pressure
             + decisive_bonus
             + pawn_connectivity)
        return _soft_clamp(raw)



    def heuristic_eval_fast(self) -> float:
        """Lightweight eval for quiescence search nodes.

        Only computes material + PST + decisive bonus.  Skips the
        expensive mobility calculation, hanging-piece detection,
        repetition penalty, king safety, passed pawns, etc.

        Quiescence search resolves capture chains — it only needs
        to know "is this position materially good?" not "is this
        position positionally good?".  The full heuristic_eval()
        is still used at the top-level MCTS leaf before quiescence.

        This is ~5-10x faster than heuristic_eval() because it
        avoids generating pseudo-legal moves for mobility.
        """
        PIECE_VAL = {
            chess.PAWN: 1.0, chess.KNIGHT: 3.0, chess.BISHOP: 3.0,
            chess.ROOK: 5.0, chess.QUEEN: 9.0,
        }
        w_mat = 0.0; b_mat = 0.0
        w_pst = 0.0; b_pst = 0.0

        for sq in chess.SQUARES:
            p = self.board.piece_at(sq)
            if not p:
                continue
            if p.piece_type == chess.KING:
                continue
            val = PIECE_VAL.get(p.piece_type, 0.0)
            if p.color == chess.WHITE:
                w_mat += val
                w_pst += _pst_score(p.piece_type, sq, chess.WHITE)
            else:
                b_mat += val
                b_pst += _pst_score(p.piece_type, sq, chess.BLACK)

        # Material (tanh-scaled)
        mat_score = math.tanh((w_mat - b_mat) * 0.3)

        # PST placement
        placement_score = math.tanh((w_pst - b_pst) / 150.0)

        # Decisive advantage
        mat_diff_raw = w_mat - b_mat
        decisive_bonus = 0.0
        if abs(mat_diff_raw) >= 5.0:
            decisive_bonus = min(0.15, 0.08 + (abs(mat_diff_raw) - 5.0) * 0.02)
            if mat_diff_raw < 0:
                decisive_bonus = -decisive_bonus

        raw = 0.55 * mat_score + 0.15 * placement_score + decisive_bonus
        return _soft_clamp(raw)


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  Main Training / Test Loop
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

def train_mercenary(test_mode=False, move_delay=0.05):
    """Train Mercenary AI or run test games.

    Args:
        test_mode: If True, play random games without training (for testing rules)
        move_delay: Delay in seconds between moves (0.01-10, default 0.05)
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
        GAMES_PER_ITERATION = 25
        MCTS_SIMULATIONS = 300
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

                    # ── Heuristic-guided move selection ──
                    # Instead of random moves, evaluate each candidate
                    # with a one-ply heuristic search.  This makes test
                    # games show real strategy: captures, piece activity,
                    # and avoidance of blunders.
                    is_white = game.board.turn
                    best_score = -999.0
                    best_moves = []
                    for candidate in legal_moves:
                        child = game.copy()
                        child.make_move(candidate)
                        h = child.heuristic_eval()  # White's perspective
                        score = h if is_white else -h
                        if score > best_score + 0.01:
                            best_score = score
                            best_moves = [candidate]
                        elif abs(score - best_score) <= 0.01:
                            best_moves.append(candidate)
                    move = random.choice(best_moves) if best_moves else random.choice(legal_moves)
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
        # Note: actual sims will be adaptive (see below), but log the max
        log.self_play_header(GAMES_PER_ITERATION, MCTS_SIMULATIONS, temperature)

        # Heuristic weight: start very high (trust handcrafted eval when NN
        # is random), decay linearly to zero as the network improves.
        # Iteration 1 → 0.95,  50 → 0.71,  100 → 0.48,  200 → 0.0
        # At 0.95, only 5% of the value comes from the random NN,
        # giving MCTS a clean signal for material-based decisions.
        heuristic_weight = max(0.0, 0.95 - 0.95 * ((iteration - 1) / max(1, NUM_ITERATIONS - 1)))

        # Scale MCTS sims by heuristic_weight.  When heuristic
        # dominates (early iterations), fewer sims suffice because
        # the heuristic already provides a strong signal.  As the NN
        # improves and heuristic_weight drops, we ramp up sims.
        #   hw=0.95 (iter 1)  → 150 sims  (min floor)
        #   hw=0.50 (iter 100) → 175 sims
        #   hw=0.00 (iter 200) → 300 sims (full strength)
        adaptive_sims = max(150, int(MCTS_SIMULATIONS * (1.0 - 0.83 * heuristic_weight)))
        self_play = ImprovedSelfPlay(
            model, device=DEVICE, num_simulations=adaptive_sims,
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
    parser.add_argument('--delay', type=float, default=0.05,
                        help='Move delay 0.01-10s (default 0.05)')
    args = parser.parse_args()
    train_mercenary(test_mode=args.test,
                    move_delay=max(0.01, min(10.0, args.delay)))
