import 'dart:ffi';
import 'dart:io' show Platform;

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

import '../board/board.dart';
import '../board/moves/move.dart';
import '../board/moves/position.dart';
import '../board/piece.dart';
import '../mods/mods_enum.dart';
import '../mods/mods_cache.dart';
import 'search.dart';

// ─── Native Engine FFI Bindings ──────────────────────────────────────────────
//
// Wraps the C chess engine via dart:ffi.  The C library is compiled per-
// platform: .so on Android, .dylib on iOS/macOS, .dll on Windows.

/* ── C struct mirror ──────────────────────────────────────────────────────── */

final class EngineResultNative extends Struct {
  @Int32()
  external int fromRow;
  @Int32()
  external int fromCol;
  @Int32()
  external int toRow;
  @Int32()
  external int toCol;
  @Int32()
  external int score;
  @Int32()
  external int depth;
  @Int32()
  external int nodes;
  @Int32()
  external int isCastling;
  @Int32()
  external int isEnPassant;
  @Int32()
  external int isPromotion;
  @Int32()
  external int promoType;
}

/* ── Native function typedefs ─────────────────────────────────────────────── */

typedef _EngineInitNative = Void Function();
typedef _EngineInitDart = void Function();

typedef _EngineFindMoveNative =
    Void Function(
      Pointer<Utf8> fen,
      Int32 mod,
      Int32 timeMs,
      Int32 maxDepth,
      Int32 skillLevel,
      Int32 heirWp,
      Int32 heirBp,
      Int32 truceActive,
      Int64 truceFrozen,
      Pointer<EngineResultNative> result,
    );
typedef _EngineFindMoveDart =
    void Function(
      Pointer<Utf8> fen,
      int mod,
      int timeMs,
      int maxDepth,
      int skillLevel,
      int heirWp,
      int heirBp,
      int truceActive,
      int truceFrozen,
      Pointer<EngineResultNative> result,
    );

/* ── Library loader ───────────────────────────────────────────────────────── */

/// Uses dart:io Platform instead of defaultTargetPlatform because this
/// must work inside background isolates spawned by compute().
DynamicLibrary _loadLibrary() {
  if (Platform.isAndroid) return DynamicLibrary.open('libchess_engine.so');
  if (Platform.isIOS || Platform.isMacOS) return DynamicLibrary.process();
  if (Platform.isWindows) return DynamicLibrary.open('chess_engine.dll');
  if (Platform.isLinux) return DynamicLibrary.open('libchess_engine.so');
  throw UnsupportedError('Unsupported platform for native engine');
}

/* ── Public API ───────────────────────────────────────────────────────────── */

class NativeEngine {
  late final DynamicLibrary _lib;
  late final _EngineInitDart _init;
  late final _EngineFindMoveDart _findMove;

  static NativeEngine? _instance;

  factory NativeEngine() => _instance ??= NativeEngine._();

  NativeEngine._() {
    _lib = _loadLibrary();
    _init = _lib.lookupFunction<_EngineInitNative, _EngineInitDart>(
      'engine_init',
    );
    _findMove = _lib.lookupFunction<_EngineFindMoveNative, _EngineFindMoveDart>(
      'engine_find_move',
    );
    _init();
  }

