import 'package:equatable/equatable.dart';
import '../enums/piece_color.dart';
import '../enums/piece_type.dart';
import '../enums/game_status.dart';
import 'position.dart';
import 'piece.dart';
import 'move.dart';
import '../../../../struct/constants/game_types.dart';

class ChessBoard extends Equatable {
  final List<ChessPiece> pieces;
  final PieceColor currentPlayer;
  final GameStatus gameStatus;
  final Position? enPassantTarget;
  final bool whiteCanCastleKingside;
  final bool whiteCanCastleQueenside;
  final bool blackCanCastleKingside;
  final bool blackCanCastleQueenside;
  final int halfMoveClock;
  final int fullMoveNumber;
  final List<ChessMove> moveHistory;
  final GameType gameType;
  final bool whiteHasPromotedKing;
  final bool blackHasPromotedKing;

  const ChessBoard({
    required this.pieces,
    this.currentPlayer = PieceColor.white,
    this.gameStatus = GameStatus.ongoing,
    this.enPassantTarget,
    this.whiteCanCastleKingside = true,
    this.whiteCanCastleQueenside = true,
    this.blackCanCastleKingside = true,
    this.blackCanCastleQueenside = true,
    this.halfMoveClock = 0,
    this.fullMoveNumber = 1,
    this.moveHistory = const [],
    this.gameType = GameType.classic,
    this.whiteHasPromotedKing = false,
    this.blackHasPromotedKing = false,
  });

  /// Creates the initial chess board setup
  factory ChessBoard.initial({GameType gameType = GameType.classic}) {
    final pieces = <ChessPiece>[];

    // Add pawns
    for (int col = 0; col < 8; col++) {
      pieces.add(
        ChessPiece(
          type: PieceType.pawn,
          color: PieceColor.white,
          position: Position(1, col),
        ),
      );
      pieces.add(
        ChessPiece(
          type: PieceType.pawn,
          color: PieceColor.black,
          position: Position(6, col),
        ),
      );
    }

    // Add other pieces
    final pieceOrder = [
      PieceType.rook,
      PieceType.knight,
      PieceType.bishop,
      PieceType.queen,
      PieceType.king,
      PieceType.bishop,
      PieceType.knight,
      PieceType.rook,
    ];

    for (int col = 0; col < 8; col++) {
      pieces.add(
        ChessPiece(
          type: pieceOrder[col],
          color: PieceColor.white,
          position: Position(0, col),
        ),
      );
      pieces.add(
        ChessPiece(
          type: pieceOrder[col],
          color: PieceColor.black,
          position: Position(7, col),
        ),
      );
    }

    return ChessBoard(pieces: pieces, gameType: gameType);
  }

  /// Gets the piece at the specified position
  ChessPiece? getPieceAt(Position position) {
    try {
      return pieces.firstWhere((piece) => piece.position == position);
    } catch (e) {
      return null;
    }
  }

  /// Gets all pieces of the specified color
  List<ChessPiece> getPiecesOfColor(PieceColor color) {
    return pieces.where((piece) => piece.color == color).toList();
  }

  /// Gets the king of the specified color
  ChessPiece? getKing(PieceColor color) {
    try {
      return pieces.firstWhere(
        (piece) => piece.type == PieceType.king && piece.color == color,
      );
    } catch (e) {
      return null;
    }
  }

  /// Checks if the specified position is under attack by the specified color
  bool isPositionUnderAttack(Position position, PieceColor attackingColor) {
    final attackingPieces = getPiecesOfColor(attackingColor);
    return attackingPieces.any((piece) => piece.canAttack(position, pieces));
  }

