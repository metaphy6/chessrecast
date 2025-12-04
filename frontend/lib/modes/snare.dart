import '../board/utils/exporter.dart';
import 'game_mode.dart';

/// SNARE MODE: Knights create entangle zones that trap enemy pieces
///
/// Rules:
/// - When two knights of the same color defend each other (knight's move apart),
///   they create an "entangle zone" in the 2 squares between them
/// - Pieces in the entangle zone are trapped and can only:
///   * Move one square in any direction (king-like moves) to escape
///   * Move within the zone if alone
///   * Capture adjacent entangled enemy pieces
/// - King can move anywhere as long as at least one knight of the same color is alive
/// - Pieces can't voluntarily enter entangle zones (except from adjacent squares)
/// - Pieces moving through entangle zones are captured in the zone
/// - Suicide moves (putting own king in check/mate) are legal
/// - When the last knight is captured, it's "revengeful" - both pieces are destroyed
/// - Promotion restrictions: No knights = no promotions, 1 knight = must promote to knight
class Snare extends GameMode {
  @Deprecated(
    'Use the `modes.snare` alias from modes_cache.dart instead of direct instantiation',
  )
  const Snare();

  /// SNARE MODE: Gets the knights of the specified color
  List<ChessPiece> getKnights(PieceColor color, ChessBoard board) {
    return board.pieces
        .where(
          (piece) => piece.type == PieceType.knight && piece.color == color,
        )
        .toList();
  }

  /// SNARE MODE: Override isKingInCheck - King cannot be in check if at least one knight is alive
  /// This is for status display and move restrictions, NOT for actual capture eligibility
  bool isKingInCheckSnare(PieceColor kingColor, ChessBoard board) {
    // If the king's color has no knights, use normal check rules
    final myKnights = getKnights(kingColor, board);
    if (myKnights.isEmpty) {
      // No knights - use normal check logic
      final king = board.getKing(kingColor);
      if (king == null) return false;
      return board.isPositionUnderAttack(king.position, kingColor.opposite);
    }

    // King has at least one knight - king cannot be in check
    // King moves freely as long as knights are alive
    return false;
  }

  /// SNARE MODE: Check if king is actually capturable (can be eaten by opponent)
  /// This is different from isKingInCheckSnare - king is only capturable if it has knights
  bool isKingCapturable(PieceColor kingColor, ChessBoard board) {
    final king = board.getKing(kingColor);
    if (king == null) return false;

    // King cannot be captured if all knights are gone (only the last knight can be captured)
    final myKnights = getKnights(kingColor, board);
    if (myKnights.isEmpty) return false;

    // King is capturable if it has knights and any enemy piece can attack it
    return board.isPositionUnderAttack(king.position, kingColor.opposite);
  }

  /// SNARE MODE: Checks if two knights defend each other (creating an entangle zone)
  bool _areKnightsDefending(
    ChessPiece knight1,
    ChessPiece knight2,
    ChessBoard board,
  ) {
    // Check if knight1 can attack knight2's position
    if (!knight1.canAttack(knight2.position, board.pieces)) return false;
    // Check if knight2 can attack knight1's position
    if (!knight2.canAttack(knight1.position, board.pieces)) return false;
    return true;
  }

  /// SNARE MODE: Gets the entangle zone positions between two defending knights
  List<Position> _getEntangleZone(ChessPiece knight1, ChessPiece knight2) {
    final zone = <Position>[];

    final row1 = knight1.position.row;
    final col1 = knight1.position.col;
    final row2 = knight2.position.row;
    final col2 = knight2.position.col;

    // Determine if knights form a vertical or horizontal corridor
    final rowDiff = (row1 - row2).abs();
    final colDiff = (col1 - col2).abs();

    // For a knight move, one diff is 1 and the other is 2
    if (rowDiff == 1 && colDiff == 2) {
      // Vertical corridor (2 column difference)
      final minCol = col1 < col2 ? col1 : col2;
      final middleCol = minCol + 1; // The column between the knights

      zone.add(Position(row1, middleCol));
      zone.add(Position(row2, middleCol));
    } else if (rowDiff == 2 && colDiff == 1) {
      // Horizontal corridor (2 row difference)
      final minRow = row1 < row2 ? row1 : row2;
      final middleRow = minRow + 1; // The row between the knights

      zone.add(Position(middleRow, col1));
      zone.add(Position(middleRow, col2));
    }

    return zone;
  }

