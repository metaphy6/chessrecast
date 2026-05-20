// §9.2 T-P-005 — HELLO includes signed mod id; mod mismatch → session abort.
//
// Both peers must agree on the same mod before play begins.  The mod_id is
// included in the HELLO payload that is signed by the sender's device key,
// so a MITM cannot silently swap the mod without invalidating the signature.
//
// This module provides the mod-id inclusion rule and mismatch detection.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Known mod identifiers (must match the `modId` enum in engine.dart).
const Set<String> kValidModIds = {
  'heir',
  'friendly_fire',
  'kings_battle',
  'mercenary',
  'save_the_queen',
  'succession',
  'truce',
};

/// Thrown when the remote peer's HELLO carries an unexpected mod id.
class ModMismatchError implements Exception {
  final String localModId;
  final String remoteModId;
  const ModMismatchError(this.localModId, this.remoteModId);

  @override
  String toString() =>
      'ModMismatchError: local=$localModId remote=$remoteModId';
}

/// Build the bytes that are signed when including mod_id in a HELLO.
///
/// Includes a domain separator to prevent cross-protocol collisions.
/// [modId] must be one of [kValidModIds].
/// [sessionId] must be exactly 32 bytes.
Uint8List buildHelloModPayload({
  required String modId,
  required Uint8List sessionId,
}) {
  assert(kValidModIds.contains(modId), 'modId must be a known mod: $modId');
  assert(sessionId.length == 32, 'sessionId must be 32 bytes');
  const domain = 'chessrecast:hello:mod:v1';
  final domainBytes = utf8.encode(domain);
  final modBytes = utf8.encode(modId);
  final out = Uint8List(domainBytes.length + 32 + modBytes.length);
  var offset = 0;
  out.setRange(offset, offset += domainBytes.length, domainBytes);
  out.setRange(offset, offset += 32, sessionId);
  out.setRange(offset, offset + modBytes.length, modBytes);
  return out;
}

/// Validate the mod_id claim in a remote HELLO message.
///
/// Throws [ModMismatchError] if [remoteModId] ≠ [localModId].
/// Returns true if the mod_id matches AND the signature is valid.
bool validateHelloModId({
  required String localModId,
  required String remoteModId,
  required Uint8List remoteSessionId,
  required Uint8List remotePubKey,
  required Uint8List remoteModSig,
  required bool Function(Uint8List pk, Uint8List msg, Uint8List sig) verifyFn,
}) {
  if (remoteModId != localModId) {
    throw ModMismatchError(localModId, remoteModId);
  }
  final payload = buildHelloModPayload(
    modId: remoteModId,
    sessionId: remoteSessionId,
  );
  return verifyFn(remotePubKey, payload, remoteModSig);
}

/// Sign the mod_id payload using a stub HMAC signer.
///
/// Production code uses DeviceIdentity.sign(); this helper is for tests.
Uint8List signHelloModPayload({
  required String modId,
  required Uint8List sessionId,
  required Uint8List signingKey,
}) {
  final payload = buildHelloModPayload(modId: modId, sessionId: sessionId);
  final hmac = Hmac(sha256, signingKey);
  final h = hmac.convert(payload).bytes;
  return Uint8List(64)..setRange(0, h.length, h);
}
