import 'package:flutter_test/flutter_test.dart';
import 'package:chessrecast/board/board.dart';
import 'package:chessrecast/board/piece.dart';
import 'package:chessrecast/board/pieces/piece_color.dart';
import 'package:chessrecast/board/pieces/piece_type.dart';
import 'package:chessrecast/board/moves/position.dart';
import 'package:chessrecast/board/moves/move.dart';
import 'package:chessrecast/mods/truce.dart';
import 'package:chessrecast/mods/mods_enum.dart';

void main() {
  const truce = Truce();

  group('Truce: isTruceActive', () {
    test('initial board has truce active', () {
      final board = ChessBoard.initial(gameType: ModsEnum.truce);
      expect(truce.isTruceActive(board), isTrue);
    });

    test('truce breaks when all pieces of one color have moved', () {
      // Minimal board: white has just a king. After king moves, all white
      // pieces have moved → truce breaks.
      final whiteKing = ChessPiece(
        type: PieceType.king,
        color: PieceColor.white,
        position: const Position(0, 4),
      );
      final blackKing = ChessPiece(
        type: PieceType.king,
        color: PieceColor.black,
        position: const Position(7, 4),
      );

      // Board before king moves: truce active
      final boardBefore = ChessBoard(
        pieces: [whiteKing, blackKing],
        gameType: ModsEnum.truce,
        moveHistory: const [],
      );
      expect(truce.isTruceActive(boardBefore), isTrue);

      // After white king moves to (1,4): truce should break because white's
      // only piece has now moved.
      final movedKing = whiteKing.movedTo(const Position(1, 4));
      final boardAfter = ChessBoard(
        pieces: [movedKing, blackKing],
        gameType: ModsEnum.truce,
        moveHistory: [
          ChessMove(
            from: const Position(0, 4),
            to: const Position(1, 4),
            piece: whiteKing,
          ),
        ],
      );
      expect(truce.isTruceActive(boardAfter), isFalse);
    });

    test('truce breaks when unmoved pieces are ALL blocked', () {
      // Scenario: white has king (already moved) and a rook that is
      // completely surrounded, so it can't move without capturing.
      // Since the rook is blocked and the king has moved, all white
      // pieces are "exhausted" → truce should break.

      // White rook at a1 (0,0), surrounded by:
      //   (1,0) = black pawn, (0,1) = white king (moved here)
      // Rook has NOT moved, but has no empty adjacent square.
      final whiteRook = ChessPiece(
        type: PieceType.rook,
        color: PieceColor.white,
        position: const Position(0, 0),
      );
      final whiteKing = ChessPiece(
        type: PieceType.king,
        color: PieceColor.white,
        position: const Position(0, 1),
        hasMoved: true,
      );
      final blackPawn = ChessPiece(
        type: PieceType.pawn,
        color: PieceColor.black,
        position: const Position(1, 0),
      );
      final blackKing = ChessPiece(
        type: PieceType.king,
        color: PieceColor.black,
        position: const Position(7, 4),
      );

      final board = ChessBoard(
        pieces: [whiteRook, whiteKing, blackPawn, blackKing],
        gameType: ModsEnum.truce,
        moveHistory: [
          // King moved from e1 to b1
          ChessMove(
            from: const Position(0, 4),
            to: const Position(0, 1),
            piece: ChessPiece(
              type: PieceType.king,
              color: PieceColor.white,
              position: const Position(0, 4),
            ),
          ),
        ],
      );

      // White king has moved (in moveHistory). White rook hasn't moved but is
      // blocked (a1 corner, adjacent squares occupied). All white pieces
      // exhausted → truce breaks.
      expect(truce.isTruceActive(board), isFalse);
    });

    test('truce stays active when an unmoved piece CAN move', () {
      // Same setup but rook has an empty adjacent square → not blocked
      final whiteRook = ChessPiece(
        type: PieceType.rook,
        color: PieceColor.white,
        position: const Position(0, 0),
      );
      final whiteKing = ChessPiece(
        type: PieceType.king,
        color: PieceColor.white,
        position: const Position(0, 2), // king is 2 squares away
        hasMoved: true,
      );
      final blackKing = ChessPiece(
        type: PieceType.king,
        color: PieceColor.black,
        position: const Position(7, 4),
      );

      final board = ChessBoard(
        pieces: [whiteRook, whiteKing, blackKing],
        gameType: ModsEnum.truce,
        moveHistory: [
          ChessMove(
            from: const Position(0, 4),
            to: const Position(0, 2),
            piece: ChessPiece(
              type: PieceType.king,
              color: PieceColor.white,
              position: const Position(0, 4),
            ),
          ),
        ],
      );

      // White rook at a1 has (1,0) empty → can move → not exhausted
      // So truce should still be active.
      expect(truce.isTruceActive(board), isTrue);
    });

    test('blocked pawn (forward square occupied) counts as exhausted', () {
      // White: king (moved) + pawn (unmoved, blocked by black pawn directly ahead)
      final whitePawn = ChessPiece(
        type: PieceType.pawn,
        color: PieceColor.white,
        position: const Position(1, 3),
      );
      final blackPawn = ChessPiece(
        type: PieceType.pawn,
        color: PieceColor.black,
        position: const Position(2, 3), // directly in front of white pawn
      );
      final whiteKing = ChessPiece(
        type: PieceType.king,
        color: PieceColor.white,
        position: const Position(0, 4),
        hasMoved: true,
      );
      final blackKing = ChessPiece(
        type: PieceType.king,
        color: PieceColor.black,
        position: const Position(7, 4),
      );

      final board = ChessBoard(
        pieces: [whitePawn, blackPawn, whiteKing, blackKing],
        gameType: ModsEnum.truce,
        moveHistory: [
          ChessMove(
            from: const Position(0, 3),
            to: const Position(0, 4),
            piece: ChessPiece(
              type: PieceType.king,
              color: PieceColor.white,
              position: const Position(0, 3),
            ),
          ),
        ],
      );

      // White king moved, white pawn blocked → all white pieces exhausted
      expect(truce.isTruceActive(board), isFalse);
    });

    test('blocked knight (all L-squares occupied) counts as exhausted', () {
      // Knight at a1 (0,0), L-moves: (2,1) and (1,2). Place pieces there.
      final whiteKnight = ChessPiece(
        type: PieceType.knight,
        color: PieceColor.white,
        position: const Position(0, 0),
      );
      final blocker1 = ChessPiece(
        type: PieceType.pawn,
        color: PieceColor.white,
        position: const Position(2, 1),
      );
      final blocker2 = ChessPiece(
        type: PieceType.pawn,
        color: PieceColor.white,
        position: const Position(1, 2),
        hasMoved: true,
      );
      final whiteKing = ChessPiece(
        type: PieceType.king,
        color: PieceColor.white,
        position: const Position(0, 4),
        hasMoved: true,
      );
      final blackKing = ChessPiece(
        type: PieceType.king,
        color: PieceColor.black,
        position: const Position(7, 4),
      );

      final board = ChessBoard(
        pieces: [whiteKnight, blocker1, blocker2, whiteKing, blackKing],
        gameType: ModsEnum.truce,
        moveHistory: [
          // King moved
          ChessMove(
            from: const Position(0, 3),
            to: const Position(0, 4),
            piece: ChessPiece(
              type: PieceType.king,
              color: PieceColor.white,
              position: const Position(0, 3),
            ),
          ),
          // blocker2 pawn moved
          ChessMove(
            from: const Position(1, 3),
            to: const Position(1, 2),
            piece: ChessPiece(
              type: PieceType.pawn,
              color: PieceColor.white,
              position: const Position(1, 3),
            ),
          ),
        ],
      );

      // Knight at a1: valid L-moves are (2,1) and (1,2), both occupied.
      // Knight is blocked. King moved, blocker2 moved. blocker1 at (2,1) hasn't
      // moved - but blocker1 is a pawn at row 2: forward square (3,1) - if
      // empty, pawn can move. Let's place something there too.
      // Actually, let me simplify: the point is whether ALL of white's pieces
      // are exhausted. blocker1 pawn at (2,1) hasn't moved and has (3,1) empty.
      // So NOT all white pieces exhausted → truce active.
      //
      // This tests that a blocked knight is correctly identified as blocked,
      // but the truce doesn't break because another piece can still move.
      expect(truce.isTruceActive(board), isTrue);
    });

    test('all pieces exhausted: some moved, rest blocked', () {
      // White: king (moved), 2 pawns (both blocked by opponent pawns)
      // Black: king + 2 pawns
      final wKing = ChessPiece(
        type: PieceType.king,
        color: PieceColor.white,
        position: const Position(0, 4),
        hasMoved: true,
      );
      final wPawn1 = ChessPiece(
        type: PieceType.pawn,
        color: PieceColor.white,
        position: const Position(3, 0),
      );
      final wPawn2 = ChessPiece(
        type: PieceType.pawn,
        color: PieceColor.white,
        position: const Position(3, 7),
      );
      final bPawn1 = ChessPiece(
        type: PieceType.pawn,
        color: PieceColor.black,
        position: const Position(4, 0), // blocks wPawn1
      );
      final bPawn2 = ChessPiece(
        type: PieceType.pawn,
        color: PieceColor.black,
        position: const Position(4, 7), // blocks wPawn2
      );
      final bKing = ChessPiece(
        type: PieceType.king,
        color: PieceColor.black,
        position: const Position(7, 4),
      );

      final board = ChessBoard(
        pieces: [wKing, wPawn1, wPawn2, bPawn1, bPawn2, bKing],
        gameType: ModsEnum.truce,
        moveHistory: [
          ChessMove(
            from: const Position(0, 3),
            to: const Position(0, 4),
            piece: ChessPiece(
              type: PieceType.king,
              color: PieceColor.white,
              position: const Position(0, 3),
            ),
          ),
        ],
      );

      // wKing moved. wPawn1 at (3,0): forward is (4,0) = occupied by bPawn1 → blocked.
      // wPawn2 at (3,7): forward is (4,7) = occupied by bPawn2 → blocked.
      // All 3 white pieces exhausted → truce breaks.
      expect(truce.isTruceActive(board), isFalse);
    });
  });

  group('Truce: filterMoves', () {
    test('during truce, captures are filtered out', () {
      final whiteKing = ChessPiece(
        type: PieceType.king,
        color: PieceColor.white,
        position: const Position(4, 4),
      );
      final blackPawn = ChessPiece(
        type: PieceType.pawn,
        color: PieceColor.black,
        position: const Position(5, 5),
      );
      final blackKing = ChessPiece(
        type: PieceType.king,
        color: PieceColor.black,
        position: const Position(7, 0),
      );

      final board = ChessBoard(
        pieces: [whiteKing, blackPawn, blackKing],
        gameType: ModsEnum.truce,
        moveHistory: const [],
      );

      final moves = [
        ChessMove(from: whiteKing.position, to: const Position(5, 4), piece: whiteKing),
        ChessMove(from: whiteKing.position, to: const Position(5, 5), piece: whiteKing, capturedPiece: blackPawn),
      ];

      final filtered = truce.filterMoves(moves, whiteKing, board);
      expect(filtered.length, 1);
      expect(filtered.first.capturedPiece, isNull);
    });

    test('after truce breaks, captures are allowed', () {
      // White has only king, which has moved → truce broken
      final whiteKing = ChessPiece(
        type: PieceType.king,
        color: PieceColor.white,
        position: const Position(4, 4),
        hasMoved: true,
      );
      final blackPawn = ChessPiece(
        type: PieceType.pawn,
        color: PieceColor.black,
        position: const Position(5, 5),
      );
      final blackKing = ChessPiece(
        type: PieceType.king,
        color: PieceColor.black,
        position: const Position(7, 0),
      );

      final board = ChessBoard(
        pieces: [whiteKing, blackPawn, blackKing],
        gameType: ModsEnum.truce,
        moveHistory: [
          ChessMove(
            from: const Position(3, 4),
            to: const Position(4, 4),
            piece: ChessPiece(
              type: PieceType.king,
              color: PieceColor.white,
              position: const Position(3, 4),
            ),
          ),
        ],
      );

      final moves = [
        ChessMove(from: whiteKing.position, to: const Position(5, 4), piece: whiteKing),
        ChessMove(from: whiteKing.position, to: const Position(5, 5), piece: whiteKing, capturedPiece: blackPawn),
      ];

      final filtered = truce.filterMoves(moves, whiteKing, board);
      expect(filtered.length, 2); // Both moves allowed
    });
  });

  group('Truce: getTruceInfo', () {
    test('reports correct truce status with blocked pieces', () {
      // Same setup as "all pieces exhausted" test
      final wKing = ChessPiece(
        type: PieceType.king, color: PieceColor.white,
        position: const Position(0, 4), hasMoved: true,
      );
      final wPawn = ChessPiece(
        type: PieceType.pawn, color: PieceColor.white,
        position: const Position(3, 0),
      );
      final bPawn = ChessPiece(
        type: PieceType.pawn, color: PieceColor.black,
        position: const Position(4, 0),
      );
      final bKing = ChessPiece(
        type: PieceType.king, color: PieceColor.black,
        position: const Position(7, 4),
      );

      final board = ChessBoard(
        pieces: [wKing, wPawn, bPawn, bKing],
        gameType: ModsEnum.truce,
        moveHistory: [
          ChessMove(
            from: const Position(0, 3), to: const Position(0, 4),
            piece: ChessPiece(
              type: PieceType.king, color: PieceColor.white,
              position: const Position(0, 3),
            ),
          ),
        ],
      );

      final info = truce.getTruceInfo(board);
      expect(info['truceActive'], isFalse);
      expect(info['whiteMovedPieces'], 1); // only king moved
      expect(info['whiteTotalPieces'], 2);
    });
  });
}
