import '../../../board/utils/exporter.dart';

/// Detects tactical patterns (forks, pins, discovered attacks, etc.)
class TacticalPatterns {
  /// Check if a move creates a fork (attacks 2+ valuable pieces)
  static bool createsFork(ChessMove move, ChessBoard board) {
    // Apply the move
    final newBoard = _applyMove(board, move);
    final attackedPositions = _getAttackedPositions(newBoard, move.to);

    // Count valuable pieces attacked (worth > 300)
    final valuablePiecesAttacked = attackedPositions
        .map((pos) => newBoard.getPieceAt(pos))
        .where(
          (piece) =>
              piece != null &&
              piece.color != move.piece.color &&
              _getPieceValue(piece.type) > 300,
        )
        .length;

    return valuablePiecesAttacked >= 2;
  }

  /// Check if a move creates a discovered attack
  static bool createsDiscoveredAttack(ChessMove move, ChessBoard board) {
    // Skip if moving piece can't reveal anything behind it
    if (move.piece.type == PieceType.knight ||
        move.piece.type == PieceType.king) {
      return false;
    }

    // Look for friendly long-range pieces that could be revealed
    for (final piece in board.pieces) {
      if (piece.color != move.piece.color) continue;
      if (piece.type != PieceType.bishop &&
          piece.type != PieceType.rook &&
          piece.type != PieceType.queen) {
        continue;
      }

      // Check if moving piece was blocking this piece's attack
      if (_isOnAttackRay(piece.position, move.from, board)) {
        // Check if removing the piece reveals an attack
        final targets = _getRayTargets(piece.position, move.from, board);
        if (targets.any((target) {
          final targetPiece = board.getPieceAt(target);
          return targetPiece != null &&
              targetPiece.color != piece.color &&
              _getPieceValue(targetPiece.type) > 300;
        })) {
          return true;
        }
      }
    }

    return false;
  }

  /// Check if a move removes a pin on our piece
  static bool removesPin(ChessMove move, ChessBoard board) {
    // Check if the moving piece was pinned
    return _isPinned(move.piece.position, board);
  }

  /// Check if position is pinned
  static bool _isPinned(Position piecePos, ChessBoard board) {
    final piece = board.getPieceAt(piecePos);
    if (piece == null) return false;

    // Find our king
    final king = board.getKing(piece.color);
    if (king == null) return false;

    // Check if piece is on a line with king
    if (!piecePos.isOnSameRankWith(king.position) &&
        !piecePos.isOnSameFileWith(king.position) &&
        !piecePos.isOnDiagonalWith(king.position)) {
      return false;
    }

    // Check if enemy piece is attacking through this piece to king
    for (final enemyPiece in board.pieces) {
      if (enemyPiece.color == piece.color) continue;
      if (enemyPiece.type != PieceType.bishop &&
          enemyPiece.type != PieceType.rook &&
          enemyPiece.type != PieceType.queen) {
        continue;
      }

      // Check if enemy piece, our piece, and king are on same line
      if (_isOnAttackRay(enemyPiece.position, piecePos, board) &&
          _isOnAttackRay(piecePos, king.position, board)) {
        return true;
      }
    }

    return false;
  }

  /// Check if a move creates a skewer (attack valuable piece with less valuable behind)
  static bool createsSkewer(ChessMove move, ChessBoard board) {
    if (move.piece.type != PieceType.bishop &&
        move.piece.type != PieceType.rook &&
        move.piece.type != PieceType.queen) {
      return false;
    }

    final newBoard = _applyMove(board, move);
    final attackedPositions = _getAttackedPositions(newBoard, move.to);

    for (final attackedPos in attackedPositions) {
      final attackedPiece = newBoard.getPieceAt(attackedPos);
      if (attackedPiece == null || attackedPiece.color == move.piece.color) {
        continue;
      }

      // Check if there's a more valuable piece behind
      final behind = _getPieceBehind(move.to, attackedPos, newBoard);
      if (behind != null &&
          behind.color != move.piece.color &&
          _getPieceValue(behind.type) > _getPieceValue(attackedPiece.type)) {
        return true;
      }
    }

    return false;
  }

  /// Apply move to board (simplified)
  static ChessBoard _applyMove(ChessBoard board, ChessMove move) {
    final newPieces = board.pieces
        .where((p) => p.position != move.from && p.position != move.to)
        .toList();
    newPieces.add(move.piece.movedTo(move.to));

    return ChessBoard(
      pieces: newPieces,
      currentPlayer: board.currentPlayer.opposite,
      gameType: board.gameType,
    );
  }

  /// Get all positions attacked by a piece
  static List<Position> _getAttackedPositions(ChessBoard board, Position from) {
    final piece = board.getPieceAt(from);
    if (piece == null) return [];

    final attacked = <Position>[];

    for (int row = 0; row < 8; row++) {
      for (int col = 0; col < 8; col++) {
        final pos = Position(row, col);
        if (pos != from && piece.canAttack(pos, board.pieces)) {
          attacked.add(pos);
        }
      }
    }

    return attacked;
  }

  /// Check if target is on attack ray from source
  static bool _isOnAttackRay(
    Position source,
    Position target,
    ChessBoard board,
  ) {
    if (!source.isOnSameRankWith(target) &&
        !source.isOnSameFileWith(target) &&
        !source.isOnDiagonalWith(target)) {
      return false;
    }

    final dx = (target.col - source.col).sign;
    final dy = (target.row - source.row).sign;

    var current = Position(source.row + dy, source.col + dx);
    while (current.isValid && current != target) {
      final piece = board.getPieceAt(current);
      if (piece != null) return false; // Path blocked

      current = Position(current.row + dy, current.col + dx);
    }

    return current == target;
  }

  /// Get targets along a ray
  static List<Position> _getRayTargets(
    Position source,
    Position through,
    ChessBoard board,
  ) {
    if (!_isOnAttackRay(source, through, board)) return [];

    final dx = (through.col - source.col).sign;
    final dy = (through.row - source.row).sign;

    final targets = <Position>[];
    var current = Position(through.row + dy, through.col + dx);

    while (current.isValid) {
      final piece = board.getPieceAt(current);
      if (piece != null) {
        targets.add(current);
        break; // Stop at first piece
      }
      current = Position(current.row + dy, current.col + dx);
    }

    return targets;
  }

  /// Get piece behind target
  static ChessPiece? _getPieceBehind(
    Position from,
    Position target,
    ChessBoard board,
  ) {
    if (!from.isOnSameRankWith(target) &&
        !from.isOnSameFileWith(target) &&
        !from.isOnDiagonalWith(target)) {
      return null;
    }

    final dx = (target.col - from.col).sign;
    final dy = (target.row - from.row).sign;

    var current = Position(target.row + dy, target.col + dx);
    while (current.isValid) {
      final piece = board.getPieceAt(current);
      if (piece != null) return piece;
      current = Position(current.row + dy, current.col + dx);
    }

    return null;
  }

  /// Get piece value
  static int _getPieceValue(PieceType type) {
    switch (type) {
      case PieceType.pawn:
        return 100;
      case PieceType.knight:
        return 320;
      case PieceType.bishop:
        return 330;
      case PieceType.rook:
        return 500;
      case PieceType.queen:
        return 900;
      case PieceType.king:
        return 20000;
    }
  }
}
