package ai

import (
	"math"
	"math/rand"
	"time"

	"github.com/metaphy6/chessrecast/internal/engine"
)

// Bot represents an AI chess player
type Bot struct {
	Difficulty  int // 1-10
	Color       engine.Color
	MaxDepth    int           // Search depth based on difficulty
	TimeLimit   time.Duration // Max thinking time
	OpeningBook map[string]string // Opening moves database
}

// NewBot creates a new AI bot
func NewBot(difficulty int, color engine.Color) *Bot {
	if difficulty < 1 {
		difficulty = 1
	}
	if difficulty > 10 {
		difficulty = 10
	}

	maxDepth := difficultyToDepth(difficulty)
	timeLimit := difficultyToTimeLimit(difficulty)

	return &Bot{
		Difficulty:  difficulty,
		Color:       color,
		MaxDepth:    maxDepth,
		TimeLimit:   timeLimit,
		OpeningBook: loadOpeningBook(),
	}
}

// difficultyToDepth maps difficulty level to search depth
func difficultyToDepth(difficulty int) int {
	// Difficulty 1-3: 1-2 ply (half-moves)
	// Difficulty 4-6: 3-4 ply
	// Difficulty 7-8: 5-6 ply
	// Difficulty 9-10: 7-8 ply
	depthMap := map[int]int{
		1:  1,
		2:  1,
		3:  2,
		4:  3,
		5:  3,
		6:  4,
		7:  5,
		8:  6,
		9:  7,
		10: 8,
	}
	return depthMap[difficulty]
}

// difficultyToTimeLimit maps difficulty to maximum thinking time
func difficultyToTimeLimit(difficulty int) time.Duration {
	if difficulty <= 3 {
		return 1 * time.Second
	} else if difficulty <= 6 {
		return 3 * time.Second
	} else if difficulty <= 8 {
		return 10 * time.Second
	}
	return 30 * time.Second
}

// loadOpeningBook loads common opening moves
func loadOpeningBook() map[string]string {
	// TODO: Load from file or database
	// Simple opening book for now
	return map[string]string{
		"start": "e2e4", // King's pawn opening
	}
}

// GetBestMove returns the best move for the current board state
func (b *Bot) GetBestMove(board *engine.Board) (*engine.Move, error) {
	// Check opening book first (only for higher difficulties)
	if b.Difficulty >= 7 && board.MoveCount < 6 {
		if bookMove := b.getOpeningBookMove(board); bookMove != nil {
			return bookMove, nil
		}
	}

	// Generate all valid moves
	allMoves := b.getAllValidMoves(board)
	if len(allMoves) == 0 {
		return nil, nil // No valid moves
	}

	// Apply difficulty-based strategy
	switch {
	case b.Difficulty <= 3:
		return b.selectBeginnerMove(allMoves, board)
	case b.Difficulty <= 6:
		return b.selectIntermediateMove(allMoves, board)
	default:
		return b.selectAdvancedMove(allMoves, board)
	}
}

// selectBeginnerMove - Random move with basic heuristics
func (b *Bot) selectBeginnerMove(moves []engine.Move, board *engine.Board) (*engine.Move, error) {
	// Note: Go 1.20+ has auto-seeded global random, no need for manual seeding
	// Calling rand.Seed() here would actually make moves LESS random since bots
	// might get the same seed when evaluating at the same nanosecond

	// Weight moves by simple heuristics
	type weightedMove struct {
		move   engine.Move
		weight float64
	}

	weighted := []weightedMove{}
	for _, move := range moves {
		weight := 1.0

		// Prefer captures
		if move.CapturedPiece != nil {
			weight += 2.0
			// Prefer capturing valuable pieces
			weight += float64(getPieceValue(move.CapturedPiece.Type)) / 10.0
		}

		// Prefer center moves (slightly)
		if move.To.Row >= 3 && move.To.Row <= 4 && move.To.Col >= 3 && move.To.Col <= 4 {
			weight += 0.5
		}

		// Avoid hanging pieces (very basic check)
		testBoard := board.Clone()
		testBoard.MakeMove(move)
		if !b.isPieceSafe(testBoard, move.To) {
			weight *= 0.3
		}

		weighted = append(weighted, weightedMove{move: move, weight: weight})
	}

	// Select randomly with weights
	totalWeight := 0.0
	for _, wm := range weighted {
		totalWeight += wm.weight
	}

	randValue := rand.Float64() * totalWeight
	currentWeight := 0.0
	for _, wm := range weighted {
		currentWeight += wm.weight
		if randValue <= currentWeight {
			return &wm.move, nil
		}
	}

	// Fallback to first move
	return &moves[0], nil
}

