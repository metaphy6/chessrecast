// §6.7.2 Dart-side invite-link creation proof test.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/invites/invite_link_generator.dart';

void main() {
  const secret = [
    0x61, 0x62, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68,
    0x69, 0x6a, 0x6b, 0x6c, 0x6d, 0x6e, 0x6f, 0x70,
    0x71, 0x72, 0x73, 0x74, 0x75, 0x76, 0x77, 0x78,
    0x79, 0x7a, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36,
  ];

  final pubkey = Uint8List.fromList(List.generate(32, (i) => i));
  final gen = InviteLinkGenerator(hmacSecret: secret);

  group('InviteLinkGenerator §6.7.2', () {
    test('generates a non-empty token', () {
      final tok = gen.generate(pubkey: pubkey);
      expect(tok, isNotEmpty);
    });

    test('token has no base64 padding chars', () {
      final tok = gen.generate(pubkey: pubkey);
      expect(tok, isNot(contains('=')));
    });

    test('token is 112 base64url chars (84 raw bytes)', () {
      // 84 bytes → ceil(84*4/3) = 112 chars without padding
      final tok = gen.generate(pubkey: pubkey);
      expect(tok.length, equals(112));
    });

    test('two tokens for same key are different (random nonce)', () {
      final t1 = gen.generate(pubkey: pubkey);
      final t2 = gen.generate(pubkey: pubkey);
      expect(t1, isNot(equals(t2)));
    });

    test('extractPubkey round-trips the pubkey', () {
      final tok = gen.generate(pubkey: pubkey);
      final extracted = gen.extractPubkey(tok);
      expect(extracted, equals(pubkey));
    });

    test('rejects pubkey that is not 32 bytes', () {
      expect(
        () => gen.generate(pubkey: Uint8List(16)),
        throwsArgumentError,
      );
    });

    test('extractPubkey throws FormatException for invalid token', () {
      expect(
        () => gen.extractPubkey('not-valid-at-all'),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
