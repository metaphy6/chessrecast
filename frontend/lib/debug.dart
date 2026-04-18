import 'package:flutter/foundation.dart';

/// Log game moves only - shows which player moved what piece where
/// @param message - The move notation with piece icon (e.g., '♘ b8→c6', '♔ e1 ⇄ ♖ h1')
void logMove(String message) {
  debugPrint(message);
}

/// Log game end status - checkmate, stalemate, draw, etc
void logGameEnd(String message) {
  debugPrint('🏁 GAME END: $message');
}

/// Log API calls - requests to backend
void logApi(String message) {
  debugPrint('🌐 API: $message');
}

/// Error logging - always enabled even in production
void logError(dynamic message, [Object? error, StackTrace? stackTrace]) {
  debugPrint('❌ ERROR: $message');
  if (error != null) debugPrint('Error details: $error');
  if (stackTrace != null) debugPrint('Stack trace: $stackTrace');
}

// ===== GAME MOD SPECIFIC LOGGING =====

/// Save the Queen Mod: Queen escaped
void logSaveTheQueenEscape(String playerColor) {
  debugPrint(
    '👑 SAVE THE QUEEN - Escape: $playerColor queen escaped the board! VICTORY!',
  );
}

/// Save the Queen Mod: Queen captured/returned to prison
void logSaveTheQueenCapture(String capturedBy) {
  debugPrint(
    '🔒 SAVE THE QUEEN - Capture: Queen captured by $capturedBy, returned to prison!',
  );
}

/// Succession Mod: Promoted to King
void logSuccessionPromotion(String playerColor, String position) {
  debugPrint(
    '👑 SUCCESSION - Promotion: $playerColor pawn promoted to King at $position - Victory!',
  );
}

/// Succession Mod: Opponent lost all pawns
void logSuccessionNoPawns(String winner) {
  debugPrint(
    '🏆 SUCCESSION - No Pawns: $winner wins - opponent has no pawns left!',
  );
}

/// King's Battle Mod: King unlocks by capturing pawn
void logKingsBattleUnlock(String playerColor, String position) {
  debugPrint(
    '⚔️ FIRST BLOOD! $playerColor King captured pawn at $position - all pieces unlocked, bonus move granted',
  );
}

/// Truce Mod: Truce broken
void logTruceBroken(String playerColor) {
  debugPrint(
    '⚔️ TRUCE - Broken: $playerColor broke the truce! Normal rules resume!',
  );
}

// ===== GAME STATE LOGGING =====

/// Log when a player is in check
void logCheck(String playerColor) {
  debugPrint('⚠️ CHECK: $playerColor King is in check!');
}

/// Log checkmate - includes winner
void logCheckmate(String winner) {
  debugPrint('🏁 CHECKMATE: $winner wins!');
}

/// Log stalemate
void logStalemate() {
  debugPrint('🤝 STALEMATE: Game ends in a draw - no legal moves available');
}

/// Log draw by insufficient material
void logDrawInsufficientMaterial() {
  debugPrint('🤝 DRAW: Insufficient material - impossible to checkmate');
}

/// Log draw by threefold repetition
void logDrawRepetition() {
  debugPrint('🤝 DRAW: Threefold repetition - same position occurred 3 times');
}

/// Log draw by fifty-move rule
void logDrawFiftyMoveRule({bool isSpecialEndgame = false}) {
  if (isSpecialEndgame) {
    debugPrint(
      '🤝 DRAW: Failed to mate within 50 moves (special endgame rule)',
    );
  } else {
    debugPrint(
      '🤝 DRAW: Fifty-move rule - 50 moves without capture or pawn move',
    );
  }
}
