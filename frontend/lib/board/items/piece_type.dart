enum PieceType {
  pawn,
  rook,
  knight,
  bishop,
  queen,
  king;

  @override
  String toString() {
    switch (this) {
      case PieceType.pawn:
        return 'pawn';
      case PieceType.rook:
        return 'rook';
      case PieceType.knight:
        return 'knight';
      case PieceType.bishop:
        return 'bishop';
      case PieceType.queen:
        return 'queen';
      case PieceType.king:
        return 'king';
    }
  }

  /// Returns the symbol representation of the piece for FEN notation
  String get symbol {
    switch (this) {
      case PieceType.pawn:
        return 'p';
      case PieceType.rook:
        return 'r';
      case PieceType.knight:
        return 'n';
      case PieceType.bishop:
        return 'b';
      case PieceType.queen:
        return 'q';
      case PieceType.king:
        return 'k';
    }
  }
}
