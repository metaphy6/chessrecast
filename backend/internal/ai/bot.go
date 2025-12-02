package ai

import (
	"fmt"
	"math"
	"math/rand"
	"sort"
	"time"

	"github.com/metaphy6/chessrecast/internal/engine"
)

// Bot represents an AI chess player
type Bot struct {
	Difficulty    int // 1-10
	Color         engine.Color
	MaxDepth      int           // Search depth based on difficulty
	TimeLimit     time.Duration // Max thinking time
	OpeningBook   map[string]string // Opening moves database
	searchTimeout time.Time     // When to stop searching
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
	// Reduced depths for better performance
	// Difficulty 1-3: 1-2 ply (half-moves)
	// Difficulty 4-6: 2-3 ply
	// Difficulty 7-8: 3-4 ply
	// Difficulty 9-10: 4-5 ply
	depthMap := map[int]int{
		1:  1,
		2:  1,
		3:  2,
		4:  2,
		5:  3,
		6:  3,
		7:  3,
		8:  4,
		9:  4,
		10: 5,
	}
	return depthMap[difficulty]
}

// difficultyToTimeLimit maps difficulty to maximum thinking time
// Keep times short for responsive gameplay
func difficultyToTimeLimit(difficulty int) time.Duration {
	if difficulty <= 3 {
		return 300 * time.Millisecond
	} else if difficulty <= 5 {
		return 500 * time.Millisecond
	} else if difficulty <= 7 {
		return 800 * time.Millisecond
	} else if difficulty <= 9 {
		return 1200 * time.Millisecond
	}
	return 2 * time.Second // Max 2 seconds even for difficulty 10
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
	startTime := time.Now()
	defer func() {
		elapsed := time.Since(startTime)
		if elapsed > 500*time.Millisecond {
			fmt.Printf("⏱️ Bot (difficulty %d) took %v to calculate move\n", b.Difficulty, elapsed)
		}
	}()
	
	fmt.Printf("🤖 Bot calculating move for mode: %s, turn: %s\n", board.Mode, board.CurrentTurn)

	// Check opening book first (only for higher difficulties)
	if b.Difficulty >= 7 && board.MoveCount < 6 {
		if bookMove := b.getOpeningBookMove(board); bookMove != nil {
			return bookMove, nil
		}
	}

	// Generate all valid moves
	allMoves := b.getAllValidMoves(board)
	if len(allMoves) == 0 {
		fmt.Printf("⚠️ No valid moves available for %s\n", board.CurrentTurn)
		return nil, nil // No valid moves
	}
	
	// Log moves in debug mode for special modes
	if board.Mode != engine.Classic && len(allMoves) > 0 {
		fmt.Printf("🎯 Mode %s: Generated %d valid moves\n", board.Mode, len(allMoves))
	}
	
	// If only one move available, return it immediately (forced move)
	if len(allMoves) == 1 {
		fmt.Printf("🎯 Only 1 valid move available, returning immediately\n")
		return &allMoves[0], nil
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
	// Set timeout for search
	b.searchTimeout = time.Now().Add(b.TimeLimit)

	// Sort moves by potential (captures first) for better pruning
	moves = b.sortMoves(moves)

	bestMoves := []engine.Move{moves[0]}
	bestScore := math.Inf(-1)

	for i := range moves {
		// Check time before evaluating each move
		if time.Now().After(b.searchTimeout) {
			break
		}

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
	// Set timeout for search
	b.searchTimeout = time.Now().Add(b.TimeLimit)

	bestMoves := []engine.Move{moves[0]}
	bestScore := math.Inf(-1)
	alpha := math.Inf(-1)
	beta := math.Inf(1)

	// Sort moves by potential (captures first)
	moves = b.sortMoves(moves)

	for i := range moves {
		// Check time limit
		if time.Now().After(b.searchTimeout) {
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
	// Check time limit
	if !b.searchTimeout.IsZero() && time.Now().After(b.searchTimeout) {
		return b.evaluateBoard(board) // Return current evaluation if out of time
	}

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
	
	// Sort moves for better alpha-beta pruning (captures first)
	moves = b.sortMoves(moves)

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
// These bonuses are significant (comparable to piece values) to ensure the bot prioritizes mode objectives
func (b *Bot) getModeSpecificScore(board *engine.Board) float64 {
	score := 0.0

	switch board.Mode {
	case engine.RoyalPawns:
		// In Royal Pawns, pawns move like kings - prioritize pawn advancement and aggression
		for row := 0; row < 8; row++ {
			for col := 0; col < 8; col++ {
				piece := board.GetPieceAt(engine.Position{Row: row, Col: col})
				if piece == nil || piece.Type != engine.Pawn {
					continue
				}

				if piece.Color == b.Color {
					// BIG bonus for pawns in the center (they can attack in all directions)
					if col >= 2 && col <= 5 && row >= 2 && row <= 5 {
						score += 80.0
					}
					// Strong bonus for advanced pawns (near enemy territory)
					if piece.Color == engine.White {
						score += float64(row) * 30.0 // Higher rows are better for white
					} else {
						score += float64(7-row) * 30.0 // Lower rows are better for black
					}
				} else {
					// Penalize opponent's advanced pawns significantly
					if piece.Color == engine.White {
						score -= float64(row) * 30.0
					} else {
						score -= float64(7-row) * 30.0
					}
				}
			}
		}

	case engine.OtherSide:
		// Goal: Get rook to opponent's back rank - this is the PRIMARY objective
		targetRow := 7
		if b.Color == engine.Black {
			targetRow = 0
		}
		for col := 0; col < 8; col++ {
			for row := 0; row < 8; row++ {
				piece := board.GetPieceAt(engine.Position{Row: row, Col: col})
				if piece != nil && piece.Type == engine.Rook && piece.Color == b.Color {
					// Huge bonus based on how close rook is to target row
					if b.Color == engine.White {
						score += float64(row) * 60.0 // Higher is better for white
					} else {
						score += float64(7-row) * 60.0 // Lower is better for black
					}
					// MASSIVE bonus if on target row (winning condition!)
					if row == targetRow {
						score += 1000.0
					}
				}
			}
		}

	case engine.Diamonds:
		// Bishops are crucial in Diamonds mode - prioritize bishop activity and capturing
		for row := 0; row < 8; row++ {
			for col := 0; col < 8; col++ {
				piece := board.GetPieceAt(engine.Position{Row: row, Col: col})
				if piece != nil && piece.Type == engine.Bishop && piece.Color == b.Color {
					// Strong bonus for central bishops (more diagonal lines)
					if row >= 2 && row <= 5 && col >= 2 && col <= 5 {
						score += 100.0
					}
					// Bonus for active (moved) bishops
					if piece.HasMoved {
						score += 50.0
					}
				}
			}
		}

	case engine.Teleport:
		// Value king-rook alignment for teleportation opportunities
		var kingPos engine.Position
		kingFound := false
		for row := 0; row < 8; row++ {
			for col := 0; col < 8; col++ {
				piece := board.GetPieceAt(engine.Position{Row: row, Col: col})
				if piece != nil && piece.Type == engine.King && piece.Color == b.Color {
					kingPos = engine.Position{Row: row, Col: col}
					kingFound = true
					break
				}
			}
			if kingFound {
				break
			}
		}

		if kingFound {
			// Bonus for rooks aligned with king (enables teleport)
			for row := 0; row < 8; row++ {
				for col := 0; col < 8; col++ {
					piece := board.GetPieceAt(engine.Position{Row: row, Col: col})
					if piece != nil && piece.Type == engine.Rook && piece.Color == b.Color {
						if row == kingPos.Row || col == kingPos.Col {
							score += 80.0 // Aligned for potential teleport
						}
					}
				}
			}
		}

	case engine.KingsBattle:
		// Prioritize king attacking pawns to unlock other pieces
		if !board.KingsKillUnlock {
			// Game is still locked - prioritize king capturing enemy pawns
			var kingPos engine.Position
			for row := 0; row < 8; row++ {
				for col := 0; col < 8; col++ {
					piece := board.GetPieceAt(engine.Position{Row: row, Col: col})
					if piece != nil && piece.Type == engine.King && piece.Color == b.Color {
						kingPos = engine.Position{Row: row, Col: col}
						break
					}
				}
			}
			// Strong bonus for king being near enemy pawns
			for row := 0; row < 8; row++ {
				for col := 0; col < 8; col++ {
					piece := board.GetPieceAt(engine.Position{Row: row, Col: col})
					if piece != nil && piece.Type == engine.Pawn && piece.Color != b.Color {
						distance := abs(kingPos.Row-row) + abs(kingPos.Col-col)
						score += float64(14-distance) * 20.0 // Much closer is much better
					}
				}
			}
		}

	case engine.SaveTheQueen:
		// Bonus if queen has escaped - this is the win condition!
		if board.EscapedQueens[b.Color] {
			score += 2000.0
		} else {
			// Prioritize moving queen toward board edges (escape routes)
			var queenPos engine.Position
			queenFound := false
			for row := 0; row < 8; row++ {
				for col := 0; col < 8; col++ {
					piece := board.GetPieceAt(engine.Position{Row: row, Col: col})
					if piece != nil && piece.Type == engine.Queen && piece.Color == b.Color {
						queenPos = engine.Position{Row: row, Col: col}
						queenFound = true
						break
					}
				}
				if queenFound {
					break
				}
			}
			if queenFound {
				// Big bonus for queen being on edge (closer to escape)
				if queenPos.Row == 0 || queenPos.Row == 7 || queenPos.Col == 0 || queenPos.Col == 7 {
					score += 300.0
				}
			}
		}

	case engine.SaveTheKing:
		// Bonus for having promoted kings - win condition!
		score += float64(board.PromotedKings[b.Color]) * 1500.0
		// Strong bonus for pawns near promotion
		for col := 0; col < 8; col++ {
			for row := 0; row < 8; row++ {
				piece := board.GetPieceAt(engine.Position{Row: row, Col: col})
				if piece != nil && piece.Type == engine.Pawn && piece.Color == b.Color {
					if b.Color == engine.White && row >= 5 {
						score += float64(row) * 50.0
					} else if b.Color == engine.Black && row <= 2 {
						score += float64(7-row) * 50.0
					}
				}
			}
		}

	case engine.Heir:
		// Count how many kings we have vs opponent - more kings = better!
		myKings := 0
		oppKings := 0
		for row := 0; row < 8; row++ {
			for col := 0; col < 8; col++ {
				piece := board.GetPieceAt(engine.Position{Row: row, Col: col})
				if piece != nil && piece.Type == engine.King {
					if piece.Color == b.Color {
						myKings++
					} else {
						oppKings++
					}
				}
			}
		}
		score += float64(myKings-oppKings) * 500.0
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
	// Sort by MVV-LVA: Most Valuable Victim - Least Valuable Attacker
	// This greatly improves alpha-beta pruning efficiency by trying good moves first
	sort.Slice(moves, func(i, j int) bool {
		scoreI := b.getMoveOrderScore(&moves[i])
		scoreJ := b.getMoveOrderScore(&moves[j])
		return scoreI > scoreJ
	})
	return moves
}

// getMoveOrderScore returns a score for move ordering (higher = try first)
func (b *Bot) getMoveOrderScore(move *engine.Move) int {
	score := 0
	
	// Captures are very important - prioritize by MVV-LVA
	if move.CapturedPiece != nil {
		victimValue := getPieceValue(move.CapturedPiece.Type)
		attackerValue := getPieceValue(move.Piece.Type)
		// MVV-LVA: capturing queen with pawn is best (900 - 100 = 800)
		score += 10000 + victimValue - attackerValue/10
	}
	
	// Promotions are very valuable
	if move.IsPromotion {
		score += 9000
	}
	
	// Checks are often good
	// (We'd need board to check this, skip for now)
	
	// Center control bonus
	if move.To.Row >= 3 && move.To.Row <= 4 && move.To.Col >= 3 && move.To.Col <= 4 {
		score += 50
	}
	
	return score
}

func (b *Bot) isPieceSafe(board *engine.Board, pos engine.Position) bool {
	// Check if piece at position is attacked by opponent
	piece := board.GetPieceAt(pos)
	if piece == nil {
		return true
	}
	
	oppColor := piece.Color.Opposite()
	
	// Check if any opponent piece can capture at this position
	for row := 0; row < 8; row++ {
		for col := 0; col < 8; col++ {
			oppPiece := board.GetPieceAt(engine.Position{Row: row, Col: col})
			if oppPiece != nil && oppPiece.Color == oppColor {
				// Check if this opponent piece can attack the position
				if b.canPieceAttack(board, oppPiece, pos) {
					return false
				}
			}
		}
	}
	return true
}

// canPieceAttack checks if a piece can attack a target position (simplified)
func (b *Bot) canPieceAttack(board *engine.Board, piece *engine.Piece, target engine.Position) bool {
	dr := target.Row - piece.Position.Row
	dc := target.Col - piece.Position.Col
	
	switch piece.Type {
	case engine.Pawn:
		// In Royal Pawns mode, pawns attack like kings (all 8 directions)
		if board.Mode == engine.RoyalPawns {
			if abs(dr) <= 1 && abs(dc) <= 1 && (dr != 0 || dc != 0) {
				return true
			}
			return false
		}
		// Standard pawns attack diagonally
		direction := 1
		if piece.Color == engine.Black {
			direction = -1
		}
		if dr == direction && (dc == 1 || dc == -1) {
			return true
		}
	case engine.Knight:
		if (abs(dr) == 2 && abs(dc) == 1) || (abs(dr) == 1 && abs(dc) == 2) {
			return true
		}
	case engine.Bishop:
		if abs(dr) == abs(dc) && dr != 0 {
			return b.isPathClear(board, piece.Position, target)
		}
	case engine.Rook:
		if (dr == 0 || dc == 0) && (dr != 0 || dc != 0) {
			return b.isPathClear(board, piece.Position, target)
		}
	case engine.Queen:
		if abs(dr) == abs(dc) || dr == 0 || dc == 0 {
			if dr != 0 || dc != 0 {
				return b.isPathClear(board, piece.Position, target)
			}
		}
	case engine.King:
		if abs(dr) <= 1 && abs(dc) <= 1 && (dr != 0 || dc != 0) {
			return true
		}
	}
	return false
}

// isPathClear checks if there are no pieces between from and to
func (b *Bot) isPathClear(board *engine.Board, from, to engine.Position) bool {
	dr := 0
	dc := 0
	if to.Row > from.Row {
		dr = 1
	} else if to.Row < from.Row {
		dr = -1
	}
	if to.Col > from.Col {
		dc = 1
	} else if to.Col < from.Col {
		dc = -1
	}
	
	row := from.Row + dr
	col := from.Col + dc
	for row != to.Row || col != to.Col {
		if board.GetPieceAt(engine.Position{Row: row, Col: col}) != nil {
			return false
		}
		row += dr
		col += dc
	}
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

// abs returns absolute value of an integer
func abs(x int) int {
	if x < 0 {
		return -x
	}
	return x
}
