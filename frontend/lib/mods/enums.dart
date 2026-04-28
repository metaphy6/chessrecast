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
    'Players cannot attack until all pieces are moved. Each piece can only move once. No check allowed during truce. Once broken, normal chess rules apply.',
  ),
  friendlyFire(
    'Friendly Fire',
    'Players can capture their own pieces (except the king and unmoved pieces). You cannot put yourself in check or checkmate.',
  ),
  kingsBattle(
    'Kings\' Battle',
    'Only kings and pawns can move at first. A king capturing a pawn (King\'s Kill) unlocks all pieces AND grants the capturer one bonus move — the only way to earn a bonus move. A pawn promotion also unlocks all pieces but does NOT grant a bonus move. If the position is locked (pawns and kings cannot capture), Phase 2 unlocks automatically after 6 consecutive non-capturing king moves. Pawn captures (without promotion) and quiet pawn pushes do nothing.',
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
