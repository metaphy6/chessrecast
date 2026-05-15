package engine

// GameMod represents different chess variants
type GameMod int

const (
	Classic      GameMod = 0
	Mercenary    GameMod = 1
	Heir         GameMod = 3
	Truce        GameMod = 4
	FriendlyFire GameMod = 8
	KingsBattle  GameMod = 9
	SaveTheQueen GameMod = 10
	Succession   GameMod = 11
)

func (gm GameMod) String() string {
	switch gm {
	case Classic:
		return "classic"
	case Mercenary:
		return "mercenary"
	case Heir:
		return "heir"
	case Truce:
		return "truce"
	case FriendlyFire:
		return "friendly_fire"
	case KingsBattle:
		return "kings_battle"
	case SaveTheQueen:
		return "save_the_queen"
	case Succession:
		return "succession"
	default:
		return "unknown"
	}
}

// ParseGameMod converts string to GameMod
func ParseGameMod(s string) GameMod {
	modes := map[string]GameMod{
		"classic":        Classic,
		"mercenary":      Mercenary,
		"heir":           Heir,
		"truce":          Truce,
		"friendly_fire":  FriendlyFire,
		"kings_battle":   KingsBattle,
		"save_the_queen": SaveTheQueen,
		"succession":     Succession,
	}
	if mode, ok := modes[s]; ok {
		return mode
	}
	return Classic
}

// Move represents a chess move
type Move struct {
	From           Position
	To             Position
	Piece          *Piece
	CapturedPiece  *Piece
	Promotion      PieceType // Only for pawn promotion
	IsPromotion    bool
	IsCastling     bool
	IsEnPassant    bool
	MoveNumber     int       // Track move sequence
}

// NewMove creates a simple move
func NewMove(from, to Position, piece *Piece) *Move {
	return &Move{
		From:  from,
		To:    to,
		Piece: piece,
	}
}

// Clone creates a deep copy of the move
func (m *Move) Clone() *Move {
	return &Move{
		From:           m.From,
		To:             m.To,
		Piece:          m.Piece.Clone(),
		CapturedPiece:  m.CapturedPiece.Clone(),
		Promotion:      m.Promotion,
		IsPromotion:    m.IsPromotion,
		IsCastling:     m.IsCastling,
		IsEnPassant:    m.IsEnPassant,
		MoveNumber:     m.MoveNumber,
	}
}

// ToAlgebraic returns algebraic notation (e.g., "e2e4" or "e7e8q")
func (m *Move) ToAlgebraic() string {
	notation := m.From.ToAlgebraic() + m.To.ToAlgebraic()
	if m.IsPromotion {
		// Add promotion piece (lowercase)
		notation += string(m.Promotion.FENChar(Black))
	}
	return notation
}

// FormatMove returns a formatted string for logging (e.g., "White ♙ e2 → e4")
func (m *Move) FormatMove() string {
	colorName := "White"
	if m.Piece.Color == Black {
		colorName = "Black"
	}
	
	result := colorName + " " + m.Piece.Unicode() + " " + m.From.ToAlgebraic() + " → " + m.To.ToAlgebraic()
	
	if m.CapturedPiece != nil {
		result += " (captured " + m.CapturedPiece.Unicode() + ")"
	}
	if m.IsEnPassant {
		result += " (en passant)"
	}
	if m.IsCastling {
		result += " (castling)"
	}
	if m.IsPromotion {
		promotedPiece := &Piece{Type: m.Promotion, Color: m.Piece.Color}
		result += " (promoted to " + promotedPiece.Unicode() + ")"
	}
	
	return result
}

// GameState represents the current state of a chess game
type GameState int

const (
	InProgress GameState = iota
	Checkmate
	Draw
	Stalemate
	Resigned
	Timeout
	Abandoned
)

func (gs GameState) String() string {
	states := []string{
		"in_progress",
		"checkmate",
		"draw",
		"stalemate",
		"resigned",
		"timeout",
		"abandoned",
	}
	if int(gs) < len(states) {
		return states[gs]
	}
	return "unknown"
}

// GameResult contains the final result and reason
type GameResult struct {
	State  GameState
	Winner Color // Only relevant if State is WhiteWins or BlackWins
	Reason string
}

// MoveHistory tracks all moves in a game
type MoveHistory struct {
	Moves []Move
}

// Add appends a move to history
func (mh *MoveHistory) Add(move Move) {
	mh.Moves = append(mh.Moves, move)
}

// Last returns the last move (nil if empty)
func (mh *MoveHistory) Last() *Move {
	if len(mh.Moves) == 0 {
		return nil
	}
	return &mh.Moves[len(mh.Moves)-1]
}

// Count returns number of moves
func (mh *MoveHistory) Count() int {
	return len(mh.Moves)
}

// ToPGN converts history to PGN format (simplified)
func (mh *MoveHistory) ToPGN() string {
	// TODO: Implement full PGN export
	pgn := ""
	for i, move := range mh.Moves {
		if i%2 == 0 {
			pgn += " " + move.ToAlgebraic()
		} else {
			pgn += " " + move.ToAlgebraic()
		}
	}
	return pgn
}
