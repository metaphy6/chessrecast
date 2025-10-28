enum GameStatus {
  ongoing,
  check,
  checkmate,
  stalemate,
  draw;

  bool get isGameOver {
    return this == checkmate || this == stalemate || this == draw;
  }

  @override
  String toString() {
    switch (this) {
      case GameStatus.ongoing:
        return 'ongoing';
      case GameStatus.check:
        return 'check';
      case GameStatus.checkmate:
        return 'checkmate';
      case GameStatus.stalemate:
        return 'stalemate';
      case GameStatus.draw:
        return 'draw';
    }
  }
}
