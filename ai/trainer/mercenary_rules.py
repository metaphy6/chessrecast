"""
Mercenary Chess Mode Implementation
====================================
Pawns move and capture like Kings (1 square in any direction).
No en passant, no two-square initial move, no pawn promotion.

Special draw rules:
- K+pieces vs K: 50 half-moves (25+25) to mate
- Normal positions: 100 half-moves (50+50) standard rule
- K vs K: Draw
- K+P vs K+P: Draw
- K+N vs K+N (no pawns): Draw
"""
import chess
import numpy as np
from typing import List, Optional


class MercenaryBoard:
    """Chess board with Mercenary mode rules"""
    
    def __init__(self):
        self.board = chess.Board()
        self.fifty_move_counter = 0
        self.position_history = []  # For threefold repetition
        
    def reset(self):
        """Start new game"""
        self.board.reset()
        self.fifty_move_counter = 0
        self.position_history = []
        self._add_position_to_history()
    
    def _add_position_to_history(self):
        """Track positions for threefold repetition"""
        fen = self.board.fen().split()[0]  # Just piece positions
        self.position_history.append(fen)
    
    def _is_threefold_repetition(self) -> bool:
        """Check for threefold repetition"""
        if len(self.position_history) < 3:
            return False
        current_pos = self.position_history[-1]
        count = self.position_history.count(current_pos)
        return count >= 3
    
    def get_legal_moves(self) -> List[chess.Move]:
        """Get all legal moves including Mercenary pawn moves"""
        legal_moves = []
        
        for square in chess.SQUARES:
            piece = self.board.piece_at(square)
            if piece and piece.color == self.board.turn:
                if piece.piece_type == chess.PAWN:
                    # Mercenary pawn moves (king-like)
                    legal_moves.extend(self._get_mercenary_pawn_moves(square))
                else:
                    # Standard piece moves
                    for move in self.board.legal_moves:
                        if move.from_square == square:
                            legal_moves.append(move)
        
        return legal_moves
    
    def _get_mercenary_pawn_moves(self, from_square: int) -> List[chess.Move]:
        """Generate Mercenary pawn moves (one square in any direction like a king)"""
        moves = []
        piece = self.board.piece_at(from_square)
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
            target_piece = self.board.piece_at(to_square)
            
            # Empty square - can move
            if target_piece is None:
                move = chess.Move(from_square, to_square)
                if self._is_legal_after_move(move):
                    moves.append(move)
            
            # Enemy piece - can capture (except king)
            elif target_piece.color != piece.color:
                if target_piece.piece_type != chess.KING:
                    move = chess.Move(from_square, to_square)
                    if self._is_legal_after_move(move):
                        moves.append(move)
        
        return moves
    
    def _is_legal_after_move(self, move: chess.Move) -> bool:
        """Check if move doesn't leave own king in check"""
        # Make move
        self.board.push(move)
        
        # Check if opponent can capture our king
        in_check = self.board.is_check()
        
        # Undo move
        self.board.pop()
        
        return not in_check
    
    def make_move(self, move: chess.Move) -> bool:
        """Make a move with Mercenary rules"""
        legal_moves = self.get_legal_moves()
        
        if move not in legal_moves:
            return False
        
        # Check if move resets fifty-move counter
        captured_piece = self.board.piece_at(move.to_square)
        moving_piece = self.board.piece_at(move.from_square)
        
        # Reset counter on capture or pawn move
        if captured_piece or (moving_piece and moving_piece.piece_type == chess.PAWN):
            self.fifty_move_counter = 0
        else:
            self.fifty_move_counter += 1
        
        # Make the move
        self.board.push(move)
        
        # Track position
        self._add_position_to_history()
        
        return True
    
    def is_game_over(self) -> bool:
        """Check if game ended with Mercenary rules"""
        # Checkmate
        if self.board.is_checkmate():
            return True
        
        # Stalemate
        if self.board.is_stalemate():
            return True
        
        # Insufficient material
        if self._is_insufficient_material():
            return True
        
        # Threefold repetition
        if self._is_threefold_repetition():
            return True
        
        # Fifty-move rule
        if self._is_fifty_move_draw():
            return True
        
        return False
    
    def _is_insufficient_material(self) -> bool:
        """Check Mercenary insufficient material rules"""
        white_pieces = []
        black_pieces = []
        
        for square in chess.SQUARES:
            piece = self.board.piece_at(square)
            if piece:
                if piece.color == chess.WHITE:
                    white_pieces.append(piece.piece_type)
                else:
                    black_pieces.append(piece.piece_type)
        
        # K vs K
        if len(white_pieces) == 1 and len(black_pieces) == 1:
            return True
        
        # Count pawns
        white_pawns = white_pieces.count(chess.PAWN)
        black_pawns = black_pieces.count(chess.PAWN)
        
        # K+P vs K+P (each side has exactly 1 pawn)
        if (len(white_pieces) == 2 and len(black_pieces) == 2 and
            white_pawns == 1 and black_pawns == 1):
            return True
        
        # If there are pawns, they can help checkmate
        if white_pawns > 0 or black_pawns > 0:
            return False
        
        # K+N vs K+N (no pawns)
        white_knights = white_pieces.count(chess.KNIGHT)
        black_knights = black_pieces.count(chess.KNIGHT)
        if (len(white_pieces) == 2 and len(black_pieces) == 2 and
            white_knights == 1 and black_knights == 1):
            return True
        
        return False
    
    def _is_fifty_move_draw(self) -> bool:
        """Check fifty-move rule with Mercenary special endgame rules"""
        # Check for K+pieces vs K endgame (50 half-moves = 25+25)
        white_pieces = sum(1 for sq in chess.SQUARES if self.board.piece_at(sq) and 
                          self.board.piece_at(sq).color == chess.WHITE)
        black_pieces = sum(1 for sq in chess.SQUARES if self.board.piece_at(sq) and 
                          self.board.piece_at(sq).color == chess.BLACK)
        
        # K+pieces vs K or K vs K+pieces: 50 half-move limit (25+25)
        if white_pieces == 1 or black_pieces == 1:
            return self.fifty_move_counter >= 50
        
        # Normal positions: 100 half-move limit (50+50)
        return self.fifty_move_counter >= 100
    
    def get_result(self) -> str:
        """Get game result: '1-0', '0-1', '1/2-1/2'"""
        if self.board.is_checkmate():
            # Side to move is checkmated
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
                    plane += 6  # Black pieces in planes 6-11
                
                rank = chess.square_rank(square)
                file = chess.square_file(square)
                tensor[rank, file, plane] = 1.0
        
        return tensor
    
    def copy(self):
        """Create a deep copy of the board"""
        new_board = MercenaryBoard()
        new_board.board = self.board.copy()
        new_board.fifty_move_counter = self.fifty_move_counter
        new_board.position_history = self.position_history.copy()
        return new_board
    
    def fen(self) -> str:
        """Get FEN representation"""
        return self.board.fen()
