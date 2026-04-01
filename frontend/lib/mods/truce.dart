import '../board/utils/exporter.dart';
import '../board/moves/helpers.dart';
import '../debug.dart';
import 'game_mod.dart';

/// Truce Mod: Players cannot attack until all pieces have moved once
///
/// Rules:
/// - Players cannot capture opponent pieces until truce is broken
/// - Truce breaks when the side to move has exhausted all legal truce moves:
///   all pieces have moved at least once, or remaining unmoved pieces are blocked
/// - During truce, each piece can only be moved once
/// - NO check or checkmate during truce - kings move freely
/// - Moves that give check to the opponent king are illegal during truce
/// - Once truce is broken, normal chess rules apply including check/checkmate/captures
class Truce extends GameMod {
  const Truce();

  @override
  List<ChessMove> filterMoves(
    List<ChessMove> moves,
    ChessPiece piece,
    ChessBoard board,
  ) {
    // If truce is broken, return all moves
    if (_isTruceBroken(board)) {
      return moves;
    }

    if (_pieceHasMoved(board, piece)) {
      return const <ChessMove>[];
    }

    // During truce, filter out capturing moves and moves that give check
    final nonCapturingMoves = moves.where((move) {
      return move.capturedPiece == null;
    }).toList();

    // Also filter out moves that give check to the opponent king
    final safeMoves = nonCapturingMoves.where((move) {
      return !_moveGivesCheck(board, move);
    }).toList();

    return safeMoves;
  }

  /// Validate if a move is allowed during truce
  bool validateTruceMove(ChessBoard board, ChessMove move) {
    // Each piece can only move once during truce
    if (!_isTruceBroken(board) && _pieceHasMoved(board, move.piece)) {
      return false;
    }

    return true;
  }

  @override
  ChessBoard? handleSpecialMove(ChessBoard board, ChessMove move) {
    // Check if this move breaks the truce
    final wasTruceActive = !_isTruceBroken(board);
    final postMoveBoard = board.makeMove(move);

    // Check if truce should end after this move
    // Truce ends when player has exhausted all legal truce moves
    // (all pieces moved, or remaining unmoved pieces are blocked)
    if (wasTruceActive && !_isTruceBroken(postMoveBoard)) {
      // _isTruceBroken checks the post-move state already; if it returns
      // false here we're still in truce.  Nothing to log.
    } else if (wasTruceActive) {
      logTruceBroken(move.piece.color == PieceColor.white ? 'white' : 'black');
    }

    return null;
  }

  /// Check if truce is broken for the board.
  /// Truce breaks when the side to move has exhausted all legal truce moves:
  /// every piece has either moved at least once OR is blocked (no
  /// non-capturing moves available).
  bool _isTruceBroken(ChessBoard board) {
    final color = board.currentPlayer;
    final currentPieces = board.getPiecesOfColor(color);
    if (currentPieces.isEmpty) return true;

    int exhaustedCount = 0;
    for (final piece in currentPieces) {
      if (_pieceHasMoved(board, piece)) {
        exhaustedCount++;
      } else if (!_hasLegalTruceMove(board, piece)) {
        // Unmoved with no legal truce move → counts as exhausted
        exhaustedCount++;
      }
    }

    return exhaustedCount >= currentPieces.length;
  }

  bool _hasLegalTruceMove(ChessBoard board, ChessPiece piece) {
    final candidates = _candidateTruceMoves(board, piece);
    for (final move in candidates) {
      if (!_moveGivesCheck(board, move)) return true;
    }
    return false;
  }

  bool _pieceHasMoved(ChessBoard board, ChessPiece piece) {
    if (piece.hasMoved) return true;

    for (final move in board.moveHistory) {
      if (move.piece.color == piece.color && move.to == piece.position) {
        return true;
      }
    }

    return false;
  }

