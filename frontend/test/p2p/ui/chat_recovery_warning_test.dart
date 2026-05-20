// T-CHAT-001 §9.9 — Chat screen warns user before navigating to recovery flow.
//
// Proof: ChatRecoveryWarningPolicy.requiresWarning() returns true when the
// trigger source is an active chat session, and false for safe contexts.
import 'package:flutter_test/flutter_test.dart';
import '../../../lib/services/p2p/ui/chat_recovery_warning.dart';

void main() {
  group('T-CHAT-001 §9.9 — Chat → recovery navigation warning', () {
    test('requiresWarning is true when navigating from an active chat session', () {
      expect(
        ChatRecoveryWarningPolicy.requiresWarning(
            RecoveryTriggerSource.chatSession),
        isTrue,
        reason: 'seed exposure in active session must be guarded',
      );
    });

    test('requiresWarning is false when navigating from settings', () {
      expect(
        ChatRecoveryWarningPolicy.requiresWarning(
            RecoveryTriggerSource.settings),
        isFalse,
      );
    });

    test('requiresWarning is false during onboarding', () {
      expect(
        ChatRecoveryWarningPolicy.requiresWarning(
            RecoveryTriggerSource.onboarding),
        isFalse,
      );
    });

    test('warning message is non-empty and mentions seed phrase', () {
      expect(ChatRecoveryWarningPolicy.kWarningMessage, isNotEmpty);
      expect(
        ChatRecoveryWarningPolicy.kWarningMessage.toLowerCase(),
        contains('seed'),
      );
    });
  });
}
