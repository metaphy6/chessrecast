import '../pieces/piece_color.dart';
import '../pieces/piece_type.dart';
import '../../mods/mods.dart';
import 'position.dart';
import 'helpers.dart';
import '../piece.dart';
import 'move.dart';
import '../board.dart';
import 'special_cases.dart';
import 'validation.dart';
// mods.dart already imported above and provides enums and instances

/// Cached mode instances to avoid repeated instantiation
// Use centralized ModsCache for singleton mode instances

/// Extension for move generation operations
extension MoveGeneration on ChessBoard {
  /// Gets all valid moves for a piece at the specified position
  List<ChessMove> getValidMovesFor(Position position) {
    final piece = getPieceAt(position);

    if (piece == null || piece.color != currentPlayer) {
      return [];
    }

    final potentialMoves = _getPotentialMoves(piece);

    // Apply Game Mod specific move filtering first
    final filteredByGameMod = _applyGameModFilter(potentialMoves, piece);

    // Filter out moves that would put own king in check (unless Game Mod allows suicide)
    // Optimize: Pre-allocate result list
    final safeMoves = <ChessMove>[];

    for (final move in filteredByGameMod) {
      // CRITICAL: Never allow capturing the opponent's king
      // Exception: Heir Mod allows king captures as part of the game mechanics
      if (move.capturedPiece != null &&
          move.capturedPiece!.type == PieceType.king &&
          gameType != ModsEnum.heir) {
        continue; // Skip this move
      }

      final boardAfterMove = makeMoveForValidation(move);
      final kingInCheck = boardAfterMove.isKingInCheck(currentPlayer);

      // Truce Mod: Kings can move freely during truce (no check enforcement)
      if (gameType == ModsEnum.truce) {
        if (mods.truce.isTruceActive(this)) {
          // During truce, allow all moves (king can move into "check")
          safeMoves.add(move);
          continue;
        }
        // After truce breaks, apply normal check rules (fall through)
      }

      // Heir Mod: King is a regular piece UNLESS player has promoted or has no pawns
      if (gameType == ModsEnum.heir) {
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

        final heirMode = mods.heir;
        if (!heirMode.shouldApplyCheckRules(currentPlayer, this)) {
          safeMoves.add(move); // No check rules yet
          continue;
        }
        // Check rules apply, fall through to standard validation
      }

      if (!kingInCheck) {
        safeMoves.add(move);
      }
    }

    return safeMoves;
  }

  /// Centralized Game Mod move filtering to reduce duplicated switch/if blocks.
  List<ChessMove> _applyGameModFilter(
    List<ChessMove> potentialMoves,
    ChessPiece piece,
  ) {
    switch (gameType) {
      case ModsEnum.truce:
        return mods.truce.filterMoves(potentialMoves, piece, this);
      case ModsEnum.friendlyFire:
        return mods.friendlyFire.filterMoves(potentialMoves, piece, this);
      case ModsEnum.kingsBattle:
        return mods.kingsBattle.filterMoves(potentialMoves, piece, this);
      case ModsEnum.saveTheQueen:
        return mods.saveTheQueen.filterMoves(potentialMoves, piece, this);
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
    if (gameType == ModsEnum.mercenary) {
      final customMoves = mods.mercenary.getPawnMoves(pawn, this);
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

  /// Gets available promotion pieces based on Game Mod and player state
  List<String> getPromotionPieces(
    PieceColor color, {
    Position? promotionPosition,
  }) {
    // Check for Mercenary Mod - NO promotion
    if (gameType == ModsEnum.mercenary) {
      return []; // No promotion in Mercenary Mod
    }

    // Check for Save the Queen Mod - no queen promotion allowed
    if (gameType == ModsEnum.saveTheQueen) {
      return ['R', 'B', 'N']; // Rook, Bishop, Knight only
    }

    // Check for Heir Mod - can promote to King (with restrictions)
    if (gameType == ModsEnum.heir) {
      final heirMode = mods.heir;
      final options = heirMode.getPromotionPieces(
        color,
        this,
        promotionPosition: promotionPosition,
      );
      if (options != null) {
        return options;
      }
    }

    // Check for Succession Mod - can promote to King
    if (gameType == ModsEnum.succession) {
      final successionMode = mods.succession;
      final options = successionMode.getPromotionPieces(
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

    // Add castling moves if conditions are met
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

    return moves;
  }
}
