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
	// Weight moves by strategic heuristics
	type weightedMove struct {
		move   engine.Move
		weight float64
	}

	weighted := []weightedMove{}
	for _, move := range moves {
		weight := 1.0

		// Prefer captures (big weight increase)
		if move.CapturedPiece != nil {
			weight += 5.0
			// Prefer capturing valuable pieces (MVV)
			victimValue := getPieceValue(move.CapturedPiece.Type)
			weight += float64(victimValue) / 50.0
			// Penalize if capturing piece is undefended (LVA consideration)
			if !b.canMoveTo(board, move.From, move.To) {
				weight *= 0.8 // Slight penalty for potentially losing the attacking piece
			}
		}

		// STRONG preference for center moves
		if move.To.Row >= 3 && move.To.Row <= 4 && move.To.Col >= 3 && move.To.Col <= 4 {
			weight += 2.0
		}

		// Penalty for putting pieces under attack and undefended
		testBoard := board.Clone()
		testBoard.MakeMove(move)
		if !b.isPieceSafe(testBoard, move.To) {
			weight *= 0.3 // Strong penalty for hanging pieces
		}

		// Bonus for moving pieces closer to the center
		distBefore := float64(abs(move.From.Row-3)) + float64(abs(move.From.Col-3))
		distAfter := float64(abs(move.To.Row-3)) + float64(abs(move.To.Col-3))
		if distAfter < distBefore {
			weight += 0.5
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

			// Apply safety discount - hanging pieces are less valuable
			safetyMultiplier := 1.0
			if !b.isPieceSafe(board, engine.Position{Row: row, Col: col}) {
				// Piece is under attack
				if !isPositionDefended(board, engine.Position{Row: row, Col: col}, piece.Color) {
					// Piece is hanging (attacked but undefended)
					safetyMultiplier = 0.3 // Severely discount hanging pieces
				} else {
					// Piece is defended - less discount
					safetyMultiplier = 0.8
				}
			}

			totalValue := (pieceValue + positionalValue) * safetyMultiplier

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
	// Enhanced positional tables for better strategic play
	value := 0.0

	switch piece.Type {
	case engine.Pawn:
		// Pawns are more valuable when advanced
		if piece.Color == engine.White {
			value += float64(pos.Row) * 3.0
			// Extra bonus for advanced passed pawns (row 5-6)
			if pos.Row >= 5 {
				value += 15.0
			}
		} else {
			value += float64(7-pos.Row) * 3.0
			// Extra bonus for advanced passed pawns
			if pos.Row <= 2 {
				value += 15.0
			}
		}

	case engine.Knight:
		// Knights are best in the center
		if pos.Row >= 2 && pos.Row <= 5 && pos.Col >= 2 && pos.Col <= 5 {
			value += 20.0
		}
		if pos.Row >= 3 && pos.Row <= 4 && pos.Col >= 3 && pos.Col <= 4 {
			value += 10.0 // Extra bonus for deep center
		}

	case engine.Bishop:
		// Bishops prefer the center and control of long diagonals
		if pos.Row >= 2 && pos.Row <= 5 && pos.Col >= 2 && pos.Col <= 5 {
			value += 15.0
		}
		// Bonus for bishops on long diagonals
		if (pos.Row == 0 && pos.Col == 0) || (pos.Row == 7 && pos.Col == 7) ||
			(pos.Row == 0 && pos.Col == 7) || (pos.Row == 7 && pos.Col == 0) {
			value += 8.0 // Controlling important corners
		}

	case engine.Rook:
		// Rooks are strong on open files (7th rank is especially powerful)
		if piece.Color == engine.White && pos.Row >= 5 {
			value += float64(pos.Row-4) * 10.0
		} else if piece.Color == engine.Black && pos.Row <= 2 {
			value += float64(3-pos.Row) * 10.0
		}
		// Rooks active when developed from starting position
		if piece.HasMoved {
			value += 8.0
		}

	case engine.Queen:
		// Queens strong in center
		if pos.Row >= 3 && pos.Row <= 4 && pos.Col >= 3 && pos.Col <= 4 {
			value += 15.0
		}
		if pos.Row >= 2 && pos.Row <= 5 && pos.Col >= 2 && pos.Col <= 5 {
			value += 10.0
		}

	case engine.King:
		// King safety is critical - prefer back rank in opening/middlegame
		if piece.Color == engine.White {
			// White prefers back rank (row 0-1) in opening
			if pos.Row <= 1 {
				value += 10.0
			}
			// King on side files is safer (less exposed)
			if pos.Col <= 1 || pos.Col >= 6 {
				value += 5.0
			}
		} else {
			// Black prefers back rank (row 6-7)
			if pos.Row >= 6 {
				value += 10.0
			}
			// King on side files is safer
			if pos.Col <= 1 || pos.Col >= 6 {
				value += 5.0
			}
		}
	}

	// General center control bonus
	if pos.Row >= 3 && pos.Row <= 4 && pos.Col >= 3 && pos.Col <= 4 {
		value += 5.0
	}

	// Development bonus (move pieces from starting position)
	if piece.Type != engine.Pawn && piece.Type != engine.King && piece.HasMoved {
		value += 3.0
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
		// ALSO: Defend your rook and attack opponent's rook
		targetRow := 7
		if b.Color == engine.Black {
			targetRow = 0
		}
		
		var myRookPos engine.Position
		var oppRookPos engine.Position
		myRookFound := false
		oppRookFound := false
		
		// Find both rooks and score rook advancement
		for col := 0; col < 8; col++ {
			for row := 0; row < 8; row++ {
				piece := board.GetPieceAt(engine.Position{Row: row, Col: col})
				if piece != nil && piece.Type == engine.Rook {
					if piece.Color == b.Color {
						myRookPos = engine.Position{Row: row, Col: col}
						myRookFound = true
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
					} else {
						oppRookPos = engine.Position{Row: row, Col: col}
						oppRookFound = true
					}
				}
			}
		}
		
		// Evaluate rook safety and opponent threats
		if myRookFound && oppRookFound {
			// Penalty if opponent's rook is attacking our rook (unless defended)
			if isRookAttackingPosition(board, oppRookPos, myRookPos) {
				// Check if our rook is defended
				if isPositionDefended(board, myRookPos, b.Color) {
					score += 50.0 // Our rook is defended, rook trade likely favorable
				} else {
					score -= 300.0 // Our rook is under attack and undefended - critical!
				}
			}
			
			// Bonus if we can attack opponent's rook
			if isRookAttackingPosition(board, myRookPos, oppRookPos) {
				score += 150.0 // We're threatening opponent's rook
			}
			
			// Bonus for having multiple pieces that can defend our rook
			defendingPieces := countDefendingPieces(board, myRookPos, b.Color)
			score += float64(defendingPieces) * 20.0
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
			// Prioritize moving queen toward own half to escape
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
				// White queen starts at d8 (row 7), needs to reach rows 0-3 (own half)
				// Black queen starts at d1 (row 0), needs to reach rows 4-7 (own half)
				if b.Color == engine.White {
					// White wants to be in rows 0-3
					if queenPos.Row <= 3 {
						score += 1500.0 // Escaped!
					} else {
						// Give bonus for being closer to row 3 (escape line)
						distance := queenPos.Row - 3
						score += float64(4-distance) * 200.0
					}
				} else {
					// Black wants to be in rows 4-7
					if queenPos.Row >= 4 {
						score += 1500.0 // Escaped!
					} else {
						// Give bonus for being closer to row 4 (escape line)
						distance := 4 - queenPos.Row
						score += float64(4-distance) * 200.0
					}
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
		// Heir Mode Strategy:
		// 1. Protect your king (it can be captured!)
		// 2. If king is captured, prioritize pawn promotion to get a new king
		// 3. Try to capture opponent's king
		// 4. Advanced pawns are extremely valuable (potential kings)
		
		// Count kings and find their positions
		myKings := 0
		oppKings := 0
		var myKingPos engine.Position
		var oppKingPos engine.Position
		
		for row := 0; row < 8; row++ {
			for col := 0; col < 8; col++ {
				piece := board.GetPieceAt(engine.Position{Row: row, Col: col})
				if piece != nil && piece.Type == engine.King {
					if piece.Color == b.Color {
						myKings++
						myKingPos = engine.Position{Row: row, Col: col}
					} else {
						oppKings++
						oppKingPos = engine.Position{Row: row, Col: col}
					}
				}
			}
		}
		
		// King count difference is critical
		score += float64(myKings-oppKings) * 800.0
		
		// If we have no king, URGENTLY need to promote a pawn
		if myKings == 0 {
			// Find our most advanced pawn
			for row := 0; row < 8; row++ {
				for col := 0; col < 8; col++ {
					piece := board.GetPieceAt(engine.Position{Row: row, Col: col})
					if piece != nil && piece.Type == engine.Pawn && piece.Color == b.Color {
						// HUGE bonus for advanced pawns when we have no king
						if b.Color == engine.White {
							score += float64(row) * 150.0 // Row 6 = 900 bonus!
							if row == 6 { // One step from promotion
								score += 500.0
							}
						} else {
							score += float64(7-row) * 150.0
							if row == 1 { // One step from promotion
								score += 500.0
							}
						}
					}
				}
			}
		} else {
			// We have a king - protect it!
			// Penalty if king is under attack
			if !b.isPieceSafe(board, myKingPos) {
				score -= 400.0 // King in danger!
			}
			
			// Bonus for pieces defending the king
			defenders := countDefendingPieces(board, myKingPos, b.Color)
			score += float64(defenders) * 50.0
		}
		
		// If opponent has a king, bonus for attacking it
		if oppKings > 0 {
			// Count our pieces attacking opponent's king
			for row := 0; row < 8; row++ {
				for col := 0; col < 8; col++ {
					piece := board.GetPieceAt(engine.Position{Row: row, Col: col})
					if piece != nil && piece.Color == b.Color {
						if b.canPieceAttack(board, piece, oppKingPos) {
							score += 200.0 // Attacking opponent's king!
						}
					}
				}
			}
		}
		
		// If opponent has no king and no pawns, we've won
		if oppKings == 0 {
			oppPawns := 0
			for row := 0; row < 8; row++ {
				for col := 0; col < 8; col++ {
					piece := board.GetPieceAt(engine.Position{Row: row, Col: col})
					if piece != nil && piece.Type == engine.Pawn && piece.Color != b.Color {
						oppPawns++
					}
				}
			}
			if oppPawns == 0 {
				score += 10000.0 // Opponent can't get a king back - victory!
			} else {
				// Opponent has pawns but no king - try to capture their pawns
				score += 500.0 // Good position
			}
		}
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
	
	// Attacking moves (piece moves to square where it attacks an opponent piece)
	// This is implicit in captures above, but helpful for non-captures
	if move.CapturedPiece == nil {
		score += 5 // Small bonus for non-capture attacking moves
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

// canMoveTo checks if a move from->to would leave the piece defended or whether it would be lost
// Returns true if the piece would be safe after the move
func (b *Bot) canMoveTo(board *engine.Board, from, to engine.Position) bool {
	testBoard := board.Clone()
	testBoard.MakeMove(engine.Move{From: from, To: to})
	
	// Check if the piece at destination is defended
	piece := testBoard.GetPieceAt(to)
	if piece == nil {
		return true // Shouldn't happen in normal cases
	}
	
	// Check if piece is under attack
	for row := 0; row < 8; row++ {
		for col := 0; col < 8; col++ {
			oppPiece := testBoard.GetPieceAt(engine.Position{Row: row, Col: col})
			if oppPiece != nil && oppPiece.Color != piece.Color {
				if b.canPieceAttack(testBoard, oppPiece, to) {
					// Piece is under attack - check if defended
					if !isPositionDefended(testBoard, to, piece.Color) {
						return false // Hanging piece
					}
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

// isRookAttackingPosition checks if a rook at rookPos can attack targetPos
func isRookAttackingPosition(board *engine.Board, rookPos, targetPos engine.Position) bool {
	// Rooks attack horizontally and vertically
	if rookPos.Row == targetPos.Row {
		// Same row - check if path is clear
		return isPathClear(board, rookPos, targetPos)
	}
	if rookPos.Col == targetPos.Col {
		// Same column - check if path is clear
		return isPathClear(board, rookPos, targetPos)
	}
	return false
}

// isPathClear checks if there are no pieces between from and to
func isPathClear(board *engine.Board, from, to engine.Position) bool {
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

// isPositionDefended checks if a position is defended by friendly pieces
func isPositionDefended(board *engine.Board, pos engine.Position, color engine.Color) bool {
	// Check all friendly pieces to see if they can attack the position
	for row := 0; row < 8; row++ {
		for col := 0; col < 8; col++ {
			piece := board.GetPieceAt(engine.Position{Row: row, Col: col})
			if piece == nil || piece.Color != color {
				continue
			}
			
			// Check if this piece can attack the target position
			if canPieceAttackPosition(board, piece, engine.Position{Row: row, Col: col}, pos) {
				return true
			}
		}
	}
	return false
}

// countDefendingPieces counts how many pieces defend a position
func countDefendingPieces(board *engine.Board, pos engine.Position, color engine.Color) int {
	count := 0
	for row := 0; row < 8; row++ {
		for col := 0; col < 8; col++ {
			piece := board.GetPieceAt(engine.Position{Row: row, Col: col})
			if piece == nil || piece.Color != color || piece.Type == engine.King {
				continue
			}
			
			// Check if this piece can attack the target position
			if canPieceAttackPosition(board, piece, engine.Position{Row: row, Col: col}, pos) {
				count++
			}
		}
	}
	return count
}

// canPieceAttackPosition checks if a piece can attack a target position
func canPieceAttackPosition(board *engine.Board, piece *engine.Piece, from, to engine.Position) bool {
	switch piece.Type {
	case engine.Pawn:
		// Pawns attack diagonally forward
		direction := 1
		if piece.Color == engine.Black {
			direction = -1
		}
		return to.Row == from.Row+direction && abs(to.Col-from.Col) == 1

	case engine.Rook:
		// Rooks attack horizontally/vertically
		if from.Row == to.Row || from.Col == to.Col {
			return isPathClear(board, from, to)
		}
		return false

	case engine.Bishop:
		// Bishops attack diagonally
		if abs(from.Row-to.Row) == abs(from.Col-to.Col) && from != to {
			return isPathClear(board, from, to)
		}
		return false

	case engine.Knight:
		// Knights attack in L-shape
		dRow := abs(from.Row - to.Row)
		dCol := abs(from.Col - to.Col)
		return (dRow == 2 && dCol == 1) || (dRow == 1 && dCol == 2)

	case engine.Queen:
		// Queens attack like rooks + bishops
		if from.Row == to.Row || from.Col == to.Col {
			return isPathClear(board, from, to)
		}
		if abs(from.Row-to.Row) == abs(from.Col-to.Col) && from != to {
			return isPathClear(board, from, to)
		}
		return false

	case engine.King:
		// Kings attack adjacent squares
		return abs(from.Row-to.Row) <= 1 && abs(from.Col-to.Col) <= 1 && from != to
	}

	return false
}
