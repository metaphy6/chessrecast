// §12.1.bullet-3 — BUILD_REPLAY_VERSION: informational build-sequence counter.
//
// BUILD_REPLAY_VERSION is auto-incremented by CI (via -DBUILD_REPLAY_VERSION=N
// cmake configure flag).  Developer builds always have value 0.
//
// A mismatch between peers' build_replay_version is INFORMATIONAL ONLY;
// it MUST NOT cause a connection error.  Peers may be running the same
// chess-rule semantics (same ENGINE_REPLAY_VERSION) from different CI builds.
//
// Wire key: 'build_replay_version' in HELLO/HELLO_ACK payload.
// Wire size: 4 bytes (CBOR unsigned int ≤ 0xFFFF_FFFF).
library;

import 'dart:ffi';
import 'dart:io';

// ---------------------------------------------------------------------------
// Compile-time constant (source tree always 0; CI sets at cmake configure).
// ---------------------------------------------------------------------------

/// Build-sequence counter compiled into this Dart build.
///
/// Always 0 in developer builds.  CI passes the real value via
/// `--dart-define=BUILD_REPLAY_VERSION=<n>` when building the app.
const int kBuildReplayVersion = int.fromEnvironment(
  'BUILD_REPLAY_VERSION',
  defaultValue: 0,
);

/// CBOR payload key for build_replay_version in HELLO/HELLO_ACK.
const String kBuildReplayVersionKey = 'build_replay_version';

// ---------------------------------------------------------------------------
// Runtime resolver (optional FFI read from native lib).
// ---------------------------------------------------------------------------

typedef _GetVersionNative = Uint32 Function();
typedef _GetVersionDart = int Function();

/// Returns the build replay version at runtime.
///
/// 1. Tries `get_build_replay_version()` from the native shared library.
/// 2. Falls back to [kBuildReplayVersion] (always 0 in dev builds).
///
/// The result is cached after the first call.
int get resolvedBuildReplayVersion => _resolvedBuildVersion;

late final int _resolvedBuildVersion = _resolveBuildVersion();

int _resolveBuildVersion() {
  if (Platform.isIOS || Platform.isMacOS || Platform.isWindows) {
    return kBuildReplayVersion;
  }
  try {
    final overridePath =
        Platform.environment['CHESSRECAST_NATIVE_ENGINE_LIB'];
    final libPath = (overridePath?.isNotEmpty == true)
        ? overridePath!
        : '${Directory.current.path}/build/native/linux/libchess_engine.so';

    if (!File(libPath).existsSync()) return kBuildReplayVersion;

    final lib = DynamicLibrary.open(libPath);
    final fn = lib.lookup<NativeFunction<_GetVersionNative>>(
      'get_build_replay_version',
    );
    return fn.asFunction<_GetVersionDart>()();
  } catch (_) {
    return kBuildReplayVersion;
  }
}

// ---------------------------------------------------------------------------
// HELLO/HELLO_ACK helpers — build version is injected and extracted but
// NEVER used to reject a peer.
// ---------------------------------------------------------------------------

/// Inject build_replay_version into a HELLO/HELLO_ACK payload map.
///
/// Returns a new map; [payload] is not mutated.
Map<String, dynamic> addBuildVersionToHello(
  Map<String, dynamic> payload,
  int buildVersion,
) {
  return {...payload, kBuildReplayVersionKey: buildVersion};
}

/// Extract build_replay_version from a received HELLO payload.
///
/// Returns null if absent; the caller MUST NOT reject a peer on null.
int? extractBuildVersionFromHello(Map<String, dynamic> payload) {
  final v = payload[kBuildReplayVersionKey];
  if (v == null) return null;
  if (v is! int) return null;
  return v;
}
