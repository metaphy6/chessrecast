import '../board/utils/exporter.dart';
import 'game_mode.dart';

/// HEIR MODE: Pawns can promote to King
///
/// Rules:
/// - Pawns can promote to King (in addition to Q, R, B, N)
/// - Each player can only promote to King once
/// - King is a REGULAR PIECE - no "check" concept, can be captured like any piece
/// - If a King is captured and the player has pawns, they can promote one to King
/// - If a King is captured and the player has no pawns, they lose immediately
/// - If the second (promoted) King is captured, the player loses immediately
class Heir extends GameMode {
  @Deprecated(
    'Use the `modes.heir` alias from modes_cache.dart instead of direct instantiation',
  )
  const Heir();

  @override
  List<ChessMove>? getPawnMoves(ChessPiece pawn, ChessBoard board) {
    final moves = <ChessMove>[];
    final direction = pawn.color == PieceColor.white ? 1 : -1;
    final startRow = pawn.color == PieceColor.white ? 1 : 6;

    // Forward move (one square)
    final oneStep = pawn.position.offset(direction, 0);
    if (oneStep.isValid && board.getPieceAt(oneStep) == null) {
      final lastRank = pawn.color == PieceColor.white ? 7 : 0;
      if (oneStep.row == lastRank) {
        // Add promotion moves
        final promotionPieces = getPromotionPieces(
          pawn.color,
          board,
          promotionPosition: oneStep,
        );
        for (final promotionPiece in promotionPieces!) {
          moves.add(
            ChessMove.promotion(
              from: pawn.position,
              to: oneStep,
              piece: pawn,
              promotionPiece: promotionPiece,
            ),
          );
        }
      } else {
        moves.add(
          ChessMove.simple(from: pawn.position, to: oneStep, piece: pawn),
        );
      }

      // Two-step move from starting position
      if (pawn.position.row == startRow) {
        final twoStep = pawn.position.offset(direction * 2, 0);
        if (twoStep.isValid && board.getPieceAt(twoStep) == null) {
          moves.add(
            ChessMove.simple(from: pawn.position, to: twoStep, piece: pawn),
          );
        }
      }
    }

    // Diagonal captures
    for (final colOffset in [-1, 1]) {
      final capturePos = pawn.position.offset(direction, colOffset);
      if (capturePos.isValid) {
        final targetPiece = board.getPieceAt(capturePos);
        if (targetPiece != null && targetPiece.color != pawn.color) {
          final lastRank = pawn.color == PieceColor.white ? 7 : 0;
          if (capturePos.row == lastRank) {
            // Add promotion captures
            final promotionPieces = getPromotionPieces(
              pawn.color,
              board,
              promotionPosition: capturePos,
            );
            for (final promotionPiece in promotionPieces!) {
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

        // En passant
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
    }

    return moves;
  }

  @override
  List<String>? getPromotionPieces(
    PieceColor color,
    ChessBoard board, {
    Position? promotionPosition,
  }) {
    // Check if player currently has a king
    final hasKing = board.getKing(color) != null;

    if (!hasKing) {
      final hasPromotedKing = color == PieceColor.white
          ? board.whiteHasPromotedKing
          : board.blackHasPromotedKing;

      if (!hasPromotedKing) {
        // King is captured - MUST promote to King (no check rules in Heir mode)
        return ['K'];
      }
    }

    // If player has a king, check if they can still promote to King
    final hasPromotedKing = color == PieceColor.white
        ? board.whiteHasPromotedKing
        : board.blackHasPromotedKing;

    if (!hasPromotedKing) {
      // Can promote to any piece including King (no check rules in Heir mode)
      return ['Q', 'R', 'B', 'N', 'K'];
    }

    return null; // Use standard promotions if already promoted a king
  }

  @override
  bool? isGameEnd(PieceColor color, ChessBoard board) {
    final kings = board.pieces
        .where((p) => p.type == PieceType.king && p.color == color)
        .toList();
    final pawns = board.pieces
        .where((p) => p.type == PieceType.pawn && p.color == color)
        .toList();

    final hasPromotedKing = color == PieceColor.white
        ? board.whiteHasPromotedKing
        : board.blackHasPromotedKing;

    if (kings.isEmpty) {
      if (hasPromotedKing) {
        return true;
      } else if (pawns.isEmpty) {
        return true;
      } else {
        return false;
      }
    }

    return false;
  }

  @override
  GameStatus? updateGameStatus(
    ChessBoard board,
    bool currentPlayerInCheck,
    bool hasValidMoves,
  ) {
    // Check for immediate game end (no king and no pawns)
    for (final color in [PieceColor.white, PieceColor.black]) {
      final kings = board.pieces
          .where((p) => p.type == PieceType.king && p.color == color)
          .toList();
      final pawns = board.pieces
          .where((p) => p.type == PieceType.pawn && p.color == color)
          .toList();

      if (kings.isEmpty && pawns.isEmpty) {
        return GameStatus.checkmate;
      }
    }

    // Handle checkmate with Heir mode rules
    if (currentPlayerInCheck && !hasValidMoves) {
      final playerWhoLostKing = board.currentPlayer;
      final hasPromotedKing = playerWhoLostKing == PieceColor.white
          ? board.whiteHasPromotedKing
          : board.blackHasPromotedKing;

      final pawns = board.pieces
          .where(
            (p) => p.type == PieceType.pawn && p.color == playerWhoLostKing,
          )
          .toList();

      if (hasPromotedKing || pawns.isEmpty) {
        return GameStatus.checkmate;
      } else {
        // Remove the king and let the game continue
        final king = board.getKing(board.currentPlayer);
        if (king != null) {
          // This will be handled by the controller
        }
        return GameStatus.ongoing;
      }
    }

    return null; // Use standard status logic
  }
}
