# Chess Recast - Development Features

## Overview
This document describes the development and debugging features available in Chess Recast.

## Debug Configuration

### Enable/Disable Debug Mode
Located in `lib/constants.dart`:

```dart
class AppConstants {
  static const bool kDebugMode = true; // Set to false for production
  static const bool enableDebugLogs = kDebugMode; // Control print statements
  static const bool enableDevBoard = kDebugMode; // Enable dev board features
}
```

**For Production:**
- Set `kDebugMode = false`
- This will automatically disable all debug logs and hide the dev board button

## Debug Logging System

### Available Logging Functions
Located in `lib/dev/dev_utils.dart`:

1. **debugLog()** - General debug messages
   ```dart
   debugLog('Something happened', tag: 'MyClass');
   // Output: [MyClass] Something happened
   ```

2. **gameModeLog()** - Game mode specific logs
   ```dart
   gameModeLog('Knight captured', mode: 'SNARE');
   // Output: [MODE:SNARE] Knight captured
   ```

3. **moveLog()** - Move validation and execution logs
   ```dart
   moveLog('Move from e2 to e4');
   // Output: [MOVE] Move from e2 to e4
   ```

4. **boardLog()** - Board state changes
   ```dart
   boardLog('Board updated after move');
   // Output: [BOARD] Board updated after move
   ```

5. **uiLog()** - UI events and interactions
   ```dart
   uiLog('User selected square e4');
   // Output: [UI] User selected square e4
   ```

### Usage
All debug log functions respect the `AppConstants.enableDebugLogs` flag. When set to `false`, they produce no output.

## Dev Board Setup

### Accessing Dev Board
1. Ensure `AppConstants.enableDevBoard = true` in `constants.dart`
2. Launch the app
3. On the start screen, click "Dev Board Setup" button (purple button at bottom)

### Features

#### Custom Piece Placement
1. **Select Piece Color**: Choose White or Black pieces
2. **Select Piece Type**: Choose from King, Queen, Rook, Bishop, Knight, or Pawn
3. **Place Pieces**: Tap any square on the board to place the selected piece
4. **Remove Pieces**: Select the eraser (❌) icon and tap a square to remove a piece

#### Game Mode Selection
- Dropdown at the top allows you to select any game mode:
  - Classic Chess
  - Snare Mode
  - Heir Mode
  - Royal Pawns
  - Shifty Pawns
  - Supreme Queen

#### Starting Turn
- Choose whether White or Black plays first

#### Presets
- **Reset to Start**: Loads the standard chess starting position
- **Clear Board**: Removes all pieces from the board

#### Validation
- Both White and Black kings must be present to start a game
- The app will show an error if you try to start without both kings

#### Starting the Game
1. Set up your desired position
2. Select game mode and starting turn
3. Click "Start Game" button
4. Board will be marked with a purple "DEV" badge in the game

### Dev Board in Game
When playing on a dev board, you'll see:
- Purple "DEV" badge in the app bar
- Full undo/redo functionality
- All standard game features

## Undo/Redo System

### How It Works
The game maintains a complete history of board states:
- Every move creates a snapshot of the entire board state
- Undo reverts to the previous state
- Redo moves forward through history
- Making a new move clears any "future" history

### Usage in Game
- **Undo Button** (⏪): Click to undo the last move
  - Disabled when no moves have been made
  - Grayed out when unavailable
  
- **Redo Button** (⏩): Click to redo an undone move
  - Only available after undoing moves
  - Disabled when at the end of history
  - Making a new move clears redo history

### Keyboard Shortcuts (Future Enhancement)
Future versions may support:
- `Ctrl+Z` for Undo
- `Ctrl+Y` or `Ctrl+Shift+Z` for Redo

## Move History

### Accessing Move History
The move history is tracked internally in the ChessController:
- `_boardHistory`: List of all board states
- `_historyIndex`: Current position in history

### Reset Game
The "🔄 New Game" button:
- Resets to the initial starting position
- Clears all move history
- For dev boards, resets to the custom starting position you configured

## Development Workflow

### Typical Dev Workflow
1. **Enable Debug Mode**
   ```dart
   // lib/constants.dart
   static const bool kDebugMode = true;
   ```

2. **Add Debug Logs** (example in a mode file)
   ```dart
   import '../dev/dev_utils.dart';
   
   void someFunction() {
     gameModeLog('Checking knight positions', mode: 'SNARE');
     // ... your logic
     gameModeLog('Found ${knights.length} knights', mode: 'SNARE');
   }
   ```

3. **Test Custom Positions**
   - Use Dev Board Setup to create specific scenarios
   - Test edge cases, checkmate patterns, special moves
   - Use undo/redo to experiment with move sequences

4. **Prepare for Production**
   ```dart
   // lib/constants.dart
   static const bool kDebugMode = false; // Disables all debug features
   ```

## Architecture

### Files Structure
```
lib/
├── constants.dart           # Debug flags configuration
├── dev/
│   ├── dev_utils.dart      # Debug logging utilities
│   └── dev_board_setup.dart # Custom board setup UI
├── controllers/
│   └── chess_controller.dart # Includes move history system
├── ui/
│   ├── game_page.dart      # Shows undo/redo buttons
│   └── start.dart          # Shows dev board button
└── routes.dart             # Includes dev board route
```

### State Management
- **Move History**: Stored in `ChessController._boardHistory`
- **History Index**: Tracked with `ChessController._historyIndex`
- **Reactive Updates**: Undo/redo buttons auto-enable/disable via Obx

### Custom Board Initialization
When creating a dev board:
```dart
Get.toNamed('/game', arguments: {
  'gameType': GameType.snare,
  'customBoard': List<ChessPiece>[...],
  'currentPlayer': PieceColor.white,
  'isDevBoard': true,
});
```

The ChessController checks for `customBoard` in arguments and initializes accordingly.

## Future Enhancements

### Planned Features
1. **FEN Import/Export**: Load positions from FEN notation
2. **Move List Display**: Show all moves in algebraic notation
3. **Position Analysis**: Evaluate board positions
4. **Save/Load Positions**: Save custom positions for later
5. **Replay Mode**: Step through game move by move
6. **Performance Profiling**: Track move calculation times
7. **Debug Overlays**: Visual display of valid moves, attack zones, etc.

### Contributing
When adding new features:
1. Always use `debugLog()` family for debug output
2. Add dev-specific features behind `AppConstants.enableDevBoard` flag
3. Document new features in this file
4. Ensure production mode (`kDebugMode = false`) works cleanly

## Troubleshooting

### Debug Logs Not Showing
- Check `AppConstants.enableDebugLogs` is `true`
- Verify import: `import '../dev/dev_utils.dart';`
- Use correct log function (debugLog, gameModeLog, etc.)

### Dev Board Button Not Visible
- Check `AppConstants.enableDevBoard` is `true`
- Restart the app (hot reload may not pick up const changes)

### Undo/Redo Not Working
- Check console for errors
- Verify move history is being populated
- Try resetting the game

### Custom Board Not Loading
- Ensure both kings are present
- Check console for validation errors
- Verify piece positions are valid (0-7 for row/col)

## Contact & Support
For issues or questions about development features, please check the main README or open an issue on GitHub.
