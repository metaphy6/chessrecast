// §4.7 Perfect-negotiation pattern proof test.
//
// Each peer's role (polite/impolite) is deterministically derived from the
// lexicographic comparison of their device_pubkey_fingerprints.
// The impolite peer's offer wins on simultaneous-offer collision.
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/transport/perfect_negotiation.dart';

void main() {
  group('PerfectNegotiation §4.7 role assignment', () {
    test('peer with lexicographically lower fingerprint is polite', () {
      final role = PerfectNegotiation.determineRole(
          myFingerprint: 'aaa', peerFingerprint: 'bbb');
      expect(role, equals(NegotiationRole.polite));
    });

    test('peer with lexicographically higher fingerprint is impolite', () {
      final role = PerfectNegotiation.determineRole(
          myFingerprint: 'bbb', peerFingerprint: 'aaa');
      expect(role, equals(NegotiationRole.impolite));
    });

    test('roles are deterministic (same inputs → same output)', () {
      final r1 = PerfectNegotiation.determineRole(
          myFingerprint: 'fp1', peerFingerprint: 'fp2');
      final r2 = PerfectNegotiation.determineRole(
          myFingerprint: 'fp1', peerFingerprint: 'fp2');
      expect(r1, equals(r2));
    });

    test('impolite peer wins on collision (keeps its offer)', () {
      final state = PerfectNegotiationState(role: NegotiationRole.impolite);
      final decision = state.onSimultaneousOffer();
      expect(decision, equals(OfferCollisionDecision.keepOffer));
    });

    test('polite peer rolls back on collision', () {
      final state = PerfectNegotiationState(role: NegotiationRole.polite);
      final decision = state.onSimultaneousOffer();
      expect(decision, equals(OfferCollisionDecision.rollback));
    });

    test('no deadlock: exactly one side keeps, one rolls back', () {
      const fp1 = 'alpha';
      const fp2 = 'beta';
      final r1 = PerfectNegotiation.determineRole(
          myFingerprint: fp1, peerFingerprint: fp2);
      final r2 = PerfectNegotiation.determineRole(
          myFingerprint: fp2, peerFingerprint: fp1);
      expect({r1, r2},
          containsAll([NegotiationRole.polite, NegotiationRole.impolite]));
    });
  });
}
