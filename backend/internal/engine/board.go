package engine

import (
	"errors"
	"fmt"
	"log"
)

// Board represents the chess board with all pieces and game state
type Board struct {
	// 8x8 grid of pieces (nil for empty squares)
	squares [8][8]*Piece

	// Game configuration
	Mod        GameMod
	CurrentTurn Color

	// State tracking
	History            MoveHistory
	EnPassantSquare    *Position // Valid en passant target
	MoveCount          int       // Total moves (half-moves)
	FiftyMoveRule      int       // Moves since last capture or pawn move
	PositionHistory    []string  // Position keys for threefold repetition detection

	// Castling rights
	WhiteCanCastleKingside  bool
	WhiteCanCastleQueenside bool
	BlackCanCastleKingside  bool
	BlackCanCastleQueenside bool

	// Mod-specific state
	TruceActive              bool              // For Truce mod
	PieceMoveCounter         map[Position]int  // For Truce mod
	OpponentStuckInTruce     bool              // For Truce mod - opponent has no valid moves
	KingsKillUnlock          bool              // For Kings' Battle mode
	EscapedQueens            map[Color]bool    // For Save the Queen mod
	QueenCaptureCounter      map[string]int    // For Save the Queen mod - tracks repeated queen captures
	PromotedKings            map[Color]int     // For Succession mod
}

// NewBoard creates a standard starting position
func NewBoard(mode GameMod) *Board {
	b := &Board{
		Mod:                    mode,
		CurrentTurn:             White,
		WhiteCanCastleKingside:  true,
		WhiteCanCastleQueenside: true,
		BlackCanCastleKingside:  true,
		BlackCanCastleQueenside: true,
		PieceMoveCounter:        make(map[Position]int),
		EscapedQueens:           make(map[Color]bool),
		QueenCaptureCounter:     make(map[string]int),
		PromotedKings:           make(map[Color]int),
		TruceActive:             mode == Truce,
		PositionHistory:         make([]string, 0),
	}

	b.setupStandardPosition()
	
	// Add initial position to history for threefold repetition tracking
	b.PositionHistory = append(b.PositionHistory, b.GetPositionKey())
	
	return b
}

// NewBoardFromFEN creates a board from FEN notation
func NewBoardFromFEN(fen string, mode GameMod) (*Board, error) {
	// TODO: Implement full FEN parsing
	b := NewBoard(mode)
	// Parse FEN string and setup board
	return b, nil
}

// CustomPiece represents a piece for custom board setup
type CustomPiece struct {
	Type     string `json:"type"`     // "pawn", "rook", "knight", "bishop", "queen", "king"
	Color    string `json:"color"`    // "white" or "black"
	Position string `json:"position"` // "e4" algebraic notation
}

// NewBoardWithPieces creates a board with custom piece positions
func NewBoardWithPieces(mode GameMod, pieces []CustomPiece, currentTurn Color) (*Board, error) {
	b := &Board{
		Mod:                    mode,
		CurrentTurn:             currentTurn,
		WhiteCanCastleKingside:  false, // Custom boards disable castling by default
		WhiteCanCastleQueenside: false,
		BlackCanCastleKingside:  false,
		BlackCanCastleQueenside: false,
		PieceMoveCounter:        make(map[Position]int),
		EscapedQueens:           make(map[Color]bool),
		PromotedKings:           make(map[Color]int),
		TruceActive:             mode == Truce,
		PositionHistory:         make([]string, 0),
	}

	// Clear board
	for row := 0; row < 8; row++ {
		for col := 0; col < 8; col++ {
			b.squares[row][col] = nil
		}
	}

	// Place pieces
	for _, cp := range pieces {
		pieceType, valid := parsePieceType(cp.Type)
		if !valid {
			continue // Skip invalid piece types
		}

		color := White
		if cp.Color == "black" {
			color = Black
		}

		pos := ParsePosition(cp.Position)
		if !pos.IsValid() {
			continue // Skip invalid positions
		}

		piece := NewPiece(pieceType, color, pos)
		piece.HasMoved = true // Assume all pieces have moved in custom setups
		b.setPiece(piece)
	}

	// Add initial position to history for threefold repetition tracking
	b.PositionHistory = append(b.PositionHistory, b.GetPositionKey())

	return b, nil
}

