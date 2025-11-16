package game

import (
	"errors"
	"fmt"
	"sync"
	"time"

	"github.com/google/uuid"
	"github.com/metaphy6/chessrecast/internal/ai"
	"github.com/metaphy6/chessrecast/internal/engine"
)

// PlayerType represents the type of player
type PlayerType string

const (
	Human PlayerType = "human"
	AI    PlayerType = "ai"
)

// Player represents a game participant
type Player struct {
	ID         string
	Type       PlayerType
	Color      engine.Color
	Bot        *ai.Bot // Only for AI players
	Connected  bool
	LastActive time.Time
}

// Session represents an active game session
type Session struct {
	ID            string
	Board         *engine.Board
	WhitePlayer   *Player
	BlackPlayer   *Player
	State         engine.GameState
	Result        *engine.GameResult
	CreatedAt     time.Time
	UpdatedAt     time.Time
	LastMoveAt    time.Time
	Spectators    []string // Player IDs watching the game
	
	mu            sync.RWMutex
	moveChannel   chan MoveRequest
	subscribers   map[string]chan GameUpdate
}

// MoveRequest represents a move request from a player
type MoveRequest struct {
	PlayerID string
	Move     engine.Move
	Response chan MoveResponse
}

// MoveResponse contains the result of a move attempt
type MoveResponse struct {
	Success bool
	Error   error
	Update  *GameUpdate
}

// GameUpdate represents a game state change
type GameUpdate struct {
	GameID    string
	Board     *engine.Board
	LastMove  *engine.Move
	State     engine.GameState
	Result    *engine.GameResult
	Timestamp time.Time
}

// Service manages game sessions
type Service struct {
	sessions map[string]*Session
	mu       sync.RWMutex
}

// NewService creates a new game service
func NewService() *Service {
	return &Service{
		sessions: make(map[string]*Session),
	}
}

// CreateGame creates a new game session
func (s *Service) CreateGame(mode engine.GameMode, whitePlayer, blackPlayer *Player) (*Session, error) {
	sessionID := uuid.New().String()
	board := engine.NewBoard(mode)

	session := &Session{
		ID:          sessionID,
		Board:       board,
		WhitePlayer: whitePlayer,
		BlackPlayer: blackPlayer,
		State:       engine.InProgress,
		CreatedAt:   time.Now(),
		UpdatedAt:   time.Now(),
		LastMoveAt:  time.Now(),
		Spectators:  []string{},
		moveChannel: make(chan MoveRequest, 100),
		subscribers: make(map[string]chan GameUpdate),
	}

	// Start game loop
	go session.run()

	// If AI players, trigger their moves
	if whitePlayer.Type == AI && board.CurrentTurn == engine.White {
		go session.triggerAIMove()
	}

	s.mu.Lock()
	s.sessions[sessionID] = session
	s.mu.Unlock()

	return session, nil
}

// GetSession retrieves a game session
func (s *Service) GetSession(sessionID string) (*Session, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	session, exists := s.sessions[sessionID]
	if !exists {
		return nil, errors.New("session not found")
	}

	return session, nil
}

// MakeMove attempts to make a move in a session
func (s *Service) MakeMove(sessionID, playerID string, move engine.Move) (*MoveResponse, error) {
	session, err := s.GetSession(sessionID)
	if err != nil {
		return nil, err
	}

	// Validate player
	if !session.isPlayerTurn(playerID) {
		return &MoveResponse{
			Success: false,
			Error:   errors.New("not your turn"),
		}, nil
	}

	// Send move request to session
	response := make(chan MoveResponse, 1)
	session.moveChannel <- MoveRequest{
		PlayerID: playerID,
		Move:     move,
		Response: response,
	}

	// Wait for response with timeout
	select {
	case resp := <-response:
		return &resp, nil
	case <-time.After(5 * time.Second):
		return &MoveResponse{
			Success: false,
			Error:   errors.New("move timeout"),
		}, nil
	}
}

// ResignGame allows a player to resign
func (s *Service) ResignGame(sessionID, playerID string) error {
	session, err := s.GetSession(sessionID)
	if err != nil {
		return err
	}

	session.mu.Lock()
	defer session.mu.Unlock()

	// Determine winner
	var winner engine.Color
	if session.WhitePlayer.ID == playerID {
		winner = engine.Black
	} else if session.BlackPlayer.ID == playerID {
		winner = engine.White
	} else {
		return errors.New("player not in game")
	}

	session.State = engine.Resigned
	session.Result = &engine.GameResult{
		State:  engine.Resigned,
		Winner: winner,
		Reason: "Opponent resigned",
	}
	session.UpdatedAt = time.Now()

	session.broadcastUpdate(GameUpdate{
		GameID:    session.ID,
		Board:     session.Board,
		State:     session.State,
		Result:    session.Result,
		Timestamp: time.Now(),
	})

	return nil
}

