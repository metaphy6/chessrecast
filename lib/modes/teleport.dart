import 'package:chessrecast/debug.dart';
import '../board/exporter.dart';
import 'game_mode.dart';

/// TELEPORT MODE: Kings and rooks can swap positions when aligned
///
/// Rules:
/// - Kings can teleport with friendly rooks on the same rank (horizontal)
/// - Kings can teleport with friendly rooks on the same file (vertical)
/// - Teleport swaps the positions of king and rook instantly
/// - No castling is allowed in this mode
/// - All other pieces move normally
class Teleport extends GameMode {
  /// Gets all rooks of the specified color
  List<ChessPiece> getRooks(PieceColor color, ChessBoard board) {
    return board.pieces
        .where((piece) => piece.type == PieceType.rook && piece.color == color)
        .toList();
  }

  /// Checks if king and rook are aligned (same rank or file)
  bool _areAligned(Position kingPos, Position rookPos) {
    return kingPos.row == rookPos.row || kingPos.col == rookPos.col;
  }

  @override
  List<ChessMove> filterMoves(
    List<ChessMove> moves,
    ChessPiece piece,
    ChessBoard board,
  ) {
    // Only modify king moves
    if (piece.type != PieceType.king) {
      return moves; // Other pieces move normally
    }

    printDebug('🔄 TELEPORT: === FILTERING KING MOVES ===');
    printDebug(
      '🔄 TELEPORT: King: ${piece.color.name} at ${piece.position.algebraic}',
    );

    final filteredMoves = <ChessMove>[...moves];

    // Add teleport moves with friendly rooks (no path check - it's a teleport!)
    final friendlyRooks = getRooks(piece.color, board);
    for (final rook in friendlyRooks) {
      if (_areAligned(piece.position, rook.position)) {
        printDebug(
          '🔄 TELEPORT: ✓ Can teleport with rook at ${rook.position.algebraic}',
        );

        // Create a special move where king moves to rook's position
        // The actual swap will be handled in handleSpecialMove
        filteredMoves.add(
          ChessMove.simple(
            from: piece.position,
            to: rook.position,
            piece: piece,
          ),
        );
      }
    }

    printDebug('🔄 TELEPORT: Total moves: ${filteredMoves.length}');
    printDebug('🔄 TELEPORT: === END FILTERING ===');

    return filteredMoves;
  }

  @override
  ChessBoard? handleSpecialMove(ChessBoard board, ChessMove move) {
    printDebug('🔄 TELEPORT: handleSpecialMove called');
    printDebug('🔄 TELEPORT: Move piece: ${move.piece.type.name}');
    printDebug(
      '🔄 TELEPORT: Move from: ${move.from.algebraic} to: ${move.to.algebraic}',
    );
    printDebug(
      '🔄 TELEPORT: Move capturedPiece: ${move.capturedPiece != null ? "${move.capturedPiece!.color.name} ${move.capturedPiece!.type.name}" : "NONE"}',
    );

    // Check if this is a king moving to a rook's position (teleport)
    // The move might have capturedPiece set to the rook (from _attemptMove in controller)
    // or it might not (from move generation)
    if (move.piece.type == PieceType.king) {
      final targetPiece = board.getPieceAt(move.to);
      printDebug(
        '🔄 TELEPORT: Target piece at ${move.to.algebraic}: ${targetPiece != null ? "${targetPiece.color.name} ${targetPiece.type.name}" : "NONE"}',
      );

      // Check if target is a friendly rook (either from board or from move.capturedPiece)
      final isTargetFriendlyRook =
          (targetPiece != null &&
              targetPiece.type == PieceType.rook &&
              targetPiece.color == move.piece.color) ||
          (move.capturedPiece != null &&
              move.capturedPiece!.type == PieceType.rook &&
              move.capturedPiece!.color == move.piece.color);

      if (isTargetFriendlyRook) {
        // Use the target piece from board (more reliable than move.capturedPiece)
        final rookPiece = targetPiece!;

        printDebug(
          '🔄 TELEPORT: ✅ Executing teleport swap: king at ${move.from.algebraic} ↔ rook at ${move.to.algebraic}',
        );

        // Remove both pieces
        final newPieces = board.pieces.where((piece) {
          return piece.position != move.from && piece.position != move.to;
        }).toList();

        // Add king at rook's old position
        newPieces.add(move.piece.movedTo(move.to));

        // Add rook at king's old position
        newPieces.add(rookPiece.movedTo(move.from));

        final newBoard = board.copyWith(
          pieces: newPieces,
          currentPlayer: board.currentPlayer.opposite,
          moveHistory: [...board.moveHistory, move],
        );

        printDebug('🔄 TELEPORT: ✅ Teleport complete!');
        return newBoard;
      }
    }

    printDebug('🔄 TELEPORT: Not a teleport move, returning null');
    return null; // Not a teleport move, use standard handling
  }

  @override
  List<String>? getPromotionPieces(
    PieceColor color,
    ChessBoard board, {
    Position? promotionPosition,
  }) {
    return null; // Use standard promotions
  }

  @override
  GameStatus? updateGameStatus(
    ChessBoard board,
    bool currentPlayerInCheck,
    bool hasValidMoves,
  ) {
    return null; // Use standard chess rules
  }
}
