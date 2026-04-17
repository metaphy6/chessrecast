# 🤝 Draw Rules by Mod

> Last updated: 2026-04-17
>
> This document is the authoritative reference for how draws are decided
> in every active game mode. Each rule is verified against the actual codebase
> and includes code snippets, field locations, and worked examples.

---

## 📐 Architecture — Centralized `DrawRules` Class

All draw thresholds and policies are defined in a **single source of truth**:

📁 `frontend/lib/board/draw_rules.dart` — `DrawRules`

Both the board auto-draw path and the orchestrator status path delegate to
this class, guaranteeing identical thresholds everywhere.

### Path 1 — 🔄 Board Auto-Draw (immediate, after move execution)

📁 `frontend/lib/board/moves/execution.dart`

Right after a move is applied, `shouldAutoDraw()` is called on the new board.
If it returns `true`, the game ends **immediately**.

```dart
if (newBoard.shouldAutoDraw()) {
  return newBoard.copyWith(gameStatus: GameStatus.draw);
}
```

`shouldAutoDraw()` combines three checks:

📁 `frontend/lib/board/board.dart` — `shouldAutoDraw()`

```dart
bool shouldAutoDraw() {
  if (canClaimFiftyMoveRule() || hasThreefoldRepetition()) {
    return true;
  }

  // Save the Queen: same piece captures prisoner queen from the same square
  // three times → automatic draw.
  if (gameType == ModsEnum.saveTheQueen) {
    for (final count in queenCaptureCounter.values) {
      if (count >= DrawRules.queenCaptureRepeatThreshold) {
        return true;
      }
    }
  }

  return false;
}
```

`canClaimFiftyMoveRule()` delegates to `DrawRules`:

```dart
bool canClaimFiftyMoveRule() {
  final threshold = DrawRules.fiftyMoveThreshold(
    gameType: gameType,
    whitePieces: getPiecesOfColor(PieceColor.white),
    blackPieces: getPiecesOfColor(PieceColor.black),
  );
  return halfMoveClock >= threshold;
}
```

### Path 2 — 🎮 Orchestrator Status Check (after board auto-draw)

📁 `frontend/lib/management/orchestrator.dart` — `updateGameStatus()`

If the board didn't auto-draw, the orchestrator runs its own draw checks.
All delegate to `DrawRules`:

```dart
if (_isDrawByInsufficientMaterial(board)) {
  newStatus = GameStatus.draw;
} else if (_isDrawByRepetition(board)) {
  newStatus = GameStatus.draw;
} else if (_isDrawByFiftyMoveRule(board)) {
  newStatus = GameStatus.draw;
}
```

Both `_isDrawByInsufficientMaterial()` and `_isDrawByFiftyMoveRule()` delegate
to `DrawRules.isInsufficientMaterial()` and `DrawRules.fiftyMoveThreshold()`
respectively.

> ⚠️ **Note**: `_isDrawByRepetition()` is currently a **placeholder**
> that always returns `false`. Threefold repetition draws are handled
> entirely by the board auto-draw path (Path 1).

### ✅ Why this is better than before

Before the centralization, board and orchestrator had **independent**
threshold logic that could diverge. Now both paths read from the same
`DrawRules` class — any threshold change is made once and applies everywhere.

---

## ⏱️ Half-Move Clock — The Engine Behind the 50-Move Rule

### 📍 Field definition

📁 `frontend/lib/board/board.dart`

```dart
final int halfMoveClock; // For 50-move rule
```

Initialized to `0` on board creation. Incremented or reset after every move.

### 🔄 Clock reset rules

📁 `frontend/lib/board/moves/execution.dart`

Clock reset policy is centralized in `DrawRules.shouldResetHalfMoveClock()`:

```dart
final isPawnMove = move.piece.type == PieceType.pawn;
final shouldResetClock = DrawRules.shouldResetHalfMoveClock(
  gameType: gameType,
  isPawnMove: isPawnMove,
  isCapture: move.capturedPiece != null,
);
final newHalfMoveClock = shouldResetClock ? 0 : halfMoveClock + 1;
```

