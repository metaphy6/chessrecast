import '../board/exporter.dart';

class ChessGameOrchestrator {
  /// Validates if a move is legal in the current board state
  bool isValidMove(ChessBoard board, ChessMove move) {
    final validMoves = board.getValidMovesFor(move.from);
    return validMoves.any((validMove) => validMove == move);
  }

  /// Executes a move and returns the new board state
  ChessBoard executeMove(ChessBoard board, ChessMove move) {
    if (!isValidMove(board, move)) {
      throw ArgumentError('Invalid move: $move');
    }

    // Check for Queen capture in Supreme Queen mode before making the move
    if (board.gameType == GameType.supremeQueen && move.capturedPiece != null) {
      if (move.capturedPiece!.type == PieceType.queen) {
        // Make the move first, then set game as won
        var newBoard = board.makeMove(move);
        return newBoard.copyWith(gameStatus: GameStatus.checkmate);
      }
    }

    var newBoard = board.makeMove(move);
    newBoard = _updateGameStatus(newBoard);

    return newBoard;
  }

  /// Updates the game status based on the current board state
  ChessBoard _updateGameStatus(ChessBoard board) {
    // Special handling for Heir mode
    if (board.gameType == GameType.heir) {
      return _updateHeirGameStatus(board);
    }

    // Special handling for Supreme Queen mode
    if (board.gameType == GameType.supremeQueen) {
      return _updateSupremeQueenGameStatus(board);
    }

    // Special handling for Snare mode
    if (board.gameType == GameType.snare) {
      return _updateSnareGameStatus(board);
    }

    final currentPlayerInCheck = board.isKingInCheck(board.currentPlayer);
    final hasValidMoves = _hasValidMoves(board);

    GameStatus newStatus;

    if (currentPlayerInCheck) {
      if (hasValidMoves) {
        newStatus = GameStatus.check;
      } else {
        newStatus = GameStatus.checkmate;
      }
    } else {
      if (hasValidMoves) {
        newStatus = GameStatus.ongoing;
      } else {
        newStatus = GameStatus.stalemate;
      }
    }

    // Check for draw conditions
    if (_isDrawByInsufficientMaterial(board) ||
        _isDrawByRepetition(board) ||
        _isDrawByFiftyMoveRule(board)) {
      newStatus = GameStatus.draw;
    }

    return board.copyWith(gameStatus: newStatus);
  }

  /// Updates game status specifically for Heir mode
  ChessBoard _updateHeirGameStatus(ChessBoard board) {
    final currentPlayerInCheck = board.isKingInCheck(board.currentPlayer);
    final hasValidMoves = _hasValidMoves(board);

    GameStatus newStatus;
    ChessBoard updatedBoard = board;

    // Check for immediate game end conditions in Heir mode
    // If a player has no king AND no pawns, they lose immediately
    for (final color in [PieceColor.white, PieceColor.black]) {
      final kings = board.pieces
          .where((p) => p.type == PieceType.king && p.color == color)
          .toList();
      final pawns = board.pieces
          .where((p) => p.type == PieceType.pawn && p.color == color)
          .toList();

      if (kings.isEmpty && pawns.isEmpty) {
        return board.copyWith(gameStatus: GameStatus.checkmate);
      }
    }

    if (currentPlayerInCheck && !hasValidMoves) {
      // Current player's king is checkmated

      // Check if this should end the game immediately based on new Heir rules
      final playerWhoLostKing = board.currentPlayer;
      final hasPromotedKing = playerWhoLostKing == PieceColor.white
          ? board.whiteHasPromotedKing
          : board.blackHasPromotedKing;

      final pawns = board.pieces
          .where(
            (p) => p.type == PieceType.pawn && p.color == playerWhoLostKing,
          )
          .toList();

      if (hasPromotedKing) {
        // Second (promoted) king is mated - game ends immediately (like regular checkmate)
        newStatus = GameStatus.checkmate;
        updatedBoard = board; // No need to remove king, game ends
      } else if (pawns.isEmpty) {
        // First king mated and no pawns to promote - game ends immediately
        newStatus = GameStatus.checkmate;
        updatedBoard = board; // No need to remove king, game ends
      } else {
        // First king mated but pawns available - remove king and continue

        final king = board.getKing(board.currentPlayer);
        if (king != null) {

          // Create a new pieces list with the king removed
          final newPieces = board.pieces
              .where((piece) => piece != king)
              .toList();

          updatedBoard = board.copyWith(
            pieces: newPieces,
            // Keep currentPlayer unchanged - they get to continue after losing their king
          );
        }

        newStatus = GameStatus
            .ongoing; // Continue the game - player can move without king
      }
    } else if (currentPlayerInCheck) {
      newStatus = GameStatus.check;
    } else if (!hasValidMoves) {
      newStatus = GameStatus.stalemate;
    } else {
      newStatus = GameStatus.ongoing;
    }

    // Check for draw conditions
    if (_isDrawByInsufficientMaterial(updatedBoard) ||
        _isDrawByRepetition(updatedBoard) ||
        _isDrawByFiftyMoveRule(updatedBoard)) {
      newStatus = GameStatus.draw;
    }

    return updatedBoard.copyWith(gameStatus: newStatus);
  }

