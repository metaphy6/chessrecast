import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import '../../lib/services/p2p/engine_binding.dart';
import '../../lib/services/p2p/protocol/frame.dart';

void main() {
  group('EngineBinding — legal/illegal move validation (§1.3)', () {
    group('MockEngineBinding — default (all moves legal)', () {
      const binding = MockEngineBinding();

      test('any move is legal by default', () {
        expect(binding.isMoveLegal('fen', ModId.classic, 'e2e4'), isTrue);
      });

      test('applyMove with default binding returns unchanged FEN', () {
        const fen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
        expect(binding.applyMove(fen, ModId.classic, 'e2e4'), fen);
      });
    });

    group('MockEngineBinding — explicit allow-list', () {
      const binding = MockEngineBinding(legalMoves: {'e2e4', 'g1f3', 'd2d4'});

      test('move in allow-list is legal', () {
        expect(binding.isMoveLegal('', ModId.classic, 'e2e4'), isTrue);
        expect(binding.isMoveLegal('', ModId.classic, 'G1F3'), isTrue); // canonicalised
      });

      test('move NOT in allow-list is illegal', () {
        expect(binding.isMoveLegal('', ModId.classic, 'e2e3'), isFalse);
      });

      test('applyMove for illegal move throws IllegalMoveError', () {
        expect(
          () => binding.applyMove('', ModId.classic, 'e2e3'),
          throwsA(isA<IllegalMoveError>()),
        );
      });
    });

    group('MockEngineBinding — isLegalFn predicate', () {
      final binding = MockEngineBinding(
        isLegalFn: (fen, mod, uci) => mod == ModId.classic && uci == 'e2e4',
      );

      test('predicate returning true allows the move', () {
        expect(binding.isMoveLegal('', ModId.classic, 'e2e4'), isTrue);
      });

      test('predicate returning false rejects the move', () {
        expect(binding.isMoveLegal('', ModId.heir, 'e2e4'), isFalse);
      });
    });

    group('MockEngineBinding — mod isolation ×7 mods', () {
      for (final mod in ModId.values) {
        test('${mod.name}: can create binding and check move', () {
          final binding =
              MockEngineBinding(legalMoves: {'e2e4', 'e7e5', 'g1f3'});
          expect(binding.isMoveLegal('fen', mod, 'e2e4'), isTrue);
          expect(binding.isMoveLegal('fen', mod, 'z9z9'), isFalse);
        });
      }
    });

    group('StateHash via MockEngineBinding', () {
      const binding = MockEngineBinding();

      test('stateHash returns 32 bytes', () {
        const fen =
            'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
        final h = binding.stateHash(fen, ModId.classic, Uint8List(0));
        expect(h.length, 32);
      });

      test('different mods produce different hashes', () {
        const fen =
            'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
        final h1 = binding.stateHash(fen, ModId.classic, Uint8List(0));
        final h2 = binding.stateHash(fen, ModId.heir, Uint8List(0));
        expect(h1, isNot(equals(h2)));
      });
    });

    group('IllegalMoveError', () {
      test('toString includes move, fen, and modId', () {
        final e = const IllegalMoveError('e2e9', 'fen123', ModId.heir);
        expect(e.toString(), contains('e2e9'));
        expect(e.toString(), contains('fen123'));
        expect(e.toString(), contains('heir'));
      });
    });

    group('validateRemoteMove', () {
      test('legal move does not throw', () {
        const binding = MockEngineBinding(legalMoves: {'e2e4'});
        expect(
          () => validateRemoteMove(
            binding: binding,
            fen: '',
            modId: ModId.classic,
            uciMove: 'e2e4',
            modStateBytes: Uint8List(0),
          ),
          returnsNormally,
        );
      });

      test('illegal move throws IllegalMoveError', () {
        const binding = MockEngineBinding(legalMoves: {'e2e4'});
        expect(
          () => validateRemoteMove(
            binding: binding,
            fen: '',
            modId: ModId.classic,
            uciMove: 'e2e9',
            modStateBytes: Uint8List(0),
          ),
          throwsA(isA<IllegalMoveError>()),
        );
      });
    });
  });
}
