package storage

import (
	"context"
	"fmt"
	"os"
	"strings"
	"sync"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/metaphy6/chessrecast/internal/engine"
)

// logf prints a log message with timestamp (MM-DD HH:MM:SS.mmm)
func logf(format string, args ...interface{}) {
	ts := time.Now().Format("01-02 15:04:05.000")
	msg := fmt.Sprintf(format, args...)
	fmt.Printf("[%s] %s\n", ts, msg)
}

// GameRecord represents a complete game record with notation
type GameRecord struct {
	ID              int64     `json:"id"`
	GameID          string    `json:"game_id"`
	GameMode        string    `json:"game_mode"`
	WhiteMoves      string    `json:"white_moves"` // e.g., "e2e4 g1f3 f1b5 O-O ..."
	BlackMoves      string    `json:"black_moves"` // e.g., "e7e5 b8c6 a7a6 g8f6 ..."
	Winner          string    `json:"winner"`      // "white", "black", "draw"
	WinReason       string    `json:"win_reason"`  // "checkmate", "stalemate", etc.
	TotalMoves      int       `json:"total_moves"`
	WhiteDifficulty int       `json:"white_difficulty"`
	BlackDifficulty int       `json:"black_difficulty"`
	PlayedAt        time.Time `json:"played_at"`
}

// GameLogger handles logging game records to the database
type GameLogger struct {
	pool       *pgxpool.Pool
	recordChan chan GameRecord
	wg         sync.WaitGroup
	ctx        context.Context
	cancel     context.CancelFunc
}

// GameBuilder accumulates moves during a game
type GameBuilder struct {
	GameID          string
	Mode            engine.GameMode
	WhiteMoves      []string
	BlackMoves      []string
	WhiteDifficulty int
	BlackDifficulty int
	StartTime       time.Time
}

var (
	logger       *GameLogger
	loggerOnce   sync.Once
	gameBuilders = make(map[string]*GameBuilder)
	buildersMu   sync.RWMutex
)

// InitGameLogger initializes the global game logger
func InitGameLogger() error {
	var initErr error
	loggerOnce.Do(func() {
		dbURL := os.Getenv("LOGS_DATABASE_URL")
		if dbURL == "" {
			dbURL = "postgres://botlogs:botlogs_dev@localhost:5433/bot_game_logs?sslmode=disable"
		}

		logf("📊 Connecting to dedicated logs database...")

		ctx := context.Background()
		pool, err := pgxpool.New(ctx, dbURL)
		if err != nil {
			initErr = fmt.Errorf("failed to connect to logs database: %w", err)
			return
		}

		if err := pool.Ping(ctx); err != nil {
			initErr = fmt.Errorf("failed to ping database: %w", err)
			return
		}
		logf("✅ Database connection ping successful")

		var testResult int
		err = pool.QueryRow(ctx, "SELECT 1").Scan(&testResult)
		if err != nil {
			initErr = fmt.Errorf("failed basic read test: %w", err)
			return
		}
		logf("✅ Database read permission verified (SELECT 1 = OK)")

		if err := createTables(ctx, pool); err != nil {
			initErr = fmt.Errorf("failed to create tables: %w", err)
			return
		}
		logf("✅ Database write permission verified (tables created/verified)")

		logCtx, cancel := context.WithCancel(ctx)
		logger = &GameLogger{
			pool:       pool,
			recordChan: make(chan GameRecord, 100),
			ctx:        logCtx,
			cancel:     cancel,
		}

		logger.wg.Add(1)
		go logger.worker()

		logf("✅ Game logger initialized successfully")
	})
	return initErr
}

// GetDatabasePool returns the database pool for the game logger
// Used to initialize other components like MoveRecorder
func GetDatabasePool() *pgxpool.Pool {
	if logger != nil {
		return logger.pool
	}
	return nil
}