  /// Updates game status specifically for Supreme Queen mode
  ChessBoard _updateSupremeQueenGameStatus(ChessBoard board) {
    final currentPlayerInCheck = board.isKingInCheck(board.currentPlayer);
    final hasValidMoves = _hasValidMoves(board);

    GameStatus newStatus;

    // Supreme Queen mode follows regular chess rules for check/mate/stalemate
    // Queen capture ending is handled in executeMove() before this method is called
    if (currentPlayerInCheck) {
      if (hasValidMoves) {
        newStatus = GameStatus.check;
      } else {
        newStatus = GameStatus.checkmate;
      }
    } else {
      if (hasValidMoves) {
        newStatus = GameStatus.ongoing;
      } else {
        newStatus = GameStatus.stalemate;
      }
    }

    // Check for draw conditions
    if (_isDrawByInsufficientMaterial(board) ||
        _isDrawByRepetition(board) ||
        _isDrawByFiftyMoveRule(board)) {
      newStatus = GameStatus.draw;
    }

    return board.copyWith(gameStatus: newStatus);
  }

  /// SNARE MODE: Updates game status with entangled King detection
  ChessBoard _updateSnareGameStatus(ChessBoard board) {
    // If game is already over (e.g., immediate checkmate from makeMove), don't overwrite
    if (board.gameStatus != GameStatus.ongoing) {
      return board;
    }

    // Use standard chess rules
    final currentPlayerInCheck = board.isKingInCheck(board.currentPlayer);
    final hasValidMoves = _hasValidMoves(board);

    GameStatus newStatus;

    if (currentPlayerInCheck) {
      if (hasValidMoves) {
        newStatus = GameStatus.check;
      } else {
        newStatus = GameStatus.checkmate;
      }
    } else {
      if (hasValidMoves) {
        newStatus = GameStatus.ongoing;
      } else {
        newStatus = GameStatus.stalemate;
      }
    }

    // Check for draw conditions
    if (_isDrawByInsufficientMaterial(board) ||
        _isDrawByRepetition(board) ||
        _isDrawByFiftyMoveRule(board)) {
      newStatus = GameStatus.draw;
    }

    return board.copyWith(gameStatus: newStatus);
  }

  /// Checks if the current player has any valid moves
  bool _hasValidMoves(ChessBoard board) {
    final playerPieces = board.getPiecesOfColor(board.currentPlayer);

    for (final piece in playerPieces) {
      if (board.getValidMovesFor(piece.position).isNotEmpty) {
        return true;
      }
    }

    return false;
  }

  /// Checks for draw by insufficient material
  bool _isDrawByInsufficientMaterial(ChessBoard board) {
    final whitePieces = board.getPiecesOfColor(PieceColor.white);
    final blackPieces = board.getPiecesOfColor(PieceColor.black);

    // King vs King
    if (whitePieces.length == 1 && blackPieces.length == 1) {
      return true;
    }

    // King and Bishop vs King or King and Knight vs King
    if ((whitePieces.length == 2 && blackPieces.length == 1) ||
        (whitePieces.length == 1 && blackPieces.length == 2)) {
      final allPieces = [...whitePieces, ...blackPieces];
      final nonKingPieces = allPieces
          .where((p) => p.type.name != 'king')
          .toList();

      if (nonKingPieces.length == 1) {
        final piece = nonKingPieces.first;
        if (piece.type.name == 'bishop' || piece.type.name == 'knight') {
          return true;
        }
      }
    }

    return false;
  }

  /// Checks for draw by threefold repetition
  bool _isDrawByRepetition(ChessBoard board) {
    // This is a simplified version - in a real implementation,
    // you would track board positions and count repetitions
    return false;
  }

  /// Checks for draw by fifty-move rule
  bool _isDrawByFiftyMoveRule(ChessBoard board) {
    return board.halfMoveClock >= 100; // 50 moves by each player
  }

  /// Gets all possible moves for the current player
  List<ChessMove> getAllValidMoves(ChessBoard board) {
    final validMoves = <ChessMove>[];
    final playerPieces = board.getPiecesOfColor(board.currentPlayer);

    for (final piece in playerPieces) {
      validMoves.addAll(board.getValidMovesFor(piece.position));
    }

    return validMoves;
  }

  /// Checks if the game is over
  bool isGameOver(ChessBoard board) {
    return board.gameStatus.isGameOver;
  }

  /// Gets the winner of the game (returns null if game is not over or is a draw)
  PieceColor? getWinner(ChessBoard board) {
    if (board.gameStatus == GameStatus.checkmate) {
      return board
          .currentPlayer
          .opposite; // The player who is NOT in checkmate wins
    }
    return null;
  }

  /// Converts a move from algebraic notation to a ChessMove object
  ChessMove? parseAlgebraicNotation(ChessBoard board, String notation) {
    // This is a simplified parser - a full implementation would handle
    // all chess notation nuances
    if (notation.length < 2) return null;

    try {
      final moves = getAllValidMoves(board);

      // Simple parsing for basic moves (e.g., "e2e4")
      if (notation.length == 4) {
        final from = Position.fromAlgebraic(notation.substring(0, 2));
        final to = Position.fromAlgebraic(notation.substring(2, 4));

        return moves.firstWhere(
          (move) => move.from == from && move.to == to,
          orElse: () => throw StateError('Move not found'),
        );
      }

      return null;
    } catch (e) {
      return null;
    }
  }
}
