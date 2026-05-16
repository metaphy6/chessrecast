/// Perfect-negotiation pattern for WebRTC offer/answer collision.
///
/// §4.7 — When both peers simultaneously create an offer (collision), one
/// must roll back (polite) and one must keep its offer (impolite).
/// Roles are derived deterministically from the lexicographic comparison of
/// each device's DTLS fingerprint, so no explicit role exchange is needed.
library;

enum NegotiationRole { polite, impolite }

enum OfferCollisionDecision { keepOffer, rollback }

class PerfectNegotiation {
  const PerfectNegotiation._();

  /// Determine this device's negotiation role.
  ///
  /// The device with the lexicographically **lower** fingerprint is *polite*
  /// (rolls back on collision); the device with the higher fingerprint is
  /// *impolite* (keeps its offer on collision).
  static NegotiationRole determineRole({
    required String myFingerprint,
    required String peerFingerprint,
  }) {
    return myFingerprint.compareTo(peerFingerprint) < 0
        ? NegotiationRole.polite
        : NegotiationRole.impolite;
  }
}

class PerfectNegotiationState {
  final NegotiationRole role;

  const PerfectNegotiationState({required this.role});

  /// Called when a simultaneous offer collision is detected.
  OfferCollisionDecision onSimultaneousOffer() =>
      role == NegotiationRole.impolite
          ? OfferCollisionDecision.keepOffer
          : OfferCollisionDecision.rollback;
}
