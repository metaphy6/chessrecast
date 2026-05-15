import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import '../../../lib/services/p2p/protocol/frame.dart';

void main() {
  group('Session ID collision resistance (§1.9 — §11)', () {
    final iterations =
        int.tryParse(Platform.environment['P2P_FUZZ_ITERATIONS'] ?? '') ?? 1000;

    test('$iterations random handshakes produce no collisions', () {
      // Use a deterministic RNG to make the test reproducible.
      final sessionIds = <String>{};
      int collisions = 0;

      for (int i = 0; i < iterations; i++) {
        // Derive deterministic but unique inputs for each "handshake"
        final ephPubA = _deriveBytes(i, 0, 32);
        final ephPubB = _deriveBytes(i, 1, 32);
        final nonceA = _deriveBytes(i, 2, 32);
        final nonceB = _deriveBytes(i, 3, 32);

        final sid = SessionIdDeriver.derive(
          ephPubA: ephPubA,
          ephPubB: ephPubB,
          nonceA: nonceA,
          nonceB: nonceB,
        );

        final hexId = _toHex(sid);
        if (sessionIds.contains(hexId)) {
          collisions++;
        }
        sessionIds.add(hexId);
      }

      expect(
        collisions,
        0,
        reason: '$collisions collisions found in $iterations session IDs',
      );
    });

    test('swapping ephPubA/ephPubB does not change session ID (symmetric)', () {
      final ephPubA = _deriveBytes(99, 0, 32);
      final ephPubB = _deriveBytes(99, 1, 32);
      final nonceA = _deriveBytes(99, 2, 32);
      final nonceB = _deriveBytes(99, 3, 32);

      final sidAB = SessionIdDeriver.derive(
        ephPubA: ephPubA,
        ephPubB: ephPubB,
        nonceA: nonceA,
        nonceB: nonceB,
      );
      final sidBA = SessionIdDeriver.derive(
        ephPubA: ephPubB,
        ephPubB: ephPubA,
        nonceA: nonceA,
        nonceB: nonceB,
      );

      expect(sidAB, equals(sidBA));
    });

    test('swapping nonceA/nonceB does not change session ID (symmetric)', () {
      final ephPubA = _deriveBytes(100, 0, 32);
      final ephPubB = _deriveBytes(100, 1, 32);
      final nonceA = _deriveBytes(100, 2, 32);
      final nonceB = _deriveBytes(100, 3, 32);

      final sid1 = SessionIdDeriver.derive(
        ephPubA: ephPubA,
        ephPubB: ephPubB,
        nonceA: nonceA,
        nonceB: nonceB,
      );
      final sid2 = SessionIdDeriver.derive(
        ephPubA: ephPubA,
        ephPubB: ephPubB,
        nonceA: nonceB,
        nonceB: nonceA,
      );

      expect(sid1, equals(sid2));
    });

    test('changing any single input byte produces a different session ID', () {
      final ephPubA = Uint8List(32)..fillRange(0, 32, 0x01);
      final ephPubB = Uint8List(32)..fillRange(0, 32, 0x02);
      final nonceA = Uint8List(32)..fillRange(0, 32, 0x03);
      final nonceB = Uint8List(32)..fillRange(0, 32, 0x04);

      final original = SessionIdDeriver.derive(
        ephPubA: ephPubA,
        ephPubB: ephPubB,
        nonceA: nonceA,
        nonceB: nonceB,
      );

      // Flip first byte of ephPubA
      final mutated = Uint8List.fromList(ephPubA);
      mutated[0] ^= 0xFF;
      final modified = SessionIdDeriver.derive(
        ephPubA: mutated,
        ephPubB: ephPubB,
        nonceA: nonceA,
        nonceB: nonceB,
      );

      expect(original, isNot(equals(modified)));
    });
  });
}

/// Derives deterministic pseudo-random bytes for testing.
Uint8List _deriveBytes(int seed1, int seed2, int length) {
  final b = Uint8List(length);
  for (int i = 0; i < length; i++) {
    // Simple deterministic "hash" for test use only
    b[i] = ((seed1 * 31 + seed2 * 17 + i * 7) ^ (seed1 >> 2)) & 0xFF;
  }
  return b;
}

String _toHex(Uint8List b) {
  final sb = StringBuffer();
  for (final byte in b) sb.write(byte.toRadixString(16).padLeft(2, '0'));
  return sb.toString();
}