📁 `frontend/lib/board/draw_rules.dart` — `shouldResetHalfMoveClock()`

```dart
static bool shouldResetHalfMoveClock({
  required ModsEnum gameType,
  required bool isPawnMove,
  required bool isCapture,
}) {
  if (isCapture) return true;
  if (isPawnMove && gameType != ModsEnum.mercenary) return true;
  return false;
}
```

| Event | Classic / most mods | 🗡️ Mercenary |
|---|---|---|
| Any capture | Clock → 0 | Clock → 0 |
| Pawn move (no capture) | Clock → 0 | ⚡ Clock **+1** (does NOT reset!) |
| Other move | Clock +1 | Clock +1 |

> 🧩 **Why Mercenary is different**: In Mercenary, pawns can assist in
> checkmate like kings. Pawn moves are "normal" — they don't represent
> progress toward a decisive position, so they don't reset the clock.

### 💡 Example — Mercenary clock behavior

```
Move 1: White pawn e2→e4       → halfMoveClock = 1  (pawn move, NOT reset in Mercenary)
Move 2: Black pawn e7→e5       → halfMoveClock = 2  (same)
Move 3: White knight g1→f3     → halfMoveClock = 3
Move 4: Black pawn d7→d5       → halfMoveClock = 4  (still NOT reset)
Move 5: White pawn e4 x d5     → halfMoveClock = 0  (capture DOES reset)
```

Compare with Classic:
```
Move 1: White pawn e2→e4       → halfMoveClock = 0  (pawn move → reset)
Move 2: Black pawn e7→e5       → halfMoveClock = 0  (pawn move → reset)
Move 3: White knight g1→f3     → halfMoveClock = 1
Move 4: Black pawn d7→d5       → halfMoveClock = 0  (pawn move → reset)
Move 5: White pawn e4 x d5     → halfMoveClock = 0  (capture → reset)
```

---

## 📏 Fifty-Move Rule Thresholds

📁 `frontend/lib/board/draw_rules.dart` — `fiftyMoveThreshold()`

```dart
static int fiftyMoveThreshold({
  required ModsEnum gameType,
  required List<ChessPiece> whitePieces,
  required List<ChessPiece> blackPieces,
}) {
  // Succession: always 50 half-moves
  if (gameType == ModsEnum.succession) {
    return 50;
  }

  // Mercenary: 50 for one-side-only-king endgames
  if (gameType == ModsEnum.mercenary) {
    if (_isMercenaryAcceleratedEndgame(whitePieces, blackPieces)) {
      return 50;
    }
  }

  // Default for all other mods / positions
  return 100;
}
```

### 🔍 Mercenary accelerated endgame detection

```dart
static bool _isMercenaryAcceleratedEndgame(
  List<ChessPiece> whitePieces,
  List<ChessPiece> blackPieces,
) {
  final whiteOnlyKing = whitePieces.length == 1 &&
      whitePieces.first.type == PieceType.king;
  final blackOnlyKing = blackPieces.length == 1 &&
      blackPieces.first.type == PieceType.king;

  if (!whiteOnlyKing && !blackOnlyKing) return false;

  final strongerSide = whiteOnlyKing ? blackPieces : whitePieces;
  final hasPawn = strongerSide.any((p) => p.type == PieceType.pawn);

  // Pure piece-vs-King (no pawns) → accelerated
  if (!hasPawn) return true;

  // King + single Pawn vs King → accelerated
  final isKingAndPawnOnly = strongerSide.length == 2 &&
      strongerSide.any((p) => p.type == PieceType.king) &&
      hasPawn;
  return isKingAndPawnOnly;
}
```

### 📊 Complete threshold matrix

