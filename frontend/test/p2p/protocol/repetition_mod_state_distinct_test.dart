import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import '../../../lib/services/p2p/protocol/frame.dart';

void main() {
  group('RepetitionDetector — mod state in StateHasher (§1.5 / §10 / §15)', () {
    // The StateHasher must incorporate mod-specific state so that two positions
    // that are identical by FEN but differ in mod state produce different hashes.
    // RepetitionDetector works on pre-computed state hashes, so if the caller
    // passes hashes derived from different mod states, they are counted separately.

    const baseFen =
        'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1';

    test('same FEN + same mod + same modState → same hash', () {
      final modState = Uint8List.fromList([0x01, 0x02, 0x03]);
      final h1 = StateHasher.compute(baseFen, ModId.classic, modState);
      final h2 = StateHasher.compute(baseFen, ModId.classic, modState);
      expect(h1, equals(h2));
    });

    test('same FEN + same mod + different modState → different hash', () {
      final modState1 = Uint8List.fromList([0x01, 0x00]); // e.g. truce=inactive
      final modState2 = Uint8List.fromList([0x01, 0x01]); // e.g. truce=active
      final h1 = StateHasher.compute(baseFen, ModId.truce, modState1);
      final h2 = StateHasher.compute(baseFen, ModId.truce, modState2);
      expect(
        h1,
        isNot(equals(h2)),
        reason:
            'Same FEN but different truce state must produce different hashes',
      );
    });

    test('same FEN + different mod → different hash', () {
      final modState = Uint8List(0);
      final hClassic = StateHasher.compute(baseFen, ModId.classic, modState);
      final hHeir = StateHasher.compute(baseFen, ModId.heir, modState);
      expect(hClassic, isNot(equals(hHeir)));
    });

    test(
      'RepetitionDetector: same FEN with same modState counted together',
      () {
        final modState = Uint8List.fromList([0x00]);
        final h = StateHasher.compute(baseFen, ModId.truce, modState);

        final det = RepetitionDetector();
        det.push(h);
        det.push(h);
        det.push(h);
        expect(det.verifyRepetitionClaim(h, 3), isTrue);
      },
    );

    test(
      'RepetitionDetector: same FEN with different modStates NOT counted together',
      () {
        final modStateA = Uint8List.fromList([0x00]);
        final modStateB = Uint8List.fromList([0x01]);
        final hA = StateHasher.compute(baseFen, ModId.truce, modStateA);
        final hB = StateHasher.compute(baseFen, ModId.truce, modStateB);

        final det = RepetitionDetector();
        det.push(hA);
        det.push(hB);
        det.push(hA);
        // Only 2 positions with modStateA — threefold claim should fail
        expect(det.verifyRepetitionClaim(hA, 3), isFalse);
      },
    );

    test(
      'all 7 mods with same FEN and empty modState produce distinct hashes',
      () {
        final hashes = ModId.values
            .map((mod) => StateHasher.compute(baseFen, mod, Uint8List(0)))
            .toList();
        // All hashes should be distinct
        for (int i = 0; i < hashes.length; i++) {
          for (int j = i + 1; j < hashes.length; j++) {
            expect(
              hashes[i],
              isNot(equals(hashes[j])),
              reason:
                  'Mods ${ModId.values[i].name} and ${ModId.values[j].name} '
                  'produce the same hash for the same FEN',
            );
          }
        }
      },
    );

    test('StateHasher output is always 32 bytes', () {
      for (final mod in ModId.values) {
        final h = StateHasher.compute(baseFen, mod, Uint8List(4));
        expect(h.length, 32);
      }
    });
  });
}
