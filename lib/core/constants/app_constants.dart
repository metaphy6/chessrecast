class AppConstants {
  // App Information
  static const String appName = 'Chess Recast';
  static const String appVersion = '1.0.0';
  static const String appDescription =
      'Novel chess with the same board, same pieces but with new rules!';

  // Chess Board
  static const int boardSize = 8;
  static const double squareSize = 60.0;
  static const double boardPadding = 16.0;

  // Animation Durations
  static const Duration moveAnimationDuration = Duration(milliseconds: 300);
  static const Duration selectionAnimationDuration = Duration(
    milliseconds: 150,
  );

  // Colors
  static const lightSquareColor = 0xFFF0D9B5;
  static const darkSquareColor = 0xFFB58863;
  static const selectedSquareColor = 0xFF7FFF00;
  static const validMoveColor = 0xFF90EE90;

  // Messages
  static const String gameOverMessage = 'Game Over!';
  static const String checkMessage = 'Check!';
  static const String checkmateMessage = 'Checkmate!';
  static const String stalemateMessage = 'Stalemate!';
  static const String drawMessage = 'Draw!';

  // Development
  static const bool showDebugInfo = false;
  static const bool showCoordinates = false;
}
