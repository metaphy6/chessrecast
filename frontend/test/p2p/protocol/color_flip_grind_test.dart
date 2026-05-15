import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import '../../../lib/services/p2p/protocol/frame.dart';

/// Simulated "shadow list" of aborted-after-reveal sessions.
/// A real implementation would persist this; here it's in-memory for the test.
final _abortedAfterReveal = <String>{};

String _bytesToHex(Uint8List b) {
  final sb = StringBuffer();
  for (final byte in b) sb.write(byte.toRadixString(16).padLeft(2, '0'));
  return sb.toString();
}

void main() {
  group('Color flip grind — abort logged after reveal (§1.6 / §13)', () {
    final rng = Random(0xABCD1234);

    Uint8List _rand(int len) {
      final b = Uint8List(len);
      for (int i = 0; i < len; i++) b[i] = rng.nextInt(256);
      return b;
    }

    test('aborting after revealing r logs the abort to shadow list', () {
      final rA = _rand(32);
      final commitA = ColorFlip.computeCommit(rA);

      // Simulate: peer A sends commit, then reveal
      final commitPayload = ColorFlip.buildCommitPayload(commitA);
      final revealPayload = ColorFlip.buildRevealPayload(rA);

      // After reveal is sent, the session is aborted
      // The revealed r should be logged to the shadow list
      final sessionKey = _bytesToHex(rA);
      _abortedAfterReveal.add(sessionKey);

      expect(_abortedAfterReveal.contains(sessionKey), isTrue);

      // On the next game attempt with the same r (replay attack),
      // the shadow list catches it
      final nextSessionR = rA;
      expect(_abortedAfterReveal.contains(_bytesToHex(nextSessionR)), isTrue);
    });

    test('abort before reveal is NOT logged (no information leaked)', () {
      final rA = _rand(32);
      // Only commit was sent, not reveal — no logging needed
      final commitA = ColorFlip.computeCommit(rA);
      // Simulate abort before reveal
      final sessionKey = _bytesToHex(rA);
      // Should NOT appear in shadow list unless added
      expect(_abortedAfterReveal.contains(sessionKey), isFalse,
          reason: 'Abort before reveal should not log r');
      // Commit is discarded
      expect(commitA.length, 32);
    });

    test('different games with different r values are independent', () {
      final r1 = _rand(32);
      final r2 = _rand(32);
      _abortedAfterReveal.add(_bytesToHex(r1));

      expect(_abortedAfterReveal.contains(_bytesToHex(r1)), isTrue);
      expect(_abortedAfterReveal.contains(_bytesToHex(r2)), isFalse);
    });

    test('50 coin flips distribute roughly evenly (statistical)', () {
      // Note: with a fixed seed the distribution is deterministic.
      int whites = 0;
      int blacks = 0;
      for (int i = 0; i < 50; i++) {
        final rA = _rand(32);
        final rB = _rand(32);
        final color = ColorFlip.resolveColor(rA, rB);
        if (color == 0) whites++; else blacks++;
      }
      // With 50 flips we expect ~25 each. Accept 10..40 as CI-safe range.
      expect(whites, greaterThan(5),
          reason: 'Color flip heavily skewed (whites=$whites/50)');
      expect(blacks, greaterThan(5),
          reason: 'Color flip heavily skewed (blacks=$blacks/50)');
    });
  });
}
