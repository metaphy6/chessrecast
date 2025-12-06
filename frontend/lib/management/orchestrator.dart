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
    if (_isDrawByInsufficientMaterial(board) ||
        _isDrawByRepetition(board) ||
        _isDrawByFiftyMoveRule(board)) {
      newStatus = GameStatus.draw;
    }

    return board.copyWith(gameStatus: newStatus);
  }

  /// Updates game status specifically for Truce mode
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
    // If game is already over (checkmate/stalemate/draw from handleSpecialMove), don't overwrite
    // BUT we DO need to re-evaluate if status is just "check" to determine checkmate
    if (board.gameStatus == GameStatus.checkmate ||
        board.gameStatus == GameStatus.stalemate ||
        board.gameStatus == GameStatus.draw) {
      return board;
    }

    // NOTE: We do NOT check for king entanglement here!
    // Entanglement-based checkmate is ONLY triggered by handleSpecialMove when:
    // 1. A knight move is made
    // 2. That move creates a NEW entangle zone
    // 3. The opponent's king is caught in that new zone
    //
    // Kings are allowed to freely enter existing entangle zones without penalty.
    // This prevents false checkmate when a king voluntarily moves into an existing zone.

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

    // Royal Pawns mode: special insufficient material rules
    if (board.gameType == ModesEnum.royalPawns) {
      return _isDrawByInsufficientMaterialRoyalPawns(whitePieces, blackPieces);
    }

    // Classic chess insufficient material rules
    return _isDrawByInsufficientMaterialClassic(whitePieces, blackPieces);
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

    // King vs King
    if (totalPieces == 2) {
      return true;
    }

    // Two kings and one pawn (K+P vs K)
    if (totalPieces == 3) {
      final totalPawns = whitePawns + blackPawns;
      if (totalPawns == 1) {
        return true; // One pawn can't force checkmate in Royal Pawns
      }
    }

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
