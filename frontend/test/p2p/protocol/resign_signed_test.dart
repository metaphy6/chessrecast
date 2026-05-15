import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:crypto/crypto.dart';
import '../../../lib/services/p2p/protocol/frame.dart';

// HMAC-SHA256 used as a Phase 1 signing stub (Phase 2 replaces with Ed25519).
Uint8List _hmacSign(Uint8List key, Uint8List message) {
  final hmac = Hmac(sha256, key);
  return Uint8List.fromList(hmac.convert(message).bytes);
}

void main() {
  group('RESIGN signed frame (§1.7)', () {
    final sessionId = Uint8List(32)..fillRange(0, 32, 0x01);
    final signingKey = Uint8List(32)..fillRange(0, 32, 0xAB);

    test('RESIGN payload contains a 64-byte sig field', () {
      // Build the payload-without-sig
      final payloadWithoutSig = <String, dynamic>{'reason': 'resign'};
      final payloadCbor = CborCodec.encode(payloadWithoutSig);

      // Compute the message to sign
      final toSign = resignMessageToSign(sessionId, payloadCbor);
      expect(toSign.length, 32); // SHA-256 output

      // Stub signature: HMAC-SHA256 (32 bytes), padded to 64 to match Ed25519 shape
      final hmac = _hmacSign(signingKey, toSign);
      final sig64 = Uint8List(64);
      sig64.setRange(0, hmac.length, hmac);

      final payload = buildResignPayload(sig64);
      expect((payload['sig'] as Uint8List).length, 64);
    });

    test('RESIGN frame survives CBOR round-trip with 64-byte sig', () {
      final payloadWithoutSig = <String, dynamic>{'reason': 'resign'};
      final payloadCbor = CborCodec.encode(payloadWithoutSig);
      final toSign = resignMessageToSign(sessionId, payloadCbor);
      final hmac = _hmacSign(signingKey, toSign);
      final sig64 = Uint8List(64)..setRange(0, hmac.length, hmac);

      final fullPayload = {'reason': 'resign', 'sig': sig64};

      final frame = Frame.withPayloadMap(
        FrameType.resign,
        fullPayload,
        sequenceNum: 1,
      );

      final encoded = frame.encode();
      final decoded = Frame.decode(encoded);
      expect(decoded.type, FrameType.resign);

      final dp = decoded.decodePayload();
      final recoveredSig = dp['sig'] as Uint8List;
      expect(recoveredSig.length, 64);
    });

    test('signing different session IDs produces different messages', () {
      final sid1 = Uint8List(32)..fillRange(0, 32, 0x01);
      final sid2 = Uint8List(32)..fillRange(0, 32, 0x02);
      final payload = CborCodec.encode({'reason': 'resign'});

      final m1 = resignMessageToSign(sid1, payload);
      final m2 = resignMessageToSign(sid2, payload);

      int diff = 0;
      for (int i = 0; i < 32; i++) diff |= m1[i] ^ m2[i];
      expect(diff, isNot(0));
    });

    test('tampering payload changes the message to sign', () {
      final payload1 = CborCodec.encode({'reason': 'resign'});
      final payload2 = CborCodec.encode({'reason': 'resign_tampered'});

      final m1 = resignMessageToSign(sessionId, payload1);
      final m2 = resignMessageToSign(sessionId, payload2);

      int diff = 0;
      for (int i = 0; i < 32; i++) diff |= m1[i] ^ m2[i];
      expect(diff, isNot(0));
    });
  });
}
