// ignore_for_file: constant_identifier_names

/// Late-join / reconnect (§7 bullet-4).
///
/// A peer rejoining mid-game synchronises via a CRDT-style move log
/// with Lamport-clock-tagged moves. Conflicts (impossible if protocol
/// is correct) end the session.
library;

const String kLamportConflict = 'LAMPORT_CONFLICT'; // F-LATEJOIN-001

/// A move tagged with a Lamport clock value.
class LamportMove {
  final int lamportClock;
  final String uciMove;
  final String boardStateHash;

  const LamportMove({
    required this.lamportClock,
    required this.uciMove,
    required this.boardStateHash,
  });
}

/// CRDT-style move log for late-join synchronisation.
///
/// Lamport clock: each move increments the local clock by 1; on receiving
/// a remote move the clock becomes max(local, remote) + 1.
class LateJoinMoveLog {
  int _lamportClock = 0;
  final List<LamportMove> _log = [];

  int get lamportClock => _lamportClock;
  List<LamportMove> get log => List.unmodifiable(_log);

  /// Record a local move. Returns the Lamport clock value assigned.
  int recordLocal(String uciMove, String boardStateHash) {
    _lamportClock++;
    _log.add(LamportMove(
      lamportClock: _lamportClock,
      uciMove: uciMove,
      boardStateHash: boardStateHash,
    ));
    return _lamportClock;
  }

  /// Receive a remote move log segment.
  ///
  /// Returns [kLamportConflict] if a conflict is detected, null otherwise.
  String? receiveRemoteLog(List<LamportMove> remoteMoves) {
    for (final remote in remoteMoves) {
      // Update Lamport clock.
      if (remote.lamportClock > _lamportClock) {
        _lamportClock = remote.lamportClock + 1;
      }

      // Check if this move is already in our log.
      final existing = _log.where((m) => m.lamportClock == remote.lamportClock);
      if (existing.isNotEmpty) {
        // Conflict if same clock position has different move.
        if (existing.first.uciMove != remote.uciMove) {
          return kLamportConflict;
        }
        // Otherwise already known — skip.
        continue;
      }

      _log.add(remote);
    }

    // Sort log by Lamport clock.
    _log.sort((a, b) => a.lamportClock.compareTo(b.lamportClock));
    return null;
  }

  /// Produce a back-fill snapshot from [fromClock] onwards (inclusive).
  List<LamportMove> backfillFrom(int fromClock) {
    return _log.where((m) => m.lamportClock >= fromClock).toList();
  }
}
