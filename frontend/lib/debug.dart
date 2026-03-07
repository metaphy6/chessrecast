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

/// Coyote Mod: Rook reached opponent's back rank
void logCoyoteBackRank(String playerColor) {
  debugPrint(
    '🏆 COYOTE - Back Rank: $playerColor rook reached opponent\'s back rank! VICTORY!',
  );
}

/// Coyote Mod: Both rooks were captured
void logCoyoteRookCapture(String capturedBy, String position) {
  debugPrint(
    '⚔️ COYOTE - Both Rooks Captured: Final rook captured by $capturedBy at $position! VICTORY!',
  );
}

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

/// Succession Mod: Queen captured
void logSuccessionQueenCapture(String winner, String loser, String position) {
  debugPrint(
    '♕ SUCCESSION - Queen Capture: $winner captured $loser\'s queen at $position - Victory!',
  );
}

/// Succession Mod: Opponent lost all pawns
void logSuccessionNoPawns(String winner) {
  debugPrint(
    '🏆 SUCCESSION - No Pawns: $winner wins - opponent has no pawns left!',
  );
}

/// Secret Passage Mod: King-Rook swap
void logSecretPassageSwap(String playerColor, String fromPos, String toPos) {
  debugPrint(
    '🌀 SECRET PASSAGE - Swap: $playerColor King and Rook teleported! From $fromPos to $toPos',
  );
}

/// King's Battle Mod: King unlocks by capturing pawn
void logKingsBattleUnlock(String playerColor, String position) {
  debugPrint(
    '⚔️ FIRST BLOOD! $playerColor King captured pawn at $position - all pieces unlocked, bonus move granted',
  );
}

/// King's Battle Mod: King kill
void logKingsBattleKingKill(String winner, String position) {
  debugPrint(
    '⚡ KING\'S BATTLE - King Kill: $winner King killed opponent\'s King at $position! VICTORY!',
  );
}

/// Diamonds Mod: Bishop capture in diamond pattern
void logDiamondsBishopCapture(String playerColor, String position) {
  debugPrint(
    '💎 DIAMONDS - Capture: $playerColor Bishop captured in diamond pattern at $position!',
  );
}

/// Snare Mod: Knight creates/updates entangle zone
void logSnareEntangle(String playerColor, String position) {
  debugPrint(
    '🕸️ SNARE - Entangle: $playerColor Knight created entangle zone at $position!',
  );
}

/// Snare Mod: King caught in entangle zone
void logSnareKingCaught(String playerColor) {
  debugPrint(
    '🪤 SNARE - Trapped: $playerColor King caught in entangle zone! CHECKMATE!',
  );
}

/// Snare Mod: Revengeful knight capture (last knight destroyed with attacker)
void logSnareRevengefulKnight(String attackerColor, String position) {
  debugPrint(
    '💥 SNARE - Revengeful Knight: $attackerColor captured the last knight at $position! Both pieces destroyed!',
  );
}

/// Snare Mod: All knights lost - game ends in stalemate
void logSnareAllKnightsLost() {
  debugPrint(
    '🏳️ SNARE - Stalemate: All knights have been lost! Game ends in stalemate!',
  );
}

/// Heir Mod: King promoted from pawn
void logHeirKingPromotion(String playerColor, String position) {
  debugPrint(
    '👑 HEIR - King Promotion: $playerColor pawn promoted to King at $position!',
  );
}

/// Heir Mod: King captured (but game continues if pawns available)
void logHeirKingCapture(String capturedBy, String position) {
  debugPrint(
    '💀 HEIR - King Capture: King captured by $capturedBy at $position!',
  );
}

/// Friendly Fire Mod: Self-capture (intentional move)
void logFriendlyFireCapture(String playerColor, String position) {
  debugPrint(
    '🔥 FRIENDLY FIRE - Capture: $playerColor captured own piece at $position (intentional)!',
  );
}

/// Mercenary Mod: Pawn reaches back rank
void logMercenaryPromotion(String playerColor, String position) {
  debugPrint(
    '🐧 MERCENARY - Promotion: $playerColor pawn reached promotion rank at $position!',
  );
}

/// Truce Mod: Truce activated
void logTruceActivated(String playerColor) {
  debugPrint(
    '🕊️ TRUCE - Active: $playerColor called a truce! Rules are suspended until next move!',
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
