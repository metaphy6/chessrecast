import 'package:chessrecast/debug.dart';
import '../board/utils/exporter.dart';
import 'game_mode.dart';

/// TRUCE MODE: Players cannot attack until all pieces have moved once
///
/// Rules:
/// - Players cannot capture opponent pieces until truce is broken
/// - Truce breaks when one player has moved all their pieces at least once
/// - During truce, no piece can be moved more than 3 times
/// - NO check or checkmate during truce - kings move freely
/// - Once truce is broken, normal chess rules apply including check and checkmate
class Truce extends GameMode {
  @override
  List<ChessMove> filterMoves(
    List<ChessMove> moves,
    ChessPiece piece,
    ChessBoard board,
  ) {
    // If truce is broken, return all moves
    if (_isTruceBroken(board)) {
      return moves;
    }

    // During truce, filter out capturing moves
    final nonCapturingMoves = moves.where((move) {
      return move.capturedPiece == null;
    }).toList();

    printDebug(
      '🤝 TRUCE: Filtered moves for ${piece.type.name} at ${piece.position.algebraic}: ${moves.length} -> ${nonCapturingMoves.length}',
    );

    return nonCapturingMoves;
  }

  /// Validate if a move is allowed during truce
  bool validateTruceMove(ChessBoard board, ChessMove move) {
    // Check if moving the same piece too many times during truce
    if (!_isTruceBroken(board)) {
      final moveCount = _getPieceMoveCount(board, move.piece);
      if (moveCount >= 3) {
        printDebug(
          '🤝 TRUCE: Piece ${move.piece.type.name} at ${move.from.algebraic} has moved $moveCount times (max 3 during truce)',
        );
        return false;
      }
    }

    return true;
  }

  @override
  ChessBoard? handleSpecialMove(ChessBoard board, ChessMove move) {
    // Check if this move breaks the truce
    final wasTruceActive = !_isTruceBroken(board);

    // Count how many unique pieces of this color will have moved AFTER this move
    final movedPieces = _getMovedPieces(board, move.piece.color);
    movedPieces.add(move.from); // Add the current piece that's about to move

    // Important: Count total pieces BEFORE the move is made (board is pre-move state)
    final totalPieces = board.getPiecesOfColor(move.piece.color).length;

    printDebug(
      '🤝 TRUCE: ${move.piece.color.name} will have moved ${movedPieces.length}/$totalPieces unique pieces after this move',
    );

    // Truce breaks when a player has moved ALL their pieces at least once
    final isTruceNowBroken =
        movedPieces.length >= totalPieces && totalPieces > 0;

    if (wasTruceActive && isTruceNowBroken) {
      printDebug(
        '🤝 TRUCE: BROKEN! ${move.piece.color.name} has moved all $totalPieces pieces!',
      );
    }

    return null; // No special board changes needed
  }

  /// Check if truce is broken for the board
  bool _isTruceBroken(ChessBoard board) {
    // Check if either player has moved all their pieces
    // Note: We need to check if all CURRENT pieces on the board have moved at least once
    for (final color in [PieceColor.white, PieceColor.black]) {
      final movedPieces = _getMovedPieces(board, color);
      final currentPieces = board.getPiecesOfColor(color);

      // Count how many CURRENT pieces have moved at least once
      int currentPiecesThatHaveMoved = 0;
      for (final piece in currentPieces) {
        // Check if this piece position appeared as a "from" in move history
        if (movedPieces.contains(piece.position)) {
          currentPiecesThatHaveMoved++;
        } else {
          // Check if this piece moved FROM another position TO current position
          bool hasMoved = false;
          for (final move in board.moveHistory) {
            if (move.piece.color == color && move.to == piece.position) {
              hasMoved = true;
              break;
            }
          }
          if (hasMoved) {
            currentPiecesThatHaveMoved++;
          }
        }
      }

      printDebug(
        '🤝 TRUCE CHECK: ${color.name} has $currentPiecesThatHaveMoved/${currentPieces.length} pieces that have moved',
      );

      if (currentPiecesThatHaveMoved >= currentPieces.length &&
          currentPieces.isNotEmpty) {
        return true;
      }
    }

    return false;
  }

  /// Public method to check if truce is still active
  bool isTruceActive(ChessBoard board) {
    return !_isTruceBroken(board);
  }

  /// TRUCE MODE: King cannot be in check during truce
  /// Returns false during truce, normal check logic after truce breaks
  bool isKingInCheckTruce(PieceColor kingColor, ChessBoard board) {
    // During truce, kings cannot be in check (they move freely)
    if (isTruceActive(board)) {
      printDebug('🤝 TRUCE: Truce active - king cannot be in check');
      return false;
    }

    // After truce breaks, use normal check logic
    final king = board.getKing(kingColor);
    if (king == null) return false;
    return board.isPositionUnderAttack(king.position, kingColor.opposite);
  }

  /// Get how many times a specific piece has moved
  int _getPieceMoveCount(ChessBoard board, ChessPiece piece) {
    int count = 0;

    for (final move in board.moveHistory) {
      // Check if this move was made by the same piece (same color and starting position)
      if (move.piece.color == piece.color && move.from == piece.position) {
        count++;
      }
    }

    return count;
  }

  /// Get set of unique piece starting positions that have moved for a color
  Set<Position> _getMovedPieces(ChessBoard board, PieceColor color) {
    final movedPositions = <Position>{};

    for (final move in board.moveHistory) {
      if (move.piece.color == color) {
        movedPositions.add(move.from);
      }
    }

    return movedPositions;
  }

  /// Get truce status information for display
  Map<String, dynamic> getTruceInfo(ChessBoard board) {
    final whiteMovedPieces = _getMovedPieces(board, PieceColor.white);
    final blackMovedPieces = _getMovedPieces(board, PieceColor.black);

    final whiteTotalPieces = board.getPiecesOfColor(PieceColor.white).length;
    final blackTotalPieces = board.getPiecesOfColor(PieceColor.black).length;

    final whiteTruceBroken =
        whiteMovedPieces.length >= whiteTotalPieces && whiteTotalPieces > 0;
    final blackTruceBroken =
        blackMovedPieces.length >= blackTotalPieces && blackTotalPieces > 0;

    return {
      'truceActive': !whiteTruceBroken && !blackTruceBroken,
      'whiteTruceBroken': whiteTruceBroken,
      'blackTruceBroken': blackTruceBroken,
      'whiteMovedPieces': whiteMovedPieces.length,
      'blackMovedPieces': blackMovedPieces.length,
      'whiteTotalPieces': whiteTotalPieces,
      'blackTotalPieces': blackTotalPieces,
    };
  }
}