// selectIntermediateMove - Minimax with limited depth
func (b *Bot) selectIntermediateMove(moves []engine.Move, board *engine.Board) (*engine.Move, error) {
	bestMoves := []engine.Move{moves[0]}
	bestScore := math.Inf(-1)

	for i := range moves {
		testBoard := board.Clone()
		testBoard.MakeMove(moves[i])

		score := b.minimax(testBoard, b.MaxDepth-1, math.Inf(-1), math.Inf(1), false)

		if score > bestScore {
			bestScore = score
			bestMoves = []engine.Move{moves[i]}
		} else if score == bestScore {
			// Collect all moves with equal score for randomization
			bestMoves = append(bestMoves, moves[i])
		}
	}

	// Randomly select among best moves to add variety
	if len(bestMoves) > 1 {
		randomIndex := rand.Intn(len(bestMoves))
		return &bestMoves[randomIndex], nil
	}

	return &bestMoves[0], nil
}

// selectAdvancedMove - Minimax with alpha-beta pruning and advanced evaluation
func (b *Bot) selectAdvancedMove(moves []engine.Move, board *engine.Board) (*engine.Move, error) {
	bestMoves := []engine.Move{moves[0]}
	bestScore := math.Inf(-1)
	alpha := math.Inf(-1)
	beta := math.Inf(1)

	// Sort moves by potential (captures first)
	moves = b.sortMoves(moves)

	startTime := time.Now()

	for i := range moves {
		// Check time limit
		if time.Since(startTime) > b.TimeLimit {
			break
		}

		testBoard := board.Clone()
		testBoard.MakeMove(moves[i])

		score := b.minimax(testBoard, b.MaxDepth-1, alpha, beta, false)

		if score > bestScore {
			bestScore = score
			bestMoves = []engine.Move{moves[i]}
		} else if score == bestScore {
			// Collect all moves with equal score
			bestMoves = append(bestMoves, moves[i])
		}

		alpha = math.Max(alpha, score)
	}

	// Randomly select among best moves to add variety
	if len(bestMoves) > 1 {
		randomIndex := rand.Intn(len(bestMoves))
		return &bestMoves[randomIndex], nil
	}

	return &bestMoves[0], nil
}

// minimax implements the minimax algorithm with alpha-beta pruning
func (b *Bot) minimax(board *engine.Board, depth int, alpha, beta float64, maximizing bool) float64 {
	if depth == 0 {
		return b.evaluateBoard(board)
	}

	moves := b.getAllValidMoves(board)
	if len(moves) == 0 {
		// Game over or stalemate
		if b.isInCheckmate(board, board.CurrentTurn) {
			if maximizing {
				return math.Inf(-1) // Lost
			}
			return math.Inf(1) // Won
		}
		return 0 // Stalemate
	}

	if maximizing {
		maxEval := math.Inf(-1)
		for _, move := range moves {
			testBoard := board.Clone()
			testBoard.MakeMove(move)
			eval := b.minimax(testBoard, depth-1, alpha, beta, false)
			maxEval = math.Max(maxEval, eval)
			alpha = math.Max(alpha, eval)
			if beta <= alpha {
				break // Beta cutoff
			}
		}
		return maxEval
	} else {
		minEval := math.Inf(1)
		for _, move := range moves {
			testBoard := board.Clone()
			testBoard.MakeMove(move)
			eval := b.minimax(testBoard, depth-1, alpha, beta, true)
			minEval = math.Min(minEval, eval)
			beta = math.Min(beta, eval)
			if beta <= alpha {
				break // Alpha cutoff
			}
		}
		return minEval
	}
}

// evaluateBoard returns a score for the current board position
func (b *Bot) evaluateBoard(board *engine.Board) float64 {
	score := 0.0

	for row := 0; row < 8; row++ {
		for col := 0; col < 8; col++ {
			piece := board.GetPieceAt(engine.Position{Row: row, Col: col})
			if piece == nil {
				continue
			}

			pieceValue := float64(getPieceValue(piece.Type))
			positionalValue := b.getPositionalValue(piece, engine.Position{Row: row, Col: col})

			totalValue := pieceValue + positionalValue

			if piece.Color == b.Color {
				score += totalValue
			} else {
				score -= totalValue
			}
		}
	}

	// Add bonuses for game mode specific objectives
	score += b.getModeSpecificScore(board)

	return score
}

