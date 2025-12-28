"""
Classic Chess Game Rules
=========================
Basic chess implementation for neural network training.
Used as fallback when no custom game mode is specified.
"""
import chess
import numpy as np
from typing import List


class ChessGamePOC:
    """Standard chess game wrapper for neural network training"""
    
    def __init__(self):
        self.board = chess.Board()
        self.fifty_move_counter = 0
        self.position_history = []
        self._add_position_to_history()
    
    def reset(self):
        """Start new game"""
        self.board.reset()
        self.fifty_move_counter = 0
        self.position_history = []
        self._add_position_to_history()
    
    def _add_position_to_history(self):
        """Track positions for threefold repetition"""
        fen = self.board.fen().split()[0]
        self.position_history.append(fen)
    
    def _is_threefold_repetition(self) -> bool:
        """Check for threefold repetition"""
        if len(self.position_history) < 3:
            return False
        current_pos = self.position_history[-1]
        count = self.position_history.count(current_pos)
        return count >= 3
    
    def get_legal_moves(self) -> List[chess.Move]:
        """Get all legal moves"""
        return list(self.board.legal_moves)
    
    def make_move(self, move: chess.Move) -> bool:
        """Make a move"""
        if move not in self.board.legal_moves:
            return False
        
        # Track fifty-move counter
        captured_piece = self.board.piece_at(move.to_square)
        moving_piece = self.board.piece_at(move.from_square)
        
        if captured_piece or (moving_piece and moving_piece.piece_type == chess.PAWN):
            self.fifty_move_counter = 0
        else:
            self.fifty_move_counter += 1
        
        self.board.push(move)
        self._add_position_to_history()
        return True
    
    def is_game_over(self) -> bool:
        """Check if game ended"""
        if self.board.is_checkmate():
            return True
        if self.board.is_stalemate():
            return True
        if self.board.is_insufficient_material():
            return True
        if self._is_threefold_repetition():
            return True
        if self.fifty_move_counter >= 100:
            return True
        return False
    
    def get_result(self) -> str:
        """Get game result: '1-0', '0-1', '1/2-1/2'"""
        if self.board.is_checkmate():
            return '1-0' if self.board.turn == chess.BLACK else '0-1'
        return '1/2-1/2'
    
    def get_board_tensor(self) -> np.ndarray:
        """Convert board to 8x8x12 tensor for neural network"""
        tensor = np.zeros((8, 8, 12), dtype=np.float32)
        
        piece_to_plane = {
            chess.PAWN: 0, chess.KNIGHT: 1, chess.BISHOP: 2,
            chess.ROOK: 3, chess.QUEEN: 4, chess.KING: 5
        }
        
        for square in chess.SQUARES:
            piece = self.board.piece_at(square)
            if piece:
                plane = piece_to_plane[piece.piece_type]
                if piece.color == chess.BLACK:
                    plane += 6
                
                rank = chess.square_rank(square)
                file = chess.square_file(square)
                tensor[rank, file, plane] = 1.0
        
        return tensor
    
    def copy(self):
        """Create a deep copy of the game"""
        new_game = ChessGamePOC()
        new_game.board = self.board.copy()
        new_game.fifty_move_counter = self.fifty_move_counter
        new_game.position_history = self.position_history.copy()
        return new_game
    
    def fen(self) -> str:
        """Get FEN representation"""
        return self.board.fen()
