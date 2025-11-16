import 'dart:math';
import '../../board/entities/board.dart';
import '../../board/entities/move.dart';
import '../../debug.dart';
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
      logBot(name, 'No valid moves available');
      return null;
    }

    // Simulate thinking time
    await Future.delayed(Duration(milliseconds: thinkingDelayMs));

    final selectedMove = validMoves[_random.nextInt(validMoves.length)];

    logBot(
      name,
      'Selected random move: ${selectedMove.from.algebraic} → ${selectedMove.to.algebraic}',
    );

    return selectedMove;
  }
}

