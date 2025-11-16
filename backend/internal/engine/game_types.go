package engine

// GameMode represents different chess variants
type GameMode int

const (
	Classic GameMode = iota
	RoyalPawns
	OtherSide
	Heir
	Truce
	Snare
	Diamonds
	Teleport
	FriendlyFire
	KingsBattle
	SaveTheQueen
	SaveTheKing
)

func (gm GameMode) String() string {
	names := []string{
		"classic",
		"royal_pawns",
		"other_side",
		"heir",
		"truce",
		"snare",
		"diamonds",
		"teleport",
		"friendly_fire",
		"kings_battle",
		"save_the_queen",
		"save_the_king",
	}
	if int(gm) < len(names) {
		return names[gm]
	}
	return "unknown"
}

// ParseGameMode converts string to GameMode
func ParseGameMode(s string) GameMode {
	modes := map[string]GameMode{
		"classic":         Classic,
		"royal_pawns":     RoyalPawns,
		"other_side":      OtherSide,
		"heir":            Heir,
		"truce":           Truce,
		"snare":           Snare,
		"diamonds":        Diamonds,
		"teleport":        Teleport,
		"friendly_fire":   FriendlyFire,
		"kings_battle":    KingsBattle,
		"save_the_queen":  SaveTheQueen,
		"save_the_king":   SaveTheKing,
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
	IsTeleport     bool      // For Teleport mode
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
		IsTeleport:     m.IsTeleport,
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

// GameState represents the current state of a chess game
type GameState int

const (
	InProgress GameState = iota
	WhiteWins
	BlackWins
	Draw
	Stalemate
	Resigned
	Timeout
	Abandoned
)

func (gs GameState) String() string {
	states := []string{
		"in_progress",
		"white_wins",
		"black_wins",
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