  /// SNARE MODE: Gets all entangled pieces for a given color
  Map<String, dynamic>? getEntangleInfo(PieceColor color, ChessBoard board) {
    final knights = getKnights(color, board);
    if (knights.length != 2) return null;

    // Check if the two knights defend each other
    if (!_areKnightsDefending(knights[0], knights[1], board)) return null;

    // Get the entangle zone
    final zone = _getEntangleZone(knights[0], knights[1]);
    if (zone.isEmpty) return null;

    // Find all pieces in the entangle zone
    final entangledPieces = board.pieces.where((piece) {
      return zone.any((pos) => pos == piece.position);
    }).toList();

    return {
      'knights': knights,
      'zone': zone,
      'entangledPieces': entangledPieces,
    };
  }

  /// SNARE MODE: Checks if a piece is currently entangled
  bool isPieceEntangled(ChessPiece piece, ChessBoard board) {
    // Check both colors' knights for entanglement
    for (final color in [PieceColor.white, PieceColor.black]) {
      final info = getEntangleInfo(color, board);
      if (info != null) {
        final entangledPieces = info['entangledPieces'] as List<ChessPiece>;
        for (final p in entangledPieces) {
          if (p.position == piece.position) {
            return true;
          }
        }
      }
    }
    return false;
  }

  /// SNARE MODE: Gets the entangle zone positions that trap this piece
  List<Position>? getEntangleZoneForPiece(ChessPiece piece, ChessBoard board) {
    for (final color in [PieceColor.white, PieceColor.black]) {
      final info = getEntangleInfo(color, board);
      if (info != null) {
        final entangledPieces = info['entangledPieces'] as List<ChessPiece>;
        if (entangledPieces.any((p) => p.position == piece.position)) {
          return info['zone'] as List<Position>;
        }
      }
    }
    return null;
  }

  /// SNARE MODE: Checks if the king is entangled (instant mate condition)
  bool isKingEntangled(PieceColor kingColor, ChessBoard board) {
    final king = board.getKing(kingColor);
    if (king == null) return false;

    return isPieceEntangled(king, board);
  }

