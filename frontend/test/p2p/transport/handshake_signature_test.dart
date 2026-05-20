// T-S-002 §9.3 — Client validates handshake signatures end-to-end.
//
// Proof: validateHelloSignature() and validateConfirmSignature() enforce that
// both HELLO and HELLO_CONFIRM are signed by the respective device key, and
// that Bob's confirm binds to Alice's original HELLO signature.
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../../lib/services/p2p/transport/handshake_signatures.dart';

/// Stub Ed25519: HMAC-SHA256(pk, msg) padded to 64 bytes.
Uint8List _stubSign(Uint8List pk, Uint8List msg) {
  final hmac = Hmac(sha256, pk);
  final h = hmac.convert(msg).bytes;
  return Uint8List(64)..setRange(0, h.length, h);
}

bool _stubVerify(Uint8List pk, Uint8List msg, Uint8List sig) {
  final hmac = Hmac(sha256, pk);
  final expected = hmac.convert(msg).bytes;
  for (var i = 0; i < expected.length; i++) {
    if (sig[i] != expected[i]) return false;
  }
  return true;
}

void main() {
  // Simulate Alice and Bob each having a distinct device key.
  final pubKeyAlice = Uint8List(32)..fillRange(0, 32, 0xAA);
  final pubKeyBob = Uint8List(32)..fillRange(0, 32, 0xBB);
  // CBOR payloads (deterministic bytes — content doesn't matter here).
  final helloPayload = Uint8List.fromList([0xa1, 0x01, 0x02]); // tiny stub
  final confirmPayload = Uint8List.fromList([0xa1, 0x03, 0x04]);

  group('T-S-002 §9.3 — End-to-end handshake signature validation', () {
    late Uint8List sigAlice;

    setUp(() {
      final helloMsg = buildHelloSigningInput(helloPayload);
      sigAlice = _stubSign(pubKeyAlice, helloMsg);
    });

    // --- HELLO validation ---
    test('HELLO signing input includes domain separator', () {
      final input = buildHelloSigningInput(helloPayload);
      const dom = kHelloSigningDomain;
      for (var i = 0; i < dom.length; i++) {
        expect(input[i], equals(dom.codeUnitAt(i)));
      }
    });

    test('valid HELLO signature passes validateHelloSignature', () {
      expect(
        validateHelloSignature(
          helloPayloadCbor: helloPayload,
          pubKeyAlice: pubKeyAlice,
          sigAlice: sigAlice,
          verifyFn: _stubVerify,
        ),
        isTrue,
      );
    });

    test('HELLO sig with wrong key fails', () {
      final wrongKey = Uint8List(32)..fillRange(0, 32, 0xFF);
      expect(
        validateHelloSignature(
          helloPayloadCbor: helloPayload,
          pubKeyAlice: wrongKey,
          sigAlice: sigAlice,
          verifyFn: _stubVerify,
        ),
        isFalse,
      );
    });

    // --- HELLO_CONFIRM validation ---
    test('valid HELLO_CONFIRM passes validateConfirmSignature', () {
      final confirmMsg = buildConfirmSigningInput(confirmPayload, sigAlice);
      final sigBob = _stubSign(pubKeyBob, confirmMsg);

      expect(
        validateConfirmSignature(
          confirmPayloadCbor: confirmPayload,
          sigAlice: sigAlice,
          pubKeyBob: pubKeyBob,
          sigBob: sigBob,
          verifyFn: _stubVerify,
        ),
        isTrue,
      );
    });

    test('HELLO_CONFIRM with swapped sigAlice (replay) fails', () {
      final confirmMsg = buildConfirmSigningInput(confirmPayload, sigAlice);
      final sigBob = _stubSign(pubKeyBob, confirmMsg);

      // Attacker replaces sigAlice with an all-zero blob.
      final fakeSigAlice = Uint8List(64);
      expect(
        validateConfirmSignature(
          confirmPayloadCbor: confirmPayload,
          sigAlice: fakeSigAlice, // different from what Bob signed over
          pubKeyBob: pubKeyBob,
          sigBob: sigBob,
          verifyFn: _stubVerify,
        ),
        isFalse,
        reason: 'confirm must bind to the specific HELLO sig Alice sent',
      );
    });

    test('HELLO_CONFIRM with wrong Bob key fails', () {
      final confirmMsg = buildConfirmSigningInput(confirmPayload, sigAlice);
      final sigBob = _stubSign(pubKeyBob, confirmMsg);
      final eveKey = Uint8List(32)..fillRange(0, 32, 0xEE);

      expect(
        validateConfirmSignature(
          confirmPayloadCbor: confirmPayload,
          sigAlice: sigAlice,
          pubKeyBob: eveKey,
          sigBob: sigBob,
          verifyFn: _stubVerify,
        ),
        isFalse,
      );
    });

    test('short signatures (< 64 bytes) are immediately rejected', () {
      expect(
        validateHelloSignature(
          helloPayloadCbor: helloPayload,
          pubKeyAlice: pubKeyAlice,
          sigAlice: Uint8List(32),
          verifyFn: _stubVerify,
        ),
        isFalse,
      );
      expect(
        validateConfirmSignature(
          confirmPayloadCbor: confirmPayload,
          sigAlice: sigAlice,
          pubKeyBob: pubKeyBob,
          sigBob: Uint8List(32),
          verifyFn: _stubVerify,
        ),
        isFalse,
      );
    });
  });
}
