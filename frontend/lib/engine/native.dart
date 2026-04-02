import 'dart:ffi';
import 'dart:io' show Directory, File, Platform;

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

import '../board/board.dart';
import '../board/game_status.dart';
import '../board/moves/move.dart';
import '../board/moves/position.dart';
import '../board/piece.dart';
import '../board/pieces/piece_color.dart';
import '../board/pieces/piece_type.dart';
import '../management/orchestrator.dart';
import '../mods/mods_enum.dart';
import '../mods/mods_cache.dart';
import 'evaluation.dart';
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

typedef _EngineResetNative = Void Function(Int32 clearTt);
typedef _EngineResetDart = void Function(int clearTt);

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
  if (Platform.isLinux) return _loadLinuxLibrary();
  throw UnsupportedError('Unsupported platform for native engine');
}

DynamicLibrary _loadLinuxLibrary() {
  final overridePath = Platform.environment['CHESSRECAST_NATIVE_ENGINE_LIB'];
  final executableDir = File(Platform.resolvedExecutable).parent.path;
  final cwd = Directory.current.path;
  final candidates = <String>[
    if (overridePath != null && overridePath.isNotEmpty) overridePath,
    '$executableDir/lib/libchess_engine.so',
    '$cwd/build/native/linux/libchess_engine.so',
    '$cwd/build/linux/x64/debug/bundle/lib/libchess_engine.so',
    '$cwd/build/linux/x64/profile/bundle/lib/libchess_engine.so',
    '$cwd/build/linux/x64/release/bundle/lib/libchess_engine.so',
    '$cwd/libchess_engine.so',
  ];
  final seen = <String>{};

  for (final path in candidates) {
    if (!seen.add(path)) continue;
    if (File(path).existsSync()) {
      return DynamicLibrary.open(path);
    }
  }

  throw UnsupportedError(
    'Linux native engine library not found. Build the Linux bundle or set '
    'CHESSRECAST_NATIVE_ENGINE_LIB to a locally built libchess_engine.so.',
  );
}

/* ── Public API ───────────────────────────────────────────────────────────── */

class NativeEngine {
  static const bool _enableKingsBattleVerification = true;
  late final DynamicLibrary _lib;
  late final _EngineInitDart _init;
  late final _EngineResetDart _reset;
  late final _EngineFindMoveDart _findMove;

  static NativeEngine? _instance;

  factory NativeEngine() => _instance ??= NativeEngine._();