  /// Check if native engine is available on this platform.
  static bool get isAvailable {
    try {
      NativeEngine();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Map a [ModsEnum] to the C engine's mod integer.
  static int _modToInt(ModsEnum mod) {
    switch (mod) {
      case ModsEnum.mercenary:
        return 1;
      case ModsEnum.heir:
        return 2;
      case ModsEnum.truce:
        return 3;
      case ModsEnum.friendlyFire:
        return 4;
      case ModsEnum.kingsBattle:
        return 5;
      default:
        return 0;
    }
  }

  /// Compute a bitboard of squares with pieces that have moved (for Friendly Fire).
  static int _getHasMovedBitboard(ChessBoard board) {
    int bb = 0;
    for (final p in board.pieces) {
      if (p.hasMoved) {
        bb |= 1 << (p.position.row * 8 + p.position.col);
      }
    }
    return bb;
  }

  /// Find the best move synchronously.
  ///
  /// Call from a background isolate via [compute()] to keep the UI responsive.
  NativeSearchResult findBestMoveSync(
    ChessBoard board, {
    int timeLimitMs = 1500,
    int maxDepth = 0,
    int skillLevel = 4,
  }) {
    final fen = board.toFEN();
    final mod = _modToInt(board.gameType);
    final heirWp = board.whiteHasPromotedKing ? 1 : 0;
    final heirBp = board.blackHasPromotedKing ? 1 : 0;
    final truceActive = board.gameType == ModsEnum.truce
        ? (mods.truce.isTruceActive(board) ? 1 : 0)
        : board.gameType == ModsEnum.kingsBattle
        ? (mods.kingsBattle.isUnlocked(board) ? 1 : 0)
        : 0;
    final truceFrozen = board.gameType == ModsEnum.truce
        ? mods.truce.getTruceFrozenBitboard(board)
        : board.gameType == ModsEnum.friendlyFire
        ? _getHasMovedBitboard(board)
        : 0;
    final fenPtr = fen.toNativeUtf8();
    final resultPtr = calloc<EngineResultNative>();

    try {
      _findMove(
        fenPtr,
        mod,
        timeLimitMs,
        maxDepth,
        skillLevel,
        heirWp,
        heirBp,
        truceActive,
        truceFrozen,
        resultPtr,
      );
      return _parseResult(resultPtr.ref, board);
    } finally {
      calloc.free(fenPtr);
      calloc.free(resultPtr);
    }
  }

  /// Async wrapper — runs the synchronous search on a background isolate.
  Future<NativeSearchResult> findBestMove(
    ChessBoard board, {
    int timeLimitMs = 1500,
    int maxDepth = 0,
    int skillLevel = 4,
  }) {
    return compute(
      _runNativeSearch,
      _NativeSearchArgs(board, timeLimitMs, maxDepth, skillLevel),
    );
  }

  NativeSearchResult _parseResult(EngineResultNative r, ChessBoard board) {
    // Guard: if the engine returned MOVE_NONE (depth=0, all zeros), return null move
    if (r.depth == 0 &&
        r.nodes == 0 &&
        r.fromRow == 0 &&
        r.fromCol == 0 &&
        r.toRow == 0 &&
        r.toCol == 0) {
      return NativeSearchResult(
        bestMove: null,
        score: r.score,
        depth: r.depth,
        nodesSearched: r.nodes,
      );
    }

    final from = Position(r.fromRow, r.fromCol);
    final to = Position(r.toRow, r.toCol);

    // Identify the piece on the from-square
    ChessPiece? piece;
    for (final p in board.pieces) {
      if (p.position == from && p.color == board.currentPlayer) {
        piece = p;
        break;
      }
    }

    // Identify captured piece
    ChessPiece? captured;
    if (r.isEnPassant == 1) {
      // En passant: the captured pawn is on the same row as 'from', same col as 'to'
      final capPos = Position(from.row, to.col);
      for (final p in board.pieces) {
        if (p.position == capPos && p.color != board.currentPlayer) {
          captured = p;
          break;
        }
      }
    } else {
      for (final p in board.pieces) {
        if (p.position == to && p.color != board.currentPlayer) {
          captured = p;
          break;
        }
      }
      // Friendly Fire: captured piece may be same color
      if (captured == null && board.gameType == ModsEnum.friendlyFire) {
        for (final p in board.pieces) {
          if (p.position == to &&
              p.color == board.currentPlayer &&
              p != piece) {
            captured = p;
            break;
          }
        }
      }
    }

    ChessMove? move;
    if (piece != null) {
      if (r.isCastling == 1) {
        move = ChessMove.castling(from: from, to: to, piece: piece);
      } else if (r.isPromotion == 1) {
        const promoChars = ['P', 'N', 'B', 'R', 'Q', 'K'];
        final promoChar = promoChars[r.promoType.clamp(0, 5)];
        move = ChessMove.promotion(
          from: from,
          to: to,
          piece: piece,
          promotionPiece: promoChar,
          capturedPiece: captured,
        );
      } else if (r.isEnPassant == 1 && captured != null) {
        move = ChessMove.enPassant(
          from: from,
          to: to,
          piece: piece,
          capturedPiece: captured,
        );
      } else if (captured != null) {
        move = ChessMove.simple(
          from: from,
          to: to,
          piece: piece,
          capturedPiece: captured,
        );
      } else {
        move = ChessMove.simple(from: from, to: to, piece: piece);
      }
    }

    return NativeSearchResult(
      bestMove: move,
      score: r.score,
      depth: r.depth,
      nodesSearched: r.nodes,
    );
  }
}

/* ── Isolate helper (must be top-level for compute()) ─────────────────────── */

class _NativeSearchArgs {
  final ChessBoard board;
  final int timeMs;
  final int maxDepth;
  final int skillLevel;
  const _NativeSearchArgs(
    this.board,
    this.timeMs,
    this.maxDepth,
    this.skillLevel,
  );
}

NativeSearchResult _runNativeSearch(_NativeSearchArgs args) {
  final engine = NativeEngine();
  return engine.findBestMoveSync(
    args.board,
    timeLimitMs: args.timeMs,
    maxDepth: args.maxDepth,
    skillLevel: args.skillLevel,
  );
}

/// Result from the native C engine search.
class NativeSearchResult {
  final ChessMove? bestMove;
  final int score;
  final int depth;
  final int nodesSearched;

  const NativeSearchResult({
    this.bestMove,
    required this.score,
    required this.depth,
    required this.nodesSearched,
  });

  /// Convert to the Dart engine's SearchResult for compatibility.
  SearchResult toSearchResult() => SearchResult(
    bestMove: bestMove,
    score: score,
    depth: depth,
    nodesSearched: nodesSearched,
  );

  @override
  String toString() =>
      'NativeSearchResult(depth=$depth, score=$score, nodes=$nodesSearched)';
}
