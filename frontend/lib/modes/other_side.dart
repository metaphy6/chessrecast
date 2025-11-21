import 'package:chessrecast/debug.dart';
import '../board/utils/exporter.dart';
import 'game_mode.dart';

/// OTHER SIDE MODE: Race your rook to the opponent's back rank!
///
/// WIN CONDITIONS:
/// - Your rook reaches the opponent's back rank (rank 8 for white, rank 1 for black)
/// - You checkmate the opponent's king
/// - You capture an opponent's rook (instant win)
///
/// SPECIAL RULES:
/// 1. Pawns move normally (forward only, like classic chess)
/// 2. Pawns cannot promote to rooks (only queen, bishop, knight)
/// 3. Losing a rook results in immediate game loss
/// 4. Rooks can only capture opponent rooks (cannot capture other pieces)
class OtherSide extends GameMode {
  @Deprecated(
    'Use the `modes.otherSide` alias from modes_cache.dart instead of direct instantiation',
  )
  const OtherSide();
  @override
  ChessBoard? handleSpecialMove(ChessBoard board, ChessMove move) {
    printDebug(
      '🏰 OTHER SIDE: handleSpecialMove called for ${move.piece.color.name} ${move.piece.type.name} ${move.from.algebraic}->${move.to.algebraic}',
    );
    // Check if a rook was captured - instant loss for the player who lost it
    if (move.capturedPiece != null &&
        move.capturedPiece!.type == PieceType.rook) {
      printDebug('🏰 OTHER SIDE: Rook captured! Opponent wins!');
      // Opponent wins by checkmate
      final newBoard = board.makeMove(move);
      return newBoard.copyWith(gameStatus: GameStatus.checkmate);
    }

    // Check if a rook reached the opponent's back rank
    if (move.piece.type == PieceType.rook) {
      final movingColor = move.piece.color;
      final targetRank = movingColor == PieceColor.white ? 7 : 0; // Rank 8 or 1

      if (move.to.row == targetRank) {
        printDebug(
          '🏰 OTHER SIDE: Rook reached the back rank! ${movingColor.name} wins!',
        );
        final newBoard = board.makeMove(move);
        return newBoard.copyWith(gameStatus: GameStatus.checkmate);
      }
    }

    return null; // No special handling, continue with normal move
  }

  @override
  List<ChessMove>? getPawnMoves(ChessPiece pawn, ChessBoard board) {
    printDebugVerbose(
      '♟️ OTHER SIDE: getPawnMoves called for ${pawn.color.name} pawn at ${pawn.position.algebraic}',
    );
    final moves = <ChessMove>[];
    final forwardDirection = pawn.color == PieceColor.white ? 1 : -1;
    final startRow = pawn.color == PieceColor.white ? 1 : 6;
    final lastRank = pawn.color == PieceColor.white ? 7 : 0;

    printDebug(
      '♟️ OTHER SIDE PAWN: ${pawn.position.algebraic} moves forward only (like classic chess)',
    );

    // One square forward
    final oneForward = pawn.position.offset(forwardDirection, 0);
    if (oneForward.isValid) {
      final targetPiece = board.getPieceAt(oneForward);
      if (targetPiece == null) {
        // Check for promotion
        if (oneForward.row == lastRank) {
          // Add promotion moves
          for (final promotionPiece in board.getPromotionPieces(
            pawn.color,
            promotionPosition: oneForward,
          )) {
            moves.add(
              ChessMove.promotion(
                from: pawn.position,
                to: oneForward,
                piece: pawn,
                promotionPiece: promotionPiece,
              ),
            );
          }
        } else {
          moves.add(
            ChessMove.simple(from: pawn.position, to: oneForward, piece: pawn),
          );
        }
      }
    }

    // Two squares forward from starting position
    if (pawn.position.row == startRow) {
      final twoForward = pawn.position.offset(forwardDirection * 2, 0);
      if (twoForward.isValid && board.getPieceAt(twoForward) == null) {
        final oneForwardCheck = pawn.position.offset(forwardDirection, 0);
        if (board.getPieceAt(oneForwardCheck) == null) {
          moves.add(
            ChessMove.simple(from: pawn.position, to: twoForward, piece: pawn),
          );
        }
      }
    }

    // Diagonal captures (forward only)
    for (final colOffset in [-1, 1]) {
      final capturePos = pawn.position.offset(forwardDirection, colOffset);
      if (!capturePos.isValid) continue;

      final targetPiece = board.getPieceAt(capturePos);
      if (targetPiece != null && targetPiece.color != pawn.color) {
        // Check for promotion
        if (capturePos.row == lastRank) {
          // Add promotion captures
          for (final promotionPiece in board.getPromotionPieces(
            pawn.color,
            promotionPosition: capturePos,
          )) {
            moves.add(
              ChessMove.promotion(
                from: pawn.position,
                to: capturePos,
                piece: pawn,
                capturedPiece: targetPiece,
                promotionPiece: promotionPiece,
              ),
            );
          }
        } else {
          moves.add(
            ChessMove.simple(
              from: pawn.position,
              to: capturePos,
              piece: pawn,
              capturedPiece: targetPiece,
            ),
          );
        }
      }

      // En passant (forward direction only)
      if (capturePos == board.enPassantTarget) {
        final capturedPawn = board.getPieceAt(
          Position(pawn.position.row, capturePos.col),
        );
        if (capturedPawn != null && capturedPawn.type == PieceType.pawn) {
          moves.add(
            ChessMove.enPassant(
              from: pawn.position,
              to: capturePos,
              piece: pawn,
              capturedPiece: capturedPawn,
            ),
          );
        }
      }
    }

    return moves;
  }

  @override
  List<String>? getPromotionPieces(
    PieceColor color,
    ChessBoard board, {
    Position? promotionPosition,
  }) {
    // Disable promotion to rook in Other Side mode
    // Only allow promotion to queen, bishop, and knight
    printDebug('♟️ OTHER SIDE: Pawn promotion - rook promotion disabled');
    return ['q', 'b', 'n'];
  }

  @override
  List<ChessMove> filterMoves(
    List<ChessMove> moves,
    ChessPiece piece,
    ChessBoard board,
  ) {
    printDebug(
      '🏰 OTHER SIDE: filterMoves called for ${piece.color.name} ${piece.type.name} at ${piece.position.algebraic}',
    );
    // Only filter rook moves - rooks can only capture opponent rooks
    if (piece.type != PieceType.rook) {
      return moves; // Other pieces use standard rules
    }

    printDebug(
      '🏰 OTHER SIDE: Filtering rook moves - can only capture opponent rooks',
    );

    // Filter out moves where rook captures non-rook pieces
    return moves.where((move) {
      if (move.capturedPiece == null) {
        // Can move to empty squares
        return true;
      }

      // Can only capture opponent rooks
      final canCapture =
          move.capturedPiece!.type == PieceType.rook &&
          move.capturedPiece!.color != piece.color;

      if (!canCapture) {
        printDebug(
          '🏰 OTHER SIDE: Blocking rook capture of ${move.capturedPiece!.type.name} at ${move.to.algebraic}',
        );
      }

      return canCapture;
    }).toList();
  }
}
