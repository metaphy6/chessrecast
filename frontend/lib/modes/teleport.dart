import '../board/utils/exporter.dart';
import '../debug.dart';
import 'game_mode.dart';

/// TELEPORT MODE: Kings and rooks can swap positions when aligned
///
/// Rules:
/// - Kings can teleport with friendly rooks on the same rank or file
/// - Teleport swaps the positions of king and rook instantly
/// - RESTRICTIONS (safe corridor):
///   1. King must NOT be under attack
///   2. Rook must NOT be under attack
///   3. No pieces between king and rook
///   4. No opponent piece attacking ANY square on the teleport line
/// - No castling is allowed in this mode
/// - All other pieces move normally
class Teleport extends GameMode {
  @Deprecated(
    'Use the `modes.teleport` alias from modes_cache.dart instead of direct instantiation',
  )
  const Teleport();

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

  /// Gets all squares between two positions (exclusive of endpoints)
  List<Position> _getSquaresBetween(Position from, Position to) {
    final squares = <Position>[];

    if (from.row == to.row) {
      // Same row - horizontal line
      final minCol = from.col < to.col ? from.col : to.col;
      final maxCol = from.col > to.col ? from.col : to.col;
      for (int col = minCol + 1; col < maxCol; col++) {
        squares.add(Position(from.row, col));
      }
    } else if (from.col == to.col) {
      // Same column - vertical line
      final minRow = from.row < to.row ? from.row : to.row;
      final maxRow = from.row > to.row ? from.row : to.row;
      for (int row = minRow + 1; row < maxRow; row++) {
        squares.add(Position(row, from.col));
      }
    }

    return squares;
  }

  /// Checks if teleport is legal (safe corridor exists)
  bool _isTeleportLegal(
    Position kingPos,
    Position rookPos,
    PieceColor color,
    ChessBoard board,
  ) {
    final opponentColor = color.opposite;

    // 1. King must NOT be under attack
    if (board.isPositionUnderAttack(kingPos, opponentColor)) {
      return false;
    }

    // 2. Rook must NOT be under attack
    if (board.isPositionUnderAttack(rookPos, opponentColor)) {
      return false;
    }

    // 3. No pieces between king and rook
    final squaresBetween = _getSquaresBetween(kingPos, rookPos);
    for (final square in squaresBetween) {
      if (board.getPieceAt(square) != null) {
        return false;
      }
    }

    // 4. No opponent piece attacking ANY square on the teleport line
    for (final square in squaresBetween) {
      if (board.isPositionUnderAttack(square, opponentColor)) {
        return false;
      }
    }

    return true;
  }

  @override
  List<ChessMove> filterMoves(
    List<ChessMove> moves,
    ChessPiece piece,
    ChessBoard board,
  ) {
    // Handle king teleport moves
    if (piece.type == PieceType.king) {
      final filteredMoves = <ChessMove>[...moves];

      // Add teleport moves with friendly rooks if safe corridor exists
      final friendlyRooks = getRooks(piece.color, board);
      for (final rook in friendlyRooks) {
        if (_areAligned(piece.position, rook.position) &&
            _isTeleportLegal(
              piece.position,
              rook.position,
              piece.color,
              board,
            )) {
          filteredMoves.add(
            ChessMove.simple(
              from: piece.position,
              to: rook.position,
              piece: piece,
            ),
          );
        }
      }

      return filteredMoves;
    }

    // Handle rook teleport moves
    if (piece.type == PieceType.rook) {
      // Get the friendly king position
      final king = board.getKing(piece.color);

      // Filter out any normal rook move that would "capture" the friendly king
      // (rooks can't capture friendly pieces, but we need to replace it with teleport)
      final filteredMoves = <ChessMove>[];
      for (final move in moves) {
        // Skip moves to the king's position - these will be replaced by teleport if legal
        if (king != null && move.to == king.position) {
          continue;
        }
        filteredMoves.add(move);
      }

      // Add teleport move with friendly king if safe corridor exists
      if (king != null &&
          _areAligned(piece.position, king.position) &&
          _isTeleportLegal(king.position, piece.position, piece.color, board)) {
        filteredMoves.add(
          ChessMove.simple(
            from: piece.position,
            to: king.position,
            piece: piece,
          ),
        );
      }

      return filteredMoves;
    }

    return moves; // Other pieces move normally
  }

  @override
  ChessBoard? handleSpecialMove(ChessBoard board, ChessMove move) {
    // Check if this is a king moving to a rook's position (teleport)
    if (move.piece.type == PieceType.king) {
      final targetPiece = board.getPieceAt(move.to);

      // Check if target is a friendly rook
      final isTargetFriendlyRook =
          (targetPiece != null &&
              targetPiece.type == PieceType.rook &&
              targetPiece.color == move.piece.color) ||
          (move.capturedPiece != null &&
              move.capturedPiece!.type == PieceType.rook &&
              move.capturedPiece!.color == move.piece.color);

      if (isTargetFriendlyRook) {
        final rookPiece = targetPiece!;

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

        final playerColor = move.piece.color == PieceColor.white
            ? 'White'
            : 'Black';
        final fromPos =
            '${String.fromCharCode(97 + move.from.col)}${8 - move.from.row}';
        final toPos =
            '${String.fromCharCode(97 + move.to.col)}${8 - move.to.row}';
        logTeleportSwap(playerColor, fromPos, toPos);

        return newBoard;
      }
    }

    // Check if this is a rook moving to a king's position (teleport)
    if (move.piece.type == PieceType.rook) {
      final targetPiece = board.getPieceAt(move.to);

      // Check if target is a friendly king
      final isTargetFriendlyKing =
          (targetPiece != null &&
              targetPiece.type == PieceType.king &&
              targetPiece.color == move.piece.color) ||
          (move.capturedPiece != null &&
              move.capturedPiece!.type == PieceType.king &&
              move.capturedPiece!.color == move.piece.color);

      if (isTargetFriendlyKing) {
        final kingPiece = targetPiece!;

        // Remove both pieces
        final newPieces = board.pieces.where((piece) {
          return piece.position != move.from && piece.position != move.to;
        }).toList();

        // Add rook at king's old position
        newPieces.add(move.piece.movedTo(move.to));

        // Add king at rook's old position
        newPieces.add(kingPiece.movedTo(move.from));

        final newBoard = board.copyWith(
          pieces: newPieces,
          currentPlayer: board.currentPlayer.opposite,
          moveHistory: [...board.moveHistory, move],
        );

        return newBoard;
      }
    }

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
