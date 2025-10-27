import '../board/exporter.dart';
import 'game_mode.dart';

/// Kings' Battle Mode: Two-phase game with restricted movement initially
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
class KingsBattleMode implements GameMode {
  @override
  List<ChessMove> filterMoves(
    List<ChessMove> moves,
    ChessPiece piece,
    ChessBoard board,
  ) {
    print('👑 KINGS BATTLE: === FILTERING MOVES ===');
    print(
      '👑 KINGS BATTLE: Piece: ${piece.color.name} ${piece.type.name} at ${piece.position.algebraic}',
    );
    print('👑 KINGS BATTLE: Phase: ${_getPhase(board)}');

    // Check if we're in Phase 1 (before King's Kill)
    if (!_hasKingsKillHappened(board)) {
      print('👑 KINGS BATTLE: PHASE 1 - Only kings and pawns can move');

      // In Phase 1, only kings and pawns can move
      if (piece.type != PieceType.king && piece.type != PieceType.pawn) {
        print('👑 KINGS BATTLE: ❌ ${piece.type.name} cannot move in Phase 1');
        return []; // Other pieces cannot move yet
      }

      // Kings cannot capture other kings
      if (piece.type == PieceType.king) {
        final filteredMoves = moves.where((move) {
          if (move.capturedPiece != null &&
              move.capturedPiece!.type == PieceType.king) {
            print('👑 KINGS BATTLE: ❌ King cannot capture enemy king');
            return false;
          }
          return true;
        }).toList();

        print('👑 KINGS BATTLE: King moves: ${filteredMoves.length}');
        return filteredMoves;
      }

      print('👑 KINGS BATTLE: Pawn moves: ${moves.length}');
      return moves; // Pawns can move normally
    }

    // Phase 2: All pieces can move normally
    print('👑 KINGS BATTLE: PHASE 2 - All pieces can move');
    return moves;
  }

  @override
  ChessBoard? handleSpecialMove(ChessBoard board, ChessMove move) {
    // Check if this move is a King's Kill (king capturing a pawn)
    if (move.piece.type == PieceType.king &&
        move.capturedPiece != null &&
        move.capturedPiece!.type == PieceType.pawn &&
        !_hasKingsKillHappened(board)) {
      print(
        '👑 KINGS BATTLE: ⚔️ KING\'S KILL! ${move.piece.color.name} king captured pawn at ${move.to.algebraic}',
      );

      // Execute the move normally first
      final newBoard = board.makeMove(move);

      // Mark that King's Kill has happened and grant bonus move
      // We'll use a custom board property for this
      return _markKingsKillAndGrantBonusMove(newBoard);
    }

    // Check if this is a pawn promotion (also unlocks all pieces)
    if (move.isPromotion && !_hasKingsKillHappened(board)) {
      print(
        '👑 KINGS BATTLE: 👑 PAWN PROMOTED! This unlocks all pieces like King\'s Kill',
      );

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

  String _getPhase(ChessBoard board) {
    return _hasKingsKillHappened(board)
        ? 'PHASE 2 (All Pieces)'
        : 'PHASE 1 (Kings & Pawns Only)';
  }

  /// Marks that King's Kill happened and grants a bonus move
  /// This is done by NOT switching the current player
  ChessBoard _markKingsKillAndGrantBonusMove(ChessBoard board) {
    print(
      '👑 KINGS BATTLE: 🎁 Granting bonus move to ${board.currentPlayer.opposite.name}',
    );

    // The board has already switched players after the move
    // We need to switch back to give the same player another turn
    return board.copyWith(
      currentPlayer: board.currentPlayer.opposite, // Switch back
    );
  }
}
