// §11.9 — Five-fold auto-draw per FIDE 2014+.
//
// Both engines force a draw without UX when five-fold repetition occurs.
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/clock/repetition.dart';

void main() {
  group('§11.9 five_fold_auto_draw', () {
    test('fifth occurrence triggers mandatory draw', () {
      final tracker = RepetitionTracker();
      const hash = 'pos_hash';
      for (int i = 0; i < 5; i++) {
        tracker.record(hash);
        if (i < 4) tracker.record('other_$i');
      }
      expect(tracker.isFiveFold(hash), isTrue);
      expect(tracker.isAutoDrawRequired(hash), isTrue);
    });

    test('fourth occurrence does not trigger auto-draw', () {
      final tracker = RepetitionTracker();
      const hash = 'pos_hash';
      for (int i = 0; i < 4; i++) {
        tracker.record(hash);
        if (i < 3) tracker.record('other_$i');
      }
      expect(tracker.isFiveFold(hash), isFalse);
      expect(tracker.isAutoDrawRequired(hash), isFalse);
    });

    test('cross-peer: both trackers reach five-fold on same hash', () {
      final trackerA = RepetitionTracker();
      final trackerB = RepetitionTracker();

      const hash = 'shared_hash';
      // Both peers record the same move sequence (deterministic).
      for (int i = 0; i < 9; i++) {
        final h = i.isEven ? hash : 'other_$i';
        trackerA.record(h);
        trackerB.record(h);
      }
      // hash appears at i=0,2,4,6,8 → 5 times.
      expect(trackerA.isFiveFold(hash), isTrue);
      expect(trackerB.isFiveFold(hash), isTrue);
      expect(trackerA.isAutoDrawRequired(hash), isTrue);
      expect(trackerB.isAutoDrawRequired(hash), isTrue);
    });

    test('different positions do not pollute each other', () {
      final tracker = RepetitionTracker();
      const hashA = 'pos_a';
      const hashB = 'pos_b';

      for (int i = 0; i < 5; i++) {
        tracker.record(hashA);
      }
      for (int i = 0; i < 2; i++) {
        tracker.record(hashB);
      }
      expect(tracker.isAutoDrawRequired(hashA), isTrue);
      expect(tracker.isAutoDrawRequired(hashB), isFalse);
    });
  });
}
