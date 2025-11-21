import 'package:flutter/foundation.dart';
import 'constants.dart';

/// Main debug print function - compile-time optimization
/// In release builds, these calls are completely stripped out
void printDebug(dynamic message) {
  if (kDebugMode && AppConstants.enableDebugLogs) {
    debugPrint(message.toString());
  }
}

/// Very verbose debug (for hot-loops and high-volume logging)
void printDebugVerbose(dynamic message) {
  if (kDebugMode &&
      AppConstants.enableDebugLogs &&
      AppConstants.enableVerboseLogs) {
    debugPrint(message.toString());
  }
}

/// Bot-specific logging - accepts optional bot name
void logBot(dynamic message, [dynamic secondParam]) {
  if (kDebugMode && AppConstants.enableDebugLogs) {
    // Support both old (name, message) and new (message) signatures
    if (secondParam != null) {
      debugPrint('🤖 BOT [$message]: $secondParam');
    } else {
      debugPrint('🤖 BOT: $message');
    }
  }
}

/// Analytics logging - accepts optional context
void logAnalytics(dynamic message, [Map<String, dynamic>? context]) {
  if (kDebugMode && AppConstants.enableDebugLogs) {
    debugPrint('📊 ANALYTICS: $message${context != null ? ' - $context' : ''}');
  }
}

/// Game flow logging
void logGame(dynamic message) {
  if (kDebugMode && AppConstants.enableDebugLogs) {
    debugPrint('♟️ GAME: $message');
  }
}

/// Error logging - always enabled even in production
void logError(dynamic message, [Object? error, StackTrace? stackTrace]) {
  if (kDebugMode) {
    debugPrint('❌ ERROR: $message');
    if (error != null) debugPrint('Error details: $error');
    if (stackTrace != null) debugPrint('Stack trace: $stackTrace');
  }
}