| Mod | Position | Threshold | Source |
|---|---|---|---|
| ♟️ Classic | All | **100 half-moves** | Default |
| 🗡️ Mercenary | K+P vs K | **50 half-moves** | `_isMercenaryAcceleratedEndgame` |
| 🗡️ Mercenary | Pawnless piece-vs-K (e.g. K+R vs K) | **50 half-moves** | `_isMercenaryAcceleratedEndgame` |
| 🗡️ Mercenary | Other positions | **100 half-moves** | Default |
| 👑 Succession | All | **50 half-moves** | Explicit mod check |
| 👸 Save the Queen | All | **100 half-moves** | Default |
| 🏰 Heir | All | **100 half-moves** | Default |
| 🕊️ Truce | All | **100 half-moves** | Default |
| 🔥 Friendly Fire | All | **100 half-moves** | Default |
| ⚔️ Kings' Battle | All | **100 half-moves** | Default |

### 💡 Example — K+P vs K in Mercenary

```
Position: White King e1 + White Pawn d5  vs  Black King e8
Clock starts at 0 after the last capture.

Half-move 49 (White's 25th move): halfMoveClock = 49
  → DrawRules.fiftyMoveThreshold() → _isMercenaryAcceleratedEndgame → true → 50
  → halfMoveClock >= 50? → NO (49 < 50) → game continues ▶️

Half-move 50 (Black's 25th move): halfMoveClock = 50
  → DrawRules.fiftyMoveThreshold() → 50
  → halfMoveClock >= 50? → YES
  → shouldAutoDraw() → true → GameStatus.draw 🤝
```

---

## 🔁 Threefold Repetition

### 📍 Fields

📁 `frontend/lib/board/board.dart`

```dart
final List<String> positionHistory; // For threefold repetition
```

After every move, the new position key is appended:

📁 `frontend/lib/board/moves/execution.dart`

```dart
newBoard = newBoard.copyWith(
  positionHistory: [...positionHistory, newBoard.getPositionKey()],
);
```

### 🔍 Detection logic

📁 `frontend/lib/board/board.dart` — `hasThreefoldRepetition()` + `shouldAutoDraw()`

```dart
bool shouldAutoDraw() {
  if (canClaimFiftyMoveRule() || hasThreefoldRepetition()) {
    return true;
  }

  // Save the Queen: same piece captures prisoner queen from the same square
  // three times → automatic draw.
  if (gameType == ModsEnum.saveTheQueen) {
    for (final count in queenCaptureCounter.values) {
      if (count >= DrawRules.queenCaptureRepeatThreshold) {
        return true;
      }
    }
  }

  return false;
}
```

```dart
bool hasThreefoldRepetition() {
  if (positionHistory.isEmpty) return false;

  final currentPosition = getPositionKey();
  int count = 0;

  for (int i = 0; i < positionHistory.length; i++) {
    if (positionHistory[i] == currentPosition) {
      count++;
      if (count >= 3) {
        return true;
      }
    }
  }

  return false;
}
```

**Threshold constant**: `DrawRules.threefoldRepetitionCount = 3`

> 📌 Position keys encode: piece placement, current player, castling rights,
> and en passant target. This matches the standard chess definition of
> "same position."

### 💡 Example

```
Move 1: Nf3   → history: [pos_A]
Move 2: Nf6   → history: [pos_A, pos_B]
Move 3: Ng1   → history: [pos_A, pos_B, pos_C]
Move 4: Ng8   → history: [pos_A, pos_B, pos_C, pos_A]     ← pos_A seen 2×
Move 5: Nf3   → history: [pos_A, pos_B, pos_C, pos_A, pos_B]
Move 6: Nf6   → history: [pos_A, pos_B, pos_C, pos_A, pos_B, pos_A]
                                                              ↑ pos_A seen 3× → 🤝 DRAW
```

### ✅ Applies to all mods

Threefold repetition is checked via `shouldAutoDraw()` which runs for every
mod. No mod overrides or disables it.

---

## ♟️ Insufficient Material

📁 `frontend/lib/board/draw_rules.dart` — `isInsufficientMaterial()`

