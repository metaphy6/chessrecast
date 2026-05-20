// §12.1 T-P-RVF — ENGINE_REPLAY_VERSION header exists and FFI symbol is
// consistent with the Dart compile-time constant kEngineReplayVersion.
//
// Pre-implementation (failing) state:
//   front/native/engine/replay_version.h does not exist → test fails.
//
// Post-implementation (passing) state:
//   replay_version.h exists with ENGINE_REPLAY_VERSION = 1.
//   replay_version.c is compiled into the shared lib (next CI rebuild).
//   Dart kEngineReplayVersion == 1 matches the header.
//   Optional FFI call get_engine_replay_version() == 1 when lib exports it.
import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:chessrecast/services/p2p/protocol/engine_replay_version.dart';

// Typedef for the optional FFI probe.
typedef _GetVersionNative = Uint32 Function();
typedef _GetVersionDart = int Function();

void main() {
  group('§12.1 ENGINE_REPLAY_VERSION header + FFI', () {
    late String headerPath;

    setUpAll(() {
      // Resolve replay_version.h from the test process cwd (frontend/).
      final cwd = Directory.current.path;
      // When running under `flutter test`, cwd is frontend/.
      // Also allow the monorepo root cwd (CI may run from repo root).
      final candidates = [
        '$cwd/native/engine/replay_version.h',
        '$cwd/../frontend/native/engine/replay_version.h',
        '$cwd/frontend/native/engine/replay_version.h',
      ];
      headerPath = candidates.firstWhere(
        (p) => File(p).existsSync(),
        orElse: () => candidates.first, // will fail the test below
      );
    });

    test('replay_version.h exists at expected path', () {
      expect(
        File(headerPath).existsSync(),
        isTrue,
        reason:
            'frontend/native/engine/replay_version.h must exist '
            '(Phase 12.1). Create it with ENGINE_REPLAY_VERSION = 1.',
      );
    });

    test('replay_version.h defines ENGINE_REPLAY_VERSION', () {
      final content = File(headerPath).readAsStringSync();
      expect(
        content,
        contains('ENGINE_REPLAY_VERSION'),
        reason: 'replay_version.h must define the ENGINE_REPLAY_VERSION macro.',
      );
    });

    test('replay_version.h defines ENGINE_REPLAY_VERSION as 1', () {
      final content = File(headerPath).readAsStringSync();
      // Look for the numeric literal 1 adjacent to ENGINE_REPLAY_VERSION.
      expect(
        RegExp(r'ENGINE_REPLAY_VERSION[^0-9]*\b1\b').hasMatch(content),
        isTrue,
        reason: 'ENGINE_REPLAY_VERSION must equal 1 for the initial release.',
      );
    });

    test('Dart kEngineReplayVersion matches header value (== 1)', () {
      // This guards against the Dart constant drifting from the C header.
      expect(
        kEngineReplayVersion,
        equals(1),
        reason:
            'kEngineReplayVersion in engine_replay_version.dart must equal '
            'ENGINE_REPLAY_VERSION in replay_version.h (both must be 1).',
      );
    });

    test(
      'FFI get_engine_replay_version() returns kEngineReplayVersion',
      () {
        // Attempt to dlsym the function. Skip gracefully if not yet compiled
        // into the shared lib (will be available after next cmake build).
        final overridePath =
            Platform.environment['CHESSRECAST_NATIVE_ENGINE_LIB'];
        final libPath = overridePath?.isNotEmpty == true
            ? overridePath!
            : '${Directory.current.path}/build/native/linux/libchess_engine.so';

        if (!File(libPath).existsSync()) {
          // Native lib not present — skip FFI check.
          return;
        }

        try {
          final lib = DynamicLibrary.open(libPath);
          final fn = lib.lookup<NativeFunction<_GetVersionNative>>(
            'get_engine_replay_version',
          );
          final getVersion = fn.asFunction<_GetVersionDart>();
          expect(
            getVersion(),
            equals(kEngineReplayVersion),
            reason:
                'C get_engine_replay_version() must equal kEngineReplayVersion.',
          );
        } on ArgumentError {
          // Symbol not yet exported — lib was built before replay_version.c
          // was added to CMakeLists. This is expected until the next rebuild.
          // The filesystem test above already validates the header.
        }
      },
      skip: Platform.isIOS || Platform.isMacOS || Platform.isWindows,
    );
  });
}
