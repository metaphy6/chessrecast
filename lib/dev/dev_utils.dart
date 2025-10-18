import '../constants.dart';

/// Debug logging utility that respects the global debug flag
///
/// Use this instead of print() throughout the app to enable/disable
/// debug output from a single location.
void debugLog(Object? message, {String? tag}) {
  if (AppConstants.enableDebugLogs) {
    final prefix = tag != null ? '[$tag] ' : '[DEBUG] ';
    print('$prefix$message');
  }
}

/// Log specifically for game mode logic
void gameModeLog(Object? message, {String? mode}) {
  if (AppConstants.enableDebugLogs) {
    final prefix = mode != null ? '[MODE:$mode] ' : '[MODE] ';
    print('$prefix$message');
  }
}

/// Log for move validation and execution
void moveLog(Object? message) {
  if (AppConstants.enableDebugLogs) {
    print('[MOVE] $message');
  }
}

/// Log for board state changes
void boardLog(Object? message) {
  if (AppConstants.enableDebugLogs) {
    print('[BOARD] $message');
  }
}

/// Log for UI events
void uiLog(Object? message) {
  if (AppConstants.enableDebugLogs) {
    print('[UI] $message');
  }
}
