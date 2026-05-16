/// ICE restart policy tied to session-key lifetime.
///
/// §4.3 — ICE restarts are triggered by network changes.  However, after
/// [maxSessionKeyAge] the DTLS session key must be rotated, which requires
/// a full teardown rather than a lightweight ICE restart.
library;

class IceRestartPolicy {
  /// Maximum age of a DTLS session key before a hard teardown is required.
  static const Duration maxSessionKeyAge = Duration(minutes: 30);

  /// The point in time at which the current session key was established.
  final DateTime sessionKeyCreatedAt;

  IceRestartPolicy({required this.sessionKeyCreatedAt});

  /// Whether an in-place ICE restart (without DTLS renegotiation) is
  /// still safe at this moment.
  bool get canRestart =>
      DateTime.now().difference(sessionKeyCreatedAt) <= maxSessionKeyAge;

  /// Human-readable reason to include in the ICE-restart or teardown event.
  String get restartReason =>
      canRestart ? 'network_change' : 'session_key_expired';
}
