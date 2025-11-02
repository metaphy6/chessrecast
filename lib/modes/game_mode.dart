import '../board/exporter.dart';

/// Base class for game mode implementations
/// Each game mode can override specific behaviors to modify chess rules
abstract class GameMode {
  /// Get pawn moves for this game mode
  /// Returns null if the mode uses default pawn behavior
  List<ChessMove>? getPawnMoves(ChessPiece pawn, ChessBoard board) => null;

  /// Get promotion pieces available for this game mode
  /// Returns null if the mode uses default promotion behavior
  List<String>? getPromotionPieces(
    PieceColor color,
    ChessBoard board, {
    Position? promotionPosition,
  }) => null;

  /// Filter moves based on game mode rules
  /// Returns the same list if no filtering is needed
  List<ChessMove> filterMoves(
    List<ChessMove> moves,
    ChessPiece piece,
    ChessBoard board,
  ) => moves;

  /// Update game status based on mode-specific rules
  /// Returns null if the mode uses default status update logic
  GameStatus? updateGameStatus(
    ChessBoard board,
    bool currentPlayerInCheck,
    bool hasValidMoves,
  ) => null;

  /// Check if a move should trigger special behavior before execution
  /// Returns a modified board if special handling occurred, or null for normal move processing
  ChessBoard? handleSpecialMove(ChessBoard board, ChessMove move) => null;

  /// Check if the game has ended for a specific color (for modes with non-standard end conditions)
  bool? isGameEnd(PieceColor color, ChessBoard board) => null;
}
