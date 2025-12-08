package main

import (
	"fmt"
	"time"

	"github.com/metaphy6/chessrecast/internal/engine"
)

// logf prints a timestamped log message (MM-DD HH:mm:ss.SSS)
func logf(format string, args ...interface{}) {
    timestamp := time.Now().Format("01-02 15:04:05.000")
    msg := fmt.Sprintf(format, args...)
    fmt.Printf("[%s] %s\n", timestamp, msg)
}

// parseGameMode converts string to GameMode
func parseGameMode(mode string) engine.GameMode {
    // Use the engine's ParseGameMode function which has all modes
    return engine.ParseGameMode(mode)
}

// parsePosition converts algebraic notation to Position
func parsePosition(notation string) (engine.Position, error) {
    if len(notation) != 2 {
        return engine.Position{}, nil
    }

    col := int(notation[0] - 'a')
    row := int(notation[1] - '1')

    return engine.Position{Row: row, Col: col}, nil
}
