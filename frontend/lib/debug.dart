import 'package:flutter/foundation.dart';

/// Log game moves only - shows which player moved what piece where
void logMove(String message) {
  debugPrint('♟️ MOVE: $message');
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

// ===== GAME MODE SPECIFIC LOGGING =====

/// Other Side Mode: Rook reached opponent's back rank
void logOtherSideBackRank(String playerColor) {
  debugPrint(
    '🏆 OTHER SIDE - Back Rank: $playerColor rook reached opponent\'s back rank! VICTORY!',
  );
}

/// Other Side Mode: Rook was captured
void logOtherSideRookCapture(String capturedBy, String position) {
  debugPrint(
    '⚔️ OTHER SIDE - Rook Capture: Rook captured by $capturedBy at $position! VICTORY!',
  );
}

/// Save the Queen Mode: Queen escaped
void logSaveTheQueenEscape(String playerColor) {
  debugPrint(
    '👑 SAVE THE QUEEN - Escape: $playerColor queen escaped the board! VICTORY!',
  );
}

/// Save the Queen Mode: Queen captured/returned to prison
void logSaveTheQueenCapture(String capturedBy) {
  debugPrint(
    '🔒 SAVE THE QUEEN - Capture: Queen captured by $capturedBy, returned to prison!',
  );
}

/// Save the King Mode: Promoted to King
void logSaveTheKingPromotion(String playerColor, String position) {
  debugPrint(
    '👸 SAVE THE KING - Promotion: $playerColor pawn promoted to King at $position!',
  );
}

/// Save the King Mode: Promoted King captured
void logSaveTheKingKingCapture(String capturedBy, String position) {
  debugPrint(
    '💀 SAVE THE KING - King Capture: Promoted King captured by $capturedBy at $position!',
  );
}

/// Teleport Mode: King-Rook swap
void logTeleportSwap(String playerColor, String fromPos, String toPos) {
  debugPrint(
    '🌀 TELEPORT - Swap: $playerColor King and Rook teleported! From $fromPos to $toPos',
  );
}

/// King's Battle Mode: King unlocks by capturing pawn
void logKingsBattleUnlock(String playerColor, String position) {
  debugPrint(
    '🔓 KING\'S BATTLE - Unlock: $playerColor King captured pawn at $position, pieces unlocked!',
  );
}

/// King's Battle Mode: King kill
void logKingsBattleKingKill(String winner, String position) {
  debugPrint(
    '⚡ KING\'S BATTLE - King Kill: $winner King killed opponent\'s King at $position! VICTORY!',
  );
}

/// Diamonds Mode: Bishop capture in diamond pattern
void logDiamondsBishopCapture(String playerColor, String position) {
  debugPrint(
    '💎 DIAMONDS - Capture: $playerColor Bishop captured in diamond pattern at $position!',
  );
}

/// Snare Mode: Knight creates/updates entangle zone
void logSnareEntangle(String playerColor, String position) {
  debugPrint(
    '🕸️ SNARE - Entangle: $playerColor Knight created entangle zone at $position!',
  );
}

/// Snare Mode: King caught in entangle zone
void logSnareKingCaught(String playerColor) {
  debugPrint(
    '🪤 SNARE - Trapped: $playerColor King caught in entangle zone! CHECKMATE!',
  );
}

/// Heir Mode: King promoted from pawn
void logHeirKingPromotion(String playerColor, String position) {
  debugPrint(
    '👑 HEIR - King Promotion: $playerColor pawn promoted to King at $position!',
  );
}

/// Heir Mode: King captured (but game continues if pawns available)
void logHeirKingCapture(String capturedBy, String position) {
  debugPrint(
    '💀 HEIR - King Capture: King captured by $capturedBy at $position!',
  );
}

/// Friendly Fire Mode: Self-capture (intentional move)
void logFriendlyFireCapture(String playerColor, String position) {
  debugPrint(
    '🔥 FRIENDLY FIRE - Capture: $playerColor captured own piece at $position (intentional)!',
  );
}

/// Royal Pawns Mode: Pawn reaches back rank
void logRoyalPawnsPromotion(String playerColor, String position) {
  debugPrint(
    '👸 ROYAL PAWNS - Promotion: $playerColor pawn reached promotion rank at $position!',
  );
}

/// Truce Mode: Truce activated
void logTruceActivated(String playerColor) {
  debugPrint(
    '🕊️ TRUCE - Active: $playerColor called a truce! Rules are suspended until next move!',
  );
}

/// Truce Mode: Truce broken
void logTruceBroken(String playerColor) {
  debugPrint(
    '⚔️ TRUCE - Broken: $playerColor broke the truce! Normal rules resume!',
  );
}
