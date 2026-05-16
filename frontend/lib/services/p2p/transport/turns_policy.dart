/// TURNS (TLS relay) policy models.
///
/// §4.10 — TURNS (TURN over TLS) is used as a last-resort fallback when
/// both STUN and plain TURN UDP are blocked by a captive portal or
/// enterprise firewall.  TURNS uses TCP port 5349 which is normally
/// allowed alongside HTTPS.
library;

// ── Failover policy ──────────────────────────────────────────────────────────

enum TurnsDecision { usePlainTurn, failoverToTurns }

class TurnsFailoverPolicy {
  /// Standard TURN UDP/TCP port.
  static const int plainTurnPort = 3478;

  /// TURNS TLS port (same as HTTPS alternative, typically open everywhere).
  static const int turnsPort = 5349;

  TurnsDecision onTurnResult({required bool success}) =>
      success ? TurnsDecision.usePlainTurn : TurnsDecision.failoverToTurns;
}

// ── Auto-promote ─────────────────────────────────────────────────────────────

class TurnsAutoPromote {
  static const String _turnHost = 'turn.chessrecast.app';

  const TurnsAutoPromote._();

  /// Build the ICE server URL list, optionally including TURNS.
  static List<String> buildIceCandidateUrls({required bool turnUdpBlocked}) {
    final urls = <String>[
      'turn:$_turnHost:${TurnsFailoverPolicy.plainTurnPort}',
    ];
    if (turnUdpBlocked) {
      urls.add(
          'turns:$_turnHost:${TurnsFailoverPolicy.turnsPort}?transport=tcp');
    }
    return urls;
  }
}

// ── Metered network + TURNS prompt ──────────────────────────────────────────

enum MeteredNetworkTurnsAction { warnUser, proceed }

class MeteredNetworkTurnsPolicy {
  MeteredNetworkTurnsAction evaluate({
    required bool isMetered,
    required bool turnsRequired,
  }) {
    if (isMetered && turnsRequired) return MeteredNetworkTurnsAction.warnUser;
    return MeteredNetworkTurnsAction.proceed;
  }
}

// ── Error codes ───────────────────────────────────────────────────────────────

class TurnsErrorCodes {
  const TurnsErrorCodes._();

  /// Emitted when the TURNS TLS handshake fails (certificate error,
  /// connection refused, or timeout).
  static const String handshakeFailed = 'TURNS_HANDSHAKE_FAILED';
}
