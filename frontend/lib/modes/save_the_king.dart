import '../board/utils/exporter.dart';
import '../debug.dart';
import 'game_mode.dart';
import 'modes_enum.dart';

/// Save the King Mode: Race to promote a pawn to King!
///
/// SETUP:
/// - Each side starts with TWO queens (no king initially)
/// - Normal pawn setup (8 pawns each)
/// - All other pieces as normal
///
/// RULES:
/// 1. First player to promote a pawn to King wins immediately
/// 2. Can promote to any piece (not King) during the game
/// 3. Your LAST pawn must promote to King (no choice)
/// 4. Cannot promote to King if the promotion square is under attack
/// 5. Lose immediately if:
///    - Any of your queens are captured
///    - You run out of pawns (no way to promote to King)
/// 6. Draw if 50 moves (25 per side) with no captures or pawn moves
///
/// STARTING POSITION:
/// White: Two queens on d1 and e1
/// Black: Two queens on d8 and e8
class SaveTheKing extends GameMode {
  @Deprecated(
    'Use the `modes.saveTheKing` alias from modes_cache.dart instead of direct instantiation',
  )
  const SaveTheKing();
  // Track halfmoves for 50-move draw rule (static to persist across instances)
  static int _halfmoveClock = 0;

  @override
  ChessBoard? handleSpecialMove(ChessBoard board, ChessMove move) {
    // Update halfmove clock
    if (move.capturedPiece != null || move.piece.type == PieceType.pawn) {
      _halfmoveClock = 0;
    } else {
      _halfmoveClock++;
    }

    // Check if a queen was captured - instant loss for the player who lost the queen
    if (move.capturedPiece != null &&
        move.capturedPiece!.type == PieceType.queen) {
      // Opponent wins by checkmate
      final newBoard = board.makeMove(move);
      return newBoard.copyWith(gameStatus: GameStatus.checkmate);
    }

    // Check for promotion to King
    if (move.isPromotion && move.promotionPiece == 'K') {
      final movingColor = move.piece.color;
      final opponentColor = movingColor.opposite;
      final promotionSquare = move.to;

      // Cannot promote to King if square is under attack
      if (board.isPositionUnderAttack(promotionSquare, opponentColor)) {
        // This shouldn't happen (filtered out), but handle gracefully
        return null;
      }

      // VICTORY! Successfully promoted to King
      final newBoard = board.makeMove(move);
      final winner = movingColor == PieceColor.white ? 'White' : 'Black';
      final position =
          '${String.fromCharCode(97 + move.to.col)}${8 - move.to.row}';
      logSaveTheKingPromotion(winner, position);
      return newBoard.copyWith(gameStatus: GameStatus.checkmate);
    }

    return null; // Normal processing
  }

  @override
  List<String>? getPromotionPieces(
    PieceColor color,
    ChessBoard board, {
    Position? promotionPosition,
  }) {
    if (promotionPosition == null) return null;

    final opponentColor = color.opposite;

    // Count remaining pawns for this color
    final remainingPawns = board.pieces
        .where((p) => p.color == color && p.type == PieceType.pawn)
        .length;

    final isLastPawn = remainingPawns == 1;

    // Check if promotion square is under attack
    final squareUnderAttack = board.isPositionUnderAttack(
      promotionPosition,
      opponentColor,
    );

    if (isLastPawn) {
      // Last pawn MUST promote to King
      if (squareUnderAttack) {
        // Can't promote to King on attacked square
        // Game is lost - return empty list
        return [];
      }
      // Force King promotion
      return ['K']; // King
    }

    // Not the last pawn - can promote to any piece
    final options = ['Q', 'R', 'B', 'N']; // Queen, Rook, Bishop, Knight

    // Can also promote to King if square is safe
    if (!squareUnderAttack) {
      options.add('K'); // King
    }

    return options;
  }

  @override
  GameStatus? updateGameStatus(
    ChessBoard board,
    bool currentPlayerInCheck,
    bool hasValidMoves,
  ) {
    final currentColor = board.currentPlayer;

    // Check if current player has lost all queens
    final currentQueens = board.pieces
        .where((p) => p.color == currentColor && p.type == PieceType.queen)
        .length;

    if (currentQueens == 0) {
      // Lost all queens - opponent wins
      return GameStatus.checkmate;
    }

    // Check if current player has run out of pawns
    final currentPawns = board.pieces
        .where((p) => p.color == currentColor && p.type == PieceType.pawn)
        .length;

    if (currentPawns == 0) {
      // No pawns left, can't promote to King - opponent wins
      return GameStatus.checkmate;
    }

    // Check for 50-move draw (25 moves per side)
    if (_halfmoveClock >= 50) {
      return GameStatus.draw;
    }

    // Check for stalemate
    if (!hasValidMoves && !currentPlayerInCheck) {
      return GameStatus.draw;
    }

    return null; // Use default status logic
  }