  /// SNARE MODE: Gets valid moves for an entangled piece
  List<ChessMove> _getEntangledPieceMoves(ChessPiece piece, ChessBoard board) {
    final moves = <ChessMove>[];
    final entangleZone = getEntangleZoneForPiece(piece, board);
    if (entangleZone == null) return moves;

    // Count how many pieces are in the entangle (including this one)
    final entangledPieces = board.pieces.where((p) {
      return entangleZone.any((pos) => pos == p.position);
    }).toList();

    // RULE: If only 1 piece entangled, it can move within the zone
    if (entangledPieces.length == 1) {
      for (final zonePos in entangleZone) {
        if (zonePos != piece.position) {
          final targetPiece = board.getPieceAt(zonePos);
          if (targetPiece == null) {
            moves.add(
              ChessMove.simple(from: piece.position, to: zonePos, piece: piece),
            );
          }
        }
      }
    }

    // RULE: ALL entangled pieces can escape via king-like moves

    final escapeOffsets = [
      [-1, -1],
      [-1, 0],
      [-1, 1],
      [0, -1],
      [0, 1],
      [1, -1],
      [1, 0],
      [1, 1],
    ];

    for (final offset in escapeOffsets) {
      final newPos = piece.position.offset(offset[0], offset[1]);
      if (!newPos.isValid) continue;

      // Can't escape to a position still in the entangle zone
      if (entangleZone.any((pos) => pos == newPos)) {
        continue;
      }

      final targetPiece = board.getPieceAt(newPos);

      // Can move to empty square or capture enemy piece
      if (targetPiece == null) {
        moves.add(
          ChessMove.simple(from: piece.position, to: newPos, piece: piece),
        );
      } else if (targetPiece.color != piece.color) {
        // RULE: Entangled pieces CANNOT capture the defending knights
        final defendingKnights = getKnights(targetPiece.color, board);
        final isDefendingKnight =
            defendingKnights.length == 2 &&
            defendingKnights.any(
              (knight) => knight.position == targetPiece.position,
            ) &&
            _areKnightsDefending(
              defendingKnights[0],
              defendingKnights[1],
              board,
            );

        if (isDefendingKnight) {
          // Cannot capture defending knight
        } else {
          moves.add(
            ChessMove.simple(
              from: piece.position,
              to: newPos,
              piece: piece,
              capturedPiece: targetPiece,
            ),
          );
        }
      }
    }

    // RULE: Entangled pieces of opposite colors can capture each other (one square away)
    if (entangledPieces.length >= 2) {
      for (final entangledTarget in entangledPieces) {
        if (entangledTarget.color != piece.color) {
          final rowDiff = (entangledTarget.position.row - piece.position.row)
              .abs();
          final colDiff = (entangledTarget.position.col - piece.position.col)
              .abs();

          if (rowDiff <= 1 && colDiff <= 1 && (rowDiff > 0 || colDiff > 0)) {
            moves.add(
              ChessMove.simple(
                from: piece.position,
                to: entangledTarget.position,
                piece: piece,
                capturedPiece: entangledTarget,
              ),
            );
          }
        }
      }
    }

    return moves;
  }

  /// SNARE MODE: Checks if a move passes through an entangle zone
  Position? _getPathThroughZone(
    Position from,
    Position to,
    List<Position> zone,
    ChessBoard board,
  ) {
    final path = _getPathBetween(from, to);

    for (final pos in path) {
      if (pos != from && zone.contains(pos)) {
        return pos;
      }
    }

    return null;
  }

  /// Helper: Gets all positions along a straight line path
  List<Position> _getPathBetween(Position from, Position to) {
    final path = <Position>[];

    final rowDiff = to.row - from.row;
    final colDiff = to.col - from.col;

    final rowStep = rowDiff == 0 ? 0 : (rowDiff > 0 ? 1 : -1);
    final colStep = colDiff == 0 ? 0 : (colDiff > 0 ? 1 : -1);

    if (rowStep == 0 && colStep == 0) return path;
    if (rowStep != 0 && colStep != 0 && rowDiff.abs() != colDiff.abs()) {
      return path;
    }

    int currentRow = from.row;
    int currentCol = from.col;

    while (currentRow != to.row || currentCol != to.col) {
      path.add(Position(currentRow, currentCol));
      currentRow += rowStep;
      currentCol += colStep;
    }
    path.add(to);

    return path;
  }

  @override
  List<String>? getPromotionPieces(
    PieceColor color,
    ChessBoard board, {
    Position? promotionPosition,
  }) {
    final knights = getKnights(color, board);

    if (knights.isEmpty) {
      return [];
    } else if (knights.length == 1) {
      return ['N'];
    }

    return null; // Use standard promotions if 2 knights exist
  }

