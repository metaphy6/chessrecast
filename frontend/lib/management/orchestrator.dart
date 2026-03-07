import 'package:chessrecast/debug.dart';
import '../board/utils/exporter.dart';
import '../mods/mods.dart';

/// Cached mode instances to avoid repeated instantiation
// Use centralized mods cache (ModsCache) to avoid repeated instantiation

class Orchestrator {
  /// Validates if a move is legal in the current board state
  bool isValidMove(ChessBoard board, ChessMove move) {
    // Truce Mod: Check if move violates truce rules
    if (board.gameType == ModsEnum.truce) {
      if (!mods.truce.validateTruceMove(board, move)) {
        return false;
      }
    }

    final validMoves = board.getValidMovesFor(move.from);

    // DISABLED MOD: Secret Passage
    // if (board.gameType == ModsEnum.secretPassage &&
    //     (move.piece.type == PieceType.king ||
    //         move.piece.type == PieceType.rook)) {
    //   final isValid = validMoves.any(
    //     (validMove) =>
    //         validMove.from == move.from &&
    //         validMove.to == move.to &&
    //         validMove.piece.type == move.piece.type,
    //   );
    //   return isValid;
    // }

    // DISABLED MOD: Diamonds move validation
    // if (board.gameType == ModsEnum.diamonds &&
    //     move.piece.type == PieceType.bishop) {
    //   final isValid = validMoves.any(
    //     (validMove) => validMove.from == move.from && validMove.to == move.to,
    //   );
    //   return isValid;
    // }

    final isValid = validMoves.any((validMove) => validMove == move);
    return isValid;
  }

  /// Executes a move and returns the new board state
  ChessBoard executeMove(ChessBoard board, ChessMove move) {
    if (!isValidMove(board, move)) {
      throw ArgumentError('Invalid move: $move');
    }

    // Check for Heir Mod special moves (king capture detection)
    if (board.gameType == ModsEnum.heir) {
      final heirBoard = mods.heir.handleSpecialMove(board, move);
      if (heirBoard != null) {
        return updateGameStatus(heirBoard);
      }
    }

    // DISABLED MOD: Secret Passage
    // if (board.gameType == ModsEnum.secretPassage) {
    //   final secretPassageBoard = mods.secretPassage.handleSpecialMove(
    //     board,
    //     move,
    //   );
    //   if (secretPassageBoard != null) {
    //     return updateGameStatus(secretPassageBoard);
    //   }
    // }

    // Check for Kings' Battle mode special moves (King's Kill or pawn promotion)
    if (board.gameType == ModsEnum.kingsBattle) {
      final kingsBattleBoard = mods.kingsBattle.handleSpecialMove(board, move);
      if (kingsBattleBoard != null) {
        return updateGameStatus(kingsBattleBoard);
      }
    }

    // Check for Save the Queen Mod special moves (queen capture or return to prison)
    if (board.gameType == ModsEnum.saveTheQueen) {
      final saveTheQueenBoard = mods.saveTheQueen.handleSpecialMove(
        board,
        move,
      );
      if (saveTheQueenBoard != null) {
        return updateGameStatus(saveTheQueenBoard);
      }
    }

    // Check for Succession Mod special moves (queen capture or King promotion)
    if (board.gameType == ModsEnum.succession) {
      final successionBoard = mods.succession.handleSpecialMove(board, move);
      if (successionBoard != null) {
        return updateGameStatus(successionBoard);
      }
    }

    // DISABLED MOD: Coyote
    // if (board.gameType == ModsEnum.coyote) {
    //   final coyoteBoard = mods.coyote.handleSpecialMove(board, move);
    //   if (coyoteBoard != null) {
    //     return updateGameStatus(coyoteBoard);
    //   }
    // }

    // DISABLED MOD: Snare
    // if (board.gameType == ModsEnum.snare) {
    //   final snareBoard = mods.snare.handleSpecialMove(board, move);
    //   if (snareBoard != null) {
    //     return updateGameStatus(snareBoard);
    //   }
    // }

    // Check for Truce Mod special move handling
    if (board.gameType == ModsEnum.truce) {
      final truceBoard = mods.truce.handleSpecialMove(board, move);
      if (truceBoard != null) {
        return updateGameStatus(truceBoard);
      }
    }

    var newBoard = board.makeMove(move);
    newBoard = updateGameStatus(newBoard);

    return newBoard;
  }

