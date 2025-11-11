import 'package:equatable/equatable.dart';
import '../types/piece_color.dart';
import '../types/piece_type.dart';
import 'position.dart';

class ChessPiece extends Equatable {
  final PieceType type;
  final PieceColor color;
  final Position position;
  final bool hasMoved;

  const ChessPiece({
    required this.type,
    required this.color,
    required this.position,
    this.hasMoved = false,
  });

  /// Creates a copy of this piece with updated properties
  ChessPiece copyWith({
    PieceType? type,
    PieceColor? color,
    Position? position,
    bool? hasMoved,
  }) {
    return ChessPiece(
      type: type ?? this.type,
      color: color ?? this.color,
      position: position ?? this.position,
      hasMoved: hasMoved ?? this.hasMoved,
    );
  }

  /// Creates a piece that has moved to a new position
  ChessPiece movedTo(Position newPosition) {
    return copyWith(position: newPosition, hasMoved: true);
  }

  /// Returns the FEN symbol for this piece
  String get fenSymbol {
    final symbol = type.symbol;
    return color == PieceColor.white ? symbol.toUpperCase() : symbol;
  }

  /// Returns true if this piece is white
  bool get isWhite => color == PieceColor.white;

  /// Returns true if this piece is black
  bool get isBlack => color == PieceColor.black;

  /// Returns true if this piece can potentially attack the given position
  /// This is a basic implementation that will be extended for Chess Recast rules
  bool canAttack(Position target, List<ChessPiece> allPieces) {
    if (position == target) return false;

    switch (type) {
      case PieceType.pawn:
        return _canPawnAttack(target);
      case PieceType.rook:
        return _canRookAttack(target, allPieces);
      case PieceType.knight:
        return _canKnightAttack(target);
      case PieceType.bishop:
        return _canBishopAttack(target, allPieces);
      case PieceType.queen:
        return _canQueenAttack(target, allPieces);
      case PieceType.king:
        return _canKingAttack(target);
    }
  }

  bool _canPawnAttack(Position target) {
    final direction = color == PieceColor.white ? 1 : -1;
    final attackRow = position.row + direction;

    return target.row == attackRow &&
        (target.col == position.col - 1 || target.col == position.col + 1);
  }

  bool _canRookAttack(Position target, List<ChessPiece> allPieces) {
    if (!position.isOnSameRankWith(target) &&
        !position.isOnSameFileWith(target)) {
      return false;
    }
    return !_isPathBlocked(target, allPieces);
  }

  bool _canKnightAttack(Position target) {
    final dx = (target.col - position.col).abs();
    final dy = (target.row - position.row).abs();
    return (dx == 2 && dy == 1) || (dx == 1 && dy == 2);
  }

  bool _canBishopAttack(Position target, List<ChessPiece> allPieces) {
    if (!position.isOnDiagonalWith(target)) return false;
    return !_isPathBlocked(target, allPieces);
  }

  bool _canQueenAttack(Position target, List<ChessPiece> allPieces) {
    return _canRookAttack(target, allPieces) ||
        _canBishopAttack(target, allPieces);
  }

  bool _canKingAttack(Position target) {
    final dx = (target.col - position.col).abs();
    final dy = (target.row - position.row).abs();
    return dx <= 1 && dy <= 1 && (dx != 0 || dy != 0);
  }

  bool _isPathBlocked(Position target, List<ChessPiece> allPieces) {
    final dx = target.col - position.col;
    final dy = target.row - position.row;
    final distance = dx.abs() > dy.abs() ? dx.abs() : dy.abs();

    final stepX = dx == 0 ? 0 : dx ~/ dx.abs();
    final stepY = dy == 0 ? 0 : dy ~/ dy.abs();

    for (int i = 1; i < distance; i++) {
      final checkPos = Position(
        position.row + stepY * i,
        position.col + stepX * i,
      );

      if (allPieces.any((piece) => piece.position == checkPos)) {
        return true;
      }
    }

    return false;
  }

  @override
  List<Object?> get props => [type, color, position, hasMoved];

  @override
  String toString() =>
      '${color.toString().toUpperCase()} ${type.toString().toUpperCase()} at ${position.algebraic}';
}
