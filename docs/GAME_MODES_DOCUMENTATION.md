# Chess Recast - Game Modes Documentation

## Overview
Chess Recast is a novel chess game featuring 14 unique game modes, each introducing different piece movements, board rules, and victory conditions. This document provides a comprehensive analysis of all modes.

---

## Classic Mode
**Description:** Standard chess rules with no modifications.
- All pieces move according to classical chess rules
- Checkmate or stalemate ends the game
- King is protected and cannot be captured while in check
- Win condition: Checkmate opponent's king

---

## Diamonds Mode
**Description:** Bishops have split movement and capture patterns.
**Key Rules:**
- Bishops move diagonally any distance (normal movement)
- Bishops can ONLY capture in a diamond pattern (8 squares adjacent around them: 4 diagonal + 4 orthogonal 2 squares away)
- Example: Bishop at d4 can move diagonally but capture at c3, d2, e3, f4, e5, d6, c5, b4
- Pawns can ONLY promote to Bishops
- Strategic focus: Close-range capture control vs. long-range movement

---

## Friendly Fire Mode
**Description:** Players can capture their own pieces (except kings).
**Key Rules:**
- Can capture your own pieces (strategic sacrifice)
- Cannot capture your own king
- Cannot capture pieces that haven't moved yet (balancing restriction)
- Cannot put yourself in check/checkmate
- Allows for complex piece sacrifices and tactical rearrangement

---

## Heir Mode ⚠️ (BUGGY - NEEDS FIX)
**Description:** Pawns can promote to King; captured kings can be replaced.
**Key Rules:**
- Pawns can promote to King in addition to Q/R/B/N
- Each player can only promote to King once
- King is a regular piece (can be captured by any piece if not defended)
- If king is captured and player has pawns remaining, they lose immediately
- If all pawns AND king are lost, game is over (opponent wins)
- Second king capture = immediate loss
- King promotion cannot result in immediate check
- **CURRENT BUG:** King should be treated as a regular piece, not triggering check/checkmate
- **NEEDS FIX:** King capture mechanics and game-over detection

---

