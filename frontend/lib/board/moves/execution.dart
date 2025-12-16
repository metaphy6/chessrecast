import '../items/piece_type.dart';
import '../items/piece_color.dart';
import '../game_status.dart';
import '../../modes/modes_enum.dart';
import '../piece.dart';
import 'move.dart';
import '../board.dart';
import 'helpers.dart';

/// Extension for move execution operations
extension MoveExecution on ChessBoard {
  /// Makes a move and returns a new board state (public method)
  ChessBoard makeMove(ChessMove move) {
    final newPieces = List<ChessPiece>.from(pieces);

    // Remove the moving piece from its current position
    newPieces.removeWhere((piece) => piece.position == move.from);

    // Remove captured piece if any
    if (move.capturedPiece != null) {
      if (move.isEnPassant) {
        // For en passant, remove the pawn that was captured
        newPieces.removeWhere((piece) => piece == move.capturedPiece);
      } else {
        newPieces.removeWhere((piece) => piece.position == move.to);
      }
    }

    // Add the piece to its new position
    if (move.isPromotion) {
      // Handle pawn promotion - create the promoted piece
      PieceType promotedType;
      switch (move.promotionPiece) {
        case 'Q':
          promotedType = PieceType.queen;
          break;
        case 'R':
          promotedType = PieceType.rook;
          break;
        case 'B':
          promotedType = PieceType.bishop;
          break;
        case 'N':
          promotedType = PieceType.knight;
          break;
        case 'K':
          promotedType = PieceType.king;
          break;
        default:
          promotedType = PieceType.queen; // Default fallback
      }

      newPieces.add(
        ChessPiece(
          type: promotedType,
          color: move.piece.color,
          position: move.to,
        ),
      );
    } else {
      // Regular move
      newPieces.add(move.piece.movedTo(move.to));
    }

    // Handle castling - move the rook as well using the helper
    if (move.isCastling) {
      performCastlingRookMove(newPieces, move.from, move.to);
    }

    // Determine en passant target for next turn
    final newEnPassantTarget = computeEnPassantTargetForMove(move);

    // Update castling rights based on piece movements
    final castling = computeNewCastlingRights(
      move,
      whiteCanCastleKingside,
      whiteCanCastleQueenside,
      blackCanCastleKingside,
      blackCanCastleQueenside,
    );

    final newWhiteCanCastleKingside = castling['whiteCanCastleKingside']!;
    final newWhiteCanCastleQueenside = castling['whiteCanCastleQueenside']!;
    final newBlackCanCastleKingside = castling['blackCanCastleKingside']!;
    final newBlackCanCastleQueenside = castling['blackCanCastleQueenside']!;

    // Track king promotions for Heir mode
    bool newWhiteHasPromotedKing = whiteHasPromotedKing;
    bool newBlackHasPromotedKing = blackHasPromotedKing;

    if (gameType == ModesEnum.heir &&
        move.isPromotion &&
        move.promotionPiece == 'K') {
      if (move.piece.color == PieceColor.white) {
        newWhiteHasPromotedKing = true;
      } else {
        newBlackHasPromotedKing = true;
      }
    }

    // Track queen escapes for Save the Queen mode
    Map<PieceColor, bool> newEscapedQueens = Map.from(escapedQueens);
    if (gameType == ModesEnum.saveTheQueen &&
        move.piece.type == PieceType.queen) {
      // Check if queen is currently in its own half
      // White's own half: rows 0-3 (rows 4-7 are black's)
      // Black's own half: rows 4-7 (rows 0-3 are white's)
      bool inOwnHalf =
          (move.piece.color == PieceColor.white && move.to.row <= 3) ||
          (move.piece.color == PieceColor.black && move.to.row >= 4);
      // Update escaped status based on current position
      newEscapedQueens[move.piece.color] = inOwnHalf;
    }

    // Update halfMoveClock for 50-move rule
    // Reset to 0 on pawn move or capture, otherwise increment
    // Exception: In Mercenary mode, pawn moves don't reset the counter
    final isPawnMove = move.piece.type == PieceType.pawn;
    final shouldResetClock =
        move.capturedPiece != null ||
        (isPawnMove && gameType != ModesEnum.mercenary);
    final newHalfMoveClock = shouldResetClock ? 0 : halfMoveClock + 1;

    // Update fullMoveNumber (increments after black's move)
    final newFullMoveNumber = currentPlayer == PieceColor.black
        ? fullMoveNumber + 1
        : fullMoveNumber;

    // Create the new board state first
    var newBoard = copyWith(
      pieces: newPieces,
      currentPlayer: currentPlayer.opposite,
      moveHistory: [...moveHistory, move],
      enPassantTarget: newEnPassantTarget, // Clear or set en passant target
      whiteCanCastleKingside: newWhiteCanCastleKingside,
      whiteCanCastleQueenside: newWhiteCanCastleQueenside,
      blackCanCastleKingside: newBlackCanCastleKingside,
      blackCanCastleQueenside: newBlackCanCastleQueenside,
      whiteHasPromotedKing: newWhiteHasPromotedKing,
      blackHasPromotedKing: newBlackHasPromotedKing,
      halfMoveClock: newHalfMoveClock,
      fullMoveNumber: newFullMoveNumber,
      escapedQueens: newEscapedQueens,
    );

    // Add the NEW position to history (after turn switch) for correct threefold repetition tracking
    newBoard = newBoard.copyWith(
      positionHistory: [...positionHistory, newBoard.getPositionKey()],
    );

    // Check for automatic draw conditions (50-move rule or threefold repetition)
    if (newBoard.shouldAutoDraw()) {
      return newBoard.copyWith(gameStatus: GameStatus.draw);
    }

    return newBoard;
  }
}
