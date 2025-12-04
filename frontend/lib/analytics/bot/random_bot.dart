import 'dart:math';
import '../../board/board.dart';
import '../../board/moves/move.dart';
import 'chess_bot.dart';

/// Simple bot that picks random moves
class RandomBot extends ChessBot {
  final Random _random = Random();
  final int thinkingDelayMs;

  RandomBot({
    required super.name,
    required super.color,
    this.thinkingDelayMs = 500,
  });

  @override
  String get description => 'Random move selection';

  @override
  Future<ChessMove?> selectMove(
    ChessBoard board,
    List<ChessMove> validMoves,
  ) async {
    if (validMoves.isEmpty) {
      return null;
    }

    // Simulate thinking time
    await Future.delayed(Duration(milliseconds: thinkingDelayMs));

    final selectedMove = validMoves[_random.nextInt(validMoves.length)];

    return selectedMove;
  }
}
