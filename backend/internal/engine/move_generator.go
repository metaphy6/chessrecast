package engine

// MoveGenerator generates valid moves for pieces
type MoveGenerator struct {
	board *Board
}

// NewMoveGenerator creates a new move generator
func NewMoveGenerator(board *Board) *MoveGenerator {
	return &MoveGenerator{board: board}
}

// GetValidMoves returns all valid moves for a piece at the given position
func (mg *MoveGenerator) GetValidMoves(pos Position) []Move {
	piece := mg.board.GetPieceAt(pos)
	if piece == nil || piece.Color != mg.board.CurrentTurn {
		return []Move{}
	}

	// Generate pseudo-legal moves
	var moves []Move
	switch piece.Type {
	case Pawn:
		moves = mg.getPawnMoves(piece)
	case Rook:
		moves = mg.getRookMoves(piece)
	case Knight:
		moves = mg.getKnightMoves(piece)
	case Bishop:
		moves = mg.getBishopMoves(piece)
	case Queen:
		moves = mg.getQueenMoves(piece)
	case King:
		moves = mg.getKingMoves(piece)
	}

	// Apply Game Mod specific rules
	moves = mg.applyGameModRules(moves, piece)

	// Truce mod: During truce, there is NO check concept - kings move freely
	// Skip all check-related filtering when truce is active
	if mg.board.Mod == Truce && mg.board.TruceActive {
		return moves
	}

	// Filter moves that would leave king in check (unless Game Mod allows it)
	if !mg.allowsSelfCheck() {
		moves = mg.filterCheckMoves(moves)
	}

	return moves
}

// getPawnMoves generates pawn moves
func (mg *MoveGenerator) getPawnMoves(pawn *Piece) []Move {
	// Special handling for Mercenary mod
	if mg.board.Mod == Mercenary {
		return mg.getMercenaryPawnMoves(pawn)
	}

	moves := []Move{}
	direction := 1
	startRow := 1
	promotionRow := 7

	if pawn.Color == Black {
		direction = -1
		startRow = 6
		promotionRow = 0
	}

	// Forward move
	oneStep := pawn.Position.Offset(direction, 0)
	if oneStep.IsValid() && mg.board.GetPieceAt(oneStep) == nil {
		if oneStep.Row == promotionRow {
			// Promotion
			for _, promoPiece := range mg.getPromotionPieces(pawn.Color) {
				move := NewMove(pawn.Position, oneStep, pawn)
				move.IsPromotion = true
				move.Promotion = promoPiece
				moves = append(moves, *move)
			}
		} else {
			moves = append(moves, *NewMove(pawn.Position, oneStep, pawn))
			
			// Two-step move from starting position
			if pawn.Position.Row == startRow {
				twoStep := pawn.Position.Offset(direction*2, 0)
				if twoStep.IsValid() && mg.board.GetPieceAt(twoStep) == nil {
					moves = append(moves, *NewMove(pawn.Position, twoStep, pawn))
				}
			}
		}
	}

	// Diagonal captures
	for _, colOffset := range []int{-1, 1} {
		capturePos := pawn.Position.Offset(direction, colOffset)
		if !capturePos.IsValid() {
			continue
		}

		targetPiece := mg.board.GetPieceAt(capturePos)
		if targetPiece != nil && targetPiece.Color != pawn.Color {
			if capturePos.Row == promotionRow {
				// Capture with promotion
				for _, promoPiece := range mg.getPromotionPieces(pawn.Color) {
					move := NewMove(pawn.Position, capturePos, pawn)
					move.CapturedPiece = targetPiece
					move.IsPromotion = true
					move.Promotion = promoPiece
					moves = append(moves, *move)
				}
			} else {
				move := NewMove(pawn.Position, capturePos, pawn)
				move.CapturedPiece = targetPiece
				moves = append(moves, *move)
			}
		}

		// En passant
		if mg.board.EnPassantSquare != nil && capturePos.Equals(*mg.board.EnPassantSquare) {
			capturedPawn := mg.board.GetPieceAt(Position{Row: pawn.Position.Row, Col: capturePos.Col})
			if capturedPawn != nil && capturedPawn.Type == Pawn {
				move := NewMove(pawn.Position, capturePos, pawn)
				move.IsEnPassant = true
				move.CapturedPiece = capturedPawn
				moves = append(moves, *move)
			}
		}
	}

	return moves
}

