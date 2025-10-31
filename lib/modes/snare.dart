import '../board/exporter.dart';
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
/// - If the King is entangled, it's instant checkmate
/// - Pieces can't voluntarily enter entangle zones (except from adjacent squares)
/// - Pieces moving through entangle zones are captured in the zone
/// - Suicide moves (putting own king in check/mate) are legal
/// - When the last knight is captured, it's "revengeful" - both pieces are destroyed
/// - Promotion restrictions: No knights = no promotions, 1 knight = must promote to knight
class Snare extends GameMode {
  /// SNARE MODE: Gets the knights of the specified color
  List<ChessPiece> getKnights(PieceColor color, ChessBoard board) {
    return board.pieces
        .where(
          (piece) => piece.type == PieceType.knight && piece.color == color,
        )
        .toList();
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

    print(
      '🔍 ZONE CALC: ${knight1.position.algebraic} (row=$row1, col=$col1) + ${knight2.position.algebraic} (row=$row2, col=$col2)',
    );

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
      print(
        '🔍 ZONE CALC: Vertical corridor - added ${Position(row1, middleCol).algebraic}, ${Position(row2, middleCol).algebraic}',
      );
    } else if (rowDiff == 2 && colDiff == 1) {
      // Horizontal corridor (2 row difference)
      final minRow = row1 < row2 ? row1 : row2;
      final middleRow = minRow + 1; // The row between the knights

      zone.add(Position(middleRow, col1));
      zone.add(Position(middleRow, col2));
      print(
        '🔍 ZONE CALC: Horizontal corridor - added ${Position(middleRow, col1).algebraic}, ${Position(middleRow, col2).algebraic}',
      );
    } else {
      print(
        '🔍 ZONE CALC: Invalid knight position for entangle - rowDiff=$rowDiff, colDiff=$colDiff',
      );
    }

    print(
      '🕸️ SNARE: Entangle zone between ${knight1.position.algebraic} and ${knight2.position.algebraic}: ${zone.isEmpty ? "EMPTY!" : zone.map((p) => p.algebraic).join(", ")}',
    );

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

    if (entangledPieces.isNotEmpty) {
      print(
        '🕸️ SNARE: ${entangledPieces.length} piece(s) entangled by ${color.name} knights: ${entangledPieces.map((p) => '${p.color.name} ${p.type.name} at ${p.position.algebraic}').join(", ")}',
      );
    }

