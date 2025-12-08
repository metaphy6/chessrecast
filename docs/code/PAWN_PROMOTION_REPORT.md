# Pawn Promotion Behavior Report

**Generated:** December 8, 2025  
**Context:** Analysis of pawn promotion handling across all game modes

---

## Summary

Pawn promotion in ChessRecast is handled through a two-stage system:

1. **Controller Check** (`controller.dart` line 320-326): Determines IF promotion dialog should appear
2. **Mode-Specific Logic** (`generation.dart` line 247+): Determines WHAT pieces are available for promotion

---

## Critical Bug Found & Fixed

### Royal Pawns Mode Issue
**Problem:** Promotion dialog was appearing for Royal Pawns despite mode explicitly disabling promotion.

**Root Cause:**
- Controller only checked `board.gameType != ModesEnum.royalPawns` (FIXED)
- `getPromotionPieces()` was missing Royal Pawns case, fell through to standard pieces (FIXED)

**Fix Applied:**
```dart
// controller.dart - Skip promotion dialog
if (piece.type == PieceType.pawn && board.gameType != ModesEnum.royalPawns)

// generation.dart - Return empty list
if (gameType == ModesEnum.royalPawns) {
  return []; // No promotion in Royal Pawns mode
}
```

---

## Promotion Behavior By Game Mode

### 🚫 NO PROMOTION
| Mode | Behavior | Implementation |
|------|----------|----------------|
| **Royal Pawns** | Pawns CANNOT promote. Move like kings (one square any direction). | Returns `[]` from `getPromotionPieces()` |
| **Snare** (no knights) | NO promotion if all knights in player's color are lost. | Returns `[]` when `knights.isEmpty` |

---

### 🎯 RESTRICTED PROMOTION (Specific Pieces Only)

| Mode | Available Pieces | Reason | Implementation |
|------|------------------|---------|----------------|
| **Diamonds** | `['B']` | Bishop-focused variant, only bishop promotion allowed | Direct return in mode class |
| **Save the Queen** | `['R', 'B', 'N']` | NO QUEEN promotion (queens start as prisoners) | Direct return in mode class |
| **Other Side** | `['Q', 'B', 'N']` | NO ROOK promotion (mode focuses on rooks racing) | Returns lowercase `['q', 'b', 'n']` ⚠️ |
| **Snare** (1 knight) | `['N']` | Can ONLY promote to knight (to get back to 2 knights) | Returns `['N']` when `knights.length == 1` |
| **Snare** (2 knights) | `['Q', 'R', 'B']` | Can promote to Q/R/B but NOT knight (max 2 knights allowed) | Returns `['Q', 'R', 'B']` when `knights.length == 2` |

---

### 👑 SPECIAL: KING PROMOTION

| Mode | Behavior | Conditions | Implementation |
|------|----------|------------|----------------|
| **Heir** | Can promote to King ONCE | - Returns `['K']` if king captured and not promoted yet<br>- Returns `['Q', 'R', 'B', 'N', 'K']` if still has king and hasn't promoted yet<br>- Standard promotion after king promotion used | Complex logic in `heir.dart` checking `hasPromotedKing` flag |
| **Save the King** | MUST promote to King on last pawn | - Returns `['K']` if last pawn and square is safe<br>- Returns `[]` if last pawn but square under attack (GAME LOST)<br>- Returns `['Q', 'R', 'B', 'N', 'K']` if not last pawn and square safe<br>- Returns `['Q', 'R', 'B', 'N']` if not last pawn but square under attack | Complex logic in `save_the_king.dart` checking pawn count and square safety |

---

### ✅ STANDARD PROMOTION

| Mode | Behavior | Available Pieces |
|------|----------|------------------|
| **Classic** | Standard chess promotion | `['Q', 'R', 'B', 'N']` |
| **Teleport** | Standard promotion (returns `null` = use default) | `['Q', 'R', 'B', 'N']` |
| **Truce** | Standard promotion | `['Q', 'R', 'B', 'N']` |
| **Friendly Fire** | Standard promotion (returns `null` = use default) | `['Q', 'R', 'B', 'N']` |
| **Kings' Battle** | Standard promotion (returns `null` = use default)<br>Note: Promotion unlocks all pieces | `['Q', 'R', 'B', 'N']` |

---

## Implementation Architecture

### Entry Point: Controller (`lib/management/controller.dart`)
```dart
void _attemptMove(Position from, Position to) {
  // Line 320-326: First gate - should we show promotion dialog?
  if (piece.type == PieceType.pawn && board.gameType != ModesEnum.royalPawns) {
    final lastRank = piece.color == PieceColor.white ? 7 : 0;
    if (to.row == lastRank) {
      _showPromotionDialog(from, to, piece, capturedPiece);
      return;
    }
  }
}
```

**Current State:** ✅ Correctly excludes Royal Pawns

---

