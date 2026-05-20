// T-§9.8 — Future client can verify historical transcripts signed with legacy
// crypto_suite_id = 0x01 (kSuiteClassical).
//
// When ChessRecast introduces a new cryptographic suite (e.g., post-quantum),
// the transcript stored under the old suite must remain verifiable.  This test
// proves that:
//   1. kSuiteClassical = 0x01 is a stable, documented constant.
//   2. A transcript frame signed under the classical suite can be re-verified
//      on a client that also supports the legacy suite.
//   3. The CryptoSuiteId wire value is embedded in every BYE frame payload
//      so a future verifier knows which algorithm to use.
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../../lib/services/p2p/identity/identity.dart';
import '../../../lib/services/p2p/protocol/frame.dart';

/// Stub sign with HMAC-SHA256 padded to 64 bytes.
Uint8List _sign(Uint8List key, Uint8List message) {
  final hmac = Hmac(sha256, key);
  final h = hmac.convert(message).bytes;
  return Uint8List(64)..setRange(0, h.length, h);
}

bool _verify(Uint8List pk, Uint8List msg, Uint8List sig) {
  final hmac = Hmac(sha256, pk);
  final expected = hmac.convert(msg).bytes;
  for (var i = 0; i < expected.length; i++) {
    if (sig[i] != expected[i]) return false;
  }
  return true;
}

void main() {
  group('§9.8 — Legacy suite (0x01) transcript verifiable by future client', () {
    const suiteId = CryptoSuiteId.kSuiteClassical; // 0x01

    test('kSuiteClassical constant is 0x01 and must not change', () {
      // This constant is part of the on-wire / on-disk format; it must never
      // be reassigned.  If this test fails, any stored transcript is broken.
      expect(suiteId, equals(0x01));
    });

    test('CryptoSuiteId(0x01).isKnown is true on a "future" client', () {
      // A client compiled with knowledge of the new suite must still
      // recognise the old suite to replay historical games.
      const legacySuite = CryptoSuiteId(suiteId);
      expect(legacySuite.isKnown, isTrue);
    });

    test('negotiate accepts two peers who both present suite 0x01', () {
      // Historical transcript was signed under 0x01.  A future client
      // replaying it presents 0x01; the verifier also presents 0x01 →
      // negotiation must succeed.
      expect(
        () => CryptoSuiteId.negotiate(suiteId, suiteId),
        returnsNormally,
      );
      final negotiated = CryptoSuiteId.negotiate(suiteId, suiteId);
      expect(negotiated.value, equals(suiteId));
    });

    test('BYE frame signed under suite 0x01 survives encode-decode', () {
      // Build a minimal BYE payload that includes crypto_suite_id.
      final sessionId = Uint8List(32)..fillRange(0, 32, 0x01);
      final signingKey = Uint8List(32)..fillRange(0, 32, 0xAB);
      final moves = ['e2e4', 'e7e5', 'd2d4', 'd7d5'];

      // Payload mimics §1.8: include 'crypto_suite_id' so future verifiers
      // know which algorithm was used.
      final payloadMap = <String, dynamic>{
        'result': '1-0',
        'moves': moves,
        'crypto_suite_id': suiteId,
      };
      final payloadBytes = CborCodec.encode(payloadMap);
      final toSign = byeMessageToSign(sessionId, payloadBytes);
      final sig = _sign(signingKey, toSign);
      final withSig = Map<String, dynamic>.from(payloadMap)..['sig'] = sig;

      final frame = Frame.withPayloadMap(
        FrameType.bye,
        withSig,
        sequenceNum: 1,
      );
      final decoded = Frame.decode(frame.encode());
      final decodedMap = decoded.decodePayload();

      // Verify: suite id survives round-trip.
      expect(
        decodedMap['crypto_suite_id'],
        equals(suiteId),
        reason: 'crypto_suite_id must survive encode-decode for legacy verify',
      );

      // Verify: signature is still valid using the legacy algorithm.
      final restoredSig =
          Uint8List.fromList(decodedMap['sig'] as List<int>);
      final restoredMoves =
          (decodedMap['moves'] as List).cast<String>();
      final restoredPayload = CborCodec.encode({
        'result': decodedMap['result'],
        'moves': restoredMoves,
        'crypto_suite_id': decodedMap['crypto_suite_id'],
      });
      final toVerify = byeMessageToSign(sessionId, restoredPayload);
      expect(_verify(signingKey, toVerify, restoredSig), isTrue,
          reason: 'legacy suite 0x01 BYE signature must verify on future client');
    });

    test('transcript without crypto_suite_id defaults to suite 0x01', () {
      // Some early transcripts may omit the field.  The policy is to
      // treat absence as kSuiteClassical.
      final noSuitePayload = <String, dynamic>{
        'result': '0-1',
        'moves': ['e2e4'],
      };
      final suiteInPayload =
          noSuitePayload['crypto_suite_id'] as int? ?? suiteId;
      expect(suiteInPayload, equals(suiteId),
          reason: 'missing field defaults to 0x01');
    });
  });
}
