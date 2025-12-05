package main

import (
	"github.com/gin-gonic/gin"
)

func registerRoutes(r *gin.Engine) {
    // Health checks
    r.GET("/healthz", func(c *gin.Context) { c.JSON(200, gin.H{"status": "ok"}) })
    r.GET("/health", func(c *gin.Context) { c.JSON(200, gin.H{"status": "ok"}) })

    r.GET("/", func(c *gin.Context) { c.JSON(200, gin.H{"message": "ChessRecast API (dev)"}) })

    // API v1 routes
    v1 := r.Group("/api/v1")
    {
        // Auth routes
        auth := v1.Group("/auth")
        {
            auth.POST("/guest", handleGuestLogin)
        }

        // Bot routes
        bots := v1.Group("/bots")
        {
            bots.POST("/vs-bot", handleBotVsBot)
            bots.POST("/custom-board", handleCustomBoardBotVsBot)
        }

        // Game routes
        games := v1.Group("/games")
        {
            games.POST("", handleCreateGame)
            games.GET("/:id", handleGetGame)
            games.POST("/:id/moves", handleMakeMove)
            games.POST("/:id/pause", handlePauseGame)
            games.POST("/:id/resume", handleResumeGame)
            games.POST("/:id/stop", handleStopGame)
            games.POST("/:id/delay", handleSetDelay)
            games.GET("/:id/status", handleGetGameStatus)
        }

        // Game records routes (simplified notation storage)
        records := v1.Group("/records")
        {
            records.GET("", handleGetGameRecords)
            records.GET("/:game_id", handleGetGameRecord)
        }

        // Database health/test routes
        db := v1.Group("/db")
        {
            db.GET("/test", handleDatabaseTest)
            db.GET("/health", handleDatabaseHealth)
            db.DELETE("/reset", handleDatabaseReset)
        }

        // WebSocket routes
        ws := v1.Group("/ws")
        {
            ws.GET("/game/:id", handleGameWebSocket)
        }
    }
}
