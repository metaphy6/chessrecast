import 'piece.dart';
import 'pieces/piece_type.dart';
import '../mods/enums.dart';

/// Centralized draw-rule policy for all game modes.
///
/// Both the board auto-draw path (`ChessBoard.shouldAutoDraw`) and the
/// orchestrator status path (`Orchestrator._isDrawByFiftyMoveRule`) must
/// delegate to this class so that thresholds are always in sync.
class DrawRules {
  const DrawRules._();

  // ───────────────────────── Fifty-move thresholds ─────────────────────────

  /// Returns the half-move clock threshold at which the game is drawn.
  ///
  /// The result depends on the [gameType] and the current material on the
  /// board (supplied as [whitePieces] / [blackPieces]).
  static int fiftyMoveThreshold({
    required ModsEnum gameType,
    required List<ChessPiece> whitePieces,
    required List<ChessPiece> blackPieces,
  }) {
    // Succession: always 50 half-moves
    if (gameType == ModsEnum.succession) {
      return 50;
    }

    // Mercenary: 50 for one-side-only-king endgames (piece-vs-K or K+P vs K)
    if (gameType == ModsEnum.mercenary) {
      if (_isMercenaryAcceleratedEndgame(whitePieces, blackPieces)) {
        return 50;
      }
    }

    // Default for all other mods / positions
    return 100;
  }

  // ──────────────────── Mercenary endgame detection ────────────────────────

  /// Whether the current Mercenary position qualifies for the accelerated
  /// 50-half-move draw window.
  ///
  /// Qualifying positions:
  /// - King + Pawn vs King
  /// - Pawnless piece(s) vs lone King (mop-up endgame)
  static bool _isMercenaryAcceleratedEndgame(
    List<ChessPiece> whitePieces,
    List<ChessPiece> blackPieces,
  ) {
    final whiteOnlyKing =
        whitePieces.length == 1 && whitePieces.first.type == PieceType.king;
    final blackOnlyKing =
        blackPieces.length == 1 && blackPieces.first.type == PieceType.king;

    if (!whiteOnlyKing && !blackOnlyKing) return false;

    final strongerSide = whiteOnlyKing ? blackPieces : whitePieces;
    final hasPawn = strongerSide.any((p) => p.type == PieceType.pawn);

    // Pure piece-vs-King (no pawns) → accelerated
    if (!hasPawn) return true;

    // King + single Pawn vs King → accelerated
    final isKingAndPawnOnly =
        strongerSide.length == 2 &&
        strongerSide.any((p) => p.type == PieceType.king) &&
        hasPawn;
    return isKingAndPawnOnly;
  }

  // ────────────────── Insufficient material (router) ───────────────────────

  /// Returns `true` when the material on the board makes checkmate impossible.
  static bool isInsufficientMaterial({
    required ModsEnum gameType,
    required List<ChessPiece> whitePieces,
    required List<ChessPiece> blackPieces,
  }) {
    if (gameType == ModsEnum.mercenary) {
      return _isInsufficientMaterialMercenary(whitePieces, blackPieces);
    }

    if (gameType == ModsEnum.heir) {
      return _isInsufficientMaterialHeir(whitePieces, blackPieces);
    }

    return _isInsufficientMaterialClassic(whitePieces, blackPieces);
  }

  // ──────────────── Classic insufficient material ──────────────────────────

  static bool _isInsufficientMaterialClassic(
    List<ChessPiece> whitePieces,
    List<ChessPiece> blackPieces,
  ) {
    // King vs King
    if (whitePieces.length == 1 && blackPieces.length == 1) {
      return true;
    }

    // King + Bishop/Knight vs King
    if ((whitePieces.length == 2 && blackPieces.length == 1) ||
        (whitePieces.length == 1 && blackPieces.length == 2)) {
      final allPieces = [...whitePieces, ...blackPieces];
      final nonKingPieces = allPieces
          .where((p) => p.type != PieceType.king)
          .toList();

      if (nonKingPieces.length == 1) {
        final piece = nonKingPieces.first;
        if (piece.type == PieceType.bishop || piece.type == PieceType.knight) {
          return true;
        }
      }
    }

    // King + Bishop vs King + Bishop (same-color squares)
    if (whitePieces.length == 2 && blackPieces.length == 2) {
      final whiteBishops = whitePieces
          .where((p) => p.type == PieceType.bishop)
          .toList();
      final blackBishops = blackPieces
          .where((p) => p.type == PieceType.bishop)
          .toList();

      if (whiteBishops.length == 1 && blackBishops.length == 1) {
        final whiteSquareColor =
            (whiteBishops.first.position.row +
                whiteBishops.first.position.col) %
            2;
        final blackSquareColor =
            (blackBishops.first.position.row +
                blackBishops.first.position.col) %
            2;

        if (whiteSquareColor == blackSquareColor) {
          return true;
        }
      }
    }

    return false;
  }

  // ──────────────── Mercenary insufficient material ────────────────────────

  static bool _isInsufficientMaterialMercenary(
    List<ChessPiece> whitePieces,
    List<ChessPiece> blackPieces,
  ) {
    final whitePawns = whitePieces
        .where((p) => p.type == PieceType.pawn)
        .length;
    final blackPawns = blackPieces
        .where((p) => p.type == PieceType.pawn)
        .length;

    final totalPieces = whitePieces.length + blackPieces.length;

    // King vs King
    if (totalPieces == 2) return true;

    // Pawns can assist in checkmate — not insufficient
    if (whitePawns > 0 || blackPawns > 0) return false;

    // K+N vs K+N (no pawns) — insufficient in Mercenary
    if (totalPieces == 4) {
      final whiteKnights = whitePieces
          .where((p) => p.type == PieceType.knight)
          .length;
      final blackKnights = blackPieces
          .where((p) => p.type == PieceType.knight)
          .length;
      if (whiteKnights == 1 && blackKnights == 1) return true;
    }

    // Fall back to classic rules for remaining piece combinations
    return _isInsufficientMaterialClassic(whitePieces, blackPieces);
  }

  // ──────────────── Heir insufficient material ─────────────────────────────

  static bool _isInsufficientMaterialHeir(
    List<ChessPiece> whitePieces,
    List<ChessPiece> blackPieces,
  ) {
    // Only K vs K is truly insufficient — kings can never capture each other
    return whitePieces.length == 1 &&
        blackPieces.length == 1 &&
        whitePieces.first.type == PieceType.king &&
        blackPieces.first.type == PieceType.king;
  }

  // ────────────────── Half-move clock reset policy ─────────────────────────

  /// Whether the half-move clock should be reset to 0 after this move.
  ///
  /// In all mods: captures reset the clock.
  /// In all mods except Mercenary: pawn moves also reset the clock.
  /// In Mercenary: pawn moves do NOT reset the clock.
  static bool shouldResetHalfMoveClock({
    required ModsEnum gameType,
    required bool isPawnMove,
    required bool isCapture,
  }) {
    if (isCapture) return true;
    if (isPawnMove && gameType != ModsEnum.mercenary) return true;
    return false;
  }

  // ────────────────── Save the Queen queen-capture draw ────────────────────

  /// Threshold for the repeated queen-capture counter in Save the Queen.
  /// Same piece captures the same prisoner queen from the same square this
  /// many times → automatic draw.
  static const int queenCaptureRepeatThreshold = 3;

  // ────────────────── Threefold repetition ─────────────────────────────────

  /// Number of times a position must appear to trigger a repetition draw.
  static const int threefoldRepetitionCount = 3;
}