  @override
  List<ChessMove> filterMoves(
    List<ChessMove> moves,
    ChessPiece piece,
    ChessBoard board,
  ) {
    // Handle entangled pieces
    if (isPieceEntangled(piece, board)) {
      return _getEntangledPieceMoves(piece, board);
    }

    // Filter out moves INTO or THROUGH entangle zones
    final filteredMoves = <ChessMove>[];

    for (final move in moves) {
      bool moveIntercepted = false;

      for (final color in [PieceColor.white, PieceColor.black]) {
        final info = getEntangleInfo(color, board);
        if (info != null) {
          final zone = info['zone'] as List<Position>;

          // Check if destination is in the zone
          if (zone.any((pos) => pos == move.to)) {
            final targetPiece = board.getPieceAt(move.to);

            // Check if move is from adjacent square or already in zone
            final rowDiff = (move.to.row - move.from.row).abs();
            final colDiff = (move.to.col - move.from.col).abs();
            final isAdjacentMove = (rowDiff <= 1 && colDiff <= 1);
            final isAlreadyInZone = zone.any((pos) => pos == move.from);

            if (!isAdjacentMove && !isAlreadyInZone) {
              moveIntercepted = true;
              break;
            }

            // Allow entry to empty squares
            if (targetPiece == null) {
              continue;
            }

            // Allow capturing entangled enemy pieces
            final entangledPieces =
                info['entangledPieces'] as List<ChessPiece>?;
            final isTargetEntangled =
                entangledPieces != null &&
                entangledPieces.any(
                  (entangledPiece) =>
                      entangledPiece.position == move.to &&
                      entangledPiece.color != piece.color,
                );

            if (isTargetEntangled) {
              continue;
            }

            continue;
          }

          // Check if move passes through the zone
          final pathThroughZone = _getPathThroughZone(
            move.from,
            move.to,
            zone,
            board,
          );
          if (pathThroughZone != null) {
            final interceptedMove = ChessMove.simple(
              from: move.from,
              to: pathThroughZone,
              piece: move.piece,
              capturedPiece: move.capturedPiece,
            );
            filteredMoves.add(interceptedMove);
            moveIntercepted = true;
            break;
          }
        }
      }

      if (!moveIntercepted) {
        filteredMoves.add(move);
      }
    }

    return filteredMoves;
  }

  @override
  GameStatus? updateGameStatus(
    ChessBoard board,
    bool currentPlayerInCheck,
    bool hasValidMoves,
  ) {
    // If game is already over, don't overwrite
    if (board.gameStatus != GameStatus.ongoing) {
      return board.gameStatus;
    }

    // Check if current player's King is entangled (instant mate)
    if (isKingEntangled(board.currentPlayer, board)) {
      return GameStatus.checkmate;
    }

    return null; // Use standard chess rules
  }

  @override
  ChessBoard? handleSpecialMove(ChessBoard board, ChessMove move) {
    // Check for revengeful knight capture (BEFORE the move is executed)
    if (move.capturedPiece != null &&
        move.capturedPiece!.type == PieceType.knight) {
      final capturedKnightColor = move.capturedPiece!.color;
      // Count knights BEFORE capture to see if this is the last one
      final defendingKnights = getKnights(capturedKnightColor, board);

      // If capturing the last knight, activate revenge
      if (defendingKnights.length == 1) {
        // Execute the move first to get the new board state
        final newBoard = board.makeMove(move);

        // Remove the attacking piece (it gets destroyed by revenge)
        final newPieces = newBoard.pieces.where((piece) {
          return piece.position != move.to;
        }).toList();

        // Don't switch turn back - keep it as is after makeMove
        // If the attacker was a King, the game will end with the attacker losing
        return newBoard.copyWith(pieces: newPieces);
      }
    }

    // Check for immediate entanglement after move
    final newBoard = board.makeMove(move);

    // Only trigger checkmate if a knight move CREATES a NEW entangle zone that traps a king
    // Self-checkmate happens when a player moves their own knight in a way that creates
    // an entangle zone catching a king (could be own or opponent's king)
    if (move.piece.type == PieceType.knight) {
      // Check both players' kings
      for (final kingColor in [PieceColor.white, PieceColor.black]) {
        // Check if king was entangled BEFORE this move
        final kingWasEntangledBefore = isKingEntangled(kingColor, board);

        // Check if king is entangled AFTER this move
        final kingIsEntangledAfter = isKingEntangled(kingColor, newBoard);

        // Self-checkmate only happens if king was NOT entangled before, but IS entangled after
        // This means the knight move created a NEW zone that caught the king
        if (!kingWasEntangledBefore && kingIsEntangledAfter) {
          return newBoard.copyWith(gameStatus: GameStatus.checkmate);
        }
      }
    }

    return null; // Normal move processing
  }
}
