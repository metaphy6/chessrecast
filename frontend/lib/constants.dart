class AppConstants {
  // App Information
  static const String appName = 'Chess Recast';

  // Development & Debug Settings
  static const bool kDebugMode = true; // Set to false for production
  static const bool enableDebugLogs = true; // Enable move/API/error logging
  static const bool enableVerboseLogs =
      false; // Toggle very verbose logs (loop prints etc.)
  // Feature Flags
  static const bool enableDevBoard = kDebugMode; // Enable custom board features
}