// createTables creates the necessary database tables
func createTables(ctx context.Context, pool *pgxpool.Pool) error {
	schema := `
	CREATE TABLE IF NOT EXISTS game_records (
		id BIGSERIAL PRIMARY KEY,
		game_id VARCHAR(36) UNIQUE NOT NULL,
		game_mode VARCHAR(50) NOT NULL,
		white_moves TEXT NOT NULL,
		black_moves TEXT NOT NULL,
		winner VARCHAR(10),
		win_reason VARCHAR(50),
		total_moves INT NOT NULL,
		white_difficulty INT NOT NULL,
		black_difficulty INT NOT NULL,
		played_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
	);

	CREATE TABLE IF NOT EXISTS move_records (
		id BIGSERIAL PRIMARY KEY,
		game_id VARCHAR(36) NOT NULL,
		move_number INT NOT NULL,
		from_row INT NOT NULL,
		from_col INT NOT NULL,
		to_row INT NOT NULL,
		to_col INT NOT NULL,
		piece_type VARCHAR(20) NOT NULL,
		piece_color VARCHAR(10) NOT NULL,
		captured_piece VARCHAR(20),
		is_promotion BOOLEAN DEFAULT FALSE,
		promotion_type VARCHAR(20),
		is_castling BOOLEAN DEFAULT FALSE,
		move_timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
		recorded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
		FOREIGN KEY (game_id) REFERENCES game_records(game_id) ON DELETE CASCADE,
		UNIQUE(game_id, move_number)
	);

	CREATE INDEX IF NOT EXISTS idx_game_records_game_mode ON game_records(game_mode);
	CREATE INDEX IF NOT EXISTS idx_game_records_played_at ON game_records(played_at);
	CREATE INDEX IF NOT EXISTS idx_game_records_winner ON game_records(winner);
	CREATE INDEX IF NOT EXISTS idx_move_records_game_id ON move_records(game_id);
	CREATE INDEX IF NOT EXISTS idx_move_records_timestamp ON move_records(move_timestamp);
	`

	_, err := pool.Exec(ctx, schema)
	return err
}

// worker processes game records in the background
func (gl *GameLogger) worker() {
	defer gl.wg.Done()

	for {
		select {
		case <-gl.ctx.Done():
			for len(gl.recordChan) > 0 {
				record := <-gl.recordChan
				gl.insertRecord(record)
			}
			return
		case record := <-gl.recordChan:
			gl.insertRecord(record)
		}
	}
}

// insertRecord inserts a game record
func (gl *GameLogger) insertRecord(record GameRecord) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	_, err := gl.pool.Exec(ctx, `
		INSERT INTO game_records (
			game_id, game_mode, white_moves, black_moves,
			winner, win_reason, total_moves,
			white_difficulty, black_difficulty, played_at
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
		ON CONFLICT (game_id) DO UPDATE SET
			white_moves = EXCLUDED.white_moves,
			black_moves = EXCLUDED.black_moves,
			winner = EXCLUDED.winner,
			win_reason = EXCLUDED.win_reason,
			total_moves = EXCLUDED.total_moves
	`,
		record.GameID, record.GameMode, record.WhiteMoves, record.BlackMoves,
		record.Winner, record.WinReason, record.TotalMoves,
		record.WhiteDifficulty, record.BlackDifficulty, record.PlayedAt,
	)
	if err != nil {
		logf("❌ Failed to insert game record: %v", err)
	} else {
		logf("📝 Game record saved: %s (%s) - %d moves, winner: %s",
			record.GameID[:8], record.GameMode, record.TotalMoves, record.Winner)
	}
}

// StartGame initializes a new game builder for tracking moves AND creates initial DB record
func StartGame(gameID string, mode engine.GameMode, whiteDiff, blackDiff int) {
	buildersMu.Lock()
	gameBuilders[gameID] = &GameBuilder{
		GameID:          gameID,
		Mode:            mode,
		WhiteMoves:      []string{},
		BlackMoves:      []string{},
		WhiteDifficulty: whiteDiff,
		BlackDifficulty: blackDiff,
		StartTime:       time.Now(),
	}
	buildersMu.Unlock()

	logf("🎮 Game started: %s (mode: %s, white: %d, black: %d)",
		gameID[:8], mode.String(), whiteDiff, blackDiff)

	// Create initial game record in database IMMEDIATELY to satisfy FK constraint for move_records
	if logger != nil && logger.pool != nil {
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()

		_, err := logger.pool.Exec(ctx, `
			INSERT INTO game_records (
				game_id, game_mode, white_moves, black_moves,
				winner, win_reason, total_moves,
				white_difficulty, black_difficulty, played_at
			) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
			ON CONFLICT (game_id) DO NOTHING
		`,
			gameID, mode.String(), "", "",
			nil, nil, 0,
			whiteDiff, blackDiff, time.Now(),
		)
		if err != nil {
			logf("❌ Failed to create initial game record for %s: %v", gameID[:8], err)
		} else {
			logf("📝 Initial game record created for %s", gameID[:8])
		}
	} else {
		logf("⚠️ Logger not available, skipping initial game record for %s", gameID[:8])
	}
}

// RecordMove adds a move to the game builder
func RecordMove(gameID string, move *engine.Move) {
	buildersMu.Lock()
	defer buildersMu.Unlock()

	builder, exists := gameBuilders[gameID]
	if !exists {
		return
	}

	notation := moveToNotation(move)

	if move.Piece.Color == engine.White {
		builder.WhiteMoves = append(builder.WhiteMoves, notation)
	} else {
		builder.BlackMoves = append(builder.BlackMoves, notation)
	}
}

