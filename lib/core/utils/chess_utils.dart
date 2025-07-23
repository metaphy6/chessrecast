import '../../features/chess/domain/enums/piece_type.dart';
import '../../features/chess/domain/enums/piece_color.dart';

class ChessUtils {
  /// Returns the Unicode chess symbol for a piece
  static String getChessSymbol(PieceType type, PieceColor color) {
    return type.getUnicodeSymbol(color == PieceColor.white);
  }

  /// Validates if a position string is in correct algebraic notation
  static bool isValidAlgebraicNotation(String notation) {
    if (notation.length != 2) return false;

    final file = notation[0].toLowerCase();
    final rank = notation[1];

    return file.codeUnitAt(0) >= 'a'.codeUnitAt(0) &&
        file.codeUnitAt(0) <= 'h'.codeUnitAt(0) &&
        rank.codeUnitAt(0) >= '1'.codeUnitAt(0) &&
        rank.codeUnitAt(0) <= '8'.codeUnitAt(0);
  }

  /// Converts row/col indices to algebraic notation
  static String positionToAlgebraic(int row, int col) {
    if (row < 0 || row > 7 || col < 0 || col > 7) {
      throw ArgumentError('Invalid position: row=$row, col=$col');
    }

    final file = String.fromCharCode('a'.codeUnitAt(0) + col);
    final rank = (row + 1).toString();
    return '$file$rank';
  }

  /// Converts algebraic notation to row/col indices
  static (int, int) algebraicToPosition(String algebraic) {
    if (!isValidAlgebraicNotation(algebraic)) {
      throw ArgumentError('Invalid algebraic notation: $algebraic');
    }

    final col = algebraic.codeUnitAt(0) - 'a'.codeUnitAt(0);
    final row = int.parse(algebraic[1]) - 1;

    return (row, col);
  }

  /// Returns true if the square is light colored
  static bool isLightSquare(int row, int col) {
    return (row + col) % 2 == 0;
  }

  /// Returns a description of the piece for accessibility
  static String getPieceDescription(PieceType type, PieceColor color) {
    return '${color.toString()} ${type.toString()}';
  }
}
