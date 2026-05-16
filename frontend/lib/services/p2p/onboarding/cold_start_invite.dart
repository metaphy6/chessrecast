// §6.7.5 Cold-start deep-link: onboarding first, then honour invite.
//
// When the app is launched via an invite deep-link before the user has
// completed onboarding, the flow must:
//   1. Store the pending invite link (persist via SecureStorage simulation).
//   2. Route the user through the 4-screen onboarding wizard first.
//   3. After onboarding completes, redeem the stored invite link automatically.
//   4. Guarantee that the link survives a simulated process restart (cold start).
//
// This class simulates the SecureStorage layer with a simple in-memory map
// so the test can run without native platform channels.

import '../invites/invite_link_generator.dart';
import '../onboarding/p2p_onboarding.dart';

/// Result of attempting to redeem a pending invite link.
enum InviteRedemptionResult {
  /// Invite link was redeemed and handed to the caller.
  redeemed,

  /// No pending invite link was found.
  noPendingLink,

  /// Onboarding has not been completed yet; link is still pending.
  onboardingRequired,
}

/// Manages the cold-start deep-link flow for §6.7.5.
///
/// In production, [_storage] would be backed by flutter_secure_storage; here
/// it is an in-memory map so tests are hermetic.
class ColdStartInviteFlow {
  final Map<String, String> _storage;
  final P2pOnboardingState _onboarding;

  static const _storageKey = 'pending_invite_link';

  ColdStartInviteFlow({
    required Map<String, String> storage,
    required P2pOnboardingState onboarding,
  })  : _storage = storage,
        _onboarding = onboarding;

  /// Stores [inviteLink] as a pending deep-link.  Call this when the app is
  /// launched with an invite URL before the session is established.
  void storePendingLink(String inviteLink) {
    _storage[_storageKey] = inviteLink;
  }

  /// Returns `true` when there is a stored invite link waiting to be redeemed.
  bool get hasPendingLink => _storage.containsKey(_storageKey);

  /// Attempts to redeem the stored invite link.
  ///
  /// Returns [InviteRedemptionResult.onboardingRequired] if onboarding is not
  /// yet complete, leaving the link in storage.
  ///
  /// Returns [InviteRedemptionResult.redeemed] and clears the stored link when
  /// onboarding is complete and a link is present.
  ///
  /// Returns [InviteRedemptionResult.noPendingLink] when nothing is stored.
  ({InviteRedemptionResult result, String? link}) tryRedeem() {
    if (!hasPendingLink) {
      return (result: InviteRedemptionResult.noPendingLink, link: null);
    }
    if (!_onboarding.isOnboardingComplete) {
      return (result: InviteRedemptionResult.onboardingRequired, link: null);
    }
    final link = _storage.remove(_storageKey)!;
    return (result: InviteRedemptionResult.redeemed, link: link);
  }

  /// Extracts the pubkey embedded in [token] without server validation.
  /// Useful for displaying "invited by …" UI before network is available.
  String? extractInviterHint(String token) {
    try {
      const secret = <int>[];
      final gen = InviteLinkGenerator(hmacSecret: secret);
      final pk = gen.extractPubkey(token);
      // Return first 8 bytes as hex hint (not a secret).
      return pk.take(8).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    } catch (_) {
      return null;
    }
  }
}
