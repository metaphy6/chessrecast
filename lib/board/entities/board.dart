import 'package:chessrecast/debug.dart';
import 'package:equatable/equatable.dart';
import '../types/piece_color.dart';
import '../types/piece_type.dart';
import '../types/game_status.dart';
import 'position.dart';
import 'piece.dart';
import 'move.dart';
import '../../modes/modes_enum.dart';
import '../../modes/save_the_king.dart';

/// Core ChessBoard class with state and basic operations
class ChessBoard extends Equatable {
  final List<ChessPiece> pieces;
  final PieceColor currentPlayer;
  final GameStatus gameStatus;
  final Position? enPassantTarget;
  final bool whiteCanCastleKingside;
  final bool whiteCanCastleQueenside;
  final bool blackCanCastleKingside;
  final bool blackCanCastleQueenside;
  final int halfMoveClock; // For 50-move rule
  final int fullMoveNumber;
  final List<ChessMove> moveHistory;
  final ModesEnum gameType;
  final bool whiteHasPromotedKing;
  final bool blackHasPromotedKing;
  final List<String> positionHistory; // For threefold repetition

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
    this.gameType = ModesEnum.classic,
    this.whiteHasPromotedKing = false,
    this.blackHasPromotedKing = false,
    this.positionHistory = const [],
  });

  /// Creates the initial chess board setup
  factory ChessBoard.initial({ModesEnum gameType = ModesEnum.classic}) {
    // Special handling for Save the King mode - uses custom initial setup
    if (gameType == ModesEnum.saveTheKing) {
      return SaveTheKing.getInitialBoard();
    }

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
      // For Save the Queen mode, swap queen positions
      if (gameType == ModesEnum.saveTheQueen &&
          pieceOrder[col] == PieceType.queen) {
        // White queen goes to d8 (black's side)
        pieces.add(
          ChessPiece(
            type: PieceType.queen,
            color: PieceColor.white,
            position: Position(7, col), // d8 (row 7, col 3)
          ),
        );
        // Black queen goes to d1 (white's side)
        pieces.add(
          ChessPiece(
            type: PieceType.queen,
            color: PieceColor.black,
            position: Position(0, col), // d1 (row 0, col 3)
          ),
        );
      } else {
        // Normal positioning for other pieces and other game modes
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
    }

    printDebug(
      '👸 BOARD INIT: Creating Save the Queen board with ${pieces.length} pieces',
    );
    if (gameType == ModesEnum.saveTheQueen) {
      // Debug: Print all piece positions
      for (final piece in pieces) {
        printDebug(
          '👸 BOARD INIT: ${piece.color.name} ${piece.type.name} at ${piece.position.algebraic}',
        );
      }
    }

    final board = ChessBoard(pieces: pieces, gameType: gameType);
    // Add initial position to history for threefold repetition tracking
    return board.copyWith(positionHistory: [board.getPositionKey()]);
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
    // Optimize with pre-allocated list for hot path performance
    final result = <ChessPiece>[];
    for (final piece in pieces) {
      if (piece.color == color) {
        result.add(piece);
      }
    }
    return result;
  }

  /// Gets the king of the specified color
  ChessPiece? getKing(PieceColor color) {
    // Direct iteration is faster than firstWhere with exception
    for (final piece in pieces) {
      if (piece.type == PieceType.king && piece.color == color) {
        return piece;
      }
    }
    return null;
  }

  /// Generates a unique key for the current position (for threefold repetition)
  /// Includes piece positions, current player, castling rights, and en passant
  /// OPTIMIZED: Avoid expensive string operations on every move
  String getPositionKey() {
    // Use StringBuffer for efficient string building
    final buffer = StringBuffer();

    // Sort pieces by position for consistent ordering (cached pattern)
    final sortedPieces = <ChessPiece>[];
    for (final piece in pieces) {
      sortedPieces.add(piece);
    }
    sortedPieces.sort((a, b) {
      if (a.position.row != b.position.row) {
        return a.position.row.compareTo(b.position.row);
      }
      return a.position.col.compareTo(b.position.col);
    });

    // Build string efficiently with StringBuffer
    bool first = true;
    for (final p in sortedPieces) {
      if (!first) buffer.write('|');
      first = false;

      buffer.write(p.color == PieceColor.white ? 'W' : 'B');
      buffer.write(p.type.name[0].toUpperCase());
      buffer.write(p.position.algebraic);
    }

    buffer.write(':');
    buffer.write(currentPlayer == PieceColor.white ? 'W' : 'B');
    buffer.write(':');

    // Castling rights
    if (whiteCanCastleKingside) buffer.write('K');
    if (whiteCanCastleQueenside) buffer.write('Q');
    if (blackCanCastleKingside) buffer.write('k');
    if (blackCanCastleQueenside) buffer.write('q');

    buffer.write(':');
    buffer.write(enPassantTarget?.algebraic ?? '-');

    return buffer.toString();
  }

  /// Checks if the 50-move rule applies (draw available)
  bool canClaimFiftyMoveRule() {
    return halfMoveClock >= 100; // 100 half-moves = 50 full moves
  }

  /// Checks if threefold repetition has occurred (draw available)
  /// OPTIMIZED: Early exit and reduced debug logging
  bool hasThreefoldRepetition() {
    if (positionHistory.isEmpty) return false;

    final currentPosition = getPositionKey();
    int count = 1; // Start at 1 to count the current position

    // Early exit optimization - stop counting after we reach 3
    for (int i = 0; i < positionHistory.length; i++) {
      if (positionHistory[i] == currentPosition) {
        count++;
        if (count >= 3) {
          printDebug('🔁 THREEFOLD REPETITION DETECTED');
          return true;
        }
      }
    }

    return false;
  }

  /// Checks if draw conditions are met (50-move rule or threefold repetition)
  bool shouldAutoDraw() {
    return canClaimFiftyMoveRule() || hasThreefoldRepetition();
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
    ModesEnum? gameType,
    bool? whiteHasPromotedKing,
    bool? blackHasPromotedKing,
    List<String>? positionHistory,
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
      positionHistory: positionHistory ?? this.positionHistory,
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
    positionHistory,
  ];
}