### Promotion Dialog (`lib/management/controller.dart`)
```dart
void _showPromotionDialog(...) {
  // Line 430-435: Get available pieces from board
  final availablePieces = _getAvailablePromotionPieces(piece.color, to);
  
  // If empty list, silently deselect (no promotion possible)
  if (availablePieces.isEmpty) {
    _deselectPiece();
    return;
  }
  
  // Show dialog with available options
  Get.dialog(AlertDialog(...));
}
```

**Behavior:** Empty list = no dialog, silently fails

---

### Mode Logic Dispatcher (`lib/board/moves/generation.dart`)
```dart
List<String> getPromotionPieces(PieceColor color, {Position? promotionPosition}) {
  // Line 251-254: Royal Pawns - NO promotion
  if (gameType == ModesEnum.royalPawns) return [];
  
  // Line 257-259: Diamonds - only bishops
  if (gameType == ModesEnum.diamonds) return ['B'];
  
  // Line 262-264: Save the Queen - no queen promotion
  if (gameType == ModesEnum.saveTheQueen) return ['R', 'B', 'N'];
  
  // Line 267-269: Other Side - no rook promotion
  if (gameType == ModesEnum.otherSide) return ['Q', 'B', 'N'];
  
  // Line 272-279: Heir - King promotion logic
  if (gameType == ModesEnum.heir) {
    final options = heirMode.getPromotionPieces(color, this, promotionPosition: promotionPosition);
    if (options != null) return options;
  }
  
  // Line 282-289: Save the King - King promotion logic
  if (gameType == ModesEnum.saveTheKing) {
    final options = saveTheKingMode.getPromotionPieces(...);
    if (options != null) return options;
  }
  
  // Line 292-299: Snare - Knight-based restrictions
  if (gameType == ModesEnum.snare) {
    final options = snareMode.getPromotionPieces(...);
    if (options != null) return options;
  }
  
  // Line 305: Default fallback
  return ['Q', 'R', 'B', 'N']; // Standard promotion pieces
}
```

---

## Potential Issues Found

### ⚠️ Issue 1: Inconsistent Case in Other Side Mode
**Location:** `lib/modes/other_side.dart` line 165
```dart
return ['q', 'b', 'n']; // Lowercase letters
```

**Expected:** `['Q', 'B', 'N']` (uppercase like all other modes)

**Impact:** May cause promotion piece name resolution to fail

**Recommendation:** Change to uppercase for consistency

---

### ⚠️ Issue 2: Kings' Battle Unlocking Logic
**Observation:** `kings_battle.dart` returns `null` (standard promotion), but mode description says "Pawn promotion unlocks all pieces"

**Location:** `lib/modes/kings_battle.dart` line 107
```dart
List<String>? getPromotionPieces(...) {
  // Standard promotion to any piece
  return null; // Use default
}
```

**Question:** Where is the "unlock all pieces" logic implemented?

**Recommendation:** Verify if promotion unlock is handled in `handleSpecialMove()` or elsewhere

---

### ⚠️ Issue 3: Mode Parity Between Controller and Generation
**Current State:**
- Controller checks: `board.gameType != ModesEnum.royalPawns` (line 321)
- Generation checks: All modes individually

**Concern:** If a mode disables promotion, BOTH locations must be updated

**Recommendation:** Consider refactoring to single source of truth:
```dart
// Centralized check
bool shouldShowPromotionDialog(ModesEnum gameType) {
  return gameType != ModesEnum.royalPawns; // Add other no-promotion modes here
}
```

---

## Test Coverage Recommendations

### Test Scenarios Needed

1. **Royal Pawns:** Pawn reaches last rank → no dialog appears ✅ (Fixed)
2. **Snare (no knights):** Pawn reaches last rank → no dialog appears
3. **Snare (1 knight):** Dialog shows ONLY knight option
4. **Snare (2 knights):** Dialog shows Q/R/B (no knight)
5. **Diamonds:** Dialog shows ONLY bishop
6. **Save the Queen:** Dialog shows R/B/N (no queen)
7. **Other Side:** Dialog shows Q/B/N (no rook) - verify case sensitivity
8. **Heir (no king):** Dialog shows ONLY king (forced)
9. **Heir (has king, not promoted):** Dialog shows Q/R/B/N/K
10. **Heir (already promoted king):** Dialog shows Q/R/B/N
11. **Save the King (last pawn, safe):** Dialog shows ONLY king
12. **Save the King (last pawn, attacked):** No dialog, game lost
13. **Kings' Battle:** Verify promotion unlocks all pieces

---

## Files Modified in This Fix

1. ✅ `lib/management/controller.dart` (line 321)
   - Added `&& board.gameType != ModesEnum.royalPawns` check

2. ✅ `lib/board/moves/generation.dart` (lines 251-254)
   - Added Royal Pawns check returning empty list

---

## Conclusion

**Promotion System Status:** ✅ Mostly Working

**Critical Bugs:** ✅ Royal Pawns fixed

**Minor Issues:** ⚠️ Other Side lowercase letters, Kings' Battle unlock verification needed

**Architectural Concern:** Promotion logic split across controller and generation - consider consolidation

**Test Coverage:** Needs comprehensive test suite for all 13 game modes' promotion behaviors
