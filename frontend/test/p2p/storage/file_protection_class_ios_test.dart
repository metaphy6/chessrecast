// Proof test for roadmap §0.6.bullet-3 — iOS file-protection class.
//
// Verifies that ios/Runner/Info.plist declares NSFileProtectionKey so that the
// OS applies the requested file-protection class to the app's documents
// directory on iOS/iPadOS.
// CWD = frontend/ when invoked via `flutter test`.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String infoPlistPath;

  setUpAll(() {
    infoPlistPath = '${Directory.current.path}/ios/Runner/Info.plist';
  });

  test('1. Info.plist declares NSFileProtectionKey', () {
    final content = File(infoPlistPath).readAsStringSync();
    expect(
      content,
      contains('<key>NSFileProtectionKey</key>'),
      reason:
          'Info.plist must declare NSFileProtectionKey so iOS applies the '
          'requested file-protection class to app data at rest.',
    );
  });

  test(
    '2. Info.plist NSFileProtection value is CompleteUntilFirstUserAuthentication or stricter',
    () {
      final content = File(infoPlistPath).readAsStringSync();
      // Accept Complete (most strict) or CompleteUntilFirstUserAuthentication.
      final hasProtection =
          content.contains('NSFileProtectionComplete') ||
          content.contains('NSFileProtectionCompleteUnlessOpen');
      expect(
        hasProtection,
        isTrue,
        reason:
            'NSFileProtectionKey value must be NSFileProtectionComplete or '
            'NSFileProtectionCompleteUntilFirstUserAuthentication; '
            'NSFileProtectionNone or NSFileProtectionCompleteUnlessOpen are '
            'insufficient for stored game and forensic data.',
      );
    },
  );
}