    return {
      'knights': knights,
      'zone': zone,
      'entangledPieces': entangledPieces,
    };
  }

  /// SNARE MODE: Checks if a piece is currently entangled
  bool isPieceEntangled(ChessPiece piece, ChessBoard board) {
    print(
      '🔍 ENTANGLE CHECK: Checking if ${piece.color.name} ${piece.type.name} at ${piece.position.algebraic} is entangled',
    );

    // Check both colors' knights for entanglement
    for (final color in [PieceColor.white, PieceColor.black]) {
      final info = getEntangleInfo(color, board);
      if (info != null) {
        final entangledPieces = info['entangledPieces'] as List<ChessPiece>;
        print(
          '🔍 ENTANGLE CHECK: ${color.name} knights have ${entangledPieces.length} entangled pieces',
        );

        for (final p in entangledPieces) {
          print(
            '🔍   - ${p.color.name} ${p.type.name} at ${p.position.algebraic}',
          );
          if (p.position == piece.position) {
            print(
              '✅ MATCH FOUND: Piece at ${piece.position.algebraic} IS ENTANGLED',
            );
            return true;
          }
        }
      } else {
        print(
          '🔍 ENTANGLE CHECK: ${color.name} knights have no entangle info (null)',
        );
      }
    }
    print('❌ NO MATCH: Piece at ${piece.position.algebraic} is NOT entangled');
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

    print(
      '🕸️ SNARE: Entangled piece ${piece.type.name} at ${piece.position.algebraic}, ${entangledPieces.length} total entangled',
    );

    // RULE: If only 1 piece entangled, it can move within the zone
    if (entangledPieces.length == 1) {
      for (final zonePos in entangleZone) {
        if (zonePos != piece.position) {
          final targetPiece = board.getPieceAt(zonePos);
          if (targetPiece == null) {
            print('🕸️ SNARE: Can move within zone to ${zonePos.algebraic}');
            moves.add(
              ChessMove.simple(from: piece.position, to: zonePos, piece: piece),
            );
          }
        }
      }
    }

    // RULE: ALL entangled pieces can escape via king-like moves
    print('🕸️ SNARE: Checking escape moves (king-like one square moves)');

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
        print('🕸️ SNARE: ${newPos.algebraic} is still in zone, skip');
        continue;
      }

      final targetPiece = board.getPieceAt(newPos);

      // Can move to empty square or capture enemy piece
      if (targetPiece == null) {
        print('🕸️ SNARE: Can escape to ${newPos.algebraic}');
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
          print(
            '🕸️ SNARE: ${newPos.algebraic} blocked - cannot capture defending knight!',
          );
        } else {
          print(
            '🕸️ SNARE: Can escape and capture ${targetPiece.type.name} at ${newPos.algebraic}',
          );
          moves.add(
            ChessMove.simple(
              from: piece.position,
              to: newPos,
              piece: piece,
              capturedPiece: targetPiece,
            ),
          );
        }
      } else {
        print('🕸️ SNARE: ${newPos.algebraic} blocked by friendly piece');
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
            print(
              '🕸️ SNARE: Can capture entangled enemy ${entangledTarget.type.name} at ${entangledTarget.position.algebraic}',
            );
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

    print(
      '🕸️ SNARE: Total moves for entangled piece (suicide allowed): ${moves.length}',
    );
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
      print('🕸️ SNARE: ${color.name} has no knights - NO PROMOTIONS ALLOWED');
      return [];
    } else if (knights.length == 1) {
      print('🕸️ SNARE: ${color.name} has 1 knight - MUST promote to Knight');
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
      print('🕸️ SNARE: Piece IS ENTANGLED - using entangled piece moves');
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
              print(
                '🕸️ SNARE: Move BLOCKED - cannot enter entangle zone from non-adjacent square',
              );
              moveIntercepted = true;
              break;
            }

            // Allow entry to empty squares
            if (targetPiece == null) {
              print('🕸️ SNARE: Move ALLOWED - entering empty zone');
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
              print('🕸️ SNARE: Move ALLOWED - capturing entangled piece');
              continue;
            }

            print('🕸️ SNARE: Zone occupied by non-entangled piece');
            continue;
          }

          // Check if move passes through the zone
          print(
            '🔍 PATH CHECK: Testing move ${move.from.algebraic} → ${move.to.algebraic}',
          );
          final pathThroughZone = _getPathThroughZone(
            move.from,
            move.to,
            zone,
            board,
          );
          if (pathThroughZone != null) {
            print(
              '🕸️ SNARE: Move INTERCEPTED - captured at ${pathThroughZone.algebraic}',
            );
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
      print(
        '🕸️ SNARE: ${board.currentPlayer.name} King is ENTANGLED - CHECKMATE!',
      );
      return GameStatus.checkmate;
    }

    return null; // Use standard chess rules
  }

  @override
  ChessBoard? handleSpecialMove(ChessBoard board, ChessMove move) {
    // Check for revengeful knight capture
    if (move.capturedPiece != null &&
        move.capturedPiece!.type == PieceType.knight) {
      final capturedKnightColor = move.capturedPiece!.color;
      final defendingKnights = getKnights(capturedKnightColor, board);

      // If this is the last knight, activate revenge
      if (defendingKnights.length == 1 &&
          defendingKnights[0].position == move.capturedPiece!.position) {
        print('⚡ SNARE: Last ${capturedKnightColor.name} knight captured!');
        print('⚡ SNARE: REVENGEFUL KNIGHT - Both pieces destroyed!');

        // Remove both pieces
        final newPieces = board.pieces.where((piece) {
          return piece.position != move.from && piece.position != move.to;
        }).toList();

        return board.copyWith(
          pieces: newPieces,
          currentPlayer: capturedKnightColor, // Turn returns to knight owner
          moveHistory: [...board.moveHistory, move],
        );
      }
    }

    // Check for immediate entanglement after move
    final newBoard = board.makeMove(move);

    // Check if either king is entangled
    if (isKingEntangled(board.currentPlayer, newBoard)) {
      print('🕸️ SNARE: ${board.currentPlayer.name} King ENTANGLED after move');
      return newBoard.copyWith(gameStatus: GameStatus.checkmate);
    }

    if (isKingEntangled(board.currentPlayer.opposite, newBoard)) {
      print(
        '🕸️ SNARE: ${board.currentPlayer.opposite.name} King ENTANGLED after move',
      );
      return newBoard.copyWith(gameStatus: GameStatus.checkmate);
    }

    return null; // Normal move processing
  }
}
