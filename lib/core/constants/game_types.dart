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
  );

  const GameType(this.displayName, this.description);

  final String displayName;
  final String description;
}
