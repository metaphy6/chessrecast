# Development Tools

This folder contains development and debugging utilities for Chess Recast.

## Files

### `dev_utils.dart`
Debug logging utilities that can be toggled on/off via `AppConstants.enableDebugLogs`.

**Functions:**
- `debugLog()` - General debug messages
- `gameModeLog()` - Game mode specific logs  
- `moveLog()` - Move validation logs
- `boardLog()` - Board state changes
- `uiLog()` - UI events

All respect the global debug flag in `lib/constants.dart`.

### `dev_board_setup.dart`
Interactive UI for setting up custom board positions for testing.

**Features:**
- Place any pieces on any squares
- Choose game mode
- Select starting turn
- Validate and start custom games
- Only visible when `AppConstants.enableDevBoard = true`

## Usage

### Enable Debug Mode
```dart
// lib/constants.dart
class AppConstants {
  static const bool kDebugMode = true; // false for production
  static const bool enableDebugLogs = kDebugMode;
  static const bool enableDevBoard = kDebugMode;
}
```

### Use Debug Logging
```dart
import '../dev/dev_utils.dart';

void myFunction() {
  debugLog('Debug message', tag: 'MyClass');
  gameModeLog('Game state changed', mode: 'SNARE');
}
```

### Access Dev Board
1. Set `enableDevBoard = true` in constants
2. Launch app
3. Click "Dev Board Setup" on start screen
4. Configure board and start game

## Documentation
See `docs/development-features.md` for complete documentation.
