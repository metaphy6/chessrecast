import '../items/piece_color.dart';
import '../items/piece_type.dart';
import '../../modes/modes.dart';
import 'position.dart';
import 'helpers.dart';
import '../piece.dart';
import 'move.dart';
import '../board.dart';
import 'special_cases.dart';
import 'validation.dart';
// modes.dart already imported above and provides enums and instances

/// Cached mode instances to avoid repeated instantiation
// Use centralized ModesCache for singleton mode instances

/// Extension for move generation operations
extension MoveGeneration on ChessBoard {
  /// Gets all valid moves for a piece at the specified position
  List<ChessMove> getValidMovesFor(Position position) {
    final piece = getPieceAt(position);

    if (piece == null || piece.color != currentPlayer) {
      return [];
    }

    final potentialMoves = _getPotentialMoves(piece);

    // Apply game mode specific move filtering first
    final filteredByGameMode = _applyGameModeFilter(potentialMoves, piece);

    // Filter out moves that would put own king in check (unless game mode allows suicide)
    // Optimize: Pre-allocate result list
    final safeMoves = <ChessMove>[];

    for (final move in filteredByGameMode) {
      // CRITICAL: Never allow capturing the opponent's king
      // Exception: Heir mode allows king captures as part of the game mechanics
      // Exception: Snare mode allows king capture if it's actually under attack
      if (move.capturedPiece != null &&
          move.capturedPiece!.type == PieceType.king &&
          gameType != ModesEnum.heir) {
        // In Snare mode, allow king capture only if the king is actually under attack
        if (gameType == ModesEnum.snare) {
          final opponentColor = move.capturedPiece!.color;
          // Check if opponent's king is actually capturable (under attack)
          if (!modes.snare.isKingCapturable(opponentColor, this)) {
            continue; // Skip this move
          }
          // King is capturable - allow the move
          safeMoves.add(move);
          continue;
        }

        continue; // Skip this move
      }

      final boardAfterMove = makeMoveForValidation(move);
      final kingInCheck = boardAfterMove.isKingInCheck(currentPlayer);

      // Truce mode: Kings can move freely during truce (no check enforcement)
      if (gameType == ModesEnum.truce) {
        if (modes.truce.isTruceActive(this)) {
          // During truce, allow all moves (king can move into "check")
          safeMoves.add(move);
          continue;
        }
        // After truce breaks, apply normal check rules (fall through)
      }

      // Heir mode: King is a regular piece UNLESS player has promoted or has no pawns
      if (gameType == ModesEnum.heir) {
        // CRITICAL: Kings must ALWAYS respect adjacency rule, regardless of check rules
        if (move.piece.type == PieceType.king) {
          // Check if move would place king adjacent to opponent king
          final opponentKing = boardAfterMove.getKing(currentPlayer.opposite);
          if (opponentKing != null) {
            final rowDiff = (opponentKing.position.row - move.to.row).abs();
            final colDiff = (opponentKing.position.col - move.to.col).abs();
            if (rowDiff <= 1 &&
                colDiff <= 1 &&
                (rowDiff != 0 || colDiff != 0)) {
              continue; // Skip - would be adjacent to opponent king
            }
          }
        }

        final heirMode = modes.heir;
        if (!heirMode.shouldApplyCheckRules(currentPlayer, this)) {
          safeMoves.add(move); // No check rules yet
          continue;
        }
        // Check rules apply, fall through to standard validation
      }

      // Snare mode: King cannot be checkmated while it has knights, but still cannot
      // move into attacked squares. Knights attack normally in L-shape pattern.
      // King can only end up in entangle zone if knights create it around the king,
      // not by king's own movement (already filtered in snare.dart filterMoves).
      // No special handling needed here - let normal check rules apply.

      if (!kingInCheck) {
        safeMoves.add(move);
      }
    }

    return safeMoves;
  }

  /// Centralized game mode move filtering to reduce duplicated switch/if blocks.
  List<ChessMove> _applyGameModeFilter(
    List<ChessMove> potentialMoves,
    ChessPiece piece,
  ) {
    switch (gameType) {
      case ModesEnum.snare:
        return modes.snare.filterMoves(potentialMoves, piece, this);
      case ModesEnum.truce:
        return modes.truce.filterMoves(potentialMoves, piece, this);
      case ModesEnum.diamonds:
        return modes.diamonds.filterMoves(potentialMoves, piece, this);
      case ModesEnum.teleport:
        return modes.teleport.filterMoves(potentialMoves, piece, this);
      case ModesEnum.friendlyFire:
        return modes.friendlyFire.filterMoves(potentialMoves, piece, this);
      case ModesEnum.kingsBattle:
        return modes.kingsBattle.filterMoves(potentialMoves, piece, this);
      case ModesEnum.saveTheQueen:
        return modes.saveTheQueen.filterMoves(potentialMoves, piece, this);
      case ModesEnum.otherSide:
        return modes.otherSide.filterMoves(potentialMoves, piece, this);
      default:
        return potentialMoves;
    }
  }

