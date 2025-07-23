enum PieceColor {
  white,
  black;

  PieceColor get opposite {
    switch (this) {
      case PieceColor.white:
        return PieceColor.black;
      case PieceColor.black:
        return PieceColor.white;
    }
  }

  @override
  String toString() {
    switch (this) {
      case PieceColor.white:
        return 'white';
      case PieceColor.black:
        return 'black';
    }
  }
}
