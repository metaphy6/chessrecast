"""
Simplified chess rules for POC.
Only implements Classic mode with basic validation.
"""
import chess
from typing import List

class ChessGamePOC:
    def __init__(self):
        self.board = chess.Board()
    
    def reset(self):
        """Start new game"""
        self.board.reset()
    
    def get_legal_moves(self) -> List[chess.Move]:
        """Get all legal moves in current position"""
        return list(self.board.legal_moves)
    
    def make_move(self, move: chess.Move) -> bool:
        """Make a move, return True if legal"""
        if move in self.board.legal_moves:
            self.board.push(move)
            return True
        return False
    
    def is_game_over(self) -> bool:
        """Check if game ended"""
        return self.board.is_game_over()
    
    def get_result(self) -> str:
        """Get game result: '1-0', '0-1', '1/2-1/2'"""
        if self.board.is_checkmate():
            return '1-0' if self.board.turn == chess.BLACK else '0-1'
        return '1/2-1/2'
    
    def get_board_tensor(self):
        """
        Convert board to 8x8x12 tensor (12 piece planes).
        Simplified for POC - just piece positions.
        """
        import numpy as np
        
        # 12 planes: 6 piece types × 2 colors
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
    
    def get_fen(self) -> str:
        """Get current position in FEN notation"""
        return self.board.fen()
