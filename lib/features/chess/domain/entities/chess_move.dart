import 'package:equatable/equatable.dart';
import 'position.dart';
import 'chess_piece.dart';

class ChessMove extends Equatable {
  final Position from;
  final Position to;
  final ChessPiece piece;
  final ChessPiece? capturedPiece;
  final bool isEnPassant;
  final bool isCastling;
  final bool isPromotion;
  final String? promotionPiece;

  const ChessMove({
    required this.from,
    required this.to,
    required this.piece,
    this.capturedPiece,
    this.isEnPassant = false,
    this.isCastling = false,
    this.isPromotion = false,
    this.promotionPiece,
  });

  /// Creates a simple move without special conditions
  factory ChessMove.simple({
    required Position from,
    required Position to,
    required ChessPiece piece,
    ChessPiece? capturedPiece,
  }) {
    return ChessMove(
      from: from,
      to: to,
      piece: piece,
      capturedPiece: capturedPiece,
    );
  }

  /// Creates a castling move
  factory ChessMove.castling({
    required Position from,
    required Position to,
    required ChessPiece piece,
  }) {
    return ChessMove(from: from, to: to, piece: piece, isCastling: true);
  }

  /// Creates an en passant move
  factory ChessMove.enPassant({
    required Position from,
    required Position to,
    required ChessPiece piece,
    required ChessPiece capturedPiece,
  }) {
    return ChessMove(
      from: from,
      to: to,
      piece: piece,
      capturedPiece: capturedPiece,
      isEnPassant: true,
    );
  }

  /// Creates a promotion move
  factory ChessMove.promotion({
    required Position from,
    required Position to,
    required ChessPiece piece,
    required String promotionPiece,
    ChessPiece? capturedPiece,
  }) {
    return ChessMove(
      from: from,
      to: to,
      piece: piece,
      capturedPiece: capturedPiece,
      isPromotion: true,
      promotionPiece: promotionPiece,
    );
  }

  /// Returns true if this move captures an opponent's piece
  bool get isCapture => capturedPiece != null;

  /// Returns the algebraic notation for this move
  String get algebraicNotation {
    String notation = '';

    // Add piece symbol (except for pawns)
    if (piece.type.name != 'pawn') {
      notation += piece.type.symbol.toUpperCase();
    }

    // Add capture indicator
    if (isCapture) {
      if (piece.type.name == 'pawn') {
        notation += from.algebraic[0]; // file of origin for pawn captures
      }
      notation += 'x';
    }

    // Add destination
    notation += to.algebraic;

    // Add special move indicators
    if (isPromotion && promotionPiece != null) {
      notation += '=${promotionPiece!.toUpperCase()}';
    }

    if (isCastling) {
      // Determine if it's kingside or queenside castling
      if (to.col > from.col) {
        notation = 'O-O'; // Kingside
      } else {
        notation = 'O-O-O'; // Queenside
      }
    }

    if (isEnPassant) {
      notation += ' e.p.';
    }

    return notation;
  }

  /// Creates a copy of this move with updated properties
  ChessMove copyWith({
    Position? from,
    Position? to,
    ChessPiece? piece,
    ChessPiece? capturedPiece,
    bool? isEnPassant,
    bool? isCastling,
    bool? isPromotion,
    String? promotionPiece,
  }) {
    return ChessMove(
      from: from ?? this.from,
      to: to ?? this.to,
      piece: piece ?? this.piece,
      capturedPiece: capturedPiece ?? this.capturedPiece,
      isEnPassant: isEnPassant ?? this.isEnPassant,
      isCastling: isCastling ?? this.isCastling,
      isPromotion: isPromotion ?? this.isPromotion,
      promotionPiece: promotionPiece ?? this.promotionPiece,
    );
  }

  @override
  List<Object?> get props => [
    from,
    to,
    piece,
    capturedPiece,
    isEnPassant,
    isCastling,
    isPromotion,
    promotionPiece,
  ];

  @override
  String toString() => algebraicNotation;
}