  /// Checks if the king of the specified color is in check
  bool isKingInCheck(PieceColor kingColor) {
    final king = getKing(kingColor);
    if (king == null) {
      print('🔍 DEBUG: No king found for $kingColor');
      return false;
    }

    print(
      '�🔍 DEBUG: Checking if $kingColor king at ${king.position} is in check',
    );
    final inCheck = isPositionUnderAttack(king.position, kingColor.opposite);
    print(
      '🔍 DEBUG: King at ${king.position} is ${inCheck ? 'IN CHECK' : 'SAFE'}',
    );
    return inCheck;
  }

  /// Gets all valid moves for a piece at the specified position
  List<ChessMove> getValidMovesFor(Position position) {
    final piece = getPieceAt(position);
    if (piece == null || piece.color != currentPlayer) {
      return [];
    }

    print(
      '🎯 GET VALID MOVES: ${piece.color.name} ${piece.type.name} at ${position.algebraic}, gameType = $gameType',
    );

    print(' Using normal _getPotentialMoves() for ${piece.type.name}');
    final potentialMoves = _getPotentialMoves(piece);

    // Filter out moves that would put own king in check
    final safeMoves = potentialMoves.where((move) {
      print(
        '🔍 DEBUG: Validating king safety for move: ${move.from} → ${move.to}, isEnPassant: ${move.isEnPassant}',
      );
      final boardAfterMove = _makeMoveForValidation(move);
      final kingInCheck = boardAfterMove.isKingInCheck(currentPlayer);
      print('🔍 DEBUG: After move simulation, king in check: $kingInCheck');
      if (kingInCheck) {
        print('❌ DEBUG: Move REJECTED - would put king in check');
      } else {
        print('✅ DEBUG: Move ACCEPTED - king is safe');
      }
      return !kingInCheck;
    }).toList();

    return safeMoves;
  }

  /// SNARE MODE: Checks if a move passes through an entangle zone
  /// Returns the first zone position encountered, or null if path doesn't cross zone
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
    final moves = <ChessMove>[];
    final direction = pawn.color == PieceColor.white ? 1 : -1;
    final startRow = pawn.color == PieceColor.white ? 1 : 6;

    // Debug en passant target - always print
    print(
      '🎯 EN PASSANT DEBUG: Target = ${enPassantTarget?.algebraic ?? "NULL"}, Checking pawn at ${pawn.position.algebraic}',
    );

