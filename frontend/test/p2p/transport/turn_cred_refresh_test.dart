// Proof test for §4.1 TURN credential refresh (Dart client side).
//
// Verifies that TurnCredentialService:
// - Holds a TTL property matching the server-side 5-minute window
// - Marks credentials as near-expired within the refresh buffer
// - After expiry the isExpired flag is set
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/transport/turn_credentials.dart';

void main() {
  group('TurnCredentialService §4.1 short-lived creds', () {
    test('serverTtl constant is 5 minutes', () {
      expect(TurnCredentialService.serverTtl,
          equals(const Duration(minutes: 5)));
    });

    test('freshly constructed credential is not expired', () {
      final expiry = DateTime.now().add(const Duration(minutes: 5));
      final cred = TurnCredential(
        username: '${expiry.millisecondsSinceEpoch ~/ 1000}:testuser',
        credential: 'base64password',
        expiresAt: expiry,
      );
      expect(cred.isExpired, isFalse);
    });

    test('credential past expiresAt is reported as expired', () {
      final past = DateTime.now().subtract(const Duration(seconds: 1));
      final cred = TurnCredential(
        username: '1:testuser',
        credential: 'pw',
        expiresAt: past,
      );
      expect(cred.isExpired, isTrue);
    });

    test('credential within refresh buffer is reported as nearExpired', () {
      // Refresh buffer is 60 s before expiry.
      final expiry =
          DateTime.now().add(const Duration(seconds: 30)); // < buffer
      final cred = TurnCredential(
        username: '${expiry.millisecondsSinceEpoch ~/ 1000}:user',
        credential: 'pw',
        expiresAt: expiry,
      );
      expect(cred.nearExpired, isTrue);
    });

    test('credential not within refresh buffer is not nearExpired', () {
      final expiry =
          DateTime.now().add(const Duration(minutes: 4)); // well within TTL
      final cred = TurnCredential(
        username: '${expiry.millisecondsSinceEpoch ~/ 1000}:user',
        credential: 'pw',
        expiresAt: expiry,
      );
      expect(cred.nearExpired, isFalse);
    });

    test('TurnCredentialService.fromServerResponse parses fields', () {
      final now = DateTime.now();
      final expiry = now.add(const Duration(minutes: 5));
      final cred = TurnCredential.fromServerResponse({
        'username': '${expiry.millisecondsSinceEpoch ~/ 1000}:alice',
        'credential': 'abc123',
        'ttl': 300,
      });
      expect(cred.username, contains(':alice'));
      expect(cred.credential, equals('abc123'));
      expect(cred.isExpired, isFalse);
    });
  });
}
