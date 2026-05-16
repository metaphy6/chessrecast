/// Network heal policy — tracks ICE disconnect → reconnect events.
///
/// §4.4 — If the ICE connection drops (e.g. VPN toggle, WiFi handoff)
/// but reconnects within [healWindowMs], the session continues without
/// user intervention.  After the window expires the error code
/// 'NETWORK_LOST' is emitted and the session must be torn down.
library;

enum HealResult { healed, networkLost }

/// Network change event types used in chaos / scenario testing.
enum NetworkChangeType {
  airplaneToggle,
  wifiReconnect,
  cellularHandoff,
  vpnToggle,
}

class NetworkHealPolicy {
  /// Duration within which the ICE connection must recover (ms).
  static const int healWindowMs = 10000; // 10 s

  int? _disconnectedAtMs;
  HealResult? _result;
  String? _errorCode;

  HealResult? get result => _result;
  String? get errorCode => _errorCode;

  void onDisconnect({required int timestampMs}) {
    _disconnectedAtMs = timestampMs;
    _result = null;
    _errorCode = null;
  }

  void onReconnect({required int timestampMs}) {
    if (_disconnectedAtMs == null) return;
    final elapsed = timestampMs - _disconnectedAtMs!;
    if (elapsed <= healWindowMs) {
      _result = HealResult.healed;
    }
  }

  void onTimeout({required int timestampMs}) {
    if (_disconnectedAtMs == null) return;
    final elapsed = timestampMs - _disconnectedAtMs!;
    if (elapsed > healWindowMs) {
      _result = HealResult.networkLost;
      _errorCode = 'NETWORK_LOST';
    }
  }
}
