import 'package:chessrecast/board/utils/exporter.dart';
import 'package:chessrecast/management/orchestrator.dart';
import 'package:chessrecast/mods/enums.dart';
import 'package:flutter_test/flutter_test.dart';

// ignore_for_file: deprecated_member_use

void main() {
  final orchestrator = Orchestrator();

  group('Succession: queen-capture triggers instant win', () {
    test('capturing enemy queen ends the game immediately', () {
      // White rook on e2 can capture black queen on e5.
      // After the capture the board status should be checkmate (game over).
      final board = ChessBoard.fromFEN(
        '8/8/8/4q3/8/8/4R3/3QQ3 w - - 0 1',
        gameType: ModsEnum.succession,
      );
      final moves = orchestrator.getAllValidMoves(board);
      final queenCapture = moves.firstWhere(
        (m) =>
            m.from == const Position(6, 4) &&
            m.to == const Position(3, 4) &&
            m.capturedPiece?.type == PieceType.queen,
      );

      final nextBoard = orchestrator.executeMove(board, queenCapture);
      expect(nextBoard.gameStatus, equals(GameStatus.checkmate));
    });
  });

  group('Succession: king-promotion triggers instant win', () {
    test('promoting last pawn to king on a safe square wins immediately', () {
      // White pawn on d7, uncontested. Promoting to king on d8 should win.
      final board = ChessBoard.fromFEN(
        '8/3P4/8/8/8/8/8/3QQ3 w - - 0 1',
        gameType: ModsEnum.succession,
      );
      final moves = orchestrator.getAllValidMoves(board);
      final kingPromotion = moves.any(
        (m) =>
            m.piece.type == PieceType.pawn &&
            m.isPromotion &&
            m.promotionPiece == 'K',
      );

      expect(kingPromotion, isTrue);

      final promoMove = moves.firstWhere(
        (m) => m.piece.type == PieceType.pawn && m.promotionPiece == 'K',
      );
      final nextBoard = orchestrator.executeMove(board, promoMove);
      expect(nextBoard.gameStatus, equals(GameStatus.checkmate));
    });

    test('king promotion onto an attacked square is not offered', () {
      // Black rook guards d8. White pawn on d7 → promotion to K on d8
      // should be filtered out because d8 is attacked.
      final board = ChessBoard.fromFEN(
        '3r4/3P4/8/8/8/8/8/3QQ3 w - - 0 1',
        gameType: ModsEnum.succession,
      );
      final moves = orchestrator.getAllValidMoves(board);
      final kingPromotionToAttackedSquare = moves.any(
        (m) =>
            m.piece.type == PieceType.pawn &&
            m.isPromotion &&
            m.promotionPiece == 'K' &&
            m.to == const Position(0, 3),
      );

      expect(kingPromotionToAttackedSquare, isFalse);
    });
  });

  group('Succession: losing all pawns triggers instant loss', () {
    test('capturing the last enemy pawn ends the game for the pawn-loser', () {
      // Black has one pawn left on e5; white knight captures it.
      // This leaves black with no pawns → instant loss for black.
      final board = ChessBoard.fromFEN(
        '3qq3/8/8/4p3/4N3/8/8/3QQ3 w - - 0 1',
        gameType: ModsEnum.succession,
      );
      final moves = orchestrator.getAllValidMoves(board);
      final pawnCapture = moves.firstWhere(
        (m) =>
            m.piece.type == PieceType.knight &&
            m.capturedPiece?.type == PieceType.pawn,
      );

      final nextBoard = orchestrator.executeMove(board, pawnCapture);
      expect(nextBoard.gameStatus, equals(GameStatus.checkmate));
    });
  });
}
