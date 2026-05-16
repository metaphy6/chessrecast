/// Deep-link / cold-start invite state.
///
/// §4.3 — A user can tap a "Join game" notification before the Flutter
/// app has finished launching.  The platform layer (Android Intent /
/// iOS Universal Link handler) writes the token here before the Dart
/// isolate is ready; the P2P service reads it once the isolate starts.
library;

class InviteState {
  String? _pendingToken;
  bool _receivedBeforeAppReady = false;

  /// The invite token waiting to be consumed, or null if there is none.
  String? get pendingToken => _pendingToken;

  /// True when [setDeepLink] was called before the app finished
  /// initialising (i.e. there is an unhandled deep-link).
  bool get hasUnhandledDeepLink =>
      _pendingToken != null && _receivedBeforeAppReady;

  /// Record an incoming deep-link invite token.
  ///
  /// If called multiple times, the latest token wins (the user tapped
  /// a newer invite).
  void setDeepLink({
    required String token,
    bool receivedBeforeAppReady = false,
  }) {
    _pendingToken = token;
    _receivedBeforeAppReady = receivedBeforeAppReady;
  }

  /// Return the pending token and clear it, or null if there is none.
  String? consumeToken() {
    final t = _pendingToken;
    _pendingToken = null;
    _receivedBeforeAppReady = false;
    return t;
  }
}
