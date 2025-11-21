import 'package:chessrecast/debug.dart';
import '../board/utils/exporter.dart';
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
    if (piece.type != PieceType.queen) {
      printDebug(
        '👸 SAVE QUEEN: ${piece.color.name} ${piece.type.name} at ${piece.position.algebraic} - passing through ${moves.length} moves',
      );

      // Filter out moves that would capture a prisoner queen on its initial prison square
      // OR capture a prisoner queen when its prison square is occupied
      final filteredMoves = moves.where((move) {
        final targetPiece = board.getPieceAt(move.to);
        if (targetPiece != null && targetPiece.type == PieceType.queen) {
          // Check if the enemy queen is still on its initial prison square
          final isOnPrisonSquare = _isInPrison(
            targetPiece.position,
            targetPiece.color,
          );
          if (isOnPrisonSquare) {
            printDebug(
              '👸 SAVE QUEEN: ❌ Cannot capture ${targetPiece.color.name} queen at ${targetPiece.position.algebraic} - still in prison',
            );
            return false; // Cannot capture queen on prison square
          }

          // Check if queen is prisoner (in opponent's half) and its prison square is occupied
          final queenInOwnHalf = _isInOwnHalf(
            targetPiece.position,
            targetPiece.color,
          );
          if (!queenInOwnHalf) {
            // Queen is a prisoner, check if prison square is occupied
            final prisonPosition = targetPiece.color == PieceColor.white
                ? whiteQueenPrison
                : blackQueenPrison;
            final prisonOccupied = board.pieces.any(
              (p) => p.position == prisonPosition,
            );

            if (prisonOccupied) {
              printDebug(
                '👸 SAVE QUEEN: ❌ Cannot capture ${targetPiece.color.name} prisoner queen at ${targetPiece.position.algebraic} - prison square ${prisonPosition.algebraic} is occupied',
              );
              return false; // Cannot capture prisoner queen if prison is occupied
            }
          }
        }
        return true;
      }).toList();

      return filteredMoves;
    }

    printDebug('👸 SAVE QUEEN: === FILTERING QUEEN MOVES ===');
    printDebug(
      '👸 SAVE QUEEN: ${piece.color.name} queen at ${piece.position.algebraic}',
    );

    final isInOwnHalf = _isInOwnHalf(piece.position, piece.color);
    final isInPrison = _isInPrison(piece.position, piece.color);

    printDebug(
      '👸 SAVE QUEEN: In own half: $isInOwnHalf, In prison: $isInPrison',
    );

    if (isInOwnHalf) {
      // ESCAPED STATE: Queen can move and capture like normal
      printDebug('👸 SAVE QUEEN: ✅ Queen is ESCAPED - full queen moves');

      // Filter out moves that would return queen to opponent's half
      final safeMoves = moves.where((move) {
        final targetInOwnHalf = _isInOwnHalf(move.to, piece.color);
        if (!targetInOwnHalf) {
          printDebug(
            '👸 SAVE QUEEN: ⚠️ Move to ${move.to.algebraic} would return to prison',
          );
        }
        return targetInOwnHalf;
      }).toList();

      printDebug(
        '👸 SAVE QUEEN: Safe moves (staying in own half): ${safeMoves.length}',
      );
      return safeMoves;
    } else {
      // PRISONER STATE: Queen moves like king, can't capture
      printDebug(
        '👸 SAVE QUEEN: 🔒 Queen is PRISONER - limited to king moves, no captures',
      );

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
            printDebug(
              '👸 SAVE QUEEN: ❌ Cannot capture ${targetPiece.type.name} at ${targetPos.algebraic} (prisoner)',
            );
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

          printDebug('👸 SAVE QUEEN: ✅ Can move to ${targetPos.algebraic}');
        }
      }

      printDebug(
        '👸 SAVE QUEEN: Total prisoner moves: ${prisonerMoves.length}',
      );
      return prisonerMoves;
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

      printDebug(
        '👸 SAVE QUEEN: Checking win condition for ${move.piece.color.name} queen',
      );
      printDebug(
        '👸 SAVE QUEEN: Moving to ${move.to.algebraic} (row ${move.to.row}, col ${move.to.col})',
      );
      printDebug(
        '👸 SAVE QUEEN: Opponent prison: ${opponentPrison.algebraic} (row ${opponentPrison.row}, col ${opponentPrison.col})',
      );
      printDebug('👸 SAVE QUEEN: Is in own half: $isInOwnHalf');
      printDebug(
        '👸 SAVE QUEEN: Positions match: ${move.to == opponentPrison}',
      );

      if (isInOwnHalf && move.to == opponentPrison) {
        printDebug(
          '👸 SAVE QUEEN: 🏆 ESCAPED QUEEN REACHED OPPONENT PRISON! ${move.piece.color.name.toUpperCase()} WINS!',
        );

        final newBoard = board.makeMove(move);
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
        printDebug(
          '👸 SAVE QUEEN: ⚔️ ESCAPED QUEEN CAPTURED! ${move.piece.color.name} WINS!',
        );

        final newBoard = board.makeMove(move);
        return newBoard.copyWith(gameStatus: GameStatus.checkmate);
      } else {
        // CAPTURED PRISONER QUEEN = Return to prison (if prison is empty)
        printDebug(
          '👸 SAVE QUEEN: 🔒 Prisoner queen captured, checking if can return to prison',
        );

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
          printDebug(
            '👸 SAVE QUEEN: ❌ Prison square ${prisonPosition.algebraic} is occupied - queen captured permanently!',
          );

          // Just execute the capture normally (queen disappears)
          final newBoard = board.makeMove(move);
          return newBoard;
        } else {
          // Prison is empty - return queen to prison
          printDebug(
            '👸 SAVE QUEEN: ✅ Prison square is empty - returning queen to prison',
          );

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

          printDebug(
            '👸 SAVE QUEEN: Queen returned to prison at ${prisonPosition.algebraic}',
          );
          return newBoard;
        }
      }
    }

    // Check if queen moved back to opponent's half (becomes prisoner)
    if (move.piece.type == PieceType.queen) {
      final wasInOwnHalf = _isInOwnHalf(move.from, move.piece.color);
      final nowInOpponentHalf = !_isInOwnHalf(move.to, move.piece.color);

      if (wasInOwnHalf && nowInOpponentHalf) {
        printDebug(
          '👸 SAVE QUEEN: ⚠️ Queen moved back to opponent half - becoming prisoner',
        );

        // Execute the move first
        var newBoard = board.makeMove(move);

        // Teleport queen back to prison
        final prisonPosition = move.piece.color == PieceColor.white
            ? whiteQueenPrison
            : blackQueenPrison;

        // Remove queen from current position
        final newPieces = newBoard.pieces
            .where((p) => p.position != move.to)
            .toList();

        // Add queen at prison
        final prisonedQueen = move.piece.copyWith(
          position: prisonPosition,
          hasMoved: false,
        );
        newPieces.add(prisonedQueen);

        newBoard = newBoard.copyWith(pieces: newPieces);

        printDebug(
          '👸 SAVE QUEEN: Queen teleported to prison at ${prisonPosition.algebraic}',
        );
        return newBoard;
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
