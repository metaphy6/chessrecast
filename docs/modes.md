# Game Modes Architecture

## Overview
The chess game modes have been refactored into a modular, extensible architecture. Each game mode is now a separate file with its own implementation, making the codebase more maintainable and easier to extend.

## Structure

### Base Class: `GameMode` (game_mode.dart)
Abstract base class that defines the interface for all game modes:
- `getPawnMoves()` - Custom pawn movement rules
- `getPromotionPieces()` - Available promotion pieces
- `filterMoves()` - Filter/modify valid moves based on mode rules
- `updateGameStatus()` - Custom game status logic
- `handleSpecialMove()` - Handle special move behavior (e.g., instant wins)
- `isGameEnd()` - Check for mode-specific end conditions

### Mode Implementations

#### 1. **Classic Mode** (`classic.dart`)
- Standard chess rules
- All methods return `null` to use default behavior

#### 2. **Snare Mode** (`snare.dart`)
- Knights create entangle zones when defending each other
- Entangled pieces have restricted movement
- King entanglement = instant checkmate
- Revengeful knight mechanic
- Knight promotion restrictions

**Key Methods:**
- `getKnights()`, `getEntangleInfo()`, `isPieceEntangled()`
- `isKingEntangled()`, `_getEntangledPieceMoves()`
- `_areKnightsDefending()`, `_getEntangleZone()`

#### 3. **Heir Mode** (`heir.dart`)
- Pawns can promote to King (once per player)
- If King is captured and pawns exist, can promote to new King
- No King + no pawns = game over
- Second King captured = game over

**Key Methods:**
- `_wouldKingPromotionBeInCheck()` - Safety check for King promotion
- `isGameEnd()` - Check if player has lost

#### 4. **Supreme Queen Mode** (`supreme_queen.dart`)
- Capturing opponent's Queen = instant win
- Pawns cannot promote to Queen

**Key Methods:**
- `handleSpecialMove()` - Detect Queen capture

#### 5. **Royal Pawns Mode** (`royal_pawns.dart`)
- Pawns move AND capture like Kings (one square in any direction)
- Two-square initial move still available
- En passant still works

#### 6. **Shifty Pawns Mode** (`shifty_pawns.dart`)
- Pawns move like Kings (one square in any direction)
- Pawns capture like regular pawns (diagonal forward only)
- Two-square initial move still available
- En passant still works

## File Locations

```
lib/game/board/modes/
├── modes.dart              # Export file for all modes
├── game_mode.dart          # Base abstract class
├── classic.dart            # Standard chess
├── snare.dart              # Entangle zones
├── heir.dart               # King promotion
├── supreme_queen.dart      # Queen capture wins
├── royal_pawns.dart        # King-like pawns (move + capture)
└── shifty_pawns.dart       # King-like movement, pawn captures
```

## Integration Points

### board.dart
The `ChessBoard` class should:
1. Instantiate the appropriate `GameMode` based on `gameType`
2. Delegate mode-specific behavior to the mode instance
3. Use mode methods for:
   - Pawn moves
   - Promotion pieces
   - Move filtering
   - Special move handling

### game_service.dart
The `ChessGameService` should:
1. Call `handleSpecialMove()` before making a move
2. Use `updateGameStatus()` for mode-specific status updates
3. Check `isGameEnd()` for non-standard end conditions

## Benefits

✅ **Modularity**: Each mode is self-contained
✅ **Maintainability**: Easy to find and update mode-specific code
✅ **Extensibility**: Adding new modes is straightforward
✅ **Testability**: Each mode can be tested independently
✅ **Readability**: Clear separation of concerns
✅ **Reusability**: Mode logic can be composed/mixed

## Next Steps

To complete the refactoring:
1. Update `board.dart` to instantiate and use `GameMode` instances
2. Update `game_service.dart` to delegate to mode classes
3. Remove old mode-specific methods from `board.dart`
4. Add mode instance to `ChessBoard` constructor
5. Test each mode to ensure behavior is preserved

## Usage Example

```dart
// In board.dart
class ChessBoard {
  final GameMode mode;
  
  ChessBoard({
    required this.pieces,
    required this.gameType,
  }) : mode = _createMode(gameType);
  
  static GameMode _createMode(GameType type) {
    switch (type) {
      case GameType.classic: return ClassicMode();
      case GameType.snare: return SnareMode();
      case GameType.heir: return HeirMode();
      case GameType.supremeQueen: return SupremeQueenMode();
      case GameType.royalPawns: return RoyalPawnsMode();
      case GameType.shiftyPawns: return ShiftyPawnsMode();
    }
  }
  
  List<ChessMove> getValidMovesFor(Position position) {
    final piece = getPieceAt(position);
    if (piece == null) return [];
    
    // Get potential moves
    var moves = _getPotentialMoves(piece);
    
    // Let mode filter moves
    moves = mode.filterMoves(moves, piece, this);
    
    return moves;
  }
}
```
