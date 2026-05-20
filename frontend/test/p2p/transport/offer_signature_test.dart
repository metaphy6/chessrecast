// T-N-002 §9.1 — SDP offer/answer is signed under the long-term device key.
//
// Proof: buildOfferSigningInput() binds the session ID and SDP body to the
// domain separator; validateOfferSignature() rejects tampered SDPs.
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../../lib/services/p2p/transport/offer_signature.dart';

/// Stub Ed25519 verify: HMAC-SHA256(pk, msg)[0..31] must match sig[0..31].
bool _stubVerify(Uint8List pk, Uint8List msg, Uint8List sig) {
  final hmac = Hmac(sha256, pk);
  final expected = hmac.convert(msg).bytes;
  for (var i = 0; i < expected.length; i++) {
    if (sig[i] != expected[i]) return false;
  }
  return true;
}

/// Stub Ed25519 sign: HMAC-SHA256(pk, msg) padded to 64 bytes.
Uint8List _stubSign(Uint8List pk, Uint8List msg) {
  final hmac = Hmac(sha256, pk);
  final h = hmac.convert(msg).bytes;
  return Uint8List(64)..setRange(0, h.length, h);
}

void main() {
  final sessionId = Uint8List(32)..fillRange(0, 32, 0xAB);
  final sdp = utf8.encode('v=0\r\nm=application 9 UDP/DTLS/SCTP webrtc-datachannel\r\n');
  final pubKey = Uint8List(32)..fillRange(0, 32, 0x7F);

  group('T-N-002 §9.1 — SDP offer signed under device key', () {
    test('signing input includes domain separator', () {
      final input = buildOfferSigningInput(
        sessionId: sessionId,
        sdpBytes: Uint8List.fromList(sdp),
      );
      const domainSep = kOfferSigningDomain;
      final sepBytes = utf8.encode(domainSep);
      for (var i = 0; i < sepBytes.length; i++) {
        expect(input[i], equals(sepBytes[i]),
            reason: 'domain separator byte $i mismatch');
      }
    });

    test('signing input embeds session ID at correct offset', () {
      final input = buildOfferSigningInput(
        sessionId: sessionId,
        sdpBytes: Uint8List.fromList(sdp),
      );
      final sepLen = utf8.encode(kOfferSigningDomain).length;
      for (var i = 0; i < 32; i++) {
        expect(input[sepLen + i], equals(sessionId[i]),
            reason: 'session ID byte $i mismatch');
      }
    });

    test('valid signature passes validateOfferSignature', () {
      final sdpBytes = Uint8List.fromList(sdp);
      final message = buildOfferSigningInput(
        sessionId: sessionId,
        sdpBytes: sdpBytes,
      );
      final sig = _stubSign(pubKey, message);

      expect(
        validateOfferSignature(
          sessionId: sessionId,
          sdpBytes: sdpBytes,
          publicKey: pubKey,
          signature: sig,
          verifyFn: _stubVerify,
        ),
        isTrue,
      );
    });

    test('signature over different session ID is rejected', () {
      final sdpBytes = Uint8List.fromList(sdp);
      final correctInput = buildOfferSigningInput(
        sessionId: sessionId,
        sdpBytes: sdpBytes,
      );
      final sig = _stubSign(pubKey, correctInput);

      // Use a different session ID → signing input changes → verify fails.
      final wrongSession = Uint8List(32)..fillRange(0, 32, 0x00);
      expect(
        validateOfferSignature(
          sessionId: wrongSession,
          sdpBytes: sdpBytes,
          publicKey: pubKey,
          signature: sig,
          verifyFn: _stubVerify,
        ),
        isFalse,
        reason: 'wrong session ID must be rejected',
      );
    });

    test('tampered SDP body is rejected', () {
      final sdpBytes = Uint8List.fromList(sdp);
      final message = buildOfferSigningInput(
        sessionId: sessionId,
        sdpBytes: sdpBytes,
      );
      final sig = _stubSign(pubKey, message);

      // Change one byte in the SDP.
      final tamperedSdp = Uint8List.fromList(sdpBytes);
      tamperedSdp[0] ^= 0xFF;

      expect(
        validateOfferSignature(
          sessionId: sessionId,
          sdpBytes: tamperedSdp,
          publicKey: pubKey,
          signature: sig,
          verifyFn: _stubVerify,
        ),
        isFalse,
        reason: 'tampered SDP must be rejected',
      );
    });

    test('wrong-length signature is always rejected', () {
      final sdpBytes = Uint8List.fromList(sdp);
      final shortSig = Uint8List(32); // only 32 bytes, not 64

      expect(
        validateOfferSignature(
          sessionId: sessionId,
          sdpBytes: sdpBytes,
          publicKey: pubKey,
          signature: shortSig,
          verifyFn: _stubVerify,
        ),
        isFalse,
        reason: 'signature shorter than 64 bytes must be rejected',
      );
    });
  });
}
