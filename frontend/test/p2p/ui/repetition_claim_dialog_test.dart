// §11.9 — Repetition-claim wiring.
//
// Three-fold repetition is claimable per FIDE rules — the player whose move it
// is can play the move that causes the third occurrence and claim a draw, or
// play it without claiming.
// Five-fold repetition is automatic (FIDE 2014+).
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/clock/repetition.dart';

void main() {
  group('§11.9 repetition_claim_dialog', () {
    test('detects three-fold repetition', () {
      final tracker = RepetitionTracker();
      // Add the same hash three times with different interleaving.
      const hash = 'abc123';
      tracker.record(hash);
      tracker.record('xyz789');
      tracker.record(hash);
      tracker.record('lmn456');
      tracker.record(hash); // Third occurrence.

      expect(tracker.isThreeFold(hash), isTrue);
    });

    test('two occurrences is not three-fold', () {
      final tracker = RepetitionTracker();
      const hash = 'abc123';
      tracker.record(hash);
      tracker.record('other');
      tracker.record(hash);

      expect(tracker.isThreeFold(hash), isFalse);
    });

    test('detects five-fold repetition', () {
      final tracker = RepetitionTracker();
      const hash = 'abc123';
      for (int i = 0; i < 9; i++) {
        tracker.record(i.isEven ? hash : 'other_$i');
      }
      // hash recorded at i=0,2,4,6,8 → 5 times.
      expect(tracker.isFiveFold(hash), isTrue);
    });

    test('five-fold triggers auto-draw flag', () {
      final tracker = RepetitionTracker();
      const hash = 'rep_hash';
      for (int i = 0; i < 5; i++) {
        tracker.record(hash);
        tracker.record('other_$i');
      }
      // 5 occurrences of hash.
      expect(tracker.isAutoDrawRequired(hash), isTrue);
    });

    test('three-fold claim is optional; five-fold is mandatory', () {
      final tracker = RepetitionTracker();
      const hash = 'test';
      for (int i = 0; i < 3; i++) {
        tracker.record(hash);
        tracker.record('x_$i');
      }
      // Three-fold → claimable but not mandatory.
      expect(tracker.isThreeFold(hash), isTrue);
      expect(tracker.isAutoDrawRequired(hash), isFalse);
    });
  });
}
