// §12.2 T-P-ERV — Engine replay-version negotiation in HELLO/HELLO_ACK.
//
// Both peers must carry the same ENGINE_REPLAY_VERSION in their HELLO frame.
// A mismatch aborts the handshake with ENGINE_VERSION_MISMATCH (§10.1).
//
// Version 1 is the initial value. When the native C layer (Phase 12.1) ships,
// this constant will be replaced by an FFI read of the static symbol
// `engine_replay_version` exported from replay_version.h. Until then, the
// Dart constant is the authoritative source.
library;

/// Current engine replay version (u32).
///
/// Bumped manually for any change that affects move generation, legality,
/// draw rules, mod-specific rules, or canonical state hash.
/// NOT bumped for: search-only, eval-only, opening book content, performance
/// tuning that does not affect move legality.
///
/// Wire size: 4 bytes (CBOR unsigned int ≤ 0xFFFF_FFFF).
const int kEngineReplayVersion = 1;

/// CBOR payload key for engine_replay_version in HELLO/HELLO_ACK.
const String kEngineReplayVersionKey = 'engine_replay_version';

/// Thrown when two peers' HELLO frames carry different engine_replay_version
/// values. Surfaces as F-PROTO-010 ENGINE_VERSION_MISMATCH in the UI.
class EngineVersionMismatchError implements Exception {
  final int localVersion;
  final int remoteVersion;

  const EngineVersionMismatchError({
    required this.localVersion,
    required this.remoteVersion,
  });

  @override
  String toString() =>
      'EngineVersionMismatchError: '
      'local=$localVersion remote=$remoteVersion '
      '(ENGINE_VERSION_MISMATCH §10.1)';
}

/// Validate that [remoteVersion] matches [localVersion].
///
/// Throws [EngineVersionMismatchError] if they differ.
/// This check is O(1) at handshake (§12.3 performance attribute).
void validateHelloEngineReplayVersion({
  required int localVersion,
  required int remoteVersion,
}) {
  if (localVersion != remoteVersion) {
    throw EngineVersionMismatchError(
      localVersion: localVersion,
      remoteVersion: remoteVersion,
    );
  }
}

/// Inject [engineReplayVersion] into an existing HELLO/HELLO_ACK payload map.
///
/// Returns a new map with the `engine_replay_version` field added.
/// The original [payload] is not mutated.
Map<String, dynamic> addEngineVersionToHello(
  Map<String, dynamic> payload,
  int engineReplayVersion,
) {
  return {
    ...payload,
    kEngineReplayVersionKey: engineReplayVersion,
  };
}

/// Extract the `engine_replay_version` field from a received HELLO payload.
///
/// Returns null if the field is absent (peer is pre-Phase-12; treat as
/// mismatch per the backward-compat policy: none in v1).
int? extractEngineVersionFromHello(Map<String, dynamic> payload) {
  final v = payload[kEngineReplayVersionKey];
  if (v == null) return null;
  if (v is! int) return null;
  return v;
}
