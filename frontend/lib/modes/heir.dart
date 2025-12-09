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
  List<ChessMove>? getKingMoves(ChessPiece king, ChessBoard board) {
    // In Heir mode, kings follow classic chess rules with each other:
    // - Kings can NEVER capture each other
    // - Kings can NEVER be adjacent to each other
    final moves = <ChessMove>[];
    final offsets = [
      [-1, -1],
      [-1, 0],
      [-1, 1],
      [0, -1],
      [0, 1],
      [1, -1],
      [1, 0],
      [1, 1],
    ];

    for (final offset in offsets) {
      final newPos = king.position.offset(offset[0], offset[1]);
      if (!newPos.isValid) continue;

      final targetPiece = board.getPieceAt(newPos);

      // Can't capture opponent king
      if (targetPiece != null && targetPiece.type == PieceType.king) {
        continue; // Skip this move
      }

      // Can't move adjacent to opponent king
      if (_isKingAdjacentToSquare(newPos, king.color.opposite, board)) {
        continue; // Skip - would be adjacent to opponent king
      }

      if (targetPiece == null) {
        // Empty square
        moves.add(
          ChessMove.simple(from: king.position, to: newPos, piece: king),
        );
      } else if (targetPiece.color != king.color) {
        // Enemy piece (but not king)
        moves.add(
          ChessMove.simple(
            from: king.position,
            to: newPos,
            piece: king,
            capturedPiece: targetPiece,
          ),
        );
      }
    }

    return moves;
  }

  /// Helper to check if opponent king is adjacent to a given square
  bool _isKingAdjacentToSquare(
    Position pos,
    PieceColor kingColor,
    ChessBoard board,
  ) {
    final opponentKing = board.getKing(kingColor);
    if (opponentKing == null) return false;

    final rowDiff = (opponentKing.position.row - pos.row).abs();
    final colDiff = (opponentKing.position.col - pos.col).abs();

    // Kings are adjacent if within 1 square (but not same square)
    return rowDiff <= 1 && colDiff <= 1 && (rowDiff != 0 || colDiff != 0);
  }

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
    final hasPromotedKing = color == PieceColor.white
        ? board.whiteHasPromotedKing
        : board.blackHasPromotedKing;

    // Check if promotion square is under attack by opponent
    // This matters for King promotion since the promoted King becomes the "last" king
    // and classic chess check rules apply
    bool canPromoteToKing = !hasPromotedKing;
    if (canPromoteToKing && promotionPosition != null) {
      final isUnderAttack = board.isPositionUnderAttack(
        promotionPosition,
        color.opposite,
      );
      if (isUnderAttack) {
        canPromoteToKing = false; // Can't promote to King into check
      }
    }

    if (!hasKing && !hasPromotedKing) {
      // King is captured - MUST promote to King
      if (canPromoteToKing) {
        return ['K']; // Only King promotion allowed
      }
      // If can't promote to King (square under attack), NO promotion is legal
      // This will effectively block this pawn from promoting on this square
      // Player must find a different pawn or clear the attack on this square
      return []; // Empty list = no valid promotions
    }

    if (canPromoteToKing) {
      // Can promote to any piece including King
      return ['Q', 'R', 'B', 'N', 'K'];
    }

    return null; // Use standard promotions if already promoted a king or can't promote to king
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
        return true; // Second king lost
      } else if (pawns.isEmpty) {
        return true; // No king and no pawns to promote
      } else {
        return false; // Can still promote a pawn to king
      }
    }

    return false;
  }

  /// In Heir mode, check rules apply if:
  /// 1. Player has promoted a king (no more replacements), OR
  /// 2. Player has no pawns left (can't get a replacement king)
  bool shouldApplyCheckRules(PieceColor color, ChessBoard board) {
    final hasPromotedKing = color == PieceColor.white
        ? board.whiteHasPromotedKing
        : board.blackHasPromotedKing;

    if (hasPromotedKing) {
      return true; // Promoted king → check rules apply
    }

    final pawns = board.pieces
        .where((p) => p.type == PieceType.pawn && p.color == color)
        .toList();

    if (pawns.isEmpty) {
      return true; // No pawns → can't get replacement king → check rules apply
    }

    return false; // Has pawns and hasn't promoted → king is regular piece
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
