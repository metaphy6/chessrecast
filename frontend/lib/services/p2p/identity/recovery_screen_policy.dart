// §9.9 T-D-006 — Recovery screen applies FLAG_SECURE (screenshots disabled).
// §9.9 T-D-007 — Recovery screen offers custom keyboard option.
//
// These policies prevent the seed phrase from leaking via:
//   - Screenshot / screen-recording APIs (FLAG_SECURE / iOS Privacy flag).
//   - Third-party keyboard apps that may log keystrokes.
library;

/// Platform flags that must be applied to any screen displaying secret material
/// (seed phrase, private key, safety numbers).
class ScreenSecurityPolicy {
  /// True when FLAG_SECURE (Android) / allowScreenshot=false (iOS) must be set.
  ///
  /// Must be true for the recovery screen.
  final bool screenshotsDisabled;

  /// True when the custom secure keyboard must be offered as default.
  ///
  /// Prevents third-party IME keystroke logging during seed entry.
  final bool useSecureKeyboard;

  const ScreenSecurityPolicy({
    required this.screenshotsDisabled,
    required this.useSecureKeyboard,
  });

  /// The policy that MUST be applied on the recovery screen.
  static const ScreenSecurityPolicy recoveryScreen = ScreenSecurityPolicy(
    screenshotsDisabled: true,
    useSecureKeyboard: true,
  );

  /// Policy for non-sensitive screens (no restrictions).
  static const ScreenSecurityPolicy standard = ScreenSecurityPolicy(
    screenshotsDisabled: false,
    useSecureKeyboard: false,
  );

  /// Assert that [policy] satisfies the recovery-screen requirements.
  ///
  /// Throws [AssertionError] if screenshots are allowed or the secure
  /// keyboard is not offered.
  static void assertRecoveryRequirements(ScreenSecurityPolicy policy) {
    assert(
      policy.screenshotsDisabled,
      'Recovery screen must set FLAG_SECURE / disable screenshots',
    );
    assert(
      policy.useSecureKeyboard,
      'Recovery screen must offer the secure keyboard to prevent IME logging',
    );
  }
}

/// Clipboard policy for the recovery / seed-phrase screen (T-D-006b).
///
/// The recovery mnemonic must NOT be auto-copied or auto-pasted to/from the
/// system clipboard — clipboard content is accessible to any app.
class ClipboardPolicy {
  /// Whether clipboard paste is allowed on this screen.
  final bool allowPaste;

  /// Whether the "copy to clipboard" action is offered.
  final bool allowCopy;

  const ClipboardPolicy({required this.allowPaste, required this.allowCopy});

  /// Policy for the recovery / seed-phrase input screen.
  ///
  /// Both copy and paste are disabled: the user must type the phrase manually.
  static const ClipboardPolicy recoveryScreen = ClipboardPolicy(
    allowPaste: false,
    allowCopy: false,
  );

  /// Standard policy (e.g., ordinary text fields).
  static const ClipboardPolicy standard = ClipboardPolicy(
    allowPaste: true,
    allowCopy: true,
  );

  bool get isRestricted => !allowPaste && !allowCopy;
}
