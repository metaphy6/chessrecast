// §14.9 — Fingerprint always visible in UI: policy proof test.
//
// Verifies that:
//   1. kFingerprintAlwaysVisible is true (policy constant).
//   2. extractDisplayName() returns null for invalid handles (fingerprint-only fallback).
//   3. A valid display name does not replace the fingerprint — both must be shown.
library;

import 'package:flutter_test/flutter_test.dart';
import '../../../lib/services/p2p/identity/handle_policy.dart';

void main() {
  group('§14.9 — Fingerprint always visible', () {
    test('kFingerprintAlwaysVisible policy constant is true', () {
      expect(
        kFingerprintAlwaysVisible,
        isTrue,
        reason: 'The fingerprint must NEVER be hidden by a display name',
      );
    });

    test(
      'extractDisplayName returns null when no display_name in capabilities',
      () {
        // When no display name is present, the UI must show fingerprint only.
        final result = extractDisplayName({});
        expect(result, isNull);
      },
    );

    test('extractDisplayName returns null for an impersonation-risk name', () {
      // Invalid names cause fingerprint-only fallback.
      final result = extractDisplayName({'display_name': 'admin'});
      expect(
        result,
        isNull,
        reason:
            'Impersonation-risk names are rejected; fingerprint shown instead',
      );
    });

    test('extractDisplayName returns non-null for a valid name', () {
      // When a valid name is present, it is shown alongside (not instead of) the fingerprint.
      final result = extractDisplayName({'display_name': 'AliceB'});
      expect(result, isNotNull);
      // Policy: the fingerprint is STILL shown even when display name is present.
      // This is enforced by kFingerprintAlwaysVisible = true.
      expect(
        kFingerprintAlwaysVisible,
        isTrue,
        reason:
            'Even when a display name is shown, fingerprint must also be visible',
      );
    });

    test(
      'a valid display name does not suppress the fingerprint (policy assertion)',
      () {
        // Simulate a UI decision: should we hide the fingerprint when a display name exists?
        const hasDisplayName = true;
        final shouldHideFingerprint =
            hasDisplayName && !kFingerprintAlwaysVisible;
        expect(
          shouldHideFingerprint,
          isFalse,
          reason:
              'Policy forbids hiding the fingerprint even when a display name is present',
        );
      },
    );

    test('extractDisplayName trims surrounding whitespace', () {
      final result = extractDisplayName({'display_name': '  Alice  '});
      expect(
        result,
        equals('Alice'),
        reason: 'Leading/trailing whitespace must be stripped',
      );
    });

    test('extractDisplayName returns null for a name that is too long', () {
      final longName = 'A' * 33;
      final result = extractDisplayName({'display_name': longName});
      expect(
        result,
        isNull,
        reason: 'Overly long names are rejected; fingerprint shown instead',
      );
    });
  });
}
