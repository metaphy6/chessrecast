import 'package:logger/logger.dart';
import 'constants.dart';

/// Global logger instance configured for the chess app
final logger = Logger(
  filter: _ChessLogFilter(),
  printer: PrettyPrinter(
    methodCount: 0, // Don't include call stack
    errorMethodCount: 5, // Show call stack for errors
    lineLength: 80,
    colors: true,
    printEmojis: true,
    dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
  ),
);

/// Custom log filter that respects AppConstants.enableDebugLogs
class _ChessLogFilter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) {
    if (!AppConstants.enableDebugLogs) {
      // Only show warnings and errors in production
      return event.level.index >= Level.warning.index;
    }
    return true; // Show all logs in debug mode
  }
}

/// Convenience function for backward compatibility
void printDebug(Object? message) {
  logger.d(message);
}

/// Bot-specific logger
void logBot(String botName, String message) {
  logger.i('🤖 [$botName] $message');
}

/// Analytics logger
void logAnalytics(String event, Map<String, dynamic>? data) {
  logger.i('📊 [Analytics] $event${data != null ? ': $data' : ''}');
}

/// Game logger
void logGame(String message) {
  logger.d('🎮 [Game] $message');
}

/// Error logger
void logError(String context, Object error, [StackTrace? stackTrace]) {
  logger.e('❌ [$context] $error', error: error, stackTrace: stackTrace);
}

/// Warning logger
void logWarning(String message) {
  logger.w('⚠️  $message');
}
