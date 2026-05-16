# P2P Android OEM Battery Optimisation Matrix

This document catalogues the per-OEM battery-optimisation behaviours that can
kill or restrict the Chess Recast foreground service, the per-vendor
deep-link route to the exemption screen, and the expected user-visible
symptoms.

## Background

Standard Android allows a foreground service (with a persistent notification)
to keep a peer-to-peer WebRTC session alive while the app is in the background.
Several OEM Android skins override this with proprietary battery managers that
kill foreground services regardless of the API contract.

The `OemLifecyclePolicy` class in
`frontend/lib/services/p2p/transport/oem_lifecycle_policy.dart` detects the
OEM at runtime and provides the correct deep-link route so the app can nudge
the user to add Chess Recast to the battery-exempt list.

## OEM Compatibility Matrix

| OEM / Skin | Battery Manager | Kill Behaviour | Exemption Route | `OemVendor` |
|---|---|---|---|---|
| Stock Android (AOSP) | Standard Doze | Foreground services survive | N/A (no nudge needed) | `stockAndroid` |
| Xiaomi (MIUI 12+) | MIUI Battery & Performance | Kills foreground services after ~3 min | `android.settings.battery_saver` (MIUI Battery) | `xiaomiMiui` |
| Huawei (EMUI 9+) | PowerGenie | Kills any background app; ignores foreground-service flag | `com.huawei.systemmanager/.power.ui.HwPowerManagerActivity` | `huaweiEmui` |
| OnePlus (OxygenOS 11+) | Battery Optimization | Kills restricted apps aggressively | `com.oneplus.brickmode/.BatteryActivity` | `onePlusOxygenOs` |
| Samsung (One UI 4+) | Device Care | Battery adaptive sleeping; less aggressive than MIUI | `android.settings.IGNORE_BATTERY_OPTIMIZATION` | *(future)* |
| Oppo / Realme (ColorOS 12+) | Smart Power Saver | Similar to MIUI | `com.coloros.oppoguardelf/.power.StartupManagerActivity` | *(future)* |

> Note: OEM skin detection is performed via `android.os.Build.MANUFACTURER` and
> `android.os.Build.VERSION.INCREMENTAL` patterns.  The Dart layer receives the
> detected `OemVendor` via a `MethodChannel` call at app startup.

## Restricted-Mode Session Cap

When the device is in Android's "Restricted" background mode (introduced in
Android 13), battery-exempt exemptions are temporary.  The
`RestrictedModeSessionCap` class enforces a 5-minute hard cap on P2P sessions
in this mode to prevent silent connection drops mid-game.

| Mode | Max Session Length | Error Code on Cap |
|---|---|---|
| Normal background | Unlimited (foreground service) | — |
| Restricted background | 300 s (5 min) | `SESSION_CAP_EXCEEDED` |

## Foreground Service Killed Postmortem

If the foreground service is killed by the OEM battery manager mid-game:

1. The service writes a tombstone (`ForegroundServiceKilledPolicy.onServiceKilled`)
   containing the last ACKed sequence number and any pending move bytes.
2. On next app launch, `onAppLaunch()` detects the tombstone and emits the
   `FOREGROUND_SERVICE_KILLED` error code to the P2P session layer.
3. The session layer uses the tombstone's `lastSeq` to attempt a resync
   handshake with the peer (§4.6 ResyncProtocol).
4. If the peer is still connected, the game continues from the last ACKed
   position.  If the peer has abandoned, the session is terminated gracefully.

## Testing

Unit tests for OEM lifecycle policies are in:

- `frontend/test/p2p/transport/oem_battery_optimisation_nudge_test.dart`
- `frontend/test/p2p/transport/foreground_service_killed_postmortem_test.dart`
- `frontend/test/p2p/transport/restricted_mode_session_cap_test.dart`

Manual testing on real OEM devices is required to verify that the deep-link
routes above navigate to the correct settings screen; these paths are known
to change between OEM firmware updates.