// parsePieceType converts string to PieceType
func parsePieceType(s string) (PieceType, bool) {
	switch s {
	case "pawn":
		return Pawn, true
	case "rook":
		return Rook, true
	case "knight":
		return Knight, true
	case "bishop":
		return Bishop, true
	case "queen":
		return Queen, true
	case "king":
		return King, true
	default:
		return Pawn, false // Return false to indicate invalid type
	}
}

// ParsePosition converts algebraic notation to Position
func ParsePosition(s string) Position {
	if len(s) != 2 {
		return Position{Row: -1, Col: -1}
	}
	col := int(s[0] - 'a')
	row := int(s[1] - '1')
	return Position{Row: row, Col: col}
}

// setupStandardPosition sets up the standard chess starting position
func (b *Board) setupStandardPosition() {
	// Clear board
	for row := 0; row < 8; row++ {
		for col := 0; col < 8; col++ {
			b.squares[row][col] = nil
		}
	}

	// Setup pawns
	for col := 0; col < 8; col++ {
		b.setPiece(NewPiece(Pawn, White, Position{Row: 1, Col: col}))
		b.setPiece(NewPiece(Pawn, Black, Position{Row: 6, Col: col}))
	}

	// Setup back ranks
	backRankPieces := []PieceType{Rook, Knight, Bishop, Queen, King, Bishop, Knight, Rook}
	for col, pieceType := range backRankPieces {
		b.setPiece(NewPiece(pieceType, White, Position{Row: 0, Col: col}))
		b.setPiece(NewPiece(pieceType, Black, Position{Row: 7, Col: col}))
	}

	// Mod-specific setup
	switch b.Mod {
	case SaveTheQueen:
		b.setupSaveTheQueen()
	case Succession:
		b.setupSuccession()
	}
}

// setupSaveTheQueen - Queens start as prisoners on opponent's side
func (b *Board) setupSaveTheQueen() {
	// Get both queens before moving them (since they swap positions)
	whiteQueen := b.GetPieceAt(Position{Row: 0, Col: 3})
	blackQueen := b.GetPieceAt(Position{Row: 7, Col: 3})

	fmt.Printf("🔍 DEBUG setupSaveTheQueen: whiteQueen=%v, blackQueen=%v\n", whiteQueen, blackQueen)

	// Clear both positions first
	b.squares[0][3] = nil
	b.squares[7][3] = nil

	// Move white queen to black's side (imprisoned at d8)
	if whiteQueen != nil {
		whiteQueen.Position = Position{Row: 7, Col: 3}
		b.setPiece(whiteQueen)
		fmt.Printf("✅ Moved white queen to d8 (row 7, col 3)\n")
	}

	// Move black queen to white's side (imprisoned at d1)
	if blackQueen != nil {
		blackQueen.Position = Position{Row: 0, Col: 3}
		b.setPiece(blackQueen)
		fmt.Printf("✅ Moved black queen to d1 (row 0, col 3)\n")
	}

	// Initialize both queens as prisoners (not escaped)
	b.EscapedQueens[White] = false
	b.EscapedQueens[Black] = false

	fmt.Printf("🎯 Save the Queen setup complete. FEN: %s\n", b.ToFEN())
}

// setupSuccession - Start with two queens, no kings initially
func (b *Board) setupSuccession() {
	// Remove kings
	b.squares[0][4] = nil
	b.squares[7][4] = nil

	// Add second queen for each side
	b.setPiece(NewPiece(Queen, White, Position{Row: 0, Col: 4}))
	b.setPiece(NewPiece(Queen, Black, Position{Row: 7, Col: 4}))
}

// GetPieceAt returns the piece at a position (nil if empty)
func (b *Board) GetPieceAt(pos Position) *Piece {
	if !pos.IsValid() {
		return nil
	}
	return b.squares[pos.Row][pos.Col]
}

// setPiece places a piece on the board
func (b *Board) setPiece(piece *Piece) {
	if piece == nil || !piece.Position.IsValid() {
		return
	}
	b.squares[piece.Position.Row][piece.Position.Col] = piece
}

// removePiece removes a piece from the board
func (b *Board) removePiece(pos Position) {
	if !pos.IsValid() {
		return
	}
	b.squares[pos.Row][pos.Col] = nil
}

