// §6.7.3 Share-sheet integration and §6.7.4 QR-code fallback.
//
// The [InviteShareService] wraps the OS share sheet and provides a QR fallback
// when the share sheet is unavailable or the user prefers it.
//
// Rules:
//   • The service NEVER auto-sends an invite; it only opens the system share
//     sheet (§14.2 — user is always in the loop).
//   • If [shareLinkViaSheet] is called without a share adapter (e.g. in tests
//     or on platforms without native share), it returns false and records
//     that the QR fallback should be shown.
//   • [buildQrPayload] returns the exact UTF-8 string to embed in the QR; the
//     UI layer is responsible for rendering it.

/// Result of a share-sheet invocation attempt.
enum ShareOutcome {
  /// OS share sheet was presented; result unknown (user may cancel).
  presented,

  /// Share sheet is unavailable on this platform; show QR fallback.
  qrFallback,
}

/// Injectable adapter so tests can observe calls without native OS dependency.
abstract class ShareAdapter {
  /// Opens the OS share sheet with [text].  Returns true if the sheet was
  /// presented successfully.
  Future<bool> share(String text);
}

/// [InviteShareService] is the coordinator for §6.7.3 and §6.7.4.
class InviteShareService {
  final ShareAdapter? _adapter;

  /// If [adapter] is null the service will always fall back to QR.
  const InviteShareService({ShareAdapter? adapter}) : _adapter = adapter;

  /// Attempts to open the OS share sheet with [inviteLink].
  ///
  /// Returns [ShareOutcome.presented] on success and
  /// [ShareOutcome.qrFallback] when the share sheet is unavailable.
  Future<ShareOutcome> shareLinkViaSheet(String inviteLink) async {
    if (_adapter == null) return ShareOutcome.qrFallback;
    final ok = await _adapter.share(inviteLink);
    return ok ? ShareOutcome.presented : ShareOutcome.qrFallback;
  }

  /// Returns the exact QR payload string for [inviteLink].
  ///
  /// The payload is the raw invite link, which is already URL-safe (base64url
  /// without padding).  The UI layer should render this as a QR code.
  String buildQrPayload(String inviteLink) => inviteLink;
}