// Subscribe adds a subscriber to receive game updates
func (s *Service) Subscribe(sessionID, subscriberID string) (<-chan GameUpdate, error) {
	session, err := s.GetSession(sessionID)
	if err != nil {
		return nil, err
	}

	session.mu.Lock()
	defer session.mu.Unlock()

	updateChan := make(chan GameUpdate, 10)
	session.subscribers[subscriberID] = updateChan

	return updateChan, nil
}

// Unsubscribe removes a subscriber
func (s *Service) Unsubscribe(sessionID, subscriberID string) {
	session, err := s.GetSession(sessionID)
	if err != nil {
		return
	}

	session.mu.Lock()
	defer session.mu.Unlock()

	if ch, exists := session.subscribers[subscriberID]; exists {
		close(ch)
		delete(session.subscribers, subscriberID)
	}
}

// Session methods

// run is the main game loop
func (sess *Session) run() {
	ticker := time.NewTicker(1 * time.Minute)
	defer ticker.Stop()

	for {
		select {
		case req := <-sess.moveChannel:
			resp := sess.processMove(req)
			req.Response <- resp

			// If move was successful and next player is AI, trigger AI move
			if resp.Success && sess.State == engine.InProgress {
				currentPlayer := sess.getCurrentPlayer()
				if currentPlayer != nil && currentPlayer.Type == AI {
					go sess.triggerAIMove()
				}
			}

		case <-ticker.C:
			// Check for timeouts, inactive players, etc.
			sess.checkTimeout()
		}
	}
}

// processMove handles a move request
func (sess *Session) processMove(req MoveRequest) MoveResponse {
	sess.mu.Lock()
	defer sess.mu.Unlock()

	// Validate move is legal
	mg := engine.NewMoveGenerator(sess.Board)
	validMoves := mg.GetValidMoves(req.Move.From)
	
	isValid := false
	for _, validMove := range validMoves {
		if validMove.To.Equals(req.Move.To) {
			// Update move with full details from valid move
			req.Move = validMove
			isValid = true
			break
		}
	}

	if !isValid {
		return MoveResponse{
			Success: false,
			Error:   errors.New("invalid move"),
		}
	}

	// Execute move
	if err := sess.Board.MakeMove(req.Move); err != nil {
		return MoveResponse{
			Success: false,
			Error:   err,
		}
	}

	sess.UpdatedAt = time.Now()
	sess.LastMoveAt = time.Now()

	// Check game state
	sess.updateGameState()

	// Broadcast update
	update := GameUpdate{
		GameID:    sess.ID,
		Board:     sess.Board.Clone(),
		LastMove:  &req.Move,
		State:     sess.State,
		Result:    sess.Result,
		Timestamp: time.Now(),
	}
	sess.broadcastUpdate(update)

	return MoveResponse{
		Success: true,
		Update:  &update,
	}
}

// triggerAIMove requests AI to make a move
func (sess *Session) triggerAIMove() {
	time.Sleep(500 * time.Millisecond) // Simulate thinking time

	currentPlayer := sess.getCurrentPlayer()
	if currentPlayer == nil || currentPlayer.Bot == nil {
		return
	}

	move, err := currentPlayer.Bot.GetBestMove(sess.Board)
	if err != nil || move == nil {
		return
	}

	// Submit move
	response := make(chan MoveResponse, 1)
	sess.moveChannel <- MoveRequest{
		PlayerID: currentPlayer.ID,
		Move:     *move,
		Response: response,
	}

	// Wait for response
	<-response
}

// updateGameState checks for checkmate, stalemate, etc.
func (sess *Session) updateGameState() {
	// Generate all valid moves for current player
	mg := engine.NewMoveGenerator(sess.Board)
	hasValidMoves := false

	for row := 0; row < 8; row++ {
		for col := 0; col < 8; col++ {
			pos := engine.Position{Row: row, Col: col}
			moves := mg.GetValidMoves(pos)
			if len(moves) > 0 {
				hasValidMoves = true
				break
			}
		}
		if hasValidMoves {
			break
		}
	}

	if !hasValidMoves {
		// Checkmate or stalemate
		sess.State = engine.Stalemate
		sess.Result = &engine.GameResult{
			State:  engine.Stalemate,
			Reason: "No valid moves available",
		}
		// TODO: Distinguish checkmate from stalemate
	}

	// Check fifty-move rule
	if sess.Board.FiftyMoveRule >= 100 {
		sess.State = engine.Draw
		sess.Result = &engine.GameResult{
			State:  engine.Draw,
			Reason: "Fifty-move rule",
		}
	}
}