  List<ChessMove> _candidateTruceMoves(ChessBoard board, ChessPiece piece) {
    switch (piece.type) {
      case PieceType.pawn:
        return _pawnTruceMoves(board, piece);
      case PieceType.rook:
        return board
            .generateSlidingMoves(piece, const [
              [1, 0],
              [-1, 0],
              [0, 1],
              [0, -1],
            ])
            .where((move) => !move.isCapture)
            .toList();
      case PieceType.knight:
        return board
            .generateStepMoves(piece, const [
              [-2, -1],
              [-2, 1],
              [-1, -2],
              [-1, 2],
              [1, -2],
              [1, 2],
              [2, -1],
              [2, 1],
            ])
            .where((move) => !move.isCapture)
            .toList();
      case PieceType.bishop:
        return board
            .generateSlidingMoves(piece, const [
              [1, 1],
              [1, -1],
              [-1, 1],
              [-1, -1],
            ])
            .where((move) => !move.isCapture)
            .toList();
      case PieceType.queen:
        return board
            .generateSlidingMoves(piece, const [
              [1, 0],
              [-1, 0],
              [0, 1],
              [0, -1],
              [1, 1],
              [1, -1],
              [-1, 1],
              [-1, -1],
            ])
            .where((move) => !move.isCapture)
            .toList();
      case PieceType.king:
        final moves = board
            .generateStepMoves(piece, const [
              [1, 0],
              [-1, 0],
              [0, 1],
              [0, -1],
              [1, 1],
              [1, -1],
              [-1, 1],
              [-1, -1],
            ])
            .where((move) => !move.isCapture)
            .toList();
        final kingRow = piece.color == PieceColor.white ? 0 : 7;
        if (piece.position == Position(kingRow, 4)) {
          if (board.canCastleKingside(piece.color)) {
            moves.add(
              ChessMove.castling(
                from: piece.position,
                to: Position(kingRow, 6),
                piece: piece,
              ),
            );
          }
          if (board.canCastleQueenside(piece.color)) {
            moves.add(
              ChessMove.castling(
                from: piece.position,
                to: Position(kingRow, 2),
                piece: piece,
              ),
            );
          }
        }
        return moves;
    }
  }

  List<ChessMove> _pawnTruceMoves(ChessBoard board, ChessPiece piece) {
    final moves = <ChessMove>[];
    final direction = piece.color == PieceColor.white ? 1 : -1;
    final startRow = piece.color == PieceColor.white ? 1 : 6;
    final oneStep = piece.position.offset(direction, 0);

    if (oneStep.isValid && board.getPieceAt(oneStep) == null) {
      moves.addAll(
        board.createMovesWithPromotionCheck(
          piece,
          oneStep,
          promotionOptions: board.getPromotionPieces(
            piece.color,
            promotionPosition: oneStep,
          ),
        ),
      );

      if (piece.position.row == startRow) {
        final twoStep = piece.position.offset(direction * 2, 0);
        if (twoStep.isValid && board.getPieceAt(twoStep) == null) {
          moves.add(
            ChessMove.simple(from: piece.position, to: twoStep, piece: piece),
          );
        }
      }
    }

    return moves;
  }

  /// Public method to check if truce is still active
  bool isTruceActive(ChessBoard board) {
    return !_isTruceBroken(board);
  }

  /// Check if a move would give check to the opponent king.
  /// Creates a simulated board with the piece moved and checks if the
  /// opponent's king position is under attack.
  bool _moveGivesCheck(ChessBoard board, ChessMove move) {
    final opponentColor = move.piece.color.opposite;
    final king = board.getKing(opponentColor);
    if (king == null) return false;

    final simBoard = board.makeMoveForValidation(move);
    final opponentKing = simBoard.getKing(opponentColor);
    if (opponentKing == null) return false;
    return simBoard.isPositionUnderAttack(
      opponentKing.position,
      move.piece.color,
    );
  }

  /// Truce Mod: King cannot be in check during truce
  bool isKingInCheckTruce(PieceColor kingColor, ChessBoard board) {
    if (isTruceActive(board)) {
      return false; // No check during truce
    }

    // After truce breaks, use normal check logic
    final king = board.getKing(kingColor);
    if (king == null) return false;
    return board.isPositionUnderAttack(king.position, kingColor.opposite);
  }

  /// Returns a bitboard of squares where pieces have already moved during truce.
  /// Bit i is set if the piece at square (row=i/8, col=i%8) cannot be moved.
  int getTruceFrozenBitboard(ChessBoard board) {
    if (_isTruceBroken(board)) return 0;
    int frozen = 0;
    for (final piece in board.pieces) {
      if (_pieceHasMoved(board, piece)) {
        final sq = piece.position.row * 8 + piece.position.col;
        frozen |= (1 << sq);
      }
    }
    return frozen;
  }

  /// Get truce status information for display
  Map<String, dynamic> getTruceInfo(ChessBoard board) {
    final isBroken = _isTruceBroken(board);
    final whiteMovedCount = board
        .getPiecesOfColor(PieceColor.white)
        .where((piece) => _pieceHasMoved(board, piece))
        .length;
    final blackMovedCount = board
        .getPiecesOfColor(PieceColor.black)
        .where((piece) => _pieceHasMoved(board, piece))
        .length;

    final whiteTotalPieces = board.getPiecesOfColor(PieceColor.white).length;
    final blackTotalPieces = board.getPiecesOfColor(PieceColor.black).length;

    return {
      'truceActive': !isBroken,
      'whiteTruceBroken': isBroken,
      'blackTruceBroken': isBroken,
      'whiteMovedPieces': whiteMovedCount,
      'blackMovedPieces': blackMovedCount,
      'whiteTotalPieces': whiteTotalPieces,
      'blackTotalPieces': blackTotalPieces,
    };
  }
}
