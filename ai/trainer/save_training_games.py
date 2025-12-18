"""
Save training games to JSON format for visualization in Flutter app.
This allows you to watch how the AI is learning and making moves.
"""
import json
import chess
from pathlib import Path
from datetime import datetime

class GameRecorder:
    """Records self-play games for later visualization"""
    
    def __init__(self, output_dir='../data/training_games'):
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(parents=True, exist_ok=True)
        self.current_game = None
        self.game_counter = 0
    
    def start_game(self, iteration: int, game_num: int, mode: str = 'mercenary'):
        """Start recording a new game"""
        self.current_game = {
            'metadata': {
                'iteration': iteration,
                'game_number': game_num,
                'mode': mode,
                'timestamp': datetime.now().isoformat(),
                'starting_fen': chess.Board().fen()
            },
            'moves': [],
            'captured_pawns': [],
            'result': None
        }
    
    def log_move(self, move_num: int, move: chess.Move, board: chess.Board,
                 value: float, top_moves: list, turn: str):
        """Log a single move with AI evaluation"""
        move_data = {
            'number': move_num,
            'move': move.uci(),
            'san': board.san(move),  # Standard algebraic notation
            'from': chess.square_name(move.from_square),
            'to': chess.square_name(move.to_square),
            'turn': turn,
            'fen_before': board.fen(),
            'value': float(value),
            'top_3_moves': [
                {'move': m.uci(), 'probability': float(p)}
                for m, p in top_moves
            ]
        }
        
        # Check for captures
        if board.is_capture(move):
            captured = board.piece_at(move.to_square)
            if captured:
                move_data['captured'] = {
                    'piece': captured.symbol(),
                    'color': 'white' if captured.color else 'black'
                }
        
        self.current_game['moves'].append(move_data)
    
    def log_mercenary_capture(self, square: int, old_color: bool, new_color: bool):
        """Log Mercenary-specific pawn color change"""
        self.current_game['captured_pawns'].append({
            'square': chess.square_name(square),
            'old_color': 'white' if old_color else 'black',
            'new_color': 'white' if new_color else 'black',
            'move_number': len(self.current_game['moves'])
        })
    
    def end_game(self, result: str, total_moves: int):
        """Finish recording and save game"""
        if not self.current_game:
            return
        
        self.current_game['result'] = result
        self.current_game['total_moves'] = total_moves
        self.current_game['metadata']['end_fen'] = self.current_game['moves'][-1]['fen_before'] if self.current_game['moves'] else None
        
        # Save to file
        filename = f"game_{self.current_game['metadata']['iteration']:03d}_{self.current_game['metadata']['game_number']:03d}.json"
        filepath = self.output_dir / filename
        
        with open(filepath, 'w') as f:
            json.dump(self.current_game, f, indent=2)
        
        self.game_counter += 1
        return filepath
    
    def create_games_index(self, iteration: int, games_saved: int):
        """Create an index file for easy access"""
        index_file = self.output_dir / 'index.json'
        
        if index_file.exists():
            with open(index_file, 'r') as f:
                index = json.load(f)
        else:
            index = {'games': []}
        
        # List all game files
        game_files = sorted(self.output_dir.glob('game_*.json'))
        index['games'] = [
            {
                'iteration': int(f.stem.split('_')[1]),
                'game_number': int(f.stem.split('_')[2]),
                'filename': f.name
            }
            for f in game_files
        ]
        index['total_games'] = len(index['games'])
        index['last_updated'] = datetime.now().isoformat()
        
        with open(index_file, 'w') as f:
            json.dump(index, f, indent=2)
        
        print(f"📁 Saved {games_saved} training games to: {self.output_dir}")
        print(f"   Index: {index_file}")
