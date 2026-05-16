// §6.7 P2P onboarding state machine.
//
// Tracks the four-screen first-launch onboarding flow that must be completed
// before the matchmaking surface is unlocked.
//
// Screens (in order):
//   1. What P2P means here in plain language.
//   2. Recovery-code generation with re-entry verification (§2.2).
//   3. Chat-safety primer + phishing warning (§14.6).
//   4. Optional contact-verification primer (§2.9).

/// Represents one screen in the first-launch P2P onboarding flow.
enum OnboardingScreen {
  /// Screen 1 — plain-language explanation of P2P.
  p2pExplainer,

  /// Screen 2 — recovery-code generation and re-entry verification.
  recoveryCode,

  /// Screen 3 — chat-safety primer and phishing warning.
  chatSafety,

  /// Screen 4 — optional contact-verification primer.
  contactVerification,
}

/// Manages state for the first-launch P2P onboarding wizard.
///
/// The user must complete all four screens (in order) before
/// [isOnboardingComplete] returns `true`.
class P2pOnboardingState {
  final Set<OnboardingScreen> _completed = {};

  /// Ordered list of all onboarding screens.
  static const List<OnboardingScreen> allScreens = [
    OnboardingScreen.p2pExplainer,
    OnboardingScreen.recoveryCode,
    OnboardingScreen.chatSafety,
    OnboardingScreen.contactVerification,
  ];

  /// Returns the current screen that the user should see, or `null` when
  /// onboarding is complete.
  OnboardingScreen? get currentScreen {
    for (final screen in allScreens) {
      if (!_completed.contains(screen)) return screen;
    }
    return null;
  }

  /// Returns `true` when all four screens have been completed.
  bool get isOnboardingComplete => _completed.length == allScreens.length;

  /// Marks [screen] as completed.  Screens must be completed in order;
  /// throws [StateError] if a screen is completed out of order.
  void completeScreen(OnboardingScreen screen) {
    final expectedIndex = _completed.length;
    if (allScreens[expectedIndex] != screen) {
      throw StateError(
        'Expected to complete ${allScreens[expectedIndex].name} '
        'but got ${screen.name}. Screens must be completed in order.',
      );
    }
    _completed.add(screen);
  }

  /// Returns the number of completed screens.
  int get completedCount => _completed.length;

  /// Returns `true` when [screen] has been completed.
  bool isCompleted(OnboardingScreen screen) => _completed.contains(screen);

  /// Resets all progress (e.g. on account change or app re-install).
  void reset() => _completed.clear();
}
