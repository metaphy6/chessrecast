# Opening Rebalance Proposal (2026-05-05)

Scope: main gate files only
- agent/openings/heir.csv
- agent/openings/friendly_fire.csv
- agent/openings/kings_battle.csv
- agent/openings/mercenary.csv
- agent/openings/save_the_queen.csv
- agent/openings/succession.csv
- agent/openings/truce.csv

Method:
- Keep each file at exactly 50 lines.
- Replace shallow or redundant lines first.
- Pull replacements from the same mod's discovery/stress files only.
- Apply replacements one-to-one in listed order (remove #1 -> add #1, etc.).

## 1) heir.csv
Keep:
- all lines except: 8, 12, 15, 23, 25, 26, 27, 31, 32, 33, 37, 38

Remove:
1. e2e4,c7c5,b1c3
2. e2e4,d7d5
3. e2e4,g8f6
4. d2d4,f7f5
5. d2d4,d7d6
6. c2c4,e7e5
7. c2c4,c7c5
8. b2b3,e7e5
9. g2g3,d7d5
10. g2g3,e7e5
11. b2b4
12. a2a3

Add:
1. d2d4,d7d5,c2c4,d5c4,g1f3,g8f6,e2e3,e7e6,f1c4,c7c5,e1g1,a7a6
2. e2e4,e7e5,g1f3,b8c6,f1b5,a7a6,b5a4,g8f6,e1g1,f8e7,f1e1,b7b5
3. e2e4,c7c5,g1f3,d7d6,d2d4,c5d4,f3d4,g8f6,b1c3,a7a6,c1e3
4. e2e4,c7c5,g1f3,d7d6,d2d4,c5d4,f3d4,g8f6,b1c3,g7g6,c1e3
5. d2d4,g8f6,c2c4,g7g6,b1c3,f8g7,e2e4,d7d6,g1f3,e8g8
6. e2e4,e7e6,d2d4,d7d5,b1c3,f8b4,a2a3,b4c3,b2c3,c7c5,a3a4
7. e2e4,e7e5,g1f3,b8c6,d2d4,e5d4,f3d4,g8f6,d4c6,b7c6
8. e2e4,c7c5,g1f3,d7d6,d2d4,c5d4,f3d4,g8f6,b1c3,b8c6
9. d2d4,d7d5,c2c4,e7e6,b1c3,g8f6,c1g5,f8e7,e2e3,e8g8
10. c2c4,c7c5,g2g3,g7g6,f1g2,f8g7,b1c3,b8c6,a1b1,a7a5
11. e2e4,e7e5,g1f3,b8c6,f1c4,f8c5,c2c3,g8f6,d2d4
12. g1f3,g8f6,g2g3,d7d5,f1g2,c7c6,e1g1,c8g4

## 2) friendly_fire.csv
Keep:
- all lines except: 8, 12, 15, 23, 25, 26, 27, 32, 33, 34, 35, 38

Remove:
1. e2e4,c7c5,b1c3
2. e2e4,d7d5
3. e2e4,g8f6
4. d2d4,f7f5
5. d2d4,d7d6
6. c2c4,e7e5
7. c2c4,c7c5
8. g2g3,d7d5
9. g2g3,e7e5
10. f2f4,d7d5
11. f2f4,e7e5
12. a2a3

Add:
1. e2e4,e7e5,f2f4,e5f4,g1f3,g7g5
2. e2e4,e7e5,f2f4,e5f4,f1c4,d8h4
3. e2e4,e7e5,g1f3,b8c6,d2d4,e5d4,f1c4,d8f6
4. e2e4,e7e5,g1f3,b8c6,b1c3,g8f6,f1b5,f8b4
5. d2d4,f7f5,c2c4,g8f6,b1c3,e7e6,g1f3,f8b4
6. d2d4,g8f6,c1g5,c7c5,d4d5,d8b6
7. d2d4,g8f6,c2c4,c7c5,d4d5,b7b5
8. e2e4,c7c5,g1f3,b8c6,d2d4,c5d4,f3d4,g7g6
9. e2e4,c7c5,g1f3,e7e6,d2d4,c5d4,f3d4,b8c6
10. e2e4,d7d5,e4d5,d8d5,b1c3,d5a5
11. f2f4,d7d5,g1f3,g8f6,e2e3,g7g6
12. g1f3,c7c5,c2c4,b8c6,b1c3,g7g6

## 3) kings_battle.csv
Keep:
- all lines except: 2, 5, 6, 7, 10, 14, 16, 18, 20, 21, 22, 25, 26, 45, 46

Remove:
1. e2e4,e7e6
2. e2e4,c7c6
3. e2e4,d7d6
4. e2e4,g7g6
5. d2d4,e7e6
6. d2d4,b7b6
7. e2e3,e7e5
8. d2d3,e7e5
9. c2c3,e7e5
10. c2c3,d7d5
11. f2f3,e7e5
12. a2a3,h7h6
13. h2h3,a7a6
14. a2a4,e7e5
15. h2h4,d7d5

Add:
1. a2a3,a7a6,b2b3,b7b6,c2c3,c7c6,d2d3,d7d6
2. e2e3,d7d6,d2d3,e7e6,c2c3,c7c6,f2f3,f7f6
3. e2e4,d7d5,e4d5,c7c6,d5c6,b7c6,c2c4,c6c5
4. e2e4,e7e5,e1e2,e8e7,e2e3,e7e6,e3f4,e6f5
5. h2h3,h7h6,g2g3,g7g6,f2f3,f7f6,e2e3,e7e6
6. a2a4,a7a5,b2b4,a5b4,c2c3,b4c3,d2d4
7. b2b4,e7e5,b4b5,d7d5,a2a4,d5d4,a4a5
8. g2g4,e7e5,g4g5,d7d5,h2h4,d5d4,h4h5
9. h2h4,h7h5,g2g4,h5g4,f2f3,g4f3,e2f3
10. h2h4,h7h5,g2g4,h5g4,f2f4,g4f3,e2e3
11. d2d4,e7e5,d4e5,d7d6,e5d6,c7d6
12. e2e4,d7d5,e4d5,e7e6,d5e6,f7e6
13. a2a4,b7b5,a4b5,a7a6,b5a6
14. h2h4,g7g5,h4g5,h7h6,g5h6
15. e2e3,e7e6,e1e2,e8e7

## 4) mercenary.csv
Keep:
- all lines except: 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12

Remove:
1. e2e3,e7e6
2. e2e3,d7d6
3. e2e3,c7c6
4. d2d3,d7d6
5. d2d3,e7e6
6. d2d3,c7c6
7. c2c3,c7c6
8. c2c3,e7e6
9. f2f3,f7f6
10. f2f3,e7e6
11. e2d3,e7d6
12. e2f3,e7f6

Add:
1. e2e3,e7e6,d2d3,d7d6,c2c3,c7c6,f2f3,f7f6,b2b3,b7b6,g2g3,g7g6
2. e2e3,e7e6,e3e4,e6e5,d2d3,d7d6,d3d4,d6d5,c2c3,c7c6,c3c4,c6c5
3. g1f3,g8f6,b1c3,b8c6,e2e3,e7e6,d2d3,d7d6,a2a3,a7a6,h2h3,h7h6
4. g2g3,g7g6,f1g2,f8g7,e2e3,e7e6,g1f3,g8f6,e1g1,e8g8
5. a2a3,a7a6,h2h3,h7h6,b2b3,b7b6,g2g3,g7g6
6. d2d3,d7d6,b1c3,b8c6,g1f3,g8f6,c1f4,c8f5
7. d2d3,d7d6,d3c4,d6c5,c4b5,c5b4,b5a6,b4a3
8. e2e3,e7e6,e3d4,e6d5,d4e5,d5e4,e5f6,e4f3
9. e2e3,e7e6,g1f3,g8f6,f1c4,f8c5,e1g1,e8g8
10. e2e3,e7e6,g1f3,g8f6,f1d3,f8d6,b1c3,b8c6
11. e2d3,e7f6,d3e4,f6g5,e4f5,g5h4,f5g6,h4h3
12. e2e3,e7e6,e1e2,e8e7,e2f3,e7f6,f3g4,f6g5

## 5) save_the_queen.csv
Keep:
- all lines except: 8, 12, 15, 23, 25, 26, 27, 31, 32, 33, 37, 38

Remove:
1. e2e4,c7c5,b1c3
2. e2e4,d7d5
3. e2e4,g8f6
4. d2d4,f7f5
5. d2d4,d7d6
6. c2c4,e7e5
7. c2c4,c7c5
8. b2b3,e7e5
9. g2g3,d7d5
10. g2g3,e7e5
11. b2b4
12. a2a3

Add:
1. d2d4,d7d5,c2c4,d5c4,g1f3,g8f6,e2e3,e7e6,f1c4,c7c5,e1g1,a7a6
2. e2e4,e7e5,g1f3,b8c6,f1b5,a7a6,b5a4,g8f6,e1g1,f8e7,f1e1,b7b5
3. d2d4,g8f6,c2c4,g7g6,b1c3,f8g7,e2e4,d7d6,g1f3,e8g8
4. d2d4,d7d5,c2c4,e7e6,b1c3,g8f6,c1g5,f8e7,e2e3,e8g8
5. c2c4,c7c5,g2g3,g7g6,f1g2,f8g7,b1c3,b8c6,a1b1,a7a5
6. g1f3,g8f6,g2g3,d7d5,f1g2,c7c6,e1g1,c8g4
7. c2c4,e7e6,g1f3,g8f6,b1c3,d7d5
8. g1f3,d7d5,g2g3,c7c5,f1g2,b8c6,e1g1
9. b2b3,e7e5,c1b2,b8c6,e2e3
10. g2g3,e7e5,f1g2,d7d5,d2d3,b8c6
11. c2c4,e7e5,b1c3,g8f6,g1f3,b8c6
12. d2d3,d7d5,g1f3,g8f6,g2g3,c7c5

## 6) succession.csv
Keep:
- all lines except: 8, 12, 15, 23, 25, 26, 27, 31, 32, 33, 37, 38

Remove:
1. e2e4,c7c5,b1c3
2. e2e4,d7d5
3. e2e4,g8f6
4. d2d4,f7f5
5. d2d4,d7d6
6. c2c4,e7e5
7. c2c4,c7c5
8. b2b3,e7e5
9. g2g3,d7d5
10. g2g3,e7e5
11. b2b4
12. a2a3

Add:
1. e2e4,e7e6,d2d4,d7d5,b1c3,f8b4,a2a3,b4c3,b2c3,c7c5,a3a4
2. e2e4,c7c5,g1f3,d7d6,d2d4,c5d4,f3d4,g8f6,b1c3,a7a6,c1g5
3. e2e4,c7c5,g1f3,d7d6,d2d4,c5d4,f3d4,g8f6,b1c3,g7g6,c1e3
4. d2d4,f7f5,c2c4,g8f6,b1c3,e7e6,g1f3,f8b4
5. d2d4,g8f6,c2c4,c7c5,d4d5,e7e6
6. d2d4,g8f6,c2c4,c7c5,d4d5,b7b5
7. e2e4,c7c6,d2d4,d7d5,b1c3,d5e4
8. e2e4,c7c6,d2d4,d7d5,e4d5,c6d5
9. e2e4,d7d5,e4d5,d8d5,b1c3,d5a5
10. e2e4,e7e6,d2d4,d7d5,e4e5,c7c5
11. f2f4,e7e5,f4e5,d7d6,e5d6,f8d6
12. e2e4,e7e5,f2f4,e5f4,g1f3,g7g5

## 7) truce.csv
Keep:
- all lines except: 8, 12, 15, 23, 25, 26, 27, 31, 32, 33, 37, 38

Remove:
1. e2e4,c7c5,b1c3
2. e2e4,d7d5
3. e2e4,g8f6
4. d2d4,f7f5
5. d2d4,d7d6
6. c2c4,e7e5
7. c2c4,c7c5
8. b2b3,e7e5
9. g2g3,d7d5
10. g2g3,e7e5
11. b2b4
12. a2a3

Add:
1. d2d4,d7d5,g1f3,g8f6,c2c4,c7c6,b1c3,b8c6,c1f4,c8f5,e2e3,e7e6,f1d3,f8d6
2. d2d4,d7d5,c2c4,d5c4,g1f3,g8f6,e2e3,e7e6,f1c4,c7c5,e1g1,a7a6
3. e2e4,e7e5,g1f3,b8c6,f1b5,a7a6,b5a4,g8f6,e1g1,f8e7,f1e1,b7b5
4. c2c4,c7c5,g2g3,g7g6,f1g2,f8g7,b1c3,b8c6,a1b1,a7a5
5. d2d4,d7d5,c2c4,e7e6,b1c3,g8f6,c1g5,f8e7,e2e3,e8g8
6. g1f3,g8f6,g2g3,d7d5,f1g2,c7c6,e1g1,c8g4
7. c2c4,e7e6,g1f3,g8f6,b1c3,d7d5
8. d2d3,d7d5,g1f3,g8f6,g2g3,c7c5
9. g1f3,d7d5,g2g3,c7c5,f1g2,b8c6,e1g1
10. b2b3,e7e5,c1b2,b8c6,e2e3
11. g2g3,e7e5,f1g2,d7d5,d2d3,b8c6
12. c2c4,e7e5,b1c3,g8f6,g1f3,b8c6

---

# Minimal C Opening-Book Implementation Plan (file-by-file)

Goal:
- Make opening play stronger and faster in first plies.
- Keep behavior deterministic at skill 4, controlled variety below skill 4.
- Avoid changing core alpha-beta semantics.

## New file 1: frontend/native/engine/book/opening_book.h
Add:
- BookEntry struct: mod, key, move, min_fullmove, max_fullmove, min_skill, max_skill, weight.
- API:
  - void opening_book_init(void);
  - bool opening_book_probe(const Board *b, int skill_level, Move *out_move, int *out_score);
  - void opening_book_reset(void);

Purpose:
- Small, isolated interface with no search-side coupling.

## New file 2: frontend/native/engine/book/opening_book.c
Add:
- Static seed table per mod (start with 30-80 entries total, not exhaustive).
- One-time build path at init:
  - Convert seed FEN to Board via board_set_fen.
  - Convert UCI move text to legal Move by scanning generate_moves output.
  - Store entries keyed by (mod, board.hash).
- Probe path:
  - Filter by mod, board.hash, fullmove window, skill window.
  - Skill 4: choose max weight deterministically (tie-break by move encoding).
  - Skill 0-3: weighted random among top cluster.
- Safety:
  - If no legal conversion or no hit, return false.

Purpose:
- Adds opening intelligence with minimal runtime overhead and no Dart dependency.

## Change file 3: frontend/native/engine/CMakeLists.txt
Add:
- book/opening_book.c to chess_engine target sources.

Purpose:
- Include the opening-book module in shared library builds.

## Change file 4: frontend/native/engine/bridge.c
Add in bridge_engine_search_best_move:
- Before search_think, call opening_book_probe.
- On hit:
  - Set raw.best_move from book.
  - Set raw.score to a small positive prior (for example +12) and depth/nodes to 0.
  - Continue through existing refine chain (ff/kb/heir/succ/stq/mercenary/king_discipline).
- On miss:
  - Use current search_think flow unchanged.

Purpose:
- Zero API change for Dart FFI.
- Keeps all current mod-specific legality/safety refinements active on book moves.

## Change file 5: frontend/native/engine/bridge.h
Optional, minimal:
- No FFI API change required.
- Optionally document that engine_find_move may return book-prioritized move at early fullmove numbers.

Purpose:
- Keep integration transparent to callers.

## Optional tooling file 6: frontend/tool/generate_opening_book.dart
Add:
- Read agent/openings/<mod>.csv and emit compact C seed arrays (fen + move + weight).
- Weight strategy:
  - base file lines get default weight 100.
  - discovery/stress promoted lines can be 120-160 if they improve KPI hotspots.

Purpose:
- Keeps book data refreshable without hand-editing C arrays.

## Tests to add (minimal)
1. frontend/test/native_opening_book_smoke_test.dart
- Given known opening FEN at fullmove <= threshold, assert move is one of expected book moves.

2. frontend/test/native_opening_book_skill_variance_test.dart
- Skill 4 deterministic over repeated calls.
- Skill 0/1 shows weighted diversity over repeated calls.

3. Existing gate tests unchanged
- king_castling_policy_regression_test.dart
- <mod>_engine_regression_test.dart
- manual_<mod>_audit_batch_test.dart (for KPI impact checks)

## Rollout sequence
1. Ship opening-book infra with 10-15 seed positions per mod.
2. Run all gate tests + 50-game batches for heir and mercenary first.
3. Expand seed set gradually from rebalanced gate files.
4. Tune weights only after KPI deltas are observed.