// MakeMove executes a move on the board (assumes move is valid)
func (b *Board) MakeMove(move Move) error {
	piece := b.GetPieceAt(move.From)
	if piece == nil {
		return errors.New("no piece at source position")
	}

	if piece.Color != b.CurrentTurn {
		return errors.New("not your turn")
	}

	// Execute the move
	b.removePiece(move.From)
	
	// Handle capture
	if move.CapturedPiece != nil {
		// Save the Queen mod: If capturing a prisoner queen, return it to prison instead of removing
		if b.Mod == SaveTheQueen && move.CapturedPiece.Type == Queen {
			capturedQueenInOwnHalf := (move.CapturedPiece.Color == White && move.To.Row <= 3) ||
				(move.CapturedPiece.Color == Black && move.To.Row >= 4)
			
			if !capturedQueenInOwnHalf {
				// Queen was a prisoner (in opponent's half), return to prison
				prisonPos := Position{Row: 7, Col: 3} // White queen prison (d8)
				if move.CapturedPiece.Color == Black {
					prisonPos = Position{Row: 0, Col: 3} // Black queen prison (d1)
				}
				
				// Only return to prison if prison square is not occupied
				if b.GetPieceAt(prisonPos) == nil {
					// Track queen capture repetition (capturer queen + captured queen color)
					captureKey := fmt.Sprintf("%s_%d_%d_captures_%s",
						piece.Color.String(),
						move.From.Row, move.From.Col,
						move.CapturedPiece.Color.String())
					b.QueenCaptureCounter[captureKey]++
					
					// IMPORTANT: Clone the captured piece to avoid modifying the original
					returnedQueen := move.CapturedPiece.Clone()
					returnedQueen.Position = prisonPos
					returnedQueen.HasMoved = false
					b.setPiece(returnedQueen)
					b.EscapedQueens[move.CapturedPiece.Color] = false
					// Don't fully remove - just moved back to prison
				} else {
					// Prison occupied, queen is actually captured (removed)
					b.removePiece(move.To)
				}
			} else {
				// Escaped queen captured = game over (but we remove it normally here)
				b.removePiece(move.To)
			}
		} else {
			// Normal capture
			b.removePiece(move.To)
		}
		
		b.FiftyMoveRule = 0
	}

	// Handle special moves
	if move.IsCastling {
		b.executeCastling(move)
	} else if move.IsEnPassant {
		b.executeEnPassant(move)
	}

	// Move piece to destination
	if piece != nil {
		piece.Position = move.To
		piece.HasMoved = true
		b.setPiece(piece)

		// Handle pawn promotion
		if move.IsPromotion {
			piece.Type = move.Promotion
			// Track king promotions for Heir and Succession mods
			if move.Promotion == King {
				b.PromotedKings[piece.Color]++
			}
		}

		// Save the Queen mod: Check if queen has escaped to own half
		if b.Mod == SaveTheQueen && piece.Type == Queen {
			inOwnHalf := (piece.Color == White && piece.Position.Row <= 3) ||
				(piece.Color == Black && piece.Position.Row >= 4)
			b.EscapedQueens[piece.Color] = inOwnHalf
		}
	}

	// Update state
	b.EnPassantSquare = nil
	if piece != nil && piece.Type == Pawn {
		// In Mercenary mode, pawns move like kings and don't reset the counter
		if b.Mod != Mercenary {
			b.FiftyMoveRule = 0
		} else {
			b.FiftyMoveRule++ // Treat pawn moves like regular piece moves in Mercenary
		}
		// Check for en passant opportunity (not applicable in Mercenary mode)
		if abs(move.From.Row-move.To.Row) == 2 {
			b.EnPassantSquare = &Position{
				Row: (move.From.Row + move.To.Row) / 2,
				Col: move.From.Col,
			}
		}
	} else {
		b.FiftyMoveRule++
	}

	// Update castling rights
	if piece != nil {
		b.updateCastlingRights(piece, move)
	}

	// Truce mod: Update piece move counter and check if truce breaks
	if b.Mod == Truce && b.TruceActive && piece != nil {
		// Increment move count for this piece
		b.PieceMoveCounter[move.From]++
		
		// Check if truce should break: the NEXT player to move is exhausted
		// (all their pieces have moved once or are blocked)
		nextColor := piece.Color.Opposite()
		if b.checkTruceBreak(nextColor) {
			b.TruceActive = false
			log.Printf("⚔️ TRUCE BROKEN by %s! %s has no legal truce moves. Combat is now allowed!", piece.Color, nextColor)
		}
	}

	// Add to history
	move.MoveNumber = b.MoveCount
	b.History.Add(move)
	b.MoveCount++

	// Kings' Battle mode: Check for King's Kill (First Blood)
	if b.Mod == KingsBattle && !b.KingsKillUnlock {
		if piece != nil && piece.Type == King && move.CapturedPiece != nil && move.CapturedPiece.Type == Pawn {
			// King captured a pawn - unlock all pieces and grant bonus move
			b.KingsKillUnlock = true
			// Note: First Blood unlocked all pieces and grants bonus move
			// Don't switch turn - grant bonus move to the player who made King's Kill
			return nil
		}
	}

	// Switch turn (unless Kings' Kill bonus move)
	b.CurrentTurn = b.CurrentTurn.Opposite()

	// Add position to history AFTER switching turns so we capture the state with correct next player
	b.PositionHistory = append(b.PositionHistory, b.GetPositionKey())

	return nil
}

