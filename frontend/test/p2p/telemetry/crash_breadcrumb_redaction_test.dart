import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/identity/identity.dart';

/// Crash breadcrumb redaction tests (§2.7.bullet-4).
///
/// Verifies that [CrashBreadcrumbFilter.shouldRedact] correctly identifies
/// stack frames that must be withheld from Sentry / Crashlytics.
void main() {
  group('Crash breadcrumb redaction (§2.7)', () {
    test('libsodium symbols are redacted', () {
      expect(
        CrashBreadcrumbFilter.shouldRedact('sodium_memzero at 0x7f42'),
        isTrue,
      );
      expect(
        CrashBreadcrumbFilter.shouldRedact('crypto_box_easy wrapper line 24'),
        isTrue,
      );
    });

    test('identity service symbols are redacted', () {
      expect(
        CrashBreadcrumbFilter.shouldRedact(
          '#12 DeviceIdentity.sign (identity.dart:102)',
        ),
        isTrue,
      );
      expect(
        CrashBreadcrumbFilter.shouldRedact(
          'SessionKdf.sharedSecret (identity.dart:555)',
        ),
        isTrue,
      );
      expect(
        CrashBreadcrumbFilter.shouldRedact(
          'AeadCipher.encrypt (identity.dart:701)',
        ),
        isTrue,
      );
      expect(
        CrashBreadcrumbFilter.shouldRedact(
          'Argon2idStub.derive (identity.dart:408)',
        ),
        isTrue,
      );
      expect(
        CrashBreadcrumbFilter.shouldRedact(
          'WrappedBlob.unwrap (identity.dart:503)',
        ),
        isTrue,
      );
      expect(
        CrashBreadcrumbFilter.shouldRedact(
          'RecoveryCode.deriveKek (identity.dart:310)',
        ),
        isTrue,
      );
      expect(
        CrashBreadcrumbFilter.shouldRedact(
          'KciAuthenticator.generateMac (identity.dart:867)',
        ),
        isTrue,
      );
    });

    test('non-secret frames are NOT redacted', () {
      expect(
        CrashBreadcrumbFilter.shouldRedact('ChessBoard.render (board.dart:42)'),
        isFalse,
      );
      expect(
        CrashBreadcrumbFilter.shouldRedact('GameRoute.build (routes.dart:10)'),
        isFalse,
      );
      expect(CrashBreadcrumbFilter.shouldRedact('main (main.dart:1)'), isFalse);
    });

    test('empty string is not redacted', () {
      expect(CrashBreadcrumbFilter.shouldRedact(''), isFalse);
    });

    test(
      'partial-match is case-sensitive (only exact prefix substrings match)',
      () {
        // 'SODIUM_' (upper case) should not match 'sodium_' prefix pattern
        // since Dart contains() is case-sensitive by default
        expect(
          CrashBreadcrumbFilter.shouldRedact('SODIUM_MEMZERO'),
          isFalse,
          reason:
              'Redaction is case-sensitive; only lower-case libsodium symbols match',
        );
      },
    );
  });
}
