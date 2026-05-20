// §14.1 — Block-list persistence round-trip test.
//
// Simulates serialise → load → verify for block-list entries, exercising
// the `loadFrom` path that the SQLCipher persistence layer would drive.
library;

import 'package:flutter_test/flutter_test.dart';
import '../../../lib/services/p2p/ui/block_list.dart';

void main() {
  group('§14.1 — BlockList persistence (loadFrom round-trip)', () {
    test('serialise and reload preserves all fingerprints', () {
      final original = BlockList();
      original.block('fp-alice', kind: BlockKind.device);
      original.block('acc-fp-bob', kind: BlockKind.account);
      original.block('fp-charlie', kind: BlockKind.device);

      // Simulate serialise → SQLCipher write → reload.
      final snapshot = original.entries.toList();

      final reloaded = BlockList();
      reloaded.loadFrom(snapshot);

      expect(reloaded.length, equals(3));
      expect(reloaded.isBlocked('fp-alice'), isTrue);
      expect(reloaded.isBlocked('acc-fp-bob'), isTrue);
      expect(reloaded.isBlocked('fp-charlie'), isTrue);
    });

    test('reload after unblock does not restore removed entry', () {
      final original = BlockList();
      original.block('fp-alice');
      original.unblock('fp-alice');

      final snapshot = original.entries.toList();
      final reloaded = BlockList();
      reloaded.loadFrom(snapshot);

      expect(reloaded.isBlocked('fp-alice'), isFalse);
      expect(reloaded.length, equals(0));
    });

    test('loadFrom is idempotent for duplicate fingerprints in source', () {
      // Duplicate fingerprints in source list (should not crash, deduped).
      final when = DateTime(2025);
      final entries = [
        BlockEntry(
          fingerprint: 'fp-dup',
          kind: BlockKind.device,
          addedAt: when,
        ),
        BlockEntry(
          fingerprint: 'fp-dup',
          kind: BlockKind.device,
          addedAt: when,
        ),
      ];
      final list = BlockList();
      list.loadFrom(entries);
      expect(list.length, equals(1));
      expect(list.isBlocked('fp-dup'), isTrue);
    });

    test('empty loadFrom clears existing in-memory state', () {
      final list = BlockList();
      list.block('fp-x');
      list.loadFrom([]);
      expect(list.length, equals(0));
      expect(list.isBlocked('fp-x'), isFalse);
    });

    test('BlockEntry preserves addedAt timestamp', () {
      final ts = DateTime.utc(2025, 6, 1, 12, 0, 0);
      final list = BlockList();
      list.block('fp-ts', addedAt: ts);
      expect(list.entries.first.addedAt, equals(ts));

      final reloaded = BlockList();
      reloaded.loadFrom(list.entries);
      expect(reloaded.entries.first.addedAt, equals(ts));
    });
  });
}
