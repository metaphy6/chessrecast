// §9.3 T-S-002 — Client validates end-to-end handshake signatures.
//
// The signaling server cannot forge a valid HELLO_CONFIRM because it does
// not have either peer's device private key.  This module provides the
// client-side validation logic.
//
// Handshake signing protocol (§2.2):
//   1. Alice sends HELLO with:
//        hello_payload = { session_id, mod_id, pub_key_alice }
//        sig_alice     = DeviceIdentity.sign("chessrecast:hello:v1" || hello_payload_cbor)
//   2. Bob receives HELLO, validates sig_alice, sends HELLO_CONFIRM with:
//        confirm_payload = { session_id, nonce_bob, pub_key_bob }
//        sig_bob         = DeviceIdentity.sign("chessrecast:confirm:v1" || confirm_payload_cbor || sig_alice)
//   3. Alice validates sig_bob; session starts only if both signatures pass.
library;

import 'dart:convert';
import 'dart:typed_data';

/// Domain separator for HELLO signing.
const String kHelloSigningDomain = 'chessrecast:hello:v1';

/// Domain separator for HELLO_CONFIRM signing (binds Bob's sig to Alice's).
const String kHelloConfirmSigningDomain = 'chessrecast:confirm:v1';

/// Build the message Alice signs in her HELLO.
///
/// [helloPayloadCbor] is the deterministic CBOR encoding of the hello map.
Uint8List buildHelloSigningInput(Uint8List helloPayloadCbor) {
  final prefix = utf8.encode(kHelloSigningDomain);
  final out = Uint8List(prefix.length + helloPayloadCbor.length);
  var offset = 0;
  out.setRange(offset, offset += prefix.length, prefix);
  out.setRange(offset, offset + helloPayloadCbor.length, helloPayloadCbor);
  return out;
}

/// Build the message Bob signs in his HELLO_CONFIRM.
///
/// [confirmPayloadCbor] is the deterministic CBOR encoding of the confirm map.
/// [helloSigAlice]      is Alice's 64-byte HELLO signature (binds Bob's
///                      confirm to the original HELLO exchange).
Uint8List buildConfirmSigningInput(
  Uint8List confirmPayloadCbor,
  Uint8List helloSigAlice,
) {
  assert(helloSigAlice.length == 64, 'HELLO sig must be 64 bytes');
  final prefix = utf8.encode(kHelloConfirmSigningDomain);
  final out = Uint8List(
    prefix.length + confirmPayloadCbor.length + helloSigAlice.length,
  );
  var offset = 0;
  out.setRange(offset, offset += prefix.length, prefix);
  out.setRange(
    offset,
    offset += confirmPayloadCbor.length,
    confirmPayloadCbor,
  );
  out.setRange(offset, offset + helloSigAlice.length, helloSigAlice);
  return out;
}

/// Validate Alice's HELLO signature.
///
/// Returns true iff [sigAlice] is a valid signature by [pubKeyAlice] over
/// the canonical hello signing input built from [helloPayloadCbor].
bool validateHelloSignature({
  required Uint8List helloPayloadCbor,
  required Uint8List pubKeyAlice,
  required Uint8List sigAlice,
  required bool Function(Uint8List pk, Uint8List msg, Uint8List sig) verifyFn,
}) {
  if (sigAlice.length != 64) return false;
  final message = buildHelloSigningInput(helloPayloadCbor);
  return verifyFn(pubKeyAlice, message, sigAlice);
}

/// Validate Bob's HELLO_CONFIRM signature.
///
/// Returns true iff [sigBob] is a valid signature by [pubKeyBob] over the
/// canonical confirm signing input (which includes [sigAlice]).
bool validateConfirmSignature({
  required Uint8List confirmPayloadCbor,
  required Uint8List sigAlice,
  required Uint8List pubKeyBob,
  required Uint8List sigBob,
  required bool Function(Uint8List pk, Uint8List msg, Uint8List sig) verifyFn,
}) {
  if (sigBob.length != 64) return false;
  final message = buildConfirmSigningInput(confirmPayloadCbor, sigAlice);
  return verifyFn(pubKeyBob, message, sigBob);
}
