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
func (s *Service) CreateGame(mode engine.GameMod, whitePlayer, blackPlayer *Player) (*Session, error) {
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

	s.mu.Lock()
	s.sessions[sessionID] = session
	s.mu.Unlock()

	// If it's not bot vs bot and the starting player is a bot, trigger initial AI move
	if !isBotVsBot {
		currentPlayer := session.getCurrentPlayer()
		if currentPlayer != nil && currentPlayer.Type == AI {
			logf("🤖 Initial turn is bot's (%s), triggering AI move", board.CurrentTurn)
			go session.triggerAIMove()
		}
	}

	return session, nil
}

// CreateGameWithCustomBoard creates a game with a custom piece layout
func (s *Service) CreateGameWithCustomBoard(mode engine.GameMod, pieces []engine.CustomPiece, currentTurn engine.Color, whitePlayer, blackPlayer *Player) (*Session, error) {
	sessionID := uuid.New().String()
	
	board, err := engine.NewBoardWithPieces(mode, pieces, currentTurn)
	if err != nil {
		return nil, err
	}

	// Log custom board setup
	logf("📋 Custom board piece positions:")
	for row := 0; row < 8; row++ {
		for col := 0; col < 8; col++ {
			piece := board.GetPieceAt(engine.Position{Row: row, Col: col})
			if piece != nil {
				colStr := string(rune('a' + col))
				rowStr := string(rune('1' + row))
				logf("  %s at %s%s", piece.String(), colStr, rowStr)
			}
		}
	}

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

	s.mu.Lock()
	s.sessions[sessionID] = session
	s.mu.Unlock()

	logf("🎲 Custom board game created: %s (mode: %s, turn: %s)", sessionID, mode, currentTurn)
	
	// If it's not bot vs bot and the starting player is a bot, trigger initial AI move
	if !isBotVsBot {
		currentPlayer := session.getCurrentPlayer()
		if currentPlayer != nil && currentPlayer.Type == AI {
			logf("🤖 Initial turn is bot's (%s), triggering AI move", currentTurn)
			go session.triggerAIMove()
		}
	}
	
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
	log.Printf("🔒 processMove: Acquiring write lock...")
	sess.mu.Lock()
	log.Printf("✅ processMove: Write lock acquired")
	defer func() {
		sess.mu.Unlock()
		log.Printf("🔓 processMove: Write lock released")
	}()

	// Validate move is legal
	mg := engine.NewMoveGenerator(sess.Board)
	validMoves := mg.GetValidMoves(req.Move.From)
	
	// Log what piece is at the source position (for debugging)
	piece := sess.Board.GetPieceAt(req.Move.From)
	if piece == nil {
		logf("⚠️ processMove: NO PIECE at %s%s (requested by move)", 
			string('a'+req.Move.From.Col), string('1'+req.Move.From.Row))
	} else {
		// Check if king and if in check
		inCheckInfo := ""
		if piece.Type == engine.King {
			if sess.Board.IsKingInCheck(piece.Color) {
				inCheckInfo = " (IN CHECK!)"
			}
		}
		logf("🔍 processMove: Piece at %s%s is %s %s%s, %d valid moves", 
			string('a'+req.Move.From.Col), string('1'+req.Move.From.Row),
			piece.Color, piece.Type, inCheckInfo, len(validMoves))
	}
	
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
		logf("❌ Invalid move: %s%s -> %s%s (from %d valid moves for piece at %s%s)", 
			string('a'+req.Move.From.Col), string('1'+req.Move.From.Row),
			string('a'+req.Move.To.Col), string('1'+req.Move.To.Row),
			len(validMoves),
			string('a'+req.Move.From.Col), string('1'+req.Move.From.Row))
		return MoveResponse{
			Success: false,
			Error:   errors.New("invalid move"),
		}
	}

	// Execute move
	// Track if First Blood happened before the move (for Kings' Battle logging)
	wasUnlocked := sess.Board.KingsKillUnlock

	if err := sess.Board.MakeMove(req.Move); err != nil {
		return MoveResponse{
			Success: false,
			Error:   err,
		}
	}

	// Log the move
	log.Printf("📝 %s", req.Move.FormatMove())

	// Log Kings' Battle First Blood event (only once when it happens)
	if sess.Board.Mod == engine.KingsBattle && !wasUnlocked && sess.Board.KingsKillUnlock {
		log.Printf("⚔️ FIRST BLOOD! %s King captured a Pawn - all pieces unlocked, bonus move granted", req.Move.Piece.Color)
	}

	sess.UpdatedAt = time.Now()
	sess.LastMoveAt = time.Now()

	// Stream move to database for real-time recording
	// This happens immediately after move is executed (one-way stream)
	sess.MoveNumber++
	storage.RecordMoveStream(sess.ID, sess.MoveNumber, &req.Move, req.Move.Piece.Color)
	
	// Also update GameBuilder for final game record summary
	storage.RecordMove(sess.ID, &req.Move)

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
	// Check for Game Mod specific win conditions FIRST
	if sess.checkGameModVictory() {
		return
	}

	// Heir mod: Check if a player has no king AND no pawns - they lose immediately
	if sess.Board.Mod == engine.Heir {
		for _, color := range []engine.Color{engine.White, engine.Black} {
			hasKing := sess.Board.HasKing(color)
			hasPawns := sess.Board.HasPawns(color)
			if !hasKing && !hasPawns {
				// This player has lost - no king and no pawns to promote
				sess.State = engine.Checkmate
				sess.Result = &engine.GameResult{
					State:  engine.Checkmate,
					Winner: color.Opposite(),
					Reason: "No king and no pawns remaining",
				}
				return
			}
		}
	}

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
	// Save the Queen mod: 50 total half-moves (25 white + 25 black)
	// Succession mod: 50 total half-moves (25 white + 25 black)
	// Special endgames (Mercenary K+pieces vs K): 50 total moves (half-moves)
	// Normal games: 50 full moves = 100 half-moves
	fiftyMoveLimit := 100
	
	if sess.Board.Mod == engine.SaveTheQueen || sess.Board.Mod == engine.Succession {
		fiftyMoveLimit = 50 // 50 half-moves (25 white + 25 black)
	} else {
		isSpecialEndgame := sess.isSpecialEndgameRequiringFasterMate()
		if isSpecialEndgame {
			fiftyMoveLimit = 50 // Must mate within 50 total moves (white 25 + black 25)
			log.Printf("🔍 Special endgame detected - fifty-move limit set to %d (current: %d)", fiftyMoveLimit, sess.Board.FiftyMoveRule)
		}
	}

	if sess.Board.FiftyMoveRule >= fiftyMoveLimit {
		reasonMsg := ""
		if sess.Board.Mod == engine.SaveTheQueen {
			reasonMsg = "Draw - 50 moves without capture (Save the Queen rule)"
			log.Printf("🏳️ Draw: Save the Queen fifty-move rule triggered (%d half-moves)", sess.Board.FiftyMoveRule)
		} else if sess.Board.Mod == engine.Succession {
			reasonMsg = "Draw - 50 moves without capture (Succession rule)"
			log.Printf("🏳️ Draw: Succession fifty-move rule triggered (%d half-moves)", sess.Board.FiftyMoveRule)
		} else if fiftyMoveLimit == 50 {
			reasonMsg = "Draw - failed to mate within 50 moves"
			log.Printf("🏳️ Draw: Special endgame fifty-move rule triggered (%d moves)", sess.Board.FiftyMoveRule)
		} else {
			reasonMsg = "Draw - 50 moves without capture or pawn move"
			log.Printf("🏳️ Draw: Fifty-move rule triggered (%d half-moves)", sess.Board.FiftyMoveRule)
		}
		
		sess.State = engine.Draw
		sess.Result = &engine.GameResult{
			State:  engine.Draw,
			Reason: reasonMsg,
		}
		return
	}

	// Save the Queen: Check for repeated queen capture draw (3 times)
	if sess.Board.Mod == engine.SaveTheQueen {
		for captureKey, count := range sess.Board.QueenCaptureCounter {
			if count >= 3 {
				log.Printf("🏳️ Draw: Save the Queen - same queen captured 3 times (%s)", captureKey)
				sess.State = engine.Draw
				sess.Result = &engine.GameResult{
					State:  engine.Draw,
					Reason: "Draw - queen captured 3 times by same piece",
				}
				return
			}
		}
	}

	// Check for insufficient material draw
	if sess.isDrawByInsufficientMaterial() {
		sess.State = engine.Draw
		sess.Result = &engine.GameResult{
			State:  engine.Draw,
			Reason: "Insufficient material",
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

	// Truce mod: Check if truce should end
	if sess.Board.Mod == engine.Truce && sess.Board.TruceActive {
		if !sess.Board.HasMovableUnmovedPieces(sess.Board.CurrentTurn) {
			log.Printf("🔓 TRUCE ENDING: %s has exhausted all legal truce moves", sess.Board.CurrentTurn)
			sess.Board.TruceActive = false
		}
	}

	if !hasValidMoves {
		// No legal moves - check if it's checkmate or stalemate
		// In Heir mod, king doesn't trigger "check", so no valid moves = stalemate
		if sess.Board.Mod == engine.Heir {
			// In Heir mod, no valid moves is always stalemate (king is a regular piece)
			sess.State = engine.Stalemate
			sess.Result = &engine.GameResult{
				State:  engine.Stalemate,
				Reason: "Stalemate - no legal moves",
			}
			return
		}

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

// checkGameModVictory checks for Game Mod specific win conditions
// Returns true if a victory condition was met
func (sess *Session) checkGameModVictory() bool {
	lastMove := sess.Board.History.Last()
	if lastMove == nil {
		return false
	}

	switch sess.Board.Mod {
	case engine.SaveTheQueen:
		return sess.checkSaveTheQueenVictory(lastMove)
	case engine.Succession:
		return sess.checkSuccessionVictory(lastMove)
	// Add other game mods here as needed
	default:
		return false
	}
}

// checkSaveTheQueenVictory checks Save the Queen mod win conditions:
// 1. Queen reaches opponent's initial prison square (d1 for black, d8 for white)
// 2. An escaped queen is captured
func (sess *Session) checkSaveTheQueenVictory(lastMove *engine.Move) bool {
	// Check if a queen was captured
	if lastMove.CapturedPiece != nil && lastMove.CapturedPiece.Type == engine.Queen {
		capturedColor := lastMove.CapturedPiece.Color
		capturedPos := lastMove.To

		// Check if the captured queen was in its own half (i.e., it had escaped)
		wasInOwnHalf := false
		if capturedColor == engine.White {
			wasInOwnHalf = capturedPos.Row <= 3 // White's own half is rows 0-3
		} else {
			wasInOwnHalf = capturedPos.Row >= 4 // Black's own half is rows 4-7
		}

		if wasInOwnHalf {
			// Escaped queen was captured - capturer wins!
			winner := lastMove.Piece.Color
			sess.State = engine.Checkmate
			sess.Result = &engine.GameResult{
				State:  engine.Checkmate,
				Winner: winner,
				Reason: "Escaped queen captured - Save the Queen victory!",
			}
			logf("🏆 Save the Queen: %s wins by capturing escaped queen!", winner)
			return true
		}
	}

	// Check if a queen reached opponent's prison square
	if lastMove.Piece.Type == engine.Queen {
		movingColor := lastMove.Piece.Color
		targetPos := lastMove.To

		// Determine opponent's prison square
		opponentPrison := engine.Position{Row: 0, Col: 3} // d1 (black's prison)
		if movingColor == engine.Black {
			opponentPrison = engine.Position{Row: 7, Col: 3} // d8 (white's prison)
		}

		// Check if queen reached opponent's prison square AND is in own half
		isInOwnHalf := false
		if movingColor == engine.White {
			isInOwnHalf = targetPos.Row <= 3 // White's own half is rows 0-3
		} else {
			isInOwnHalf = targetPos.Row >= 4 // Black's own half is rows 4-7
		}

		if targetPos == opponentPrison && isInOwnHalf {
			// Queen reached opponent's prison while in own half - instant win!
			winner := movingColor
			sess.State = engine.Checkmate
			sess.Result = &engine.GameResult{
				State:  engine.Checkmate,
				Winner: winner,
				Reason: "Queen reached opponent's prison - Save the Queen victory!",
			}
			logf("🏆 Save the Queen: %s wins by reaching opponent's prison!", winner)
			return true
		}
	}

	return false
}

// checkSuccessionVictory checks Succession mod win conditions:
// 1. Player loses all pawns - instant loss (can't promote to King)
func (sess *Session) checkSuccessionVictory(lastMove *engine.Move) bool {
	// Check if a pawn was captured - check if opponent has any pawns left
	if lastMove.CapturedPiece != nil && lastMove.CapturedPiece.Type == engine.Pawn {
		opponent := lastMove.CapturedPiece.Color
		// Check if opponent has any pawns left
		if !sess.Board.HasPawns(opponent) {
			winner := lastMove.Piece.Color
			sess.State = engine.Checkmate
			sess.Result = &engine.GameResult{
				State:  engine.Checkmate,
				Winner: winner,
				Reason: "Opponent lost all pawns - Succession victory!",
			}
			logf("🏆 Succession: %s wins - opponent has no pawns left!", winner)
			return true
		}
	}

	return false
}

// isDrawByInsufficientMaterial checks if the game is a draw due to insufficient material
func (sess *Session) isDrawByInsufficientMaterial() bool {
	whitePieces := sess.Board.GetPiecesOfColor(engine.White)
	blackPieces := sess.Board.GetPiecesOfColor(engine.Black)

	// Mercenary mod: special insufficient material rules (check first)
	if sess.Board.Mod == engine.Mercenary {
		return sess.isDrawByInsufficientMaterialMercenary(whitePieces, blackPieces)
	}

	// Apply classic chess insufficient material rules (applies to all other mods)
	if sess.isDrawByInsufficientMaterialClassic(whitePieces, blackPieces) {
		return true
	}

	return false
}

// isDrawByInsufficientMaterialClassic checks classic chess insufficient material rules
func (sess *Session) isDrawByInsufficientMaterialClassic(whitePieces, blackPieces []*engine.Piece) bool {
	// King vs King
	if len(whitePieces) == 1 && len(blackPieces) == 1 {
		return true
	}

	// King and Bishop vs King or King and Knight vs King
	if (len(whitePieces) == 2 && len(blackPieces) == 1) ||
		(len(whitePieces) == 1 && len(blackPieces) == 2) {
		allPieces := append(whitePieces, blackPieces...)
		nonKingPieces := []*engine.Piece{}
		for _, p := range allPieces {
			if p.Type != engine.King {
				nonKingPieces = append(nonKingPieces, p)
			}
		}

		if len(nonKingPieces) == 1 {
			piece := nonKingPieces[0]
			if piece.Type == engine.Bishop || piece.Type == engine.Knight {
				return true
			}
		}
	}

	// King and Bishop vs King and Bishop (same color squares)
	if len(whitePieces) == 2 && len(blackPieces) == 2 {
		whiteBishops := []*engine.Piece{}
		blackBishops := []*engine.Piece{}
		for _, p := range whitePieces {
			if p.Type == engine.Bishop {
				whiteBishops = append(whiteBishops, p)
			}
		}
		for _, p := range blackPieces {
			if p.Type == engine.Bishop {
				blackBishops = append(blackBishops, p)
			}
		}

		if len(whiteBishops) == 1 && len(blackBishops) == 1 {
			// Check if bishops are on same color squares
			whiteSquareColor := (whiteBishops[0].Position.Row + whiteBishops[0].Position.Col) % 2
			blackSquareColor := (blackBishops[0].Position.Row + blackBishops[0].Position.Col) % 2

			if whiteSquareColor == blackSquareColor {
				return true
			}
		}
	}

	return false
}

// isSpecialEndgameRequiringFasterMate checks if current position requires mate within 50 total moves
// Mercenary: K+pieces vs K (must mate within 50 half-moves = 25 white + 25 black)
func (sess *Session) isSpecialEndgameRequiringFasterMate() bool {
	whitePieces := sess.Board.GetPiecesOfColor(engine.White)
	blackPieces := sess.Board.GetPiecesOfColor(engine.Black)

	// Mercenary mod: K+pieces vs K or K vs K+pieces
	if sess.Board.Mod == engine.Mercenary {
		// Check if one side has only king
		whiteOnlyKing := len(whitePieces) == 1
		blackOnlyKing := len(blackPieces) == 1

		if whiteOnlyKing || blackOnlyKing {
			return true
		}
	}

	return false
}

// isDrawByInsufficientMaterialMercenary checks Mercenary mod insufficient material rules
// Pawns can't promote but move like kings, so they can assist in checkmates
func (sess *Session) isDrawByInsufficientMaterialMercenary(whitePieces, blackPieces []*engine.Piece) bool {
	whitePawns := 0
	blackPawns := 0

	for _, p := range whitePieces {
		if p.Type == engine.Pawn {
			whitePawns++
		}
	}

	for _, p := range blackPieces {
		if p.Type == engine.Pawn {
			blackPawns++
		}
	}

	totalPieces := len(whitePieces) + len(blackPieces)

	// King vs King - draw
	if totalPieces == 2 {
		return true
	}

	// If there are pawns, they can assist in checkmate (don't draw yet)
	if whitePawns > 0 || blackPawns > 0 {
		return false
	}

	// No pawns left - check Mercenary specific insufficient material
	// K+N vs K+N is insufficient in Mercenary (can't checkmate without pawns to promote)
	if totalPieces == 4 {
		whiteKnights := 0
		blackKnights := 0
		for _, p := range whitePieces {
			if p.Type == engine.Knight {
				whiteKnights++
			}
		}
		for _, p := range blackPieces {
			if p.Type == engine.Knight {
				blackKnights++
			}
		}
		if whiteKnights == 1 && blackKnights == 1 {
			return true // K+N vs K+N is insufficient
		}
	}

	// Apply classic insufficient material for remaining pieces
	return sess.isDrawByInsufficientMaterialClassic(whitePieces, blackPieces)
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
	logf("🎮 game mod: %s", session.Board.Mod.String())
	logf("🤖 White Bot: Difficulty %d", session.WhitePlayer.Bot.Difficulty)
	logf("🤖 Black Bot: Difficulty %d", session.BlackPlayer.Bot.Difficulty)

	// Start game recording
	storage.StartGame(sessionID, session.Board.Mod, 
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
		if currentTurn == engine.White {
			currentBot = session.WhitePlayer.Bot
		} else {
			currentBot = session.BlackPlayer.Bot
		}

		// Calculate bot move and execute atomically with write lock to prevent race conditions
		logf("🤔 Bot calculating move...")
		session.mu.Lock()
		
		// Calculate move on current board state (holding write lock for entire operation)
		move, err := currentBot.GetBestMove(session.Board)
		
		// Check for stop signal
		stopped := session.IsStopped
		if stopped {
			session.mu.Unlock()
			logf("🛑 PlayBotVsBot: Game stopped during bot calculation")
			storage.EndGame(sessionID, "", "stopped")
			return nil
		}
		
		if err != nil {
			session.mu.Unlock()
			logf("❌ Bot returned error: %v", err)
			break
		}
		
		if move == nil {
			logf("❌ Bot returned nil move (no valid moves available)")
			logf("📊 Game state: %s, Turn: %s", session.State, session.Board.CurrentTurn)
			
			// Game should end - check for checkmate or stalemate
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
					// Check game state first - stalemate/draw should have no winner
					if gameResult.State == engine.Stalemate || gameResult.State == engine.Draw {
						winner = "" // No winner for stalemate/draw
					} else {
						switch gameResult.Winner {
						case engine.White:
							winner = "white"
						case engine.Black:
							winner = "black"
						default:
							winner = "draw"
						}
					}
					winReason = gameResult.Reason
				}
				storage.EndGame(sessionID, winner, winReason)
			}
			break
		}

		logf("✅ %s", move.FormatMove())

		// Execute move directly on the board (we already hold the lock)
		if err := session.Board.MakeMove(*move); err != nil {
			session.mu.Unlock()
			logf("❌ Move execution failed: %v", err)
			break
		}
		
		// Update session state
		session.UpdatedAt = time.Now()
		session.LastMoveAt = time.Now()
		session.updateGameState()
		
		// Broadcast move update to WebSocket clients before releasing lock
		session.broadcastUpdate(GameUpdate{
			GameID:    sessionID,
			Board:     session.Board,
			LastMove:  move,
			State:     session.State,
			Result:    session.Result,
			Timestamp: time.Now(),
		})
		
		// Release lock after move is fully executed
		session.mu.Unlock()
		
		logf("✅ Move executed successfully")
		moveCount++

		// Note: Move is already streamed to DB via RecordMoveStream in processMove()
		// Also update GameBuilder for final game record summary
		storage.RecordMove(sessionID, move)

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
				// Check game state first - stalemate/draw should have no winner
				if gameResult.State == engine.Stalemate || gameResult.State == engine.Draw {
					winner = "" // No winner for stalemate/draw
				} else {
					switch gameResult.Winner {
					case engine.White:
						winner = "white"
					case engine.Black:
						winner = "black"
					default:
						winner = "draw"
					}
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

