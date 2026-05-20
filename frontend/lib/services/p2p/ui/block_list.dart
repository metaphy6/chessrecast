// §14.1 — Per-device opponent block-list.
//
// Blocks are keyed by device fingerprint (§2.1).  Blocking a device prevents
// future matches and silently drops incoming chat (no notification to sender).
// An optional account-level block survives device rebind.
//
// The block list is local-only (no server reporting).  Users can review and
// unblock at any time.
library;

/// Type of block applied to an opponent.
enum BlockKind {
  /// Block only the specific device fingerprint (cleared on rebind).
  device,

  /// Block the account fingerprint; survives opponent's device replacement.
  account,
}

/// Reason a session was ended mid-game due to a block action.
const String kBlockByeReason = 'user_blocked';

/// Immutable record of a single block entry.
final class BlockEntry {
  const BlockEntry({
    required this.fingerprint,
    required this.kind,
    required this.addedAt,
  });

  /// The blocked device or account fingerprint (hex string).
  final String fingerprint;

  /// Whether this is a device-level or account-level block.
  final BlockKind kind;

  /// When the block was added (UTC).
  final DateTime addedAt;
}

/// In-memory block list with O(1) lookup via a hash set.
///
/// Persistence (to SQLCipher per §0.6) is the caller's responsibility; this
/// class manages the in-memory representation and lookup semantics only.
final class BlockList {
  final Set<String> _blocked = {};
  final List<BlockEntry> _entries = [];

  /// Number of entries currently in the block list.
  int get length => _entries.length;

  /// Returns `true` when [fingerprint] is currently blocked.
  ///
  /// Complexity: O(1) average-case (hash set lookup).
  bool isBlocked(String fingerprint) => _blocked.contains(fingerprint);

  /// Add [fingerprint] to the block list.
  ///
  /// A duplicate add is idempotent (no-op if already blocked).
  void block(
    String fingerprint, {
    BlockKind kind = BlockKind.device,
    DateTime? addedAt,
  }) {
    if (_blocked.add(fingerprint)) {
      _entries.add(
        BlockEntry(
          fingerprint: fingerprint,
          kind: kind,
          addedAt: addedAt ?? DateTime.now().toUtc(),
        ),
      );
    }
  }

  /// Remove [fingerprint] from the block list.
  ///
  /// Returns `true` if the entry was present and removed.
  bool unblock(String fingerprint) {
    if (_blocked.remove(fingerprint)) {
      _entries.removeWhere((e) => e.fingerprint == fingerprint);
      return true;
    }
    return false;
  }

  /// All current block entries (unmodifiable snapshot).
  List<BlockEntry> get entries => List.unmodifiable(_entries);

  /// Populate this list from a serialised [entries] list (e.g. from SQLCipher).
  ///
  /// Existing entries are cleared first.
  void loadFrom(List<BlockEntry> entries) {
    _blocked.clear();
    _entries.clear();
    for (final e in entries) {
      if (_blocked.add(e.fingerprint)) {
        _entries.add(e);
      }
    }
  }
}
