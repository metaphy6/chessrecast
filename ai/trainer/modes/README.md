# Game Modes

This directory contains implementations of various chess game modes.

## Architecture

The architecture follows the Flutter app's design:
- **Base class**: `GameMode` (in `../game_mode.py`) provides common chess logic
- **Mode implementations**: Each mode extends `GameMode` and overrides specific behavior
- **Board wrapper**: `ChessBoardWithMode` manages the board state with mode-specific rules

## Adding a New Mode

To add a new game mode:

1. **Create a new file** in this directory (e.g., `snare.py`, `truce.py`)

2. **Import the base class**:
```python
from game_mode import GameMode
import chess
from typing import List, Optional
```

3. **Implement your mode**:
```python
class SnareMode(GameMode):
    def get_mode_name(self) -> str:
        return "snare"
    
    def get_pawn_moves(self, board: chess.Board, from_square: int) -> Optional[List[chess.Move]]:
        """Override if pawns have special rules"""
        return None  # Use default pawn moves
    
    def filter_moves(self, board: chess.Board, moves: List[chess.Move]) -> List[chess.Move]:
        """Override to filter moves based on mode rules"""
        # Example: Filter based on some condition
        return moves
    
    # Override other methods as needed...
```

4. **Add backward compatibility wrapper** (if needed for existing code):
```python
class SnareBoard:
    """Legacy wrapper for SnareMode"""
    def __init__(self):
        from game_mode import ChessBoardWithMode
        self._board_with_mode = ChessBoardWithMode(SnareMode())
    
    @property
    def board(self):
        return self._board_with_mode.board
    
    # Add other methods as needed...
```

5. **Update `__init__.py`**:
```python
from .snare import SnareMode, SnareBoard

__all__ = [
    # ... existing modes
    'SnareMode',
    'SnareBoard',
]
```

## Available Modes

### Mercenary Mode
**File**: `mercenary.py`

Pawns move and capture like Kings (1 square in any direction).
- No en passant
- No two-square initial move
- No pawn promotion
- Special draw rules for K+pieces vs K endgames

## Methods You Can Override

From `GameMode` base class:

- `get_mode_name()` - Return mode name (required)
- `get_pawn_moves()` - Custom pawn movement rules
- `filter_moves()` - Filter legal moves based on mode rules
- `should_reset_fifty_move_counter()` - Custom fifty-move rule logic
- `get_draw_conditions()` - Mode-specific draw conditions
- `is_game_over_custom()` - Custom game-over logic

## Testing Your Mode

After implementing a mode, test it by:

1. Creating a simple test script:
```python
from modes.your_mode import YourMode
from game_mode import ChessBoardWithMode

board = ChessBoardWithMode(YourMode())
# Test moves, game logic, etc.
```

2. Running with the training script
3. Connecting Flutter app to verify validation works correctly
