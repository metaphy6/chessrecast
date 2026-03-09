package main

import (
	"context"
	"strconv"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/metaphy6/chessrecast/internal/ai"
	"github.com/metaphy6/chessrecast/internal/engine"
	"github.com/metaphy6/chessrecast/internal/game"
	"github.com/metaphy6/chessrecast/internal/storage"
)

const invalidRequestMsg = "Invalid request"

// handleGuestLogin creates a guest user session
func handleGuestLogin(c *gin.Context) {
    userID := uuid.New().String()
    token := uuid.New().String() // Simplified token for dev

    c.JSON(200, gin.H{
        "user_id": userID,
        "token":   token,
        "message": "Guest login successful",
    })
}

// BotVsBotRequest represents a bot vs bot game request
type BotVsBotRequest struct {
    Mod            string `json:"mode"`
    WhiteDifficulty int    `json:"white_difficulty"`
    BlackDifficulty int    `json:"black_difficulty"`
    AutoPlay        bool   `json:"auto_play"`
    MoveDelay       int    `json:"move_delay"`
}

// handleBotVsBot creates a bot vs bot game
func handleBotVsBot(c *gin.Context) {
    var req BotVsBotRequest
    if err := c.ShouldBindJSON(&req); err != nil {
        c.JSON(400, gin.H{"error": invalidRequestMsg + ": " + err.Error()})
        return
    }

    // Parse game mod
    GameMod := parseGameMod(req.Mod)

    // Create white bot player
    whiteBot := ai.NewBot(req.WhiteDifficulty, engine.White)
    whitePlayer := &game.Player{
        ID:    uuid.New().String(),
        Type:  game.AI,
        Color: engine.White,
        Bot:   whiteBot,
    }

    // Create black bot player
    blackBot := ai.NewBot(req.BlackDifficulty, engine.Black)
    blackPlayer := &game.Player{
        ID:    uuid.New().String(),
        Type:  game.AI,
        Color: engine.Black,
        Bot:   blackBot,
    }

    // Create game session
    session, err := gameService.CreateGame(GameMod, whitePlayer, blackPlayer)
    if err != nil {
        c.JSON(500, gin.H{"error": "Failed to create game: " + err.Error()})
        return
    }

    // If auto-play, start the bot vs bot game loop
    if req.AutoPlay {
        go gameService.PlayBotVsBot(session.ID, req.MoveDelay)
    }

    c.JSON(201, gin.H{
        "game_id": session.ID,
        "message": "Bot vs Bot game created",
        "white":   gin.H{"difficulty": req.WhiteDifficulty},
        "black":   gin.H{"difficulty": req.BlackDifficulty},
    })
}

// CustomBoardBotVsBotRequest represents a custom board bot vs bot game request
type CustomBoardBotVsBotRequest struct {
    Mod            string               `json:"mode"`
    Pieces          []engine.CustomPiece `json:"pieces"`
    CurrentPlayer   string               `json:"current_player"` // "white" or "black"
    WhiteDifficulty int                  `json:"white_difficulty"`
    BlackDifficulty int                  `json:"black_difficulty"`
    AutoPlay        bool                 `json:"auto_play"`
    MoveDelay       int                  `json:"move_delay"`
}

// CustomBoardHumanVsBotRequest represents a custom board human vs bot game request
type CustomBoardHumanVsBotRequest struct {
    Mod          string                `json:"mode"`
    Pieces        []engine.CustomPiece `json:"pieces"`
    CurrentPlayer string                `json:"current_player"`
    BotDifficulty int                   `json:"bot_difficulty"`
    HumanColor    string                `json:"human_color"` // "white" or "black"
}

