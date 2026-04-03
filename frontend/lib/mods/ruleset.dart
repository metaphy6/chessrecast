import '../board/utils/exporter.dart';

/// Base class for game-mode rulesets.
///
/// Each ruleset can override specific behaviors to modify the default chess
/// rules for a given mode.
abstract class Ruleset {
  const Ruleset();

  /// Returns custom pawn moves, or null to keep the default pawn behavior.
  List<ChessMove>? getPawnMoves(ChessPiece pawn, ChessBoard board) => null;

  /// Returns custom promotion pieces, or null to keep the default options.
  List<String>? getPromotionPieces(
    PieceColor color,
    ChessBoard board, {
    Position? promotionPosition,
  }) => null;

  /// Filters moves according to mode-specific rules.
  List<ChessMove> filterMoves(
    List<ChessMove> moves,
    ChessPiece piece,
    ChessBoard board,
  ) => moves;

  /// Returns a custom status, or null to keep the default status logic.
  GameStatus? updateGameStatus(
    ChessBoard board,
    bool currentPlayerInCheck,
    bool hasValidMoves,
  ) => null;

  /// Handles special move side effects before normal execution when needed.
  ChessBoard? handleSpecialMove(ChessBoard board, ChessMove move) => null;

  /// Returns a custom end-state decision, or null to keep the default logic.
  bool? isGameEnd(PieceColor color, ChessBoard board) => null;
}
