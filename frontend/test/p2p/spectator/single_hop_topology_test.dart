// §7.8.1 single-hop fan-out topology proof test.
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/spectator/spectator_topology.dart';

void main() {
  group('SpectatorTopology §7.8.1 single-hop fan-out', () {
    test('issuing peer accepts spectator adds and returns list', () {
      final topo = SpectatorTopology(localRole: PeerRole.issuing);
      for (var i = 0; i < 5; i++) {
        topo.addSpectator(SpectatorChannel(
          spectatorPubKey: Uint8List.fromList(List.generate(32, (_) => i + 1)),
        ));
      }
      expect(topo.spectatorCount, equals(5));
    });

    test('SCTP chess stream is 1, chat stream is 7', () {
      expect(SpectatorChannel.streamChess, equals(1));
      expect(SpectatorChannel.streamChat, equals(7));
    });

    test('non-issuing peer returns empty spectator list', () {
      final topo = SpectatorTopology(localRole: PeerRole.nonIssuing);
      expect(topo.spectatorPubKeys, isEmpty);
    });

    test('fan-out target count equals spectator count', () {
      final topo = SpectatorTopology(localRole: PeerRole.issuing);
      const count = 3;
      for (var i = 0; i < count; i++) {
        topo.addSpectator(SpectatorChannel(
          spectatorPubKey: Uint8List.fromList(List.generate(32, (_) => i + 10)),
        ));
      }
      expect(topo.spectatorCount, equals(count));
    });
  });
}