    if (enPassantTarget != null) {
      print(
        '🎯 EN PASSANT: Current target = ${enPassantTarget!.algebraic}, Checking pawn at ${pawn.position.algebraic}',
      );
    }

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
            print(
              '🎯 En passant capture found! Attacking: ${pawn.position.algebraic} → ${capturePos.algebraic}, Captured: ${capturedPawn.position.algebraic}',
            );
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
    return ['Q', 'R', 'B', 'N']; // Standard promotion pieces
  }

  List<ChessMove> _getRookMoves(ChessPiece rook) {
    final moves = <ChessMove>[];
    final directions = [
      [-1, 0], [1, 0], [0, -1], [0, 1], // up, down, left, right
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
      [-1, -1], [-1, 1], [1, -1], [1, 1], // diagonals
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

    // TODO: Add castling logic

    // Add castling moves if conditions are met
    if (king.color == PieceColor.white) {
      // White kingside castling (O-O)
      if (whiteCanCastleKingside && _canCastleKingside(king.color)) {
        final castleMove = ChessMove.castling(
          from: king.position,
          to: Position(0, 6), // g1
          piece: king,
        );
        moves.add(castleMove);
        print(
          '🏰 WHITE KINGSIDE CASTLING move added: ${castleMove.from.algebraic} → ${castleMove.to.algebraic}',
        );
      }

      // White queenside castling (O-O-O)
      if (whiteCanCastleQueenside && _canCastleQueenside(king.color)) {
        final castleMove = ChessMove.castling(
          from: king.position,
          to: Position(0, 2), // c1
          piece: king,
        );
        moves.add(castleMove);
        print(
          '🏰 WHITE QUEENSIDE CASTLING move added: ${castleMove.from.algebraic} → ${castleMove.to.algebraic}',
        );
      }
    } else {
      // Black kingside castling (O-O)
      if (blackCanCastleKingside && _canCastleKingside(king.color)) {
        final castleMove = ChessMove.castling(
          from: king.position,
          to: Position(7, 6), // g8
          piece: king,
        );
        moves.add(castleMove);
        print(
          '🏰 BLACK KINGSIDE CASTLING move added: ${castleMove.from.algebraic} → ${castleMove.to.algebraic}',
        );
      }

      // Black queenside castling (O-O-O)
      if (blackCanCastleQueenside && _canCastleQueenside(king.color)) {
        final castleMove = ChessMove.castling(
          from: king.position,
          to: Position(7, 2), // c8
          piece: king,
        );
        moves.add(castleMove);
        print(
          '🏰 BLACK QUEENSIDE CASTLING move added: ${castleMove.from.algebraic} → ${castleMove.to.algebraic}',
        );
      }
    }

    return moves;
  }

  /// Checks if kingside castling is possible for the given color
  bool _canCastleKingside(PieceColor color) {
    final kingRow = color == PieceColor.white ? 0 : 7;
    final king = getKing(color);

    // King must be on starting square
    if (king == null || king.position != Position(kingRow, 4)) {
      return false;
    }

    // Rook must be on starting square
    final rook = getPieceAt(Position(kingRow, 7));
    if (rook == null || rook.type != PieceType.rook || rook.color != color) {
      return false;
    }

    // Squares between king and rook must be empty
    if (getPieceAt(Position(kingRow, 5)) != null ||
        getPieceAt(Position(kingRow, 6)) != null) {
      return false;
    }

    // King cannot be in check
    if (isKingInCheck(color)) {
      return false;
    }

    // King cannot pass through or land on attacked squares
    if (isPositionUnderAttack(Position(kingRow, 5), color.opposite) ||
        isPositionUnderAttack(Position(kingRow, 6), color.opposite)) {
      return false;
    }

    return true;
  }

  /// Checks if queenside castling is possible for the given color
  bool _canCastleQueenside(PieceColor color) {
    final kingRow = color == PieceColor.white ? 0 : 7;
    final king = getKing(color);

    // King must be on starting square
    if (king == null || king.position != Position(kingRow, 4)) {
      return false;
    }

    // Rook must be on starting square
    final rook = getPieceAt(Position(kingRow, 0));
    if (rook == null || rook.type != PieceType.rook || rook.color != color) {
      return false;
    }

    // Squares between king and rook must be empty
    if (getPieceAt(Position(kingRow, 1)) != null ||
        getPieceAt(Position(kingRow, 2)) != null ||
        getPieceAt(Position(kingRow, 3)) != null) {
      return false;
    }

    // King cannot be in check
    if (isKingInCheck(color)) {
      return false;
    }

    // King cannot pass through or land on attacked squares
    if (isPositionUnderAttack(Position(kingRow, 2), color.opposite) ||
        isPositionUnderAttack(Position(kingRow, 3), color.opposite)) {
      return false;
    }

    return true;
  }

  /// Makes a move for validation purposes (preserves en passant target)
  ChessBoard _makeMoveForValidation(ChessMove move) {
    print(
      '🔍 DEBUG: _makeMoveForValidation called for move: ${move.from} → ${move.to}, isEnPassant: ${move.isEnPassant}',
    );
    final newPieces = List<ChessPiece>.from(pieces);
    print('🔍 DEBUG: Starting with ${newPieces.length} pieces');

    // Remove the moving piece from its current position
    newPieces.removeWhere((piece) => piece.position == move.from);
    print('🔍 DEBUG: After removing moving piece: ${newPieces.length} pieces');

    // Remove captured piece if any
    if (move.capturedPiece != null) {
      print(
        '🔍 DEBUG: Found captured piece: ${move.capturedPiece!.type} ${move.capturedPiece!.color} at ${move.capturedPiece!.position}',
      );
      if (move.isEnPassant) {
        // For en passant, remove the pawn that was captured
        print('🔍 DEBUG: En passant - removing captured pawn');
        final beforeCount = newPieces.length;
        newPieces.removeWhere((piece) => piece == move.capturedPiece);
        print(
          '🔍 DEBUG: Removed ${beforeCount - newPieces.length} pieces, now have ${newPieces.length}',
        );
      } else {
        newPieces.removeWhere((piece) => piece.position == move.to);
        print('🔍 DEBUG: Regular capture - removed piece at destination');
      }
    } else {
      print('🔍 DEBUG: No captured piece');
    }

    // Add the piece to its new position
    newPieces.add(move.piece.movedTo(move.to));
    print(
      '🔍 DEBUG: Added piece to new position: ${move.to}, total pieces: ${newPieces.length}',
    );

    // Handle castling in validation - move the rook as well
    if (move.isCastling) {
      final kingRow = move.from.row;
      final isKingside = move.to.col == 6; // g-file

      if (isKingside) {
        // Kingside castling: move rook from h-file to f-file
        final rook = getPieceAt(Position(kingRow, 7));
        if (rook != null) {
          newPieces.removeWhere(
            (piece) => piece.position == Position(kingRow, 7),
          );
          newPieces.add(rook.movedTo(Position(kingRow, 5))); // f-file
          print(
            '🔍 DEBUG: Castling validation - moved rook for kingside castling',
          );
        }
      } else {
        // Queenside castling: move rook from a-file to d-file
        final rook = getPieceAt(Position(kingRow, 0));
        if (rook != null) {
          newPieces.removeWhere(
            (piece) => piece.position == Position(kingRow, 0),
          );
          newPieces.add(rook.movedTo(Position(kingRow, 3))); // d-file
          print(
            '🔍 DEBUG: Castling validation - moved rook for queenside castling',
          );
        }
      }
    }

    // For validation, preserve the current en passant target
    final result = copyWith(
      pieces: newPieces,
      currentPlayer: currentPlayer.opposite,
      moveHistory: [...moveHistory, move],
      enPassantTarget: enPassantTarget, // Keep current en passant target
    );
    print(
      '🔍 DEBUG: Final validation board has ${result.pieces.length} pieces',
    );
    return result;
  }

  /// Makes a move and returns a new board state
  /// Makes a move and returns a new board state (public method)
  ChessBoard makeMove(ChessMove move) {
    final newPieces = List<ChessPiece>.from(pieces);

    // Remove the moving piece from its current position
    newPieces.removeWhere((piece) => piece.position == move.from);

    // Remove captured piece if any
    if (move.capturedPiece != null) {
      if (move.isEnPassant) {
        // For en passant, remove the pawn that was captured
        newPieces.removeWhere((piece) => piece == move.capturedPiece);
      } else {
        newPieces.removeWhere((piece) => piece.position == move.to);
      }
    }

    // Add the piece to its new position
    if (move.isPromotion) {
      // Handle pawn promotion - create the promoted piece
      PieceType promotedType;
      switch (move.promotionPiece) {
        case 'Q':
          promotedType = PieceType.queen;
          break;
        case 'R':
          promotedType = PieceType.rook;
          break;
        case 'B':
          promotedType = PieceType.bishop;
          break;
        case 'N':
          promotedType = PieceType.knight;
          break;
        case 'K':
          promotedType = PieceType.king;
          print(
            '🔥 HEIR MODE: Promoting pawn to KING at ${move.to.algebraic}!',
          );
          break;
        default:
          promotedType = PieceType.queen; // Default fallback
      }

      newPieces.add(
        ChessPiece(
          type: promotedType,
          color: move.piece.color,
          position: move.to,
        ),
      );
      print(
        '👑 Promotion: ${move.piece.color} pawn → ${move.promotionPiece} at ${move.to.algebraic}',
      );
    } else {
      // Regular move
      newPieces.add(move.piece.movedTo(move.to));
    }

    // Handle castling - move the rook as well
    if (move.isCastling) {
      final kingRow = move.from.row;
      final isKingside = move.to.col == 6; // g-file

      if (isKingside) {
        // Kingside castling: move rook from h-file to f-file
        final rook = getPieceAt(Position(kingRow, 7));
        if (rook != null) {
          newPieces.removeWhere(
            (piece) => piece.position == Position(kingRow, 7),
          );
          newPieces.add(rook.movedTo(Position(kingRow, 5))); // f-file
          print(
            '🏰 Kingside castling: Rook moved from ${Position(kingRow, 7).algebraic} to ${Position(kingRow, 5).algebraic}',
          );
        }
      } else {
        // Queenside castling: move rook from a-file to d-file
        final rook = getPieceAt(Position(kingRow, 0));
        if (rook != null) {
          newPieces.removeWhere(
            (piece) => piece.position == Position(kingRow, 0),
          );
          newPieces.add(rook.movedTo(Position(kingRow, 3))); // d-file
          print(
            '🏰 Queenside castling: Rook moved from ${Position(kingRow, 0).algebraic} to ${Position(kingRow, 3).algebraic}',
          );
        }
      }
    }

    // Determine en passant target for next turn
    Position? newEnPassantTarget;
    if (move.piece.type == PieceType.pawn) {
      // Check if this is a double pawn move
      final rowDiff = (move.to.row - move.from.row).abs();
      print(
        '🔍 EN PASSANT CHECK: ${move.from.algebraic}→${move.to.algebraic}, rowDiff=$rowDiff',
      );
      if (rowDiff == 2) {
        // Set en passant target to the square the pawn passed over
        final targetRow = (move.from.row + move.to.row) ~/ 2;
        newEnPassantTarget = Position(targetRow, move.from.col);
        print('🎯 En passant target set: ${newEnPassantTarget.algebraic}');
      } else {
        print('🚫 Not a double move, clearing en passant target');
      }
    } else {
      print('🚫 Not a pawn move, clearing en passant target');
    }

    // Update castling rights based on piece movements
    bool newWhiteCanCastleKingside = whiteCanCastleKingside;
    bool newWhiteCanCastleQueenside = whiteCanCastleQueenside;
    bool newBlackCanCastleKingside = blackCanCastleKingside;
    bool newBlackCanCastleQueenside = blackCanCastleQueenside;

    // Disable castling if king or rook moves
    if (move.piece.type == PieceType.king) {
      if (move.piece.color == PieceColor.white) {
        newWhiteCanCastleKingside = false;
        newWhiteCanCastleQueenside = false;
      } else {
        newBlackCanCastleKingside = false;
        newBlackCanCastleQueenside = false;
      }
    } else if (move.piece.type == PieceType.rook) {
      if (move.piece.color == PieceColor.white) {
        if (move.from == Position(0, 0)) {
          // a1 rook
          newWhiteCanCastleQueenside = false;
        } else if (move.from == Position(0, 7)) {
          // h1 rook
          newWhiteCanCastleKingside = false;
        }
      } else {
        if (move.from == Position(7, 0)) {
          // a8 rook
          newBlackCanCastleQueenside = false;
        } else if (move.from == Position(7, 7)) {
          // h8 rook
          newBlackCanCastleKingside = false;
        }
      }
    }

    // Also disable castling if rook is captured
    if (move.capturedPiece?.type == PieceType.rook) {
      if (move.to == Position(0, 0)) {
        // a1 rook captured
        newWhiteCanCastleQueenside = false;
      } else if (move.to == Position(0, 7)) {
        // h1 rook captured
        newWhiteCanCastleKingside = false;
      } else if (move.to == Position(7, 0)) {
        // a8 rook captured
        newBlackCanCastleQueenside = false;
      } else if (move.to == Position(7, 7)) {
        // h8 rook captured
        newBlackCanCastleKingside = false;
      }
    }

    // Track king promotions for Heir mode
    bool newWhiteHasPromotedKing = whiteHasPromotedKing;
    bool newBlackHasPromotedKing = blackHasPromotedKing;

    if (gameType == GameType.heir &&
        move.isPromotion &&
        move.promotionPiece == 'K') {
      if (move.piece.color == PieceColor.white) {
        newWhiteHasPromotedKing = true;
        print('👑 HEIR MODE: White has promoted a pawn to King!');
      } else {
        newBlackHasPromotedKing = true;
        print('👑 HEIR MODE: Black has promoted a pawn to King!');
      }
    }

    // Create the new board state first
    final newBoard = copyWith(
      pieces: newPieces,
      currentPlayer: currentPlayer.opposite,
      moveHistory: [...moveHistory, move],
      enPassantTarget: newEnPassantTarget, // Clear or set en passant target
      whiteCanCastleKingside: newWhiteCanCastleKingside,
      whiteCanCastleQueenside: newWhiteCanCastleQueenside,
      blackCanCastleKingside: newBlackCanCastleKingside,
      blackCanCastleQueenside: newBlackCanCastleQueenside,
      whiteHasPromotedKing: newWhiteHasPromotedKing,
      blackHasPromotedKing: newBlackHasPromotedKing,
    );

    // SNARE MODE: Check immediately if ANY king is entangled after the move
    return newBoard;
  }

  /// Creates a copy of the board with updated properties
  ChessBoard copyWith({
    List<ChessPiece>? pieces,
    PieceColor? currentPlayer,
    GameStatus? gameStatus,
    Position? enPassantTarget,
    bool? whiteCanCastleKingside,
    bool? whiteCanCastleQueenside,
    bool? blackCanCastleKingside,
    bool? blackCanCastleQueenside,
    int? halfMoveClock,
    int? fullMoveNumber,
    List<ChessMove>? moveHistory,
    GameType? gameType,
    bool? whiteHasPromotedKing,
    bool? blackHasPromotedKing,
  }) {
    return ChessBoard(
      pieces: pieces ?? this.pieces,
      currentPlayer: currentPlayer ?? this.currentPlayer,
      gameStatus: gameStatus ?? this.gameStatus,
      enPassantTarget: enPassantTarget ?? this.enPassantTarget,
      whiteCanCastleKingside:
          whiteCanCastleKingside ?? this.whiteCanCastleKingside,
      whiteCanCastleQueenside:
          whiteCanCastleQueenside ?? this.whiteCanCastleQueenside,
      blackCanCastleKingside:
          blackCanCastleKingside ?? this.blackCanCastleKingside,
      blackCanCastleQueenside:
          blackCanCastleQueenside ?? this.blackCanCastleQueenside,
      halfMoveClock: halfMoveClock ?? this.halfMoveClock,
      fullMoveNumber: fullMoveNumber ?? this.fullMoveNumber,
      moveHistory: moveHistory ?? this.moveHistory,
      gameType: gameType ?? this.gameType,
      whiteHasPromotedKing: whiteHasPromotedKing ?? this.whiteHasPromotedKing,
      blackHasPromotedKing: blackHasPromotedKing ?? this.blackHasPromotedKing,
    );
  }

  @override
  List<Object?> get props => [
    pieces,
    currentPlayer,
    gameStatus,
    enPassantTarget,
    whiteCanCastleKingside,
    whiteCanCastleQueenside,
    blackCanCastleKingside,
    blackCanCastleQueenside,
    halfMoveClock,
    fullMoveNumber,
    moveHistory,
    gameType,
    whiteHasPromotedKing,
    blackHasPromotedKing,
  ];
}
