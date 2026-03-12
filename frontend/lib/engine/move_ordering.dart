import '../board/board.dart';
import '../board/piece.dart';
import '../board/pieces/piece_color.dart';
import '../board/pieces/piece_type.dart';
import '../board/moves/move.dart';
import '../mods/mods_enum.dart';

// ─── Move Ordering ───────────────────────────────────────────────────────────
//
// Good move ordering is the single biggest factor in alpha-beta performance.
// We score each move and sort descending so the search prunes early.
//
// Heuristics (in priority order):
//  1. TT best move            → score 10 000 000
//  2. Winning / equal captures → MVV-LVA  (Most Valuable Victim – Least Valuable Attacker)
//  3. Killer moves            → 900 000
//  4. History heuristic       → 0 – 800 000

/// Static piece values for MVV-LVA scoring.
const Map<PieceType, int> _pieceVal = {
  PieceType.pawn: 100,
  PieceType.knight: 320,
  PieceType.bishop: 330,
  PieceType.rook: 500,
  PieceType.queen: 900,
  PieceType.king: 20000,
};

/// Persists across the entire game for better ordering in later positions.
class MoveOrderer {
  // killer[ply][0..1]
  final List<List<ChessMove?>> _killers = List.generate(
    64,
    (_) => List<ChessMove?>.filled(2, null),
  );

  // history[color 0/1][from sq 0-63][to sq 0-63]
  final List<List<List<int>>> _history = List.generate(
    2,
    (_) => List.generate(64, (_) => List<int>.filled(64, 0)),
  );

  /// Record a quiet (non-capture) move that caused a beta cutoff.
  void recordKiller(ChessMove move, int ply) {
    if (ply >= _killers.length) return;
    if (_killers[ply][0] != move) {
      _killers[ply][1] = _killers[ply][0];
      _killers[ply][0] = move;
    }
  }

  void recordHistory(ChessMove move, PieceColor color, int depth) {
    final ci = color == PieceColor.white ? 0 : 1;
    final from = move.from.row * 8 + move.from.col;
    final to = move.to.row * 8 + move.to.col;
    _history[ci][from][to] += depth * depth;
    // Prevent overflow-ish growth
    if (_history[ci][from][to] > 800000) {
      _halveHistory();
    }
  }

  void _halveHistory() {
    for (var c = 0; c < 2; c++) {
      for (var f = 0; f < 64; f++) {
        for (var t = 0; t < 64; t++) {
          _history[c][f][t] >>= 1;
        }
      }
    }
  }

  /// Sort [moves] in place, best-first.
  void orderMoves(
    List<ChessMove> moves,
    ChessBoard board, {
    ChessMove? ttBestMove,
    required int ply,
  }) {
    final colorIdx = board.currentPlayer == PieceColor.white ? 0 : 1;
    final isMerc = board.gameType == ModsEnum.mercenary;

    // Score every move
    final scores = List<int>.generate(moves.length, (i) {
      final m = moves[i];

      // 1. TT best move
      if (ttBestMove != null &&
          m.from == ttBestMove.from &&
          m.to == ttBestMove.to) {
        return 10000000;
      }

      // 2. Captures — MVV-LVA
      if (m.isCapture) {
        final victimVal = _pieceVal[m.capturedPiece!.type] ?? 100;
        final attackerVal = _pieceValForPiece(m.piece, isMerc);
        // Higher victim, lower attacker = better
        return 1000000 + victimVal * 10 - attackerVal;
      }

      // 3. Promotions
      if (m.isPromotion) {
        return 950000;
      }

      // 4. Killers
      if (ply < _killers.length) {
        if (_killers[ply][0] != null &&
            m.from == _killers[ply][0]!.from &&
            m.to == _killers[ply][0]!.to) {
          return 900000;
        }
        if (_killers[ply][1] != null &&
            m.from == _killers[ply][1]!.from &&
            m.to == _killers[ply][1]!.to) {
          return 899000;
        }
      }

      // 5. History
      final from = m.from.row * 8 + m.from.col;
      final to = m.to.row * 8 + m.to.col;
      return _history[colorIdx][from][to];
    });

    // Insertion sort is faster than quicksort for small lists (< ~50 moves)
    for (var i = 1; i < moves.length; i++) {
      final m = moves[i];
      final s = scores[i];
      var j = i - 1;
      while (j >= 0 && scores[j] < s) {
        moves[j + 1] = moves[j];
        scores[j + 1] = scores[j];
        j--;
      }
      moves[j + 1] = m;
      scores[j + 1] = s;
    }
  }

  static int _pieceValForPiece(ChessPiece piece, bool isMerc) {
    // In Mercenary mod, pawns move like kings — value them higher
    if (isMerc && piece.type == PieceType.pawn) return 200;
    return _pieceVal[piece.type] ?? 100;
  }

  void clear() {
    for (final slot in _killers) {
      slot[0] = null;
      slot[1] = null;
    }
    for (var c = 0; c < 2; c++) {
      for (var f = 0; f < 64; f++) {
        for (var t = 0; t < 64; t++) {
          _history[c][f][t] = 0;
        }
      }
    }
  }
}
