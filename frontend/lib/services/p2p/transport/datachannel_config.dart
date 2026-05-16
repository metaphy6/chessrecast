/// DataChannel configuration for chess and clock channels.
///
/// §4.2 — Two negotiated DataChannels are pre-agreed out-of-band via
/// the signaling layer so that both sides create them simultaneously
/// using the same id, avoiding the in-band negotiation round-trip.
library;

/// Immutable specification for a single DataChannel.
class DataChannelSpec {
  final String label;
  final int id;

  /// Whether messages are delivered in-order (SCTP ordered stream).
  final bool ordered;

  /// Whether this channel was agreed out-of-band (negotiated=true skips
  /// the in-band negotiation exchange).
  final bool negotiated;

  /// Maximum number of retransmissions before the message is dropped.
  /// `null` means the channel is fully reliable (no retransmit limit).
  final int? maxRetransmits;

  const DataChannelSpec({
    required this.label,
    required this.id,
    required this.ordered,
    required this.negotiated,
    this.maxRetransmits,
  });
}

/// Pre-agreed DataChannel configurations.
///
/// `chess` — reliable, ordered, used for moves and game state.
/// `clock` — unreliable, unordered; latest-wins for clock sync ticks.
class DataChannelConfig {
  static const DataChannelSpec chess = DataChannelSpec(
    label: 'chess',
    id: 1,
    ordered: true,
    negotiated: true,
    // null = reliable (no maxRetransmits limit)
    maxRetransmits: null,
  );

  static const DataChannelSpec clock = DataChannelSpec(
    label: 'clock',
    id: 2,
    ordered: false,
    negotiated: true,
    maxRetransmits: 0, // 0 = drop immediately on congestion; fire-and-forget
  );

  const DataChannelConfig._();
}
