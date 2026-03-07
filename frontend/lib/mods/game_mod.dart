import '../board/utils/exporter.dart';

/// Base class for Game Mod implementations
/// Each Game Mod can override specific behaviors to modify chess rules
abstract class GameMod {
  const GameMod();

  /// Get pawn moves for this Game Mod
  /// Returns null if the mode uses default pawn behavior
  List<ChessMove>? getPawnMoves(ChessPiece pawn, ChessBoard board) => null;

  /// Get promotion pieces available for this Game Mod
  /// Returns null if the mode uses default promotion behavior
  List<String>? getPromotionPieces(
    PieceColor color,
    ChessBoard board, {
    Position? promotionPosition,
  }) => null;

  /// Filter moves based on Game Mod rules
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

  /// Check if the game has ended for a specific color (for mods with non-standard end conditions)
  bool? isGameEnd(PieceColor color, ChessBoard board) => null;
}
