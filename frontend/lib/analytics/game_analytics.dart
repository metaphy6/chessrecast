import '../board/game_status.dart';
import '../board/items/piece_color.dart';
import '../modes/modes_enum.dart';
import '../debug.dart';

/// Tracks game statistics and analytics
class GameAnalytics {
  // Game identification
  final String gameId;
  final ModesEnum gameMode;
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
    required this.gameMode,
    required this.whitePlayer,
    required this.blackPlayer,
    this.isWhiteBot = false,
    this.isBlackBot = false,
  }) : startTime = DateTime.now() {
    lastMoveTime = startTime;
    logAnalytics('Game Started', {
      'gameId': gameId,
      'mode': gameMode.name,
      'white': whitePlayer,
      'black': blackPlayer,
      'whiteIsBot': isWhiteBot,
      'blackIsBot': isBlackBot,
    });
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

    // Log the move with player color and move number
    final playerName = player == PieceColor.white ? whitePlayer : blackPlayer;
    final isBot = player == PieceColor.white ? isWhiteBot : isBlackBot;
    final botIndicator = isBot ? ' 🤖' : '';

    logGame(
      'Move #$moveCount: ${player.name.toUpperCase()}$botIndicator ($playerName) - $moveNotation',
    );

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

    final duration = endTime!.difference(startTime);

    logAnalytics('Game Ended', {
      'gameId': gameId,
      'mode': gameMode.name,
      'status': status.name,
      'winner': winner?.name ?? 'none',
      'reason': reason ?? 'normal',
      'duration': duration.inSeconds,
      'moves': moveCount,
      'captures': captureCount,
      'promotions': promotionCount,
    });
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
      'mode': gameMode.displayName,
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

  /// Print summary to console
  void printSummary() {
    final stats = getStatistics();
    final duration = Duration(seconds: stats['duration'] as int);

    printDebug('📊 ═══════════════════════════════════════');
    printDebug('📊 GAME SUMMARY');
    printDebug('📊 ═══════════════════════════════════════');
    printDebug('📊 Mode: ${stats['mode']}');
    printDebug('📊 White: ${stats['whitePlayer']}${isWhiteBot ? ' 🤖' : ''}');
    printDebug('📊 Black: ${stats['blackPlayer']}${isBlackBot ? ' 🤖' : ''}');
    printDebug('📊 ───────────────────────────────────────');
    printDebug('📊 Result: ${stats['status']?.toString().toUpperCase()}');
    if (winner != null) {
      printDebug('📊 Winner: ${winner!.name.toUpperCase()}');
    }
    if (endReason != null) {
      printDebug('📊 Reason: $endReason');
    }
    printDebug('📊 ───────────────────────────────────────');
    printDebug(
      '📊 Duration: ${duration.inMinutes}m ${duration.inSeconds % 60}s',
    );
    printDebug('📊 Total Moves: $moveCount');
    printDebug('📊 Captures: $captureCount');
    printDebug('📊 Promotions: $promotionCount');
    printDebug('📊 Avg Move Time: ${stats['avgMoveTimeMs']}ms');
    printDebug('📊 ───────────────────────────────────────');

    // Print complete move history
    if (moveList.isNotEmpty) {
      printDebug('📊 COMPLETE MOVE HISTORY:');
      for (int i = 0; i < moveList.length; i++) {
        final moveNum = i + 1;
        final color = i % 2 == 0 ? 'WHITE' : 'BLACK';
        printDebug('📊   #$moveNum $color: ${moveList[i]}');
      }
      printDebug('📊 ───────────────────────────────────────');
    }

    printDebug('📊 ═══════════════════════════════════════');
  }
}
