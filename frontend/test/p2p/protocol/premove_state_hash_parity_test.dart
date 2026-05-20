// §11.8 — Premove cross-peer determinism.
//
// Premove is purely local until fired; once fired it is an ordinary MOVE
// and state_hash parity is preserved.
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/clock/premove.dart';

void main() {
  group('§11.8 premove_state_hash_parity', () {
    test('fired premove produces the same move as a manual move', () {
      // Premove that fires should produce an identical PremoveMove to what
      // would be sent as a normal move.
      final queue = PremoveQueue();
      const expectedMove = PremoveMove(from: 'e2', to: 'e4');
      queue.enqueue(expectedMove);

      final validator = FakePremoveValidator(isLegal: true);
      final result = queue.tryFire(validator);
      expect(result, equals(PremoveFireResult.fired));

      // The fired move is retrievable from the validator.
      expect(validator.lastFiredMove, equals(expectedMove));
    });

    test('premove hash: identical move from different origins is equal', () {
      const a = PremoveMove(from: 'e2', to: 'e4');
      const b = PremoveMove(from: 'e2', to: 'e4');
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('different premove moves are not equal', () {
      const a = PremoveMove(from: 'e2', to: 'e4');
      const b = PremoveMove(from: 'd2', to: 'd4');
      expect(a, isNot(equals(b)));
    });
  });
}
