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

/// Succession Mode: Promoted to King
void logSuccessionPromotion(String playerColor, String position) {
  debugPrint(
    '👑 SUCCESSION - Promotion: $playerColor pawn promoted to King at $position - Victory!',
  );
}

/// Succession Mode: Queen captured
void logSuccessionQueenCapture(String winner, String loser, String position) {
  debugPrint(
    '♕ SUCCESSION - Queen Capture: $winner captured $loser\'s queen at $position - Victory!',
  );
}

/// Succession Mode: Opponent lost all pawns
void logSuccessionNoPawns(String winner) {
  debugPrint(
    '🏆 SUCCESSION - No Pawns: $winner wins - opponent has no pawns left!',
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
    '⚔️ FIRST BLOOD! $playerColor King captured pawn at $position - all pieces unlocked, bonus move granted',
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

/// Snare Mode: Revengeful knight capture (last knight destroyed with attacker)
void logSnareRevengefulKnight(String attackerColor, String position) {
  debugPrint(
    '💥 SNARE - Revengeful Knight: $attackerColor captured the last knight at $position! Both pieces destroyed!',
  );
}

/// Snare Mode: All knights lost - game ends in stalemate
void logSnareAllKnightsLost() {
  debugPrint(
    '🏳️ SNARE - Stalemate: All knights have been lost! Game ends in stalemate!',
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
