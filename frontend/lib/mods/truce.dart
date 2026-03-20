import '../board/utils/exporter.dart';
import '../debug.dart';
import 'game_mod.dart';

/// Truce Mod: Players cannot attack until all pieces have moved once
///
/// Rules:
/// - Players cannot capture opponent pieces until truce is broken
/// - Truce breaks when one player has made all legal truce moves:
///   all pieces have moved at least once, or remaining unmoved pieces are blocked
/// - During truce, no piece can be moved more than 3 times
/// - NO check or checkmate during truce - kings move freely
/// - Once truce is broken, normal chess rules apply including check/checkmate/captures
class Truce extends GameMod {
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
    // Truce ends when player has exhausted all legal truce moves
    // (all pieces moved, or remaining unmoved pieces are blocked)
    if (wasTruceActive && !_isTruceBroken(board)) {
      // _isTruceBroken checks the post-move state already; if it returns
      // false here we're still in truce.  Nothing to log.
    } else if (wasTruceActive) {
      logTruceBroken(
        move.piece.color == PieceColor.white ? 'white' : 'black',
      );
    }

    return null;
  }

  /// Check if truce is broken for the board.
  /// Truce breaks when one player has exhausted all legal truce moves:
  /// every piece has either moved at least once OR is blocked (no
  /// non-capturing moves available).
  bool _isTruceBroken(ChessBoard board) {
    for (final color in [PieceColor.white, PieceColor.black]) {
      final movedPieces = _getMovedPieces(board, color);
      final currentPieces = board.getPiecesOfColor(color);
      if (currentPieces.isEmpty) continue;

      int exhaustedCount = 0;
      for (final piece in currentPieces) {
        bool hasMoved = false;
        if (movedPieces.contains(piece.position)) {
          hasMoved = true;
        } else {
          for (final move in board.moveHistory) {
            if (move.piece.color == color && move.to == piece.position) {
              hasMoved = true;
              break;
            }
          }
        }

        if (hasMoved) {
          exhaustedCount++;
        } else if (!_canPieceMoveWithoutCapture(board, piece)) {
          // Unmoved AND blocked → counts as exhausted
          exhaustedCount++;
        }
      }

      if (exhaustedCount >= currentPieces.length) {
        return true;
      }
    }

    return false;
  }

  /// Returns true when [piece] has at least one non-capturing move.
  /// Uses simple directional checks (no full move-gen) to avoid
  /// circular dependency with filterMoves → _isTruceBroken.
  bool _canPieceMoveWithoutCapture(ChessBoard board, ChessPiece piece) {
    final pos = piece.position;
    switch (piece.type) {
      case PieceType.pawn:
        final dir = piece.color == PieceColor.white ? 1 : -1;
        final oneStep = pos.offset(dir, 0);
        return oneStep.isValid && board.getPieceAt(oneStep) == null;
      case PieceType.knight:
        const offsets = [
          [-2, -1], [-2, 1], [-1, -2], [-1, 2],
          [1, -2], [1, 2], [2, -1], [2, 1],
        ];
        for (final o in offsets) {
          final t = pos.offset(o[0], o[1]);
          if (t.isValid && board.getPieceAt(t) == null) return true;
        }
        return false;
      case PieceType.bishop:
        for (final d in [[1, 1], [1, -1], [-1, 1], [-1, -1]]) {
          final t = pos.offset(d[0], d[1]);
          if (t.isValid && board.getPieceAt(t) == null) return true;
        }
        return false;
      case PieceType.rook:
        for (final d in [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
          final t = pos.offset(d[0], d[1]);
          if (t.isValid && board.getPieceAt(t) == null) return true;
        }
        return false;
      case PieceType.queen:
      case PieceType.king:
        for (final d in [
          [1, 0], [-1, 0], [0, 1], [0, -1],
          [1, 1], [1, -1], [-1, 1], [-1, -1],
        ]) {
          final t = pos.offset(d[0], d[1]);
          if (t.isValid && board.getPieceAt(t) == null) return true;
        }
        return false;
    }
  }

  /// Public method to check if truce is still active
  bool isTruceActive(ChessBoard board) {
    return !_isTruceBroken(board);
  }

  /// Truce Mod: King cannot be in check during truce
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

  /// Returns a bitboard of squares where pieces have exhausted their 3-move truce limit.
  /// Bit i is set if the piece at square (row=i/8, col=i%8) cannot be moved.
  int getTruceFrozenBitboard(ChessBoard board) {
    if (_isTruceBroken(board)) return 0;
    int frozen = 0;
    for (final piece in board.pieces) {
      if (_getPieceMoveCount(board, piece) >= 3) {
        final sq = piece.position.row * 8 + piece.position.col;
        frozen |= (1 << sq);
      }
    }
    return frozen;
  }

  /// Get truce status information for display
  Map<String, dynamic> getTruceInfo(ChessBoard board) {
    final isBroken = _isTruceBroken(board);
    final whiteMovedPieces = _getMovedPieces(board, PieceColor.white);
    final blackMovedPieces = _getMovedPieces(board, PieceColor.black);

    final whiteTotalPieces = board.getPiecesOfColor(PieceColor.white).length;
    final blackTotalPieces = board.getPiecesOfColor(PieceColor.black).length;

    return {
      'truceActive': !isBroken,
      'whiteTruceBroken': isBroken,
      'blackTruceBroken': isBroken,
      'whiteMovedPieces': whiteMovedPieces.length,
      'blackMovedPieces': blackMovedPieces.length,
      'whiteTotalPieces': whiteTotalPieces,
      'blackTotalPieces': blackTotalPieces,
    };
  }
}