// getMercenaryPawnMoves - Pawns move like kings in Mercenary mod
func (mg *MoveGenerator) getMercenaryPawnMoves(pawn *Piece) []Move {
	moves := []Move{}
	
	// King-like moves (one square in any direction)
	offsets := [][2]int{
		{-1, -1}, {-1, 0}, {-1, 1},
		{0, -1}, {0, 1},
		{1, -1}, {1, 0}, {1, 1},
	}

	for _, offset := range offsets {
		newPos := pawn.Position.Offset(offset[0], offset[1])
		if !newPos.IsValid() {
			continue
		}

		targetPiece := mg.board.GetPieceAt(newPos)
		if targetPiece == nil {
			// Empty square - can move (no promotion in Mercenary)
			moves = append(moves, *NewMove(pawn.Position, newPos, pawn))
		} else if targetPiece.Color != pawn.Color {
			// Enemy piece - can capture (but not king unless Heir mod)
			if targetPiece.Type == King && mg.board.Mod != Heir {
				continue // Skip capturing king
			}
			move := NewMove(pawn.Position, newPos, pawn)
			move.CapturedPiece = targetPiece
			moves = append(moves, *move)
		}
		// Friendly pieces block movement
	}

	return moves
}

// getRookMoves generates rook moves
func (mg *MoveGenerator) getRookMoves(rook *Piece) []Move {
	return mg.getSlidingMoves(rook, [][2]int{{-1, 0}, {1, 0}, {0, -1}, {0, 1}})
}

// getKnightMoves generates knight moves
func (mg *MoveGenerator) getKnightMoves(knight *Piece) []Move {
	moves := []Move{}
	offsets := [][2]int{
		{-2, -1}, {-2, 1}, {-1, -2}, {-1, 2},
		{1, -2}, {1, 2}, {2, -1}, {2, 1},
	}

	for _, offset := range offsets {
		newPos := knight.Position.Offset(offset[0], offset[1])
		if !newPos.IsValid() {
			continue
		}

		targetPiece := mg.board.GetPieceAt(newPos)
		if targetPiece == nil {
			moves = append(moves, *NewMove(knight.Position, newPos, knight))
		} else if targetPiece.Color != knight.Color {
			move := NewMove(knight.Position, newPos, knight)
			move.CapturedPiece = targetPiece
			moves = append(moves, *move)
		}
	}

	return moves
}

// getBishopMoves generates bishop moves
func (mg *MoveGenerator) getBishopMoves(bishop *Piece) []Move {
	return mg.getSlidingMoves(bishop, [][2]int{{-1, -1}, {-1, 1}, {1, -1}, {1, 1}})
}

// getQueenMoves generates queen moves
func (mg *MoveGenerator) getQueenMoves(queen *Piece) []Move {
	// Queen moves like rook + bishop
	allOffsets := [][2]int{
		{-1, 0}, {1, 0}, {0, -1}, {0, 1}, // Rook-like
		{-1, -1}, {-1, 1}, {1, -1}, {1, 1}, // Bishop-like
	}
	return mg.getSlidingMoves(queen, allOffsets)
}