  /// Creates the initial board for Save the King mode
  static ChessBoard getInitialBoard() {
    final pieces = <ChessPiece>[];

    // White pieces (back rank) - TWO QUEENS
    pieces.add(
      ChessPiece(
        type: PieceType.rook,
        color: PieceColor.white,
        position: Position.fromAlgebraic('a1'),
      ),
    );
    pieces.add(
      ChessPiece(
        type: PieceType.knight,
        color: PieceColor.white,
        position: Position.fromAlgebraic('b1'),
      ),
    );
    pieces.add(
      ChessPiece(
        type: PieceType.bishop,
        color: PieceColor.white,
        position: Position.fromAlgebraic('c1'),
      ),
    );
    pieces.add(
      ChessPiece(
        type: PieceType.queen,
        color: PieceColor.white,
        position: Position.fromAlgebraic('d1'),
      ),
    ); // Queen 1
    pieces.add(
      ChessPiece(
        type: PieceType.queen,
        color: PieceColor.white,
        position: Position.fromAlgebraic('e1'),
      ),
    ); // Queen 2
    pieces.add(
      ChessPiece(
        type: PieceType.bishop,
        color: PieceColor.white,
        position: Position.fromAlgebraic('f1'),
      ),
    );
    pieces.add(
      ChessPiece(
        type: PieceType.knight,
        color: PieceColor.white,
        position: Position.fromAlgebraic('g1'),
      ),
    );
    pieces.add(
      ChessPiece(
        type: PieceType.rook,
        color: PieceColor.white,
        position: Position.fromAlgebraic('h1'),
      ),
    );

    // White pawns (rank 2)
    for (int file = 0; file < 8; file++) {
      pieces.add(
        ChessPiece(
          type: PieceType.pawn,
          color: PieceColor.white,
          position: Position(1, file), // row 1 = rank 2
        ),
      );
    }

    // Black pieces (back rank) - TWO QUEENS
    pieces.add(
      ChessPiece(
        type: PieceType.rook,
        color: PieceColor.black,
        position: Position.fromAlgebraic('a8'),
      ),
    );
    pieces.add(
      ChessPiece(
        type: PieceType.knight,
        color: PieceColor.black,
        position: Position.fromAlgebraic('b8'),
      ),
    );
    pieces.add(
      ChessPiece(
        type: PieceType.bishop,
        color: PieceColor.black,
        position: Position.fromAlgebraic('c8'),
      ),
    );
    pieces.add(
      ChessPiece(
        type: PieceType.queen,
        color: PieceColor.black,
        position: Position.fromAlgebraic('d8'),
      ),
    ); // Queen 1
    pieces.add(
      ChessPiece(
        type: PieceType.queen,
        color: PieceColor.black,
        position: Position.fromAlgebraic('e8'),
      ),
    ); // Queen 2
    pieces.add(
      ChessPiece(
        type: PieceType.bishop,
        color: PieceColor.black,
        position: Position.fromAlgebraic('f8'),
      ),
    );
    pieces.add(
      ChessPiece(
        type: PieceType.knight,
        color: PieceColor.black,
        position: Position.fromAlgebraic('g8'),
      ),
    );
    pieces.add(
      ChessPiece(
        type: PieceType.rook,
        color: PieceColor.black,
        position: Position.fromAlgebraic('h8'),
      ),
    );

    // Black pawns (rank 7)
    for (int file = 0; file < 8; file++) {
      pieces.add(
        ChessPiece(
          type: PieceType.pawn,
          color: PieceColor.black,
          position: Position(6, file), // row 6 = rank 7
        ),
      );
    }

    // Reset halfmove clock
    _halfmoveClock = 0;

    return ChessBoard(
      pieces: pieces,
      currentPlayer: PieceColor.white,
      gameStatus: GameStatus.ongoing,
      gameType: ModesEnum.saveTheKing,
    );
  }
}
