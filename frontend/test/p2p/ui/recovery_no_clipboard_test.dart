// T-D-006b §9.9 — Recovery / seed-phrase screen disables clipboard paste and copy.
//
// Proof: ClipboardPolicy.recoveryScreen has allowPaste=false and allowCopy=false.
// isRestricted returns true for the recovery screen policy.
import 'package:flutter_test/flutter_test.dart';
import '../../../lib/services/p2p/identity/recovery_screen_policy.dart';

void main() {
  group('T-D-006b §9.9 — Recovery screen: clipboard disabled', () {
    test('recoveryScreen ClipboardPolicy has allowPaste = false', () {
      expect(
        ClipboardPolicy.recoveryScreen.allowPaste,
        isFalse,
        reason: 'clipboard paste enables silent exfiltration from another app',
      );
    });

    test('recoveryScreen ClipboardPolicy has allowCopy = false', () {
      expect(
        ClipboardPolicy.recoveryScreen.allowCopy,
        isFalse,
        reason: 'clipboard copy exposes the seed to any app with clipboard access',
      );
    });

    test('recoveryScreen ClipboardPolicy.isRestricted = true', () {
      expect(ClipboardPolicy.recoveryScreen.isRestricted, isTrue);
    });

    test('standard ClipboardPolicy is not restricted', () {
      expect(ClipboardPolicy.standard.isRestricted, isFalse);
    });

    test('standard ClipboardPolicy allows both copy and paste', () {
      expect(ClipboardPolicy.standard.allowPaste, isTrue);
      expect(ClipboardPolicy.standard.allowCopy, isTrue);
    });
  });
}
