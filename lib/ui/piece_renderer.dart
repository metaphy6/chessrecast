import 'package:flutter/material.dart';
import 'package:chess_vectors_flutter/chess_vectors_flutter.dart';
import '../board/exporter.dart';

/// Widget that renders a chess piece using SVG graphics from chess_vectors_flutter
class PieceRenderer extends StatelessWidget {
  final PieceType type;
  final PieceColor color;
  final double size;

  const PieceRenderer({
    super.key,
    required this.type,
    required this.color,
    this.size = 45.0,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: size, height: size, child: _getPieceWidget());
  }

  Widget _getPieceWidget() {
    // chess_vectors_flutter provides beautiful SVG pieces
    // They automatically handle sizing and rendering

    if (color == PieceColor.white) {
      switch (type) {
        case PieceType.pawn:
          return WhitePawn();
        case PieceType.knight:
          return WhiteKnight();
        case PieceType.bishop:
          return WhiteBishop();
        case PieceType.rook:
          return WhiteRook();
        case PieceType.queen:
          return WhiteQueen();
        case PieceType.king:
          return WhiteKing();
      }
    } else {
      switch (type) {
        case PieceType.pawn:
          return BlackPawn();
        case PieceType.knight:
          return BlackKnight();
        case PieceType.bishop:
          return BlackBishop();
        case PieceType.rook:
          return BlackRook();
        case PieceType.queen:
          return BlackQueen();
        case PieceType.king:
          return BlackKing();
      }
    }
  }
}

/// Helper extension to get piece renderer from ChessPiece
extension ChessPieceRenderer on ChessPiece {
  Widget toWidget({double size = 45.0}) {
    return PieceRenderer(type: type, color: color, size: size);
  }
}
