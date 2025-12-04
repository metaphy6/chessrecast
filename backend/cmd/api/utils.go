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
    switch mode {
    case "classic":
        return engine.Classic
    case "other_side":
        return engine.OtherSide
    case "royal_pawns":
        return engine.RoyalPawns
    case "save_the_queen":
        return engine.SaveTheQueen
    case "save_the_king":
        return engine.SaveTheKing
    case "snare":
        return engine.Snare
    default:
        return engine.Classic
    }
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