## Kings' Battle Mode
**Description:** Two-phase game with restricted movement until "King's Kill" happens.
**Phase 1 (Before King's Kill):**
- Only pawns and kings can move
- Kings and pawns can capture any piece
- Kings cannot capture each other
- If king captures a pawn = "King's Kill" → triggers Phase 2 + bonus move
- Pawn promotion unlocks all pieces

**Phase 2 (After King's Kill):**
- All pieces can move normally
- Standard chess rules apply

---

## Coyote Mode
**Description:** Race to get your rook to opponent's back rank.
**Win Conditions:**
- Your rook reaches opponent's back rank (rank 8 for white, rank 1 for black)
- Checkmate opponent's king
- Capture BOTH opponent's rooks (instant win)

**Special Rules:**
- Pawns move normally but cannot promote to rooks
- Losing both rooks = immediate loss
- Rooks can only capture opponent rooks (not other pieces)
- No castling allowed

---

## Mercenary Mode
**Description:** Pawns move and capture like Kings.
**Key Rules:**
- Pawns can move one square in ANY direction (8 directions like a King)
- Pawns can capture in ANY direction
- Pawns CANNOT promote (remain pawns even on last rank)
- No two-square initial move
- No en passant
- Significantly more mobile and dangerous pawn structure
- Standard 100 half-move draw rule applies (pawn moves count as regular moves)
- **Insufficient material:** K vs K, K+P vs K+P, K+N vs K+N (when no pawns remain)
- Pawns can assist in checkmates (like extra kings), so K+N vs K with pawns is NOT insufficient

---

## Succession Mode
**Description:** Race to promote a pawn to King; each side starts with two queens.
**Setup:**
- Each side has TWO queens (no king initially)
- 8 pawns per side as normal
- All other pieces standard

**Rules:**
- First player to promote a pawn to King wins immediately
- Can promote to Rook, Bishop, or Knight (NOT Queen - already have 2)
- Your LAST pawn MUST promote to King (no choice)
- Cannot promote to King if promotion square is under attack
- **Instant loss conditions:**
  - Any of your queens are captured
  - You lose all of your pawns (no way to promote to King)
- 50 half-move draw rule applies (25 white + 25 black with no captures/pawn moves)

---

## Save the Queen Mode
**Description:** Queens are prisoners that must escape to their own half of the board.
**Queen States:**

1. **PRISONER (in opponent's half):**
   - Moves like a King (one square in any direction)
   - CANNOT capture or checkmate
   - White queen starts at d8 (black's territory)
   - Black queen starts at d1 (white's territory)

2. **ESCAPED (reached own half):**
   - Moves and captures like a regular queen
   - Can checkmate
   - If captured = GAME OVER (instant win for capturer)

3. **RECAPTURED (captured while prisoner):**
   - Returns to initial prison position
   - Becomes prisoner again

**Special Rules:**
- If escaped queen moves back to opponent's half = becomes prisoner again
- Pawns CANNOT promote to Queen
- Queens CANNOT be captured while on their initial prison squares (d1 for black, d8 for white)
- Capturing an escaped queen (in own territory) = instant win/checkmate
- Regular checkmate possible with other pieces

---

## Snare Mode
**Description:** Knights create entangle zones that trap enemy pieces.
**Key Rules:**
- When two knights of same color defend each other (knight's move apart), they create an "entangle zone"
- Pieces in entangle zone can only:
  - Move one square in any direction (king-like) to escape
  - Move within the zone if alone
  - Capture adjacent entangled enemy pieces
- King can move anywhere as long as at least one friendly knight is alive
- King cannot be in check if knights exist
- Last knight captured = "revengeful" - both pieces destroyed
- Promotion restrictions: No knights = no promotions; 1 knight = must promote to knight

---

## Secret Passage Mode
**Description:** Kings and rooks can swap positions when aligned.
**Rules:**
- Kings can teleport with friendly rooks on the same rank or file
- Secret passage swaps positions instantly
- Safe corridor requirements:
  1. King must NOT be under attack
  2. Rook must NOT be under attack
  3. No pieces between king and rook
  4. No opponent piece attacking ANY square on the passage line
- No castling allowed
- All other pieces move normally

---

## Truce Mode
**Description:** No captures allowed until all pieces have moved once.
**Rules:**
- Players cannot capture opponent pieces during truce
- Truce breaks when one player has moved all their pieces at least once
- During truce, no piece can be moved more than 3 times
- NO check or checkmate during truce (kings move freely)
- Once truce broken, normal chess rules apply including check and checkmate

---

## Summary Table

| Mode | Core Mechanic | Complexity | Win Condition |
|------|---------------|-----------|--------------|
| Classic | None | Low | Checkmate |
| Diamonds | Bishop diamond capture | Medium | Checkmate |
| Friendly Fire | Capture own pieces | Medium | Checkmate (with sacrifice) |
| Heir | King as regular piece | High | Capture king + pawns |
| Kings' Battle | Two-phase movement | Medium | Checkmate (after unlock) |
| Coyote | Rook race | Medium | Rook to back rank |
| Mercenary | King-like pawns | Low | Checkmate |
| Succession | Two queens, pawn race | High | First king promotion |
| Save the Queen | Prisoner queen escape | High | Queen escape + capture |
| Snare | Knight entangle zones | Very High | Checkmate (knights alive) |
| Secret Passage | King-rook swap | Medium | Checkmate |
| Truce | Delayed combat | Medium | Checkmate (after truce break) |

---

## Key Innovation Patterns

1. **Movement Restrictions:** Diamonds, Mercenary
2. **Piece State Management:** Heir, Save the Queen
3. **Asymmetric Objectives:** Coyote, Succession, Secret Passage
4. **Dynamic Board Rules:** Kings' Battle, Truce, Snare
5. **Capture Modifications:** Diamonds, Friendly Fire, Snare
