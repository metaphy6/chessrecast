package engine

import (
	"errors"
	"fmt"
)

// Board represents the chess board with all pieces and game state
type Board struct {
	// 8x8 grid of pieces (nil for empty squares)
	squares [8][8]*Piece

	// Game configuration
	Mode        GameMode
	CurrentTurn Color

	// State tracking
	History       MoveHistory
	EnPassantSquare *Position // Valid en passant target
	MoveCount     int         // Total moves (half-moves)
	FiftyMoveRule int         // Moves since last capture or pawn move

	// Castling rights
	WhiteCanCastleKingside  bool
	WhiteCanCastleQueenside bool
	BlackCanCastleKingside  bool
	BlackCanCastleQueenside bool

	// Mode-specific state
	TruceActive      bool              // For Truce mode
	PieceMoveCounter map[Position]int  // For Truce mode
	KingsKillUnlock  bool              // For Kings' Battle mode
	EscapedQueens    map[Color]bool    // For Save the Queen mode
	PromotedKings    map[Color]int     // For Save the King mode
}

// NewBoard creates a standard starting position
func NewBoard(mode GameMode) *Board {
	b := &Board{
		Mode:                    mode,
		CurrentTurn:             White,
		WhiteCanCastleKingside:  true,
		WhiteCanCastleQueenside: true,
		BlackCanCastleKingside:  true,
		BlackCanCastleQueenside: true,
		PieceMoveCounter:        make(map[Position]int),
		EscapedQueens:           make(map[Color]bool),
		PromotedKings:           make(map[Color]int),
		TruceActive:             mode == Truce,
	}

	b.setupStandardPosition()
	return b
}

// NewBoardFromFEN creates a board from FEN notation
func NewBoardFromFEN(fen string, mode GameMode) (*Board, error) {
	// TODO: Implement full FEN parsing
	b := NewBoard(mode)
	// Parse FEN string and setup board
	return b, nil
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

	// Mode-specific setup
	switch b.Mode {
	case SaveTheQueen:
		b.setupSaveTheQueen()
	case SaveTheKing:
		b.setupSaveTheKing()
	}
}

// setupSaveTheQueen - Queens start as prisoners on opponent's side
func (b *Board) setupSaveTheQueen() {
	// Move white queen to black's side (imprisoned)
	whiteQueen := b.GetPieceAt(Position{Row: 0, Col: 3})
	if whiteQueen != nil {
		b.squares[0][3] = nil
		whiteQueen.Position = Position{Row: 7, Col: 3}
		b.setPiece(whiteQueen)
	}

	// Move black queen to white's side (imprisoned)
	blackQueen := b.GetPieceAt(Position{Row: 7, Col: 3})
	if blackQueen != nil {
		b.squares[7][3] = nil
		blackQueen.Position = Position{Row: 0, Col: 4}
		b.setPiece(blackQueen)
	}
}

// setupSaveTheKing - Start with two queens, no kings initially
func (b *Board) setupSaveTheKing() {
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
		b.removePiece(move.To)
		b.FiftyMoveRule = 0
	}

	// Handle special moves
	if move.IsCastling {
		b.executeCastling(move)
	} else if move.IsEnPassant {
		b.executeEnPassant(move)
	} else if move.IsTeleport {
		b.executeTeleport(move)
	}

	// Move piece to destination
	piece.Position = move.To
	piece.HasMoved = true
	b.setPiece(piece)

	// Handle pawn promotion
	if move.IsPromotion {
		piece.Type = move.Promotion
	}

	// Update state
	b.EnPassantSquare = nil
	if piece.Type == Pawn {
		b.FiftyMoveRule = 0
		// Check for en passant opportunity
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
	b.updateCastlingRights(piece, move)

	// Add to history
	move.MoveNumber = b.MoveCount
	b.History.Add(move)
	b.MoveCount++

	// Switch turn
	b.CurrentTurn = b.CurrentTurn.Opposite()

	return nil
}

// executeCastling handles castling move
func (b *Board) executeCastling(move Move) {
	// Move the rook
	if move.To.Col == 6 { // Kingside
		rookFrom := Position{Row: move.From.Row, Col: 7}
		rookTo := Position{Row: move.From.Row, Col: 5}
		rook := b.GetPieceAt(rookFrom)
		b.removePiece(rookFrom)
		rook.Position = rookTo
		rook.HasMoved = true
		b.setPiece(rook)
	} else if move.To.Col == 2 { // Queenside
		rookFrom := Position{Row: move.From.Row, Col: 0}
		rookTo := Position{Row: move.From.Row, Col: 3}
		rook := b.GetPieceAt(rookFrom)
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

// executeTeleport handles king-rook teleportation in Teleport mode
func (b *Board) executeTeleport(move Move) {
	// Swap king and rook positions
	rook := b.GetPieceAt(move.To)
	if rook != nil {
		b.removePiece(move.To)
		rook.Position = move.From
		b.setPiece(rook)
	}
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
		Mode:                    b.Mode,
		CurrentTurn:             b.CurrentTurn,
		MoveCount:               b.MoveCount,
		FiftyMoveRule:           b.FiftyMoveRule,
		WhiteCanCastleKingside:  b.WhiteCanCastleKingside,
		WhiteCanCastleQueenside: b.WhiteCanCastleQueenside,
		BlackCanCastleKingside:  b.BlackCanCastleKingside,
		BlackCanCastleQueenside: b.BlackCanCastleQueenside,
		TruceActive:             b.TruceActive,
		KingsKillUnlock:         b.KingsKillUnlock,
		PieceMoveCounter:        make(map[Position]int),
		EscapedQueens:           make(map[Color]bool),
		PromotedKings:           make(map[Color]int),
	}

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

// Helper function
func abs(x int) int {
	if x < 0 {
		return -x
	}
	return x
}
