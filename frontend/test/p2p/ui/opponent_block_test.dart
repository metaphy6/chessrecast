// §14.1 — Proof tests for BlockList and BlockEntry.
//
// Covers: device-level block, account-level block, O(1) lookup semantics,
// duplicate block idempotency, unblock, load-from-persistence, UI surface
// constants, and the mid-game block BYE reason.
library;

import 'package:flutter_test/flutter_test.dart';
import '../../../lib/services/p2p/ui/block_list.dart';

void main() {
  group('§14.1 — BlockList service', () {
    late BlockList list;

    setUp(() => list = BlockList());

    test('isBlocked returns false for unknown fingerprint', () {
      expect(list.isBlocked('fp-unknown'), isFalse);
    });

    test('block() adds fingerprint; isBlocked returns true', () {
      list.block('fp-alice');
      expect(list.isBlocked('fp-alice'), isTrue);
    });

    test('block() is idempotent for duplicate fingerprint', () {
      list.block('fp-alice');
      list.block('fp-alice'); // second call is a no-op
      expect(list.length, equals(1));
    });

    test('unblock() removes fingerprint; isBlocked returns false', () {
      list.block('fp-alice');
      expect(list.unblock('fp-alice'), isTrue);
      expect(list.isBlocked('fp-alice'), isFalse);
    });

    test('unblock() returns false for unknown fingerprint', () {
      expect(list.unblock('fp-nobody'), isFalse);
    });

    test('block() with BlockKind.account records account kind', () {
      list.block('acc-fp-alice', kind: BlockKind.account);
      final entry = list.entries.first;
      expect(entry.kind, equals(BlockKind.account));
    });

    test('block() defaults to BlockKind.device', () {
      list.block('fp-bob');
      final entry = list.entries.first;
      expect(entry.kind, equals(BlockKind.device));
    });

    test('entries returns unmodifiable snapshot', () {
      list.block('fp-alice');
      final snap = list.entries;
      expect(() => (snap as dynamic).add(null), throwsA(anything));
    });

    test('loadFrom() populates list from persisted entries', () {
      final stored = [
        BlockEntry(
          fingerprint: 'fp-alice',
          kind: BlockKind.device,
          addedAt: DateTime(2025),
        ),
        BlockEntry(
          fingerprint: 'acc-fp-bob',
          kind: BlockKind.account,
          addedAt: DateTime(2025),
        ),
      ];
      list.loadFrom(stored);
      expect(list.isBlocked('fp-alice'), isTrue);
      expect(list.isBlocked('acc-fp-bob'), isTrue);
      expect(list.length, equals(2));
    });

    test('loadFrom() clears existing entries before loading', () {
      list.block('fp-old');
      list.loadFrom([
        BlockEntry(
          fingerprint: 'fp-new',
          kind: BlockKind.device,
          addedAt: DateTime(2025),
        ),
      ]);
      expect(list.isBlocked('fp-old'), isFalse);
      expect(list.isBlocked('fp-new'), isTrue);
    });

    test('kBlockByeReason is user_blocked', () {
      expect(kBlockByeReason, equals('user_blocked'));
    });

    test('can hold multiple simultaneous blocks', () {
      for (var i = 0; i < 100; i++) {
        list.block('fp-$i');
      }
      expect(list.length, equals(100));
      for (var i = 0; i < 100; i++) {
        expect(list.isBlocked('fp-$i'), isTrue);
      }
    });
  });
}