```dart
static bool isInsufficientMaterial({
  required ModsEnum gameType,
  required List<ChessPiece> whitePieces,
  required List<ChessPiece> blackPieces,
}) {
  if (gameType == ModsEnum.mercenary) {
    return _isInsufficientMaterialMercenary(whitePieces, blackPieces);
  }
  if (gameType == ModsEnum.heir) {
    return _isInsufficientMaterialHeir(whitePieces, blackPieces);
  }
  return _isInsufficientMaterialClassic(whitePieces, blackPieces);
}
```

### 📋 Classic insufficient material

Applies to: Classic, Truce, Friendly Fire, Kings' Battle, Save the Queen, Succession.

| Position | Draw? | Why |
|---|---|---|
| ♚ vs ♚ | ✅ Yes | No mating material at all |
| ♚♗ vs ♚ | ✅ Yes | Single bishop can't deliver mate |
| ♚♞ vs ♚ | ✅ Yes | Single knight can't deliver mate |
| ♚♗ vs ♚♗ (same-color squares) | ✅ Yes | Bishops can't cover all squares |
| ♚♗ vs ♚♗ (different-color squares) | ❌ No | Theoretically possible to mate |
| ♚♞♞ vs ♚ | ❌ No | Technically possible (though difficult) |

### 🗡️ Mercenary insufficient material

| Position | Draw? | Why |
|---|---|---|
| ♚ vs ♚ | ✅ Yes | No mating material |
| ♚♞ vs ♚♞ (no pawns on board) | ✅ Yes | Knights alone can't force mate in Mercenary |
| ♚♟ vs ♚ | ❌ No | Pawn can assist in checkmate! |
| ♚♗ vs ♚ | ✅ Yes | Falls back to classic check |
| ♚♞ vs ♚ | ✅ Yes | Falls back to classic check |
| Any position with pawns | ❌ No | Pawns can always help |

> 🧩 **Key insight**: The presence of pawns blocks *any* insufficient-material
> draw in Mercenary. Even K+P vs K is not drawn by material — it's only drawn
> by the 50 half-move clock.

### 🏰 Heir insufficient material

Only **K vs K** is insufficient. All other material configurations can
potentially lead to checkmate in Heir because kings are capturable by
non-king pieces.

---

## 👸 Save the Queen — Draw Rules

### 🎭 How the mod works (draw-relevant summary)

Both queens begin **imprisoned** on the opponent's back rank and must escape to their own half:

| Queen | Starts at | Escapes when reaching |
|---|---|---|
| White ♛ | d8 (row 7, black's back rank) | Ranks 1–4 (rows 0–3, white's own half) |
| Black ♛ | d1 (row 0, white's back rank) | Ranks 5–8 (rows 4–7, black's own half) |

```
  ┌──────────────────────────────────┐
8 │  . . . ♛ . . . .   ← White queen imprisoned here (d8)
7 │  . . . . . . . .   │ Black's half (ranks 5-8)
6 │  . . . . . . . .   │ White must escape THROUGH this zone
5 │  . . . . . . . .   │
  ├──────────────────────────────────┤ ← Escape boundary
4 │  . . . . . . . .   │ White's half (ranks 1-4)
3 │  . . . . . . . .   │ Black must escape THROUGH this zone
2 │  . . . . . . . .   │
1 │  . . . ♛ . . . .   ← Black queen imprisoned here (d1)
  └──────────────────────────────────┘
     a  b  c  d  e  f  g  h
```

Each queen has **three states**:

| State | Where the queen is | Mobility | Capturable? |
|---|---|---|---|
| **PRISONER** | In opponent's half (not on prison square) | King-like: 1 square, no captures | ✅ Returns to prison |
| **On prison square** | Exactly on d8 (white) or d1 (black) | King-like | ❌ Immune — cannot be captured |
| **ESCAPED** | In own half | Full queen power, can capture & checkmate | ✅ Instant win for capturer |

