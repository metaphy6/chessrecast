// §14.3 — Client-side abuse report builder.
//
// Constructs the signed report bundle that is uploaded to the operator's
// review queue with explicit user consent.  The upload itself is handled by
// the transport layer; this class manages bundle composition and validation.
library;

/// Reason codes the reporter selects from the report UI.
enum AbuseReportReason {
  harassment,
  sexualContent,
  threats,
  cheatingSuspicion,
  other,
}

/// An unsubmitted report bundle ready for user review before upload.
final class AbuseReportBundle {
  const AbuseReportBundle({
    required this.opponentFingerprint,
    required this.reason,
    required this.transcriptHash,
    required this.chatHistoryBytes,
    required this.reporterFingerprintHashed,
    required this.sessionId,
    required this.createdAt,
  });

  /// The reported peer's device fingerprint (hex).
  final String opponentFingerprint;

  /// Reporter-selected reason code.
  final AbuseReportReason reason;

  /// SHA-256 hash of the signed game transcript (`BYE` payload hash).
  final List<int> transcriptHash;

  /// Raw (already end-to-end encrypted at rest) chat history bytes.
  final List<int> chatHistoryBytes;

  /// SHA-256 hash of the reporter's account fingerprint (anonymisation layer).
  /// The raw fingerprint is stored separately and revealed only on escalation.
  final List<int> reporterFingerprintHashed;

  /// Session identifier.
  final String sessionId;

  /// Creation timestamp (UTC).
  final DateTime createdAt;

  /// Estimated bundle size in bytes (transcript hash + chat + metadata).
  int get estimatedSizeBytes =>
      transcriptHash.length + chatHistoryBytes.length + 512 /* metadata overhead */;

  /// Returns `true` when the bundle is within the 256 KB upload limit.
  bool get isWithinSizeLimit => estimatedSizeBytes <= 256 * 1024;
}

/// Validates and prepares an [AbuseReportBundle] for upload.
///
/// Throws [AbuseReportTooLargeException] when `estimatedSizeBytes > 256 KB`.
AbuseReportBundle validateBundle(AbuseReportBundle bundle) {
  if (!bundle.isWithinSizeLimit) {
    throw AbuseReportTooLargeException(bundle.estimatedSizeBytes);
  }
  return bundle;
}

/// Thrown when a report bundle exceeds the 256 KB limit (§14.7).
final class AbuseReportTooLargeException implements Exception {
  const AbuseReportTooLargeException(this.actualBytes);
  final int actualBytes;

  @override
  String toString() =>
      'AbuseReportTooLargeException: bundle is $actualBytes bytes '
      '(limit ${256 * 1024} bytes)';
}
