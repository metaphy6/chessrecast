import '../board/utils/exporter.dart';
import '../debug.dart';
import 'game_mod.dart';

/// Kings' Battle Mod: Two-phase game with restricted movement initially
///
/// PHASE 1 (Before King's Kill):
/// - Only pawns and kings can move
/// - Kings and pawns can capture any piece (even checkmate)
/// - Kings cannot capture each other
/// - If king captures a pawn = "King's Kill" → Phase 2 + bonus move
/// - Pawn promotion unlocks all pieces (acts like King's Kill happened)
///
/// PHASE 2 (After King's Kill):
/// - All pieces can move normally
/// - Standard chess rules apply
/// - Player who made King's Kill gets one bonus move immediately
class KingsBattle implements GameMod {
  @Deprecated(
    'Use the `mods.kingsBattle` alias from mods_cache.dart instead of direct instantiation',
  )
  const KingsBattle();
  @override
  List<ChessMove> filterMoves(
    List<ChessMove> moves,
    ChessPiece piece,
    ChessBoard board,
  ) {
    // Check if we're in Phase 1 (before King's Kill)
    if (!_hasKingsKillHappened(board)) {
      // In Phase 1, only kings and pawns can move
      if (piece.type != PieceType.king && piece.type != PieceType.pawn) {
        return []; // Other pieces cannot move yet
      }

      // Kings cannot capture other kings
      if (piece.type == PieceType.king) {
        final filteredMoves = moves.where((move) {
          if (move.capturedPiece != null &&
              move.capturedPiece!.type == PieceType.king) {
            return false;
          }
          return true;
        }).toList();

        return filteredMoves;
      }

      return moves; // Pawns can move normally
    }

    // Phase 2: All pieces can move normally
    return moves;
  }

  @override
  ChessBoard? handleSpecialMove(ChessBoard board, ChessMove move) {
    // Check if this move is a King's Kill (king capturing a pawn)
    if (move.piece.type == PieceType.king &&
        move.capturedPiece != null &&
        move.capturedPiece!.type == PieceType.pawn &&
        !_hasKingsKillHappened(board)) {
      // Execute the move normally first
      final newBoard = board.makeMove(move);

      // Mark that King's Kill has happened and grant bonus move
      // We'll use a custom board property for this
      final playerColor = move.piece.color == PieceColor.white
          ? 'White'
          : 'Black';
      final position =
          '${String.fromCharCode(97 + move.to.col)}${8 - move.to.row}';
      logKingsBattleUnlock(playerColor, position);

      return _markKingsKillAndGrantBonusMove(newBoard);
    }

    // Check if this is a pawn promotion (also unlocks all pieces)
    if (move.isPromotion && !_hasKingsKillHappened(board)) {
      // Execute the promotion normally first
      final newBoard = board.makeMove(move);

      // Mark that King's Kill equivalent has happened (pawn promoted)
      return _markKingsKillAndGrantBonusMove(newBoard);
    }

    return null; // Use standard handling
  }

  @override
  GameStatus? updateGameStatus(
    ChessBoard board,
    bool currentPlayerInCheck,
    bool hasValidMoves,
  ) {
    // Standard checkmate/stalemate logic applies
    return null;
  }

  @override
  List<String>? getPromotionPieces(
    PieceColor color,
    ChessBoard board, {
    Position? promotionPosition,
  }) {
    // Standard promotion to any piece
    return null; // Use default
  }

  @override
  List<ChessMove>? getPawnMoves(ChessPiece pawn, ChessBoard board) {
    // Use default pawn moves
    return null;
  }

  @override
  bool? isGameEnd(PieceColor color, ChessBoard board) {
    // Use default game end logic
    return null;
  }

  /// Helper methods

  /// Checks if King's Kill has happened (public for engine FFI bridge)
  bool isUnlocked(ChessBoard board) => _hasKingsKillHappened(board);

  /// Checks if King's Kill has happened by looking at move history
  bool _hasKingsKillHappened(ChessBoard board) {
    // Check if any move in history was a king capturing a pawn
    for (final move in board.moveHistory) {
      if (move.piece.type == PieceType.king &&
          move.capturedPiece != null &&
          move.capturedPiece!.type == PieceType.pawn) {
        return true; // King's Kill happened
      }

      // Also check for pawn promotions (equivalent to King's Kill)
      if (move.isPromotion) {
        return true; // Promotion unlocks all pieces
      }
    }

    return false; // Still in Phase 1
  }

  /// Marks that King's Kill happened and grants a bonus move
  /// This is done by NOT switching the current player
  ChessBoard _markKingsKillAndGrantBonusMove(ChessBoard board) {
    // The board has already switched players after the move
    // We need to switch back to give the same player another turn
    return board.copyWith(
      currentPlayer: board.currentPlayer.opposite, // Switch back
    );
  }
}
