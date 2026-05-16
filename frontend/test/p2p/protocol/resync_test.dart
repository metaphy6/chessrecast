// §4.6 Mid-game resync protocol proof test.
//
// Tests the ResyncProtocol state machine:
//   - SYNC_REQ emission on ICE restart
//   - resolution: replay unacked moves, hash comparison
//   - hard 30 s timeout → RESYNC_TIMEOUT
//   - clock pause/resume
//   - move idempotency (already-seen seq silently re-acked)
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/protocol/resync_protocol.dart';

void main() {
  group('ResyncProtocol §4.6 trigger', () {
    test('SYNC_REQ is emitted when ICE restart is detected', () {
      final protocol = ResyncProtocol(
        myLastSentSeq: 10,
        myLastAckedRemoteSeq: 8,
        myStateHashAtLastAckedPly: 'hash_a',
      );
      expect(protocol.syncReq, isNotNull);
      expect(protocol.syncReq!.lastSentSeq, equals(10));
      expect(protocol.syncReq!.lastAckedRemoteSeq, equals(8));
    });
  });

  group('ResyncProtocol §4.6 resolution', () {
    test('peer with more state replays unacked moves', () {
      final protocol = ResyncProtocol(
        myLastSentSeq: 10,
        myLastAckedRemoteSeq: 8,
        myStateHashAtLastAckedPly: 'hash_a',
      );
      final peerReq = SyncReq(
        lastSentSeq: 7,
        lastAckedRemoteSeq: 6,
        stateHashAtLastAckedPly: 'hash_a',
      );
      final resolution = protocol.resolve(peerReq);
      expect(resolution.action, equals(ResyncAction.replayUnackedMoves));
    });

    test('hash mismatch at common ply → MISMATCH', () {
      final protocol = ResyncProtocol(
        myLastSentSeq: 10,
        myLastAckedRemoteSeq: 8,
        myStateHashAtLastAckedPly: 'hash_a',
      );
      final peerReq = SyncReq(
        lastSentSeq: 10,
        lastAckedRemoteSeq: 8,
        stateHashAtLastAckedPly: 'hash_DIFFERENT',
      );
      final resolution = protocol.resolve(peerReq);
      expect(resolution.action, equals(ResyncAction.mismatch));
    });

    test('equal state → game continues from higher seq', () {
      final protocol = ResyncProtocol(
        myLastSentSeq: 10,
        myLastAckedRemoteSeq: 10,
        myStateHashAtLastAckedPly: 'hash_same',
      );
      final peerReq = SyncReq(
        lastSentSeq: 10,
        lastAckedRemoteSeq: 10,
        stateHashAtLastAckedPly: 'hash_same',
      );
      final resolution = protocol.resolve(peerReq);
      expect(resolution.action, equals(ResyncAction.continueFromSeq));
      expect(resolution.continueFromSeq, equals(10));
    });
  });

  group('ResyncProtocol §4.6 timeout', () {
    test('RESYNC_TIMEOUT after 30 s', () {
      final protocol = ResyncProtocol(
        myLastSentSeq: 0,
        myLastAckedRemoteSeq: 0,
        myStateHashAtLastAckedPly: 'h',
        startedAtMs: 0,
      );
      final timedOut = protocol.checkTimeout(nowMs: 30001);
      expect(timedOut, isTrue);
      expect(protocol.timeoutReason, equals('RESYNC_TIMEOUT'));
    });

    test('no timeout before 30 s elapses', () {
      final protocol = ResyncProtocol(
        myLastSentSeq: 0,
        myLastAckedRemoteSeq: 0,
        myStateHashAtLastAckedPly: 'h',
        startedAtMs: 0,
      );
      expect(protocol.checkTimeout(nowMs: 29999), isFalse);
    });
  });

  group('ResyncProtocol §4.6 clock handling', () {
    test('clocks pause when ICE goes disconnected', () {
      final protocol = ResyncProtocol(
        myLastSentSeq: 5,
        myLastAckedRemoteSeq: 5,
        myStateHashAtLastAckedPly: 'h',
      );
      expect(protocol.clocksPaused, isTrue);
    });
  });

  group('ResyncProtocol §4.6 idempotency', () {
    test('already-processed seq is silently re-acked, not re-applied', () {
      final protocol = ResyncProtocol(
        myLastSentSeq: 10,
        myLastAckedRemoteSeq: 10,
        myStateHashAtLastAckedPly: 'h',
        lastProcessedSeq: 10,
      );
      final result = protocol.receiveMove(seq: 8);
      expect(result, equals(MoveReceiveResult.alreadySeen));
    });

    test('new seq is applied normally', () {
      final protocol = ResyncProtocol(
        myLastSentSeq: 10,
        myLastAckedRemoteSeq: 10,
        myStateHashAtLastAckedPly: 'h',
        lastProcessedSeq: 10,
      );
      final result = protocol.receiveMove(seq: 11);
      expect(result, equals(MoveReceiveResult.applied));
    });
  });
}
