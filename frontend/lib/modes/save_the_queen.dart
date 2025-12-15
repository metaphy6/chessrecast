import '../board/utils/exporter.dart';
import '../debug.dart';
import 'modes_enum.dart';
import 'game_mode.dart';

/// Save the Queen Mode: Queens start as prisoners and must escape to the other half
///
/// QUEEN STATES:
/// 1. PRISONER (in opponent's half, starting position):
///    - Moves like a king (one square in any direction)
///    - CANNOT capture or checkmate
///    - White queen starts at d8 (black's side)
///    - Black queen starts at d1 (white's side)
///
/// 2. ESCAPED (reached own half of board):
///    - Moves and captures like a regular queen
///    - Can checkmate
///    - If captured here = GAME OVER (instant win for capturer)
///
/// 3. RECAPTURED (captured while in prisoner state):
///    - Returns to initial position (d8 for white, d1 for black)
///    - Becomes prisoner again
///
/// SPECIAL RULES:
/// - If escaped queen moves back to opponent's half = becomes prisoner again
/// - Returns to initial position automatically
/// - Pawns CANNOT promote to Queen
/// - Regular checkmate still possible with other pieces
class SaveTheQueen implements GameMode {
  @Deprecated(
    'Use the `modes.saveTheQueen` alias from modes_cache.dart instead of direct instantiation',
  )
  const SaveTheQueen();
  // Initial queen positions (prisoners)
  static const Position whiteQueenPrison = Position(
    7,
    3,
  ); // d8 (black's back rank)
  static const Position blackQueenPrison = Position(
    0,
    3,
  ); // d1 (white's back rank)

  @override
  List<ChessMove> filterMoves(
    List<ChessMove> moves,
    ChessPiece piece,
    ChessBoard board,
  ) {
    if (piece.type == PieceType.queen) {
      // QUEENS CANNOT CAPTURE OTHER QUEENS in Save the Queen mode
      final filteredMoves = moves.where((move) {
        final targetPiece = board.getPieceAt(move.to);
        // Block any attempt to capture another queen
        if (targetPiece != null && targetPiece.type == PieceType.queen) {
          return false;
        }
        return true;
      }).toList();

      // Now apply queen movement rules (imprisoned vs escaped)
      final isInOwnHalf = _isInOwnHalf(piece.position, piece.color);

      if (isInOwnHalf) {
        // ESCAPED STATE: Queen has full queen power within own half,
        // but can only move like a king when crossing back to opponent's half
        final safeMoves = filteredMoves.where((move) {
          final targetInOwnHalf = _isInOwnHalf(move.to, piece.color);
          
          if (targetInOwnHalf) {
            // Target is in own half - allow full queen power
            return true;
          } else {
            // Target is in opponent's half - only allow king-like moves (becoming prisoner again)
            final rowDiff = (move.to.row - piece.position.row).abs();
            final colDiff = (move.to.col - piece.position.col).abs();
            // Only 1-square moves, no captures when crossing back
            return rowDiff <= 1 && colDiff <= 1 && move.capturedPiece == null;
          }
        }).toList();
        return safeMoves;
      } else {
        // PRISONER STATE: Queen moves like king, can't capture

        final prisonerMoves = <ChessMove>[];

        // Generate king-like moves (one square in any direction)
        for (int rowDelta = -1; rowDelta <= 1; rowDelta++) {
          for (int colDelta = -1; colDelta <= 1; colDelta++) {
            if (rowDelta == 0 && colDelta == 0) continue;

            final newRow = piece.position.row + rowDelta;
            final newCol = piece.position.col + colDelta;

            if (newRow < 0 || newRow > 7 || newCol < 0 || newCol > 7) continue;

            final targetPos = Position(newRow, newCol);
            final targetPiece = board.getPieceAt(targetPos);

            // Prisoner queen CANNOT capture
            if (targetPiece != null) {
              continue;
            }

            // Can only move to empty squares
            prisonerMoves.add(
              ChessMove.simple(
                from: piece.position,
                to: targetPos,
                piece: piece,
                capturedPiece: null,
              ),
            );
          }
        }

        return prisonerMoves;
      }
    } else {
      // Non-queen pieces
      // Filter out moves that would capture a queen on its prison square
      final filteredMoves = moves.where((move) {
        final targetPiece = board.getPieceAt(move.to);
        if (targetPiece != null && targetPiece.type == PieceType.queen) {
          // Check if the enemy queen is on its initial prison square
          final isOnPrisonSquare = _isInPrison(
            targetPiece.position,
            targetPiece.color,
          );
          if (isOnPrisonSquare) {
            // Cannot capture queen on prison square
            return false;
          }
        }
        return true;
      }).toList();

      return filteredMoves;
    }
  }

