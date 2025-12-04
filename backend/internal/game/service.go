package game

import (
	"errors"
	"fmt"
	"log"
	"sync"
	"time"

	"github.com/google/uuid"
	"github.com/metaphy6/chessrecast/internal/ai"
	"github.com/metaphy6/chessrecast/internal/engine"
	"github.com/metaphy6/chessrecast/internal/storage"
)

// logf prints a log message with timestamp (MM-DD HH:MM:SS.mmm)
func logf(format string, args ...interface{}) {
	ts := time.Now().Format("01-02 15:04:05.000")
	msg := fmt.Sprintf(format, args...)
	fmt.Printf("[%s] %s\n", ts, msg)
}

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
	MoveNumber    int       // For move recording stream
	
	// Bot vs Bot control
	IsPaused      bool
	IsStopped     bool // Flag to indicate game should stop
	MoveDelay     int // milliseconds
	IsBotVsBot    bool // true if this is a bot vs bot game (controlled by PlayBotVsBot)
	stopChannel   chan struct{}
	
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

	// Check if this is a bot vs bot game
	isBotVsBot := whitePlayer.Type == AI && blackPlayer.Type == AI

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
		IsBotVsBot:  isBotVsBot,
		moveChannel: make(chan MoveRequest, 100),
		subscribers: make(map[string]chan GameUpdate),
	}

	// Start game loop
	go session.run()

	// If AI player vs Human, trigger AI moves automatically
	// But NOT for bot vs bot - that's controlled by PlayBotVsBot with delay
	if !isBotVsBot && whitePlayer.Type == AI && board.CurrentTurn == engine.White {
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
	if ch, exists := session.subscribers[subscriberID]; exists {
		close(ch)
		delete(session.subscribers, subscriberID)
	}
	
	// Check if this was the last subscriber for a bot vs bot game
	noSubscribers := len(session.subscribers) == 0
	isBotVsBot := session.IsBotVsBot
	session.mu.Unlock()
	
	// If no more subscribers and it's a bot vs bot game, stop it
	if noSubscribers && isBotVsBot {
		log.Printf("🛑 No more subscribers for bot vs bot game %s, stopping game", sessionID)
		s.StopGame(sessionID)
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
			// But NOT for bot vs bot - that's controlled by PlayBotVsBot with delay
			if resp.Success && sess.State == engine.InProgress && !sess.IsBotVsBot {
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

	// Stream move to database for real-time recording
	// This happens immediately after move is executed (one-way stream)
	sess.MoveNumber++
	storage.RecordMoveStream(sess.ID, sess.MoveNumber, &req.Move, req.Move.Piece.Color)

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

// updateGameState checks for checkmate, stalemate, draw conditions, etc.
func (sess *Session) updateGameState() {
	// Check for threefold repetition draw first
	if sess.Board.HasThreefoldRepetition() {
		sess.State = engine.Draw
		sess.Result = &engine.GameResult{
			State:  engine.Draw,
			Reason: "Threefold repetition",
		}
		return
	}

	// Check for fifty-move rule draw
	if sess.Board.FiftyMoveRule >= 100 {
		sess.State = engine.Draw
		sess.Result = &engine.GameResult{
			State:  engine.Draw,
			Reason: "Fifty-move rule",
		}
		return
	}

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
		// No legal moves - check if it's checkmate or stalemate
		isInCheck := sess.Board.IsKingInCheck(sess.Board.CurrentTurn)
		
		if isInCheck {
			// Checkmate - current player loses
			sess.State = engine.Checkmate
			sess.Result = &engine.GameResult{
				State:  engine.Checkmate,
				Winner: sess.Board.CurrentTurn.Opposite(), // Opponent wins
				Reason: "Checkmate",
			}
		} else {
			// Stalemate - draw
			sess.State = engine.Stalemate
			sess.Result = &engine.GameResult{
				State:  engine.Stalemate,
				Reason: "Stalemate",
			}
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

	// Initialize control channels (only if not already set by ResumeGame)
	session.mu.Lock()
	if moveDelay > 0 {
		session.MoveDelay = moveDelay
	}
	session.IsPaused = false
	session.IsStopped = false
	if session.stopChannel == nil {
		session.stopChannel = make(chan struct{})
	}
	session.mu.Unlock()

	logf("✅ PlayBotVsBot: Validation passed, starting game loop")
	logf("🎮 Game Mode: %s", session.Board.Mode.String())
	logf("🤖 White Bot: Difficulty %d", session.WhitePlayer.Bot.Difficulty)
	logf("🤖 Black Bot: Difficulty %d", session.BlackPlayer.Bot.Difficulty)

	// Start game recording
	storage.StartGame(sessionID, session.Board.Mode, 
		session.WhitePlayer.Bot.Difficulty, session.BlackPlayer.Bot.Difficulty)

	// Keep playing until game ends
	moveCount := 0
	_ = time.Now() // gameStartTime not needed anymore
	for session.State == engine.InProgress {
		// Check for stop signal
		select {
		case <-session.stopChannel:
			logf("🛑 PlayBotVsBot: Game stopped by user")
			storage.EndGame(sessionID, "", "stopped")
			return nil
		default:
		}

		// Check if paused
		session.mu.RLock()
		isPaused := session.IsPaused
		currentDelay := session.MoveDelay
		session.mu.RUnlock()

		if isPaused {
			// Wait a bit and check again
			time.Sleep(100 * time.Millisecond)
			continue
		}

		// Apply delay BEFORE the move (so user can see the board state)
		if moveCount > 0 && currentDelay > 0 {
			logf("⏳ Waiting %dms before next move...", currentDelay)
			time.Sleep(time.Duration(currentDelay) * time.Millisecond)
		}

		session.mu.RLock()
		currentTurn := session.Board.CurrentTurn
		session.mu.RUnlock()

		logf("🎮 Move %d: %s's turn", moveCount+1, currentTurn)

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
		logf("🤔 Bot calculating move...")
		move, err := currentBot.GetBestMove(session.Board)
		
		// Check for stop signal AFTER bot calculation (in case stop was called during calculation)
		session.mu.RLock()
		stopped := session.IsStopped
		session.mu.RUnlock()
		if stopped {
			logf("🛑 PlayBotVsBot: Game stopped during bot calculation")
			storage.EndGame(sessionID, "", "stopped")
			return nil
		}
		
		if err != nil {
			logf("❌ Bot returned error: %v", err)
			break
		}
		
		if move == nil {
			logf("❌ Bot returned nil move (no valid moves available)")
			logf("📊 Game state: %s, Turn: %s", session.State, session.Board.CurrentTurn)
			
			// Game should end - check for checkmate or stalemate
			session.mu.Lock()
			session.updateGameState()
			gameEnded := session.State != engine.InProgress
			gameResult := session.Result
			session.mu.Unlock()
			
			if gameEnded {
				logf("🏁 Game ended after %d moves", moveCount)
				
				// Record game result
				winner := ""
				winReason := ""
				if gameResult != nil {
					switch gameResult.Winner {
					case engine.White:
						winner = "white"
					case engine.Black:
						winner = "black"
					default:
						winner = "draw"
					}
					winReason = gameResult.Reason
				}
				storage.EndGame(sessionID, winner, winReason)
			}
			break
		}

		logf("✅ Bot chose move: %s%s -> %s%s", 
			string('a'+move.From.Col), string('1'+move.From.Row),
			string('a'+move.To.Col), string('1'+move.To.Row))

		// Make the move
		resp, err := s.MakeMove(sessionID, playerID, *move)
		if err != nil || !resp.Success {
			logf("❌ Move failed: %v", err)
			break
		}

		logf("✅ Move executed successfully")
		moveCount++

		// Note: Move is already streamed to DB via RecordMoveStream in processMove()
		// No need to call RecordMove here (kept for backward compatibility with old system)

		// Check if game ended
		session.mu.RLock()
		gameEnded := session.State != engine.InProgress
		gameResult := session.Result
		session.mu.RUnlock()

		if gameEnded {
			logf("🏁 Game ended after %d moves", moveCount)
			
			// Record game result
			winner := ""
			winReason := ""
			if gameResult != nil {
				switch gameResult.Winner {
				case engine.White:
					winner = "white"
				case engine.Black:
					winner = "black"
				default:
					winner = "draw"
				}
				winReason = gameResult.Reason
			}
			storage.EndGame(sessionID, winner, winReason)
			
			break
		}
	}

	logf("🎮 PlayBotVsBot: Game loop completed with %d moves", moveCount)

	return nil
}

// PauseGame pauses a bot vs bot game
func (s *Service) PauseGame(sessionID string) error {
	session, err := s.GetSession(sessionID)
	if err != nil {
		return err
	}

	session.mu.Lock()
	session.IsPaused = true
	session.mu.Unlock()

	fmt.Printf("⏸️ Game %s paused\n", sessionID)
	return nil
}

// ResumeGame resumes a paused or stopped bot vs bot game
func (s *Service) ResumeGame(sessionID string) error {
	session, err := s.GetSession(sessionID)
	if err != nil {
		return err
	}

	session.mu.Lock()
	wasStopped := session.IsStopped
	session.IsPaused = false
	session.IsStopped = false
	
	// If the game was stopped (not just paused), we need to restart the game loop
	if wasStopped && session.State == engine.InProgress {
		// Create new stop channel
		session.stopChannel = make(chan struct{})
		currentDelay := session.MoveDelay
		session.mu.Unlock()
		
		fmt.Printf("▶️ Game %s resumed (restarting game loop)\n", sessionID)
		
		// Restart the game loop in a goroutine
		go func() {
			if err := s.PlayBotVsBot(sessionID, currentDelay); err != nil {
				fmt.Printf("❌ Error restarting bot game: %v\n", err)
			}
		}()
		return nil
	}
	
	session.mu.Unlock()
	fmt.Printf("▶️ Game %s resumed\n", sessionID)
	return nil
}

// SetMoveDelay updates the move delay for a bot vs bot game
func (s *Service) SetMoveDelay(sessionID string, delayMs int) error {
	session, err := s.GetSession(sessionID)
	if err != nil {
		return err
	}

	session.mu.Lock()
	session.MoveDelay = delayMs
	session.mu.Unlock()

	fmt.Printf("⏱️ Game %s move delay set to %dms\n", sessionID, delayMs)
	return nil
}

// StopGame stops a bot vs bot game completely
func (s *Service) StopGame(sessionID string) error {
	session, err := s.GetSession(sessionID)
	if err != nil {
		return err
	}

	session.mu.Lock()
	session.IsStopped = true // Set flag first
	if session.stopChannel != nil {
		close(session.stopChannel)
		session.stopChannel = nil
	}
	session.mu.Unlock()

	fmt.Printf("🛑 Game %s stopped\n", sessionID)
	return nil
}

// GetGameStatus returns the current status of a game
func (s *Service) GetGameStatus(sessionID string) (map[string]interface{}, error) {
	session, err := s.GetSession(sessionID)
	if err != nil {
		return nil, err
	}

	session.mu.RLock()
	defer session.mu.RUnlock()

	return map[string]interface{}{
		"game_id":    session.ID,
		"state":      session.State.String(),
		"is_paused":  session.IsPaused,
		"move_delay": session.MoveDelay,
	}, nil
}
