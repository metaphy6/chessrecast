import '../board/exporter.dart';
import 'game_mode.dart';

/// DIAMONDS MODE: Bishops move diagonally but capture in diamond patterns
///
/// Rules:
/// - Bishops move diagonally as in classical chess (any number of squares)
/// - Bishops can ONLY capture in a diamond pattern around them
/// - Diamond pattern = 8 squares adjacent to the bishop (1 square in each direction)
/// - For bishop at d4: Can capture at c3, d2, e3, f4, e5, d6, c5, b4
/// - Near board edges, the diamond may be incomplete
/// - Pawns can ONLY promote to Bishops
class Diamonds extends GameMode {
  /// Gets all bishops of the specified color
  List<ChessPiece> getBishops(PieceColor color, ChessBoard board) {
    return board.pieces
        .where(
          (piece) => piece.type == PieceType.bishop && piece.color == color,
        )
        .toList();
  }

  /// Gets the diamond capture pattern positions for a bishop
  /// Returns up to 8 positions forming a diamond around the bishop
  /// Pattern: 4 diagonal adjacent squares + 4 orthogonal squares 2 away
  List<Position> _getDiamondCapturePositions(Position bishopPos) {
    final capturePositions = <Position>[];

    // Diamond pattern:
    // - 4 diagonal squares (1 square diagonally)
    // - 4 orthogonal squares (2 squares straight)
    final offsets = [
      // Diagonal adjacent (1 square away diagonally)
      [-1, -1], // top-left diagonal
      [-1, 1], // top-right diagonal
      [1, -1], // bottom-left diagonal
      [1, 1], // bottom-right diagonal
      // Orthogonal 2 squares away
      [-2, 0], // 2 up
      [0, 2], // 2 right
      [2, 0], // 2 down
      [0, -2], // 2 left
    ];

    for (final offset in offsets) {
      final pos = bishopPos.offset(offset[0], offset[1]);
      if (pos.isValid) {
        capturePositions.add(pos);
      }
    }

    print(
      '💎 DIAMONDS: Bishop at ${bishopPos.algebraic} diamond capture zone: ${capturePositions.map((p) => p.algebraic).join(", ")}',
    );

    return capturePositions;
  }

  @override
  List<String>? getPromotionPieces(
    PieceColor color,
    ChessBoard board, {
    Position? promotionPosition,
  }) {
    print('💎 DIAMONDS: Pawn promotion - ONLY Bishop allowed');
    return ['B']; // Only allow bishop promotion
  }

  @override
  List<ChessMove> filterMoves(
    List<ChessMove> moves,
    ChessPiece piece,
    ChessBoard board,
  ) {
    // Only modify bishop moves
    if (piece.type != PieceType.bishop) {
      return moves; // Other pieces move normally
    }

    print('💎 DIAMONDS: === FILTERING BISHOP MOVES ===');
    print(
      '💎 DIAMONDS: Bishop: ${piece.color.name} at ${piece.position.algebraic}',
    );
    print('💎 DIAMONDS: Input moves count: ${moves.length}');

    final filteredMoves = <ChessMove>[];

    // Step 1: Keep all non-capture diagonal moves
    for (final move in moves) {
      if (move.capturedPiece == null) {
        // Non-capture diagonal move - allowed
        print(
          '💎 DIAMONDS: MOVE to ${move.to.algebraic} - ✓ ALLOWED (no capture)',
        );
        filteredMoves.add(move);
      }
    }

    // Step 2: Add diamond pattern captures
    final diamondZone = _getDiamondCapturePositions(piece.position);
    for (final capturePos in diamondZone) {
      final targetPiece = board.getPieceAt(capturePos);
      if (targetPiece != null && targetPiece.color != piece.color) {
        // Enemy piece in diamond zone - add capture move
        print(
          '💎 DIAMONDS: CAPTURE to ${capturePos.algebraic} - ✓ ALLOWED (in diamond)',
        );
        filteredMoves.add(
          ChessMove.simple(
            from: piece.position,
            to: capturePos,
            piece: piece,
            capturedPiece: targetPiece,
          ),
        );
      }
    }

    print('💎 DIAMONDS: Output moves count: ${filteredMoves.length}');
    print('💎 DIAMONDS: === END FILTERING ===');

    return filteredMoves;
  }

  @override
  GameStatus? updateGameStatus(
    ChessBoard board,
    bool currentPlayerInCheck,
    bool hasValidMoves,
  ) {
    // Diamonds mode uses standard chess rules for game status
    return null;
  }

  @override
  ChessBoard? handleSpecialMove(ChessBoard board, ChessMove move) {
    // No special move handling needed for Diamonds mode
    return null;
  }
}