// EndGame finalizes and saves the game record
func EndGame(gameID string, winner string, winReason string) {
	buildersMu.Lock()
	builder, exists := gameBuilders[gameID]
	if exists {
		delete(gameBuilders, gameID)
	}
	buildersMu.Unlock()

	if !exists || logger == nil {
		return
	}

	record := GameRecord{
		GameID:          gameID,
		GameMode:        builder.Mode.String(),
		WhiteMoves:      strings.Join(builder.WhiteMoves, " "),
		BlackMoves:      strings.Join(builder.BlackMoves, " "),
		Winner:          winner,
		WinReason:       winReason,
		TotalMoves:      len(builder.WhiteMoves) + len(builder.BlackMoves),
		WhiteDifficulty: builder.WhiteDifficulty,
		BlackDifficulty: builder.BlackDifficulty,
		PlayedAt:        builder.StartTime,
	}

	select {
	case logger.recordChan <- record:
	default:
		logf("⚠️ Record buffer full, dropping game record")
	}
}

// moveToNotation converts a move to algebraic notation
func moveToNotation(move *engine.Move) string {
	if move.IsCastling {
		if move.To.Col > move.From.Col {
			return "O-O" // Kingside
		}
		return "O-O-O" // Queenside
	}

	var sb strings.Builder

	// Piece letter (except pawns)
	switch move.Piece.Type {
	case engine.King:
		sb.WriteString("K")
	case engine.Queen:
		sb.WriteString("Q")
	case engine.Rook:
		sb.WriteString("R")
	case engine.Bishop:
		sb.WriteString("B")
	case engine.Knight:
		sb.WriteString("N")
	}

	// From square
	sb.WriteString(positionToAlgebraic(move.From))

	// Capture indicator
	if move.CapturedPiece != nil {
		sb.WriteString("x")
	} else {
		sb.WriteString("-")
	}

	// To square
	sb.WriteString(positionToAlgebraic(move.To))

	// Promotion
	if move.IsPromotion && move.Promotion != 0 {
		sb.WriteString("=")
		switch move.Promotion {
		case engine.Queen:
			sb.WriteString("Q")
		case engine.Rook:
			sb.WriteString("R")
		case engine.Bishop:
			sb.WriteString("B")
		case engine.Knight:
			sb.WriteString("N")
		}
	}

	return sb.String()
}

// positionToAlgebraic converts a Position to algebraic notation (e.g., "e4")
func positionToAlgebraic(pos engine.Position) string {
	file := string(rune('a' + pos.Col))
	rank := string(rune('1' + pos.Row))
	return file + rank
}