// getPieceValue returns the material value of a piece
func getPieceValue(pieceType engine.PieceType) int {
	values := map[engine.PieceType]int{
		engine.Pawn:   100,
		engine.Knight: 320,
		engine.Bishop: 330,
		engine.Rook:   500,
		engine.Queen:  900,
		engine.King:   20000,
	}
	return values[pieceType]
}

// getPositionalValue returns positional bonus for piece location
func (b *Bot) getPositionalValue(piece *engine.Piece, pos engine.Position) float64 {
	// Simplified positional tables
	// TODO: Add full piece-square tables for each piece type

	value := 0.0

	// Center control bonus
	if pos.Row >= 3 && pos.Row <= 4 && pos.Col >= 3 && pos.Col <= 4 {
		value += 10.0
	}

	// Development bonus (move pieces from starting position)
	if piece.Type != engine.Pawn && piece.HasMoved {
		value += 5.0
	}

	// Pawn advancement bonus
	if piece.Type == engine.Pawn {
		if piece.Color == engine.White {
			value += float64(pos.Row) * 2.0
		} else {
			value += float64(7-pos.Row) * 2.0
		}
	}

	// King safety in early/mid game
	if piece.Type == engine.King && !b.isEndgame(b.getCurrentBoard()) {
		// Prefer king on back rank or near castle position
		if (piece.Color == engine.White && pos.Row == 0) ||
			(piece.Color == engine.Black && pos.Row == 7) {
			value += 15.0
		}
	}

	return value
}

// getModeSpecificScore adds scoring for game mode objectives
func (b *Bot) getModeSpecificScore(board *engine.Board) float64 {
	score := 0.0

	switch board.Mode {
	case engine.OtherSide:
		// Bonus for rooks near opponent's back rank
		for col := 0; col < 8; col++ {
			piece := board.GetPieceAt(engine.Position{Row: 7, Col: col})
			if piece != nil && piece.Type == engine.Rook && piece.Color == b.Color {
				score += 50.0
			}
		}

	case engine.SaveTheQueen:
		// Bonus if queen has escaped
		if board.EscapedQueens[b.Color] {
			score += 200.0
		}

	case engine.SaveTheKing:
		// Bonus for having king(s)
		score += float64(board.PromotedKings[b.Color]) * 300.0
	}

	return score
}

// Helper methods

func (b *Bot) getAllValidMoves(board *engine.Board) []engine.Move {
	allMoves := []engine.Move{}
	mg := engine.NewMoveGenerator(board)

	for row := 0; row < 8; row++ {
		for col := 0; col < 8; col++ {
			pos := engine.Position{Row: row, Col: col}
			piece := board.GetPieceAt(pos)
			if piece != nil && piece.Color == board.CurrentTurn {
				moves := mg.GetValidMoves(pos)
				allMoves = append(allMoves, moves...)
			}
		}
	}

	return allMoves
}

func (b *Bot) sortMoves(moves []engine.Move) []engine.Move {
	// Sort by capture value (MVV-LVA: Most Valuable Victim - Least Valuable Attacker)
	// This improves alpha-beta pruning efficiency
	// TODO: Implement proper sorting
	return moves
}

func (b *Bot) isPieceSafe(board *engine.Board, pos engine.Position) bool {
	// Check if piece at position is defended or not under attack
	// Simplified implementation
	return true
}

func (b *Bot) isInCheckmate(board *engine.Board, color engine.Color) bool {
	// Check if king is in check and no legal moves
	// Simplified - assumes move generator filters illegal moves
	moves := b.getAllValidMoves(board)
	return len(moves) == 0
}

func (bot *Bot) isEndgame(board *engine.Board) bool {
	// Safety check
	if board == nil {
		return false
	}

	// Simple endgame detection: few pieces left
	pieceCount := 0
	for row := 0; row < 8; row++ {
		for col := 0; col < 8; col++ {
			piece := board.GetPieceAt(engine.Position{Row: row, Col: col})
			if piece != nil {
				pieceCount++
			}
		}
	}
	return pieceCount <= 12
}

func (b *Bot) getCurrentBoard() *engine.Board {
	// This should be passed from context
	// Placeholder for now
	return nil
}

func (b *Bot) getOpeningBookMove(board *engine.Board) *engine.Move {
	// TODO: Implement opening book lookup based on move history
	return nil
}
