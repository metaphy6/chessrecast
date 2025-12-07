enum ModesEnum {
  classic('Classic Chess', 'Traditional chess with standard rules'),
  royalPawns(
    'Royal Pawns',
    'Pawns move and capture like kings (one square in any direction). Pawns cannot promote. No two-square initial move. No en passant.',
  ),
  otherSide(
    'Other Side',
    'Race your rook to the opponent\'s back rank! Rooks can only capture rooks. Capturing a rook or reaching the back rank wins instantly.',
  ),
  heir(
    'Heir',
    'Kings can be captured when mated. Pawns can promote to King once. Game ends when second King is mated, King is mated with no pawns left, or all pawns are captured.',
  ),
  truce(
    'Truce',
    'Players cannot attack until one player moves all pieces. No piece can move more than 3 times during truce. No check or checkmate during truce. Once broken, normal chess rules apply.',
  ),
  snare(
    'Snare',
    'Knight-focused variant: Two knights create "entangle zone" that trap pieces. King moves freely without being checked as long as at least one knight is in game but it can be captured and the game ends; it becomes classic king where there\'re no knight left in its color. King can be checkmated if opponent catches it in an entangle zone. Last knight becomes revengeful. No promotions if all knights in a color are lost. Focuses on draw oriented game plays',
  ),
  diamonds(
    'Diamonds',
    'Bishop-focused variant: Bishops move diagonally but capture in a diamond pattern (8 squares around them). Pawns can only promote to Bishops.',
  ),
  teleport(
    'Teleport',
    'King and rook can swap positions when aligned horizontally or vertically. Castling is not allowed.',
  ),
  friendlyFire(
    'Friendly Fire',
    'Players can capture their own pieces (except the king and unmoved pieces). You cannot put yourself in check or checkmate.',
  ),
  kingsBattle(
    'Kings\' Battle',
    'Only kings and pawns can move untill one of kings captures a pawn (King\'s Kill); after that, all pieces unlock and the capturer gets a bonus move. Pawn promotion also unlocks all the other pieces.',
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

  /// Convert enum name to snake_case for backend API
  String toSnakeCase() {
    return name
        .replaceAllMapped(
          RegExp(r'[A-Z]'),
          (match) => '_${match.group(0)!.toLowerCase()}',
        )
        .replaceFirst(
          RegExp(r'^_'),
          '',
        ); // Remove leading underscore if present
  }
}
