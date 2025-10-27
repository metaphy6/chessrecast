enum GameType {
  classic('Classic Chess', 'Traditional chess with standard rules'),
  royalPawns(
    'Royal Pawns',
    'Pawns can move and capture like kings in all directions',
  ),
  shiftyPawns(
    'Shifty Pawns',
    'Pawns can move like kings but capture like regular pawns',
  ),
  heir(
    'Heir',
    'Kings can be captured when mated. Pawns can promote to King once. Game ends when second King is mated or King is mated with no pawns left.',
  ),
  supremeQueen(
    'Supreme Queen',
    'Pawns cannot promote to Queen. Capturing the opponent\'s Queen wins the game immediately.',
  ),
  snare(
    'Snare',
    'Knight-focused variant: Two knights create "entangle zones" that trap pieces. Last knight becomes revengeful. No promotions if all knights lost.',
  ),
  diamonds(
    'Diamonds',
    'Bishop-focused variant: Bishops move diagonally but capture in a diamond pattern (8 squares around them). Pawns can only promote to Bishops.',
  ),
  teleport(
    'Teleport',
    'Kings and rooks can swap positions when aligned on the same rank or file. Castling is disabled.',
  ),
  friendlyFire(
    'Friendly Fire',
    'Players can capture their own pieces (except the king and unmoved pieces). You cannot put yourself in check or checkmate.',
  ),
  kingsBattle(
    'Kings\' Battle',
    'Phase 1: Only kings and pawns can move. When a king captures a pawn (King\'s Kill), all pieces unlock and the capturer gets a bonus move. Pawn promotion also unlocks all pieces.',
  );

  const GameType(this.displayName, this.description);

  final String displayName;
  final String description;
}
