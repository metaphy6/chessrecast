import '../../board/board.dart';
import '../../board/moves/move.dart';
import '../../board/items/piece_color.dart';

/// Base class for all chess bots
abstract class ChessBot {
  final String name;
  final PieceColor color;

  ChessBot({required this.name, required this.color});

  /// Selects the best move from the list of valid moves
  /// Returns null if no valid moves available
  Future<ChessMove?> selectMove(ChessBoard board, List<ChessMove> validMoves);

  /// Called when the bot is about to make a move (for logging/UI updates)
  void onThinking() {}

  /// Called after the bot makes a move
  void onMoveMade(ChessMove move) {}

  /// Get bot difficulty/strength description
  String get description;
}

