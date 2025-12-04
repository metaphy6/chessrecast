package main

import (
	"encoding/json"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/gorilla/websocket"
	"github.com/metaphy6/chessrecast/internal/engine"
	"github.com/metaphy6/chessrecast/internal/game"
)

// GameConnection represents a WebSocket connection to a game
type GameConnection struct {
    conn     *websocket.Conn
    gameID   string
    playerID string
    send     chan []byte
    done     chan struct{} // Signal to stop subscribing
}

// addConnection registers a new WebSocket connection
func (cm *ConnectionManager) addConnection(conn *GameConnection) {
    cm.mu.Lock()
    defer cm.mu.Unlock()

    if cm.connections[conn.gameID] == nil {
        cm.connections[conn.gameID] = make(map[string]*GameConnection)
    }
    cm.connections[conn.gameID][conn.playerID] = conn
}

// removeConnection unregisters a WebSocket connection
func (cm *ConnectionManager) removeConnection(conn *GameConnection) {
    cm.mu.Lock()
    defer cm.mu.Unlock()

    if gameConns, ok := cm.connections[conn.gameID]; ok {
        delete(gameConns, conn.playerID)
        if len(gameConns) == 0 {
            delete(cm.connections, conn.gameID)
        }
    }
}

// broadcastToGame sends a message to all connections for a game
func (cm *ConnectionManager) broadcastToGame(gameID string, message []byte) {
    cm.mu.RLock()
    defer cm.mu.RUnlock()

    if gameConns, ok := cm.connections[gameID]; ok {
        for _, conn := range gameConns {
            select {
            case conn.send <- message:
            default:
                // Channel full, skip
            }
        }
    }
}

// writePump pumps messages from the send channel to the WebSocket connection
func (gc *GameConnection) writePump() {
    defer func() {
        gc.conn.Close()
        connManager.removeConnection(gc)
        logf("🔌 WebSocket: Connection closed for game %s, player %s", gc.gameID, gc.playerID)
    }()

    for message := range gc.send {
        if err := gc.conn.WriteMessage(websocket.TextMessage, message); err != nil {
            logf("WebSocket write error: %v", err)
            return
        }
    }
}

// readPump pumps messages from the WebSocket connection
func (gc *GameConnection) readPump() {
    defer func() {
        close(gc.done) // Signal subscribeToGame to stop
        close(gc.send)
    }()

    for {
        _, message, err := gc.conn.ReadMessage()
        if err != nil {
            if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
                logf("WebSocket read error: %v", err)
            }
            return
        }

        // Handle incoming messages (e.g., moves from client)
        gc.handleMessage(message)
    }
}

// WSMessage represents a WebSocket message
type WSMessage struct {
    Type    string          `json:"type"`
    Payload json.RawMessage `json:"payload,omitempty"`
}

// WSMovePayload represents a move message payload
type WSMovePayload struct {
    From      string `json:"from"`
    To        string `json:"to"`
    Promotion string `json:"promotion,omitempty"`
}

// WSGameState represents the game state sent over WebSocket
type WSGameState struct {
    Type        string `json:"type"`
    GameID      string `json:"game_id"`
    State       string `json:"state"`
    CurrentTurn string `json:"current_turn"`
    Board       string `json:"board,omitempty"` // FEN or custom format
    LastMove    string `json:"last_move,omitempty"`
}

// handleMessage processes incoming WebSocket messages
func (gc *GameConnection) handleMessage(message []byte) {
    var msg WSMessage
    if err := json.Unmarshal(message, &msg); err != nil {
        logf("Invalid WebSocket message: %v", err)
        return
    }

    switch msg.Type {
    case "move":
        var movePayload WSMovePayload
        if err := json.Unmarshal(msg.Payload, &movePayload); err != nil {
            logf("Invalid move payload: %v", err)
            return
        }
        gc.handleMoveMessage(movePayload)

    case "ping":
        gc.sendPong()

    case "get_state":
        gc.sendGameState()
    }
}

