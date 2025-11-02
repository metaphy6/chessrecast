import 'dart:math';
import '../board/entities/board.dart';
import '../board/entities/move.dart';
import '../debug.dart';
import 'chess_bot.dart';

/// Bot that prioritizes captures and good tactical moves
class GreedyBot extends ChessBot {
  final Random _random = Random();
  final int thinkingDelayMs;

  GreedyBot({
    required super.name,
    required super.color,
    this.thinkingDelayMs = 100,
  });

  @override
  String get description => 'Prefers captures';

  @override
  Future<ChessMove?> selectMove(
    ChessBoard board,
    List<ChessMove> validMoves,
  ) async {
    if (validMoves.isEmpty) {
      logBot(name, 'No valid moves available');
      return null;
    }

    // Very simple: prefer any capture, otherwise random
    final captures = validMoves.where((m) => m.capturedPiece != null).toList();

    final selectedMove = captures.isNotEmpty
        ? captures[_random.nextInt(captures.length)]
        : validMoves[_random.nextInt(validMoves.length)];

    logBot(
      name,
      'Selected: ${selectedMove.from.algebraic}→${selectedMove.to.algebraic}${selectedMove.capturedPiece != null ? ' (captures!)' : ''}',
    );

    await Future.delayed(Duration(milliseconds: thinkingDelayMs));
    return selectedMove;
  }
}