// getKingMoves generates king moves
func (mg *MoveGenerator) getKingMoves(king *Piece) []Move {
	moves := []Move{}
	offsets := [][2]int{
		{-1, -1}, {-1, 0}, {-1, 1},
		{0, -1}, {0, 1},
		{1, -1}, {1, 0}, {1, 1},
	}

	for _, offset := range offsets {
		newPos := king.Position.Offset(offset[0], offset[1])
		if !newPos.IsValid() {
			continue
		}

		targetPiece := mg.board.GetPieceAt(newPos)
		
		// Heir mod: Kings follow classic chess rules with each other
		// Kings can NEVER capture each other or be adjacent
		if targetPiece != nil && targetPiece.Type == King {
			continue // Skip this move - kings can't capture each other or be adjacent
		}
		
		// Check if moving to this square would put king adjacent to opponent king
		if mg.isKingAdjacentToSquare(newPos, king.Color.Opposite()) {
			continue // Skip - would be adjacent to opponent king
		}
		
		if targetPiece == nil {
			moves = append(moves, *NewMove(king.Position, newPos, king))
		} else if targetPiece.Color != king.Color {
			move := NewMove(king.Position, newPos, king)
			move.CapturedPiece = targetPiece
			moves = append(moves, *move)
		}
	}

	// Castling
	if !king.HasMoved {
		moves = append(moves, mg.getCastlingMoves(king)...)
	}

	return moves
}

// getSlidingMoves generates moves for sliding pieces (rook, bishop, queen)
func (mg *MoveGenerator) getSlidingMoves(piece *Piece, directions [][2]int) []Move {
	moves := []Move{}

	for _, dir := range directions {
		for distance := 1; distance < 8; distance++ {
			newPos := piece.Position.Offset(dir[0]*distance, dir[1]*distance)
			if !newPos.IsValid() {
				break
			}

			targetPiece := mg.board.GetPieceAt(newPos)
			if targetPiece == nil {
				moves = append(moves, *NewMove(piece.Position, newPos, piece))
			} else {
				if targetPiece.Color != piece.Color {
					move := NewMove(piece.Position, newPos, piece)
					move.CapturedPiece = targetPiece
					moves = append(moves, *move)
				}
				break // Can't move past any piece
			}
		}
	}

	return moves
}

// getCastlingMoves generates castling moves for the king
func (mg *MoveGenerator) getCastlingMoves(king *Piece) []Move {
	moves := []Move{}
	
	// Check if king is in check (can't castle out of check)
	if mg.isSquareAttacked(king.Position, king.Color.Opposite()) {
		return moves
	}

	row := 0
	if king.Color == Black {
		row = 7
	}

	// Kingside castling
	canKingside := (king.Color == White && mg.board.WhiteCanCastleKingside) ||
		(king.Color == Black && mg.board.BlackCanCastleKingside)
		
	if canKingside {
		// Verify rook is actually present
		rook := mg.board.GetPieceAt(Position{Row: row, Col: 7})
		if rook != nil && rook.Type == Rook && rook.Color == king.Color {
			// Check squares between king and rook are empty
			if mg.board.GetPieceAt(Position{Row: row, Col: 5}) == nil &&
				mg.board.GetPieceAt(Position{Row: row, Col: 6}) == nil {
				// Check squares king moves through aren't attacked
				if !mg.isSquareAttacked(Position{Row: row, Col: 5}, king.Color.Opposite()) &&
					!mg.isSquareAttacked(Position{Row: row, Col: 6}, king.Color.Opposite()) {
					move := NewMove(king.Position, Position{Row: row, Col: 6}, king)
					move.IsCastling = true
					moves = append(moves, *move)
				}
			}
		}
	}

	// Queenside castling
	canQueenside := (king.Color == White && mg.board.WhiteCanCastleQueenside) ||
		(king.Color == Black && mg.board.BlackCanCastleQueenside)
		
	if canQueenside {
		// Verify rook is actually present
		rook := mg.board.GetPieceAt(Position{Row: row, Col: 0})
		if rook != nil && rook.Type == Rook && rook.Color == king.Color {
			// Check squares between king and rook are empty
			if mg.board.GetPieceAt(Position{Row: row, Col: 1}) == nil &&
				mg.board.GetPieceAt(Position{Row: row, Col: 2}) == nil &&
				mg.board.GetPieceAt(Position{Row: row, Col: 3}) == nil {
				// Check squares king moves through aren't attacked
				if !mg.isSquareAttacked(Position{Row: row, Col: 2}, king.Color.Opposite()) &&
					!mg.isSquareAttacked(Position{Row: row, Col: 3}, king.Color.Opposite()) {
					move := NewMove(king.Position, Position{Row: row, Col: 2}, king)
					move.IsCastling = true
					moves = append(moves, *move)
				}
			}
		}
	}

	return moves
}

