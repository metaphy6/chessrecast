/**
 * replay_version.c — FFI-visible accessors for ENGINE_REPLAY_VERSION and
 * BUILD_REPLAY_VERSION (Phase 12.1).
 *
 * These two thin functions are the sole exports added by Phase 12.  They let
 * the Dart P2P layer read the versioning tokens compiled into this build
 * without relying on a hard-coded Dart constant.
 *
 * Note: the EXPORT macro (visibility("default")) is defined in bridge.h.
 */
#include "bridge.h"
#include "replay_version.h"

/**
 * get_engine_replay_version()
 *
 * Returns ENGINE_REPLAY_VERSION as defined in replay_version.h.
 * Dart FFI signature:  int Function()  (Uint32 native return).
 *
 * Used by:
 *   - engine_replay_version.dart  (kEngineReplayVersion fallback init)
 *   - replay_version_ffi_test.dart  (§12.1 proof)
 */
EXPORT uint32_t get_engine_replay_version(void) {
    return ENGINE_REPLAY_VERSION;
}

/**
 * get_build_replay_version()
 *
 * Returns BUILD_REPLAY_VERSION as defined at configure time (default 0 in
 * developer builds; set by CI via -DBUILD_REPLAY_VERSION=<n>).
 * Dart FFI signature:  int Function()  (Uint32 native return).
 *
 * A mismatch between peers' BUILD_REPLAY_VERSION is informational only
 * and MUST NOT cause a connection error.
 */
EXPORT uint32_t get_build_replay_version(void) {
    return BUILD_REPLAY_VERSION;
}
