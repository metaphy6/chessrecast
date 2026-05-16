// §4.6 Move idempotency proof test.
//
// Already-processed seq values must be silently re-acked (never re-applied).
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/protocol/resync_protocol.dart';

void main() {
  group('Move idempotency §4.6', () {
    test('seq < last_processed is alreadySeen', () {
      final proto = ResyncProtocol(
        myLastSentSeq: 10,
        myLastAckedRemoteSeq: 10,
        myStateHashAtLastAckedPly: 'h',
        lastProcessedSeq: 10,
      );
      expect(proto.receiveMove(seq: 5), equals(MoveReceiveResult.alreadySeen));
      expect(proto.receiveMove(seq: 10), equals(MoveReceiveResult.alreadySeen));
    });

    test('seq == last_processed + 1 is applied', () {
      final proto = ResyncProtocol(
        myLastSentSeq: 10,
        myLastAckedRemoteSeq: 10,
        myStateHashAtLastAckedPly: 'h',
        lastProcessedSeq: 10,
      );
      expect(proto.receiveMove(seq: 11), equals(MoveReceiveResult.applied));
    });

    test('applying seq 11 advances lastProcessedSeq to 11', () {
      final proto = ResyncProtocol(
        myLastSentSeq: 10,
        myLastAckedRemoteSeq: 10,
        myStateHashAtLastAckedPly: 'h',
        lastProcessedSeq: 10,
      );
      proto.receiveMove(seq: 11);
      expect(proto.lastProcessedSeq, equals(11));
    });

    test('seq > lastProcessed + 1 is out-of-sequence (not applied)', () {
      final proto = ResyncProtocol(
        myLastSentSeq: 10,
        myLastAckedRemoteSeq: 10,
        myStateHashAtLastAckedPly: 'h',
        lastProcessedSeq: 10,
      );
      expect(proto.receiveMove(seq: 15), equals(MoveReceiveResult.outOfSequence));
    });
  });
}
