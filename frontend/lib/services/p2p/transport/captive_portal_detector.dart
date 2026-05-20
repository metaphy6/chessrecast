// §9.1 T-N-007 — Captive portal detection via HTTPS canary probe.
//
// When STUN and plain TURN UDP are blocked, the ICE connection fails and the
// device may be behind a captive portal (e.g. hotel Wi-Fi, coffee shop).
// The client detects this by issuing a HEAD request to a known-good HTTPS
// canary endpoint and checking the response code.
//
// Design:
//   canary URL:   https://captive-check.chessrecast.app/ping
//   expected code: 204 (No Content) — matches Chrome Connectivity Service style
//   decision logic:
//     - HTTP 204 → reachable, no captive portal
//     - any other status or network error → captive portal suspected
library;

/// Well-known canary URL for captive-portal detection.
const String kCaptivePortalCanaryUrl =
    'https://captive-check.chessrecast.app/ping';

/// Expected HTTP status code from the canary when no captive portal is present.
const int kCaptivePortalExpectedStatus = 204;

/// Decision returned by [CaptivePortalDetector.evaluate].
enum CaptivePortalDecision {
  /// HTTPS canary returned 204 — no captive portal detected.
  reachable,

  /// HTTPS canary returned an unexpected status → captive portal suspected.
  suspectedPortal,

  /// HTTPS canary request failed (network error, timeout) → captive portal
  /// suspected.
  networkError,
}

/// Evaluates a canary HTTP response to determine captive-portal state.
///
/// Injectable [fetchStatus] callback enables testing without real HTTP.
class CaptivePortalDetector {
  /// The canary URL queried on each [detect] call.
  final String canaryUrl;

  const CaptivePortalDetector({
    this.canaryUrl = kCaptivePortalCanaryUrl,
  });

  /// Evaluate whether the device is behind a captive portal.
  ///
  /// [fetchStatus] should perform a HEAD request to [canaryUrl] and return
  /// the HTTP status code, or null on network error.
  CaptivePortalDecision evaluate({required int? statusCode}) {
    if (statusCode == null) return CaptivePortalDecision.networkError;
    if (statusCode == kCaptivePortalExpectedStatus) {
      return CaptivePortalDecision.reachable;
    }
    return CaptivePortalDecision.suspectedPortal;
  }
}