// getPromotionPieces returns available promotion pieces for a color
func (mg *MoveGenerator) getPromotionPieces(color Color) []PieceType {
	switch mg.board.Mod {
	case Succession:
		// Cannot promote to queen (each side has two queens already)
		// Check if can promote to king
		if mg.board.PromotedKings[color] == 0 {
			return []PieceType{King, Rook, Bishop, Knight}
		}
		return []PieceType{Rook, Bishop, Knight}
	case SaveTheQueen:
		// Cannot promote to queen (only one queen per side allowed)
		return []PieceType{Rook, Bishop, Knight}
	case Heir:
		// In Heir mod, can promote to King only once
		// BUT: the promoted King becomes the "last" king, so classic check rules apply
		// Therefore, cannot promote to King if the promotion square is under attack
		if mg.board.PromotedKings[color] == 0 {
			return []PieceType{Queen, Rook, Bishop, Knight, King}
		}
		return []PieceType{Queen, Rook, Bishop, Knight}
	default:
		return []PieceType{Queen, Rook, Bishop, Knight}
	}
}

// applyGameModRules applies game-specific movement rules
func (mg *MoveGenerator) applyGameModRules(moves []Move, piece *Piece) []Move {
	switch mg.board.Mod {
	case FriendlyFire:
		return mg.applyFriendlyFireRules(moves, piece)
	case KingsBattle:
		return mg.applyKingsBattleRules(moves, piece)
	case Truce:
		return mg.applyTruceRules(moves, piece)
	case SaveTheQueen:
		return mg.applySaveTheQueenRules(moves, piece)
	case Heir:
		return mg.applyHeirRules(moves, piece)
	default:
		return moves
	}
}

// applyFriendlyFireRules allows capturing own pieces (except king and unmoved pieces)
func (mg *MoveGenerator) applyFriendlyFireRules(moves []Move, piece *Piece) []Move {
	// Add moves to capture friendly pieces that have moved
	additionalMoves := []Move{}
	
	for row := 0; row < 8; row++ {
		for col := 0; col < 8; col++ {
			targetPiece := mg.board.GetPieceAt(Position{Row: row, Col: col})
			if targetPiece == nil || targetPiece.Color != piece.Color {
				continue
			}
			
			// Can't capture king or unmoved pieces
			if targetPiece.Type == King || !targetPiece.HasMoved {
				continue
			}

			// Check if piece can reach this square
			targetPos := Position{Row: row, Col: col}
			if mg.canPieceReach(piece, targetPos) {
				move := NewMove(piece.Position, targetPos, piece)
				move.CapturedPiece = targetPiece
				additionalMoves = append(additionalMoves, *move)
			}
		}
	}

	return append(moves, additionalMoves...)
}

// applyKingsBattleRules locks pieces until king captures pawn
func (mg *MoveGenerator) applyKingsBattleRules(moves []Move, piece *Piece) []Move {
	if mg.board.KingsKillUnlock {
		// All pieces unlocked after First Blood
		return moves
	}

	// Phase 1: Only kings and pawns can move
	if piece.Type != King && piece.Type != Pawn {
		// Lock this piece - return no moves
		return []Move{}
	}

	// Kings and pawns can move
	return moves
}

// applyTruceRules enforces truce period rules
func (mg *MoveGenerator) applyTruceRules(moves []Move, piece *Piece) []Move {
	if !mg.board.TruceActive {
		// Truce broken - normal chess rules apply
		return moves
	}

	// During truce: Check if piece has moved 3 times
	if mg.board.PieceMoveCounter[piece.Position] >= 3 {
		return []Move{} // Can't move anymore during truce
	}

	// During truce: Filter out captures (captures allowed only when truce breaks)
	nonCaptureMoves := []Move{}
	for _, move := range moves {
		if move.CapturedPiece == nil {
			nonCaptureMoves = append(nonCaptureMoves, move)
		}
	}

	return nonCaptureMoves
}

