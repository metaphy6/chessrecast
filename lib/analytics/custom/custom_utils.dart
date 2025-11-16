import '../../constants.dart';
import '../../debug.dart';

/// Debug logging utility that respects the global debug flag
///
/// Use this instead of print() throughout the app to enable/disable
/// debug output from a single location.
void debugLog(Object? message, {String? tag}) {
  if (AppConstants.enableDebugLogs) {
    final prefix = tag != null ? '[$tag] ' : '[DEBUG] ';
    printDebug('$prefix$message');
  }
}

/// Log specifically for game mode logic
void gameModeLog(Object? message, {String? mode}) {
  if (AppConstants.enableDebugLogs) {
    final prefix = mode != null ? '[MODE:$mode] ' : '[MODE] ';
    printDebug('$prefix$message');
  }
}

/// Log for move validation and execution
void moveLog(Object? message) {
  if (AppConstants.enableDebugLogs) {
    printDebug('[MOVE] $message');
  }
}

/// Log for board state changes
void boardLog(Object? message) {
  if (AppConstants.enableDebugLogs) {
    printDebug('[BOARD] $message');
  }
}

/// Log for UI events
void uiLog(Object? message) {
  if (AppConstants.enableDebugLogs) {
    printDebug('[UI] $message');
  }
}
