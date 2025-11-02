import 'package:chessrecast/debug.dart';
import '../board/exporter.dart';
import 'game_mode.dart';

/// HEIR MODE: Pawns can promote to King
///
/// Rules:
/// - Pawns can promote to King (in addition to Q, R, B, N)
/// - Each player can only promote to King once
/// - If a King is captured and the player has pawns, they can promote one to King
/// - If a King is captured and the player has no pawns, they lose immediately
/// - If the second (promoted) King is captured, the player loses immediately
/// - King promotion must not result in immediate check
class Heir extends GameMode {
  /// Checks if promoting a pawn to King would result in immediate check
  bool _wouldKingPromotionBeInCheck(
    PieceColor color,
    Position position,
    ChessBoard board,
  ) {
    final newPieces = List<ChessPiece>.from(board.pieces);

    newPieces.add(
      ChessPiece(type: PieceType.king, color: color, position: position),
    );

    final tempBoard = board.copyWith(pieces: newPieces);

    final wouldBeInCheck = tempBoard.isPositionUnderAttack(
      position,
      color.opposite,
    );

    printDebug(
      '🔍 KING PROMOTION CHECK: ${color.name} King at ${position.algebraic} would be ${wouldBeInCheck ? "IN CHECK" : "SAFE"}',
    );

    return wouldBeInCheck;
  }

  @override
  List<ChessMove>? getPawnMoves(ChessPiece pawn, ChessBoard board) {
    final moves = <ChessMove>[];
    final direction = pawn.color == PieceColor.white ? 1 : -1;
    final startRow = pawn.color == PieceColor.white ? 1 : 6;

    printDebug(
      '👑 HEIR PAWN: ${pawn.position.algebraic} - Standard pawn moves with King promotion option',
    );

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
          printDebug(
            '👑 HEIR PAWN promotion move: ${pawn.position.algebraic} → ${oneStep.algebraic} = $promotionPiece',
          );
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
              printDebug(
                '👑 HEIR PAWN promotion capture: ${pawn.position.algebraic} → ${capturePos.algebraic} = $promotionPiece',
              );
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
            printDebug(
              '🎯 En passant capture found! Attacking: ${pawn.position.algebraic} → ${capturePos.algebraic}',
            );
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
        // Check if King promotion would be safe
        if (promotionPosition != null &&
            _wouldKingPromotionBeInCheck(color, promotionPosition, board)) {
          printDebug(
            '👑 HEIR MODE: ${color.name} cannot promote to King - would be in check',
          );
          return [];
        }
        printDebug(
          '👑 HEIR MODE: ${color.name} has no king - can only promote to King',
        );
        return ['K'];
      }
    }

    // If player has a king, check if they can still promote to King
    final hasPromotedKing = color == PieceColor.white
        ? board.whiteHasPromotedKing
        : board.blackHasPromotedKing;

    if (!hasPromotedKing) {
      final availablePieces = ['Q', 'R', 'B', 'N'];
      if (promotionPosition == null ||
          !_wouldKingPromotionBeInCheck(color, promotionPosition, board)) {
        availablePieces.add('K');
      } else {
        printDebug(
          '👑 HEIR MODE: ${color.name} cannot promote to King - would be in check',
        );
      }
      return availablePieces;
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

    printDebug(
      '🔍 HEIR MODE: Checking game end for $color: ${kings.length} kings, ${pawns.length} pawns',
    );

    final hasPromotedKing = color == PieceColor.white
        ? board.whiteHasPromotedKing
        : board.blackHasPromotedKing;

    if (kings.isEmpty) {
      if (hasPromotedKing) {
        printDebug('🏁 HEIR MODE: Second king mated for $color - Game Over!');
        return true;
      } else if (pawns.isEmpty) {
        printDebug('🏁 HEIR MODE: First king mated and no pawns left - Game Over!');
        return true;
      } else {
        printDebug(
          '👑 HEIR MODE: First king mated but pawns available - continues!',
        );
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
        printDebug(
          '🏁 HEIR MODE: ${color.name} has no king and no pawns - Game Over!',
        );
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
        printDebug('🏁 HEIR MODE: Game ends for ${playerWhoLostKing.name}');
        return GameStatus.checkmate;
      } else {
        printDebug('👑 HEIR MODE: King mated but pawns available - continue');
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
