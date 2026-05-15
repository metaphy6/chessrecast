import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/identity/identity.dart';

/// Argon2id performance probe (§2.4).
///
/// This test verifies that Argon2id derivation does NOT exceed a reasonable
/// wall-clock budget at floor params. It is NOT a benchmark — it just guards
/// against accidental N² behaviour in the stub.
///
/// The floor params (m=16 MiB, t=4) are guaranteed by [argon2_floor_enforced_test.dart].
void main() {
  group('Argon2id performance (§2.4)', () {
    test('derivation at floor params completes within 10s', () {
      // NOTE: The pure-Dart stub is not timing-representative of real Argon2id.
      // This test guards against accidental O(n²) or infinite loops only.
      // Production benchmarks use the libsodium path and a dedicated perf CI job.
      final password = Uint8List.fromList('test-password-abc'.codeUnits);
      final salt = Uint8List(16)..fillRange(0, 16, 0x42);
      final sw = Stopwatch()..start();
      Argon2idStub.derive(
        password: password,
        salt: salt,
        mKib: Argon2idStub.mMinKib,
        iterations: Argon2idStub.tMin,
      );
      sw.stop();
      // The stub must complete in under 10 seconds (very generous for a stub)
      expect(sw.elapsed, lessThan(const Duration(seconds: 10)));
    });

    test('derivation is faster for fewer iterations (or equal for stub)', () {
      final password = Uint8List.fromList([1, 2, 3, 4, 5]);
      final salt = Uint8List(16)..fillRange(0, 16, 0x55);
      final sw4 = Stopwatch()..start();
      Argon2idStub.derive(
        password: password,
        salt: salt,
        mKib: Argon2idStub.mMinKib,
        iterations: Argon2idStub.tMin, // 4
      );
      sw4.stop();
      final sw8 = Stopwatch()..start();
      Argon2idStub.derive(
        password: password,
        salt: salt,
        mKib: Argon2idStub.mMinKib,
        iterations: Argon2idStub.tMin * 2, // 8
      );
      sw8.stop();
      // More iterations should take >= time (may be equal for tiny inputs in the stub)
      expect(
        sw8.elapsed.inMicroseconds,
        greaterThanOrEqualTo(sw4.elapsed.inMicroseconds),
      );
    });

    test('derives a 32-byte output at floor params', () {
      final password = Uint8List.fromList('perf-check'.codeUnits);
      final salt = Uint8List(16)..fillRange(0, 16, 0x66);
      final out = Argon2idStub.derive(
        password: password,
        salt: salt,
        mKib: Argon2idStub.mMinKib,
        iterations: Argon2idStub.tMin,
      );
      expect(out.length, equals(32));
    });
  });
}
