// T-N-003 §9.1 — TURN credential is HMAC-bound to session; mismatched relay
// rejected.
//
// Proof: validateTurnSessionBinding() returns ok for correctly minted
// credentials and mismatchedSession/invalidHmac for stolen/transplanted ones.
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import '../../../lib/services/p2p/transport/turn_credentials.dart';
import '../../../lib/services/p2p/transport/turn_session_binding.dart';

void main() {
  final sharedKey = Uint8List(32)..fillRange(0, 32, 0x42);
  const baseUser = 'alice-session-abc123';

  TurnCredential _mint(String user, {DateTime? exp}) {
    return mintSessionBoundCredential(
      baseUser: user,
      sharedKey: sharedKey,
      expiresAt: exp ?? DateTime.now().add(const Duration(minutes: 5)),
    );
  }

  group('T-N-003 §9.1 — TURN cred HMAC-bound to session', () {
    test('correctly minted credential passes binding check', () {
      final cred = _mint(baseUser);
      final result = validateTurnSessionBinding(
        cred: cred,
        expectedBaseUser: baseUser,
        sharedKey: sharedKey,
      );
      expect(result, equals(TurnBindResult.ok));
    });

    test('credential minted for different session is rejected (mismatchedSession)', () {
      final cred = _mint('eve-session-xyz999');
      final result = validateTurnSessionBinding(
        cred: cred,
        expectedBaseUser: baseUser,
        sharedKey: sharedKey,
      );
      expect(result, equals(TurnBindResult.mismatchedSession));
    });

    test('credential with wrong HMAC (wrong key) is rejected (invalidHmac)', () {
      // Mint with the correct base-user but a different shared key.
      final wrongKey = Uint8List(32)..fillRange(0, 32, 0x00);
      final cred = mintSessionBoundCredential(
        baseUser: baseUser,
        sharedKey: wrongKey,
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
      );
      final result = validateTurnSessionBinding(
        cred: cred,
        expectedBaseUser: baseUser,
        sharedKey: sharedKey, // correct key — HMAC won't match
      );
      expect(result, equals(TurnBindResult.invalidHmac));
    });

    test('manually forged credential (no HMAC) is rejected', () {
      // Adversary fabricates a credential without knowing the shared key.
      final forgery = TurnCredential(
        username: '${DateTime.now().millisecondsSinceEpoch ~/ 1000}:$baseUser',
        credential: base64.encode(Uint8List(32)), // all-zero fake MAC
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
      );
      final result = validateTurnSessionBinding(
        cred: forgery,
        expectedBaseUser: baseUser,
        sharedKey: sharedKey,
      );
      expect(result, equals(TurnBindResult.invalidHmac));
    });

    test('malformed username (no colon) returns malformedUsername', () {
      final malformed = TurnCredential(
        username: 'notimestampbaseuser',
        credential: 'whatever',
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
      );
      final result = validateTurnSessionBinding(
        cred: malformed,
        expectedBaseUser: baseUser,
        sharedKey: sharedKey,
      );
      expect(result, equals(TurnBindResult.malformedUsername));
    });

    test('username with non-numeric timestamp returns malformedUsername', () {
      final malformed = TurnCredential(
        username: 'badts:$baseUser',
        credential: 'whatever',
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
      );
      final result = validateTurnSessionBinding(
        cred: malformed,
        expectedBaseUser: baseUser,
        sharedKey: sharedKey,
      );
      expect(result, equals(TurnBindResult.malformedUsername));
    });
  });
}
