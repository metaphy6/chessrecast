package engine

// Position represents a square on the chess board (0-7 for both row and col)
type Position struct {
	Row int
	Col int
}

// NewPosition creates a position from algebraic notation (e.g., "e4")
func NewPosition(algebraic string) Position {
	if len(algebraic) != 2 {
		return Position{Row: -1, Col: -1}
	}
	col := int(algebraic[0] - 'a')
	row := int(algebraic[1] - '1')
	return Position{Row: row, Col: col}
}

// ToAlgebraic converts position to algebraic notation
func (p Position) ToAlgebraic() string {
	if !p.IsValid() {
		return ""
	}
	return string(rune('a'+p.Col)) + string(rune('1'+p.Row))
}

// IsValid checks if position is within board bounds
func (p Position) IsValid() bool {
	return p.Row >= 0 && p.Row < 8 && p.Col >= 0 && p.Col < 8
}

// Equals checks position equality
func (p Position) Equals(other Position) bool {
	return p.Row == other.Row && p.Col == other.Col
}

// Offset creates a new position by adding offsets
func (p Position) Offset(rowOffset, colOffset int) Position {
	return Position{
		Row: p.Row + rowOffset,
		Col: p.Col + colOffset,
	}
}

// Color represents piece color
type Color int

const (
	White Color = iota
	Black
)

func (c Color) String() string {
	if c == White {
		return "white"
	}
	return "black"
}

// Opposite returns the opposite color
func (c Color) Opposite() Color {
	if c == White {
		return Black
	}
	return White
}

// PieceType represents chess piece types
type PieceType int

const (
	Pawn PieceType = iota
	Rook
	Knight
	Bishop
	Queen
	King
)

func (pt PieceType) String() string {
	names := []string{"pawn", "rook", "knight", "bishop", "queen", "king"}
	return names[pt]
}

// FENChar returns the FEN character for this piece type
func (pt PieceType) FENChar(color Color) rune {
	chars := map[PieceType]rune{
		Pawn:   'p',
		Rook:   'r',
		Knight: 'n',
		Bishop: 'b',
		Queen:  'q',
		King:   'k',
	}
	char := chars[pt]
	if color == White {
		return rune(char - 32) // Uppercase for white
	}
	return char
}

// Piece represents a chess piece
type Piece struct {
	Type     PieceType
	Color    Color
	Position Position
	HasMoved bool // Track if piece has moved (for castling, pawn double-move)
}

// NewPiece creates a new piece
func NewPiece(pieceType PieceType, color Color, pos Position) *Piece {
	return &Piece{
		Type:     pieceType,
		Color:    color,
		Position: pos,
		HasMoved: false,
	}
}

// Clone creates a deep copy of the piece
func (p *Piece) Clone() *Piece {
	if p == nil {
		return nil
	}
	return &Piece{
		Type:     p.Type,
		Color:    p.Color,
		Position: p.Position,
		HasMoved: p.HasMoved,
	}
}

// String returns string representation
func (p *Piece) String() string {
	return p.Color.String() + " " + p.Type.String()
}
