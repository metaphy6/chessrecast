/// Network monitor helpers: metered network, battery saver, and roaming.
///
/// §4.8 — Adaptive quality policies for bandwidth-sensitive environments.
library;

// ── Metered network ─────────────────────────────────────────────────────────

enum MeteredNetworkAction { warnUser, proceed }

class MeteredNetworkPolicy {
  static const String warningMessage =
      'You are on a metered network. This chess game uses a TURN relay '
      'which may consume additional mobile data.';

  MeteredNetworkAction check({
    required bool isMetered,
    required bool willUseTurnRelay,
  }) {
    if (isMetered && willUseTurnRelay) return MeteredNetworkAction.warnUser;
    return MeteredNetworkAction.proceed;
  }
}

// ── Battery saver ────────────────────────────────────────────────────────────

class BatterySaverClockPolicy {
  /// Normal clock heartbeat interval (ms).
  static const int normalCadenceMs = 250;

  /// Reduced heartbeat interval when OS battery saver is active (ms).
  static const int batterySaverCadenceMs = 1000;

  int cadenceMs({required bool batterySaverActive}) =>
      batterySaverActive ? batterySaverCadenceMs : normalCadenceMs;
}

// ── Roaming ──────────────────────────────────────────────────────────────────

enum RoamingAction { warnOnce, suppress }

class RoamingPolicy {
  static const String warningMessage =
      'You appear to be roaming. International data rates may apply.';

  bool _warned = false;
  bool _lastRoaming = false;

  RoamingAction onRoamingChanged({required bool isRoaming}) {
    if (!isRoaming) {
      // Back on home network — reset guard for next roaming event.
      _warned = false;
      _lastRoaming = false;
      return RoamingAction.suppress;
    }
    if (!_warned) {
      _warned = true;
      _lastRoaming = true;
      return RoamingAction.warnOnce;
    }
    return RoamingAction.suppress;
  }
}