  /// Gets all potential moves for a piece (without checking for king safety)
  List<ChessMove> _getPotentialMoves(ChessPiece piece) {
    switch (piece.type) {
      case PieceType.pawn:
        return _getPawnMoves(piece);
      case PieceType.rook:
        return _getRookMoves(piece);
      case PieceType.knight:
        return _getKnightMoves(piece);
      case PieceType.bishop:
        return _getBishopMoves(piece);
      case PieceType.queen:
        return _getQueenMoves(piece);
      case PieceType.king:
        return _getKingMoves(piece);
    }
  }

  List<ChessMove> _getPawnMoves(ChessPiece pawn) {
    // Check if the game mode has custom pawn moves
    if (gameType == ModesEnum.otherSide) {
      final customMoves = modes.otherSide.getPawnMoves(pawn, this);
      if (customMoves != null) return customMoves;
    }

    if (gameType == ModesEnum.royalPawns) {
      final customMoves = modes.royalPawns.getPawnMoves(pawn, this);
      if (customMoves != null) return customMoves;
    }

    final moves = <ChessMove>[];
    final direction = pawn.color == PieceColor.white ? 1 : -1;
    final startRow = pawn.color == PieceColor.white ? 1 : 6;

    // Debug en passant target - always print

    if (enPassantTarget != null) {}

    // Forward move
    final oneStep = pawn.position.offset(direction, 0);
    if (oneStep.isValid && getPieceAt(oneStep) == null) {
      // Check for promotion
      final lastRank = pawn.color == PieceColor.white ? 7 : 0;
      if (oneStep.row == lastRank) {
        moves.addAll(
          createMovesWithPromotionCheck(
            pawn,
            oneStep,
            promotionOptions: getPromotionPieces(
              pawn.color,
              promotionPosition: oneStep,
            ),
          ),
        );
      } else {
        // Regular forward move
        moves.add(
          ChessMove.simple(from: pawn.position, to: oneStep, piece: pawn),
        );
      }

      // Two-step move from starting position
      if (pawn.position.row == startRow) {
        final twoStep = pawn.position.offset(direction * 2, 0);
        if (twoStep.isValid && getPieceAt(twoStep) == null) {
          moves.add(
            ChessMove.simple(from: pawn.position, to: twoStep, piece: pawn),
          );
        }
      }
    }

    // Diagonal captures
    for (final colOffset in [-1, 1]) {
      final capturePos = pawn.position.offset(direction, colOffset);
      if (capturePos.isValid) {
        final targetPiece = getPieceAt(capturePos);
        if (targetPiece != null && targetPiece.color != pawn.color) {
          // Check for promotion when capturing
          final lastRank = pawn.color == PieceColor.white ? 7 : 0;
          if (capturePos.row == lastRank) {
            moves.addAll(
              createMovesWithPromotionCheck(
                pawn,
                capturePos,
                capturedPiece: targetPiece,
                promotionOptions: getPromotionPieces(
                  pawn.color,
                  promotionPosition: capturePos,
                ),
              ),
            );
          } else {
            // Regular capture
            moves.add(
              ChessMove.simple(
                from: pawn.position,
                to: capturePos,
                piece: pawn,
                capturedPiece: targetPiece,
              ),
            );
          }
        }

        // En passant
        if (capturePos == enPassantTarget) {
          // The captured pawn is on the same row as the attacking pawn
          final capturedPawn = getPieceAt(
            Position(pawn.position.row, capturePos.col),
          );
          if (capturedPawn != null && capturedPawn.type == PieceType.pawn) {
            moves.add(
              ChessMove.enPassant(
                from: pawn.position,
                to: capturePos,
                piece: pawn,
                capturedPiece: capturedPawn,
              ),
            );
          }
        }
      }
    }

    return moves;
  }