> ⚡ **Win conditions** (not draws — context for why draws matter):
> 1. Capture the opponent's **escaped** queen → instant win
> 2. Your escaped queen reaches the opponent's **prison square** (d1 / d8) → instant win
> 3. Standard checkmate with other pieces → win
>
> Draws occur when neither side can achieve these goals decisively.

---

### 🚦 Draw Trigger 1 — Repeated Queen Capture (same piece, same square)

If the **same piece** captures a **prisoner queen** from the **same square** three times, the game is drawn. The capture counter tracks each unique combination of `attacker_color + piece_type + square + victim_color`.

📁 `frontend/lib/board/draw_rules.dart`

```dart
static const int queenCaptureRepeatThreshold = 3;
```

📁 `frontend/lib/mods/savequeen.dart` — capture key format:

```dart
final captureKey =
    '${move.piece.color}_${move.piece.type.name}_${move.from.row}_${move.from.col}_captures_${capturedQueen.color}';
```

📁 `frontend/lib/board/board.dart` — checked in `shouldAutoDraw()`:

```dart
if (gameType == ModsEnum.saveTheQueen) {
  for (final count in queenCaptureCounter.values) {
    if (count >= DrawRules.queenCaptureRepeatThreshold) {
      return true;
    }
  }
}
```

> 💡 **Why this exists**: A prisoner queen that is captured respawns at its prison square. Without this rule, one side could farm the prisoner queen endlessly. The counter detects this loop for same-piece-same-square captures. For **different** pieces capturing the prisoner queen, **threefold repetition** (Draw Trigger 3) handles it naturally.

#### 💡 Example — Same rook captures prisoner queen 3 times

```
White rook on d5. Black prisoner queen escapes to d7.

1. Rd5×Qd7 → Black queen respawns at d1 (prison) → counter["white_rook_4_3_captures_black"] = 1
   ... Black queen moves d1→d2→d3→...→d7 again ...
2. Rd5×Qd7 → Black queen respawns at d1 → counter["white_rook_4_3_captures_black"] = 2
   ... Black queen moves d1→d2→...→d7 again ...
3. Rd5×Qd7 → counter["white_rook_4_3_captures_black"] = 3
   → 3 >= queenCaptureRepeatThreshold (3) → shouldAutoDraw() → 🤝 DRAW
```

#### 💡 Example — Different pieces capture → no counter draw, threefold applies

```
White rook captures black prisoner queen from d5: counter["white_rook_4_3_captures_black"] = 1
White bishop captures black prisoner queen from c4: counter["white_bishop_3_2_captures_black"] = 1
White rook captures black prisoner queen from d5: counter["white_rook_4_3_captures_black"] = 2
White bishop captures black prisoner queen from c4: counter["white_bishop_3_2_captures_black"] = 2
→ Neither counter reaches 3, but the board positions repeat → threefold repetition → 🤝 DRAW
```

---

### 🚦 Draw Trigger 2 — Fifty-Move Rule (100 half-moves)

Save the Queen uses the same **100 half-move** threshold as Classic. All captures (including prisoner queen captures) reset the clock, and pawn moves reset the clock.

📁 `frontend/lib/board/draw_rules.dart` — `fiftyMoveThreshold()`

Save the Queen is not special-cased — it falls through to the default `return 100`.

---

### 🚦 Draw Trigger 3 — Threefold Repetition

Standard threefold repetition applies. Because prisoner queens move king-like (one square at a time), they can easily oscillate between adjacent squares and recreate the same board position three times without either side making progress.

📁 `frontend/lib/board/board.dart` — `hasThreefoldRepetition()`

```dart
bool hasThreefoldRepetition() {
  final currentPosition = getPositionKey();
  int count = 0;
  for (final pos in positionHistory) {
    if (pos == currentPosition) {
      count++;
      if (count >= DrawRules.threefoldRepetitionCount) return true; // = 3
    }
  }
  return false;
}
```

#### 💡 Example — Prisoner oscillation leading to repetition

