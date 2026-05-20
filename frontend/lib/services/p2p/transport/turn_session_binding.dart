// §9.1 T-N-003 — TURN credential is HMAC-bound to the signaling session.
//
// The client must reject TURN credentials that were not minted for the
// current session's base-user string.  This prevents credential-theft
// cross-session attacks: if Eve intercepts Alice's TURN password she cannot
// reuse it for a different session because the username embeds the session
// base-user as the verifiable component.
//
// Session binding policy:
//   username format: "<unix_ts>:<base_user>"  (per RFC 8656 / coturn convention)
//   credential:      HMAC-SHA256(shared_key, username)
//
// The client side validates:
//   1. username starts with a numeric timestamp segment.
//   2. The base_user suffix matches the expected session base-user.
//   3. The credential matches HMAC-SHA256(shared_key, username).
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'turn_credentials.dart';

/// Result of a TURN credential session-binding check.
enum TurnBindResult {
  /// Credential is valid and bound to this session.
  ok,

  /// The base-user in the username does not match the expected session user.
  mismatchedSession,

  /// The HMAC credential does not verify against the shared key.
  invalidHmac,

  /// The username is not in the expected "<ts>:<base_user>" format.
  malformedUsername,
}

/// Validate that [cred] was minted for [expectedBaseUser] using [sharedKey].
///
/// [sharedKey] is the 32-byte coturn shared secret.
TurnBindResult validateTurnSessionBinding({
  required TurnCredential cred,
  required String expectedBaseUser,
  required Uint8List sharedKey,
}) {
  final parts = cred.username.split(':');
  // Must be "<ts>:<base_user>".
  if (parts.length < 2) return TurnBindResult.malformedUsername;
  // First part must be a numeric timestamp.
  if (int.tryParse(parts[0]) == null) return TurnBindResult.malformedUsername;
  // The rest (joined) is the base-user.
  final embeddedBaseUser = parts.sublist(1).join(':');
  if (embeddedBaseUser != expectedBaseUser) {
    return TurnBindResult.mismatchedSession;
  }
  // Verify HMAC-SHA256(sharedKey, username) == credential.
  final hmac = Hmac(sha256, sharedKey);
  final expectedCred =
      base64.encode(hmac.convert(utf8.encode(cred.username)).bytes);
  if (cred.credential != expectedCred) return TurnBindResult.invalidHmac;
  return TurnBindResult.ok;
}

/// Mint a session-bound TURN credential for [baseUser].
///
/// Returns a [TurnCredential] whose credential is HMAC-SHA256(sharedKey,
/// username).
TurnCredential mintSessionBoundCredential({
  required String baseUser,
  required Uint8List sharedKey,
  required DateTime expiresAt,
}) {
  final ts = expiresAt
      .subtract(TurnCredentialService.serverTtl)
      .millisecondsSinceEpoch ~/
      1000;
  final username = '$ts:$baseUser';
  final hmac = Hmac(sha256, sharedKey);
  final credential = base64.encode(hmac.convert(utf8.encode(username)).bytes);
  return TurnCredential(
    username: username,
    credential: credential,
    expiresAt: expiresAt,
  );
}
