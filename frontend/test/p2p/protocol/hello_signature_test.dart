import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:crypto/crypto.dart';
import '../../../lib/services/p2p/protocol/frame.dart';

// HMAC-SHA256 stub for Phase 1 tests (Phase 2 replaces with Ed25519).
Uint8List _hmacSign(Uint8List key, Uint8List message) {
  final hmac = Hmac(sha256, key);
  return Uint8List.fromList(hmac.convert(message).bytes);
}

/// Builds a HELLO payload with an HMAC-SHA256 signature over the payload CBOR
/// (excluding the sig field itself).
Map<String, dynamic> _buildSignedHello({
  required Uint8List ephPub,
  required Uint8List nonce,
  required Uint8List signingKey,
  int mod = 0,
  int skill = 1,
}) {
  // Build payload without sig first
  final payloadWithoutSig = <String, dynamic>{
    'eph_pub': ephPub,
    'mod': mod,
    'nonce': nonce,
    'skill': skill,
    'version': '1.0.0',
  };
  final encoded = CborCodec.encode(payloadWithoutSig);
  final sig = _hmacSign(signingKey, encoded);
  // sig must be 32 bytes (HMAC-SHA256) — padded to 64 to match Ed25519 shape
  final sig64 = Uint8List(64);
  sig64.setRange(0, sig.length, sig);
  return {
    ...payloadWithoutSig,
    'sig': sig64,
  };
}

void main() {
  group('HELLO signature verification (§1.1 — §3 HELLO, Phase 1 HMAC stub)', () {
    final ephPub = Uint8List(32)..fillRange(0, 32, 0x01);
    final nonce = Uint8List(32)..fillRange(0, 32, 0x02);
    final signingKey = Uint8List(32)..fillRange(0, 32, 0xAB);

    test('original HELLO frame signature is valid (HMAC-SHA256 stub)', () {
      final payload =
          _buildSignedHello(ephPub: ephPub, nonce: nonce, signingKey: signingKey);

      // Verify sig over payload-without-sig
      final payloadWithoutSig = Map<String, dynamic>.from(payload)
        ..remove('sig');
      final encoded = CborCodec.encode(payloadWithoutSig);
      final expectedSig = _hmacSign(signingKey, encoded);
      final sig = payload['sig'] as Uint8List;

      // Compare first 32 bytes (HMAC-SHA256 output length)
      int diff = 0;
      for (int i = 0; i < 32; i++) {
        diff |= sig[i] ^ expectedSig[i];
      }
      expect(diff, 0);
    });

    test('tampering eph_pub invalidates the signature', () {
      final payload =
          _buildSignedHello(ephPub: ephPub, nonce: nonce, signingKey: signingKey);
      final tampered = Map<String, dynamic>.from(payload);
      // Corrupt eph_pub
      final tamperedPub = Uint8List.fromList(ephPub);
      tamperedPub[0] = 0xFF;
      tampered['eph_pub'] = tamperedPub;

      final payloadWithoutSig = Map<String, dynamic>.from(tampered)
        ..remove('sig');
      final encoded = CborCodec.encode(payloadWithoutSig);
      final actualSig = _hmacSign(signingKey, encoded);
      final claimedSig = payload['sig'] as Uint8List;

      int diff = 0;
      for (int i = 0; i < 32; i++) {
        diff |= claimedSig[i] ^ actualSig[i];
      }
      expect(diff, isNot(0));
    });

    test('tampering nonce invalidates the signature', () {
      final payload =
          _buildSignedHello(ephPub: ephPub, nonce: nonce, signingKey: signingKey);
      final tampered = Map<String, dynamic>.from(payload);
      final tamperedNonce = Uint8List.fromList(nonce);
      tamperedNonce[15] = 0xFF;
      tampered['nonce'] = tamperedNonce;

      final payloadWithoutSig = Map<String, dynamic>.from(tampered)
        ..remove('sig');
      final encoded = CborCodec.encode(payloadWithoutSig);
      final actualSig = _hmacSign(signingKey, encoded);
      final claimedSig = payload['sig'] as Uint8List;

      int diff = 0;
      for (int i = 0; i < 32; i++) {
        diff |= claimedSig[i] ^ actualSig[i];
      }
      expect(diff, isNot(0));
    });

    test('tampering the sig field itself is detected', () {
      final payload =
          _buildSignedHello(ephPub: ephPub, nonce: nonce, signingKey: signingKey);
      final badSig = Uint8List(64)..fillRange(0, 64, 0xDE);

      final payloadWithoutSig = Map<String, dynamic>.from(payload)
        ..remove('sig');
      final encoded = CborCodec.encode(payloadWithoutSig);
      final expectedSig = _hmacSign(signingKey, encoded);

      int diff = 0;
      for (int i = 0; i < 32; i++) {
        diff |= badSig[i] ^ expectedSig[i];
      }
      expect(diff, isNot(0));
    });

    test('wrong signing key invalidates the signature', () {
      final payload =
          _buildSignedHello(ephPub: ephPub, nonce: nonce, signingKey: signingKey);
      final wrongKey = Uint8List(32)..fillRange(0, 32, 0xCC);

      final payloadWithoutSig = Map<String, dynamic>.from(payload)
        ..remove('sig');
      final encoded = CborCodec.encode(payloadWithoutSig);
      final actualSig = _hmacSign(wrongKey, encoded);
      final claimedSig = payload['sig'] as Uint8List;

      int diff = 0;
      for (int i = 0; i < 32; i++) {
        diff |= claimedSig[i] ^ actualSig[i];
      }
      expect(diff, isNot(0));
    });
  });
}