// GetGameRecords retrieves game records
func GetGameRecords(ctx context.Context, mode string, limit int) ([]GameRecord, error) {
	if logger == nil || logger.pool == nil {
		return nil, fmt.Errorf("game logger not initialized")
	}

	query := `SELECT id, game_id, game_mode, white_moves, black_moves,
		COALESCE(winner, ''), COALESCE(win_reason, ''), total_moves,
		white_difficulty, black_difficulty, played_at
		FROM game_records WHERE 1=1`
	args := []interface{}{}
	argNum := 1

	if mode != "" {
		query += fmt.Sprintf(" AND game_mode = $%d", argNum)
		args = append(args, mode)
		argNum++
	}

	query += " ORDER BY played_at DESC"

	if limit > 0 {
		query += fmt.Sprintf(" LIMIT $%d", argNum)
		args = append(args, limit)
	}

	rows, err := logger.pool.Query(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var records []GameRecord
	for rows.Next() {
		var r GameRecord
		err := rows.Scan(
			&r.ID, &r.GameID, &r.GameMode, &r.WhiteMoves, &r.BlackMoves,
			&r.Winner, &r.WinReason, &r.TotalMoves,
			&r.WhiteDifficulty, &r.BlackDifficulty, &r.PlayedAt,
		)
		if err != nil {
			return nil, err
		}
		records = append(records, r)
	}

	return records, rows.Err()
}

// GetGameRecord retrieves a single game record by ID
func GetGameRecord(ctx context.Context, gameID string) (*GameRecord, error) {
	if logger == nil || logger.pool == nil {
		return nil, fmt.Errorf("game logger not initialized")
	}

	var r GameRecord
	err := logger.pool.QueryRow(ctx, `
		SELECT id, game_id, game_mode, white_moves, black_moves,
			COALESCE(winner, ''), COALESCE(win_reason, ''), total_moves,
			white_difficulty, black_difficulty, played_at
		FROM game_records WHERE game_id = $1
	`, gameID).Scan(
		&r.ID, &r.GameID, &r.GameMode, &r.WhiteMoves, &r.BlackMoves,
		&r.Winner, &r.WinReason, &r.TotalMoves,
		&r.WhiteDifficulty, &r.BlackDifficulty, &r.PlayedAt,
	)
	if err != nil {
		return nil, err
	}

	return &r, nil
}

// TestDatabaseConnection performs a database connection test
func TestDatabaseConnection(ctx context.Context) (map[string]interface{}, error) {
	result := make(map[string]interface{})
	result["timestamp"] = time.Now().Format("01-02 15:04:05.000")

	if logger == nil || logger.pool == nil {
		result["status"] = "error"
		result["error"] = "game logger not initialized"
		return result, fmt.Errorf("game logger not initialized")
	}

	pingStart := time.Now()
	pingErr := logger.pool.Ping(ctx)
	result["ping_latency_ms"] = time.Since(pingStart).Milliseconds()
	result["ping_success"] = pingErr == nil

	var recordCount int64
	_ = logger.pool.QueryRow(ctx, "SELECT COUNT(*) FROM game_records").Scan(&recordCount)
	result["game_records_count"] = recordCount

	stats := logger.pool.Stat()
	result["pool_stats"] = map[string]interface{}{
		"total_conns": stats.TotalConns(),
		"idle_conns":  stats.IdleConns(),
		"max_conns":   stats.MaxConns(),
	}

	if pingErr == nil {
		result["status"] = "healthy"
	} else {
		result["status"] = "unhealthy"
	}

	return result, nil
}

// Shutdown gracefully shuts down the logger
func Shutdown() {
	if logger == nil {
		return
	}
	logger.cancel()
	logger.wg.Wait()
	logger.pool.Close()
	logf("✅ Game logger shut down")
}

// DatabaseResetResult contains the result of resetting all database tables
type DatabaseResetResult struct {
	TablesCleared    []string          `json:"tables_cleared"`
	RowsDeleted      map[string]int64  `json:"rows_deleted"`
	AllTablesEmpty   bool              `json:"all_tables_empty"`
	Message          string            `json:"message"`
}

// ResetDatabase clears all data from the database tables (move_records first due to FK constraint, then game_records)
func ResetDatabase(ctx context.Context) (*DatabaseResetResult, error) {
	if logger == nil || logger.pool == nil {
		return nil, fmt.Errorf("database not initialized")
	}

	pool := logger.pool
	result := &DatabaseResetResult{
		TablesCleared: []string{},
		RowsDeleted:   make(map[string]int64),
	}

	// Clear move_records first (has FK to game_records)
	moveRes, err := pool.Exec(ctx, "DELETE FROM move_records")
	if err != nil {
		return nil, fmt.Errorf("failed to clear move_records: %w", err)
	}
	movesDeleted := moveRes.RowsAffected()
	result.RowsDeleted["move_records"] = movesDeleted
	if movesDeleted > 0 {
		result.TablesCleared = append(result.TablesCleared, "move_records")
	}
	logf("🗑️ Deleted %d rows from move_records", movesDeleted)

	// Clear game_records
	gameRes, err := pool.Exec(ctx, "DELETE FROM game_records")
	if err != nil {
		return nil, fmt.Errorf("failed to clear game_records: %w", err)
	}
	gamesDeleted := gameRes.RowsAffected()
	result.RowsDeleted["game_records"] = gamesDeleted
	if gamesDeleted > 0 {
		result.TablesCleared = append(result.TablesCleared, "game_records")
	}
	logf("🗑️ Deleted %d rows from game_records", gamesDeleted)

	// Verify tables are empty
	var moveCount, gameCount int
	err = pool.QueryRow(ctx, "SELECT COUNT(*) FROM move_records").Scan(&moveCount)
	if err != nil {
		return nil, fmt.Errorf("failed to verify move_records: %w", err)
	}
	err = pool.QueryRow(ctx, "SELECT COUNT(*) FROM game_records").Scan(&gameCount)
	if err != nil {
		return nil, fmt.Errorf("failed to verify game_records: %w", err)
	}

	result.AllTablesEmpty = (moveCount == 0 && gameCount == 0)
	
	totalDeleted := movesDeleted + gamesDeleted
	if totalDeleted == 0 {
		result.Message = "All tables were already empty"
	} else {
		result.Message = fmt.Sprintf("Successfully deleted %d total rows. All tables are now empty.", totalDeleted)
	}

	logf("✅ Database reset complete: %s", result.Message)
	return result, nil
}