  /// Updates the game status based on the current board state
  ChessBoard updateGameStatus(ChessBoard board) {
    // CRITICAL: Check if any king is missing (should never happen in most mods)
    // Exceptions:
    // - Heir Mod: allows king captures, player can promote pawn to get new king
    // - Succession Mod: starts with no kings, must promote to get one
    if (board.gameType != ModsEnum.heir &&
        board.gameType != ModsEnum.succession) {
      final whiteKing = board.getKing(PieceColor.white);
      final blackKing = board.getKing(PieceColor.black);

      if (whiteKing == null) {
        logError(
          'ORCHESTRATOR',
          'WHITE KING MISSING! Black wins by king capture (illegal state in ${board.gameType.name} mode)',
        );
        // Set currentPlayer to White so that getWinner() returns Black (White.opposite)
        return board.copyWith(
          gameStatus: GameStatus.checkmate,
          currentPlayer: PieceColor.white,
        );
      }
      if (blackKing == null) {
        logError(
          'ORCHESTRATOR',
          'BLACK KING MISSING! White wins by king capture (illegal state in ${board.gameType.name} mode)',
        );
        // Set currentPlayer to Black so that getWinner() returns White (Black.opposite)
        return board.copyWith(
          gameStatus: GameStatus.checkmate,
          currentPlayer: PieceColor.black,
        );
      }
    }

    // If the game is already over (from special move handling), don't recalculate
    if (board.gameStatus == GameStatus.checkmate ||
        board.gameStatus == GameStatus.stalemate ||
        board.gameStatus == GameStatus.draw) {
      return board;
    }

    // Special handling for Heir Mod
    if (board.gameType == ModsEnum.heir) {
      return _updateHeirGameStatus(board);
    }

    // Special handling for Truce Mod
    if (board.gameType == ModsEnum.truce) {
      return _updateTruceGameStatus(board);
    }

    // DISABLED MOD: Snare
    // if (board.gameType == ModsEnum.snare) {
    //   return _updateSnareGameStatus(board);
    // }

    final currentPlayerInCheck = board.isKingInCheck(board.currentPlayer);
    final hasValidMoves = _hasValidMoves(board);

    GameStatus newStatus;

    if (currentPlayerInCheck) {
      if (hasValidMoves) {
        logCheck(board.currentPlayer.name);
        newStatus = GameStatus.check;
      } else {
        final winner = board.currentPlayer == PieceColor.white
            ? 'black'
            : 'white';
        logCheckmate(winner);
        newStatus = GameStatus.checkmate;
      }
    } else {
      if (hasValidMoves) {
        newStatus = GameStatus.ongoing;
      } else {
        logStalemate();
        newStatus = GameStatus.stalemate;
      }
    }

    // Check for draw conditions
    if (_isDrawByInsufficientMaterial(board)) {
      logDrawInsufficientMaterial();
      newStatus = GameStatus.draw;
    } else if (_isDrawByRepetition(board)) {
      logDrawRepetition();
      newStatus = GameStatus.draw;
    } else if (_isDrawByFiftyMoveRule(board)) {
      logDrawFiftyMoveRule(
        isSpecialEndgame: _isSpecialEndgameRequiringFasterMate(board),
      );
      newStatus = GameStatus.draw;
    }

    return board.copyWith(gameStatus: newStatus);
  }

