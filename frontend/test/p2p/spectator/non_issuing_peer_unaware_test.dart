// §7.8.1 non-issuing peer unaware of spectators proof test.
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/spectator/spectator_topology.dart';

void main() {
  group('Non-issuing peer unaware §7.8.1', () {
    test('non-issuing peer spectators list is always empty', () {
      final topo = SpectatorTopology(localRole: PeerRole.nonIssuing);
      expect(topo.spectatorPubKeys, isEmpty);
    });

    test('non-issuing peer throws on addSpectator', () {
      final topo = SpectatorTopology(localRole: PeerRole.nonIssuing);
      final ch = SpectatorChannel(
        spectatorPubKey: Uint8List.fromList(List.generate(32, (i) => i + 1)),
      );
      expect(() => topo.addSpectator(ch), throwsStateError);
    });

    test('non-issuing peer cannot see spectator identities', () {
      final issuing = SpectatorTopology(localRole: PeerRole.issuing);
      final non = SpectatorTopology(localRole: PeerRole.nonIssuing);
      issuing.addSpectator(SpectatorChannel(
        spectatorPubKey: Uint8List.fromList(List.generate(32, (i) => i + 5)),
      ));
      expect(non.spectatorPubKeys, isEmpty);
    });
  });
}