  @override
  ChessBoard? handleSpecialMove(ChessBoard board, ChessMove move) {
    // Check if escaped queen reached opponent's prison square = WIN!
    if (move.piece.type == PieceType.queen) {
      final isInOwnHalf = _isInOwnHalf(move.to, move.piece.color);

      // White queen reaching d1 (black's prison) or black queen reaching d8 (white's prison)
      final opponentPrison = move.piece.color == PieceColor.white
          ? blackQueenPrison // d1
          : whiteQueenPrison; // d8

      if (isInOwnHalf && move.to == opponentPrison) {
        final newBoard = board.makeMove(move);
        final winner = move.piece.color == PieceColor.white ? 'White' : 'Black';
        logSaveTheQueenEscape(winner);
        return newBoard.copyWith(gameStatus: GameStatus.checkmate);
      }
    }

    // Check if a queen was captured
    if (move.capturedPiece != null &&
        move.capturedPiece!.type == PieceType.queen) {
      final capturedQueen = move.capturedPiece!;
      final wasInOwnHalf = _isInOwnHalf(move.to, capturedQueen.color);

      if (wasInOwnHalf) {
        // CAPTURED ESCAPED QUEEN = GAME OVER!
        final newBoard = board.makeMove(move);
        final winner = move.piece.color == PieceColor.white ? 'White' : 'Black';
        logSaveTheQueenCapture(winner);
        return newBoard.copyWith(gameStatus: GameStatus.checkmate);
      } else {
        // CAPTURED PRISONER QUEEN = Return to prison (if prison is empty)

        // Check prison position
        final prisonPosition = capturedQueen.color == PieceColor.white
            ? whiteQueenPrison
            : blackQueenPrison;

        // Check if prison square is occupied
        final prisonOccupied = board.pieces.any(
          (p) => p.position == prisonPosition,
        );

        if (prisonOccupied) {
          // Prison is occupied - queen is captured permanently
          // Just execute the capture normally (queen disappears)
          final newBoard = board.makeMove(move);
          return newBoard;
        } else {
          // Prison is empty - return queen to prison

          // Execute the capture
          var newBoard = board.makeMove(move);

          // Return captured queen to prison
          final prisonedQueen = capturedQueen.copyWith(
            position: prisonPosition,
            hasMoved: false, // Reset movement state
          );

          final newPieces = newBoard.pieces.toList();
          newPieces.add(prisonedQueen);

          newBoard = newBoard.copyWith(pieces: newPieces);

          return newBoard;
        }
      }
    }

    return null; // Use standard handling
  }

  @override
  GameStatus? updateGameStatus(
    ChessBoard board,
    bool currentPlayerInCheck,
    bool hasValidMoves,
  ) {
    // Standard checkmate/stalemate logic applies
    return null;
  }

  @override
  List<String>? getPromotionPieces(
    PieceColor color,
    ChessBoard board, {
    Position? promotionPosition,
  }) {
    // NO QUEEN PROMOTION!
    return ['R', 'B', 'N']; // Rook, Bishop, Knight only
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

  /// Helper methods

  /// Checks if a position is in the piece's own half of the board
  bool _isInOwnHalf(Position pos, PieceColor color) {
    if (color == PieceColor.white) {
      return pos.row <= 3; // Rows 0-3 (ranks 1-4) are white's half
    } else {
      return pos.row >= 4; // Rows 4-7 (ranks 5-8) are black's half
    }
  }

  /// Checks if queen is at its prison position
  bool _isInPrison(Position pos, PieceColor color) {
    final prisonPos = color == PieceColor.white
        ? whiteQueenPrison
        : blackQueenPrison;
    return pos == prisonPos;
  }

  /// Gets the initial board setup for Save the Queen mode
  static ChessBoard getInitialBoard() {
    // This will need to be called from board initialization
    // Queens start at opponent's side:
    // White queen at d8 (7, 3)
    // Black queen at d1 (0, 3)

    // Note: This might need special handling in board setup
    return ChessBoard.initial(gameType: ModesEnum.saveTheQueen);
  }
}