  NativeEngine._() {
    _lib = _loadLibrary();
    _init = _lib.lookupFunction<_EngineInitNative, _EngineInitDart>(
      'engine_init',
    );
    _reset = _lib.lookupFunction<_EngineResetNative, _EngineResetDart>(
      'engine_reset',
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

  /// Reset native search state. Useful for audit/probe tooling where each
  /// search should start from a clean transposition table.
  void resetState({bool clearTranspositionTable = true}) {
    _reset(clearTranspositionTable ? 1 : 0);
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
      case ModsEnum.saveTheQueen:
        return 6;
      case ModsEnum.succession:
        return 7;
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
    final rawResult = _findBestMoveRawSync(
      board,
      timeLimitMs: timeLimitMs,
      maxDepth: maxDepth,
      skillLevel: skillLevel,
    );

    if (!_shouldVerifyKingsBattleResult(
      board,
      rawResult,
      timeLimitMs: timeLimitMs,
      maxDepth: maxDepth,
      skillLevel: skillLevel,
    )) {
      return rawResult;
    }

    return _maybeVerifyKingsBattleResult(
      board,
      rawResult,
      timeLimitMs: timeLimitMs,
      maxDepth: maxDepth,
      skillLevel: skillLevel,
    );
  }

  NativeSearchResult _findBestMoveRawSync(
    ChessBoard board, {
    required int timeLimitMs,
    required int maxDepth,
    required int skillLevel,
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

  NativeSearchResult _maybeVerifyKingsBattleResult(
    ChessBoard board,
    NativeSearchResult rawResult, {
    required int timeLimitMs,
    required int maxDepth,
    required int skillLevel,
  }) {
    final candidates = _kingsBattleVerificationCandidates(
      board,
      rawResult.bestMove,
    );
    if (candidates.length <= 1) {
      return rawResult;
    }

    final openingVerification = board.moveHistory.length <= 2;
    final unlockedVerification = mods.kingsBattle.isUnlocked(board);
    final verifyDepth = openingVerification
        ? (maxDepth <= 4 ? 7 : maxDepth + 1)
        : unlockedVerification
        ? (maxDepth <= 4 ? 6 : maxDepth)
        : (maxDepth <= 4 ? 6 : maxDepth);
    final verifyMs = openingVerification
        ? (timeLimitMs <= 0 ? 480 : (timeLimitMs * 4).clamp(320, 520))
        : unlockedVerification
        ? (timeLimitMs <= 0 ? 280 : (timeLimitMs * 3).clamp(220, 420))
        : (timeLimitMs <= 0 ? 200 : (timeLimitMs * 3).clamp(180, 360));
    final orchestrator = Orchestrator();
    ChessMove? bestMove;
    int? bestScore;
    int? rawBestScore;

    for (final move in candidates) {
      final childBoard = orchestrator.executeMove(board, move);
      final score = _scoreKingsBattleCandidate(
        board,
        childBoard,
        timeLimitMs: verifyMs,
        maxDepth: verifyDepth,
        skillLevel: skillLevel,
      );

      if (bestScore == null || score > bestScore) {
        bestMove = move;
        bestScore = score;
      }
      if (move == rawResult.bestMove) {
        rawBestScore = score;
      }
    }

    if (bestMove == null ||
        bestScore == null ||
        rawBestScore == null ||
        bestMove == rawResult.bestMove ||
        bestScore < rawBestScore + 40) {
      return rawResult;
    }

    return NativeSearchResult(
      bestMove: bestMove,
      score: bestScore,
      depth: rawResult.depth,
      nodesSearched: rawResult.nodesSearched,
    );
  }

  bool _shouldVerifyKingsBattleResult(
    ChessBoard board,
    NativeSearchResult rawResult, {
    required int timeLimitMs,
    required int maxDepth,
    required int skillLevel,
  }) {
    if (!_enableKingsBattleVerification ||
        board.gameType != ModsEnum.kingsBattle ||
        skillLevel < 4 ||
        maxDepth <= 1 ||
        rawResult.bestMove == null) {
      return false;
    }

    if (mods.kingsBattle.isUnlocked(board)) {
      return maxDepth <= 4 || timeLimitMs <= 150;
    }

    return maxDepth <= 4 || timeLimitMs <= 200;
  }

  List<ChessMove> _kingsBattleVerificationCandidates(
    ChessBoard board,
    ChessMove? rawBestMove,
  ) {
    final orchestrator = Orchestrator();
    final legalMoves = orchestrator.getAllValidMoves(board);
    final candidates = <ChessMove>[];
    final seen = <String>{};

    void add(ChessMove? move) {
      if (move == null) return;
      final key = _verificationMoveKey(move);
      if (seen.add(key)) {
        candidates.add(move);
      }
    }

    add(rawBestMove);

    if (board.moveHistory.length <= 2) {
      for (final move in legalMoves) {
        if (_isKingsBattleCentralTwoStepBreak(move)) {
          add(move);
        }
      }
      return candidates;
    }

    if (mods.kingsBattle.isUnlocked(board)) {
      for (final move in legalMoves) {
        if (move.isPromotion) {
          add(move);
          continue;
        }

        if (_isKingsBattleUnlockedQueenPressureMove(board, move)) {
          add(move);
          continue;
        }

        if (_isKingsBattleUnlockedKingSafetyMove(board, move)) {
          add(move);
          continue;
        }

        if (_isKingsBattleUnlockedShelterMove(board, move)) {
          add(move);
          continue;
        }

        if (_isKingsBattleUnlockedDevelopmentMove(move)) {
          add(move);
        }
      }

      return candidates;
    }

    for (final move in legalMoves) {
      if (move.isPromotion) {
        add(move);
        continue;
      }

      if (move.piece.type == PieceType.king &&
          move.capturedPiece?.type == PieceType.pawn) {
        add(move);
        continue;
      }

      if (_isKingsBattlePhase1PawnCapture(move)) {
        add(move);
        continue;
      }

      if (_isKingsBattlePhase1KingRouteMove(move)) {
        add(move);
        continue;
      }

      if (_isKingsBattlePhase1SupportPawnMove(board, move)) {
        add(move);
        continue;
      }

      if (_isKingsBattleCentralPhase1BreakMove(move)) {
        add(move);
      }
    }

    return candidates;
  }

  bool _isKingsBattlePhase1PawnCapture(ChessMove move) {
    return move.piece.type == PieceType.pawn &&
        move.isCapture &&
        !move.isEnPassant &&
        !move.isPromotion;
  }

  bool _isKingsBattlePhase1KingRouteMove(ChessMove move) {
    return move.piece.type == PieceType.king &&
        !move.isPromotion &&
        !move.isEnPassant;
  }

  bool _isKingsBattlePhase1SupportPawnMove(ChessBoard board, ChessMove move) {
    if (move.piece.type != PieceType.pawn ||
        move.isCapture ||
        move.isEnPassant ||
        move.isPromotion) {
      return false;
    }

    final homeRow = move.piece.color == PieceColor.white ? 1 : 6;
    if (move.from.row != homeRow) {
      return false;
    }

    final rowDelta = (move.to.row - move.from.row).abs();
    if (rowDelta != 1) {
      return false;
    }

    final attackRow = move.piece.color == PieceColor.white
        ? move.to.row + 1
        : move.to.row - 1;
    if (attackRow < 0 || attackRow > 7) {
      return false;
    }

    for (final dc in const [-1, 1]) {
      final attackCol = move.to.col + dc;
      if (attackCol < 0 || attackCol > 7) {
        continue;
      }

      for (final piece in board.pieces) {
        if (piece.color != move.piece.color &&
            piece.type == PieceType.pawn &&
            piece.position.row == attackRow &&
            piece.position.col == attackCol) {
          return true;
        }
      }
    }

    return false;
  }

  bool _isKingsBattleCentralPhase1BreakMove(ChessMove move) {
    if (move.piece.type != PieceType.pawn ||
        move.isCapture ||
        move.isEnPassant ||
        move.isPromotion) {
      return false;
    }

    final homeRow = move.piece.color == PieceColor.white ? 1 : 6;
    return move.from.row == homeRow &&
        move.to.row != move.from.row &&
        (move.from.col == 3 || move.from.col == 4);
  }

  bool _isKingsBattleCentralTwoStepBreak(ChessMove move) {
    if (!_isKingsBattleCentralPhase1BreakMove(move)) {
      return false;
    }

    return (move.to.row - move.from.row).abs() == 2;
  }

  bool _isKingsBattleUnlockedQueenPressureMove(
    ChessBoard board,
    ChessMove move,
  ) {
    if (move.piece.type != PieceType.queen ||
        move.isEnPassant ||
        move.isPromotion) {
      return false;
    }

    final enemyKing = _findKing(board, move.piece.color.opposite);
    if (enemyKing == null) {
      return false;
    }

    final fromDistance = _chebyshev(move.from, enemyKing.position);
    final toDistance = _chebyshev(move.to, enemyKing.position);
    return toDistance <= 2 || toDistance + 1 < fromDistance;
  }

  bool _isKingsBattleUnlockedKingSafetyMove(ChessBoard board, ChessMove move) {
    if (move.piece.type != PieceType.king ||
        move.isEnPassant ||
        move.isPromotion) {
      return false;
    }

    return _findQueen(board, move.piece.color.opposite) != null;
  }

  bool _isKingsBattleUnlockedShelterMove(ChessBoard board, ChessMove move) {
    if (move.piece.type != PieceType.pawn ||
        move.isCapture ||
        move.isEnPassant ||
        move.isPromotion) {
      return false;
    }

    final ownKing = _findKing(board, move.piece.color);
    if (ownKing == null ||
        _findQueen(board, move.piece.color.opposite) == null) {
      return false;
    }

    return _chebyshev(move.to, ownKing.position) <= 1;
  }

  bool _isKingsBattleUnlockedDevelopmentMove(ChessMove move) {
    if (move.isCapture || move.isEnPassant || move.isPromotion) {
      return false;
    }

    if (move.piece.type != PieceType.knight &&
        move.piece.type != PieceType.bishop) {
      return false;
    }

    final homeRow = move.piece.color == PieceColor.white ? 0 : 7;
    return move.from.row == homeRow && move.to.row != homeRow;
  }

  ChessPiece? _findKing(ChessBoard board, PieceColor color) {
    for (final piece in board.pieces) {
      if (piece.color == color && piece.type == PieceType.king) {
        return piece;
      }
    }
    return null;
  }

  ChessPiece? _findQueen(ChessBoard board, PieceColor color) {
    for (final piece in board.pieces) {
      if (piece.color == color && piece.type == PieceType.queen) {
        return piece;
      }
    }
    return null;
  }

  int _chebyshev(Position a, Position b) {
    final rowDistance = (a.row - b.row).abs();
    final colDistance = (a.col - b.col).abs();
    return rowDistance > colDistance ? rowDistance : colDistance;
  }

  int _scoreKingsBattleCandidate(
    ChessBoard rootBoard,
    ChessBoard childBoard, {
    required int timeLimitMs,
    required int maxDepth,
    required int skillLevel,
  }) {
    if (childBoard.gameStatus == GameStatus.checkmate) {
      return mateScore;
    }
    if (childBoard.gameStatus == GameStatus.draw ||
        childBoard.gameStatus == GameStatus.stalemate) {
      return 0;
    }

    resetState();
    final reply = _findBestMoveRawSync(
      childBoard,
      timeLimitMs: timeLimitMs,
      maxDepth: maxDepth,
      skillLevel: skillLevel,
    );
    return childBoard.currentPlayer == rootBoard.currentPlayer
        ? reply.score
        : -reply.score;
  }

  static String _verificationMoveKey(ChessMove move) {
    final promotion = move.isPromotion ? move.promotionPiece ?? '' : '';
    return '${move.from.algebraic}${move.to.algebraic}$promotion';
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
