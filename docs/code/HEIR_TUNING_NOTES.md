# Heir Engine Tuning Notes

## Objective

Improve decision quality for mod "Heir" by running repeated 50-game audits,
analyzing worst-miss behavior, and applying targeted engine changes.

## Baseline Audit (50 games, 60 plies)

- Report: `/tmp/heir_audit_batch_baseline.txt`
- Aggregate: avg worst miss **1.79**, max worst miss **8.61**
- Thresholds: `>= 2.00` was **14/50**, `>= 3.00` was **8/50**
- KPI aggregate:
  - `earlyKingMoves=3`
  - `castlingRightLosses=69`
  - `castled[w=0/50,b=0/50]`
  - `kingExposureIndex(avg)=37.12`

## Implemented Changes

### File: `frontend/native/engine/eval/eval_heir.c`

1. Increased advancement and race bonus tables to reward active progress sooner.
2. Raised low-rank recovery bonuses (non-zero at low advance levels).
3. Increased hung-piece penalties (minor/rook/queen).
4. Increased early development bonus and added a milestone bonus for 3+ developed pieces.
5. Increased knight outpost scoring.
6. Added rook-on-7th-rank bonus (+ extra when enemy king is on back rank).
7. Added connected-rooks bonus.
8. Added bishop center-control bonus.
9. Reduced local tempo bonus to avoid excessive double tempo with common eval.

### File: `frontend/native/engine/search.c`

1. Increased quiet move ordering bonus for minor-piece development.
2. Added rook ordering bonus for 7th-rank occupation.
3. Added rook ordering bonus for moving to open files.
4. Added centralization bonus for knight/bishop quiet moves.

## Verification Audit V2 (50 games)

### Completed Run (24 plies)

- Report: `/tmp/heir_audit_batch_v2.txt`
- Aggregate: avg worst miss **0.66**, max worst miss **1.49**
- Thresholds: `>= 2.00` was **0/50**, `>= 3.00` was **0/50**
- KPI aggregate:
  - `earlyKingMoves=0`
  - `castlingRightLosses=21`
  - `castled[w=0/50,b=0/50]`
  - `kingExposureIndex(avg)=28.96`

Note: This run used the tool default plies (`24`), so it is a strong signal of
improvement but not a strict apples-to-apples comparison against the baseline
(`60` plies).

### Per-Game Investigation (completed 24-ply run)

Worst miss by game:

1. `e2e4,e7e5` -> `0.24`
2. `e2e4,c7c5` -> `0.74`
3. `e2e4,g8f6` -> `0.49`
4. `e2e4,d7d5` -> `0.51`
5. `e2e4,b8c6` -> `0.60`
6. `d2d4,e7e5` -> `0.38`
7. `d2d4,c7c5` -> `1.49`
8. `d2d4,g8f6` -> `0.00`
9. `d2d4,d7d5` -> `0.63`
10. `d2d4,b8c6` -> `0.33`
11. `c2c4,e7e5` -> `0.50`
12. `c2c4,c7c5` -> `0.17`
13. `c2c4,g8f6` -> `1.02`
14. `c2c4,d7d5` -> `0.79`
15. `c2c4,b8c6` -> `0.67`
16. `g1f3,e7e5` -> `0.58`
17. `g1f3,c7c5` -> `0.70`
18. `g1f3,g8f6` -> `0.30`
19. `g1f3,d7d5` -> `0.69`
20. `g1f3,b8c6` -> `0.51`
21. `b1c3,e7e5` -> `0.73`
22. `b1c3,c7c5` -> `0.38`
23. `b1c3,g8f6` -> `0.56`
24. `b1c3,d7d5` -> `0.24`
25. `b1c3,b8c6` -> `0.40`
26. `g2g3,e7e5` -> `1.25`
27. `g2g3,c7c5` -> `0.32`
28. `g2g3,g8f6` -> `1.03`
29. `g2g3,d7d5` -> `0.35`
30. `g2g3,b8c6` -> `1.25`
31. `b2b3,e7e5` -> `0.51`
32. `b2b3,c7c5` -> `0.77`
33. `b2b3,g8f6` -> `1.10`
34. `b2b3,d7d5` -> `0.86`
35. `b2b3,b8c6` -> `0.35`
36. `e2e3,e7e5` -> `0.70`
37. `e2e3,c7c5` -> `1.09`
38. `e2e3,g8f6` -> `0.59`
39. `e2e3,d7d5` -> `0.69`
40. `e2e3,b8c6` -> `0.60`
41. `d2d3,e7e5` -> `1.21`
42. `d2d3,c7c5` -> `0.54`
43. `d2d3,g8f6` -> `0.86`
44. `d2d3,d7d5` -> `0.45`
45. `d2d3,b8c6` -> `0.45`
46. `f2f4,e7e5` -> `1.41`
47. `f2f4,c7c5` -> `0.70`
48. `f2f4,g8f6` -> `1.24`
49. `f2f4,d7d5` -> `0.27`
50. `f2f4,b8c6` -> `0.51`

Counts:

- `>= 1.00`: 10/50
- `>= 1.50`: 0/50
- `>= 2.00`: 0/50

## In Progress

Strict apples-to-apples verification run is in progress with 50 games at
60 plies:

- `HEIR_BATCH_REPORT_PATH=/tmp/heir_audit_batch_v2_60.txt`
- `HEIR_BATCH_MAX_PLIES=60`

## Batch Harness Controls (added)

The Heir batch runner now supports explicit blunder guarding and progress output:

- `HEIR_BATCH_STOP_AT_DELTA`
  - Example: `HEIR_BATCH_STOP_AT_DELTA=3.00`
  - Stops the 50-game suite early when a game's worst miss reaches the threshold.
  - Report contains an `EARLY STOP:` marker with game/opening/delta details.

- `HEIR_BATCH_LIVE_PROGRESS`
  - `1` (default): emit per-game progress lines.
  - `0`: disable per-game progress lines.
