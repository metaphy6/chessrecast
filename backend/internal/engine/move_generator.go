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
		// Special handling for Other Side mode
		if mg.board.Mode == OtherSide {
			moves = mg.getOtherSideRookMoves(piece)
		} else {
			moves = mg.getRookMoves(piece)
		}
	case Knight:
		moves = mg.getKnightMoves(piece)
	case Bishop:
		moves = mg.getBishopMoves(piece)
	case Queen:
		moves = mg.getQueenMoves(piece)
	case King:
		moves = mg.getKingMoves(piece)
	}

	// Apply game mode specific rules
	moves = mg.applyGameModeRules(moves, piece)

	// Filter moves that would leave king in check (unless game mode allows it)
	if !mg.allowsSelfCheck() {
		moves = mg.filterCheckMoves(moves)
	} else if mg.board.Mode == Snare && piece.Type == King {
		// In Snare mode: king cannot move into squares under attack
		// even though "check" doesn't exist in the traditional sense
		moves = mg.filterKingMovesSelfCheck(moves, piece)
	}

	return moves
}

// getPawnMoves generates pawn moves
func (mg *MoveGenerator) getPawnMoves(pawn *Piece) []Move {
	// Special handling for Royal Pawns mode
	if mg.board.Mode == RoyalPawns {
		return mg.getRoyalPawnMoves(pawn)
	}

	// Special handling for Other Side mode
	if mg.board.Mode == OtherSide {
		return mg.getOtherSidePawnMoves(pawn)
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

// getRoyalPawnMoves - Pawns move like kings in Royal Pawns mode
func (mg *MoveGenerator) getRoyalPawnMoves(pawn *Piece) []Move {
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
			// Empty square - can move (no promotion in Royal Pawns)
			moves = append(moves, *NewMove(pawn.Position, newPos, pawn))
		} else if targetPiece.Color != pawn.Color {
			// Enemy piece - can capture (but not king unless Heir mode)
			if targetPiece.Type == King && mg.board.Mode != Heir {
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

// getOtherSidePawnMoves - Special pawn rules for Other Side mode
// Pawns move normally (forward only), but cannot promote to rooks
func (mg *MoveGenerator) getOtherSidePawnMoves(pawn *Piece) []Move {
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
			// Promotion - but NO ROOK allowed in Other Side mode
			for _, promoPiece := range []PieceType{Queen, Bishop, Knight} {
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
				// Capture with promotion - NO ROOK allowed
				for _, promoPiece := range []PieceType{Queen, Bishop, Knight} {
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

// getOtherSideRookMoves - Rooks can only capture opponent rooks in Other Side mode
func (mg *MoveGenerator) getOtherSideRookMoves(rook *Piece) []Move {
	allMoves := mg.getSlidingMoves(rook, [][2]int{{-1, 0}, {1, 0}, {0, -1}, {0, 1}})
	
	// Filter: rooks can only capture opponent rooks (not other pieces)
	filteredMoves := []Move{}
	for _, move := range allMoves {
		if move.CapturedPiece == nil {
			// Can move to empty squares
			filteredMoves = append(filteredMoves, move)
		} else if move.CapturedPiece.Type == Rook && move.CapturedPiece.Color != rook.Color {
			// Can only capture opponent rooks (defensive: verify color even though getSlidingMoves ensures it)
			filteredMoves = append(filteredMoves, move)
		}
		// Skip captures of non-rook pieces
	}
	
	return filteredMoves
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
	// Special handling for Diamonds mode
	if mg.board.Mode == Diamonds {
		return mg.getDiamondBishopMoves(bishop)
	}
	return mg.getSlidingMoves(bishop, [][2]int{{-1, -1}, {-1, 1}, {1, -1}, {1, 1}})
}

// getDiamondBishopMoves - Bishops capture in diamond pattern in Diamonds mode
func (mg *MoveGenerator) getDiamondBishopMoves(bishop *Piece) []Move {
	// Move diagonally but capture in 8 squares around
	moves := mg.getSlidingMoves(bishop, [][2]int{{-1, -1}, {-1, 1}, {1, -1}, {1, 1}})
	
	// Add diamond capture pattern
	diamondOffsets := [][2]int{
		{-1, -1}, {-1, 0}, {-1, 1},
		{0, -1}, {0, 1},
		{1, -1}, {1, 0}, {1, 1},
	}

	for _, offset := range diamondOffsets {
		capturePos := bishop.Position.Offset(offset[0], offset[1])
		if !capturePos.IsValid() {
			continue
		}

		targetPiece := mg.board.GetPieceAt(capturePos)
		if targetPiece != nil && targetPiece.Color != bishop.Color {
			move := NewMove(bishop.Position, capturePos, bishop)
			move.CapturedPiece = targetPiece
			// Check if this move isn't already in moves
			found := false
			for _, m := range moves {
				if m.To.Equals(capturePos) {
					found = true
					break
				}
			}
			if !found {
				moves = append(moves, *move)
			}
		}
	}

	return moves
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
		if targetPiece == nil {
			moves = append(moves, *NewMove(king.Position, newPos, king))
		} else if targetPiece.Color != king.Color {
			// Can't capture king unless in Heir mode
			if targetPiece.Type == King && mg.board.Mode != Heir {
				continue
			}
			move := NewMove(king.Position, newPos, king)
			move.CapturedPiece = targetPiece
			moves = append(moves, *move)
		}
	}

	// Castling (not in Teleport mode)
	if mg.board.Mode != Teleport && !king.HasMoved {
		moves = append(moves, mg.getCastlingMoves(king)...)
	}

	// Teleport moves (Teleport mode only)
	if mg.board.Mode == Teleport {
		moves = append(moves, mg.getTeleportMoves(king)...)
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

// getTeleportMoves generates king-rook teleport moves for Teleport mode
func (mg *MoveGenerator) getTeleportMoves(king *Piece) []Move {
	moves := []Move{}
	
	// Find all rooks of the same color aligned horizontally or vertically
	for row := 0; row < 8; row++ {
		for col := 0; col < 8; col++ {
			piece := mg.board.GetPieceAt(Position{Row: row, Col: col})
			if piece == nil || piece.Type != Rook || piece.Color != king.Color {
				continue
			}

			// Check if aligned
			aligned := (piece.Position.Row == king.Position.Row) ||
				(piece.Position.Col == king.Position.Col)

			if aligned {
				// Can swap positions (king moves to rook's square)
				move := NewMove(king.Position, piece.Position, king)
				move.IsTeleport = true
				moves = append(moves, *move)
			}
		}
	}

	return moves
}

// getPromotionPieces returns available promotion pieces for a color
func (mg *MoveGenerator) getPromotionPieces(color Color) []PieceType {
	switch mg.board.Mode {
	case Diamonds:
		return []PieceType{Bishop} // Only bishop promotion
	case SaveTheKing:
		// Check if can promote to king
		if mg.board.PromotedKings[color] == 0 {
			return []PieceType{King, Queen, Rook, Bishop, Knight}
		}
		return []PieceType{Queen, Rook, Bishop, Knight}
	case Heir:
		// In Heir mode, can always promote to King (only once though)
		// No check restriction since king is a regular piece
		if mg.board.PromotedKings[color] == 0 {
			return []PieceType{Queen, Rook, Bishop, Knight, King}
		}
		return []PieceType{Queen, Rook, Bishop, Knight}
	case Snare:
		// Snare mode knight-based promotion rules
		knightCount := mg.board.CountKnights(color)
		switch knightCount {
	case 0:
			// No knights = no promotion at all
			return []PieceType{}
		case 1:
			// One knight = can only promote to knight (to get back to 2)
			return []PieceType{Knight}
		default:
			// Two knights = Q, R, B only (no knight, max 2 knights per game)
			return []PieceType{Queen, Rook, Bishop}
		}
	default:
		return []PieceType{Queen, Rook, Bishop, Knight}
	}
}

// applyGameModeRules applies game-specific movement rules
func (mg *MoveGenerator) applyGameModeRules(moves []Move, piece *Piece) []Move {
	switch mg.board.Mode {
	case FriendlyFire:
		return mg.applyFriendlyFireRules(moves, piece)
	case KingsBattle:
		return mg.applyKingsBattleRules(moves, piece)
	case Truce:
		return mg.applyTruceRules(moves, piece)
	case Snare:
		return mg.applySnareRules(moves, piece)
	case SaveTheQueen:
		return mg.applySaveTheQueenRules(moves, piece)
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
		return moves // All pieces unlocked
	}

	// Only kings and pawns can move
	if piece.Type != King && piece.Type != Pawn {
		return []Move{}
	}

	return moves
}

// applyTruceRules enforces truce period rules
func (mg *MoveGenerator) applyTruceRules(moves []Move, piece *Piece) []Move {
	if !mg.board.TruceActive {
		return moves // Truce broken, normal rules
	}

	// Check if piece has moved 3 times
	if mg.board.PieceMoveCounter[piece.Position] >= 3 {
		return []Move{} // Can't move anymore during truce
	}

	// Filter out captures during truce
	nonCaptureMoves := []Move{}
	for _, move := range moves {
		if move.CapturedPiece == nil {
			nonCaptureMoves = append(nonCaptureMoves, move)
		}
	}

	return nonCaptureMoves
}

// applySnareRules handles knight entanglement zones
func (mg *MoveGenerator) applySnareRules(moves []Move, piece *Piece) []Move {
	// Check if piece is entangled
	if mg.isPieceEntangled(piece) {
		return mg.getEntangledPieceMoves(piece)
	}

	// King cannot voluntarily move into ANY entangle zone
	if piece.Type == King {
		filteredMoves := []Move{}
		for _, move := range moves {
			if !mg.isInAnyEntangleZone(move.To) {
				filteredMoves = append(filteredMoves, move)
			}
		}
		return filteredMoves
	}

	// Filter out moves INTO or THROUGH entangle zones (except from adjacent)
	filteredMoves := []Move{}
	for _, move := range moves {
		blocked := false
		
		// Check all entangle zones
		for _, color := range []Color{White, Black} {
			zone := mg.getEntangleZone(color)
			if len(zone) == 0 {
				continue
			}

			// Check if destination is in zone
			inZone := false
			for _, zonePos := range zone {
				if move.To.Equals(zonePos) {
					inZone = true
					break
				}
			}

			if inZone {
				// Check if move is from adjacent square or already in zone
				rowDiff := abs(move.To.Row - move.From.Row)
				colDiff := abs(move.To.Col - move.From.Col)
				isAdjacent := rowDiff <= 1 && colDiff <= 1

				alreadyInZone := false
				for _, zonePos := range zone {
					if move.From.Equals(zonePos) {
						alreadyInZone = true
						break
					}
				}

				if !isAdjacent && !alreadyInZone {
					blocked = true
					break
				}
			}

			// Check if move passes through zone
			if mg.movePassesThroughZone(move.From, move.To, zone) {
				blocked = true
				break
			}
		}

		if !blocked {
			filteredMoves = append(filteredMoves, move)
		}
	}

	return filteredMoves
}

// getKnights returns all knights of the specified color
func (mg *MoveGenerator) getKnights(color Color) []*Piece {
	knights := []*Piece{}
	for row := 0; row < 8; row++ {
		for col := 0; col < 8; col++ {
			piece := mg.board.GetPieceAt(Position{Row: row, Col: col})
			if piece != nil && piece.Type == Knight && piece.Color == color {
				knights = append(knights, piece)
			}
		}
	}
	return knights
}

// areKnightsDefending checks if two knights defend each other
func (mg *MoveGenerator) areKnightsDefending(k1, k2 *Piece) bool {
	// Knight moves in L-shape
	offsets := [][2]int{
		{-2, -1}, {-2, 1}, {-1, -2}, {-1, 2},
		{1, -2}, {1, 2}, {2, -1}, {2, 1},
	}
	
	// Check if k1 can attack k2's position
	k1CanAttackK2 := false
	for _, offset := range offsets {
		if k1.Position.Offset(offset[0], offset[1]).Equals(k2.Position) {
			k1CanAttackK2 = true
			break
		}
	}
	
	if !k1CanAttackK2 {
		return false
	}

	// Check if k2 can attack k1's position
	for _, offset := range offsets {
		if k2.Position.Offset(offset[0], offset[1]).Equals(k1.Position) {
			return true
		}
	}
	
	return false
}

// getEntangleZone returns the entangle zone positions for a color's knights
func (mg *MoveGenerator) getEntangleZone(color Color) []Position {
	knights := mg.getKnights(color)
	if len(knights) != 2 {
		return []Position{}
	}

	if !mg.areKnightsDefending(knights[0], knights[1]) {
		return []Position{}
	}

	// Calculate the zone between the knights
	k1 := knights[0].Position
	k2 := knights[1].Position
	
	rowDiff := abs(k1.Row - k2.Row)
	colDiff := abs(k1.Col - k2.Col)

	zone := []Position{}

	// For a knight move, one diff is 1 and the other is 2
	if rowDiff == 1 && colDiff == 2 {
		// Horizontal corridor (2 column difference, 1 row difference)
		minCol := k1.Col
		if k2.Col < minCol {
			minCol = k2.Col
		}
		middleCol := minCol + 1

		zone = append(zone, Position{Row: k1.Row, Col: middleCol})
		zone = append(zone, Position{Row: k2.Row, Col: middleCol})
	} else if rowDiff == 2 && colDiff == 1 {
		// Vertical corridor (2 row difference, 1 column difference)
		minRow := k1.Row
		if k2.Row < minRow {
			minRow = k2.Row
		}
		middleRow := minRow + 1

		zone = append(zone, Position{Row: middleRow, Col: k1.Col})
		zone = append(zone, Position{Row: middleRow, Col: k2.Col})
	}

	return zone
}

// isPieceEntangled checks if a piece is in an entangle zone
func (mg *MoveGenerator) isPieceEntangled(piece *Piece) bool {
	for _, color := range []Color{White, Black} {
		zone := mg.getEntangleZone(color)
		for _, zonePos := range zone {
			if piece.Position.Equals(zonePos) {
				return true
			}
		}
	}
	return false
}

// isInAnyEntangleZone checks if a position is in any entangle zone
func (mg *MoveGenerator) isInAnyEntangleZone(pos Position) bool {
	for _, color := range []Color{White, Black} {
		zone := mg.getEntangleZone(color)
		for _, zonePos := range zone {
			if pos.Equals(zonePos) {
				return true
			}
		}
	}
	return false
}

// getEntangledPieceMoves returns valid moves for an entangled piece
func (mg *MoveGenerator) getEntangledPieceMoves(piece *Piece) []Move {
	moves := []Move{}
	
	// Find which zone this piece is in
	var zone []Position
	for _, color := range []Color{White, Black} {
		z := mg.getEntangleZone(color)
		for _, zonePos := range z {
			if piece.Position.Equals(zonePos) {
				zone = z
				break
			}
		}
		if len(zone) > 0 {
			break
		}
	}

	if len(zone) == 0 {
		return moves
	}

	// Count entangled pieces in zone
	entangledCount := 0
	for _, zonePos := range zone {
		if mg.board.GetPieceAt(zonePos) != nil {
			entangledCount++
		}
	}

	// If only 1 piece entangled, it can move within the zone
	if entangledCount == 1 {
		for _, zonePos := range zone {
			if !piece.Position.Equals(zonePos) && mg.board.GetPieceAt(zonePos) == nil {
				moves = append(moves, Move{
					From:  piece.Position,
					To:    zonePos,
					Piece: piece,
				})
			}
		}
	}

	// All entangled pieces can escape via king-like moves
	offsets := [][2]int{
		{-1, -1}, {-1, 0}, {-1, 1},
		{0, -1}, {0, 1},
		{1, -1}, {1, 0}, {1, 1},
	}

	for _, offset := range offsets {
		newPos := piece.Position.Offset(offset[0], offset[1])
		if !newPos.IsValid() {
			continue
		}

		// Can't escape to a position still in the zone
		inZone := false
		for _, zonePos := range zone {
			if newPos.Equals(zonePos) {
				inZone = true
				break
			}
		}
		if inZone {
			continue
		}

		targetPiece := mg.board.GetPieceAt(newPos)
		if targetPiece == nil {
			moves = append(moves, Move{
				From:  piece.Position,
				To:    newPos,
				Piece: piece,
			})
		} else if targetPiece.Color != piece.Color {
			moves = append(moves, Move{
				From:          piece.Position,
				To:            newPos,
				Piece:         piece,
				CapturedPiece: targetPiece,
			})
		}
	}

	return moves
}

// movePassesThroughZone checks if a move passes through an entangle zone
func (mg *MoveGenerator) movePassesThroughZone(from, to Position, zone []Position) bool {
	path := mg.getPathBetween(from, to)
	for _, pathPos := range path {
		if pathPos.Equals(from) {
			continue
		}
		for _, zonePos := range zone {
			if pathPos.Equals(zonePos) {
				return true
			}
		}
	}
	return false
}

// getPathBetween returns all positions along a straight line path
func (mg *MoveGenerator) getPathBetween(from, to Position) []Position {
	path := []Position{}
	
	dr := to.Row - from.Row
	dc := to.Col - from.Col
	
	// Determine step direction
	rowStep := 0
	if dr != 0 {
		rowStep = dr / abs(dr)
	}
	colStep := 0
	if dc != 0 {
		colStep = dc / abs(dc)
	}
	
	// Not a straight line
	if rowStep == 0 && colStep == 0 {
		return path
	}
	if rowStep != 0 && colStep != 0 && abs(dr) != abs(dc) {
		return path
	}
	
	currentRow := from.Row
	currentCol := from.Col
	
	for currentRow != to.Row || currentCol != to.Col {
		path = append(path, Position{Row: currentRow, Col: currentCol})
		currentRow += rowStep
		currentCol += colStep
	}
	path = append(path, to)
	
	return path
}

// applySaveTheQueenRules handles imprisoned queen movement
func (mg *MoveGenerator) applySaveTheQueenRules(moves []Move, piece *Piece) []Move {
	if piece.Type != Queen {
		return moves
	}

	// Check if queen has escaped
	escaped := mg.board.EscapedQueens[piece.Color]
	if escaped {
		return moves // Full queen power
	}

	// Queen is imprisoned - moves like king only
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

// Helper methods

func (mg *MoveGenerator) canPieceReach(piece *Piece, target Position) bool {
	return mg.canPieceReachOnBoard(mg.board, piece, target)
}

// canPieceReachOnBoard checks if a sliding piece can reach target on the specified board
func (mg *MoveGenerator) canPieceReachOnBoard(board *Board, piece *Piece, target Position) bool {
	// For sliding pieces, check if path is clear and direction is valid
	dr := target.Row - piece.Position.Row
	dc := target.Col - piece.Position.Col
	
	switch piece.Type {
	case Pawn:
		return false // Handled separately
	case Knight:
		return false // Handled separately
	case King:
		return false // Handled separately
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
		if board.GetPieceAt(Position{Row: row, Col: col}) != nil {
			return false
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
		testBoard.MakeMove(move)
		
		// Check if own king is in check
		if !mg.isKingInCheck(testBoard, move.Piece.Color) {
			validMoves = append(validMoves, move)
		}
	}

	return validMoves
}

// filterKingMovesSelfCheck filters king moves to prevent moving into attacked squares
// Used in Snare mode where traditional "check" doesn't apply but king still can't move to attacked squares
func (mg *MoveGenerator) filterKingMovesSelfCheck(moves []Move, king *Piece) []Move {
	validMoves := []Move{}
	
	for _, move := range moves {
		// Check if destination square is attacked by enemy
		if !mg.isSquareAttacked(move.To, king.Color.Opposite()) {
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
		return false // No king (possible in some game modes)
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
	// Check if any enemy piece can attack this square
	for row := 0; row < 8; row++ {
		for col := 0; col < 8; col++ {
			piece := board.GetPieceAt(Position{Row: row, Col: col})
			if piece == nil || piece.Color != byColor {
				continue
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
	// OTHER SIDE MODE: Rooks can ONLY attack/capture opponent rooks, not the king or other pieces
	// This means rooks should NEVER put the king in check in this mode
	if board.Mode == OtherSide && piece.Type == Rook {
		// Check what piece is at the target position
		targetPiece := board.GetPieceAt(target)
		if targetPiece == nil {
			// Can move to empty squares but not "attack" them for check purposes
			return false
		}
		// Can only attack opponent rooks - not king, not other pieces
		return targetPiece.Type == Rook && targetPiece.Color != piece.Color
	}

	// Simplified attack check without generating full moves
	switch piece.Type {
	case Pawn:
		// In Royal Pawns mode, pawns attack like kings (all 8 directions)
		if board.Mode == RoyalPawns {
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

func (mg *MoveGenerator) allowsSelfCheck() bool {
	// Heir mode allows the king to be captured like a regular piece
	// Snare mode uses normal chess rules for check - king cannot move into attacked squares
	return mg.board.Mode == Heir
}
