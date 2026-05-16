// §6.7.1 First-launch P2P onboarding proof test.
//
// Verifies the four-screen onboarding wizard state machine:
//   1. p2pExplainer — what P2P means
//   2. recoveryCode — recovery-code gen + re-entry verification
//   3. chatSafety   — chat-safety primer + phishing warning
//   4. contactVerification — contact-verification primer
//
// The user must complete all 4 before matchmaking is unlocked.
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/onboarding/p2p_onboarding.dart';

void main() {
  group('P2pOnboardingState §6.7.1', () {
    late P2pOnboardingState state;

    setUp(() => state = P2pOnboardingState());

    test('defines exactly 4 onboarding screens', () {
      expect(P2pOnboardingState.allScreens, hasLength(4));
    });

    test('first screen is p2pExplainer', () {
      expect(P2pOnboardingState.allScreens.first,
          equals(OnboardingScreen.p2pExplainer));
    });

    test('last screen is contactVerification', () {
      expect(P2pOnboardingState.allScreens.last,
          equals(OnboardingScreen.contactVerification));
    });

    test('onboarding is not complete at start', () {
      expect(state.isOnboardingComplete, isFalse);
    });

    test('currentScreen is p2pExplainer at start', () {
      expect(state.currentScreen, equals(OnboardingScreen.p2pExplainer));
    });

    test('completing all screens in order unlocks matchmaking', () {
      for (final screen in P2pOnboardingState.allScreens) {
        state.completeScreen(screen);
      }
      expect(state.isOnboardingComplete, isTrue);
      expect(state.currentScreen, isNull);
    });

    test('completing screens out of order throws StateError', () {
      expect(
        () => state.completeScreen(OnboardingScreen.recoveryCode),
        throwsStateError,
      );
    });

    test('matchmaking is not unlocked after only 3 screens', () {
      for (final screen in P2pOnboardingState.allScreens.take(3)) {
        state.completeScreen(screen);
      }
      expect(state.isOnboardingComplete, isFalse);
      expect(state.currentScreen, equals(OnboardingScreen.contactVerification));
    });

    test('reset clears all progress', () {
      for (final screen in P2pOnboardingState.allScreens) {
        state.completeScreen(screen);
      }
      state.reset();
      expect(state.isOnboardingComplete, isFalse);
      expect(state.completedCount, equals(0));
    });

    test('isCompleted returns false before completing a screen', () {
      expect(
          state.isCompleted(OnboardingScreen.p2pExplainer), isFalse);
    });

    test('isCompleted returns true after completing a screen', () {
      state.completeScreen(OnboardingScreen.p2pExplainer);
      expect(state.isCompleted(OnboardingScreen.p2pExplainer), isTrue);
    });
  });
}