// executeCastling handles castling move
func (b *Board) executeCastling(move Move) {
	// Move the rook
	if move.To.Col == 6 { // Kingside
		rookFrom := Position{Row: move.From.Row, Col: 7}
		rookTo := Position{Row: move.From.Row, Col: 5}
		rook := b.GetPieceAt(rookFrom)
		if rook == nil {
			return // Rook not found, skip castling execution
		}
		b.removePiece(rookFrom)
		rook.Position = rookTo
		rook.HasMoved = true
		b.setPiece(rook)
	} else if move.To.Col == 2 { // Queenside
		rookFrom := Position{Row: move.From.Row, Col: 0}
		rookTo := Position{Row: move.From.Row, Col: 3}
		rook := b.GetPieceAt(rookFrom)
		if rook == nil {
			return // Rook not found, skip castling execution
		}
		b.removePiece(rookFrom)
		rook.Position = rookTo
		rook.HasMoved = true
		b.setPiece(rook)
	}
}

// executeEnPassant handles en passant capture
func (b *Board) executeEnPassant(move Move) {
	// Remove the captured pawn
	capturedPawnPos := Position{
		Row: move.From.Row,
		Col: move.To.Col,
	}
	b.removePiece(capturedPawnPos)
}

// updateCastlingRights updates castling availability after a move
func (b *Board) updateCastlingRights(piece *Piece, move Move) {
	// If king moves, lose all castling rights
	if piece.Type == King {
		if piece.Color == White {
			b.WhiteCanCastleKingside = false
			b.WhiteCanCastleQueenside = false
		} else {
			b.BlackCanCastleKingside = false
			b.BlackCanCastleQueenside = false
		}
	}

	// If rook moves or is captured, lose that side's castling
	if piece.Type == Rook || (move.CapturedPiece != nil && move.CapturedPiece.Type == Rook) {
		if move.From.Equals(Position{Row: 0, Col: 0}) {
			b.WhiteCanCastleQueenside = false
		} else if move.From.Equals(Position{Row: 0, Col: 7}) {
			b.WhiteCanCastleKingside = false
		} else if move.From.Equals(Position{Row: 7, Col: 0}) {
			b.BlackCanCastleQueenside = false
		} else if move.From.Equals(Position{Row: 7, Col: 7}) {
			b.BlackCanCastleKingside = false
		}
	}
}

// Clone creates a deep copy of the board
func (b *Board) Clone() *Board {
	clone := &Board{
		Mod:                    b.Mod,
		CurrentTurn:             b.CurrentTurn,
		MoveCount:               b.MoveCount,
		FiftyMoveRule:           b.FiftyMoveRule,
		WhiteCanCastleKingside:  b.WhiteCanCastleKingside,
		WhiteCanCastleQueenside: b.WhiteCanCastleQueenside,
		BlackCanCastleKingside:  b.BlackCanCastleKingside,
		BlackCanCastleQueenside: b.BlackCanCastleQueenside,
		TruceActive:             b.TruceActive,
		OpponentStuckInTruce:    b.OpponentStuckInTruce,
		KingsKillUnlock:         b.KingsKillUnlock,
		PieceMoveCounter:        make(map[Position]int),
		EscapedQueens:           make(map[Color]bool),
		QueenCaptureCounter:     make(map[string]int),
		PromotedKings:           make(map[Color]int),
		PositionHistory:         make([]string, len(b.PositionHistory)),
	}

	// Copy position history
	copy(clone.PositionHistory, b.PositionHistory)

	// Copy pieces
	for row := 0; row < 8; row++ {
		for col := 0; col < 8; col++ {
			if b.squares[row][col] != nil {
				clone.squares[row][col] = b.squares[row][col].Clone()
			}
		}
	}

	// Copy en passant square
	if b.EnPassantSquare != nil {
		square := *b.EnPassantSquare
		clone.EnPassantSquare = &square
	}

	// Copy maps
	for k, v := range b.PieceMoveCounter {
		clone.PieceMoveCounter[k] = v
	}
	for k, v := range b.EscapedQueens {
		clone.EscapedQueens[k] = v
	}
	for k, v := range b.QueenCaptureCounter {
		clone.QueenCaptureCounter[k] = v
	}
	for k, v := range b.PromotedKings {
		clone.PromotedKings[k] = v
	}

	return clone
}

