enum ModsEnum {
  classic('Classic Chess', 'Traditional chess with standard rules'),
  mercenary(
    'Mercenary',
    'Pawns move and capture like kings (one square in any direction). Pawns cannot promote. No two-square initial move. No en passant.',
  ),
  heir(
    'Heir',
    'Kings can be captured when checkmated. Pawns can promote to King once. Game ends when second King is checkmated, King is checkmated with no pawns left, or all pawns are captured.',
  ),
  truce(
    'Truce',
    'Players cannot attack until one player moves all pieces. Each piece can only move once during truce. No check or checkmate during truce. Once broken, normal chess rules apply.',
  ),
  friendlyFire(
    'Friendly Fire',
    'Players can capture their own pieces (except the king and unmoved pieces). You cannot put yourself in check or checkmate.',
  ),
  kingsBattle(
    'Kings\' Battle',
    'Only kings and pawns can move until one of kings captures a pawn (King\'s Kill); after that, all pieces unlock and the capturer gets a bonus move. Pawn promotion also unlocks all the other pieces.',
  ),
  saveTheQueen(
    'Save the Queen',
    'Queens start as prisoners on opponent\'s side, moving like kings and unable to capture. Escape to your half to gain full power. Captured escaped queen = instant win!',
  ),
  succession(
    'Succession',
    'Start with two queens each. Race to promote a pawn to King! Lose if a queen is captured or you run out of pawns. Last pawn auto-promotes to King.',
  );

  const ModsEnum(this.displayName, this.description);

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