// applySaveTheQueenRules handles imprisoned queen movement and capture restrictions
func (mg *MoveGenerator) applySaveTheQueenRules(moves []Move, piece *Piece) []Move {
	if piece.Type == Queen {
		// Check if queen is currently in its own half
		currentlyInOwnHalf := false
		if piece.Color == White {
			currentlyInOwnHalf = piece.Position.Row <= 3 // White's own half is rows 0-3
		} else {
			currentlyInOwnHalf = piece.Position.Row >= 4 // Black's own half is rows 4-7
		}

		if !currentlyInOwnHalf {
			// Queen is imprisoned (in opponent's half) - moves like king only
			restrictedMoves := []Move{}
			for _, move := range moves {
				// Only allow one-square moves
				rowDiff := abs(move.To.Row - move.From.Row)
				colDiff := abs(move.To.Col - move.From.Col)
				if rowDiff <= 1 && colDiff <= 1 {
					// Can't capture while imprisoned
					if move.CapturedPiece == nil {
						restrictedMoves = append(restrictedMoves, move)
					}
				}
			}
			return restrictedMoves
		}

		// Queen is escaped (in own half) - has full queen power within own half,
		// but can only move like a king when crossing back to opponent's half
		filteredMoves := []Move{}
		for _, move := range moves {
			targetInOwnHalf := false
			if piece.Color == White {
				targetInOwnHalf = move.To.Row <= 3 // White's own half is rows 0-3
			} else {
				targetInOwnHalf = move.To.Row >= 4 // Black's own half is rows 4-7
			}

			if targetInOwnHalf {
				// Target is in own half - allow full queen power
				filteredMoves = append(filteredMoves, move)
			} else {
				// Target is in opponent's half - only allow king-like moves (becoming prisoner again)
				rowDiff := abs(move.To.Row - move.From.Row)
				colDiff := abs(move.To.Col - move.From.Col)
				if rowDiff <= 1 && colDiff <= 1 && move.CapturedPiece == nil {
					filteredMoves = append(filteredMoves, move)
				}
			}
		}
		return filteredMoves
	}

	// For non-queen pieces: filter out captures of queens on their prison squares
	// AND filter out captures of prisoner queens when their prison is occupied
	filteredMoves := []Move{}
	for _, move := range moves {
		// Check if this move captures a queen
		if move.CapturedPiece != nil && move.CapturedPiece.Type == Queen {
			// Check if the captured queen is on its initial prison square
			whitePrison := Position{Row: 7, Col: 3} // d8
			blackPrison := Position{Row: 0, Col: 3} // d1
			
			isOnPrisonSquare := (move.CapturedPiece.Color == White && move.To == whitePrison) ||
				(move.CapturedPiece.Color == Black && move.To == blackPrison)
			
			if isOnPrisonSquare {
				// Cannot capture queen on its prison square - skip this move
				continue
			}

			// Check if capturing a prisoner queen (in opponent's half)
			capturedQueenInOwnHalf := (move.CapturedPiece.Color == White && move.To.Row <= 3) ||
				(move.CapturedPiece.Color == Black && move.To.Row >= 4)
			
			if !capturedQueenInOwnHalf {
				// Queen is a prisoner - check if prison is occupied
				prisonPos := blackPrison
				if move.CapturedPiece.Color == White {
					prisonPos = whitePrison
				}
				
				prisonOccupied := mg.board.GetPieceAt(prisonPos) != nil
				
				if prisonOccupied {
					// Prison is occupied - cannot capture prisoner queen
					continue
				}
			}
		}
		
		// Keep all other moves
		filteredMoves = append(filteredMoves, move)
	}
	
	return filteredMoves
}

