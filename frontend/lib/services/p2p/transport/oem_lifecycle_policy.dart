/// OEM lifecycle policies for aggressive Android OEM battery optimisations.
///
/// §4.9 — Certain OEM Android skins (Xiaomi MIUI, Huawei EMUI, OnePlus
/// OxygenOS) aggressively kill background apps beyond what AOSP specifies.
/// This module provides nudge logic and postmortem recovery for those cases.
library;

// ── OEM vendor classification ────────────────────────────────────────────────

enum OemVendor { xiaomiMiui, huaweiEmui, onePlusOxygenOs, stockAndroid }

class OemLifecyclePolicy {
  final OemVendor oem;

  const OemLifecyclePolicy({required this.oem});

  /// Whether this OEM skin requires a user nudge to disable battery
  /// optimisation for the app.
  bool get needsBatteryNudge => oem != OemVendor.stockAndroid;

  /// Deep-link route for the OEM battery settings screen.
  String get nudgeSettingsRoute => switch (oem) {
        OemVendor.xiaomiMiui =>
          'android.settings.battery_saver (MIUI Battery)',
        OemVendor.huaweiEmui =>
          'com.huawei.systemmanager/.power.ui.HwPowerManagerActivity',
        OemVendor.onePlusOxygenOs =>
          'com.oneplus.brickmode/.BatteryActivity (OxygenOS battery)',
        OemVendor.stockAndroid => '',
      };
}

// ── Foreground service killed postmortem ─────────────────────────────────────

class _Tombstone {
  final int lastSeq;
  final List<int> pendingMoveBytes;

  const _Tombstone({required this.lastSeq, required this.pendingMoveBytes});
}

class _RecoveryInfo {
  final String errorCode;
  const _RecoveryInfo({required this.errorCode});
}

class ForegroundServiceKilledPolicy {
  _Tombstone? _tombstone;

  _Tombstone? get tombstone => _tombstone;

  void onServiceKilled({
    required int lastSeq,
    required List<int> pendingMoveBytes,
  }) {
    _tombstone = _Tombstone(
      lastSeq: lastSeq,
      pendingMoveBytes: pendingMoveBytes,
    );
  }

  _RecoveryInfo? onAppLaunch() {
    if (_tombstone == null) return null;
    return const _RecoveryInfo(errorCode: 'FOREGROUND_SERVICE_KILLED');
  }
}

// ── Restricted background mode session cap ───────────────────────────────────

class RestrictedModeSessionCap {
  static const int maxRestrictedSessionSeconds = 300; // 5 minutes

  int? _startMs;
  String? _errorCode;

  String? get errorCode => _errorCode;

  void onSessionStart({required int nowMs}) {
    _startMs = nowMs;
    _errorCode = null;
  }

  bool isCapExceeded({required int nowMs}) {
    if (_startMs == null) return false;
    final elapsedMs = nowMs - _startMs!;
    if (elapsedMs > maxRestrictedSessionSeconds * 1000) {
      _errorCode = 'SESSION_CAP_EXCEEDED';
      return true;
    }
    return false;
  }
}
