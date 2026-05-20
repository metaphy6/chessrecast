// §9.9 T-N-009 — Rooted/jailbroken device → casual-only mode.
//
// On a rooted or jailbroken device, the chess engine's integrity cannot be
// guaranteed (the attacker may patch the native lib).  The policy is:
//   - If root is detected: allow only casual games (no rated, no tournament).
//   - Surface a persistent warning in the UI.
//   - The rated/tournament game start is blocked at the service layer.
library;

/// Device root/jailbreak detection status.
enum RootStatus {
  /// Device shows no signs of root / jailbreak.
  clean,

  /// Root or jailbreak detected; integrity guarantees void.
  rooted,

  /// Detection inconclusive (e.g., emulator, unusual ROM).
  unknown,
}

/// Game modes available per root status.
enum GameModeRestriction {
  /// All modes available (clean device).
  unrestricted,

  /// Only casual games allowed (rooted or unknown device).
  casualOnly,
}

/// Policy enforcing rooted-device game-mode restrictions (§9.9 T-N-009).
class RootedDevicePolicy {
  /// Evaluate the allowed game-mode restriction for [status].
  static GameModeRestriction evaluate(RootStatus status) {
    switch (status) {
      case RootStatus.clean:
        return GameModeRestriction.unrestricted;
      case RootStatus.rooted:
      case RootStatus.unknown:
        return GameModeRestriction.casualOnly;
    }
  }

  /// Whether [status] allows rated / tournament games.
  static bool allowsRatedGames(RootStatus status) =>
      evaluate(status) == GameModeRestriction.unrestricted;

  /// Human-readable warning shown to the user on rooted devices.
  static const String kRootWarning =
      'Root or jailbreak detected. Rated and tournament games are unavailable '
      'because engine integrity cannot be verified on this device.';
}