// applyHeirRules applies Heir mod specific rules
// Main rule: Cannot promote pawn to King if the promotion square is under attack
// This is because the promoted King becomes the "last" king and classic check rules apply
// If player has no king, they MUST promote to King, so if square is under attack, NO promotion is legal
func (mg *MoveGenerator) applyHeirRules(moves []Move, piece *Piece) []Move {
	if piece.Type != Pawn {
		return moves
	}

	// Check if player has already promoted a king
	if mg.board.PromotedKings[piece.Color] > 0 {
		return moves // Already promoted a king, no special filtering needed
	}

	// Check if player currently has a king
	hasKing := mg.board.HasKing(piece.Color)

	// Filter promotion moves based on whether player has a king
	filteredMoves := []Move{}
	for _, move := range moves {
		if move.IsPromotion {
			// Check if the promotion square is under attack
			isUnderAttack := mg.isSquareAttacked(move.To, piece.Color.Opposite())

			if !hasKing {
				// No king = MUST promote to King only
				if move.Promotion == King {
					if !isUnderAttack {
						filteredMoves = append(filteredMoves, move) // King promotion is legal
					}
					// If under attack, skip this move (can't promote to King into check)
				}
				// Skip all non-King promotions when player has no king
			} else {
				// Has king = can promote to any piece
				if move.Promotion == King {
					if !isUnderAttack {
						filteredMoves = append(filteredMoves, move) // King promotion is legal
					}
					// If under attack, skip King promotion
				} else {
					filteredMoves = append(filteredMoves, move) // Other promotions are always legal
				}
			}
		} else {
			// Non-promotion moves are always included
			filteredMoves = append(filteredMoves, move)
		}
	}

	return filteredMoves
}

// Helper methods

func (mg *MoveGenerator) canPieceReach(piece *Piece, target Position) bool {
	return mg.canPieceReachOnBoard(mg.board, piece, target)
}

// canPieceReachOnBoard checks if a sliding piece can reach target on the specified board
func (mg *MoveGenerator) canPieceReachOnBoard(board *Board, piece *Piece, target Position) bool {
	// KINGS' BATTLE PHASE 1: Only pawns and kings can reach targets (they have effect)
	// Other pieces are placeholders with no effect
	if board.Mod == KingsBattle && !board.KingsKillUnlock {
		if piece.Type != Pawn && piece.Type != King {
			return false // Other pieces are placeholders
		}
	}

	// For sliding pieces, check if path is clear and direction is valid
	dr := target.Row - piece.Position.Row
	dc := target.Col - piece.Position.Col
	
	switch piece.Type {
	case Pawn:
		// Pawns can only capture diagonally
		direction := 1
		if piece.Color == Black {
			direction = -1
		}
		return dr == direction && (dc == -1 || dc == 1)
	case Knight:
		// Knight L-shape
		return (abs(dr) == 2 && abs(dc) == 1) || (abs(dr) == 1 && abs(dc) == 2)
	case King:
		// King can move one square in any direction
		return abs(dr) <= 1 && abs(dc) <= 1 && (dr != 0 || dc != 0)
	case Rook:
		// Rooks move horizontally or vertically
		if dr != 0 && dc != 0 {
			return false
		}
		return mg.isPathClearOnBoard(board, piece.Position, target)
	case Bishop:
		// Bishops move diagonally
		if abs(dr) != abs(dc) || dr == 0 {
			return false
		}
		return mg.isPathClearOnBoard(board, piece.Position, target)
	case Queen:
		// Queen can move like rook or bishop
		if (dr == 0 || dc == 0) && (dr != 0 || dc != 0) {
			return mg.isPathClearOnBoard(board, piece.Position, target)
		}
		if abs(dr) == abs(dc) && dr != 0 {
			return mg.isPathClearOnBoard(board, piece.Position, target)
		}
		return false
	}
	return false
}

// isPathClearOnBoard checks if there are no pieces between from and to on the specified board
func (mg *MoveGenerator) isPathClearOnBoard(board *Board, from, to Position) bool {
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
		blockingPiece := board.GetPieceAt(Position{Row: row, Col: col})
		if blockingPiece != nil {
			// KINGS' BATTLE PHASE 1: Only pawns and kings block paths (they have effect)
			// Other pieces are placeholders with no effect
			if board.Mod == KingsBattle && !board.KingsKillUnlock {
				if blockingPiece.Type != Pawn && blockingPiece.Type != King {
					// Ignore other pieces - they have no effect
					row += dr
					col += dc
					continue
				}
			}
			return false // Path is blocked
		}
		row += dr
		col += dc
	}
	return true
}

