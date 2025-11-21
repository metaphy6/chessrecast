import 'package:flutter/material.dart';
import 'package:chess_vectors_flutter/chess_vectors_flutter.dart';
import '../board/utils/exporter.dart';

/// Cached piece widgets to prevent SVG re-parsing on every render
class _PieceWidgetCache {
  // Pre-instantiate all piece widgets for maximum performance
  static final whitePawn = WhitePawn();
  static final whiteKnight = WhiteKnight();
  static final whiteBishop = WhiteBishop();
  static final whiteRook = WhiteRook();
  static final whiteQueen = WhiteQueen();
  static final whiteKing = WhiteKing();

  static final blackPawn = BlackPawn();
  static final blackKnight = BlackKnight();
  static final blackBishop = BlackBishop();
  static final blackRook = BlackRook();
  static final blackQueen = BlackQueen();
  static final blackKing = BlackKing();
}

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
    // Wrap in RepaintBoundary and use cached SVG widgets
    return RepaintBoundary(
      child: SizedBox(
        width: size,
        height: size,
        child: _getCachedPieceWidget(),
      ),
    );
  }

  Widget _getCachedPieceWidget() {
    // Use pre-instantiated widgets from cache - avoids SVG parsing overhead
    if (color == PieceColor.white) {
      switch (type) {
        case PieceType.pawn:
          return _PieceWidgetCache.whitePawn;
        case PieceType.knight:
          return _PieceWidgetCache.whiteKnight;
        case PieceType.bishop:
          return _PieceWidgetCache.whiteBishop;
        case PieceType.rook:
          return _PieceWidgetCache.whiteRook;
        case PieceType.queen:
          return _PieceWidgetCache.whiteQueen;
        case PieceType.king:
          return _PieceWidgetCache.whiteKing;
      }
    } else {
      switch (type) {
        case PieceType.pawn:
          return _PieceWidgetCache.blackPawn;
        case PieceType.knight:
          return _PieceWidgetCache.blackKnight;
        case PieceType.bishop:
          return _PieceWidgetCache.blackBishop;
        case PieceType.rook:
          return _PieceWidgetCache.blackRook;
        case PieceType.queen:
          return _PieceWidgetCache.blackQueen;
        case PieceType.king:
          return _PieceWidgetCache.blackKing;
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
