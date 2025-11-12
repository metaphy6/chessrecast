import 'package:chessrecast/debug.dart';
import '../types/piece_color.dart';
import '../types/piece_type.dart';
import '../../modes/modes_enum.dart';
import '../entities/position.dart';
import '../entities/piece.dart';
import '../entities/move.dart';
import '../entities/board.dart';
import '../entities/queries.dart';
import 'validation.dart';
import '../../modes/snare.dart';
import '../../modes/diamonds.dart';
import '../../modes/teleport.dart';
import '../../modes/friendly_fire.dart';
import '../../modes/kings_battle.dart';
import '../../modes/save_the_queen.dart';
import '../../modes/save_the_king.dart';
import '../../modes/other_side.dart';
import '../../modes/royal_pawns.dart';

/// Extension for move generation operations
extension MoveGeneration on ChessBoard {
  /// Gets all valid moves for a piece at the specified position
  List<ChessMove> getValidMovesFor(Position position) {
    final piece = getPieceAt(position);

    printDebug('🔍 MOVE GEN: Clicked ${position.algebraic}');
    printDebug(
      '🔍 MOVE GEN: Piece: ${piece != null ? "${piece.color.name} ${piece.type.name}" : "NONE"}',
    );
    printDebug('🔍 MOVE GEN: Current player: ${currentPlayer.name}');
    printDebug('🔍 MOVE GEN: Game type: ${gameType.name}');

    if (piece == null || piece.color != currentPlayer) {
      printDebug('🔍 MOVE GEN: ❌ Returning empty - wrong turn or no piece');
      return [];
    }

    final potentialMoves = _getPotentialMoves(piece);
    printDebug(
      '🔍 MOVE GEN: Potential moves generated: ${potentialMoves.length}',
    );

    // Apply game mode specific move filtering first
    var filteredByGameMode = potentialMoves;

    printDebug(
      '🔍 MOVE GEN: About to apply game mode filtering for ${gameType.name}',
    );

    if (gameType == ModesEnum.snare) {
      final snareMode = Snare();
      filteredByGameMode = snareMode.filterMoves(potentialMoves, piece, this);
      printDebug(
        '🕸️ BOARD: Snare mode filtered moves for ${piece.color.name} ${piece.type.name} at ${piece.position.algebraic}: ${potentialMoves.length} → ${filteredByGameMode.length}',
      );
    } else if (gameType == ModesEnum.diamonds) {
      final diamondsMode = Diamonds();
      filteredByGameMode = diamondsMode.filterMoves(
        potentialMoves,
        piece,
        this,
      );
      printDebug(
        '💎 BOARD: Diamonds mode filtered moves for ${piece.color.name} ${piece.type.name} at ${piece.position.algebraic}: ${potentialMoves.length} → ${filteredByGameMode.length}',
      );
    } else if (gameType == ModesEnum.teleport) {
      final teleportMode = Teleport();
      filteredByGameMode = teleportMode.filterMoves(
        potentialMoves,
        piece,
        this,
      );
      printDebug(
        '🔄 BOARD: Teleport mode filtered moves for ${piece.color.name} ${piece.type.name} at ${piece.position.algebraic}: ${potentialMoves.length} → ${filteredByGameMode.length}',
      );
    } else if (gameType == ModesEnum.friendlyFire) {
      final friendlyFireMode = FriendlyFire();
      filteredByGameMode = friendlyFireMode.filterMoves(
        potentialMoves,
        piece,
        this,
      );
      printDebug(
        '🔥 BOARD: Friendly Fire mode filtered moves for ${piece.color.name} ${piece.type.name} at ${piece.position.algebraic}: ${potentialMoves.length} → ${filteredByGameMode.length}',
      );
    } else if (gameType == ModesEnum.kingsBattle) {
      final kingsBattleMode = KingsBattle();
      filteredByGameMode = kingsBattleMode.filterMoves(
        potentialMoves,
        piece,
        this,
      );
      printDebug(
        '👑 BOARD: Kings Battle mode filtered moves for ${piece.color.name} ${piece.type.name} at ${piece.position.algebraic}: ${potentialMoves.length} → ${filteredByGameMode.length}',
      );
    } else if (gameType == ModesEnum.saveTheQueen) {
      final saveTheQueenMode = SaveTheQueen();
      filteredByGameMode = saveTheQueenMode.filterMoves(
        potentialMoves,
        piece,
        this,
      );
      printDebug(
        '👸 BOARD: Save the Queen mode filtered moves for ${piece.color.name} ${piece.type.name} at ${piece.position.algebraic}: ${potentialMoves.length} → ${filteredByGameMode.length}',
      );
    } else if (gameType == ModesEnum.otherSide) {
      final otherSideMode = OtherSide();
      filteredByGameMode = otherSideMode.filterMoves(
        potentialMoves,
        piece,
        this,
      );
      printDebug(
        '🏰 BOARD: Other Side mode filtered moves for ${piece.color.name} ${piece.type.name} at ${piece.position.algebraic}: ${potentialMoves.length} → ${filteredByGameMode.length}',
      );
    }

    // Filter out moves that would put own king in check (unless game mode allows suicide)
    final safeMoves = filteredByGameMode.where((move) {
      // CRITICAL: Never allow capturing the opponent's king
      // Exception: Heir mode allows king captures as part of the game mechanics
      // Exception: Snare mode allows king capture if it's actually under attack
      if (move.capturedPiece != null &&
          move.capturedPiece!.type == PieceType.king &&
          gameType != ModesEnum.heir) {
        // In Snare mode, allow king capture only if the king is actually under attack
        if (gameType == ModesEnum.snare) {
          final snareMode = Snare();
          final opponentColor = move.capturedPiece!.color;
          // Check if opponent's king is actually capturable (under attack)
          if (!snareMode.isKingCapturable(opponentColor, this)) {
            printDebug(
              '🚫 MOVE GEN: Blocking king capture - king not under attack in Snare mode: ${move.piece.type.name} ${move.from.algebraic} → ${move.to.algebraic}',
            );
            return false;
          }
          // King is capturable - allow the move
          printDebug(
            '⚡ SNARE: Allowing king capture (king is under attack): ${move.piece.type.name} ${move.from.algebraic} → ${move.to.algebraic}',
          );
          return true;
        }

        printDebug(
          '🚫 MOVE GEN: Blocking illegal king capture move: ${move.piece.type.name} ${move.from.algebraic} → ${move.to.algebraic}',
        );
        return false;
      }

      final boardAfterMove = makeMoveForValidation(move);
      final kingInCheck = boardAfterMove.isKingInCheck(currentPlayer);

      // Snare mode allows suicide moves (king moving into danger) ONLY if king has knights
      if (gameType == ModesEnum.snare && piece.type == PieceType.king) {
        final snareMode = Snare();
        final myKnights = snareMode.getKnights(currentPlayer, this);

        if (myKnights.isNotEmpty) {
          // King has knights - allow the move even if it puts king in check
          // King can freely move into entangle zones
          printDebug(
            '🕸️ BOARD: Snare mode - allowing king move to ${move.to.algebraic} (king has ${myKnights.length} knights)',
          );
          return true;
        } else {
          // King has no knights - apply normal check rules
          printDebug(
            '🕸️ BOARD: Snare mode - king has NO knights left, applying normal check rules for move to ${move.to.algebraic}',
          );
        }
      }

      if (kingInCheck) {
      } else {}
      return !kingInCheck;
    }).toList();

    printDebug('🔍 MOVE GEN: Final safe moves: ${safeMoves.length}');
    return safeMoves;
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
      final customMoves = OtherSide().getPawnMoves(pawn, this);
      if (customMoves != null) return customMoves;
    }

