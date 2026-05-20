// §9.1 T-N-002 — SDP offer/answer is signed under the long-term device key.
//
// The signing envelope is:
//   to_sign = domain_sep || session_id (32 bytes) || sdp_bytes
// where domain_sep = "chessrecast:offer:v1" encoded as UTF-8.
//
// Production code calls DeviceIdentity.sign(to_sign).
// Validators check the 64-byte signature with DeviceIdentity.verify().
library;

import 'dart:convert';
import 'dart:typed_data';

/// Domain separator for SDP offer/answer signing (prevents cross-protocol reuse
/// of device-key signatures).
const String kOfferSigningDomain = 'chessrecast:offer:v1';

/// Byte size of an Ed25519 signature (64 bytes per RFC 8032).
const int kSignatureBytes = 64;

/// Build the byte string that is fed to the signing key when signing an SDP
/// offer or answer.
///
/// [sessionId] must be exactly 32 bytes.
/// [sdpBytes]  is the raw UTF-8-encoded SDP body.
Uint8List buildOfferSigningInput({
  required Uint8List sessionId,
  required Uint8List sdpBytes,
}) {
  assert(sessionId.length == 32, 'sessionId must be 32 bytes');
  final prefix = utf8.encode(kOfferSigningDomain);
  final out = Uint8List(prefix.length + 32 + sdpBytes.length);
  var offset = 0;
  out.setRange(offset, offset += prefix.length, prefix);
  out.setRange(offset, offset += 32, sessionId);
  out.setRange(offset, offset + sdpBytes.length, sdpBytes);
  return out;
}

/// Validate that [signature] over [sdpBytes] is consistent with [sessionId].
///
/// This thin validator enforces that:
///   1. [signature] is exactly [kSignatureBytes] long.
///   2. The signature was computed over the canonical signing input.
///
/// It delegates the actual Ed25519 verify to the caller-supplied [verifyFn]
/// so that both libsodium (production) and the pure-Dart stub (tests) are
/// supported without creating a hard dependency here.
bool validateOfferSignature({
  required Uint8List sessionId,
  required Uint8List sdpBytes,
  required Uint8List publicKey,
  required Uint8List signature,
  required bool Function(Uint8List pk, Uint8List msg, Uint8List sig) verifyFn,
}) {
  if (signature.length != kSignatureBytes) return false;
  final message = buildOfferSigningInput(
    sessionId: sessionId,
    sdpBytes: sdpBytes,
  );
  return verifyFn(publicKey, message, signature);
}