// handleCustomBoardHumanVsBot creates a human vs bot game with custom board
func handleCustomBoardHumanVsBot(c *gin.Context) {
    var req CustomBoardHumanVsBotRequest
    if err := c.ShouldBindJSON(&req); err != nil {
        c.JSON(400, gin.H{"error": invalidRequestMsg + ": " + err.Error()})
        return
    }

    GameMod := parseGameMod(req.Mod)
    currentPlayer := engine.White
    if req.CurrentPlayer == "black" {
        currentPlayer = engine.Black
    }

    humanColor := engine.White
    if req.HumanColor == "black" {
        humanColor = engine.Black
    }
    botColor := humanColor.Opposite()

    // Create players
    humanPlayer := &game.Player{
        ID:    uuid.New().String(),
        Type:  game.Human,
        Color: humanColor,
    }

    bot := ai.NewBot(req.BotDifficulty, botColor)
    botPlayer := &game.Player{
        ID:    uuid.New().String(),
        Type:  game.AI,
        Color: botColor,
        Bot:   bot,
    }

    // Determine white and black players based on colors
    var whitePlayer, blackPlayer *game.Player
    if humanColor == engine.White {
        whitePlayer = humanPlayer
        blackPlayer = botPlayer
    } else {
        whitePlayer = botPlayer
        blackPlayer = humanPlayer
    }

    // Create game session
    session, err := gameService.CreateGameWithCustomBoard(
        GameMod,
        req.Pieces,
        currentPlayer,
        whitePlayer,
        blackPlayer,
    )
    if err != nil {
        c.JSON(500, gin.H{"error": "Failed to create game: " + err.Error()})
        return
    }

    // Create initial game record
    whiteDiff := 0
    blackDiff := 0
    if whitePlayer.Type == game.AI {
        whiteDiff = req.BotDifficulty
    } else {
        blackDiff = req.BotDifficulty
    }
    storage.InitGameRecord(session.ID, GameMod.String(), whiteDiff, blackDiff)

    logf("✅ Custom board game created: %s (mode: %s, human: %s, bot: %s)", session.ID, GameMod.String(), humanColor, botColor)

    c.JSON(201, gin.H{
        "game_id":   session.ID,
        "player_id": humanPlayer.ID,
    })
}

// handleCustomBoardBotVsBot creates a bot vs bot game with custom board
func handleCustomBoardBotVsBot(c *gin.Context) {
    var req CustomBoardBotVsBotRequest
    if err := c.ShouldBindJSON(&req); err != nil {
        c.JSON(400, gin.H{"error": invalidRequestMsg + ": " + err.Error()})
        return
    }

    // Parse game mod
    GameMod := parseGameMod(req.Mod)

    // Parse current player
    currentTurn := engine.White
    if req.CurrentPlayer == "black" {
        currentTurn = engine.Black
    }

    // Create white bot player
    whiteBot := ai.NewBot(req.WhiteDifficulty, engine.White)
    whitePlayer := &game.Player{
        ID:    uuid.New().String(),
        Type:  game.AI,
        Color: engine.White,
        Bot:   whiteBot,
    }

    // Create black bot player
    blackBot := ai.NewBot(req.BlackDifficulty, engine.Black)
    blackPlayer := &game.Player{
        ID:    uuid.New().String(),
        Type:  game.AI,
        Color: engine.Black,
        Bot:   blackBot,
    }

    // Create game session with custom board
    session, err := gameService.CreateGameWithCustomBoard(GameMod, req.Pieces, currentTurn, whitePlayer, blackPlayer)
    if err != nil {
        c.JSON(500, gin.H{"error": "Failed to create game: " + err.Error()})
        return
    }

    // Create initial game record in database
    storage.InitGameRecord(session.ID, GameMod.String(), req.WhiteDifficulty, req.BlackDifficulty)

    logf("🎲 Custom board Bot vs Bot game created: %s (mode: %s)", session.ID, GameMod)

    // If auto-play, start the bot vs bot game loop
    if req.AutoPlay {
        go gameService.PlayBotVsBot(session.ID, req.MoveDelay)
    }

    c.JSON(201, gin.H{
        "game_id":        session.ID,
        "message":        "Custom Board Bot vs Bot game created",
        "mode":           GameMod.String(),
        "current_player": req.CurrentPlayer,
        "pieces_count":   len(req.Pieces),
        "white":          gin.H{"difficulty": req.WhiteDifficulty},
        "black":          gin.H{"difficulty": req.BlackDifficulty},
    })
}

// CreateGameRequest represents a game creation request
type CreateGameRequest struct {
    Mod          string `json:"mode"`
    BotDifficulty *int   `json:"bot_difficulty,omitempty"`
    OpponentID    string `json:"opponent_id,omitempty"`
}