    if (gameType == ModesEnum.royalPawns) {
      final customMoves = RoyalPawns().getPawnMoves(pawn, this);
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
        // Add promotion moves
        for (final promotionPiece in getPromotionPieces(
          pawn.color,
          promotionPosition: oneStep,
        )) {
          moves.add(
            ChessMove.promotion(
              from: pawn.position,
              to: oneStep,
              piece: pawn,
              promotionPiece: promotionPiece,
            ),
          );
        }
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
            // Add promotion captures
            for (final promotionPiece in getPromotionPieces(
              pawn.color,
              promotionPosition: capturePos,
            )) {
              moves.add(
                ChessMove.promotion(
                  from: pawn.position,
                  to: capturePos,
                  piece: pawn,
                  capturedPiece: targetPiece,
                  promotionPiece: promotionPiece,
                ),
              );
            }
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
    // Check for Diamonds mode - only bishops allowed
    if (gameType == ModesEnum.diamonds) {
      printDebug(
        '💎 BOARD: Diamonds mode - restricting promotion to Bishop only',
      );
      return ['B']; // Only bishop promotion in Diamonds mode
    }

    // Check for Save the Queen mode - no queen promotion allowed
    if (gameType == ModesEnum.saveTheQueen) {
      printDebug('👸 BOARD: Save the Queen mode - no queen promotion allowed');
      return ['R', 'B', 'N']; // Rook, Bishop, Knight only
    }

    // Check for Other Side mode - no rook promotion allowed
    if (gameType == ModesEnum.otherSide) {
      printDebug('🏰 BOARD: Other Side mode - no rook promotion allowed');
      return ['Q', 'B', 'N']; // Queen, Bishop, Knight only
    }

    // Check for Save the King mode - can promote to King
    if (gameType == ModesEnum.saveTheKing) {
      printDebug(
        '👑 BOARD: Save the King mode - checking King promotion options',
      );
      final saveTheKingMode = SaveTheKing();
      final options = saveTheKingMode.getPromotionPieces(
        color,
        this,
        promotionPosition: promotionPosition,
      );
      if (options != null) {
        printDebug('👑 BOARD: Save the King promotion options: $options');
        return options;
      }
    }

    return ['Q', 'R', 'B', 'N']; // Standard promotion pieces
  }

