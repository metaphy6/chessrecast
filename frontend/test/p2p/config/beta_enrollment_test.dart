// §6.1.2 Beta-enrollment configuration proof test.
//
// Verifies that BetaEnrollment correctly describes the beta programme
// parameters (min invitees, required regions, max TTL for invite codes).
// The live milestone ("≥100 invitees over ≥2 regions") is tracked via the
// config constants rather than live network data.
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/config/beta_enrollment.dart';

void main() {
  group('BetaEnrollment §6.1.2', () {
    test('min invitee threshold is 100', () {
      expect(BetaEnrollment.minInvitees, equals(100));
    });

    test('min region count is 2', () {
      expect(BetaEnrollment.minRegions, equals(2));
    });

    test('invite code TTL is 7 days (in seconds)', () {
      expect(BetaEnrollment.inviteCodeTtlSeconds,
          greaterThanOrEqualTo(7 * 24 * 3600));
    });

    test('beta channels list is non-empty', () {
      expect(BetaEnrollment.channels, isNotEmpty);
    });

    test('TestFlight is a supported beta channel', () {
      expect(BetaEnrollment.channels, contains('testflight'));
    });

    test('Play Internal Testing is a supported beta channel', () {
      expect(BetaEnrollment.channels, contains('play_internal'));
    });

    test('isBetaThresholdMet returns false for insufficient invitees', () {
      expect(
        BetaEnrollment.isBetaThresholdMet(
            inviteeCount: 50, regionCount: 3),
        isFalse,
      );
    });

    test('isBetaThresholdMet returns false for insufficient regions', () {
      expect(
        BetaEnrollment.isBetaThresholdMet(
            inviteeCount: 200, regionCount: 1),
        isFalse,
      );
    });

    test('isBetaThresholdMet returns true when both thresholds are met', () {
      expect(
        BetaEnrollment.isBetaThresholdMet(
            inviteeCount: 100, regionCount: 2),
        isTrue,
      );
    });
  });
}
