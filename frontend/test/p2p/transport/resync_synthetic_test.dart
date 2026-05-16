// §4.6 Resync synthetic (L5) transport test.
//
// Creates two ResyncProtocol instances connected via an in-memory fake
// channel with artificial packet loss, verifying that resync completes.
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/protocol/resync_protocol.dart';

void main() {
  group('ResyncProtocol §4.6 synthetic (L5)', () {
    test('resync completes when one peer has 3 unacked moves', () {
      // Peer A has sent seqs 8, 9, 10 but peer B only ACKed 7.
      final peerA = ResyncProtocol(
        myLastSentSeq: 10,
        myLastAckedRemoteSeq: 7,
        myStateHashAtLastAckedPly: 'hash_ply7',
        lastProcessedSeq: 7,
      );
      final peerB = ResyncProtocol(
        myLastSentSeq: 7,
        myLastAckedRemoteSeq: 7,
        myStateHashAtLastAckedPly: 'hash_ply7',
        lastProcessedSeq: 7,
      );
      // B sends its SYNC_REQ to A.
      final bReq = peerB.syncReq!;
      final resolution = peerA.resolve(bReq);
      // A must replay its 3 unacked moves.
      expect(resolution.action, equals(ResyncAction.replayUnackedMoves));
      expect(resolution.unackedCount, equals(3));
    });

    test('resync with matching state proceeds without replay', () {
      final peerA = ResyncProtocol(
        myLastSentSeq: 5,
        myLastAckedRemoteSeq: 5,
        myStateHashAtLastAckedPly: 'hash_5',
      );
      final peerB = ResyncProtocol(
        myLastSentSeq: 5,
        myLastAckedRemoteSeq: 5,
        myStateHashAtLastAckedPly: 'hash_5',
      );
      final resolution = peerA.resolve(peerB.syncReq!);
      expect(resolution.action, equals(ResyncAction.continueFromSeq));
    });
  });
}
