import 'package:flutter/foundation.dart';

/// Log game moves only - shows which player moved what piece where
void logMove(String message) {
  debugPrint('♟️ MOVE: $message');
}

/// Log game end status - checkmate, stalemate, draw, etc
void logGameEnd(String message) {
  debugPrint('🏁 GAME END: $message');
}

/// Log API calls - requests to backend
void logApi(String message) {
  debugPrint('🌐 API: $message');
}

/// Error logging - always enabled even in production
void logError(dynamic message, [Object? error, StackTrace? stackTrace]) {
  debugPrint('❌ ERROR: $message');
  if (error != null) debugPrint('Error details: $error');
  if (stackTrace != null) debugPrint('Stack trace: $stackTrace');
}