  /// Updates game status specifically for Heir Mod
  /// In Heir Mod, the king is a regular piece and does NOT trigger "check" status
  ChessBoard _updateHeirGameStatus(ChessBoard board) {
    final hasValidMoves = _hasValidMoves(board);

    GameStatus newStatus;

    // Check for immediate game end conditions in Heir Mod
    // If a player has no king AND no pawns, they lose immediately
    for (final color in [PieceColor.white, PieceColor.black]) {
      final kings = board.pieces
          .where((p) => p.type == PieceType.king && p.color == color)
          .toList();
      final pawns = board.pieces
          .where((p) => p.type == PieceType.pawn && p.color == color)
          .toList();

      if (kings.isEmpty && pawns.isEmpty) {
        // This player has lost - set as checkmate for opponent
        final winner = color == PieceColor.white ? 'black' : 'white';
        logCheckmate(winner);
        return board.copyWith(gameStatus: GameStatus.checkmate);
      }
    }

    // In Heir Mod, king is NOT special - no check status
    // Only check for stalemate/ongoing based on valid moves
    if (!hasValidMoves) {
      newStatus = GameStatus.stalemate;
    } else {
      newStatus = GameStatus.ongoing;
    }

    // Check for draw conditions
    if (_isDrawByInsufficientMaterial(board)) {
      logDrawInsufficientMaterial();
      newStatus = GameStatus.draw;
    } else if (_isDrawByRepetition(board)) {
      logDrawRepetition();
      newStatus = GameStatus.draw;
    } else if (_isDrawByFiftyMoveRule(board)) {
      logDrawFiftyMoveRule(
        isSpecialEndgame: _isSpecialEndgameRequiringFasterMate(board),
      );
      newStatus = GameStatus.draw;
    }

    return board.copyWith(gameStatus: newStatus);
  }

  ChessBoard _updateTruceGameStatus(ChessBoard board) {
    final isTruceActive = mods.truce.isTruceActive(board);

    final hasValidMoves = _hasValidMoves(board);

    GameStatus newStatus;

    if (isTruceActive) {
      // During truce: No check or checkmate, only stalemate if no moves
      if (hasValidMoves) {
        newStatus = GameStatus.ongoing;
      } else {
        // No valid moves during truce - stalemate
        logStalemate();
        newStatus = GameStatus.stalemate;
      }
    } else {
      // After truce breaks: Apply regular chess rules
      final currentPlayerInCheck = mods.truce.isKingInCheckTruce(
        board.currentPlayer,
        board,
      );

      if (currentPlayerInCheck) {
        if (hasValidMoves) {
          logCheck(board.currentPlayer.name);
          newStatus = GameStatus.check;
        } else {
          final winner = board.currentPlayer == PieceColor.white
              ? 'black'
              : 'white';
          logCheckmate(winner);
          newStatus = GameStatus.checkmate;
        }
      } else {
        if (hasValidMoves) {
          newStatus = GameStatus.ongoing;
        } else {
          logStalemate();
          newStatus = GameStatus.stalemate;
        }
      }
    }

    // Check for draw conditions
    if (_isDrawByInsufficientMaterial(board)) {
      logDrawInsufficientMaterial();
      newStatus = GameStatus.draw;
    } else if (_isDrawByRepetition(board)) {
      logDrawRepetition();
      newStatus = GameStatus.draw;
    } else if (_isDrawByFiftyMoveRule(board)) {
      logDrawFiftyMoveRule(
        isSpecialEndgame: _isSpecialEndgameRequiringFasterMate(board),
      );
      newStatus = GameStatus.draw;
    }

    return board.copyWith(gameStatus: newStatus);
  }

  /// Snare Mod: Updates game status with entangled King detection
  ChessBoard _updateSnareGameStatus(ChessBoard board) {
    // DISABLED MOD: Snare - entire method disabled
    return board;
  }

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

    // Mercenary Mod: special insufficient material rules (check first)
    if (board.gameType == ModsEnum.mercenary) {
      if (_isDrawByInsufficientMaterialMercenary(whitePieces, blackPieces)) {
        return true;
      }
      return false; // Don't apply classic rules for Mercenary
    }

    // Apply classic chess insufficient material rules for other mods
    if (_isDrawByInsufficientMaterialClassic(whitePieces, blackPieces)) {
      return true;
    }

