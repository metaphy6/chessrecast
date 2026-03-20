import '../board/game_status.dart';
import '../board/pieces/piece_color.dart';
import '../mods/mods_enum.dart';

/// Tracks game statistics and analytics
class GameAnalytics {
  // Game identification
  final String gameId;
  final ModsEnum gameMod;
  final DateTime startTime;
  DateTime? endTime;

  // Player info
  final String whitePlayer;
  final String blackPlayer;
  final bool isWhiteBot;
  final bool isBlackBot;

  // Game stats
  int moveCount = 0;
  int whiteMoveCount = 0;
  int blackMoveCount = 0;
  int captureCount = 0;
  int promotionCount = 0;

  // Time tracking
  final List<Duration> moveTimes = [];
  DateTime? lastMoveTime;

  // Game outcome
  GameStatus? finalStatus;
  PieceColor? winner;
  String? endReason;

  // Move history details
  final List<String> moveList = [];

  GameAnalytics({
    required this.gameId,
    required this.gameMod,
    required this.whitePlayer,
    required this.blackPlayer,
    this.isWhiteBot = false,
    this.isBlackBot = false,
  }) : startTime = DateTime.now() {
    lastMoveTime = startTime;
  }

  /// Record a move
  void recordMove(
    String moveNotation,
    PieceColor player, {
    bool isCapture = false,
    bool isPromotion = false,
  }) {
    moveCount++;
    if (player == PieceColor.white) {
      whiteMoveCount++;
    } else {
      blackMoveCount++;
    }

    if (isCapture) captureCount++;
    if (isPromotion) promotionCount++;

    moveList.add(moveNotation);

    // Track move time
    final now = DateTime.now();
    if (lastMoveTime != null) {
      moveTimes.add(now.difference(lastMoveTime!));
    }
    lastMoveTime = now;
  }

  /// End the game
  void endGame({
    required GameStatus status,
    PieceColor? winnerColor,
    String? reason,
  }) {
    endTime = DateTime.now();
    finalStatus = status;
    winner = winnerColor;
    endReason = reason;
  }

  /// Get game statistics
  Map<String, dynamic> getStatistics() {
    final duration = (endTime ?? DateTime.now()).difference(startTime);
    final avgMoveTime = moveTimes.isEmpty
        ? Duration.zero
        : Duration(
            milliseconds:
                moveTimes
                    .map((d) => d.inMilliseconds)
                    .reduce((a, b) => a + b) ~/
                moveTimes.length,
          );

    return {
      'gameId': gameId,
      'mode': gameMod.displayName,
      'whitePlayer': whitePlayer,
      'blackPlayer': blackPlayer,
      'isWhiteBot': isWhiteBot,
      'isBlackBot': isBlackBot,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'duration': duration.inSeconds,
      'status': finalStatus?.name,
      'winner': winner?.name,
      'endReason': endReason,
      'totalMoves': moveCount,
      'whiteMoves': whiteMoveCount,
      'blackMoves': blackMoveCount,
      'captures': captureCount,
      'promotions': promotionCount,
      'avgMoveTimeMs': avgMoveTime.inMilliseconds,
      'moveList': moveList,
    };
  }
}
