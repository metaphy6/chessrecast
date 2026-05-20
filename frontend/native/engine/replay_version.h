/**
 * replay_version.h — Engine replay-version token (Phase 12.1).
 *
 * ENGINE_REPLAY_VERSION identifies the chess-rule semantics baked into this
 * build.  It is emitted as a 32-bit FFI symbol so the Dart layer can read the
 * current value without hard-coding it.  The Dart kEngineReplayVersion
 * constant in engine_replay_version.dart MUST match this value at all times.
 *
 * Rules for bumping ENGINE_REPLAY_VERSION:
 *   1. Move generation or legality logic changes.
 *   2. Draw-rule logic changes (50-move, repetition, mod-specific).
 *   3. Mod-specific rule changes (heir double-king, succession last-pawn, …).
 *   4. Canonical state-hash algorithm changes.
 *
 * BUILD_REPLAY_VERSION tracks the build sequence and is auto-incremented by
 * CI.  It is informational only; a mismatch between peers is NOT an error.
 * Developers MUST NOT change BUILD_REPLAY_VERSION by hand; leave it at the
 * default (0) in the source tree.
 */
#ifndef REPLAY_VERSION_H
#define REPLAY_VERSION_H

#include <stdint.h>

/** Chess-rule version — bump when any rule semantics change. */
#define ENGINE_REPLAY_VERSION ((uint32_t)1)

/**
 * Build-sequence counter — CI only.
 * Source tree always holds 0; CI passes -DBUILD_REPLAY_VERSION=<n> during
 * cmake configure.  Do NOT change this value in the source file.
 */
#ifndef BUILD_REPLAY_VERSION
#define BUILD_REPLAY_VERSION ((uint32_t)0)
#endif

#endif /* REPLAY_VERSION_H */
