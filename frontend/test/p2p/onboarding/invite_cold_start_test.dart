// §6.7.5 Cold-start deep-link proof test.
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/onboarding/cold_start_invite.dart';
import '../../../lib/services/p2p/onboarding/p2p_onboarding.dart';

ColdStartInviteFlow _makeFlow({P2pOnboardingState? onboarding}) {
  return ColdStartInviteFlow(
    storage: {},
    onboarding: onboarding ?? P2pOnboardingState(),
  );
}

P2pOnboardingState _completedOnboarding() {
  final s = P2pOnboardingState();
  for (final screen in P2pOnboardingState.allScreens) {
    s.completeScreen(screen);
  }
  return s;
}

const _fakeLink = 'fake_invite_token_112_chars_AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';

void main() {
  group('ColdStartInviteFlow §6.7.5', () {
    test('hasPendingLink is false when nothing stored', () {
      expect(_makeFlow().hasPendingLink, isFalse);
    });

    test('storePendingLink makes hasPendingLink true', () {
      final flow = _makeFlow();
      flow.storePendingLink(_fakeLink);
      expect(flow.hasPendingLink, isTrue);
    });

    test('link survives simulated process restart via shared storage', () {
      // Simulate two separate ColdStartInviteFlow instances sharing storage.
      final sharedStorage = <String, String>{};
      final flowA = ColdStartInviteFlow(
          storage: sharedStorage, onboarding: P2pOnboardingState());
      flowA.storePendingLink(_fakeLink);

      final flowB = ColdStartInviteFlow(
          storage: sharedStorage, onboarding: _completedOnboarding());
      expect(flowB.hasPendingLink, isTrue);
    });

    test('tryRedeem returns onboardingRequired when onboarding not done', () {
      final flow = _makeFlow();
      flow.storePendingLink(_fakeLink);
      final (:result, :link) = flow.tryRedeem();
      expect(result, equals(InviteRedemptionResult.onboardingRequired));
      expect(link, isNull);
    });

    test('link is still stored after onboardingRequired result', () {
      final flow = _makeFlow();
      flow.storePendingLink(_fakeLink);
      flow.tryRedeem();
      expect(flow.hasPendingLink, isTrue);
    });

    test('tryRedeem redeems link after onboarding completes', () {
      final onboarding = _completedOnboarding();
      final flow = ColdStartInviteFlow(storage: {}, onboarding: onboarding);
      flow.storePendingLink(_fakeLink);
      final (:result, :link) = flow.tryRedeem();
      expect(result, equals(InviteRedemptionResult.redeemed));
      expect(link, equals(_fakeLink));
    });

    test('link is cleared after successful redemption', () {
      final flow = ColdStartInviteFlow(
          storage: {}, onboarding: _completedOnboarding());
      flow.storePendingLink(_fakeLink);
      flow.tryRedeem();
      expect(flow.hasPendingLink, isFalse);
    });

    test('tryRedeem returns noPendingLink when nothing stored', () {
      final flow = ColdStartInviteFlow(
          storage: {}, onboarding: _completedOnboarding());
      final (:result, :link) = flow.tryRedeem();
      expect(result, equals(InviteRedemptionResult.noPendingLink));
      expect(link, isNull);
    });

    test('onboarding-first ordering: route to wizard then honour invite', () {
      final onboarding = P2pOnboardingState();
      final flow = ColdStartInviteFlow(storage: {}, onboarding: onboarding);
      flow.storePendingLink(_fakeLink);

      // Step 1 — not ready.
      expect(
          flow.tryRedeem().result, InviteRedemptionResult.onboardingRequired);

      // Step 2 — complete onboarding.
      for (final screen in P2pOnboardingState.allScreens) {
        onboarding.completeScreen(screen);
      }

      // Step 3 — now redeem.
      final (:result, :link) = flow.tryRedeem();
      expect(result, equals(InviteRedemptionResult.redeemed));
      expect(link, equals(_fakeLink));
    });
  });
}
