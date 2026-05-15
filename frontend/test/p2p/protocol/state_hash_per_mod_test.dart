import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import '../../../lib/services/p2p/protocol/frame.dart';

void main() {
  group('StateHasher — per-mod state hash (§1.4 / §10)', () {
    const _startFen =
        'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
    const _midFen =
        'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1';
    final _emptyModState = Uint8List(0);

    // Sanity: all 7 mod IDs produce 32-byte hashes.
    for (final mod in ModId.values) {
      test('${mod.name}: hash is 32 bytes for start position', () {
        final h = StateHasher.compute(_startFen, mod, _emptyModState);
        expect(h.length, 32);
      });
    }

    // Different mods → different hashes for the same FEN.
    test('classic and heir produce different hashes for same FEN', () {
      final hClassic = StateHasher.compute(
        _startFen,
        ModId.classic,
        _emptyModState,
      );
      final hHeir = StateHasher.compute(_startFen, ModId.heir, _emptyModState);
      expect(hClassic, isNot(equals(hHeir)));
    });

    test('all 7 non-classic mod hashes are distinct for start FEN', () {
      final hashes = ModId.values
          .map((m) => StateHasher.compute(_startFen, m, _emptyModState))
          .toList();
      for (int i = 0; i < hashes.length; i++) {
        for (int j = i + 1; j < hashes.length; j++) {
          expect(
            hashes[i],
            isNot(equals(hashes[j])),
            reason:
                '${ModId.values[i].name} and ${ModId.values[j].name} should have different hashes',
          );
        }
      }
    });

    // Different FEN positions → different hashes.
    test('start and mid-game positions produce different hashes', () {
      final h1 = StateHasher.compute(_startFen, ModId.classic, _emptyModState);
      final h2 = StateHasher.compute(_midFen, ModId.classic, _emptyModState);
      expect(h1, isNot(equals(h2)));
    });

    // Non-empty mod state is incorporated.
    test('same FEN + different mod state → different hashes', () {
      final ms1 = Uint8List.fromList([0x01]);
      final ms2 = Uint8List.fromList([0x02]);
      final h1 = StateHasher.compute(_startFen, ModId.mercenary, ms1);
      final h2 = StateHasher.compute(_startFen, ModId.mercenary, ms2);
      expect(h1, isNot(equals(h2)));
    });

    // Same FEN + same mod + same state → same hash (deterministic).
    test('same inputs always produce the same hash', () {
      final h1 = StateHasher.compute(_startFen, ModId.truce, _emptyModState);
      final h2 = StateHasher.compute(_startFen, ModId.truce, _emptyModState);
      expect(h1, equals(h2));
    });

    // computeClassic shorthand.
    test('computeClassic is equivalent to compute with empty modState', () {
      final h1 = StateHasher.computeClassic(_startFen, ModId.classic);
      final h2 = StateHasher.compute(_startFen, ModId.classic, _emptyModState);
      expect(h1, equals(h2));
    });
  });
}