    // DISABLED MOD: Snare special insufficient material rules
    // if (board.gameType == ModsEnum.snare) {
    //   if (_isDrawByInsufficientMaterialSnare(whitePieces, blackPieces, board)) {
    //     return true;
    //   }
    // }

    return false;
  }

  /// Classic chess insufficient material rules
  bool _isDrawByInsufficientMaterialClassic(
    List<ChessPiece> whitePieces,
    List<ChessPiece> blackPieces,
  ) {
    // King vs King
    if (whitePieces.length == 1 && blackPieces.length == 1) {
      return true;
    }

    // King and Bishop vs King or King and Knight vs King
    if ((whitePieces.length == 2 && blackPieces.length == 1) ||
        (whitePieces.length == 1 && blackPieces.length == 2)) {
      final allPieces = [...whitePieces, ...blackPieces];
      final nonKingPieces = allPieces
          .where((p) => p.type != PieceType.king)
          .toList();

      if (nonKingPieces.length == 1) {
        final piece = nonKingPieces.first;
        if (piece.type == PieceType.bishop || piece.type == PieceType.knight) {
          return true;
        }
      }
    }

    // King and Bishop vs King and Bishop (same color squares)
    if (whitePieces.length == 2 && blackPieces.length == 2) {
      final whiteBishops = whitePieces
          .where((p) => p.type == PieceType.bishop)
          .toList();
      final blackBishops = blackPieces
          .where((p) => p.type == PieceType.bishop)
          .toList();

      if (whiteBishops.length == 1 && blackBishops.length == 1) {
        // Check if bishops are on same color squares
        final whiteSquareColor =
            (whiteBishops.first.position.row +
                whiteBishops.first.position.col) %
            2;
        final blackSquareColor =
            (blackBishops.first.position.row +
                blackBishops.first.position.col) %
            2;

        if (whiteSquareColor == blackSquareColor) {
          return true;
        }
      }
    }

    return false;
  }

  /// Snare Mod insufficient material rules
  /// In Snare Mod, knights are critical for creating entangle zones
  /// Knights can defend each other and trap kings in entangle zones
  bool _isDrawByInsufficientMaterialSnare(
    List<ChessPiece> whitePieces,
    List<ChessPiece> blackPieces,
    ChessBoard board,
  ) {
    // First apply classic chess insufficient material rules
    if (_isDrawByInsufficientMaterialClassic(whitePieces, blackPieces)) {
      return true;
    }

    // Snare-specific rules:
    // K+N vs K+N: NOT insufficient material - both knights can defend and create entangle zones
    // K+N+N vs K: NOT immediate insufficient material - use 50-move rule (knights can checkmate)
    // K+N+N vs K+N+N: Insufficient material - symmetrical position, neither can gain advantage

    // Check for K+N+N vs K+N+N (two knights each) - this IS insufficient
    if (whitePieces.length == 3 && blackPieces.length == 3) {
      final whiteKnights = whitePieces
          .where((p) => p.type == PieceType.knight)
          .length;
      final blackKnights = blackPieces
          .where((p) => p.type == PieceType.knight)
          .length;

      if (whiteKnights == 2 && blackKnights == 2) {
        // Both players have only king + two knights
        final whiteNonKnights = whitePieces
            .where(
              (p) => p.type != PieceType.knight && p.type != PieceType.king,
            )
            .length;
        final blackNonKnights = blackPieces
            .where(
              (p) => p.type != PieceType.knight && p.type != PieceType.king,
            )
            .length;

        if (whiteNonKnights == 0 && blackNonKnights == 0) {
          return true; // K+N+N vs K+N+N is insufficient material (symmetrical)
        }
      }
    }

    // K+N vs K+N: NOT insufficient - knights can create entangle zones
    // K+N+N vs K: NOT insufficient - handled by 50-move rule
    // (Two knights CAN checkmate a lone king in Snare Mod via entangle zones)

    return false;
  }

  /// Mercenary Mod insufficient material rules
  /// Pawns can't promote but move like kings, so they can assist in checkmates
  bool _isDrawByInsufficientMaterialMercenary(
    List<ChessPiece> whitePieces,
    List<ChessPiece> blackPieces,
  ) {
    final whitePawns = whitePieces
        .where((p) => p.type == PieceType.pawn)
        .length;
    final blackPawns = blackPieces
        .where((p) => p.type == PieceType.pawn)
        .length;

    final totalPieces = whitePieces.length + blackPieces.length;

    // King vs King - draw
    if (totalPieces == 2) {
      return true;
    }

    // If there are pawns, they can assist in checkmate (don't draw yet)
    if (whitePawns > 0 || blackPawns > 0) {
      return false;
    }

    // No pawns left - check Mercenary specific insufficient material
    // K+N vs K+N is insufficient in Mercenary (can't checkmate without pawns to promote)
    if (totalPieces == 4) {
      final whiteKnights = whitePieces
          .where((p) => p.type == PieceType.knight)
          .length;
      final blackKnights = blackPieces
          .where((p) => p.type == PieceType.knight)
          .length;
      if (whiteKnights == 1 && blackKnights == 1) {
        return true; // K+N vs K+N is insufficient
      }
    }

    // Apply classic insufficient material for remaining pieces
    return _isDrawByInsufficientMaterialClassic(whitePieces, blackPieces);
  }

  /// Checks for draw by threefold repetition
  bool _isDrawByRepetition(ChessBoard board) {
    // This is a simplified version - in a real implementation,
    // you would track board positions and count repetitions
    return false;
  }

  /// Checks if current position is a special endgame requiring mate within 50 total moves
  /// Snare: K+N+N vs K (knights must mate within 50 half-moves = 25 white + 25 black)
  /// Mercenary: K+pieces vs K (must mate within 50 half-moves = 25 white + 25 black)
  bool _isSpecialEndgameRequiringFasterMate(ChessBoard board) {
    final whitePieces = board.getPiecesOfColor(PieceColor.white);
    final blackPieces = board.getPiecesOfColor(PieceColor.black);

    // DISABLED MOD: Snare K+N+N vs K special endgame
    // if (board.gameType == ModsEnum.snare) {
    //   int whiteKnights = 0;
    //   int blackKnights = 0;
    //   int whiteNonKingPieces = 0;
    //   int blackNonKingPieces = 0;
    //   for (final p in whitePieces) {
    //     if (p.type == PieceType.knight) { whiteKnights++; }
    //     else if (p.type != PieceType.king) { whiteNonKingPieces++; }
    //   }
    //   for (final p in blackPieces) {
    //     if (p.type == PieceType.knight) { blackKnights++; }
    //     else if (p.type != PieceType.king) { blackNonKingPieces++; }
    //   }
    //   if ((whiteKnights == 2 && blackNonKingPieces == 0 && blackKnights == 0) ||
    //       (blackKnights == 2 && whiteNonKingPieces == 0 && whiteKnights == 0)) {
    //     return true;
    //   }
    // }

    // Mercenary Mod: K+pieces vs K or K vs K+pieces
    if (board.gameType == ModsEnum.mercenary) {
      // Check if one side has only king
      final whiteOnlyKing = whitePieces.length == 1;
      final blackOnlyKing = blackPieces.length == 1;

      if (whiteOnlyKing || blackOnlyKing) {
        return true;
      }
    }

    return false;
  }

  /// Checks for draw by fifty-move rule
  /// Special endgames (Snare K+N+N vs K, Mercenary K+pieces vs K): 50 half-moves total (25+25)
  /// Normal games: 50 full moves (100 half-moves) without capture or pawn move
  bool _isDrawByFiftyMoveRule(ChessBoard board) {
    final fiftyMoveLimit = _isSpecialEndgameRequiringFasterMate(board)
        ? 50
        : 100;
    return board.halfMoveClock >= fiftyMoveLimit;
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
