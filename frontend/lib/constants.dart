class AppConstants {
  // App Information
  static const String appName = 'Chess Recast';

  // Development & Debug Settings
  static const bool enableDebugLogs = true; // Enable move/API/error logging
  // Feature Flags
  static const bool enableDevBoard = true; // Enable custom board features

  /// When true, the app uses the legacy Go HTTP/WebSocket backend.
  /// Set to false to use the local SQLite store and (in later phases) the P2P
  /// DataChannel transport.  Defaults to false as of Phase 0.2.
  static const bool kUseLegacyBackend = false;
}
