enum ModesEnum {
  classic('Classic Chess', 'Traditional chess with standard rules'),
  royalPawns(
    'Royal Pawns',
    'Pawns can move and capture like kings in all directions',
  ),
  otherSide(
    'Other Side',
    'Race your rook to the opponent\'s back rank! Pawns can move backward. Rooks can only capture rooks. Losing a rook or reaching the back rank wins instantly.',
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
  ),
  saveTheQueen(
    'Save the Queen',
    'Queens start as prisoners on opponent\'s side, moving like kings and unable to capture. Escape to your half to gain full power. Captured escaped queen = instant win!',
  ),
  saveTheKing(
    'Save the King',
    'Start with two queens each. Race to promote a pawn to King! Lose if a queen is captured or you run out of pawns. Last pawn auto-promotes to King.',
  );

  const ModesEnum(this.displayName, this.description);

  final String displayName;
  final String description;
}
