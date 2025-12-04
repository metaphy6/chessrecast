import 'dart:math';
import '../../board/utils/exporter.dart';
import 'chess_bot.dart';

/// Ultra-fast bot that just picks random valid moves
/// Zero computation - instant move selection for smooth UI
class IsolateBot extends ChessBot {
  final Random _random = Random();
  final int thinkingDelayMs;

  IsolateBot({
    required super.name,
    required super.color,
    this.thinkingDelayMs = 100,
  });

  @override
  String get description => 'Fast random player';

  @override
  Future<ChessMove?> selectMove(
    ChessBoard board,
    List<ChessMove> validMoves,
  ) async {
    if (validMoves.isEmpty) {
      return null;
    }

    // Just pick a random move - no evaluation at all
    final selectedMove = validMoves[_random.nextInt(validMoves.length)];

    // Very small delay just for visual feedback
    await Future.delayed(Duration(milliseconds: thinkingDelayMs));

    return selectedMove;
  }
}
