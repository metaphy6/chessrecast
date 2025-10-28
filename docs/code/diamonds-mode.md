# Diamonds Mode Implementation

## Overview
Diamonds is a bishop-focused chess variant where bishops have a unique capture mechanic.

## Rules

### Bishop Movement
- **Normal Movement**: Bishops move diagonally as in classical chess (any number of squares)
- **Capture Mechanic**: Bishops can ONLY capture in a diamond pattern (8 squares immediately around them)

### Diamond Capture Pattern
For a bishop at position d4, it can capture at:
- c3 (top-left)
- d2 (top)
- e3 (top-right)
- f4 (right)
- e5 (bottom-right)
- d6 (bottom)
- c5 (bottom-left)
- b4 (left)

This forms a diamond/square pattern of 8 squares around the bishop.

### Promotion Rules
- Pawns can ONLY promote to Bishops
- No queen, rook, knight, or king promotions allowed

### Game Ending
- Standard chess checkmate/stalemate/draw rules apply

## Implementation Details

### Files Created/Modified
1. **lib/modes/diamonds.dart** - New mode implementation
2. **lib/board/enums/modes.dart** - Added `diamonds` enum value
3. **lib/modes/modes.dart** - Export diamonds mode
4. **lib/board/moves/generation.dart** - Integrated diamonds filtering

### Key Methods

#### `_getDiamondCapturePositions(Position bishopPos)`
Returns the 8 positions forming the diamond capture zone around a bishop.
Handles edge cases where the bishop is near board edges.

#### `filterMoves(moves, piece, board)`
- For bishops: Filters capture moves to only allow diamond pattern captures
- For non-bishops: Returns moves unchanged
- Allows diagonal movement for bishops (non-capture)
- Blocks diagonal captures outside diamond zone

### Debug Logging
When debug mode is enabled, you'll see:
- `💎 DIAMONDS: Bishop at {pos} diamond capture zone: ...`
- `💎 DIAMONDS: Filtering moves for {color} bishop at {pos}`
- `💎 DIAMONDS: Capture ALLOWED/BLOCKED - {pos} is/not in diamond zone`
- `💎 DIAMONDS: Diagonal move ALLOWED to {pos}`
- `💎 DIAMONDS: Filtered bishop moves: X → Y`
- `💎 DIAMONDS: Pawn promotion - ONLY Bishop allowed`

## Testing Strategy

### Test Case 1: Center Board Bishop
1. Place a white bishop on d4
2. Place black pieces on various squares:
   - c3, e3, c5, e5 (diagonal adjacent - should capture ✓)
   - d2, f4, d6, b4 (orthogonal adjacent - should capture ✓)
   - b2, f2, f6, b6 (2 squares diagonal - should NOT capture ✗)
3. Verify bishop can move diagonally without capturing
4. Verify bishop can only capture in diamond zone

### Test Case 2: Edge Bishop
1. Place a white bishop on a1 (corner)
2. Diamond zone should only have 3 squares: a2, b2, b1
3. Verify incomplete diamond near edges

### Test Case 3: Pawn Promotion
1. Move a pawn to the last rank
2. Verify only Bishop option appears
3. Promote to bishop and verify new bishop follows diamond rules

### Test Case 4: Complex Position
1. Set up a position where:
   - Bishop can move to empty diagonal squares (should work)
   - Bishop has diagonal captures outside diamond (should fail)
   - Bishop has diamond captures (should work)
2. Verify move highlighting shows correct available moves

## Expected Behavior

### Bishop on d4 with enemies on various squares:
- **Can capture**: c3, d2, e3, f4, e5, d6, c5, b4 (diamond zone)
- **Cannot capture**: b2, f2, f6, b6 (diagonal but outside diamond)
- **Can move to**: Any empty diagonal square (a1, b2, c3, e5, f6, g7, h8, etc.)

### Visual Test
```
8 . . . . . . . .
7 . . . . . . . .
6 . . . X . . . .
5 . . X . X . . .
4 . X . B . X . .
3 . . X . X . . .
2 . . . X . . . .
1 . . . . . . . .
  a b c d e f g h

B = Bishop at d4
X = Diamond capture zone
```

## Game Balance Notes
This mode makes bishops:
- **Weaker at long-range captures** (can't snipe from across the board)
- **Stronger in close combat** (can capture in all 8 directions when close)
- **More tactical** (requires positioning bishops near enemy pieces)
- **Promotes aggression** (bishops must get close to capture)
