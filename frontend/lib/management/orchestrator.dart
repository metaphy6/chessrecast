import 'package:chessrecast/debug.dart';
import '../board/utils/exporter.dart';
import '../modes/modes.dart';

/// Cached mode instances to avoid repeated instantiation
// Use centralized modes cache (ModesCache) to avoid repeated instantiation

class Orchestrator {
  /// Validates if a move is legal in the current board state
  bool isValidMove(ChessBoard board, ChessMove move) {
    // Truce mode: Check if move violates truce rules
    if (board.gameType == ModesEnum.truce) {
      if (!modes.truce.validateTruceMove(board, move)) {
        return false;
      }
    }

    final validMoves = board.getValidMovesFor(move.from);

    // For teleport mode, we need special comparison because the controller
    // sets capturedPiece to the rook/king, but the generated move has capturedPiece: null
    if (board.gameType == ModesEnum.teleport &&
        (move.piece.type == PieceType.king ||
            move.piece.type == PieceType.rook)) {
      final isValid = validMoves.any(
        (validMove) =>
            validMove.from == move.from &&
            validMove.to == move.to &&
            validMove.piece.type == move.piece.type,
      );
      return isValid;
    }

    // For Diamonds mode, we need to check if the move exists by position
    // because the bishop capture moves are specially generated
    if (board.gameType == ModesEnum.diamonds && move.piece.type == PieceType.bishop) {
      final isValid = validMoves.any(
        (validMove) =>
            validMove.from == move.from &&
            validMove.to == move.to,
      );
      return isValid;
    }

    final isValid = validMoves.any((validMove) => validMove == move);
    return isValid;
  }