func (mg *MoveGenerator) filterCheckMoves(moves []Move) []Move {
	validMoves := []Move{}
	
	for _, move := range moves {
		// Make move on cloned board
		testBoard := mg.board.Clone()
		
		// IMPORTANT: Preserve the original KingsKillUnlock state for checking
		// This prevents a king capturing a pawn from unlocking pieces during the validation check
		originalUnlockState := testBoard.KingsKillUnlock
		
		testBoard.MakeMove(move)
		
		// Temporarily restore the unlock state for the check validation
		// This ensures we validate using the game state BEFORE the move
		wasUnlocked := testBoard.KingsKillUnlock
		testBoard.KingsKillUnlock = originalUnlockState
		
		// Check if own king is in check
		kingInCheck := mg.isKingInCheck(testBoard, move.Piece.Color)
		
		// Restore the actual unlock state
		testBoard.KingsKillUnlock = wasUnlocked
		
		if !kingInCheck {
			validMoves = append(validMoves, move)
		}
	}

	return validMoves
}

func (mg *MoveGenerator) isKingInCheck(board *Board, color Color) bool {
	// Find king position
	var kingPos Position
	found := false
	
	for row := 0; row < 8; row++ {
		for col := 0; col < 8; col++ {
			piece := board.GetPieceAt(Position{Row: row, Col: col})
			if piece != nil && piece.Type == King && piece.Color == color {
				kingPos = piece.Position
				found = true
				break
			}
		}
		if found {
			break
		}
	}

	if !found {
		return false // No king (possible in some game mods)
	}

	// Use the passed board for attack checking, not mg.board
	return mg.isSquareAttackedOnBoard(board, kingPos, color.Opposite())
}

// isSquareAttacked checks if a square is attacked on the current board (mg.board)
func (mg *MoveGenerator) isSquareAttacked(pos Position, byColor Color) bool {
	return mg.isSquareAttackedOnBoard(mg.board, pos, byColor)
}

// isSquareAttackedOnBoard checks if a square is attacked on the specified board
func (mg *MoveGenerator) isSquareAttackedOnBoard(board *Board, pos Position, byColor Color) bool {
	// Heir mod: Kings ALWAYS control adjacent squares to prevent opponent king from moving there
	// This ensures king-to-king respect regardless of check rule state
	if board.Mod == Heir {
		targetPiece := board.GetPieceAt(pos)
		if targetPiece != nil && targetPiece.Type == King {
			// Checking if a king position is under attack - kings always control adjacent squares
			for row := 0; row < 8; row++ {
				for col := 0; col < 8; col++ {
					piece := board.squares[row][col]
					if piece == nil || piece.Color != byColor || piece.Type != King {
						continue
					}
					// Check if this king is adjacent to the position
					rowDiff := abs(piece.Position.Row - pos.Row)
					colDiff := abs(piece.Position.Col - pos.Col)
					if rowDiff <= 1 && colDiff <= 1 && (rowDiff != 0 || colDiff != 0) {
						return true // King controls this adjacent square
					}
				}
			}
		}
	}

	// Check if any enemy piece can attack this square
	for row := 0; row < 8; row++ {
		for col := 0; col < 8; col++ {
			piece := board.GetPieceAt(Position{Row: row, Col: col})
			if piece == nil || piece.Color != byColor {
				continue
			}

			// Kings' Battle Phase 1: Only pawns and kings can attack/control squares
			// Kings and pawns follow classic chess rules between themselves
			if board.Mod == KingsBattle && !board.KingsKillUnlock {
				if piece.Type != Pawn && piece.Type != King {
					continue // Other pieces have no effect before First Blood
				}
			}

			// Get piece's attack squares (simplified - no recursion)
			if mg.canAttackSquareOnBoard(board, piece, pos) {
				return true
			}
		}
	}
	return false
}

