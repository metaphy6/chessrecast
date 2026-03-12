import 'dart:math';
import 'dart:typed_data';

import '../board/board.dart';
import '../board/pieces/piece_color.dart';
import '../board/pieces/piece_type.dart';
import '../board/moves/move.dart';

// ─── Zobrist Hashing ─────────────────────────────────────────────────────────

/// Pre-computed random 64-bit keys for Zobrist hashing.
/// Indexed: [pieceType 0-5][color 0-1][square 0-63]
/// Plus extras for castling rights, en passant file, and side to move.
class Zobrist {
  Zobrist._();

  static final Int64List _pieceKeys = _initPieceKeys();
  static final Int64List _castlingKeys = _initKeys(16); // 4 bits → 16 combos
  static final Int64List _enPassantKeys = _initKeys(9); // files 0-7 + "none"
  static final int _sideKey = _rand64();

  static Int64List _initPieceKeys() {
    final rng = Random(0xBEEF_CAFE);
    final keys = Int64List(6 * 2 * 64);
    for (var i = 0; i < keys.length; i++) {
      keys[i] = (rng.nextInt(1 << 32) << 32) | rng.nextInt(1 << 32);
    }
    return keys;
  }

  static Int64List _initKeys(int n) {
    final rng = Random(0xDEAD_FACE);
    final keys = Int64List(n);
    for (var i = 0; i < n; i++) {
      keys[i] = (rng.nextInt(1 << 32) << 32) | rng.nextInt(1 << 32);
    }
    return keys;
  }

  static int _rand64() {
    final rng = Random(0x1234_5678);
    return (rng.nextInt(1 << 32) << 32) | rng.nextInt(1 << 32);
  }

  static int _pieceIndex(PieceType t) {
    switch (t) {
      case PieceType.pawn:
        return 0;
      case PieceType.knight:
        return 1;
      case PieceType.bishop:
        return 2;
      case PieceType.rook:
        return 3;
      case PieceType.queen:
        return 4;
      case PieceType.king:
        return 5;
    }
  }

  /// Compute the full Zobrist hash for a board position.
  static int hash(ChessBoard board) {
    var h = 0;

    for (final p in board.pieces) {
      final sq = p.position.row * 8 + p.position.col;
      final colorIdx = p.color == PieceColor.white ? 0 : 1;
      final idx = (_pieceIndex(p.type) * 2 + colorIdx) * 64 + sq;
      h ^= _pieceKeys[idx];
    }

    var castling = 0;
    if (board.whiteCanCastleKingside) castling |= 1;
    if (board.whiteCanCastleQueenside) castling |= 2;
    if (board.blackCanCastleKingside) castling |= 4;
    if (board.blackCanCastleQueenside) castling |= 8;
    h ^= _castlingKeys[castling];

    if (board.enPassantTarget != null) {
      h ^= _enPassantKeys[board.enPassantTarget!.col];
    } else {
      h ^= _enPassantKeys[8];
    }

    if (board.currentPlayer == PieceColor.black) {
      h ^= _sideKey;
    }

    return h;
  }
}

// ─── Transposition Table ─────────────────────────────────────────────────────

/// Flag describing what kind of bound the stored score represents.
enum TTFlag { exact, lowerBound, upperBound }

/// A single entry in the transposition table.
class TTEntry {
  final int hash;
  final int depth;
  final int score;
  final TTFlag flag;
  final ChessMove? bestMove;

  const TTEntry({
    required this.hash,
    required this.depth,
    required this.score,
    required this.flag,
    this.bestMove,
  });
}

/// Fixed-size hash table storing search results.
class TranspositionTable {
  final int _size;
  late final List<TTEntry?> _table;

  /// [sizeMB] — approximate memory budget in megabytes.
  TranspositionTable({int sizeMB = 32}) : _size = (sizeMB * 1024 * 1024) ~/ 48 {
    // ~48 bytes per entry estimate
    _table = List<TTEntry?>.filled(_size, null);
  }

  int _index(int hash) => (hash & 0x7FFFFFFFFFFFFFFF) % _size;

  void store({
    required int hash,
    required int depth,
    required int score,
    required TTFlag flag,
    ChessMove? bestMove,
  }) {
    final idx = _index(hash);
    final existing = _table[idx];

    // Replace if deeper or same hash with deeper/equal depth
    if (existing == null ||
        existing.hash == hash && depth >= existing.depth ||
        depth > existing.depth) {
      _table[idx] = TTEntry(
        hash: hash,
        depth: depth,
        score: score,
        flag: flag,
        bestMove: bestMove,
      );
    }
  }

  TTEntry? probe(int hash) {
    final entry = _table[_index(hash)];
    if (entry != null && entry.hash == hash) return entry;
    return null;
  }

  void clear() {
    _table.fillRange(0, _size, null);
  }
}