  /// Executes a move and returns the new board state
  ChessBoard executeMove(ChessBoard board, ChessMove move) {
    if (!isValidMove(board, move)) {
      throw ArgumentError('Invalid move: $move');
    }

    // Check for Heir mode special moves (king capture detection)
    if (board.gameType == ModesEnum.heir) {
      final heirBoard = modes.heir.handleSpecialMove(board, move);
      if (heirBoard != null) {
        return updateGameStatus(heirBoard);
      }
    }

    // Check for Teleport mode special move (king-rook swap)
    if (board.gameType == ModesEnum.teleport) {
      final teleportBoard = modes.teleport.handleSpecialMove(board, move);
      if (teleportBoard != null) {
        return updateGameStatus(teleportBoard);
      }
    }

    // Check for Kings' Battle mode special moves (King's Kill or pawn promotion)
    if (board.gameType == ModesEnum.kingsBattle) {
      final kingsBattleBoard = modes.kingsBattle.handleSpecialMove(board, move);
      if (kingsBattleBoard != null) {
        return updateGameStatus(kingsBattleBoard);
      }
    }

    // Check for Save the Queen mode special moves (queen capture or return to prison)
    if (board.gameType == ModesEnum.saveTheQueen) {
      final saveTheQueenBoard = modes.saveTheQueen.handleSpecialMove(
        board,
        move,
      );
      if (saveTheQueenBoard != null) {
        return updateGameStatus(saveTheQueenBoard);
      }
    }

    // Check for Save the King mode special moves (queen capture or King promotion)
    if (board.gameType == ModesEnum.saveTheKing) {
      final saveTheKingBoard = modes.saveTheKing.handleSpecialMove(board, move);
      if (saveTheKingBoard != null) {
        return updateGameStatus(saveTheKingBoard);
      }
    }

    // Check for Other Side mode special moves (rook capture or back rank reached)
    if (board.gameType == ModesEnum.otherSide) {
      final otherSideBoard = modes.otherSide.handleSpecialMove(board, move);
      if (otherSideBoard != null) {
        return updateGameStatus(otherSideBoard);
      }
    }

    // Check for Snare mode special moves (revengeful knight capture)
    if (board.gameType == ModesEnum.snare) {
      final snareBoard = modes.snare.handleSpecialMove(board, move);
      if (snareBoard != null) {
        return updateGameStatus(snareBoard);
      }
    }

    // Check for Truce mode special move handling
    if (board.gameType == ModesEnum.truce) {
      final truceBoard = modes.truce.handleSpecialMove(board, move);
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
    // CRITICAL: Check if any king is missing (should never happen in most modes)
    // Exceptions:
    // - Heir mode: allows king captures, player can promote pawn to get new king
    // - Save the King mode: starts with no kings, must promote to get one
    if (board.gameType != ModesEnum.heir &&
        board.gameType != ModesEnum.saveTheKing) {
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

    // Special handling for Heir mode
    if (board.gameType == ModesEnum.heir) {
      return _updateHeirGameStatus(board);
    }

    // Special handling for Truce mode
    if (board.gameType == ModesEnum.truce) {
      return _updateTruceGameStatus(board);
    }

    // Special handling for Snare mode
    if (board.gameType == ModesEnum.snare) {
      return _updateSnareGameStatus(board);
    }

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

  /// Updates game status specifically for Heir mode
  /// In Heir mode, the king is a regular piece and does NOT trigger "check" status
  ChessBoard _updateHeirGameStatus(ChessBoard board) {
    final hasValidMoves = _hasValidMoves(board);

    GameStatus newStatus;

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
        // This player has lost - set as checkmate for opponent
        final winner = color == PieceColor.white ? 'black' : 'white';
        logCheckmate(winner);
        return board.copyWith(gameStatus: GameStatus.checkmate);
      }
    }

    // In Heir mode, king is NOT special - no check status
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
    final isTruceActive = modes.truce.isTruceActive(board);

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
      final currentPlayerInCheck = modes.truce.isKingInCheckTruce(
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

  /// SNARE MODE: Updates game status with entangled King detection
  ChessBoard _updateSnareGameStatus(ChessBoard board) {
    // If game is already over (checkmate/stalemate/draw from handleSpecialMove), don't overwrite
    // BUT we DO need to re-evaluate if status is just "check" to determine checkmate
    if (board.gameStatus == GameStatus.checkmate ||
        board.gameStatus == GameStatus.stalemate ||
        board.gameStatus == GameStatus.draw) {
      return board;
    }

    // CRITICAL: Check if current player's king is entangled (instant checkmate)
    // This handles both:
    // 1. Custom board setups where king starts entangled
    // 2. Kings that became entangled from knight moves (via handleSpecialMove)
    if (modes.snare.isKingEntangled(board.currentPlayer, board)) {
      // Log the entangle checkmate event
      final trappedColor = board.currentPlayer == PieceColor.white
          ? 'White'
          : 'Black';
      logSnareKingCaught(trappedColor);
      return board.copyWith(gameStatus: GameStatus.checkmate);
    }

    // NOTE: Entanglement-based checkmate from knight moves is primarily handled in handleSpecialMove
    // but we also check here to catch custom board initial states where king is already entangled

    // SNARE MODE: Special rule - if ALL knights are lost (both players), it's stalemate
    final whiteKnights = modes.snare.getKnights(PieceColor.white, board);
    final blackKnights = modes.snare.getKnights(PieceColor.black, board);

    if (whiteKnights.isEmpty && blackKnights.isEmpty) {
      // All knights lost from both sides - game ends in stalemate
      logSnareAllKnightsLost();
      return board.copyWith(gameStatus: GameStatus.stalemate);
    }

    // SNARE MODE: Check if current player's king still has knights
    final myKnights = modes.snare.getKnights(board.currentPlayer, board);

    final hasValidMoves = _hasValidMoves(board);

    GameStatus newStatus;

    if (myKnights.isNotEmpty) {
      // King has knights - cannot be checkmated, only captured
      // King moves freely and game can only end by capture (not checkmate)
      if (hasValidMoves) {
        newStatus = GameStatus.ongoing;
      } else {
        // No valid moves but king has knights - stalemate
        newStatus = GameStatus.stalemate;
      }
    } else {
      // King has no knights - apply regular chess checkmate rules
      final currentPlayerInCheck = modes.snare.isKingInCheckSnare(
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

    // Apply classic chess insufficient material rules first
    if (_isDrawByInsufficientMaterialClassic(whitePieces, blackPieces)) {
      return true;
    }

    // Snare mode: special insufficient material rules
    if (board.gameType == ModesEnum.snare) {
      if (_isDrawByInsufficientMaterialSnare(whitePieces, blackPieces, board)) {
        return true;
      }
    }

    // Royal Pawns mode: special insufficient material rules
    if (board.gameType == ModesEnum.royalPawns) {
      if (_isDrawByInsufficientMaterialRoyalPawns(whitePieces, blackPieces)) {
        return true;
      }
    }

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

  /// Snare mode insufficient material rules
  /// In Snare mode, knights are critical for creating entangle zones
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
    // (Two knights CAN checkmate a lone king in Snare mode via entangle zones)

    return false;
  }

  /// Royal Pawns mode insufficient material rules
  /// Pawns can't promote, so they're weaker. Apply relaxed rules.
  bool _isDrawByInsufficientMaterialRoyalPawns(
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

    // Two kings and one pawn (K+P vs K)
    // In Royal Pawns, one pawn can potentially checkmate a lone king
    // within 50 moves. This is checked separately by fifty-move rule.
    // Do NOT declare immediate insufficient material for K+P vs K

    // Two kings and two pawns - ONLY if each player has one pawn
    // (K+P vs K+P is draw, but K+P+P vs K is not)
    if (totalPieces == 4) {
      if (whitePawns == 1 && blackPawns == 1) {
        return true; // Each player has one pawn - insufficient material
      }
    }

    // Classic insufficient material for non-pawn pieces still applies
    final whiteNonPawns = <ChessPiece>[];
    final blackNonPawns = <ChessPiece>[];

    for (final p in whitePieces) {
      if (p.type != PieceType.pawn) whiteNonPawns.add(p);
    }
    for (final p in blackPieces) {
      if (p.type != PieceType.pawn) blackNonPawns.add(p);
    }

    // If there are only kings and one minor piece, it's a draw
    if (whiteNonPawns.length + blackNonPawns.length == 3) {
      // Two kings + one minor piece - find the non-king piece
      ChessPiece? nonKingPiece;
      for (final p in whiteNonPawns) {
        if (p.type != PieceType.king) {
          nonKingPiece = p;
          break;
        }
      }
      if (nonKingPiece == null) {
        for (final p in blackNonPawns) {
          if (p.type != PieceType.king) {
            nonKingPiece = p;
            break;
          }
        }
      }

      if (nonKingPiece != null &&
          (nonKingPiece.type == PieceType.bishop ||
              nonKingPiece.type == PieceType.knight)) {
        return true;
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

  /// Checks if current position is a special endgame requiring mate within 50 total moves
  /// Snare: K+N+N vs K (knights must mate within 50 half-moves = 25 white + 25 black)
  /// Royal Pawns: K+pieces vs K (must mate within 50 half-moves = 25 white + 25 black)
  bool _isSpecialEndgameRequiringFasterMate(ChessBoard board) {
    final whitePieces = board.getPiecesOfColor(PieceColor.white);
    final blackPieces = board.getPiecesOfColor(PieceColor.black);

    // Snare mode: K+N+N vs K or K vs K+N+N
    if (board.gameType == ModesEnum.snare) {
      int whiteKnights = 0;
      int blackKnights = 0;
      int whiteNonKingPieces = 0;
      int blackNonKingPieces = 0;

      for (final p in whitePieces) {
        if (p.type == PieceType.knight) {
          whiteKnights++;
        } else if (p.type != PieceType.king) {
          whiteNonKingPieces++;
        }
      }

      for (final p in blackPieces) {
        if (p.type == PieceType.knight) {
          blackKnights++;
        } else if (p.type != PieceType.king) {
          blackNonKingPieces++;
        }
      }

      // K+N+N vs K: Must mate within 50 moves
      if ((whiteKnights == 2 && blackNonKingPieces == 0 && blackKnights == 0) ||
          (blackKnights == 2 && whiteNonKingPieces == 0 && whiteKnights == 0)) {
        return true;
      }
    }

    // Royal Pawns mode: K+pieces vs K or K vs K+pieces
    if (board.gameType == ModesEnum.royalPawns) {
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
  /// Special endgames (Snare K+N+N vs K, Royal Pawns K+pieces vs K): 50 half-moves total (25+25)
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
