// §4.7 DataChannel re-establishment proof test.
//
// Verifies that after a hard ICE restart, DataChannels are recreated
// with the same labels/ids and that an in-flight CHESS_MOVE is
// queued and retransmitted once the channel is re-open.
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/transport/datachannel_config.dart';
import '../../../lib/services/p2p/transport/datachannel_reestablish.dart';

void main() {
  group('DataChannel re-establishment §4.7', () {
    test('reestablished chess channel has same label and id', () {
      final mgr = DataChannelReestablish();
      mgr.onChannelClosed(spec: DataChannelConfig.chess);
      final recreated = mgr.pendingRecreations.first;
      expect(recreated.label, equals('chess'));
      expect(recreated.id, equals(1));
    });

    test('in-flight CHESS_MOVE is queued during teardown', () {
      final mgr = DataChannelReestablish();
      mgr.onChannelClosed(spec: DataChannelConfig.chess);
      mgr.onInFlightMessage(message: [0x01, 0x02, 0x03]);
      expect(mgr.pendingMessages.length, equals(1));
    });

    test('queued messages are flushed once channel re-opens', () {
      final mgr = DataChannelReestablish();
      mgr.onChannelClosed(spec: DataChannelConfig.chess);
      mgr.onInFlightMessage(message: [0x01]);
      mgr.onInFlightMessage(message: [0x02]);
      mgr.onChannelOpened(spec: DataChannelConfig.chess);
      expect(mgr.pendingMessages, isEmpty);
      expect(mgr.flushedCount, equals(2));
    });

    test('clock channel is also reestablished after ICE restart', () {
      final mgr = DataChannelReestablish();
      mgr.onChannelClosed(spec: DataChannelConfig.clock);
      expect(mgr.pendingRecreations.first.label, equals('clock'));
    });
  });
}
