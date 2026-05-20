// §9.10 T-P-011 — Anti-rollback high-water mark for identity key version.
//
// Once a new device identity (key pair) has been enrolled under version N,
// the client must refuse to re-enroll an identity at version < N.  This
// prevents downgrade attacks where an attacker tries to revive a compromised
// key.
//
// The high-water mark is stored in tamper-evident persistent storage (the same
// hardware-backed store used for keys; see §9.4 T-D-001).
library;

/// Thrown when an enrollment attempt is below the stored high-water mark.
class RollbackAttemptError implements Exception {
  final int attemptedVersion;
  final int highWaterMark;

  const RollbackAttemptError({
    required this.attemptedVersion,
    required this.highWaterMark,
  });

  @override
  String toString() =>
      'RollbackAttemptError: attempted v$attemptedVersion < hwm v$highWaterMark';
}

/// Anti-rollback enforcer for device-identity key versions.
///
/// [highWaterMark] is the highest version previously enrolled.  All comparisons
/// are exclusive-lower-bound: `new_version > highWaterMark` is required.
class AntiRollbackPolicy {
  int _highWaterMark;

  AntiRollbackPolicy(int initialHighWaterMark)
      : assert(initialHighWaterMark >= 0),
        _highWaterMark = initialHighWaterMark;

  /// The current high-water mark.
  int get highWaterMark => _highWaterMark;

  /// Attempt to enroll key version [newVersion].
  ///
  /// - If [newVersion] > [highWaterMark]: updates the mark and returns normally.
  /// - Otherwise: throws [RollbackAttemptError] — the enrollment is refused.
  void enroll(int newVersion) {
    if (newVersion <= _highWaterMark) {
      throw RollbackAttemptError(
        attemptedVersion: newVersion,
        highWaterMark: _highWaterMark,
      );
    }
    _highWaterMark = newVersion;
  }

  /// Check whether [version] is strictly above the current high-water mark
  /// without modifying state.
  bool isAllowed(int version) => version > _highWaterMark;
}
