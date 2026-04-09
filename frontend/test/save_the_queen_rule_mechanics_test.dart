import 'package:chessrecast/board/utils/exporter.dart';
import 'package:chessrecast/management/orchestrator.dart';
import 'package:chessrecast/mods/enums.dart';
import 'package:flutter_test/flutter_test.dart';

// ignore_for_file: deprecated_member_use

/// White queen starts imprisoned at d8 (row=0, col=3).
/// Black queen starts imprisoned at d1 (row=7, col=3).
void main() {
  final orchestrator = Orchestrator();

  group('Save the Queen: prisoner queen moves like a king', () {
    test(
      'white prisoner queen generates only king-like non-capturing moves',
      () {
        // White queen at d8 (the prison); nothing nearby.
        final board = ChessBoard.fromFEN(
          '3Q4/8/8/8/8/8/8/3qK2k w - - 0 1',
          gameType: ModsEnum.saveTheQueen,
        );
        final moves = orchestrator.getAllValidMoves(board);
        final queenMoves = moves.where(
          (m) =>
              m.piece.type == PieceType.queen &&
              m.piece.color == PieceColor.white,
        );

        // All queen moves should be king-like (max 1 step in any direction),
        // and none should be captures.
        for (final m in queenMoves) {
          final rowDelta = (m.to.row - m.from.row).abs();
          final colDelta = (m.to.col - m.from.col).abs();
          expect(rowDelta, lessThanOrEqualTo(1));
          expect(colDelta, lessThanOrEqualTo(1));
          expect(m.isCapture, isFalse);
        }

        // d8 has 3 neighbours in valid directions (c7, d7, e7)
        expect(queenMoves.length, greaterThanOrEqualTo(3));
      },
    );
  });

  group('Save the Queen: escaped queen has full power in own half', () {
    test('white queen escaped to d4 can reach any empty square in own half', () {
      // White queen has crossed to its own half (rows 4-7 for white when board
      // is row 0=rank8, row 7=rank1 — own half for white is rows 4-7).
      // Place white queen at d4 in a mostly-empty board.
      final board = ChessBoard.fromFEN(
        '8/8/8/8/3Q4/8/8/4K2k w - - 0 1',
        gameType: ModsEnum.saveTheQueen,
      );
      final moves = orchestrator.getAllValidMoves(board);
      final queenMoves = moves.where(
        (m) =>
            m.piece.type == PieceType.queen &&
            m.piece.color == PieceColor.white,
      );

      // An unobstructed queen at d4 has 27 moves in standard chess.
      // In SaveTheQueen, moves that bring the queen back into opponent's half
      // are limited to king-like steps, reducing the count slightly.
      // There should be at least 10 queen moves (well more than the 3-8 from prison).
      expect(queenMoves.length, greaterThan(10));
    });
  });

  group(
    'Save the Queen: prisoner cannot be captured while prison is occupied',
    () {
      test('enemy piece cannot capture prisoner queen on prison square', () {
        // Black queen imprisoned at d1 (row=7,col=3). White rook on e1 could
        // normally slide to d1, but prison immunity should block this.
        final board = ChessBoard.fromFEN(
          '3Q4/8/8/8/8/8/8/3qR1K1 w - - 0 1',
          gameType: ModsEnum.saveTheQueen,
        );
        final moves = orchestrator.getAllValidMoves(board);
        final rookCapturePrison = moves.any(
          (m) =>
              m.piece.type == PieceType.rook &&
              m.to == const Position(7, 3) &&
              m.isCapture,
        );

        expect(rookCapturePrison, isFalse);
      });
    },
  );

  group('Save the Queen: capturing an escaped queen ends the game', () {
    test('capturing escaped queen triggers checkmate (instant win)', () {
      // White queen has escaped to e5 (row=3, col=4 in own half).
      // Black rook on e2 can capture it.
      final board = ChessBoard.fromFEN(
        '3q4/8/8/4Q3/8/8/4r3/6k1 b - - 0 1',
        gameType: ModsEnum.saveTheQueen,
      );
      final moves = orchestrator.getAllValidMoves(board);
      final escapedQueenCapture = moves.firstWhere(
        (m) =>
            m.piece.type == PieceType.rook &&
            m.capturedPiece?.type == PieceType.queen &&
            m.capturedPiece?.color == PieceColor.white,
      );

      final nextBoard = orchestrator.executeMove(board, escapedQueenCapture);
      expect(nextBoard.gameStatus, equals(GameStatus.checkmate));
    });
  });
}
