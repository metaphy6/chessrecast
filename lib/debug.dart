import 'constants.dart';

/// Conditional print function that only prints when enableDebugLogs is true
///
/// Usage:
/// ```dart
/// printDebug('Debug message here');
/// ```
///
/// To disable all debug prints, set `AppConstants.kDebugMode = false` in constants.dart
void printDebug(Object? message) {
  if (AppConstants.enableDebugLogs) {
    print(message);
  }
}
