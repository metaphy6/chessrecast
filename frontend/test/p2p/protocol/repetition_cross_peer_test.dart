import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import '../../../lib/services/p2p/protocol/frame.dart';

void main() {
  group('RepetitionDetector — cross-peer verification ×7 mods (§1.5 / §15)', () {
    const fen1 = 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1';
    const fen2 = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
    final emptyState = Uint8List(0);

    for (final mod in ModId.values) {
      test('mod=${mod.name}: threefold repetition claim verified correctly', () {
        final detector = RepetitionDetector();
        final h1 = StateHasher.compute(fen1, mod, emptyState);
        final h2 = StateHasher.compute(fen2, mod, emptyState);

        // Push fen1 three times (with interleaving fen2)
        detector.push(h1);
        detector.push(h2);
        detector.push(h1);
        detector.push(h2);
        detector.push(h1); // 3rd occurrence

        expect(detector.countOccurrences(h1), 3);
        expect(detector.verifyRepetitionClaim(h1, 3), isTrue);
      });

      test('mod=${mod.name}: two occurrences ≠ threefold', () {
        final detector = RepetitionDetector();
        final h1 = StateHasher.compute(fen1, mod, emptyState);
        final h2 = StateHasher.compute(fen2, mod, emptyState);
        detector.push(h1);
        detector.push(h2);
        detector.push(h1); // only 2
        expect(detector.verifyRepetitionClaim(h1, 3), isFalse);
      });

      test('mod=${mod.name}: reset clears position history', () {
        final detector = RepetitionDetector();
        final h1 = StateHasher.compute(fen1, mod, emptyState);
        detector.push(h1);
        detector.push(h1);
        detector.push(h1);
        detector.reset();
        expect(detector.countOccurrences(h1), 0);
        expect(detector.verifyRepetitionClaim(h1, 3), isFalse);
      });
    }

    test('cross-peer: both sides agree on repetition count', () {
      final mod = ModId.classic;
      final h1 = StateHasher.compute(fen1, mod, emptyState);
      final h2 = StateHasher.compute(fen2, mod, emptyState);

      final local = RepetitionDetector();
      final remote = RepetitionDetector();

      for (final h in [h2, h1, h2, h1, h2]) {
        local.push(h);
        remote.push(h);
      }

      expect(local.countOccurrences(h2), remote.countOccurrences(h2));
      expect(local.countOccurrences(h1), remote.countOccurrences(h1));
    });

    test('verifyRepetitionClaim: mismatched hash claim is rejected', () {
      final mod = ModId.classic;
      final h1 = StateHasher.compute(fen1, mod, emptyState);
      final h2 = StateHasher.compute(fen2, mod, emptyState);

      final detector = RepetitionDetector();
      detector.push(h1);
      detector.push(h1);
      detector.push(h1);

      // Claim the wrong hash
      expect(detector.verifyRepetitionClaim(h2, 3), isFalse);
    });
  });
}
