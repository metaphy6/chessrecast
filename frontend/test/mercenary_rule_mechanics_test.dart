import 'package:chessrecast/board/utils/exporter.dart';
import 'package:chessrecast/management/orchestrator.dart';
import 'package:chessrecast/mods/enums.dart';
import 'package:flutter_test/flutter_test.dart';

// ignore_for_file: deprecated_member_use

void main() {
  final orchestrator = Orchestrator();

  group('Mercenary: pawn moves in all 8 directions', () {
    test('white pawn on e4 can move forward, backward, and sideways', () {
      // Isolated white pawn on e4 — no enemies, just the two kings.
      // Expected: 8-directional moves, filtered to valid (on-board, empty).
      final board = ChessBoard.fromFEN(
        '8/8/8/8/4P3/8/8/4K2k w - - 0 1',
        gameType: ModsEnum.mercenary,
      );
      final moves = orchestrator.getAllValidMoves(board);
      final pawnMoves = moves.where(
        (m) =>
            m.piece.type == PieceType.pawn &&
            m.from == const Position(3, 4),
      );

      // e4 neighbours: d3,e3,f3,d4,f4,d5,e5,f5 — all 8 are on board and empty
      expect(pawnMoves.length, equals(8));
    });

    test('white pawn can capture diagonally backward (d3 from e4)', () {
      // Black pawn on d3 — Mercenary pawn should be able to capture it.
      final board = ChessBoard.fromFEN(
        '8/8/8/8/4P3/3p4/8/4K2k w - - 0 1',
        gameType: ModsEnum.mercenary,
      );
      final moves = orchestrator.getAllValidMoves(board);
      final backwardCapture = moves.any(
        (m) =>
            m.piece.type == PieceType.pawn &&
            m.from == const Position(3, 4) &&
            m.to == const Position(2, 3) &&
            m.isCapture,
      );

      expect(backwardCapture, isTrue);
    });

    test('white pawn on last rank does NOT promote', () {
      // White pawn on e8 — Mercenary pawns cannot promote, so the move
      // should not generate any promotion variant.
      final board = ChessBoard.fromFEN(
        '4P3/8/8/8/8/8/8/4K2k w - - 0 1',
        gameType: ModsEnum.mercenary,
      );
      final moves = orchestrator.getAllValidMoves(board);
      final promotionMoves = moves.where(
        (m) => m.piece.type == PieceType.pawn && m.isPromotion,
      );

      expect(promotionMoves, isEmpty);
    });

    test('white pawn cannot move two squares forward from start', () {
      final board = ChessBoard.initial(gameType: ModsEnum.mercenary);
      final moves = orchestrator.getAllValidMoves(board);
      final twoSquarePawnPush = moves.any(
        (m) =>
            m.piece.type == PieceType.pawn &&
            (m.to.row - m.from.row).abs() == 2,
      );

      expect(twoSquarePawnPush, isFalse);
    });

    test('no en-passant moves exist in Mercenary', () {
      // Set up a position that would trigger en passant in standard chess:
      // White pawn on d5, black pushes c7-c5 (en passant target c6).
      final board = ChessBoard.fromFEN(
        '8/8/8/3Pp3/8/8/8/4K2k w - e6 0 2',
        gameType: ModsEnum.mercenary,
      );
      final moves = orchestrator.getAllValidMoves(board);
      final enPassantMoves = moves.where((m) => m.isEnPassant);

      expect(enPassantMoves, isEmpty);
    });
  });
}
