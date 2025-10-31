import '../board/exporter.dart';
import 'game_mode.dart';

/// SUPREME QUEEN MODE: The Queen is supreme - capturing it wins the game
///
/// Rules:
/// - Capturing the opponent's Queen wins the game immediately
/// - Pawns cannot promote to Queen (only R, B, N available)
/// - Standard chess rules for check, checkmate, and stalemate still apply
class SupremeQueen extends GameMode {
  @override
  List<String>? getPromotionPieces(
    PieceColor color,
    ChessBoard board, {
    Position? promotionPosition,
  }) {
    print('👑 SUPREME QUEEN: No Queen promotion allowed - only R, B, N');
    return ['R', 'B', 'N'];
  }

  @override
  ChessBoard? handleSpecialMove(ChessBoard board, ChessMove move) {
    // Check for Queen capture
    if (move.capturedPiece != null &&
        move.capturedPiece!.type == PieceType.queen) {
      print(
        '👑 SUPREME QUEEN: Queen captured! ${move.piece.color.name} wins immediately!',
      );
      final newBoard = board.makeMove(move);
      return newBoard.copyWith(gameStatus: GameStatus.checkmate);
    }
    return null;
  }
}
