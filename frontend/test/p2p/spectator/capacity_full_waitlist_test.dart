// §7.8.2 capacity full / waitlist proof test (Dart side).
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/spectator/spectator_capacity.dart';

void main() {
  group('SpectatorCapacityManager §7.8.2', () {
    test('seats up to defaultCap (50) without error', () {
      final mgr = SpectatorCapacityManager();
      for (var i = 0; i < SpectatorCapacityManager.defaultCap; i++) {
        final key = Uint8List.fromList(List.generate(32, (_) => (i + 1) % 256));
        final result = mgr.admit(key);
        expect(result, isNull, reason: 'seat $i should succeed');
      }
      expect(mgr.seatedCount, equals(SpectatorCapacityManager.defaultCap));
    });

    test('waitlists on full', () {
      final mgr = SpectatorCapacityManager(cap: 1);
      mgr.admit(Uint8List.fromList(List.generate(32, (_) => 1)));
      final result = mgr.admit(Uint8List.fromList(List.generate(32, (_) => 2)));
      expect(result, equals('WAITLISTED'));
    });

    test('returns SPECTATOR_CAPACITY_FULL when waitlist also full', () {
      final mgr = SpectatorCapacityManager(cap: 1);
      mgr.admit(Uint8List.fromList(List.generate(32, (_) => 0)));
      for (var i = 0; i < SpectatorCapacityManager.waitlistMaxDepth; i++) {
        mgr.admit(Uint8List.fromList(List.generate(32, (_) => (i + 1) % 256)));
      }
      final result = mgr.admit(Uint8List.fromList(List.generate(32, (_) => 0xFE)));
      expect(result, equals('SPECTATOR_CAPACITY_FULL'));
    });

    test('hard ceiling is 200', () {
      expect(SpectatorCapacityManager.hardCeiling, equals(200));
    });

    test('per-account cap is 100', () {
      expect(AccountSpectatorQuota.perAccountCap, equals(100));
    });

    test('lower-of-two wins', () {
      final effective = SpectatorCapacityManager.lowerOf(200, 30);
      expect(effective, equals(30));
    });

    test('release promotes from waitlist', () {
      final keyA = Uint8List.fromList(List.generate(32, (_) => 0xAA));
      final keyW = Uint8List.fromList(List.generate(32, (_) => 0xBB));
      final mgr = SpectatorCapacityManager(cap: 1);
      mgr.admit(keyA);
      mgr.admit(keyW);
      expect(mgr.seatedCount, equals(1));
      mgr.release(keyA);
      expect(mgr.seatedCount, equals(1)); // waiter promoted
    });
  });
}
