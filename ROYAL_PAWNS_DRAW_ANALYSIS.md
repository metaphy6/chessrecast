# Royal Pawns Mode - Draw Conditions Analysis

## Overview
This document analyzes the draw conditions applicable to **Royal Pawns** chess variant and verifies their implementation across both frontend (Flutter) and backend (Go).

---

## Royal Pawns Mode Rules

### Special Movement Rules
- **Pawns move like Kings**: Pawns can move one square in ANY direction (8 directions: up, down, left, right, and all 4 diagonals)
- **Pawns capture like Kings**: Pawns can capture in ANY direction (8 directions)
- **No pawn promotion**: Pawns remain pawns even when reaching the opposite end of the board
- **No two-square initial move**: Pawns only move one square at a time (no opening double-step)
- **No en passant**: En passant capture is not available since pawns can capture in all directions

### Game End Conditions (Same as Standard Chess)
1. **Checkmate** - Player is in check with no legal moves
2. **Stalemate** - Player is NOT in check but has no legal moves
3. **Draw by 50-move rule** - 50 full moves (100 half-moves) without pawn move or capture
4. **Draw by threefold repetition** - Same position occurs 3 times

---

## Draw Conditions Applicable to Royal Pawns

### ✅ Condition 1: **Fifty-Move Rule Draw**
**Rule**: A draw can be claimed (or is automatic in some implementations) when 50 consecutive full moves have been made by each side without a pawn move or a capture.

**Technical Details**:
- Tracked via `halfMoveClock` counter
- Resets to 0 on any pawn move
- Resets to 0 on any capture
- Increments by 1 after every non-pawn, non-capture move
- Draw claimed when `halfMoveClock >= 100` (100 half-moves = 50 full moves)

**Frontend Implementation** ✅
- Location: `frontend/lib/board/board.dart` line 347
- Method: `canClaimFiftyMoveRule()`
```dart
bool canClaimFiftyMoveRule() {
  return halfMoveClock >= 100; // 100 half-moves = 50 full moves
}
```
- Location: `frontend/lib/board/moves/execution.dart` lines 131-141
- Automatically triggers draw when condition is met after a move

**Backend Implementation** ✅
- Location: `backend/internal/engine/board.go` line 21
- Field: `FiftyMoveRule int`
- Logic: Resets on pawn move (line 191) or capture (line 166), increments otherwise (line 200)
- Location: `backend/internal/game/service.go` lines 382-389
- Method: `updateGameState()` checks if `FiftyMoveRule >= 100` and sets draw status

**Status**: ✅ **IMPLEMENTED AND SYNCED** - Both frontend and backend properly track and enforce the fifty-move rule.

---

### ✅ Condition 2: **Threefold Repetition Draw**
**Rule**: A draw can be claimed when the same board position occurs three times (not necessarily consecutively).

