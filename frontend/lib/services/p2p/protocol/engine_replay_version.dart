// §12.1 + §12.2 T-P-ERV — Engine replay-version: native C header + HELLO/HELLO_ACK.
//
// ENGINE_REPLAY_VERSION is defined in frontend/native/engine/replay_version.h
// (Phase 12.1) and exposed via get_engine_replay_version() FFI.  The Dart
// compile-time constant kEngineReplayVersion MUST equal the C header value.
//
// At runtime, [resolvedEngineReplayVersion] first tries the FFI symbol and
// falls back to kEngineReplayVersion.  This lets a developer run tests with a
// pre-Phase-12 binary while still getting the correct value post-rebuild.
library;

import 'dart:ffi';
import 'dart:io';

// ---------------------------------------------------------------------------
// Compile-time constant (authoritative source of truth; must match C header).
// ---------------------------------------------------------------------------

/// Current engine replay version (u32).
///
/// **Must equal** `ENGINE_REPLAY_VERSION` in
/// `frontend/native/engine/replay_version.h` at all times.
///
/// Bumped manually for any change that affects move generation, legality,
/// draw rules, mod-specific rules, or canonical state hash.
/// NOT bumped for: search-only, eval-only, opening book content, performance
/// tuning that does not affect move legality.
///
/// Wire size: 4 bytes (CBOR unsigned int ≤ 0xFFFF_FFFF).
const int kEngineReplayVersion = 1;

// ---------------------------------------------------------------------------
// Runtime resolver — reads from native lib when available.
// ---------------------------------------------------------------------------

typedef _GetVersionNative = Uint32 Function();
typedef _GetVersionDart = int Function();

/// Returns the engine replay version at runtime.
///
/// 1. Tries `get_engine_replay_version()` from the native shared library.
/// 2. Falls back to [kEngineReplayVersion] if the symbol is absent or the lib
///    cannot be loaded (e.g. pre-Phase-12 build).
///
/// The result is cached after the first call.
int get resolvedEngineReplayVersion => _resolvedVersion;

late final int _resolvedVersion = _resolveVersion();

int _resolveVersion() {
  if (Platform.isIOS || Platform.isMacOS || Platform.isWindows) {
    // Dynamic lib path resolution differs on those platforms; fall back.
    return kEngineReplayVersion;
  }
  try {
    final overridePath =
        Platform.environment['CHESSRECAST_NATIVE_ENGINE_LIB'];
    final libPath = (overridePath?.isNotEmpty == true)
        ? overridePath!
        : '${Directory.current.path}/build/native/linux/libchess_engine.so';

    if (!File(libPath).existsSync()) return kEngineReplayVersion;

    final lib = DynamicLibrary.open(libPath);
    final fn = lib.lookup<NativeFunction<_GetVersionNative>>(
      'get_engine_replay_version',
    );
    return fn.asFunction<_GetVersionDart>()();
  } catch (_) {
    // Symbol absent (old build) or any other load error.
    return kEngineReplayVersion;
  }
}

// ---------------------------------------------------------------------------
// CBOR key + error type used by HELLO/HELLO_ACK negotiation.
// ---------------------------------------------------------------------------

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
  return {...payload, kEngineReplayVersionKey: engineReplayVersion};
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
