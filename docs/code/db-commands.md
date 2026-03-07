# Game Logs Database - Complete Guide

This guide shows how to access and view the game logs database that stores all game records and moves from the Go backend.

## Quick Access

**Database Connection Info:**
- Container: `chessrecast-logs-db`
- User: `botlogs`
- Password: `botlogs_dev`
- Database: `bot_game_logs`
- Port: `5433`

## Interactive Database Shell

```powershell
# Open interactive psql shell
docker exec -it chessrecast-logs-db psql -U botlogs -d bot_game_logs

# Inside psql shell, useful commands:
\dt                    # List all tables
\d+ table_name         # Show table structure
\q                     # Quit
```

## Game Records Table

```powershell
# View all games with full details
docker exec -it chessrecast-logs-db psql -U botlogs -d bot_game_logs -c "
SELECT 
    game_id,
    game_mode,
    total_moves,
    white_difficulty,
    black_difficulty,
    winner,
    win_reason,
    played_at
FROM game_records
ORDER BY played_at DESC;"

# View recent games (last 10)
docker exec -it chessrecast-logs-db psql -U botlogs -d bot_game_logs -c "
SELECT 
    game_id,
    game_mode,
    total_moves,
    winner,
    played_at
FROM game_records
ORDER BY played_at DESC
LIMIT 10;"

# Count total games by mode
docker exec -it chessrecast-logs-db psql -U botlogs -d bot_game_logs -c "
SELECT 
    game_mode,
    COUNT(*) as total_games,
    COUNT(CASE WHEN winner = 'white' THEN 1 END) as white_wins,
    COUNT(CASE WHEN winner = 'black' THEN 1 END) as black_wins,
    COUNT(CASE WHEN winner = 'draw' THEN 1 END) as draws
FROM game_records
GROUP BY game_mode;"

# Count games by difficulty
docker exec -it chessrecast-logs-db psql -U botlogs -d bot_game_logs -c "
SELECT 
    white_difficulty,
    black_difficulty,
    COUNT(*) as total_games,
    ROUND(AVG(total_moves), 2) as avg_moves
FROM game_records
GROUP BY white_difficulty, black_difficulty
ORDER BY white_difficulty, black_difficulty;"

# Table structure
docker exec -it chessrecast-logs-db psql -U botlogs -d bot_game_logs -c "\d+ game_records"
```

## Move Records Table

```powershell
# View all moves for a specific game
docker exec -it chessrecast-logs-db psql -U botlogs -d bot_game_logs -c "
SELECT 
    move_number,
    piece_type,
    piece_color,
    CONCAT(chr(97 + from_col), (8 - from_row)) as from_square,
    CONCAT(chr(97 + to_col), (8 - to_row)) as to_square,
    CASE WHEN captured_piece IS NOT NULL THEN 'captures ' || captured_piece ELSE '' END as capture,
    CASE WHEN is_promotion THEN 'promotes to ' || promotion_type ELSE '' END as promotion,
    is_castling as castling,
    move_timestamp
FROM move_records
WHERE game_id = '84c613fb-eeac-42f4-8227-4ef127dd499d'
ORDER BY move_number;"

# View moves by piece type
docker exec -it chessrecast-logs-db psql -U botlogs -d bot_game_logs -c "
SELECT 
    game_id,
    piece_type,
    piece_color,
    COUNT(*) as move_count
FROM move_records
WHERE game_id = 'your_game_id'
GROUP BY game_id, piece_type, piece_color
ORDER BY piece_type, piece_color;"

# Find all games with captures
docker exec -it chessrecast-logs-db psql -U botlogs -d bot_game_logs -c "
SELECT DISTINCT
    game_id,
    COUNT(*) as total_captures
FROM move_records
WHERE captured_piece IS NOT NULL
GROUP BY game_id
ORDER BY total_captures DESC;"

# View promotions in games
docker exec -it chessrecast-logs-db psql -U botlogs -d bot_game_logs -c "
SELECT 
    game_id,
    move_number,
    piece_color,
    promotion_type,
    move_timestamp
FROM move_records
WHERE is_promotion = TRUE
ORDER BY game_id, move_number;"

# Find castling moves
docker exec -it chessrecast-logs-db psql -U botlogs -d bot_game_logs -c "
SELECT 
    game_id,
    move_number,
    piece_color,
    move_timestamp
FROM move_records
WHERE is_castling = TRUE
ORDER BY game_id, move_number;"

# Table structure
docker exec -it chessrecast-logs-db psql -U botlogs -d bot_game_logs -c "\d+ move_records"
```

## Combined Analysis Queries

