import '../board/utils/exporter.dart';
import '../debug.dart';
import 'game_mode.dart';

/// TRUCE MODE: Players cannot attack until all pieces have moved once
///
/// Rules:
/// - Players cannot capture opponent pieces until truce is broken
/// - Truce breaks when one player has exhausted all unmoved pieces (all moved or blocked)
/// - During truce, no piece can be moved more than 3 times
/// - NO check or checkmate during truce - kings move freely
/// - Once truce is broken, normal chess rules apply including check/checkmate/captures
class Truce extends GameMode {
  const Truce();

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

    return nonCapturingMoves;
  }

  /// Validate if a move is allowed during truce
  bool validateTruceMove(ChessBoard board, ChessMove move) {
    // Check if moving the same piece too many times during truce
    if (!_isTruceBroken(board)) {
      final moveCount = _getPieceMoveCount(board, move.piece);
      if (moveCount >= 3) {
        return false;
      }
    }

    return true;
  }

  @override
  ChessBoard? handleSpecialMove(ChessBoard board, ChessMove move) {
    // Check if this move breaks the truce
    final wasTruceActive = !_isTruceBroken(board);

    // Check if truce should end after this move
    // Truce ends when player has exhausted all unmoved pieces
    if (wasTruceActive) {
      // Count pieces that have moved after this move
      final movedPieces = _getMovedPieces(board, move.piece.color);
      movedPieces.add(move.from);

      final totalPieces = board.getPiecesOfColor(move.piece.color).length;
      final isTruceNowBroken =
          movedPieces.length >= totalPieces && totalPieces > 0;

      if (isTruceNowBroken) {
        logTruceBroken(
          move.piece.color == PieceColor.white ? 'white' : 'black',
        );
      }
    }

    return null;
  }

  /// Check if truce is broken for the board
  bool _isTruceBroken(ChessBoard board) {
    // Check if either player has exhausted all unmoved pieces
    for (final color in [PieceColor.white, PieceColor.black]) {
      final movedPieces = _getMovedPieces(board, color);
      final currentPieces = board.getPiecesOfColor(color);

      // Count how many current pieces have moved
      int currentPiecesThatHaveMoved = 0;
      for (final piece in currentPieces) {
        if (movedPieces.contains(piece.position)) {
          currentPiecesThatHaveMoved++;
        } else {
          // Check if piece moved TO this position
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
  bool isKingInCheckTruce(PieceColor kingColor, ChessBoard board) {
    if (isTruceActive(board)) {
      return false; // No check during truce
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
      if (move.piece.color == piece.color && move.from == piece.position) {
        count++;
      }
    }
    return count;
  }

  /// Get set of unique piece starting positions that have moved
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
