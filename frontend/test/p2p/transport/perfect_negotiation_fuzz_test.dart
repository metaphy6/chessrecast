// §4.7 Perfect-negotiation fuzz test — 1k random simultaneous-offer scenarios.
//
// Verifies no deadlock: every random pair of fingerprints yields a
// (polite, impolite) pair with no ties.
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/transport/perfect_negotiation.dart';

void main() {
  test('1k random fingerprint pairs → no deadlock', () {
    final rng = Random(42); // fixed seed for reproducibility
    for (var i = 0; i < 1000; i++) {
      final fp1 = List.generate(
          16, (_) => rng.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
      final fp2 = List.generate(
          16, (_) => rng.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
      if (fp1 == fp2) continue; // vanishingly unlikely with 128-bit space
      final r1 = PerfectNegotiation.determineRole(
          myFingerprint: fp1, peerFingerprint: fp2);
      final r2 = PerfectNegotiation.determineRole(
          myFingerprint: fp2, peerFingerprint: fp1);
      expect({r1, r2}.length, equals(2),
          reason: 'deadlock at i=$i fp1=$fp1 fp2=$fp2');
    }
  });
}
