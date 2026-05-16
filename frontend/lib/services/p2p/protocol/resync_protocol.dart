/// Resync protocol state machine.
///
/// §4.6 — When an ICE restart happens mid-game, both peers may have sent
/// moves that the other side has not yet acknowledged.  The resync
/// protocol determines who replays what, and detects divergent state.
library;

enum ResyncAction {
  replayUnackedMoves,
  continueFromSeq,
  mismatch,
}

enum MoveReceiveResult {
  applied,
  alreadySeen,
  outOfSequence,
}

class SyncReq {
  final int lastSentSeq;
  final int lastAckedRemoteSeq;
  final String stateHashAtLastAckedPly;

  const SyncReq({
    required this.lastSentSeq,
    required this.lastAckedRemoteSeq,
    required this.stateHashAtLastAckedPly,
  });
}

class ResyncResolution {
  final ResyncAction action;

  /// Number of unacked moves to replay (only meaningful for [ResyncAction.replayUnackedMoves]).
  final int unackedCount;

  /// Sequence number to continue from (only meaningful for [ResyncAction.continueFromSeq]).
  final int? continueFromSeq;

  const ResyncResolution._({
    required this.action,
    this.unackedCount = 0,
    this.continueFromSeq,
  });
}

class ResyncProtocol {
  final int myLastSentSeq;
  final int myLastAckedRemoteSeq;
  final String myStateHashAtLastAckedPly;
  final int startedAtMs;

  int _lastProcessedSeq;
  bool _timedOut = false;
  String? _timeoutReason;

  ResyncProtocol({
    required this.myLastSentSeq,
    required this.myLastAckedRemoteSeq,
    required this.myStateHashAtLastAckedPly,
    int? lastProcessedSeq,
    this.startedAtMs = 0,
  }) : _lastProcessedSeq = lastProcessedSeq ?? myLastAckedRemoteSeq;

  int get lastProcessedSeq => _lastProcessedSeq;

  /// True when the ICE restart has just happened and the game state is unknown.
  bool get clocksPaused => true;

  String? get timeoutReason => _timedOut ? _timeoutReason : null;

  /// The SYNC_REQ this peer should send to its counterpart.
  SyncReq get syncReq => SyncReq(
        lastSentSeq: myLastSentSeq,
        lastAckedRemoteSeq: myLastAckedRemoteSeq,
        stateHashAtLastAckedPly: myStateHashAtLastAckedPly,
      );

  /// Check whether the 30-second resync timeout has elapsed.
  bool checkTimeout({required int nowMs}) {
    const timeoutMs = 30000;
    if (nowMs - startedAtMs > timeoutMs) {
      _timedOut = true;
      _timeoutReason = 'RESYNC_TIMEOUT';
      return true;
    }
    return false;
  }

  /// Determine the resolution given the peer's [SyncReq].
  ResyncResolution resolve(SyncReq peer) {
    // Common ply is the minimum of what both sides have ACKed from the other.
    final commonSeq = myLastAckedRemoteSeq < peer.lastAckedRemoteSeq
        ? myLastAckedRemoteSeq
        : peer.lastAckedRemoteSeq;

    // Hash mismatch at the common ply → divergence.
    if (myStateHashAtLastAckedPly != peer.stateHashAtLastAckedPly) {
      return const ResyncResolution._(action: ResyncAction.mismatch);
    }

    // If I have more sent moves than peer has ACKed, I must replay them.
    final myUnacked = myLastSentSeq - commonSeq;
    if (myUnacked > 0) {
      return ResyncResolution._(
        action: ResyncAction.replayUnackedMoves,
        unackedCount: myUnacked,
      );
    }

    // Both in sync.
    return ResyncResolution._(
      action: ResyncAction.continueFromSeq,
      continueFromSeq: commonSeq,
    );
  }

  /// Process an incoming move from the remote peer.
  MoveReceiveResult receiveMove({required int seq}) {
    if (seq <= _lastProcessedSeq) return MoveReceiveResult.alreadySeen;
    if (seq > _lastProcessedSeq + 1) return MoveReceiveResult.outOfSequence;
    _lastProcessedSeq = seq;
    return MoveReceiveResult.applied;
  }
}
