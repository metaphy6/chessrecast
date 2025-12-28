"""
Base Game Mode Implementation
==============================
Provides common chess logic with mode-specific rule overrides.
Similar to Flutter's GameMode architecture.
"""
import chess
from typing import List, Optional
from abc import ABC, abstractmethod


class GameMode(ABC):
    """Base class for all game mode implementations"""
    
    @abstractmethod
    def get_mode_name(self) -> str:
        """Return the name of this game mode"""
        pass
    
    def get_pawn_moves(self, board: chess.Board, from_square: int) -> Optional[List[chess.Move]]:
        """
        Get pawn moves for this game mode.
        Returns None if the mode uses default pawn behavior.
        
        Args:
            board: Current board state
            from_square: Square where the pawn is located
            
        Returns:
            List of legal pawn moves, or None to use default behavior
        """
        return None
    
    def filter_moves(self, board: chess.Board, moves: List[chess.Move]) -> List[chess.Move]:
        """
        Filter moves based on game mode rules.
        Returns the same list if no filtering is needed.
        
        Args:
            board: Current board state
            moves: List of potential moves
            
        Returns:
            Filtered list of moves
        """
        return moves
    
    def should_reset_fifty_move_counter(self, board: chess.Board, move: chess.Move) -> bool:
        """
        Check if a move should reset the fifty-move counter.
        Default: captures and pawn moves reset the counter.
        
        Args:
            board: Current board state
            move: The move being made
            
        Returns:
            True if counter should be reset
        """
        captured_piece = board.piece_at(move.to_square)
        moving_piece = board.piece_at(move.from_square)
        
        # Reset on capture or pawn move
        return captured_piece is not None or (moving_piece and moving_piece.piece_type == chess.PAWN)
    
    def get_draw_conditions(self) -> dict:
        """
        Get special draw conditions for this mode.
        
        Returns:
            Dictionary with draw condition parameters
        """
        return {
            'fifty_move_limit': 100,  # Standard 100 half-moves (50 full moves)
            'insufficient_material_rules': 'standard'
        }
    
    def is_game_over_custom(self, board: chess.Board, legal_moves: List[chess.Move]) -> Optional[bool]:
        """
        Check for custom game-over conditions specific to this mode.
        Returns None to use default game-over logic.
        
        Args:
            board: Current board state
            legal_moves: List of legal moves available
            
        Returns:
            True if game is over, False if continuing, None for default logic
        """
        return None


