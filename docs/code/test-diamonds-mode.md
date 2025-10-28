# Quick Test: Diamonds Mode

## How to Test

### Method 1: Using Dev Board
1. Go to start screen
2. Click "DEV BOARD SETUP" (if debug mode enabled)
3. Select "Diamonds" mode
4. Place a white bishop on d4
5. Place black pawns on: c3, e3, c5, e5 (diagonal adjacent)
6. Place black pawns on: d2, f4, d6, b4 (orthogonal adjacent)
7. Place a black pawn on b2 (2 squares diagonal)
8. Click "START GAME"

### Expected Behavior
When you select the white bishop on d4:
- ✅ Should show capture moves to: c3, d2, e3, f4, e5, d6, c5, b4 (8 diamond squares)
- ❌ Should NOT show capture to: b2 (diagonal but outside diamond)
- ✅ Should show diagonal movement to empty squares

### Diamond Pattern Visual
```
  a b c d e f g h
8 . . . . . . . .
7 . . . . . . . .
6 . . . ♟ . . . .
5 . . ♟ . ♟ . . .
4 . ♟ . ♗ . ♟ . .
3 . . ♟ . ♟ . . .
2 . ♟ . ♟ . . . .
1 . . . . . . . .

♗ = White Bishop at d4
♟ = Black Pawns
```

## Debug Log Examples

When you select the bishop and try to move, you should see:
```
💎 DIAMONDS: Bishop at d4 diamond capture zone: c3, d2, e3, f4, e5, d6, c5, b4
💎 DIAMONDS: Filtering moves for white bishop at d4
💎 DIAMONDS: Capture ALLOWED - c3 is in diamond zone
💎 DIAMONDS: Capture ALLOWED - d2 is in diamond zone
💎 DIAMONDS: Capture BLOCKED - b2 not in diamond zone
💎 DIAMONDS: Diagonal move ALLOWED to e5
💎 DIAMONDS: Filtered bishop moves: 15 → 12
```

## Pawn Promotion Test
1. Set up a white pawn on e7
2. Move it to e8
3. Promotion dialog should ONLY show Bishop option (no Q, R, N, K)
4. Select Bishop
5. New bishop should follow diamond rules

## Edge Case: Corner Bishop
1. Place white bishop on a1
2. Diamond should only have 3 squares: a2, b2, b1
3. Place black pawns on all 3 squares
4. Verify bishop can capture all 3
5. Verify bishop cannot capture pieces further away diagonally
