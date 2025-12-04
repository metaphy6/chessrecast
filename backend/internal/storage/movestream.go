package storage

import (
	"context"
	"fmt"
	"sync"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/metaphy6/chessrecast/internal/engine"
)

// MoveRecord represents a single move in a game (for real-time streaming)
type MoveRecord struct {
	GameID        string
	MoveNumber    int           // 1, 2, 3, ... (sequence)
	Move          *engine.Move
	Color         engine.Color
	Timestamp     time.Time // When move was made
	RecordedAt    time.Time // When record was created
}

// MoveRecorder handles real-time streaming of moves to database
// Uses worker pool pattern similar to gRPC unidirectional streaming
type MoveRecorder struct {
	pool        *pgxpool.Pool
	moveChannel chan MoveRecord
	workers     int
	wg          sync.WaitGroup
	ctx         context.Context
	cancel      context.CancelFunc
}

var (
	moveRecorder      *MoveRecorder
	recorderOnce      sync.Once
	recorderInitErr   error
)

// InitMoveRecorder initializes the global move recorder with worker pool
// Workers determine concurrency for database writes
func InitMoveRecorder(pool *pgxpool.Pool, workers int) error {
	var initErr error
	recorderOnce.Do(func() {
		if workers < 1 {
			workers = 3 // Default: 3 concurrent workers
		}
		if workers > 10 {
			workers = 10 // Cap at 10 to avoid connection pool exhaustion
		}

		ctx, cancel := context.WithCancel(context.Background())
		moveRecorder = &MoveRecorder{
			pool:        pool,
			moveChannel: make(chan MoveRecord, 500), // Larger buffer for move streaming
			workers:     workers,
			ctx:         ctx,
			cancel:      cancel,
		}

		// Start worker goroutines
		for i := 0; i < workers; i++ {
			moveRecorder.wg.Add(1)
			go moveRecorder.worker(i)
		}

		logf("🚀 Move Recorder initialized with %d workers (buffer: 500)", workers)
	})
	return initErr
}

// RecordMoveStream sends a move to the recording stream (non-blocking)
// Similar to how gRPC streaming sends messages
func RecordMoveStream(gameID string, moveNumber int, move *engine.Move, color engine.Color) {
	if moveRecorder == nil {
		return
	}

	record := MoveRecord{
		GameID:     gameID,
		MoveNumber: moveNumber,
		Move:       move,
		Color:      color,
		Timestamp:  time.Now(),
		RecordedAt: time.Now(),
	}

	// Non-blocking send - if buffer full, continue game anyway
	select {
	case moveRecorder.moveChannel <- record:
		// Successfully sent to stream
	default:
		// Buffer full - log warning but don't block game execution
		logf("⚠️ Move recorder buffer full for game %s, move %d (buffer size: %d)",
			gameID[:8], moveNumber, len(moveRecorder.moveChannel))
	}
}

// worker processes moves from the stream concurrently
func (mr *MoveRecorder) worker(id int) {
	defer mr.wg.Done()

	for {
		select {
		case <-mr.ctx.Done():
			// Drain remaining moves on shutdown
			for len(mr.moveChannel) > 0 {
				record := <-mr.moveChannel
				mr.insertMove(record)
			}
			logf("🛑 Move recorder worker %d shutting down", id)
			return

		case record := <-mr.moveChannel:
			mr.insertMove(record)
		}
	}
}

// insertMove writes a single move to the database
func (mr *MoveRecorder) insertMove(record MoveRecord) {
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()

	_, err := mr.pool.Exec(ctx, `
		INSERT INTO move_records (
			game_id, move_number, from_row, from_col, to_row, to_col,
			piece_type, piece_color, captured_piece, is_promotion, promotion_type,
			is_castling, move_timestamp, recorded_at
		) VALUES (
			$1, $2, $3, $4, $5, $6,
			$7, $8, $9, $10, $11,
			$12, $13, $14
		)
		ON CONFLICT (game_id, move_number) DO UPDATE SET
			move_timestamp = EXCLUDED.move_timestamp,
			recorded_at = EXCLUDED.recorded_at
	`,
		record.GameID,
		record.MoveNumber,
		record.Move.From.Row,
		record.Move.From.Col,
		record.Move.To.Row,
		record.Move.To.Col,
		record.Move.Piece.Type.String(),
		record.Move.Piece.Color.String(),
		func() *string {
			if record.Move.CapturedPiece != nil {
				s := record.Move.CapturedPiece.Type.String()
				return &s
			}
			return nil
		}(),
		record.Move.IsPromotion,
		func() *string {
			if record.Move.IsPromotion {
				s := record.Move.Promotion.String()
				return &s
			}
			return nil
		}(),
		record.Move.IsCastling,
		record.Timestamp,
		record.RecordedAt,
	)

	if err != nil {
		logf("❌ Failed to insert move %d for game %s: %v",
			record.MoveNumber, record.GameID[:8], err)
	}
}

// Shutdown gracefully shuts down the move recorder
func ShutdownMoveRecorder() error {
	if moveRecorder == nil {
		return nil
	}

	logf("🛑 Shutting down move recorder...")
	moveRecorder.cancel()

	// Wait for all workers to finish processing remaining moves
	done := make(chan struct{})
	go func() {
		moveRecorder.wg.Wait()
		close(done)
	}()

	select {
	case <-done:
		logf("✅ Move recorder shutdown complete")
		return nil
	case <-time.After(10 * time.Second):
		logf("⚠️ Move recorder shutdown timeout")
		return fmt.Errorf("move recorder shutdown timeout")
	}
}

// GetMoveHistory retrieves all moves for a game in order
func GetMoveHistory(gameID string) ([]MoveRecord, error) {
	if moveRecorder == nil {
		return nil, fmt.Errorf("move recorder not initialized")
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	rows, err := moveRecorder.pool.Query(ctx, `
		SELECT 
			game_id, move_number, from_row, from_col, to_row, to_col,
			piece_type, piece_color, captured_piece, is_promotion, promotion_type,
			is_castling, move_timestamp, recorded_at
		FROM move_records
		WHERE game_id = $1
		ORDER BY move_number ASC
	`, gameID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var moves []MoveRecord
	for rows.Next() {
		var (
			gameID         string
			moveNumber     int
			fromRow, fromCol, toRow, toCol int
			pieceType, pieceColor string
			capturedPiece *string
			isPromotion bool
			promotionType *string
			isCastling bool
			timestamp, recordedAt time.Time
		)

		if err := rows.Scan(
			&gameID, &moveNumber, &fromRow, &fromCol, &toRow, &toCol,
			&pieceType, &pieceColor, &capturedPiece, &isPromotion, &promotionType,
			&isCastling, &timestamp, &recordedAt,
		); err != nil {
			return nil, err
		}

		// Reconstruct move from database fields
		move := &engine.Move{
			From: engine.Position{Row: fromRow, Col: fromCol},
			To:   engine.Position{Row: toRow, Col: toCol},
			IsCastling: isCastling,
			IsPromotion: isPromotion,
		}

		moves = append(moves, MoveRecord{
			GameID:     gameID,
			MoveNumber: moveNumber,
			Move:       move,
			Timestamp:  timestamp,
			RecordedAt: recordedAt,
		})
	}

	return moves, rows.Err()
}
