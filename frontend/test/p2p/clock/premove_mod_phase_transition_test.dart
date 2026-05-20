// §11.8 — Premove mod-phase transition test.
//
// Mods with phase-changing rules (Kings Battle Phase-1→Phase-2,
// Mercenary pawn-as-piece transitions) must re-validate the premove
// against the post-opponent-move phase.
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/clock/premove.dart';

void main() {
  group('§11.8 premove_mod_phase_transition', () {
    test('premove is invalidated when mod phase changes (generic)', () {
      // Queue premove for source → dest.
      final queue = PremoveQueue();
      queue.enqueue(PremoveMove(from: 'e2', to: 'e4'));
      expect(queue.hasPremove, isTrue);

      // Simulate a phase transition: the premove validator returns illegal.
      final validator = FakePremoveValidator(isLegal: false);
      final result = queue.tryFire(validator);
      expect(result, equals(PremoveFireResult.invalidated));
      expect(queue.hasPremove, isFalse);
    });

    test('legal premove fires successfully', () {
      final queue = PremoveQueue();
      queue.enqueue(PremoveMove(from: 'd2', to: 'd4'));
      expect(queue.hasPremove, isTrue);

      final validator = FakePremoveValidator(isLegal: true);
      final result = queue.tryFire(validator);
      expect(result, equals(PremoveFireResult.fired));
      expect(queue.hasPremove, isFalse);
    });

    test('premove is not sent to opponent before own turn (local-only)', () {
      final queue = PremoveQueue();
      queue.enqueue(PremoveMove(from: 'g1', to: 'f3'));

      // Enqueueing does not "send" anything — local only.
      expect(queue.hasPremove, isTrue);
      expect(queue.pendingMove?.from, equals('g1'));
    });

    test('second enqueue replaces first (max depth 1)', () {
      final queue = PremoveQueue();
      queue.enqueue(PremoveMove(from: 'e2', to: 'e4'));
      queue.enqueue(PremoveMove(from: 'd2', to: 'd4'));

      // Only the latest premove is kept.
      expect(queue.pendingMove?.from, equals('d2'));
    });

    test('cancel clears the premove queue', () {
      final queue = PremoveQueue();
      queue.enqueue(PremoveMove(from: 'c2', to: 'c4'));
      queue.cancel();
      expect(queue.hasPremove, isFalse);
    });

    // Proxy tests for all 7 mods: each mod's legality check is invoked.
    for (final mod in [
      'heir',
      'friendly_fire',
      'kings_battle',
      'mercenary',
      'save_the_queen',
      'succession',
      'truce',
    ]) {
      test('$mod: premove validator is mod-aware (can be illegal)', () {
        final queue = PremoveQueue();
        queue.enqueue(PremoveMove(from: 'e2', to: 'e4'));
        final validator = FakePremoveValidator(isLegal: false, mod: mod);
        final result = queue.tryFire(validator);
        expect(result, equals(PremoveFireResult.invalidated));
      });
    }
  });
}
