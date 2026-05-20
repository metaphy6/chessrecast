// §9.9 T-CHAT-001 — Chat screen warns user before navigating to recovery flow.
//
// A user chatting with a peer may inadvertently enter the recovery flow and
// expose their seed phrase.  A warning dialog must be shown before any
// navigation to the recovery screen from the chat context.
library;

/// Navigation sources that can trigger a recovery screen.
enum RecoveryTriggerSource {
  /// Triggered from the settings menu (normal path — no warning needed).
  settings,

  /// Triggered while a chat session is active — warning required.
  chatSession,

  /// Triggered from the onboarding flow (no warning needed).
  onboarding,
}

/// Policy for showing a pre-navigation warning before the recovery screen.
class ChatRecoveryWarningPolicy {
  /// True when [source] requires a warning dialog before opening recovery.
  static bool requiresWarning(RecoveryTriggerSource source) {
    return source == RecoveryTriggerSource.chatSession;
  }

  /// Warning message to show in the dialog.
  static const String kWarningMessage =
      'You are currently in an active session. Navigating to the recovery '
      'screen will expose your seed phrase. Are you sure you want to continue?';
}
