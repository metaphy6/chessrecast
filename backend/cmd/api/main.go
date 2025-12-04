package main

import (
	"os"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/metaphy6/chessrecast/internal/game"
	"github.com/metaphy6/chessrecast/internal/storage"
)

func main() {
	// Initialize game logger (database connection)
	if err := storage.InitGameLogger(); err != nil {
		logf("⚠️ Warning: Game logger initialization failed: %v", err)
		logf("Bot game moves will NOT be logged to database")
	}

	// Initialize move recorder (high-performance streaming with worker pool)
	pool := storage.GetDatabasePool()
	if pool != nil {
		if err := storage.InitMoveRecorder(pool, 3); err != nil {
			logf("⚠️ Warning: Move recorder initialization failed: %v", err)
			logf("Moves will NOT be streamed to database in real-time")
		}
	}

	// Initialize game service
	gameService = game.NewService()

	r := gin.Default()

	// register routes from routes.go
	registerRoutes(r)

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	logf("Starting ChessRecast API on port %s", port)
	// Give postgres some time if starting in container-based environment
	time.Sleep(10 * time.Millisecond)
	if err := r.Run(":" + port); err != nil {
		logf("FATAL: failed to start server: %v", err)
		os.Exit(1)
	}
}

// all handlers, websocket helpers and helpers have been moved to separate files