```powershell
# Game statistics with move details
docker exec -it chessrecast-logs-db psql -U botlogs -d bot_game_logs -c "
SELECT 
    g.game_id,
    g.game_mode,
    g.total_moves,
    g.white_difficulty,
    g.black_difficulty,
    g.winner,
    COUNT(m.move_number) as actual_moves_recorded,
    COUNT(CASE WHEN m.captured_piece IS NOT NULL THEN 1 END) as captures,
    COUNT(CASE WHEN m.is_promotion THEN 1 END) as promotions,
    COUNT(CASE WHEN m.is_castling THEN 1 END) as castles,
    g.played_at
FROM game_records g
LEFT JOIN move_records m ON g.game_id = m.game_id
GROUP BY g.game_id, g.game_mode, g.total_moves, g.white_difficulty, g.black_difficulty, g.winner, g.played_at
ORDER BY g.played_at DESC
LIMIT 20;"

# Summary statistics
docker exec -it chessrecast-logs-db psql -U botlogs -d bot_game_logs -c "
SELECT 
    COUNT(*) as total_games,
    (SELECT COUNT(*) FROM move_records) as total_moves_recorded,
    ROUND(AVG(total_moves), 2) as avg_moves_per_game,
    MAX(total_moves) as longest_game,
    MIN(total_moves) as shortest_game,
    COUNT(CASE WHEN winner = 'draw' THEN 1 END) as total_draws
FROM game_records;"

# Piece usage statistics
docker exec -it chessrecast-logs-db psql -U botlogs -d bot_game_logs -c "
SELECT 
    piece_type,
    piece_color,
    COUNT(*) as total_moves,
    COUNT(CASE WHEN captured_piece IS NOT NULL THEN 1 END) as captures
FROM move_records
GROUP BY piece_type, piece_color
ORDER BY piece_type, piece_color;"

# Most active pieces
docker exec -it chessrecast-logs-db psql -U botlogs -d bot_game_logs -c "
SELECT 
    piece_type,
    COUNT(*) as times_moved,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM move_records), 2) as percentage
FROM move_records
GROUP BY piece_type
ORDER BY times_moved DESC;"
```

## Database Information

```powershell
# List all tables
docker exec -it chessrecast-logs-db psql -U botlogs -d bot_game_logs -c "\dt"

# Database size
docker exec -it chessrecast-logs-db psql -U botlogs -d bot_game_logs -c "
SELECT pg_size_pretty(pg_database_size('bot_game_logs')) as database_size;"

# Table sizes
docker exec -it chessrecast-logs-db psql -U botlogs -d bot_game_logs -c "
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;"

# Row counts
docker exec -it chessrecast-logs-db psql -U botlogs -d bot_game_logs -c "
SELECT 
    'game_records' as table_name,
    COUNT(*) as rows
FROM game_records
UNION ALL
SELECT 
    'move_records',
    COUNT(*)
FROM move_records;"
```

## Pretty Print Examples

### Example 1: View a Complete Game with All Moves

```powershell
docker exec -it chessrecast-logs-db psql -U botlogs -d bot_game_logs -c "
SELECT 
    '===== GAME SUMMARY =====' as game_info
FROM game_records 
WHERE game_id = 'your_game_id'

UNION ALL

SELECT 
    'Game ID: ' || game_id || ' | Mode: ' || game_mode || ' | Moves: ' || total_moves || ' | Winner: ' || COALESCE(winner, 'N/A')
FROM game_records 
WHERE game_id = 'your_game_id'

UNION ALL

SELECT '' as game_info

UNION ALL

SELECT 
    LPAD(move_number::text, 3) || '. ' || 
    piece_color || ' ' || piece_type || ': ' ||
    CONCAT(chr(97 + from_col), (8 - from_row)) || '->' || CONCAT(chr(97 + to_col), (8 - to_row)) ||
    CASE WHEN captured_piece IS NOT NULL THEN ' (captures ' || captured_piece || ')' ELSE '' END ||
    CASE WHEN is_promotion THEN ' (-> ' || promotion_type || ')' ELSE '' END ||
    CASE WHEN is_castling THEN ' (CASTLING)' ELSE '' END
FROM move_records
WHERE game_id = 'your_game_id'
ORDER BY move_number;"
```

### Example 2: Show Game Statistics Dashboard

```powershell
docker exec -it chessrecast-logs-db psql -U botlogs -d bot_game_logs -c "
SELECT 
    '════════ BOT GAME LOGS SUMMARY ════════' as dashboard

UNION ALL

SELECT ''

UNION ALL

SELECT 
    'Total Games: ' || COUNT(*) || ' | Total Moves: ' || (SELECT COUNT(*) FROM move_records) || ' | Avg Moves/Game: ' || ROUND(AVG(total_moves), 1)::text
FROM game_records

UNION ALL

SELECT ''

UNION ALL

SELECT 
    'Game Outcomes: ' || 
    COUNT(CASE WHEN winner = 'white' THEN 1 END) || ' White Wins | ' ||
    COUNT(CASE WHEN winner = 'black' THEN 1 END) || ' Black Wins | ' ||
    COUNT(CASE WHEN winner = 'draw' THEN 1 END) || ' Draws'
FROM game_records

UNION ALL

SELECT ''

UNION ALL

SELECT 
    'Most Common Mode: ' || game_mode || ' (' || COUNT(*) || ' games)'
FROM game_records
GROUP BY game_mode
ORDER BY COUNT(*) DESC
LIMIT 1;"
```

## Tips

- Replace `your_game_id` with an actual game ID from your database
- Use `LIMIT N` to restrict results and avoid huge outputs
- Add `ORDER BY` clauses to sort results meaningfully
- The chess board coordinates are converted: row 0-7 → rank 8-1, col 0-7 → files a-h
- Use `-E` flag with psql to show query execution details: `psql -E -U botlogs -d bot_game_logs`
