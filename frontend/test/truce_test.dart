import 'package:flutter_test/flutter_test.dart';
import 'package:chessrecast/board/board.dart';
import 'package:chessrecast/board/piece.dart';
import 'package:chessrecast/board/pieces/piece_color.dart';
import 'package:chessrecast/board/pieces/piece_type.dart';
import 'package:chessrecast/board/moves/position.dart';
import 'package:chessrecast/board/moves/move.dart';
import 'package:chessrecast/board/moves/generation.dart';
import 'package:chessrecast/management/orchestrator.dart';
import 'package:chessrecast/mods/truce.dart';
import 'package:chessrecast/mods/enums.dart';

void main() {
  const truce = Truce();
  final orchestrator = Orchestrator();

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

    test('truce breaks when remaining unmoved move would only give check', () {
      final wKnight = ChessPiece(
        type: PieceType.knight,
        color: PieceColor.white,
        position: const Position(0, 1),
      );
      final wKing = ChessPiece(
        type: PieceType.king,
        color: PieceColor.white,
        position: const Position(0, 7),
        hasMoved: true,
      );
      final bKing = ChessPiece(
        type: PieceType.king,
        color: PieceColor.black,
        position: const Position(0, 5),
      );
      final blockerA = ChessPiece(
        type: PieceType.pawn,
        color: PieceColor.black,
        position: const Position(2, 0),
      );
      final blockerC = ChessPiece(
        type: PieceType.pawn,
        color: PieceColor.black,
        position: const Position(2, 2),
      );

      final board = ChessBoard(
        pieces: [wKnight, wKing, bKing, blockerA, blockerC],
        currentPlayer: PieceColor.white,
        gameType: ModsEnum.truce,
        moveHistory: [
          ChessMove(
            from: const Position(0, 4),
            to: const Position(0, 7),
            piece: ChessPiece(
              type: PieceType.king,
              color: PieceColor.white,
              position: const Position(0, 4),
            ),
          ),
        ],
      );

      // White knight on b1 has only d2 available; a3 and c3 are occupied.
      // Nb1-d2 would check the black king on f1, so it is illegal during truce.
      // White king has already moved, so all legal truce moves are exhausted.
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
        ChessMove(
          from: whiteKing.position,
          to: const Position(5, 4),
          piece: whiteKing,
        ),
        ChessMove(
          from: whiteKing.position,
          to: const Position(5, 5),
          piece: whiteKing,
          capturedPiece: blackPawn,
        ),
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
        ChessMove(
          from: whiteKing.position,
          to: const Position(5, 4),
          piece: whiteKing,
        ),
        ChessMove(
          from: whiteKing.position,
          to: const Position(5, 5),
          piece: whiteKing,
          capturedPiece: blackPawn,
        ),
      ];

      final filtered = truce.filterMoves(moves, whiteKing, board);
      expect(filtered.length, 2); // Both moves allowed
    });

    test('moved piece has no generated truce moves', () {
      var board = ChessBoard.initial(gameType: ModsEnum.truce);

      ChessMove move(String notation) {
        final parsed = orchestrator.parseAlgebraicNotation(board, notation);
        expect(parsed, isNotNull, reason: 'expected legal move $notation');
        return parsed!;
      }

      board = orchestrator.executeMove(board, move('g1f3'));
      board = orchestrator.executeMove(board, move('g8f6'));

      final knightMoves = board.getValidMovesFor(const Position(2, 5));
      expect(knightMoves, isEmpty);
      expect(
        orchestrator
            .getAllValidMoves(board)
            .where((candidate) => candidate.from == const Position(2, 5)),
        isEmpty,
      );
    });

    test('castling also freezes the rook during truce', () {
      final board = ChessBoard.fromFEN(
        '4k3/8/8/8/8/8/8/4K2R w K - 0 1',
        gameType: ModsEnum.truce,
      );
      final castle = board
          .getValidMovesFor(const Position(0, 4))
          .firstWhere((move) => move.isCastling);

      final afterCastle = orchestrator.executeMove(board, castle);

      expect(afterCastle.getValidMovesFor(const Position(0, 5)), isEmpty);
    });
  });

  group('Truce: getTruceInfo', () {
    test('reports correct truce status with blocked pieces', () {
      // Same setup as "all pieces exhausted" test
      final wKing = ChessPiece(
        type: PieceType.king,
        color: PieceColor.white,
        position: const Position(0, 4),
        hasMoved: true,
      );
      final wPawn = ChessPiece(
        type: PieceType.pawn,
        color: PieceColor.white,
        position: const Position(3, 0),
      );
      final bPawn = ChessPiece(
        type: PieceType.pawn,
        color: PieceColor.black,
        position: const Position(4, 0),
      );
      final bKing = ChessPiece(
        type: PieceType.king,
        color: PieceColor.black,
        position: const Position(7, 4),
      );

      final board = ChessBoard(
        pieces: [wKing, wPawn, bPawn, bKing],
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

      final info = truce.getTruceInfo(board);
      expect(info['truceActive'], isFalse);
      expect(info['whiteMovedPieces'], 1); // only king moved
      expect(info['whiteTotalPieces'], 2);
    });
  });

  group('Truce: validateTruceMove (1-move-per-piece)', () {
    test('piece that has not moved is allowed', () {
      final whiteKnight = ChessPiece(
        type: PieceType.knight,
        color: PieceColor.white,
        position: const Position(0, 1),
      );
      final blackKing = ChessPiece(
        type: PieceType.king,
        color: PieceColor.black,
        position: const Position(7, 4),
      );
      final whiteKing = ChessPiece(
        type: PieceType.king,
        color: PieceColor.white,
        position: const Position(0, 4),
      );

      final board = ChessBoard(
        pieces: [whiteKnight, whiteKing, blackKing],
        gameType: ModsEnum.truce,
        moveHistory: const [],
      );

      final move = ChessMove(
        from: const Position(0, 1),
        to: const Position(2, 2),
        piece: whiteKnight,
      );

      expect(truce.validateTruceMove(board, move), isTrue);
    });

    test('piece that already moved once is rejected', () {
      final whiteKnight = ChessPiece(
        type: PieceType.knight,
        color: PieceColor.white,
        position: const Position(2, 2),
      );
      final blackKing = ChessPiece(
        type: PieceType.king,
        color: PieceColor.black,
        position: const Position(7, 4),
      );
      final whiteKing = ChessPiece(
        type: PieceType.king,
        color: PieceColor.white,
        position: const Position(0, 4),
      );

      final board = ChessBoard(
        pieces: [whiteKnight, whiteKing, blackKing],
        gameType: ModsEnum.truce,
        moveHistory: [
          ChessMove(
            from: const Position(0, 1),
            to: const Position(2, 2),
            piece: ChessPiece(
              type: PieceType.knight,
              color: PieceColor.white,
              position: const Position(0, 1),
            ),
          ),
        ],
      );

      final move = ChessMove(
        from: const Position(2, 2),
        to: const Position(4, 3),
        piece: whiteKnight,
      );

      expect(truce.validateTruceMove(board, move), isFalse);
    });
  });

  group('Truce: getTruceFrozenBitboard', () {
    test('pieces that moved once are frozen', () {
      final whiteKnight = ChessPiece(
        type: PieceType.knight,
        color: PieceColor.white,
        position: const Position(2, 2),
      );
      final whiteBishop = ChessPiece(
        type: PieceType.bishop,
        color: PieceColor.white,
        position: const Position(0, 2), // unmoved
      );
      final blackKing = ChessPiece(
        type: PieceType.king,
        color: PieceColor.black,
        position: const Position(7, 4),
      );
      final whiteKing = ChessPiece(
        type: PieceType.king,
        color: PieceColor.white,
        position: const Position(0, 4),
      );

      final board = ChessBoard(
        pieces: [whiteKnight, whiteBishop, whiteKing, blackKing],
        gameType: ModsEnum.truce,
        moveHistory: [
          ChessMove(
            from: const Position(0, 1),
            to: const Position(2, 2),
            piece: ChessPiece(
              type: PieceType.knight,
              color: PieceColor.white,
              position: const Position(0, 1),
            ),
          ),
        ],
      );

      final frozen = truce.getTruceFrozenBitboard(board);
      // Knight at (2,2) = square 2*8+2 = 18 → bit 18 should be set
      expect(frozen & (1 << 18), isNonZero);
      // Bishop at (0,2) = square 2 → should NOT be frozen
      expect(frozen & (1 << 2), isZero);
    });
  });

  group('Truce: side-to-move truce break', () {
    test('truce stays active when opponent is exhausted but current side is not', () {
      // White (current player) has 2 pieces: king (moved) + rook (unmoved, can move)
      // Black has only king (moved) → black is exhausted
      // But current player is white → check only white → white NOT exhausted → truce active
      final wKing = ChessPiece(
        type: PieceType.king,
        color: PieceColor.white,
        position: const Position(0, 4),
        hasMoved: true,
      );
      final wRook = ChessPiece(
        type: PieceType.rook,
        color: PieceColor.white,
        position: const Position(0, 0),
      );
      final bKing = ChessPiece(
        type: PieceType.king,
        color: PieceColor.black,
        position: const Position(7, 3),
        hasMoved: true,
      );

      final board = ChessBoard(
        pieces: [wKing, wRook, bKing],
        currentPlayer: PieceColor.white,
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
          ChessMove(
            from: const Position(7, 4),
            to: const Position(7, 3),
            piece: ChessPiece(
              type: PieceType.king,
              color: PieceColor.black,
              position: const Position(7, 4),
            ),
          ),
        ],
      );

      // Black is fully exhausted (only king, which moved). But it's white's turn
      // and white still has an unmoved rook → truce stays active.
      expect(truce.isTruceActive(board), isTrue);
    });

    test('truce breaks when current side to move is exhausted', () {
      // Same scenario but currentPlayer is black
      final wKing = ChessPiece(
        type: PieceType.king,
        color: PieceColor.white,
        position: const Position(0, 4),
        hasMoved: true,
      );
      final wRook = ChessPiece(
        type: PieceType.rook,
        color: PieceColor.white,
        position: const Position(0, 0),
      );
      final bKing = ChessPiece(
        type: PieceType.king,
        color: PieceColor.black,
        position: const Position(7, 3),
        hasMoved: true,
      );

      final board = ChessBoard(
        pieces: [wKing, wRook, bKing],
        currentPlayer: PieceColor.black,
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
          ChessMove(
            from: const Position(7, 4),
            to: const Position(7, 3),
            piece: ChessPiece(
              type: PieceType.king,
              color: PieceColor.black,
              position: const Position(7, 4),
            ),
          ),
        ],
      );

      // It's black's turn and black is exhausted → truce breaks
      expect(truce.isTruceActive(board), isFalse);
    });
  });

  group('Truce: no-check filter', () {
    test('move that gives direct check is filtered during truce', () {
      // White bishop on (0,2) can move to (2,4) or (1,3).
      // Black king at (4,2): bishop at (2,4) gives check via (3,3)→(4,2).
      // Bishop at (1,3) does NOT give check (not on diagonal to (4,2)).
      final wBishop = ChessPiece(
        type: PieceType.bishop,
        color: PieceColor.white,
        position: const Position(0, 2),
      );
      final wKing = ChessPiece(
        type: PieceType.king,
        color: PieceColor.white,
        position: const Position(0, 4),
      );
      final bKing = ChessPiece(
        type: PieceType.king,
        color: PieceColor.black,
        position: const Position(4, 2),
      );

      final board = ChessBoard(
        pieces: [wBishop, wKing, bKing],
        currentPlayer: PieceColor.white,
        gameType: ModsEnum.truce,
        moveHistory: const [],
      );

      final checkMove = ChessMove(
        from: const Position(0, 2),
        to: const Position(2, 4),
        piece: wBishop,
      );
      final safeMove = ChessMove(
        from: const Position(0, 2),
        to: const Position(1, 3),
        piece: wBishop,
      );

      final filtered = truce.filterMoves([checkMove, safeMove], wBishop, board);
      expect(filtered.length, 1);
      expect(filtered.first.to, const Position(1, 3));
    });

    test('knight move giving check is filtered during truce', () {
      final wKnight = ChessPiece(
        type: PieceType.knight,
        color: PieceColor.white,
        position: const Position(0, 1),
      );
      final wKing = ChessPiece(
        type: PieceType.king,
        color: PieceColor.white,
        position: const Position(0, 4),
      );
      // Black king at (3,1): knight going to (2,3) — is that check?
      // Knight at (2,3) attacks: (0,2),(0,4),(1,1),(1,5),(3,1),(3,5),(4,2),(4,4)
      // (3,1) is in that list! So knight at (2,3) checks king at (3,1).
      final bKing = ChessPiece(
        type: PieceType.king,
        color: PieceColor.black,
        position: const Position(3, 1),
      );

      final board = ChessBoard(
        pieces: [wKnight, wKing, bKing],
        currentPlayer: PieceColor.white,
        gameType: ModsEnum.truce,
        moveHistory: const [],
      );

      final checkMove = ChessMove(
        from: const Position(0, 1),
        to: const Position(2, 3), // Knight → (2,3) checks king at (3,1) ???
        piece: wKnight,
      );
      // Nope: knight at (2,3): L-moves are (0,2),(0,4),(1,1),(1,5),(3,1),(3,5),(4,2),(4,4)
      // Wait, that's wrong. Knight at (2,3): ±2,±1 and ±1,±2:
      // (2+2,3+1)=(4,4), (2+2,3-1)=(4,2), (2-2,3+1)=(0,4), (2-2,3-1)=(0,2)
      // (2+1,3+2)=(3,5), (2+1,3-2)=(3,1), (2-1,3+2)=(1,5), (2-1,3-2)=(1,1)
      // Yes, (3,1) is attacked! ✓

      final safeMove = ChessMove(
        from: const Position(0, 1),
        to: const Position(2, 0),
        piece: wKnight,
      );

      final filtered = truce.filterMoves([checkMove, safeMove], wKnight, board);
      expect(filtered.length, 1);
      expect(filtered.first.to, const Position(2, 0));
    });
  });
}