// canAttackSquare checks if a piece can attack a target on the current board (mg.board)
func (mg *MoveGenerator) canAttackSquare(piece *Piece, target Position) bool {
	return mg.canAttackSquareOnBoard(mg.board, piece, target)
}

// canAttackSquareOnBoard checks if a piece can attack a target on the specified board
func (mg *MoveGenerator) canAttackSquareOnBoard(board *Board, piece *Piece, target Position) bool {
	// KINGS' BATTLE PHASE 1: Only pawns and kings can attack/control squares before First Blood
	// Kings and pawns follow classic chess rules between themselves
	if board.Mod == KingsBattle && !board.KingsKillUnlock {
		if piece.Type != Pawn && piece.Type != King {
			return false // Other pieces are placeholders with no effect
		}
	}

	// Simplified attack check without generating full moves
	switch piece.Type {
	case Queen:
		// Save the Queen mod: Prisoner queens (not escaped) cannot attack/check
		if board.Mod == SaveTheQueen {
			escaped := board.EscapedQueens[piece.Color]
			if !escaped {
				return false // Prisoner queen cannot attack
			}
		}
		// Regular queen attack
		return mg.canPieceReachOnBoard(board, piece, target)
		
	case Pawn:
		// In Mercenary mode, pawns attack like kings (all 8 directions)
		if board.Mod == Mercenary {
			rowDiff := abs(piece.Position.Row - target.Row)
			colDiff := abs(piece.Position.Col - target.Col)
			return rowDiff <= 1 && colDiff <= 1 && (rowDiff > 0 || colDiff > 0)
		}
		// Standard pawn diagonal captures
		direction := 1
		if piece.Color == Black {
			direction = -1
		}
		captureLeft := piece.Position.Offset(direction, -1)
		captureRight := piece.Position.Offset(direction, 1)
		return target.Equals(captureLeft) || target.Equals(captureRight)
		
	case Knight:
		offsets := [][2]int{
			{-2, -1}, {-2, 1}, {-1, -2}, {-1, 2},
			{1, -2}, {1, 2}, {2, -1}, {2, 1},
		}
		for _, offset := range offsets {
			if piece.Position.Offset(offset[0], offset[1]).Equals(target) {
				return true
			}
		}
		return false
		
	case King:
		rowDiff := abs(piece.Position.Row - target.Row)
		colDiff := abs(piece.Position.Col - target.Col)
		return rowDiff <= 1 && colDiff <= 1
		
	default:
		// For sliding pieces, check if path is clear
		// This is simplified - full implementation would check each square
		return mg.canPieceReachOnBoard(board, piece, target)
	}
}

// isKingAdjacentToSquare checks if opponent king is adjacent to given square
func (mg *MoveGenerator) isKingAdjacentToSquare(pos Position, kingColor Color) bool {
	// Find opponent king
	for row := 0; row < 8; row++ {
		for col := 0; col < 8; col++ {
			piece := mg.board.squares[row][col]
			if piece != nil && piece.Type == King && piece.Color == kingColor {
				// Check if king is adjacent to pos (within 1 square)
				rowDiff := abs(piece.Position.Row - pos.Row)
				colDiff := abs(piece.Position.Col - pos.Col)
				if rowDiff <= 1 && colDiff <= 1 && (rowDiff != 0 || colDiff != 0) {
					return true // Kings would be adjacent
				}
			}
		}
	}
	return false
}

func (mg *MoveGenerator) allowsSelfCheck() bool {
	// Heir mod: allows king to be captured like a regular piece UNTIL:
	// 1. Player promotes a king (no more replacements possible), OR
	// 2. Player has no pawns left (can't get a replacement king)
	if mg.board.Mod == Heir {
		// Check if the current player has promoted a king
		if mg.board.PromotedKings[mg.board.CurrentTurn] > 0 {
			return false // Promoted king → must follow classic check rules
		}
		// Check if player has any pawns left
		if !mg.board.HasPawns(mg.board.CurrentTurn) {
			return false // No pawns → can't get replacement king → must follow classic check rules
		}
		// Has pawns and hasn't promoted → king can be captured freely
		return true
	}
	return false
}

