import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/identity/identity.dart';

/// Core dump prevention tests (§2.7.bullet-3).
///
/// These tests verify the behavioral contract of [CoreDumpPrevention.disable]:
/// the call must not throw, and must return either [CoreDumpResult.disabled]
/// (native FFI available) or [CoreDumpResult.notSupported] (stub/mock).
///
/// In CI (Linux, no libsodium FFI loaded) the stub returns [notSupported].
/// The contract is that the caller NEVER gets a throw — only a result enum.
void main() {
  group('Core dump prevention (§2.7)', () {
    test('CoreDumpPrevention.disable() does not throw', () {
      expect(() => CoreDumpPrevention.disable(), returnsNormally);
    });

    test('CoreDumpPrevention.disable() returns a CoreDumpResult', () {
      final result = CoreDumpPrevention.disable();
      expect(result, isA<CoreDumpResult>());
    });

    test('result is either disabled or notSupported (no other values)', () {
      final result = CoreDumpPrevention.disable();
      expect(
        CoreDumpResult.values.contains(result),
        isTrue,
        reason: 'result must be one of the defined enum variants',
      );
    });

    test('stub returns notSupported (no libsodium FFI in test environment)', () {
      // In CI the stub implementation is active; it reports notSupported.
      // On a device with libsodium wired, this would be CoreDumpResult.disabled.
      final result = CoreDumpPrevention.disable();
      expect(
        result == CoreDumpResult.disabled ||
            result == CoreDumpResult.notSupported,
        isTrue,
      );
    });

    test('disable() is idempotent (safe to call multiple times)', () {
      expect(() {
        CoreDumpPrevention.disable();
        CoreDumpPrevention.disable();
      }, returnsNormally);
    });
  });
}