```
White queen prisoner at e8, Black queen prisoner at e1.
Neither queen can break out; pieces block their paths.

Turns 1–2:  White queen: e8→d8→e8  (oscillates)
Turns 3–4:  White queen: e8→d8→e8  ← same position as start, count = 2
Turns 5–6:  White queen: e8→d8→e8  ← same position again, count = 3
            → hasThreefoldRepetition() → true → shouldAutoDraw() → 🤝 DRAW
```

---

### 🚦 Draw Trigger 4 — Stalemate

Standard stalemate: active player has no legal moves and is not in check. Because prisoner queens cannot capture, a stalemate can occur even with material on the board if all pieces are blocked and the king has no safe squares.

---

### 🚦 Draw Trigger 5 — Insufficient Material

Classic insufficient-material rules apply. In practice this is rare because both queens are usually present (as prisoners if not escaped). However, if both queens are permanently removed (captured when their prison square was occupied), classic material checks apply to the remaining pieces.

---

## 🎮 Per-Mod Draw Rules — Detailed Breakdown

---

### ♟️ Classic

| Draw mechanism | Active? | Threshold / Condition |
|---|---|---|
| Stalemate | ✅ | No legal moves, not in check |
| Insufficient material | ✅ | Classic set (K vs K, K+B/N vs K, same-color K+B vs K+B) |
| Fifty-move rule | ✅ | 100 half-moves |
| Threefold repetition | ✅ | 3× same position |
| Mod-specific draw | ❌ | — |

---

### 🗡️ Mercenary

| Draw mechanism | Active? | Threshold / Condition |
|---|---|---|
| Stalemate | ✅ | No legal moves, not in check |
| Insufficient material | ✅ | Mercenary-specific (see table above) |
| Fifty-move rule | ✅ | **K+P vs K: 50** · Pawnless piece-vs-K: **50** · Other: 100 |
| Threefold repetition | ✅ | 3× same position |
| Mod-specific draw | ❌ | — |

**⚡ Unique behaviors:**
- Pawn moves **do not** reset the half-move clock
- K+P vs K accelerated to 50 half-moves
- Pawnless mop-up endgames accelerated to 50 half-moves
- Pawns block insufficient-material draw (they can assist checkmate)

---

### 🏰 Heir

| Draw mechanism | Active? | Threshold / Condition |
|---|---|---|
| Stalemate | ✅ | Custom Heir flow in orchestrator |
| Insufficient material | ✅ | **K vs K only** |
| Fifty-move rule | ✅ | 100 half-moves |
| Threefold repetition | ✅ | 3× same position |
| Mod-specific draw | ❌ | — |

---

### 🕊️ Truce

| Draw mechanism | Active? | Threshold / Condition |
|---|---|---|
| Stalemate | ✅ | During truce: no legal moves → stalemate. After truce: standard. |
| Insufficient material | ✅ | Classic set |
| Fifty-move rule | ✅ | 100 half-moves |
| Threefold repetition | ✅ | 3× same position |
| Mod-specific draw | ❌ | — |

---

### 🔥 Friendly Fire

| Draw mechanism | Active? | Threshold / Condition |
|---|---|---|
| Stalemate | ✅ | Standard |
| Insufficient material | ✅ | Classic set |
| Fifty-move rule | ✅ | 100 half-moves |
| Threefold repetition | ✅ | 3× same position |
| Mod-specific draw | ❌ | — |

---

### ⚔️ Kings' Battle

| Draw mechanism | Active? | Threshold / Condition |
|---|---|---|
| Stalemate | ✅ | Standard |
| Insufficient material | ✅ | Classic set |
| Fifty-move rule | ✅ | 100 half-moves |
| Threefold repetition | ✅ | 3× same position |
| Mod-specific draw | ❌ | — |

---

### 👸 Save the Queen

| Draw mechanism | Active? | Threshold / Condition |
|---|---|---|
| Stalemate | ✅ | Standard |
| Insufficient material | ✅ | Classic set |
| Fifty-move rule | ✅ | **100 half-moves** (same as Classic) |
| Threefold repetition | ✅ | 3× same position |
| Queen capture counter | ✅ | Same piece, same square captures prisoner queen **3 times** → draw |

