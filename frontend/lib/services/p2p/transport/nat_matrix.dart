// §4.1 NAT type matrix.
//
// Classifies NAT types and determines whether a TURN relay is required for a
// given pair of NAT types according to the RFC 5780 NAT classification.

/// The four NAT types from RFC 5780 / ICE terminology.
enum NatType {
  /// Full-cone (least restrictive — any external endpoint can send in).
  fullCone,

  /// Address-restricted cone.
  addressRestrictedCone,

  /// Port-restricted cone.
  portRestrictedCone,

  /// Symmetric (most restrictive — different mapping per remote endpoint).
  symmetric,
}

/// Static helpers for NAT pairing analysis.
class NatMatrix {
  NatMatrix._();

  /// Returns `true` when the combination of [a] and [b] requires a TURN relay
  /// to achieve connectivity.
  ///
  /// Only symmetric×symmetric requires guaranteed TURN; every other pairing
  /// can succeed via server-reflexive (STUN) candidates.
  static bool requiresTurn(NatType a, NatType b) {
    return a == NatType.symmetric && b == NatType.symmetric;
  }
}
