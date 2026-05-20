// §12.5.bullet-1 T-P-HWM — Per-account engine-replay-version high-water-mark.
//
// A malicious peer can advertise a low engine_replay_version to coerce an
// opponent into executing older (potentially-buggy) rule semantics — even
// if both peers agreed on version N in their HELLO (which is only per-session).
//
// This module maintains a persistent "seen max" across all sessions for the
// local account. Once version N has been seen from any peer, any future HELLO
// carrying a version < N triggers OPPONENT_FINGERPRINT_DOWNGRADE_DETECTED.
//
// Separation from frontend/lib/services/p2p/identity/anti_rollback.dart:
// That module guards the device-identity key-version; this module guards the
// engine-replay-version seen from opponents across sessions. Different security
// boundaries, different stores.
library;

/// Thrown when a remote HELLO carries an engine_replay_version below the
/// stored per-account high-water mark.
///
/// Maps to F-PROTO-025 OPPONENT_FINGERPRINT_DOWNGRADE_DETECTED (§10.3) in the
/// error catalog.
class EngineReplayDowngradeDetectedError implements Exception {
  final int observedVersion;
  final int highWaterMark;

  const EngineReplayDowngradeDetectedError({
    required this.observedVersion,
    required this.highWaterMark,
  });

  @override
  String toString() =>
      'EngineReplayDowngradeDetectedError: '
      'observed=$observedVersion < hwm=$highWaterMark '
      '(OPPONENT_FINGERPRINT_DOWNGRADE_DETECTED §10.3)';
}

/// Backing store interface for the engine-replay high-water mark.
///
/// In production this is backed by the SQLCipher `meta` table
/// (key: `seen_max_engine_replay_version`). Tests use [InMemoryEngineReplayHwmStore].
abstract class EngineReplayHwmStore {
  /// Current stored high-water mark (0 if never set).
  int get storedHwm;

  /// Persist a new high-water mark. Must be called only when [newHwm] > [storedHwm].
  void persist(int newHwm);
}

/// In-memory implementation of [EngineReplayHwmStore] for unit tests.
class InMemoryEngineReplayHwmStore implements EngineReplayHwmStore {
  int _hwm = 0;

  @override
  int get storedHwm => _hwm;

  @override
  void persist(int newHwm) {
    _hwm = newHwm;
  }
}

/// Enforces the per-account engine-replay-version high-water mark.
///
/// Instantiate once per session with the backing [EngineReplayHwmStore].
class EngineReplayHwmPolicy {
  final EngineReplayHwmStore _store;

  EngineReplayHwmPolicy(this._store);

  /// Current high-water mark as read from the backing store.
  int get highWaterMark => _store.storedHwm;

  /// Record that [remoteVersion] was seen in an incoming HELLO.
  ///
  /// - If [remoteVersion] > current HWM: advances the HWM and returns normally.
  /// - If [remoteVersion] == current HWM: no-op, returns normally (same version
  ///   is expected in most sessions).
  /// - If [remoteVersion] < current HWM: throws [EngineReplayDowngradeDetectedError].
  ///   The HWM is NOT modified so subsequent sessions see the same floor.
  void observeRemoteVersion(int remoteVersion) {
    final hwm = _store.storedHwm;
    if (remoteVersion < hwm) {
      throw EngineReplayDowngradeDetectedError(
        observedVersion: remoteVersion,
        highWaterMark: hwm,
      );
    }
    if (remoteVersion > hwm) {
      _store.persist(remoteVersion);
    }
    // remoteVersion == hwm: no-op.
  }
}
