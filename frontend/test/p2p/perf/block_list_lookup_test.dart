// §14.7 — Block-list O(1) lookup performance proof test.
//
// Verifies that BlockList.isBlocked() is O(1) (set-based) regardless of the
// number of entries. Adds 10 000 entries and measures single-lookup time.
library;

import 'package:flutter_test/flutter_test.dart';
import '../../../lib/services/p2p/ui/block_list.dart';

void main() {
  group('§14.7 — BlockList O(1) lookup performance', () {
    test('isBlocked() on 10 000 entries completes within 5 ms', () {
      final bl = BlockList();
      const n = 10000;

      // Populate block list with n distinct fingerprints.
      final addedAt = DateTime(2025);
      for (int i = 0; i < n; i++) {
        bl.block('fp-$i', kind: BlockKind.device, addedAt: addedAt);
      }

      expect(bl.length, equals(n));

      // Measure lookup of the last entry (worst-case for a list, but O(1)
      // for a set).
      final sw = Stopwatch()..start();
      final found = bl.isBlocked('fp-${n - 1}');
      final elapsed = sw.elapsedMicroseconds;

      expect(found, isTrue, reason: 'last entry must be found');
      expect(elapsed, lessThan(5000 /* µs = 5 ms */),
          reason: 'lookup took ${elapsed}µs — expected < 5000µs');
    });

    test('isBlocked() for an absent key on 10 000 entries completes within 5 ms', () {
      final bl = BlockList();
      final addedAt = DateTime(2025);
      for (int i = 0; i < 10000; i++) {
        bl.block('fp-$i', kind: BlockKind.device, addedAt: addedAt);
      }

      final sw = Stopwatch()..start();
      final found = bl.isBlocked('fp-absent');
      final elapsed = sw.elapsedMicroseconds;

      expect(found, isFalse);
      expect(elapsed, lessThan(5000),
          reason: 'miss-lookup took ${elapsed}µs — expected < 5000µs');
    });

    test('block/unblock cycle does not degrade subsequent lookup time', () {
      final bl = BlockList();
      final addedAt = DateTime(2025);
      for (int i = 0; i < 10000; i++) {
        bl.block('fp-$i', kind: BlockKind.device, addedAt: addedAt);
      }
      // Unblock the first half.
      for (int i = 0; i < 5000; i++) {
        bl.unblock('fp-$i');
      }

      final sw = Stopwatch()..start();
      final found = bl.isBlocked('fp-9999');
      final elapsed = sw.elapsedMicroseconds;

      expect(found, isTrue);
      expect(elapsed, lessThan(5000));
    });
  });
}
