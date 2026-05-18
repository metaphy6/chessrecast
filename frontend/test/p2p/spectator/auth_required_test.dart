// §7.8.3 auth required proof test (Dart side).
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/spectator/spectator_auth.dart';

void main() {
  group('SpectatorAuthPolicy §7.8.3', () {
    test('anonymous request (null devicePubKey) returns SPECTATOR_AUTH_REQUIRED', () {
      final policy = SpectatorAuthPolicy();
      final req = SpectatorAuthRequest(devicePubKey: null);
      expect(policy.validate(req), equals('SPECTATOR_AUTH_REQUIRED'));
    });

    test('authenticated request (valid 32-byte pubkey) is accepted', () {
      final policy = SpectatorAuthPolicy();
      final req = SpectatorAuthRequest(
        devicePubKey: Uint8List.fromList(List.generate(32, (i) => i + 1)),
      );
      expect(policy.validate(req), isNull);
    });

    test('short pubkey (< 32 bytes) is rejected', () {
      final policy = SpectatorAuthPolicy();
      final req = SpectatorAuthRequest(
        devicePubKey: Uint8List.fromList([1, 2, 3]),
      );
      expect(policy.validate(req), equals('SPECTATOR_AUTH_REQUIRED'));
    });
  });

  group('SpectatorJoinRateLimit §7.8.4', () {
    test('allows up to 6 joins per minute', () {
      final rl = SpectatorJoinRateLimit();
      const account = 'acc_rl_test';
      for (var i = 0; i < SpectatorJoinRateLimit.maxPerMinute; i++) {
        expect(rl.attempt(account, 0), isNull, reason: 'join \$i should pass');
      }
    });

    test('7th join in one minute returns SPECTATOR_JOIN_RATE_LIMITED', () {
      final rl = SpectatorJoinRateLimit();
      const account = 'acc_heavy';
      for (var i = 0; i < SpectatorJoinRateLimit.maxPerMinute; i++) {
        rl.attempt(account, 0);
      }
      expect(rl.attempt(account, 0), equals('SPECTATOR_JOIN_RATE_LIMITED'));
    });
  });
}
