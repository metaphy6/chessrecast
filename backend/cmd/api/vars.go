package main

import (
	"net/http"
	"sync"

	"github.com/gorilla/websocket"
	"github.com/metaphy6/chessrecast/internal/game"
)

var gameService *game.Service

// WebSocket upgrader
var upgrader = websocket.Upgrader{
    CheckOrigin: func(r *http.Request) bool { return true },
}

// ConnectionManager manages all WebSocket connections
type ConnectionManager struct {
    connections map[string]map[string]*GameConnection // gameID -> playerID -> connection
    mu          sync.RWMutex
}

var connManager = &ConnectionManager{
    connections: make(map[string]map[string]*GameConnection),
}