// ToFEN converts board to FEN notation
func (b *Board) ToFEN() string {
	// TODO: Implement full FEN export
	fen := ""
	
	// Board position
	for row := 7; row >= 0; row-- {
		empty := 0
		for col := 0; col < 8; col++ {
			piece := b.squares[row][col]
			if piece == nil {
				empty++
			} else {
				if empty > 0 {
					fen += fmt.Sprintf("%d", empty)
					empty = 0
				}
				fen += string(piece.Type.FENChar(piece.Color))
			}
		}
		if empty > 0 {
			fen += fmt.Sprintf("%d", empty)
		}
		if row > 0 {
			fen += "/"
		}
	}

	// Active color
	fen += " "
	if b.CurrentTurn == White {
		fen += "w"
	} else {
		fen += "b"
	}

	// TODO: Add castling rights, en passant, halfmove clock, fullmove number

	return fen
}

// IsKingInCheck checks if the king of the given color is in check
func (b *Board) IsKingInCheck(color Color) bool {
	// Truce mod: During truce, kings cannot be in check (they move freely)
	if b.Mod == Truce && b.TruceActive {
		return false
	}
	
	mg := NewMoveGenerator(b)
	return mg.isKingInCheck(b, color)
}

// GetPositionKey generates a unique key for the current board position
// Key includes: piece positions, current turn, castling rights, en passant target
func (b *Board) GetPositionKey() string {
	// Piece placement
	pieceKey := ""
	for row := 7; row >= 0; row-- {
		for col := 0; col < 8; col++ {
			piece := b.squares[row][col]
			if piece == nil {
				pieceKey += "-"
			} else {
				pieceKey += string(piece.Type.FENChar(piece.Color))
			}
		}
	}

	// Current turn
	turnKey := fmt.Sprintf("t%c", b.CurrentTurn.String()[0])

	// Castling rights
	castleKey := "c"
	if b.WhiteCanCastleKingside {
		castleKey += "K"
	}
	if b.WhiteCanCastleQueenside {
		castleKey += "Q"
	}
	if b.BlackCanCastleKingside {
		castleKey += "k"
	}
	if b.BlackCanCastleQueenside {
		castleKey += "q"
	}

	// En passant
	epKey := "e-"
	if b.EnPassantSquare != nil {
		epKey = fmt.Sprintf("e%d%d", b.EnPassantSquare.Row, b.EnPassantSquare.Col)
	}

	return pieceKey + "|" + turnKey + "|" + castleKey + "|" + epKey
}

// HasThreefoldRepetition checks if the same position has occurred 3 times
func (b *Board) HasThreefoldRepetition() bool {
	if len(b.PositionHistory) == 0 {
		return false
	}

	currentKey := b.GetPositionKey()
	count := 1 // Start at 1 to count the current position

	// Count occurrences of current position in history
	for _, historyKey := range b.PositionHistory {
		if historyKey == currentKey {
			count++
			if count >= 3 {
				log.Printf("🔄 THREEFOLD REPETITION DETECTED! Position appeared %d times", count)
				log.Printf("🔑 Position key: %s", currentKey)
				return true
			}
		}
	}

	return false
}

// HasKing checks if the given color has a king on the board
func (b *Board) HasKing(color Color) bool {
	for row := 0; row < 8; row++ {
		for col := 0; col < 8; col++ {
			piece := b.squares[row][col]
			if piece != nil && piece.Type == King && piece.Color == color {
				return true
			}
		}
	}
	return false
}

