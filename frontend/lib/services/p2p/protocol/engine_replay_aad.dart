// §12.3.bullet-5 T-P-AAD — engine_replay_version bound into MOVE n=0 AAD.
//
// The first AEAD frame of every session (MOVE n=0) uses the concatenation
//   domain_separator || version_bytes_4_le || session_id_32
// as additional authenticated data (AAD).
//
// Any tampering of the engine_replay_version in the wire-layer HELLO would
// produce a different AAD here and cause AEAD authentication to fail,
// catching version-downgrade injection at the transport layer.
library;

import 'dart:typed_data';

/// Domain separator for the MOVE n=0 AAD.
///
/// 8 bytes, ASCII "ERVAAD01" — "Engine Replay Version AAD, version 01".
/// Follows the NIST SP 800-108 recommendation of a unique label per KDF/AAD
/// context so that AADs from different protocol steps cannot be confused.
const List<int> _kMoveZeroAadDomainSeparator = [
  0x45, 0x52, 0x56, 0x41, // "ERVA"
  0x41, 0x44, 0x30, 0x31, // "AD01"
];

/// Build the AAD bytes for the first AEAD frame (MOVE n=0) of a session.
///
/// Layout (total = 8 + 4 + 32 = 44 bytes):
/// ```
///   Offset  Len  Field
///   ──────  ───  ─────────────────────────────────────────────────
///   0       8    domain_separator ("ERVAAD01")
///   8       4    engine_replay_version (u32 little-endian)
///   12      32   session_id
/// ```
///
/// Both peers must produce identical bytes from their locally-stored
/// [engineReplayVersion] (negotiated in HELLO) and [sessionId].
Uint8List buildMoveZeroAad({
  required int engineReplayVersion,
  required Uint8List sessionId,
}) {
  assert(sessionId.length == 32, 'sessionId must be 32 bytes');
  assert(
    engineReplayVersion >= 0 && engineReplayVersion <= 0xFFFFFFFF,
    'engineReplayVersion must fit in u32',
  );

  const domainLen = 8;
  const versionLen = 4;
  const sessionLen = 32;
  const totalLen = domainLen + versionLen + sessionLen; // 44

  final buf = Uint8List(totalLen);
  int offset = 0;

  // Domain separator.
  for (final b in _kMoveZeroAadDomainSeparator) {
    buf[offset++] = b;
  }

  // Engine replay version — 4 bytes, little-endian.
  final versionView = ByteData(4);
  versionView.setUint32(0, engineReplayVersion, Endian.little);
  buf[offset++] = versionView.getUint8(0);
  buf[offset++] = versionView.getUint8(1);
  buf[offset++] = versionView.getUint8(2);
  buf[offset++] = versionView.getUint8(3);

  // Session ID.
  buf.setRange(offset, offset + sessionLen, sessionId);

  return buf;
}

/// Verify that [aad] matches what [buildMoveZeroAad] would produce for the
/// given [engineReplayVersion] and [sessionId].
///
/// Returns `false` in constant time on any mismatch.
bool verifyMoveZeroAad({
  required int engineReplayVersion,
  required Uint8List sessionId,
  required Uint8List aad,
}) {
  final expected = buildMoveZeroAad(
    engineReplayVersion: engineReplayVersion,
    sessionId: sessionId,
  );
  if (aad.length != expected.length) return false;

  // Constant-time comparison.
  int diff = 0;
  for (int i = 0; i < expected.length; i++) {
    diff |= aad[i] ^ expected[i];
  }
  return diff == 0;
}