// handleCreateGame creates a new game
func handleCreateGame(c *gin.Context) {
    var req CreateGameRequest
    if err := c.ShouldBindJSON(&req); err != nil {
        c.JSON(400, gin.H{"error": invalidRequestMsg})
        return
    }

    GameMod := parseGameMod(req.Mod)

    // Create human player (white)
    humanPlayer := &game.Player{
        ID:    uuid.New().String(),
        Type:  game.Human,
        Color: engine.White,
    }

    // Create opponent (bot or human)
    var opponent *game.Player
    if req.BotDifficulty != nil {
        bot := ai.NewBot(*req.BotDifficulty, engine.Black)
        opponent = &game.Player{
            ID:    uuid.New().String(),
            Type:  game.AI,
            Color: engine.Black,
            Bot:   bot,
        }
    } else {
        opponent = &game.Player{
            ID:    req.OpponentID,
            Type:  game.Human,
            Color: engine.Black,
        }
    }

    session, err := gameService.CreateGame(GameMod, humanPlayer, opponent)
    if err != nil {
        c.JSON(500, gin.H{"error": "Failed to create game"})
        return
    }

    // Create initial game record in database to satisfy foreign key constraint for move streaming
    whiteDiff := 0
    blackDiff := 0
    if opponent.Type == game.AI && opponent.Bot != nil {
        blackDiff = opponent.Bot.Difficulty
    }
    storage.InitGameRecord(session.ID, GameMod.String(), whiteDiff, blackDiff)

    logf("✅ Game created: %s (mode: %s, white: human, black: %s)", session.ID, GameMod.String(), opponent.Type)

    c.JSON(201, gin.H{
        "game_id":   session.ID,
        "player_id": humanPlayer.ID,
    })
}

// handleGetGame returns game state
func handleGetGame(c *gin.Context) {
    gameID := c.Param("id")

    session, err := gameService.GetSession(gameID)
    if err != nil {
        c.JSON(404, gin.H{"error": "Game not found"})
        return
    }

    c.JSON(200, gin.H{
        "game_id":      session.ID,
        "state":        session.State.String(),
        "current_turn": session.Board.CurrentTurn.String(),
        "board":        session.Board.ToFEN(),
        "created_at":   session.CreatedAt,
    })
}

// MoveRequest represents a move request
type MoveRequest struct {
    From      string `json:"from"`
    To        string `json:"to"`
    Promotion string `json:"promotion,omitempty"`
    PlayerID  string `json:"player_id,omitempty"`
}

// handleMakeMove processes a move
func handleMakeMove(c *gin.Context) {
    gameID := c.Param("id")

    var req MoveRequest
    if err := c.ShouldBindJSON(&req); err != nil {
        logf("❌ Move request parse error for game %s: %v", gameID, err)
        c.JSON(400, gin.H{"error": "Invalid request: " + err.Error()})
        return
    }

    logf("🎯 Move request for game %s: from=%s to=%s promotion=%s", gameID, req.From, req.To, req.Promotion)

    // Parse positions
    from, err := parsePosition(req.From)
    if err != nil {
        logf("❌ Invalid from position '%s' for game %s: %v", req.From, gameID, err)
        c.JSON(400, gin.H{"error": "Invalid from position: " + req.From})
        return
    }

    to, err := parsePosition(req.To)
    if err != nil {
        logf("❌ Invalid to position '%s' for game %s: %v", req.To, gameID, err)
        c.JSON(400, gin.H{"error": "Invalid to position: " + req.To})
        return
    }

    move := engine.Move{
        From: from,
        To:   to,
    }

    // Get player ID from request body, or use query param, or fallback to temp
    playerID := req.PlayerID
    if playerID == "" {
        playerID = c.Query("player_id")
    }
    if playerID == "" {
        // For backward compatibility or testing
        playerID = "temp-player"
        logf("⚠️ No player_id provided for game %s, using temp-player", gameID)
    }

    resp, err := gameService.MakeMove(gameID, playerID, move)
    if err != nil {
        logf("❌ MakeMove service error for game %s: %v", gameID, err)
        c.JSON(500, gin.H{"error": err.Error()})
        return
    }

    if !resp.Success {
        logf("❌ Move failed for game %s: %v", gameID, resp.Error)
        c.JSON(400, gin.H{"error": resp.Error.Error()})
        return
    }

    logf("✅ Move successful for game %s: %s -> %s", gameID, req.From, req.To)
    c.JSON(200, gin.H{
        "success": true,
        "state":   resp.Update.State.String(),
    })
}

