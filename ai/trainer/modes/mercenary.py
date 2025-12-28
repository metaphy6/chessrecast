"""
Mercenary Chess Mode Implementation
====================================
Pawns move and capture like Kings (1 square in any direction).
No en passant, no two-square initial move, no pawn promotion.

Special draw rules:
- Normal positions: 100 half-moves (50+50) standard rule
- K vs K: Draw
- K+N vs K+N (no pawns): Draw
"""
import chess
from typing import List, Optional
from game_mode import GameMode


class MercenaryMode(GameMode):
    """Mercenary mode: Pawns move like Kings"""
    
    def get_mode_name(self) -> str:
        return "mercenary"
    
    def get_pawn_moves(self, board: chess.Board, from_square: int) -> Optional[List[chess.Move]]:
        """Generate Mercenary pawn moves (one square in any direction like a king)"""
        moves = []
        piece = board.piece_at(from_square)
        if not piece or piece.piece_type != chess.PAWN:
            return moves
        
        rank = chess.square_rank(from_square)
        file = chess.square_file(from_square)
        
        # King-like offsets (8 directions)
        offsets = [
            (-1, -1), (-1, 0), (-1, 1),
            (0, -1),           (0, 1),
            (1, -1),  (1, 0),  (1, 1)
        ]
        
        for rank_offset, file_offset in offsets:
            new_rank = rank + rank_offset
            new_file = file + file_offset
            
            # Check bounds
            if not (0 <= new_rank <= 7 and 0 <= new_file <= 7):
                continue
            
            to_square = chess.square(new_file, new_rank)
            target_piece = board.piece_at(to_square)
            
            # Empty square - can move
            if target_piece is None:
                move = chess.Move(from_square, to_square)
                if self._is_legal_after_move(board, move):
                    moves.append(move)
            
            # Enemy piece - can capture (except king)
            elif target_piece.color != piece.color:
                if target_piece.piece_type != chess.KING:
                    move = chess.Move(from_square, to_square)
                    if self._is_legal_after_move(board, move):
                        moves.append(move)
        
        return moves
    
    def _is_legal_after_move(self, board: chess.Board, move: chess.Move) -> bool:
        """Check if move doesn't leave own king in check"""
        moving_color = board.turn
        
        # Make move
        board.push(move)
        
        # Check if the player who just moved has their king under attack
        king_square = board.king(moving_color)
        if king_square is None:
            # No king found (shouldn't happen in normal chess)
            board.pop()
            return False
        
        # Check if king is attacked by opponent
        king_attacked = board.is_attacked_by(not moving_color, king_square)
        
        # Undo move
        board.pop()
        
        return not king_attacked
    
    def should_reset_fifty_move_counter(self, board: chess.Board, move: chess.Move) -> bool:
        """
        In Mercenary mode, pawn moves count as regular moves (increment counter).
        Only captures reset the counter.
        """
        captured_piece = board.piece_at(move.to_square)
        return captured_piece is not None
    
    def get_draw_conditions(self) -> dict:
        """Mercenary mode uses standard 100 half-move rule"""
        return {
            'fifty_move_limit': 100,
            'insufficient_material_rules': 'mercenary'
        }


# Backward compatibility: Create alias for old MercenaryBoard class
class MercenaryBoard:
    """Legacy wrapper for MercenaryMode - maintains backward compatibility"""
    
    def __init__(self):
        from game_mode import ChessBoardWithMode
        self._board_with_mode = ChessBoardWithMode(MercenaryMode())
    
    @property
    def board(self):
        """Access underlying chess.Board"""
        return self._board_with_mode.board
    
    @property
    def fifty_move_counter(self):
        return self._board_with_mode.fifty_move_counter
    
    @property
    def position_history(self):
        return self._board_with_mode.position_history
    
    def reset(self):
        """Start new game"""
        self._board_with_mode.reset()
    
    def get_legal_moves(self) -> List[chess.Move]:
        """Get all legal moves including Mercenary pawn moves"""
        return self._board_with_mode.get_legal_moves()
    
    def make_move(self, move: chess.Move) -> bool:
        """Make a move with Mercenary rules"""
        return self._board_with_mode.make_move(move)
    
    def is_game_over(self) -> bool:
        """Check if game ended with Mercenary rules"""
        return self._board_with_mode.is_game_over()
    
    def get_result(self) -> str:
        """Get game result"""
        return self._board_with_mode.get_result()
    
    def copy(self):
        """Create a deep copy of the board"""
        import copy as copy_module
        new_board = MercenaryBoard()
        new_board._board_with_mode = copy_module.deepcopy(self._board_with_mode)
        return new_board
    
    def fen(self) -> str:
        """Get FEN representation"""
        return self.board.fen()
    
    def get_board_tensor(self):
        """Convert board to 8x8x12 tensor for neural network"""
        import numpy as np
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
                    plane += 6  # Black pieces in planes 6-11
                
                rank = chess.square_rank(square)
                file = chess.square_file(square)
                tensor[rank, file, plane] = 1.0
        
        return tensor
