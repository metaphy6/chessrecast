import 'package:chessrecast/board/utils/exporter.dart';

class KingPolicyMetrics {
  int earlyKingMoveCount = 0;
  int castlingRightLossByVoluntaryKingMove = 0;
  int _kingExposureAccumulator = 0;
  int _kingExposureSamples = 0;
  int? _whiteCastledByPly;
  int? _blackCastledByPly;

  void recordPly({
    required int ply,
    required ChessBoard boardBefore,
    required ChessMove playedMove,
    required ChessBoard boardAfter,
    int earlyPlyLimit = 12,
  }) {
    final side = boardBefore.currentPlayer;
    final hadCastlingRights = _hasCastlingRights(boardBefore, side);

    if (playedMove.piece.type == PieceType.king) {
      if (playedMove.isCastling) {
        if (side == PieceColor.white) {
          _whiteCastledByPly ??= ply;
        } else {
          _blackCastledByPly ??= ply;
        }
      } else {
        if (ply <= earlyPlyLimit) {
          earlyKingMoveCount++;
        }
        final stillHasCastlingRights = _hasCastlingRights(boardAfter, side);
        if (hadCastlingRights && !stillHasCastlingRights) {
          castlingRightLossByVoluntaryKingMove++;
        }
      }
    }

    _kingExposureAccumulator += _kingExposure(boardAfter, side);
    _kingExposureSamples++;
  }

  double get averageKingExposureIndex {
    if (_kingExposureSamples == 0) return 0;
    return _kingExposureAccumulator / _kingExposureSamples;
  }

  String castledByPlyLabel(PieceColor color) {
    final ply = (color == PieceColor.white) ? _whiteCastledByPly : _blackCastledByPly;
    return ply == null ? 'never' : ply.toString();
  }

  static bool _hasCastlingRights(ChessBoard board, PieceColor side) {
    if (side == PieceColor.white) {
      return board.whiteCanCastleKingside || board.whiteCanCastleQueenside;
    }
    return board.blackCanCastleKingside || board.blackCanCastleQueenside;
  }

  static int _kingExposure(ChessBoard board, PieceColor side) {
    final king = board.getKing(side);
    if (king == null) {
      return 100;
    }

    final kingPos = king.position;
    final rowDist = _min(_abs(kingPos.row - 3), _abs(kingPos.row - 4));
    final colDist = _min(_abs(kingPos.col - 3), _abs(kingPos.col - 4));
    final centerDist = rowDist + colDist;

    final centerPenalty = (4 - _min(centerDist, 4)) * 4;
    final shield = _pawnShieldCount(board, side, kingPos);
    final shieldPenalty = (3 - shield) * 3;
    final inCheckPenalty = board.isKingInCheck(side) ? 40 : 0;
    final pressurePenalty = _nearbyEnemyPressure(board, side, kingPos);

    return 20 + centerPenalty + shieldPenalty + inCheckPenalty + pressurePenalty;
  }

  static int _pawnShieldCount(ChessBoard board, PieceColor side, Position kingPos) {
    final nextRow = side == PieceColor.white ? kingPos.row + 1 : kingPos.row - 1;
    if (nextRow < 0 || nextRow > 7) {
      return 0;
    }

    var shield = 0;
    for (var dc = -1; dc <= 1; dc++) {
      final col = kingPos.col + dc;
      if (col < 0 || col > 7) continue;
      final piece = board.getPieceAt(Position(nextRow, col));
      if (piece == null) continue;
      if (piece.color == side && piece.type == PieceType.pawn) {
        shield++;
      }
    }
    return shield;
  }

  static int _nearbyEnemyPressure(ChessBoard board, PieceColor side, Position kingPos) {
    final enemy = side == PieceColor.white ? PieceColor.black : PieceColor.white;
    var penalty = 0;

    for (final piece in board.getPiecesOfColor(enemy)) {
      final distance = _max(
        _abs(piece.position.row - kingPos.row),
        _abs(piece.position.col - kingPos.col),
      );
      if (distance > 2) continue;

      switch (piece.type) {
        case PieceType.queen:
          penalty += 8;
          break;
        case PieceType.rook:
          penalty += 6;
          break;
        case PieceType.bishop:
        case PieceType.knight:
          penalty += 4;
          break;
        case PieceType.pawn:
          penalty += 2;
          break;
        case PieceType.king:
          penalty += 1;
          break;
      }
    }

    return penalty;
  }

  static int _abs(int value) => value < 0 ? -value : value;
  static int _min(int a, int b) => a < b ? a : b;
  static int _max(int a, int b) => a > b ? a : b;
}
