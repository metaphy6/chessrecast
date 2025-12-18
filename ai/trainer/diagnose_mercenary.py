"""
Quick diagnostic script to play ONE Mercenary game with full logging.
This helps debug why games end in draws.
"""
import torch
import sys
from pathlib import Path

# Add trainer directory to path
sys.path.insert(0, str(Path(__file__).parent))

from neural_network_gpu import ChessNetPOC
from mercenary_rules import MercenaryBoard
import chess
import numpy as np

def play_diagnostic_game():
    """Play one game with detailed move-by-move logging"""
    
    print("\n" + "="*70)
    print("🔍 DIAGNOSTIC MERCENARY GAME - DETAILED LOGGING")
    print("="*70)
    
    # Simple random network (untrained)
    model = ChessNetPOC(num_channels=128, num_res_blocks=10)
    model.eval()
    
    game = MercenaryBoard()
    game.reset()
    move_count = 0
    max_moves = 150  # Increased to see more play
    
    print(f"\n📋 Initial position:")
    print(game.board)
    print(f"FEN: {game.board.fen()}")
    
    print("\n🎯 MERCENARY RULES:")
    print("  - Pawns move like Kings (1 square any direction)")
    print("  - No en passant, no 2-square initial move")
    print("  - K+pieces vs K: 50 half-moves (25+25) to mate")
    print("  - Normal: 100 half-moves (50+50) draw")
    
    while not game.is_game_over() and move_count < max_moves:
        legal_moves = game.get_legal_moves()
        if not legal_moves:
            print("\n❌ No legal moves!")
            break
        
        # Make random move for diagnostic
        move = np.random.choice(legal_moves)
        
        # Log before move
        captured_piece = game.board.piece_at(move.to_square)
        moving_piece = game.board.piece_at(move.from_square)
        is_pawn_move = moving_piece and moving_piece.piece_type == chess.PAWN
        
        print(f"\n{'='*70}")
        print(f"Move {move_count + 1}: {move.uci()} ({game.board.san(move)})")
        print(f"  Turn: {'White' if game.board.turn else 'Black'}")
        print(f"  Legal moves available: {len(legal_moves)}")
        print(f"  Fifty-move counter: {game.fifty_move_counter}")
        
        if is_pawn_move:
            print(f"  ♟️ PAWN MOVE (Mercenary: king-like movement)")
        
        if captured_piece:
            print(f"  ⚔️ CAPTURE: {captured_piece.symbol()} at {chess.square_name(move.to_square)}")
        
        # Make the move
        success = game.make_move(move)
        
        if not success:
            print(f"  ❌ ILLEGAL MOVE!")
            break
        
        move_count += 1
        
        # Check game state
        if game.board.is_check():
            print(f"  ⚠️ CHECK!")
        if game.board.is_checkmate():
            print(f"  🏁 CHECKMATE!")
        if game.board.is_stalemate():
            print(f"  🏁 STALEMATE!")
        if game._is_insufficient_material():
            print(f"  🏁 INSUFFICIENT MATERIAL!")
        if game._is_threefold_repetition():
            print(f"  🏁 THREEFOLD REPETITION!")
        
        # Show FEN every 20 moves
        if move_count % 20 == 0:
            print(f"\n📋 Position after {move_count} moves:")
            print(game.board)
            print(f"FEN: {game.board.fen()}")
    
    print(f"\n{'='*70}")
    print(f"🏁 GAME ENDED")
    print(f"{'='*70}")
    print(f"Result: {game.get_result()}")
    print(f"Total moves: {move_count}")
    print(f"Fifty-move counter: {game.fifty_move_counter}")
    
    print(f"\nFinal position:")
    print(game.board)
    print(f"FEN: {game.board.fen()}")
    
    # Count pieces
    white_pieces = sum(1 for sq in chess.SQUARES if game.board.piece_at(sq) and 
                      game.board.piece_at(sq).color == chess.WHITE)
    black_pieces = sum(1 for sq in chess.SQUARES if game.board.piece_at(sq) and 
                      game.board.piece_at(sq).color == chess.BLACK)
    print(f"\nPieces remaining: White={white_pieces}, Black={black_pieces}")
    
    # Explain why it ended
    print(f"\n🔍 Why did the game end?")
    if game.board.is_checkmate():
        print("  ✓ Checkmate")
    elif game.board.is_stalemate():
        print("  ✓ Stalemate (no legal moves but not in check)")
    elif game._is_insufficient_material():
        print("  ✓ Insufficient material (Mercenary rules)")
    elif game._is_threefold_repetition():
        print("  ✓ Threefold repetition")
    elif game._is_fifty_move_draw():
        print(f"  ✓ Fifty-move rule ({game.fifty_move_counter} half-moves)")
        if white_pieces == 1 or black_pieces == 1:
            print("    (K+pieces vs K endgame: 50 half-move limit)")
        else:
            print("    (Normal position: 100 half-move limit)")
    elif move_count >= max_moves:
        print(f"  ✓ Max moves limit reached ({max_moves})")
    else:
        print("  ? Unknown reason")

if __name__ == '__main__':
    play_diagnostic_game()