// handleMoveMessage processes a move from the client
func (gc *GameConnection) handleMoveMessage(payload WSMovePayload) {
    from, _ := parsePosition(payload.From)
    to, _ := parsePosition(payload.To)

    move := engine.Move{
        From: from,
        To:   to,
    }

    resp, err := gameService.MakeMove(gc.gameID, gc.playerID, move)
    if err != nil || !resp.Success {
        // Send error back to client
        errMsg, _ := json.Marshal(map[string]interface{}{
            "type":  "error",
            "error": "Invalid move",
        })
        gc.send <- errMsg
        return
    }

    // Broadcast updated game state to all players
    gc.broadcastGameUpdate(resp.Update)
}

// sendGameState sends the current game state to this connection
func (gc *GameConnection) sendGameState() {
    session, err := gameService.GetSession(gc.gameID)
    if err != nil {
        return
    }

    state := WSGameState{
        Type:        "game_state",
        GameID:      session.ID,
        State:       session.State.String(),
        CurrentTurn: session.Board.CurrentTurn.String(),
        Board:       session.Board.ToFEN(),
    }

    msg, _ := json.Marshal(state)
    gc.send <- msg
}

// sendPong sends a pong response
func (gc *GameConnection) sendPong() {
    msg, _ := json.Marshal(map[string]string{"type": "pong"})
    gc.send <- msg
}

// broadcastGameUpdate broadcasts a game update to all connected clients
func (gc *GameConnection) broadcastGameUpdate(update *game.GameUpdate) {
    state := WSGameState{
        Type:        "game_update",
        GameID:      update.GameID,
        State:       update.State.String(),
        CurrentTurn: update.Board.CurrentTurn.String(),
        Board:       update.Board.ToFEN(),
    }

    if update.LastMove != nil {
        state.LastMove = update.LastMove.ToAlgebraic()
    }

    msg, _ := json.Marshal(state)
    connManager.broadcastToGame(gc.gameID, msg)
}

// subscribeToGame subscribes to game updates from the game service
func (gc *GameConnection) subscribeToGame() {
    updateChan, err := gameService.Subscribe(gc.gameID, gc.playerID)
    if err != nil {
        logf("Failed to subscribe to game %s: %v", gc.gameID, err)
        return
    }

    defer gameService.Unsubscribe(gc.gameID, gc.playerID)

    for {
        select {
        case <-gc.done:
            // Connection is closing, stop subscribing
            return
        case update, ok := <-updateChan:
            if !ok {
                // Update channel was closed
                return
            }

            state := WSGameState{
                Type:        "game_update",
                GameID:      update.GameID,
                State:       update.State.String(),
                CurrentTurn: update.Board.CurrentTurn.String(),
                Board:       update.Board.ToFEN(),
            }

            if update.LastMove != nil {
                state.LastMove = update.LastMove.ToAlgebraic()
            }

            msg, _ := json.Marshal(state)
            select {
            case gc.send <- msg:
            case <-gc.done:
                // Connection closing, don't send
                return
            default:
                // Channel full, skip
            }
        }
    }
}

// handleGameWebSocket handles WebSocket connections for game updates
func handleGameWebSocket(c *gin.Context) {
    gameID := c.Param("id")
    playerID := c.Query("player_id")

    if playerID == "" {
        playerID = uuid.New().String()
    }

    // Upgrade HTTP connection to WebSocket
    conn, err := upgrader.Upgrade(c.Writer, c.Request, nil)
    if err != nil {
        logf("WebSocket upgrade failed: %v", err)
        return
    }

    logf("🔌 WebSocket: New connection for game %s, player %s", gameID, playerID)

    // Create connection wrapper
    gameConn := &GameConnection{
        conn:     conn,
        gameID:   gameID,
        playerID: playerID,
        send:     make(chan []byte, 256),
        done:     make(chan struct{}),
    }

    // Register connection
    connManager.addConnection(gameConn)

    // Start goroutines for reading and writing
    go gameConn.writePump()
    go gameConn.readPump()

    // Send initial game state
    gameConn.sendGameState()

    // Subscribe to game updates
    go gameConn.subscribeToGame()
}