**⚡ Unique behaviors:**
- Queens start **imprisoned** on the opponent's back rank (white at d8, black at d1)
- Prisoner queens move **king-like** (1 square, no captures) — these moves do **not** reset the clock
- Queen on its exact prison square is **immune** to capture
- Capturing a prisoner queen sends it back to prison (if prison is empty)
- Same piece capturing prisoner queen from the same square 3 times → **automatic draw**
- Different pieces capturing → **threefold repetition** handles it naturally
- Capturing an **escaped** queen → **instant win** (not a draw)

---

### 👑 Succession

| Draw mechanism | Active? | Threshold / Condition |
|---|---|---|
| Stalemate | ✅ | Custom: no-move + no-check → draw |
| Insufficient material | ✅ | Classic set |
| Fifty-move rule | ✅ | **50 half-moves** (25+25) |
| Threefold repetition | ✅ | 3× same position |
| Mod-specific draw | ❌ | Variant victory/loss conditions can end game before draw triggers |

---

## 📊 Master Summary Table

| Mod | Stalemate | Insufficient Material | 50-Move Threshold | 3× Repetition | Extra Draw |
|---|---|---|---|---|---|
| ♟️ Classic | ✅ Standard | Classic set | 100 half-moves | ✅ | — |
| 🗡️ Mercenary | ✅ Standard | Mercenary-specific ¹ | K+P vs K: **50** · Piece-vs-K: **50** · Other: 100 | ✅ | Pawn moves don't reset clock |
| 🏰 Heir | ✅ Custom flow | K vs K only | 100 half-moves | ✅ | — |
| 🕊️ Truce | ✅ Both phases | Classic set | 100 half-moves | ✅ | — |
| 🔥 Friendly Fire | ✅ Standard | Classic set | 100 half-moves | ✅ | — |
| ⚔️ Kings' Battle | ✅ Standard | Classic set | 100 half-moves | ✅ | — |
| 👸 Save the Queen | ✅ Standard | Classic set | **100 half-moves** | ✅ | Same piece captures prisoner queen 3× from same square → draw |
| 👑 Succession | ✅ No-move/no-check → draw | Classic set | **50 half-moves** | ✅ | — |

> ¹ Mercenary insufficient material: K vs K, K+N vs K+N (no pawns), then classic fallback.
> Presence of any pawn blocks the insufficient-material draw entirely.

---

## 🗂️ File Reference Index

| File | Draw-related contents |
|---|---|
| `frontend/lib/board/draw_rules.dart` | **Central authority**: `fiftyMoveThreshold()`, `isInsufficientMaterial()`, `shouldResetHalfMoveClock()`, `threefoldRepetitionCount` |
| `frontend/lib/board/board.dart` | `halfMoveClock`, `positionHistory`, `escapedQueens`, `queenCaptureCounter`, `canClaimFiftyMoveRule()` (delegates to DrawRules), `hasThreefoldRepetition()`, `shouldAutoDraw()` |
| `frontend/lib/board/moves/execution.dart` | Half-move clock reset (delegates to DrawRules), position history append, auto-draw trigger |
| `frontend/lib/management/orchestrator.dart` | `_isDrawByInsufficientMaterial()` (delegates to DrawRules), `_isDrawByRepetition()` (placeholder), `_isDrawByFiftyMoveRule()` (delegates to DrawRules) |
| `frontend/lib/mods/savequeen.dart` | Queen respawn to prison logic (after capture), queen capture counter tracking |
| `frontend/lib/debug.dart` | `logStalemate()`, `logDrawInsufficientMaterial()`, `logDrawRepetition()`, `logDrawFiftyMoveRule()` |
| `frontend/test/mercenary_draw_conditions_test.dart` | Mercenary K+P vs K boundary tests |
| `frontend/test/repetition_draw_regression_test.dart` | Threefold repetition regression tests |

