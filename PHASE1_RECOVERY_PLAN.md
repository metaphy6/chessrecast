# Phase 1 Execution Status & Recovery Plan

## Current Situation

⚠️ **WARNING**: `lib/game/board/board.dart` is currently in a **CORRUPTED STATE**

### What Happened
During the initial attempt to remove duplicate code, an incomplete text replacement left the file in an invalid state:
- Lines ~122-130: Broken method with undefined variables (`knight1`, `knight2`)
- Method `isPositionUnderAttack()` contains code from `_getEntangleZone()`
- File will not compile in current state

### File Status
- **Git status**: Untracked (not committed)
- **Compile status**: ❌ BROKEN
- **Current size**: 2044 lines
- **Target size after cleanup**: ~1150 lines

## Recovery Options

### Option 1: Manual Fix (Recommended)
Since the file was never committed to git and is corrupted, we need to manually fix it:

1. **Immediate Fix**: Restore the broken `isPositionUnderAttack()` method
2. **Then Continue**: Remove all duplicate mode-specific code systematically

### Option 2: Recreate from Scratch
If the corruption is too extensive, we can:
1. Look for any backup versions
2. Or use the mode files as reference to rebuild board.dart cleanly

## Immediate Action Required

### Step 1: Fix Broken isPositionUnderAttack() Method

**Current (BROKEN):**
```dart
/// Checks if the specified position is under attack by the specified color
bool isPositionUnderAttack(Position position, PieceColor attackingColor) {
  // The entangle zone consists of the 2 squares that lie on a straight line
  // (horizontal or vertical) between the two knights
  // Example: c2 and d4 → zone is c3 and d3 (vertical line on column c and d)

  final zone = <Position>[];

  final row1 = knight1.position.row;  // ❌ UNDEFINED
  final col1 = knight1.position.col;  // ❌ UNDEFINED
  // ... more broken code ...
}
```

**Should Be:**
```dart
/// Checks if the specified position is under attack by the specified color
bool isPositionUnderAttack(Position position, PieceColor attackingColor) {
  final attackingPieces = getPiecesOfColor(attackingColor);
  return attackingPieces.any((piece) => piece.canAttack(position, pieces));
}
```

### Step 2: Remove All Snare Mode Methods

After fixing the immediate corruption, remove these methods (lines approximately):

1. `getKnights()` - Line ~123-130
2. `_areKnightsDefending()` - Line ~132-140
3. `_getEntangleZone()` - Line ~142-178
4. `getEntangleInfo()` - Line ~180-210
5. `isPieceEntangled()` - Line ~212-248
6. `getEntangleZoneForPiece()` - Line ~250-262
7. `isKingEntangled()` - Line ~296-304
8. `_getEntangledPieceMoves()` - Line ~510-640
9. `_getPathThroughZone()` - Line ~459-475
10. `_getPathBetween()` - Line ~477-508

**Total to remove**: ~450 lines

### Step 3: Remove Heir Mode Methods

1. `_getHeirPawnMoves()` - Line ~889-1004
2. `_wouldKingPromotionBeInCheck()` - Line ~862-887
3. `isHeirGameEnd()` - Line ~1629-1673

**Total to remove**: ~140 lines

### Step 4: Remove Royal/Shifty Pawns Methods

1. `_getRoyalPawnMoves()` - Line ~1006-1172
2. `_getShiftyPawnMoves()` - Line ~1174-1315

**Total to remove**: ~200 lines

### Step 5: Simplify Core Methods

Remove gameType-specific logic from:

1. **`_getPawnMoves()`** - Lines ~658-677
   - Remove: `if (gameType == GameType.royalPawns) return _getRoyalPawnMoves(pawn);`
   - Remove: `if (gameType == GameType.shiftyPawns) return _getShiftyPawnMoves(pawn);`
   - Remove: `if (gameType == GameType.heir) return _getHeirPawnMoves(pawn);`

2. **`getPromotionPieces()`** - Lines ~798-860
   - Remove all `if (gameType == ...)` blocks
   - Keep only: `return ['Q', 'R', 'B', 'N'];`

3. **`getValidMovesFor()`** - Lines ~306-456
   - Remove: Snare entanglement check (lines ~336-338)
   - Remove: Snare suicide logic (lines ~348-356)
   - Remove: Snare zone filtering (lines ~371-456)

4. **`isKingInCheck()`** - Lines ~269-294
   - Remove: Snare entanglement check (lines ~281-285)

5. **`makeMove()`** - Lines ~1758-1963
   - Remove: Snare entanglement check (lines ~1914-1930)
   - Remove: Heir king promotion tracking (lines ~1867-1881)

## Detailed Fix Script

### Fix 1: Restore isPositionUnderAttack()

Search for:
```dart
  /// Checks if the specified position is under attack by the specified color
  bool isPositionUnderAttack(Position position, PieceColor attackingColor) {
    // The entangle zone consists of the 2 squares that lie on a straight line
```

Replace entire method with:
```dart
  /// Checks if the specified position is under attack by the specified color
  bool isPositionUnderAttack(Position position, PieceColor attackingColor) {
    final attackingPieces = getPiecesOfColor(attackingColor);
    return attackingPieces.any((piece) => piece.canAttack(position, pieces));
  }
```

### Fix 2-4: Delete Method Blocks

For each method listed above, find the method declaration and delete the entire method including:
- The doc comment (`/// ...`)
- The method signature
- The method body
- Up to (but not including) the next method or closing brace

## Testing After Each Fix

After each change, run:
```bash
flutter analyze lib/game/board/board.dart
```

If errors appear, they should only be about missing methods (which is expected as we remove them).

## Final Verification

After all fixes:
1. ✅ File should be ~1150 lines (down from 2044)
2. ✅ No mode-specific methods remain
3. ✅ No gameType checks in core methods
4. ✅ File should compile (though functionality will be broken until Phase 2)

## Next Steps

Once Phase 1 is complete:
- Proceed to Phase 2 (Integration)
- Add GameMode field to ChessBoard
- Implement mode delegation
- Restore full functionality

## Questions?

If you encounter any issues during the cleanup:
1. Check the line numbers (they shift as code is deleted)
2. Use the method names to search
3. Look for the doc comments as markers
4. Make sure to delete complete methods (not partial)

Would you like me to:
A) Attempt to fix the immediate corruption automatically
B) Provide a step-by-step guided fix
C) Generate a clean board.dart file from scratch
