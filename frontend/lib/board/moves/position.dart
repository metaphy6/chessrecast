import 'package:equatable/equatable.dart';

class Position extends Equatable {
  final int row;
  final int col;

  const Position(this.row, this.col);

  /// Creates a position from algebraic notation (e.g., "a1", "h8")
  factory Position.fromAlgebraic(String algebraic) {
    if (algebraic.length != 2) {
      throw ArgumentError('Invalid algebraic notation: $algebraic');
    }

    final col = algebraic.codeUnitAt(0) - 'a'.codeUnitAt(0);
    final row = int.parse(algebraic[1]) - 1;

    if (col < 0 || col > 7 || row < 0 || row > 7) {
      throw ArgumentError('Invalid algebraic notation: $algebraic');
    }

    return Position(row, col);
  }

  /// Returns the algebraic notation for this position (e.g., "a1", "h8")
  String get algebraic {
    final colChar = String.fromCharCode('a'.codeUnitAt(0) + col);
    return '$colChar${row + 1}';
  }

  /// Checks if this position is within the chess board bounds
  bool get isValid {
    return row >= 0 && row < 8 && col >= 0 && col < 8;
  }

  /// Returns a new position with the given offset
  Position offset(int rowOffset, int colOffset) {
    return Position(row + rowOffset, col + colOffset);
  }

  /// Calculates the distance between this position and another
  double distanceTo(Position other) {
    final dx = (col - other.col).abs();
    final dy = (row - other.row).abs();
    return (dx * dx + dy * dy).toDouble();
  }

  /// Checks if this position is on the same diagonal as another position
  bool isOnDiagonalWith(Position other) {
    final dx = (col - other.col).abs();
    final dy = (row - other.row).abs();
    return dx == dy && dx != 0;
  }

  /// Checks if this position is on the same rank (row) as another position
  bool isOnSameRankWith(Position other) {
    return row == other.row && col != other.col;
  }

  /// Checks if this position is on the same file (column) as another position
  bool isOnSameFileWith(Position other) {
    return col == other.col && row != other.row;
  }

  @override
  List<Object?> get props => [row, col];

  @override
  String toString() => algebraic;
}
