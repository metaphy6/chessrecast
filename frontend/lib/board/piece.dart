import 'package:equatable/equatable.dart';
import 'pieces/piece_color.dart';
import 'pieces/piece_type.dart';
import 'moves/position.dart';
import '../mods/mods_enum.dart';

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
  bool canAttack(
    Position target,
    List<ChessPiece> allPieces, [
    dynamic gameType,
    bool kingsKillUnlocked = true,
  ]) {
    if (position == target) return false;

    // KINGS' BATTLE PHASE 1: Only pawns and kings have effect before First Blood
    // Kings and pawns follow classic chess rules between themselves
    if (gameType == ModsEnum.kingsBattle && !kingsKillUnlocked) {
      if (type != PieceType.pawn && type != PieceType.king) {
        return false; // Other pieces are placeholders
      }
    }

    switch (type) {
      case PieceType.pawn:
        return _canPawnAttack(target);
      case PieceType.rook:
        return _canRookAttack(target, allPieces, gameType, kingsKillUnlocked);
      case PieceType.knight:
        return _canKnightAttack(target);
      case PieceType.bishop:
        return _canBishopAttack(target, allPieces, gameType, kingsKillUnlocked);
      case PieceType.queen:
        return _canQueenAttack(target, allPieces, gameType, kingsKillUnlocked);
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

  bool _canRookAttack(
    Position target,
    List<ChessPiece> allPieces, [
    dynamic gameType,
    bool kingsKillUnlocked = true,
  ]) {
    if (!position.isOnSameRankWith(target) &&
        !position.isOnSameFileWith(target)) {
      return false;
    }
    return !_isPathBlocked(target, allPieces, gameType, kingsKillUnlocked);
  }

  bool _canKnightAttack(Position target) {
    final dx = (target.col - position.col).abs();
    final dy = (target.row - position.row).abs();
    return (dx == 2 && dy == 1) || (dx == 1 && dy == 2);
  }

  bool _canBishopAttack(
    Position target,
    List<ChessPiece> allPieces, [
    dynamic gameType,
    bool kingsKillUnlocked = true,
  ]) {
    if (!position.isOnDiagonalWith(target)) return false;
    return !_isPathBlocked(target, allPieces, gameType, kingsKillUnlocked);
  }

  bool _canQueenAttack(
    Position target,
    List<ChessPiece> allPieces, [
    dynamic gameType,
    bool kingsKillUnlocked = true,
  ]) {
    return _canRookAttack(target, allPieces, gameType, kingsKillUnlocked) ||
        _canBishopAttack(target, allPieces, gameType, kingsKillUnlocked);
  }

  bool _canKingAttack(Position target) {
    final dx = (target.col - position.col).abs();
    final dy = (target.row - position.row).abs();
    return dx <= 1 && dy <= 1 && (dx != 0 || dy != 0);
  }

  bool _isPathBlocked(
    Position target,
    List<ChessPiece> allPieces, [
    dynamic gameType,
    bool kingsKillUnlocked = true,
  ]) {
    final dx = target.col - position.col;
    final dy = target.row - position.row;
    final distance = dx.abs() > dy.abs() ? dx.abs() : dy.abs();

    final stepX = dx == 0 ? 0 : dx ~/ dx.abs();
    final stepY = dy == 0 ? 0 : dy ~/ dy.abs();

    final isKingsBattlePhase1 =
        gameType == ModsEnum.kingsBattle && !kingsKillUnlocked;

    for (int i = 1; i < distance; i++) {
      final checkPos = Position(
        position.row + stepY * i,
        position.col + stepX * i,
      );

      ChessPiece? blockingPiece;
      for (final piece in allPieces) {
        if (piece.position == checkPos) {
          blockingPiece = piece;
          break;
        }
      }

      if (blockingPiece != null) {
        // KINGS' BATTLE PHASE 1: Only pawns and kings block paths (they have effect)
        // Other pieces are placeholders with no effect
        if (isKingsBattlePhase1 &&
            blockingPiece.type != PieceType.pawn &&
            blockingPiece.type != PieceType.king) {
          continue; // Ignore other pieces - they have no effect
        }
        return true; // Path is blocked
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