  List<ChessMove> _getRookMoves(ChessPiece rook) {
    final moves = <ChessMove>[];
    final directions = [
      [-1, 0],
      [1, 0],
      [0, -1],
      [0, 1], // up, down, left, right
    ];

    for (final direction in directions) {
      for (int i = 1; i < 8; i++) {
        final newPos = rook.position.offset(direction[0] * i, direction[1] * i);
        if (!newPos.isValid) break;

        final targetPiece = getPieceAt(newPos);
        if (targetPiece == null) {
          moves.add(
            ChessMove.simple(from: rook.position, to: newPos, piece: rook),
          );
        } else {
          if (targetPiece.color != rook.color) {
            moves.add(
              ChessMove.simple(
                from: rook.position,
                to: newPos,
                piece: rook,
                capturedPiece: targetPiece,
              ),
            );
          }
          break;
        }
      }
    }

    return moves;
  }

  List<ChessMove> _getKnightMoves(ChessPiece knight) {
    final moves = <ChessMove>[];
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

    for (final move in knightMoves) {
      final newPos = knight.position.offset(move[0], move[1]);
      if (!newPos.isValid) continue;

      final targetPiece = getPieceAt(newPos);
      if (targetPiece == null || targetPiece.color != knight.color) {
        moves.add(
          ChessMove.simple(
            from: knight.position,
            to: newPos,
            piece: knight,
            capturedPiece: targetPiece,
          ),
        );
      }
    }

    return moves;
  }

  List<ChessMove> _getBishopMoves(ChessPiece bishop) {
    final moves = <ChessMove>[];
    final directions = [
      [-1, -1],
      [-1, 1],
      [1, -1],
      [1, 1], // diagonals
    ];

    for (final direction in directions) {
      for (int i = 1; i < 8; i++) {
        final newPos = bishop.position.offset(
          direction[0] * i,
          direction[1] * i,
        );
        if (!newPos.isValid) break;

        final targetPiece = getPieceAt(newPos);
        if (targetPiece == null) {
          moves.add(
            ChessMove.simple(from: bishop.position, to: newPos, piece: bishop),
          );
        } else {
          if (targetPiece.color != bishop.color) {
            moves.add(
              ChessMove.simple(
                from: bishop.position,
                to: newPos,
                piece: bishop,
                capturedPiece: targetPiece,
              ),
            );
          }
          break;
        }
      }
    }

    return moves;
  }

  List<ChessMove> _getQueenMoves(ChessPiece queen) {
    return [..._getRookMoves(queen), ..._getBishopMoves(queen)];
  }

  List<ChessMove> _getKingMoves(ChessPiece king) {
    final moves = <ChessMove>[];
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

    for (final direction in directions) {
      final newPos = king.position.offset(direction[0], direction[1]);
      if (!newPos.isValid) continue;

      final targetPiece = getPieceAt(newPos);
      if (targetPiece == null || targetPiece.color != king.color) {
        moves.add(
          ChessMove.simple(
            from: king.position,
            to: newPos,
            piece: king,
            capturedPiece: targetPiece,
          ),
        );
      }
    }

    // Add castling moves if conditions are met (not in Teleport mode)
    if (gameType != ModesEnum.teleport) {
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