**Technical Details**:
- Requires position history tracking
- Position key includes: all pieces, current turn, castling rights, en passant target
- Counter reaches 3 on same position (current position is #1, plus 2 repetitions)
- Draw is automatic when threefold repetition occurs

**Frontend Implementation** ✅
- Location: `frontend/lib/board/board.dart` line 353
- Method: `hasThreefoldRepetition()`
```dart
bool hasThreefoldRepetition() {
  if (positionHistory.isEmpty) return false;
  final currentPosition = getPositionKey();
  int count = 1; // Start at 1 to count the current position
  
  for (int i = 0; i < positionHistory.length; i++) {
    if (positionHistory[i] == currentPosition) {
      count++;
      if (count >= 3) {
        printDebug('🔁 THREEFOLD REPETITION DETECTED');
        return true;
      }
    }
  }
  return false;
}
```
- Maintains `positionHistory` list in ChessBoard
- Automatically triggers draw when condition is met

**Backend Implementation** ⚠️ **MISSING/NOT IMPLEMENTED**
- Location: `backend/internal/engine/board.go`
- **Issue**: The Board struct does NOT have a position history tracking mechanism
- **Issue**: The `updateGameState()` method in `backend/internal/game/service.go` only checks:
  - Valid moves availability (checkmate/stalemate)
  - Fifty-move rule
  - **NO threefold repetition check**

**Status**: ⚠️ **PARTIALLY IMPLEMENTED** - Frontend correctly tracks and detects threefold repetition, but backend **does NOT track or enforce threefold repetition**.

---

### ✅ Condition 3: **Stalemate Draw**
**Rule**: If a player has no legal moves but is NOT in check, the game is a draw (stalemate).

**Technical Details**:
- Must check if current player is in check
- Must check if current player has any legal moves
- If no check AND no legal moves = stalemate = draw

**Frontend Implementation** ✅
- Location: `frontend/lib/management/orchestrator.dart`
- Detects stalemate as part of game status evaluation
- Automatically sets game status to stalemate when conditions met

**Backend Implementation** ✅
- Location: `backend/internal/game/service.go` lines 376-389
- Method: `updateGameState()`
```go
if !hasValidMoves {
    // Checkmate or stalemate
    sess.State = engine.Stalemate
    sess.Result = &engine.GameResult{
        State:  engine.Stalemate,
        Reason: "No valid moves available",
    }
    // TODO: Distinguish checkmate from stalemate
}
```
- **Issue**: Backend marks ALL no-move situations as stalemate, doesn't distinguish between checkmate and actual stalemate
- **Note**: The TODO comment indicates this is a known limitation

**Status**: ⚠️ **PARTIALLY IMPLEMENTED** - Both detect no-legal-moves situations, but backend doesn't properly distinguish checkmate from stalemate.

---

### ✅ Condition 4: **Checkmate (Game End)**
**Rule**: If a player is in check and has no legal moves, the opponent wins (not a draw, but game-ending condition).

**Frontend Implementation** ✅
- Location: `frontend/lib/management/orchestrator.dart`
- Properly detects and distinguishes checkmate from stalemate

**Backend Implementation** ⚠️ **PARTIALLY IMPLEMENTED**
- Backend generates valid moves but doesn't distinguish between:
  - Checkmate (in check, no legal moves)
  - Stalemate (NOT in check, no legal moves)
- Both are currently labeled as "Stalemate" in the code (line 384 in service.go)

**Status**: ⚠️ **PARTIALLY IMPLEMENTED** - Frontend works correctly, backend has a known limitation.

---

## Special Considerations for Royal Pawns Mode

### Impact on Draw Conditions

1. **Fifty-Move Rule** ✅
   - **Pawn moves**: Since pawns can move in 8 directions (not just forward), they're still pawn moves
   - **Resets counter**: Any pawn move (in any direction) will reset the fifty-move counter to 0
   - **Effect**: Pawns in Royal Pawns mode are MORE mobile, potentially extending games or creating more pawn activity
   - **Status**: Correctly implemented - pawn identification is based on piece type, not move direction

2. **Threefold Repetition** ✅ (Frontend) ⚠️ (Backend)
   - **No special considerations**: Position repetition logic is identical
   - **Frontend**: Works correctly
   - **Backend**: NOT implemented - need to add position history tracking

3. **Stalemate** ✅ (Detection) ⚠️ (Distinction)
   - **More likely**: Royal Pawns' 8-direction movement may create more stalemate situations
   - **Frontend**: Correctly identifies stalemate
   - **Backend**: Doesn't distinguish checkmate from stalemate

4. **No Promotion Blocking Draws**
   - **Advantage**: Since pawns don't promote, there's NO way to "promote to avoid draw" - draw rules are consistent throughout the game
   - **Status**: ✅ Correctly prevents pawn promotion in Royal Pawns mode (both frontend and backend)

---

## Summary: Implementation Status

| Draw Condition | Frontend | Backend | Synced | Notes |
|---|---|---|---|---|
| **Fifty-Move Rule** | ✅ Implemented | ✅ Implemented | ✅ Yes | Both track and enforce correctly |
| **Threefold Repetition** | ✅ Implemented | ❌ Missing | ❌ No | Frontend has position history, backend does not |
| **Stalemate Detection** | ✅ Implemented | ⚠️ Partial | ⚠️ Partial | Backend can't distinguish checkmate from stalemate |
| **Checkmate/Win Condition** | ✅ Implemented | ⚠️ Partial | ⚠️ Partial | Backend labels all no-move situations as stalemate |
| **Pawn Movement (8 directions)** | ✅ Implemented | ✅ Implemented | ✅ Yes | Both correctly support king-like pawn movement |
| **No Pawn Promotion** | ✅ Implemented | ✅ Implemented | ✅ Yes | Both prevent pawn promotion |

---

## Critical Issues Found

### 🔴 Issue #1: Backend Missing Threefold Repetition (HIGH PRIORITY)
**Problem**: Backend does not track position history or detect threefold repetition
**Impact**: Backend bot games can continue indefinitely in repetitive positions instead of ending in a draw
**Solution**: Add position history tracking to backend Board struct and implement threefold repetition detection in `updateGameState()`

### 🟡 Issue #2: Backend Cannot Distinguish Checkmate from Stalemate (MEDIUM PRIORITY)
**Problem**: Backend marks all no-legal-moves situations as "Stalemate" without checking if king is in check
**Impact**: Frontend and backend may report different game-ending conditions for the same position
**Solution**: Add check detection to `updateGameState()` method to properly classify checkmate vs. stalemate

---

## Recommendations

1. **Immediate**: Fix backend threefold repetition detection to match frontend
2. **Soon**: Distinguish checkmate from stalemate in backend
3. **Optional**: Consider whether 50-move rule should trigger automatic draw or allow claiming (currently auto-draw)
4. **Testing**: Test Royal Pawns mode with:
   - Repetitive move sequences to trigger threefold draw
   - No-legal-moves positions to verify checkmate detection
   - Extended games to verify fifty-move rule works correctly

---

## Code References

**Frontend Draw Condition Detection**:
- `frontend/lib/board/board.dart` (lines 347-375)
- `frontend/lib/board/moves/execution.dart` (lines 131-141)
- `frontend/lib/management/orchestrator.dart`

**Frontend Royal Pawns Rules**:
- `frontend/lib/modes/royal_pawns.dart` (lines 1-100)

**Backend Draw Condition Detection**:
- `backend/internal/game/service.go` (lines 376-389)

**Backend Royal Pawns Rules**:
- `backend/internal/engine/move_generator.go` (lines 135-169)

**Backend Board State**:
- `backend/internal/engine/board.go` (lines 1-200)

---

**Last Updated**: December 4, 2025
**Analyzed by**: Code Review System
