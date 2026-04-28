import '../board/utils/exporter.dart';
import '../debug.dart';
import 'ruleset.dart';

/// Kings' Battle Mod: Two-phase game with restricted movement initially
///
/// PHASE 1 (locked):
/// - Only pawns and kings can move
/// - Kings and pawns can capture any piece (even checkmate)
/// - Kings cannot capture each other
/// - Three events end Phase 1 and unlock all pieces:
///   1. King's Kill: a king captures a pawn. Unlocks Phase 2 AND grants
///      the capturer one bonus (additional) move immediately. This is
///      the ONLY way to earn a bonus move in this mod.
///   2. Pawn promotion: a pawn reaches the back rank (with or without a
///      capture). Unlocks Phase 2 but does NOT grant a bonus move.
///   3. Deadlock auto-unlock: if pawns and kings cannot capture each
///      other (typical pawn blockage), Phase 2 unlocks automatically
///      after 6 consecutive non-capturing king moves (counted across
///      both colors). Any pawn move or any capture resets the counter.
///      No bonus move is granted.
/// - Pawn captures (without promotion) and quiet pawn pushes do nothing.
///
/// PHASE 2 (unlocked): standard chess rules apply for all pieces.
class KingsBattle implements Ruleset {
  @Deprecated(
    'Use the `mods.kingsBattle` alias from mods_cache.dart instead of direct instantiation',
  )
  const KingsBattle();
  @override
  List<ChessMove> filterMoves(
    List<ChessMove> moves,
    ChessPiece piece,
    ChessBoard board,
  ) {
    // Check if we're in Phase 1 (locked)
    if (!_isPhase2Unlocked(board)) {
      // In Phase 1, only kings and pawns can move
      if (piece.type != PieceType.king && piece.type != PieceType.pawn) {
        return []; // Other pieces cannot move yet
      }

      // Kings cannot capture other kings
      if (piece.type == PieceType.king) {
        final filteredMoves = moves.where((move) {
          if (move.capturedPiece != null &&
              move.capturedPiece!.type == PieceType.king) {
            return false;
          }
          return true;
        }).toList();

        return filteredMoves;
      }

      return moves; // Pawns can move normally
    }

    // Phase 2: All pieces can move normally
    return moves;
  }

  @override
  ChessBoard? handleSpecialMove(ChessBoard board, ChessMove move) {
    // Already unlocked? Nothing special to do.
    if (_isPhase2Unlocked(board)) return null;

    // 1) King's Kill: king captures a pawn -> unlock + bonus move.
    if (move.piece.type == PieceType.king &&
        move.capturedPiece != null &&
        move.capturedPiece!.type == PieceType.pawn) {
      final newBoard = board.makeMove(move);
      final playerColor = move.piece.color == PieceColor.white
          ? 'White'
          : 'Black';
      final position =
          '${String.fromCharCode(97 + move.to.col)}${8 - move.to.row}';
      logKingsBattleUnlock(playerColor, position);
      return _markKingsKillAndGrantBonusMove(newBoard);
    }

    // 2) Pawn promotion: pawn reaches back rank -> unlock, no bonus.
    //    A pawn capture WITHOUT promotion does nothing.
    if (move.piece.type == PieceType.pawn && move.isPromotion) {
      final playerColor = move.piece.color == PieceColor.white
          ? 'White'
          : 'Black';
      final position =
          '${String.fromCharCode(97 + move.to.col)}${8 - move.to.row}';
      logKingsBattlePhase2Unlock(playerColor, 'pawn promoted at $position');
      // Use default board.makeMove behavior (turn switches normally).
      return null;
    }

    // 3) Deadlock auto-unlock: if THIS move is a non-capturing king move
    //    that completes the 6th trailing consecutive non-capturing king
    //    move (across both colors), log it. The detection itself is in
    //    _isPhase2Unlocked which sees the new history after makeMove.
    if (move.piece.type == PieceType.king && move.capturedPiece == null) {
      final probe = board.makeMove(move);
      if (_isPhase2Unlocked(probe) && !_isPhase2Unlocked(board)) {
        final playerColor = move.piece.color == PieceColor.white
            ? 'White'
            : 'Black';
        logKingsBattlePhase2Unlock(playerColor, 'deadlock: 6 idle king moves');
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
    // Standard promotion to any piece
    return null; // Use default
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

  /// Checks if Phase 2 is unlocked (public for engine FFI bridge)
  bool isUnlocked(ChessBoard board) => _isPhase2Unlocked(board);

  /// Phase 2 is unlocked if any of the following has occurred:
  ///   - a king captured a pawn (King's Kill), or
  ///   - a pawn promoted (with or without capture), or
  ///   - the deadlock auto-unlock fired: 6 consecutive trailing
  ///     non-capturing king moves (any color). Any pawn move or any
  ///     capture resets the trailing counter.
  /// Pawn captures without promotion never unlock by themselves.
  bool _isPhase2Unlocked(ChessBoard board) {
    var trailingIdleKings = 0;
    var deadlockUnlocked = false;
    for (final move in board.moveHistory) {
      if (move.piece.type == PieceType.king &&
          move.capturedPiece != null &&
          move.capturedPiece!.type == PieceType.pawn) {
        return true;
      }
      if (move.piece.type == PieceType.pawn && move.isPromotion) {
        return true;
      }
      if (move.piece.type == PieceType.king && move.capturedPiece == null) {
        trailingIdleKings++;
        if (trailingIdleKings >= 6) {
          deadlockUnlocked = true;
        }
      } else {
        // Any pawn move (push or capture) or any other capture resets.
        trailingIdleKings = 0;
      }
    }
    return deadlockUnlocked;
  }

  /// Marks that King's Kill happened and grants a bonus move
  /// This is done by NOT switching the current player
  ChessBoard _markKingsKillAndGrantBonusMove(ChessBoard board) {
    // The board has already switched players after the move
    // We need to switch back to give the same player another turn
    return board.copyWith(
      currentPlayer: board.currentPlayer.opposite, // Switch back
    );
  }
}
