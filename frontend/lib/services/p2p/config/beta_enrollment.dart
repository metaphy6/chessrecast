// §6.1.2 Beta-enrollment configuration.
//
// Centralises the beta programme parameters: min invitee count, region
// requirements, invite code TTL, and supported distribution channels.
class BetaEnrollment {
  BetaEnrollment._();

  /// Minimum number of beta invitees required before opening the closed beta.
  static const int minInvitees = 100;

  /// Minimum number of geographic regions that must be represented in the
  /// invitee pool before the closed beta is considered geographically diverse.
  static const int minRegions = 2;

  /// Invite code time-to-live (seconds). Codes older than this are expired.
  static const int inviteCodeTtlSeconds = 7 * 24 * 3600; // 7 days

  /// Beta distribution channels supported. Used for store-listing copy and
  /// in-app "join beta" deep-links.
  static const List<String> channels = [
    'testflight',
    'play_internal',
  ];

  /// Returns `true` when both the invitee count and region count meet or
  /// exceed the minimum thresholds for opening the closed beta.
  static bool isBetaThresholdMet({
    required int inviteeCount,
    required int regionCount,
  }) {
    return inviteeCount >= minInvitees && regionCount >= minRegions;
  }
}