class ChessBoardWithMode:
    """Chess board with game mode support"""
    
    def __init__(self, mode: GameMode):
        self.board = chess.Board()
        self.mode = mode
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
        """Get all legal moves including mode-specific moves"""
        legal_moves = []
        
        # For each piece of the current player, generate candidate moves
        for square in chess.SQUARES:
            piece = self.board.piece_at(square)
            if piece and piece.color == self.board.turn:
                if piece.piece_type == chess.PAWN:
                    # Check if mode has custom pawn moves
                    custom_pawn_moves = self.mode.get_pawn_moves(self.board, square)
                    if custom_pawn_moves is not None:
                        # Custom pawn moves already filter out king captures and check
                        legal_moves.extend(custom_pawn_moves)
                    else:
                        # Use standard pawn moves from python-chess
                        for move in self.board.legal_moves:
                            if move.from_square == square:
                                # Filter out king captures
                                target = self.board.piece_at(move.to_square)
                                if target and target.piece_type == chess.KING:
                                    continue
                                legal_moves.append(move)
                else:
                    # For non-pawn pieces, generate pseudo-legal moves and validate them
                    # We can't use board.legal_moves because it doesn't know about custom pawn attacks
                    pseudo_legal = self._get_pseudo_legal_moves_for_piece(square, piece)
                    for move in pseudo_legal:
                        # Filter out king captures
                        target = self.board.piece_at(move.to_square)
                        if target and target.piece_type == chess.KING:
                            continue
                        
                        # Check if move leaves own king in check (considering Mercenary pawn attacks)
                        if self._is_legal_considering_custom_attacks(move):
                            legal_moves.append(move)
        
        # Apply mode-specific filtering
        legal_moves = self.mode.filter_moves(self.board, legal_moves)
        
        return legal_moves
    
    def _get_pseudo_legal_moves_for_piece(self, from_square: int, piece: chess.Piece) -> List[chess.Move]:
        """Get pseudo-legal moves for a non-pawn piece (doesn't check for check)"""
        moves = []
        
        # Get the piece's movement pattern
        if piece.piece_type == chess.KNIGHT:
            offsets = [(-2, -1), (-2, 1), (-1, -2), (-1, 2), (1, -2), (1, 2), (2, -1), (2, 1)]
            for rank_offset, file_offset in offsets:
                to_square = self._offset_square(from_square, rank_offset, file_offset)
                if to_square is not None:
                    target = self.board.piece_at(to_square)
                    if target is None or target.color != piece.color:
                        moves.append(chess.Move(from_square, to_square))
        
        elif piece.piece_type == chess.KING:
            offsets = [(-1, -1), (-1, 0), (-1, 1), (0, -1), (0, 1), (1, -1), (1, 0), (1, 1)]
            for rank_offset, file_offset in offsets:
                to_square = self._offset_square(from_square, rank_offset, file_offset)
                if to_square is not None:
                    target = self.board.piece_at(to_square)
                    if target is None or target.color != piece.color:
                        moves.append(chess.Move(from_square, to_square))
            # TODO: Add castling support if needed
        
        elif piece.piece_type in [chess.BISHOP, chess.ROOK, chess.QUEEN]:
            # Sliding pieces
            directions = []
            if piece.piece_type in [chess.ROOK, chess.QUEEN]:
                directions.extend([(0, 1), (0, -1), (1, 0), (-1, 0)])  # Rook directions
            if piece.piece_type in [chess.BISHOP, chess.QUEEN]:
                directions.extend([(1, 1), (1, -1), (-1, 1), (-1, -1)])  # Bishop directions
            
            for rank_offset, file_offset in directions:
                for distance in range(1, 8):
                    to_square = self._offset_square(from_square, rank_offset * distance, file_offset * distance)
                    if to_square is None:
                        break
                    target = self.board.piece_at(to_square)
                    if target is None:
                        moves.append(chess.Move(from_square, to_square))
                    else:
                        if target.color != piece.color:
                            moves.append(chess.Move(from_square, to_square))
                        break
        
        return moves
    
    def _offset_square(self, square: int, rank_offset: int, file_offset: int) -> Optional[int]:
        """Apply an offset to a square and return the new square, or None if out of bounds"""
        rank = chess.square_rank(square)
        file = chess.square_file(square)
        
        new_rank = rank + rank_offset
        new_file = file + file_offset
        
        if 0 <= new_rank <= 7 and 0 <= new_file <= 7:
            return chess.square(new_file, new_rank)
        return None
    
    def _is_legal_considering_custom_attacks(self, move: chess.Move) -> bool:
        """Check if move is legal considering custom pawn attacks (e.g., Mercenary mode)"""
        moving_color = self.board.turn
        
        # Make the move
        self.board.push(move)
        
        # Find our king
        king_square = self.board.king(moving_color)
        if king_square is None:
            self.board.pop()
            return False
        
        # Check if king is under attack from any opponent piece
        for square in chess.SQUARES:
            piece = self.board.piece_at(square)
            if piece and piece.color != moving_color:
                if piece.piece_type == chess.PAWN:
                    # Check if pawn can attack the king using custom rules
                    # For Mercenary mode, check if pawn could reach king square in one move
                    if self._can_pawn_attack_square(square, king_square, piece.color):
                        self.board.pop()
                        return False
                else:
                    # For non-pawns, check using pseudo-legal moves
                    attacker_moves = self._get_pseudo_legal_moves_for_piece(square, piece)
                    for attacker_move in attacker_moves:
                        if attacker_move.to_square == king_square:
                            self.board.pop()
                            return False
        
        self.board.pop()
        return True
    
    def _can_pawn_attack_square(self, pawn_square: int, target_square: int, pawn_color: chess.Color) -> bool:
        """Check if a pawn at pawn_square can attack target_square (for custom pawn moves)"""
        # Ask the mode if it has custom pawn attack logic
        # For Mercenary mode, this checks if pawn can reach target in one king-like move
        pawn_rank = chess.square_rank(pawn_square)
        pawn_file = chess.square_file(pawn_square)
        target_rank = chess.square_rank(target_square)
        target_file = chess.square_file(target_square)
        
        # Check if target is within one square (king-like movement for Mercenary)
        rank_diff = abs(target_rank - pawn_rank)
        file_diff = abs(target_file - pawn_file)
        
        # For Mercenary mode, pawn attacks like a king (any adjacent square)
        if rank_diff <= 1 and file_diff <= 1 and (rank_diff > 0 or file_diff > 0):
            return True
        
        return False
    
    def _is_legal_after_move(self, move: chess.Move) -> bool:
        """Check if move doesn't leave own king in check"""
        # Make move
        self.board.push(move)
        
        # After push, turn has switched - check if previous player's king is in check
        # (which means the move was illegal because it left our king in check)
        was_legal = not self.board.is_check()
        
        # Undo move
        self.board.pop()
        
        return was_legal
    
    def make_move(self, move: chess.Move) -> bool:
        """Make a move with mode-specific rules"""
        legal_moves = self.get_legal_moves()
        
        if move not in legal_moves:
            print(f"⚠️ Move {move.uci()} not in legal moves!")
            return False
        
        # Check if move resets fifty-move counter using mode logic
        if self.mode.should_reset_fifty_move_counter(self.board, move):
            self.fifty_move_counter = 0
        else:
            self.fifty_move_counter += 1
        
        # Make the move
        self.board.push(move)
        
        # Track position
        self._add_position_to_history()
        
        return True
    
    def is_game_over(self) -> bool:
        """Check if game ended with mode-specific rules"""
        # CRITICAL: Check if either king is missing (should never happen)
        white_king = self.board.king(chess.WHITE)
        black_king = self.board.king(chess.BLACK)
        
        if white_king is None:
            print("🚨 CRITICAL ERROR: White king is missing!")
            return True
        
        if black_king is None:
            print("🚨 CRITICAL ERROR: Black king is missing!")
            return True
        
        # Get legal moves
        legal_moves = self.get_legal_moves()
        
        # Check mode-specific game-over conditions first
        custom_game_over = self.mode.is_game_over_custom(self.board, legal_moves)
        if custom_game_over is not None:
            return custom_game_over
        
        # No legal moves = checkmate or stalemate
        if not legal_moves:
            return True
        
        # Fifty-move rule (mode-specific limit)
        draw_conditions = self.mode.get_draw_conditions()
        if self.fifty_move_counter >= draw_conditions['fifty_move_limit']:
            return True
        
        # Threefold repetition
        if self._is_threefold_repetition():
            return True
        
        # Insufficient material (basic check)
        if self._is_insufficient_material():
            return True
        
        return False
    
    def _is_insufficient_material(self) -> bool:
        """Check for insufficient material to checkmate"""
        pieces = []
        for square in chess.SQUARES:
            piece = self.board.piece_at(square)
            if piece:
                pieces.append(piece.piece_type)
        
        # K vs K
        if len(pieces) == 2:
            return True
        
        # K+N vs K or K+B vs K
        if len(pieces) == 3:
            if chess.KNIGHT in pieces or chess.BISHOP in pieces:
                return True
        
        return False
    
    def get_result(self) -> str:
        """Get game result"""
        if not self.is_game_over():
            return '*'  # Game in progress
        
        legal_moves = self.get_legal_moves()
        
        # No legal moves
        if not legal_moves:
            if self.board.is_check():
                # Checkmate
                winner = 'black' if self.board.turn else 'white'
                return f'{winner}_wins'
            else:
                # Stalemate
                return 'draw_stalemate'
        
        # Fifty-move rule
        draw_conditions = self.mode.get_draw_conditions()
        if self.fifty_move_counter >= draw_conditions['fifty_move_limit']:
            return 'draw_fifty_move'
        
        # Threefold repetition
        if self._is_threefold_repetition():
            return 'draw_repetition'
        
        # Insufficient material
        if self._is_insufficient_material():
            return 'draw_insufficient_material'
        
        return 'draw'