// broadcastUpdate sends update to all subscribers
func (sess *Session) broadcastUpdate(update GameUpdate) {
	for _, ch := range sess.subscribers {
		select {
		case ch <- update:
		default:
			// Channel full, skip
		}
	}
}

// Helper methods

func (sess *Session) isPlayerTurn(playerID string) bool {
	sess.mu.RLock()
	defer sess.mu.RUnlock()

	if sess.Board.CurrentTurn == engine.White {
		return sess.WhitePlayer.ID == playerID
	}
	return sess.BlackPlayer.ID == playerID
}

func (sess *Session) getCurrentPlayer() *Player {
	sess.mu.RLock()
	defer sess.mu.RUnlock()

	if sess.Board.CurrentTurn == engine.White {
		return sess.WhitePlayer
	}
	return sess.BlackPlayer
}

func (sess *Session) checkTimeout() {
	sess.mu.RLock()
	defer sess.mu.RUnlock()

	// TODO: Implement timeout logic
	// Check if players are connected
	// Check if game has been inactive too long
}

// PlayBotVsBot runs an automated game between two bots
func (s *Service) PlayBotVsBot(sessionID string, moveDelay int) error {
	session, err := s.GetSession(sessionID)
	if err != nil {
		fmt.Printf("❌ PlayBotVsBot: Failed to get session: %v\n", err)
		return err
	}

	fmt.Printf("🤖 PlayBotVsBot: Starting game %s with %dms delay\n", sessionID, moveDelay)

	// Safety checks
	if session.Board == nil {
		fmt.Println("❌ PlayBotVsBot: board is nil")
		return errors.New("board is nil")
	}
	if session.WhitePlayer == nil || session.BlackPlayer == nil {
		fmt.Println("❌ PlayBotVsBot: players not initialized")
		return errors.New("players not initialized")
	}
	if session.WhitePlayer.Bot == nil || session.BlackPlayer.Bot == nil {
		fmt.Println("❌ PlayBotVsBot: bot players not initialized")
		return errors.New("bot players not initialized")
	}

	// Verify both players are bots
	if session.WhitePlayer.Type != AI || session.BlackPlayer.Type != AI {
		fmt.Println("❌ PlayBotVsBot: both players must be AI")
		return errors.New("both players must be AI")
	}

	fmt.Printf("✅ PlayBotVsBot: Validation passed, starting game loop\n")
	fmt.Printf("🎮 Game Mode: %s\n", session.Board.Mode.String())
	fmt.Printf("🤖 White Bot: Difficulty %d\n", session.WhitePlayer.Bot.Difficulty)
	fmt.Printf("🤖 Black Bot: Difficulty %d\n", session.BlackPlayer.Bot.Difficulty)

	// Keep playing until game ends
	moveCount := 0
	for session.State == engine.InProgress {
		session.mu.RLock()
		currentTurn := session.Board.CurrentTurn
		session.mu.RUnlock()

		fmt.Printf("🎮 Move %d: %s's turn\n", moveCount+1, currentTurn)

		// Get current bot player
		var currentBot *ai.Bot
		var playerID string
		if currentTurn == engine.White {
			currentBot = session.WhitePlayer.Bot
			playerID = session.WhitePlayer.ID
		} else {
			currentBot = session.BlackPlayer.Bot
			playerID = session.BlackPlayer.ID
		}

		// Calculate bot move
		fmt.Printf("🤔 Bot calculating move...\n")
		move, err := currentBot.GetBestMove(session.Board)
		if err != nil || move == nil {
			fmt.Printf("❌ No valid moves available, ending game. Error: %v\n", err)
			// No valid moves, game should end
			break
		}

		fmt.Printf("✅ Bot chose move: %+v\n", move)

		// Make the move
		resp, err := s.MakeMove(sessionID, playerID, *move)
		if err != nil || !resp.Success {
			fmt.Printf("❌ Move failed: %v\n", err)
			// Move failed, stop game
			break
		}

		fmt.Printf("✅ Move executed successfully\n")
		moveCount++

		// Delay before next move
		if moveDelay > 0 {
			time.Sleep(time.Duration(moveDelay) * time.Millisecond)
		}

		// Check if game ended
		session.mu.RLock()
		gameEnded := session.State != engine.InProgress
		session.mu.RUnlock()

		if gameEnded {
			fmt.Printf("🏁 Game ended after %d moves\n", moveCount)
			break
		}
	}

	fmt.Printf("🎮 PlayBotVsBot: Game loop completed with %d moves\n", moveCount)

	return nil
}