// HasPawns checks if the given color has any pawns on the board
func (b *Board) HasPawns(color Color) bool {
	for row := 0; row < 8; row++ {
		for col := 0; col < 8; col++ {
			piece := b.squares[row][col]
			if piece != nil && piece.Type == Pawn && piece.Color == color {
				return true
			}
		}
	}
	return false
}

// CountKnights returns the number of knights of the specified color
func (b *Board) CountKnights(color Color) int {
	count := 0
	for row := 0; row < 8; row++ {
		for col := 0; col < 8; col++ {
			piece := b.squares[row][col]
			if piece != nil && piece.Type == Knight && piece.Color == color {
				count++
			}
		}
	}
	return count
}

// GetPiecesOfColor returns all pieces of the specified color
func (b *Board) GetPiecesOfColor(color Color) []*Piece {
	pieces := []*Piece{}
	for row := 0; row < 8; row++ {
		for col := 0; col < 8; col++ {
			piece := b.squares[row][col]
			if piece != nil && piece.Color == color {
				pieces = append(pieces, piece)
			}
		}
	}
	return pieces
}

// checkTruceBreak checks if the truce should break for the given color.
// Truce breaks when a player has exhausted all legal truce moves: every piece
// has either moved at least once OR is blocked (no non-capturing move exists).
func (b *Board) checkTruceBreak(color Color) bool {
	movedPositions := make(map[Position]bool)
	for _, move := range b.History.Moves {
		if move.Piece.Color == color {
			movedPositions[move.From] = true
		}
	}

	currentPieces := b.GetPiecesOfColor(color)
	if len(currentPieces) == 0 {
		return false
	}

	exhaustedCount := 0
	for _, piece := range currentPieces {
		hasMoved := false
		if movedPositions[piece.Position] {
			hasMoved = true
		} else {
			for _, move := range b.History.Moves {
				if move.Piece.Color == color && move.To == piece.Position {
					hasMoved = true
					break
				}
			}
		}

		if hasMoved {
			exhaustedCount++
		} else if !b.hasLegalTruceMove(piece) {
			// Unmoved with no legal truce move → counts as exhausted
			exhaustedCount++
		}
	}

	return exhaustedCount >= len(currentPieces)
}

func (b *Board) pieceHasMoved(piece *Piece) bool {
	for _, move := range b.History.Moves {
		if move.Piece.Color != piece.Color {
			continue
		}
		if move.From.Equals(piece.Position) || move.To.Equals(piece.Position) {
			return true
		}
	}
	return false
}

// hasLegalTruceMove returns true if the piece has at least one legal move
// during active truce after applying the one-move rule, no-capture rule,
// and no-check rule.
func (b *Board) hasLegalTruceMove(piece *Piece) bool {
	mg := NewMoveGenerator(b)
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

	moves = mg.applyTruceRules(moves, piece)
	return len(moves) > 0
}

// GetUnmovedPieces returns all pieces that haven't moved yet for a color
func (b *Board) GetUnmovedPieces(color Color) []*Piece {
	unmovedPieces := []*Piece{}
	movedPositions := make(map[Position]bool)
	
	// Track all positions that have moved
	for _, move := range b.History.Moves {
		if move.Piece.Color == color {
			movedPositions[move.From] = true
		}
	}
	
	// Find pieces that haven't moved
	for row := 0; row < 8; row++ {
		for col := 0; col < 8; col++ {
			piece := b.squares[row][col]
			if piece != nil && piece.Color == color {
				// Check if this piece has moved
				if !movedPositions[piece.Position] && !b.pieceHasMoved(piece) {
					unmovedPieces = append(unmovedPieces, piece)
				}
			}
		}
	}
	
	return unmovedPieces
}

// HasMovableUnmovedPieces checks if a player has any unmoved pieces that can move
func (b *Board) HasMovableUnmovedPieces(color Color) bool {
	unmovedPieces := b.GetUnmovedPieces(color)
	if len(unmovedPieces) == 0 {
		return false // No unmoved pieces left
	}
	
	// Check if any unmoved piece has valid moves
	for _, piece := range unmovedPieces {
		if b.hasLegalTruceMove(piece) {
			return true
		}
	}
	
	return false
}

// Helper function for absolute value
func abs(x int) int {
	if x < 0 {
		return -x
	}
	return x
}