// handlePauseGame pauses a bot vs bot game
func handlePauseGame(c *gin.Context) {
    gameID := c.Param("id")

    if err := gameService.PauseGame(gameID); err != nil {
        c.JSON(500, gin.H{"error": err.Error()})
        return
    }

    c.JSON(200, gin.H{"status": "paused", "game_id": gameID})
}

// handleResumeGame resumes a paused bot vs bot game
func handleResumeGame(c *gin.Context) {
    gameID := c.Param("id")

    if err := gameService.ResumeGame(gameID); err != nil {
        c.JSON(500, gin.H{"error": err.Error()})
        return
    }

    c.JSON(200, gin.H{"status": "resumed", "game_id": gameID})
}

// handleStopGame stops a bot vs bot game
func handleStopGame(c *gin.Context) {
    gameID := c.Param("id")

    if err := gameService.StopGame(gameID); err != nil {
        c.JSON(500, gin.H{"error": err.Error()})
        return
    }

    c.JSON(200, gin.H{"status": "stopped", "game_id": gameID})
}

// DelayRequest represents a delay update request
type DelayRequest struct {
    DelayMs int `json:"delay_ms"`
}

// handleSetDelay updates the move delay for a bot vs bot game
func handleSetDelay(c *gin.Context) {
    gameID := c.Param("id")

    var req DelayRequest
    if err := c.ShouldBindJSON(&req); err != nil {
        c.JSON(400, gin.H{"error": "Invalid request"})
        return
    }

    if err := gameService.SetMoveDelay(gameID, req.DelayMs); err != nil {
        c.JSON(500, gin.H{"error": err.Error()})
        return
    }

    c.JSON(200, gin.H{"status": "updated", "game_id": gameID, "delay_ms": req.DelayMs})
}

// handleGetGameStatus returns the current status of a game
func handleGetGameStatus(c *gin.Context) {
    gameID := c.Param("id")

    status, err := gameService.GetGameStatus(gameID)
    if err != nil {
        c.JSON(404, gin.H{"error": "Game not found"})
        return
    }

    c.JSON(200, status)
}

// handleGetGameRecords returns game records filtered by mode
func handleGetGameRecords(c *gin.Context) {
    mode := c.Query("mode")
    limitStr := c.DefaultQuery("limit", "100")
    limit, _ := strconv.Atoi(limitStr)

    records, err := storage.GetGameRecords(context.Background(), mode, limit)
    if err != nil {
        c.JSON(500, gin.H{"error": err.Error()})
        return
    }

    c.JSON(200, gin.H{
        "count":   len(records),
        "records": records,
    })
}

// handleGetGameRecord returns a specific game record by ID
func handleGetGameRecord(c *gin.Context) {
    gameID := c.Param("game_id")

    records, err := storage.GetGameRecords(context.Background(), "", 1000)
    if err != nil {
        c.JSON(500, gin.H{"error": err.Error()})
        return
    }

    // Find the record with matching game_id
    for _, record := range records {
        if record.GameID == gameID {
            c.JSON(200, record)
            return
        }
    }

    c.JSON(404, gin.H{"error": "Game record not found"})
}

// handleDatabaseTest runs a comprehensive database connection test
func handleDatabaseTest(c *gin.Context) {
    result, err := storage.TestDatabaseConnection(context.Background())
    if err != nil {
        c.JSON(500, gin.H{
            "status": "error",
            "error":  err.Error(),
        })
        return
    }

    c.JSON(200, result)
}

// handleDatabaseHealth returns a simple database health check
func handleDatabaseHealth(c *gin.Context) {
    result, err := storage.TestDatabaseConnection(context.Background())
    if err != nil {
        c.JSON(503, gin.H{
            "status": "unhealthy",
            "error":  err.Error(),
        })
        return
    }

    c.JSON(200, gin.H{
        "status": "healthy",
        "details": result,
    })
}

// handleDatabaseReset clears all data from database tables (for development/testing)
func handleDatabaseReset(c *gin.Context) {
    result, err := storage.ResetDatabase(context.Background())
    if err != nil {
        c.JSON(500, gin.H{
            "status": "error",
            "error":  err.Error(),
        })
        return
    }

    c.JSON(200, gin.H{
        "status":           "success",
        "tables_cleared":   result.TablesCleared,
        "rows_deleted":     result.RowsDeleted,
        "all_tables_empty": result.AllTablesEmpty,
        "message":          result.Message,
    })
}
