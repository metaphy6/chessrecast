import 'package:chessrecast/debug.dart';
import '../board/exporter.dart';
import 'game_mode.dart';

/// Friendly Fire Mode: Players can capture their own pieces (except kings)
/// - Can capture your own pieces
/// - Cannot capture your own king
/// - Cannot capture pieces that haven't moved yet (balancing restriction)
/// - Cannot put yourself in check/checkmate
class FriendlyFire implements GameMode {
  @override
  List<ChessMove> filterMoves(
    List<ChessMove> moves,
    ChessPiece piece,
    ChessBoard board,
  ) {
    printDebug('🔥 FRIENDLY FIRE: === FILTERING MOVES ===');
    printDebug(
      '🔥 FRIENDLY FIRE: Piece: ${piece.color.name} ${piece.type.name} at ${piece.position.algebraic}',
    );

    // Get all potential moves including captures of friendly pieces
    final expandedMoves = <ChessMove>[];

    // Keep all existing moves (empty squares and enemy captures)
    expandedMoves.addAll(moves);

    // Add moves that capture friendly pieces (except the king and unmoved pieces)
    final friendlyPieces = board.pieces.where(
      (p) =>
          p.color == piece.color &&
          p.type != PieceType.king && // Can't capture own king
          p.hasMoved && // Can only capture pieces that have moved (balancing)
          p.position != piece.position, // Can't capture self
    );

    printDebug(
      '🔥 FRIENDLY FIRE: Found ${friendlyPieces.length} friendly pieces that have moved',
    );

    printDebug(
      '🔥 FRIENDLY FIRE: Found ${friendlyPieces.length} friendly pieces that have moved',
    );

    for (final friendlyPiece in friendlyPieces) {
      final targetPosition = friendlyPiece.position;

      printDebug(
        '🔥 FRIENDLY FIRE: Checking if can reach ${friendlyPiece.type.name} at ${targetPosition.algebraic}',
      );

      // Check if this piece can reach this friendly piece's position
      if (_canPieceReach(piece, targetPosition, board, moves)) {
        // Create a capture move for the friendly piece
        final friendlyFireMove = ChessMove.simple(
          from: piece.position,
          to: targetPosition,
          piece: piece,
          capturedPiece: friendlyPiece,
        );

        // Don't add if already exists
        if (!expandedMoves.any(
          (m) => m.from == friendlyFireMove.from && m.to == friendlyFireMove.to,
        )) {
          expandedMoves.add(friendlyFireMove);
          printDebug(
            '🔥 FRIENDLY FIRE: ✅ Can capture friendly ${friendlyPiece.type.name} at ${targetPosition.algebraic}',
          );
        }
      } else {
        printDebug(
          '🔥 FRIENDLY FIRE: ❌ Cannot reach ${friendlyPiece.type.name} at ${targetPosition.algebraic}',
        );
      }
    }

    printDebug('🔥 FRIENDLY FIRE: Total moves: ${expandedMoves.length}');
    printDebug('🔥 FRIENDLY FIRE: === END FILTERING ===');
    return expandedMoves;
  }

  /// Checks if a piece can reach a target position based on its movement pattern
  bool _canPieceReach(
    ChessPiece piece,
    Position target,
    ChessBoard board,
    List<ChessMove> standardMoves,
  ) {
    // For pawns, check if target is in diagonal capture squares
    if (piece.type == PieceType.pawn) {
      final direction = piece.color == PieceColor.white ? 1 : -1;
      final captureRow = piece.position.row + direction;
      final captureColLeft = piece.position.col - 1;
      final captureColRight = piece.position.col + 1;

      return target.row == captureRow &&
          (target.col == captureColLeft || target.col == captureColRight);
    }

    // For other pieces, check if the target is in the same direction/pattern
    // as any of their standard moves
    final rowDiff = target.row - piece.position.row;
    final colDiff = target.col - piece.position.col;

    switch (piece.type) {
      case PieceType.knight:
        // Knight L-shape
        return (rowDiff.abs() == 2 && colDiff.abs() == 1) ||
            (rowDiff.abs() == 1 && colDiff.abs() == 2);

      case PieceType.bishop:
        // Diagonal
        if (rowDiff.abs() != colDiff.abs()) return false;
        return _isPathClear(piece.position, target, board);

      case PieceType.rook:
        // Straight line
        if (rowDiff != 0 && colDiff != 0) return false;
        return _isPathClear(piece.position, target, board);

      case PieceType.queen:
        // Diagonal or straight
        final isDiagonal = rowDiff.abs() == colDiff.abs();
        final isStraight = rowDiff == 0 || colDiff == 0;
        if (!isDiagonal && !isStraight) return false;
        return _isPathClear(piece.position, target, board);

      case PieceType.king:
        // One square in any direction
        return rowDiff.abs() <= 1 && colDiff.abs() <= 1;

      default:
        return false;
    }
  }

  /// Checks if the path between two positions is clear (for sliding pieces)
  bool _isPathClear(Position from, Position to, ChessBoard board) {
    final rowDirection = (to.row - from.row).sign;
    final colDirection = (to.col - from.col).sign;

    var currentRow = from.row + rowDirection;
    var currentCol = from.col + colDirection;

    while (currentRow != to.row || currentCol != to.col) {
      final pos = Position(currentRow, currentCol);
      if (board.getPieceAt(pos) != null) {
        return false; // Path blocked
      }
      currentRow += rowDirection;
      currentCol += colDirection;
    }

    return true;
  }

  @override
  ChessBoard? handleSpecialMove(ChessBoard board, ChessMove move) {
    // No special move handling needed for friendly fire
    return null;
  }

  @override
  GameStatus? updateGameStatus(
    ChessBoard board,
    bool currentPlayerInCheck,
    bool hasValidMoves,
  ) {
    // Use standard checkmate/stalemate logic
    // (Players still can't put themselves in check)
    return null;
  }

  @override
  List<String>? getPromotionPieces(
    PieceColor color,
    ChessBoard board, {
    Position? promotionPosition,
  }) {
    // Standard promotion pieces
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
}
