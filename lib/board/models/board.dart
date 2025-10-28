import 'package:equatable/equatable.dart';
import '../enums/piece_color.dart';
import '../enums/piece_type.dart';
import '../enums/game_status.dart';
import 'position.dart';
import 'piece.dart';
import 'move.dart';
import '../enums/modes.dart';

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
      // For Save the Queen mode, swap queen positions
      if (gameType == GameType.saveTheQueen &&
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

    print(
      '👸 BOARD INIT: Creating Save the Queen board with ${pieces.length} pieces',
    );
    if (gameType == GameType.saveTheQueen) {
      // Debug: Print all piece positions
      for (final piece in pieces) {
        print(
          '👸 BOARD INIT: ${piece.color.name} ${piece.type.name} at ${piece.position.algebraic}',
        );
      }
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