  /// Gets available promotion pieces based on game mode and player state
  List<String> getPromotionPieces(
    PieceColor color, {
    Position? promotionPosition,
  }) {
    // Check for Royal Pawns mode - NO promotion
    if (gameType == ModesEnum.royalPawns) {
      return []; // No promotion in Royal Pawns mode
    }

    // Check for Diamonds mode - only bishops allowed
    if (gameType == ModesEnum.diamonds) {
      return ['B']; // Only bishop promotion in Diamonds mode
    }

    // Check for Save the Queen mode - no queen promotion allowed
    if (gameType == ModesEnum.saveTheQueen) {
      return ['R', 'B', 'N']; // Rook, Bishop, Knight only
    }

    // Check for Other Side mode - no rook promotion allowed
    if (gameType == ModesEnum.otherSide) {
      return ['Q', 'B', 'N']; // Queen, Bishop, Knight only
    }

    // Check for Heir mode - can promote to King (with restrictions)
    if (gameType == ModesEnum.heir) {
      final heirMode = modes.heir;
      final options = heirMode.getPromotionPieces(
        color,
        this,
        promotionPosition: promotionPosition,
      );
      if (options != null) {
        return options;
      }
    }

    // Check for Save the King mode - can promote to King
    if (gameType == ModesEnum.saveTheKing) {
      final saveTheKingMode = modes.saveTheKing;
      final options = saveTheKingMode.getPromotionPieces(
        color,
        this,
        promotionPosition: promotionPosition,
      );
      if (options != null) {
        return options;
      }
    }

    // Check for Snare mode - knight-based promotion restrictions
    if (gameType == ModesEnum.snare) {
      final snareMode = modes.snare;
      final options = snareMode.getPromotionPieces(
        color,
        this,
        promotionPosition: promotionPosition,
      );
      if (options != null) {
        return options;
      }
    }

    return ['Q', 'R', 'B', 'N']; // Standard promotion pieces
  }

  List<ChessMove> _getRookMoves(ChessPiece rook) {
    final directions = [
      [-1, 0],
      [1, 0],
      [0, -1],
      [0, 1],
    ];
    return generateSlidingMoves(rook, directions);
  }

  List<ChessMove> _getKnightMoves(ChessPiece knight) {
    final knightMoves = [
      [-2, -1],
      [-2, 1],
      [-1, -2],
      [-1, 2],
      [1, -2],
      [1, 2],
      [2, -1],
      [2, 1],
    ];
    return generateStepMoves(knight, knightMoves);
  }

  List<ChessMove> _getBishopMoves(ChessPiece bishop) {
    final directions = [
      [-1, -1],
      [-1, 1],
      [1, -1],
      [1, 1],
    ];
    return generateSlidingMoves(bishop, directions);
  }

  List<ChessMove> _getQueenMoves(ChessPiece queen) {
    return [..._getRookMoves(queen), ..._getBishopMoves(queen)];
  }

  List<ChessMove> _getKingMoves(ChessPiece king) {
    final directions = [
      [-1, -1],
      [-1, 0],
      [-1, 1],
      [0, -1],
      [0, 1],
      [1, -1],
      [1, 0],
      [1, 1],
    ];
    final moves = generateStepMoves(king, directions);

    // Add castling moves if conditions are met (not in Teleport or OtherSide mode)
    if (gameType != ModesEnum.teleport && gameType != ModesEnum.otherSide) {
      if (king.color == PieceColor.white) {
        // White kingside castling (O-O)
        if (whiteCanCastleKingside && canCastleKingside(king.color)) {
          final castleMove = ChessMove.castling(
            from: king.position,
            to: Position(0, 6), // g1
            piece: king,
          );
          moves.add(castleMove);
        }

        // White queenside castling (O-O-O)
        if (whiteCanCastleQueenside && canCastleQueenside(king.color)) {
          final castleMove = ChessMove.castling(
            from: king.position,
            to: Position(0, 2), // c1
            piece: king,
          );
          moves.add(castleMove);
        }
      } else {
        // Black kingside castling (O-O)
        if (blackCanCastleKingside && canCastleKingside(king.color)) {
          final castleMove = ChessMove.castling(
            from: king.position,
            to: Position(7, 6), // g8
            piece: king,
          );
          moves.add(castleMove);
        }

        // Black queenside castling (O-O-O)
        if (blackCanCastleQueenside && canCastleQueenside(king.color)) {
          final castleMove = ChessMove.castling(
            from: king.position,
            to: Position(7, 2), // c8
            piece: king,
          );
          moves.add(castleMove);
        }
      }
    }

    return moves;
  }
}
