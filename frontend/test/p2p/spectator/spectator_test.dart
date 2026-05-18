// §7 Phase 7 umbrella spectator test — single-hop topology, capacity, auth, heartbeat.
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/spectator/spectator_topology.dart';
import '../../../lib/services/p2p/spectator/spectator_capacity.dart';
import '../../../lib/services/p2p/spectator/spectator_auth.dart';
import '../../../lib/services/p2p/spectator/spectator_heartbeat.dart';
import '../../../lib/services/p2p/spectator/spectator_roster_privacy.dart';

void main() {
  group('Phase 7 spectator umbrella §7.1', () {
    test('issuing peer tracks spectators, non-issuing does not', () {
      final topo = SpectatorTopology(localRole: PeerRole.issuing);
      final pubKey = Uint8List.fromList(List.generate(32, (i) => i + 1));
      final ch = SpectatorChannel(spectatorPubKey: pubKey);
      topo.addSpectator(ch);
      expect(topo.spectatorCount, equals(1));

      final nonTopo = SpectatorTopology(localRole: PeerRole.nonIssuing);
      expect(nonTopo.spectatorPubKeys, isEmpty);
      expect(() => nonTopo.addSpectator(ch), throwsStateError);
    });

    test('SpectatorAuthPolicy rejects anonymous request', () {
      final auth = SpectatorAuthPolicy();
      final req = SpectatorAuthRequest(devicePubKey: null);
      final result = auth.validate(req);
      expect(result, equals('SPECTATOR_AUTH_REQUIRED'));
    });

    test('Capacity default cap is 50', () {
      expect(SpectatorCapacityManager.defaultCap, equals(50));
      expect(SpectatorCapacityManager.hardCeiling, equals(200));
    });

    test('Heartbeat tracker evicts after 2 missed beats', () {
      final mgr = SpectatorHeartbeatManager();
      final key = Uint8List.fromList(List.generate(32, (i) => i + 1));
      mgr.registerSpectator(spectatorPubKey: key, nowMs: 0);
      // Advance past 2 heartbeat intervals.
      final futureMs = SpectatorHeartbeatTracker.heartbeatIntervalMs *
          (SpectatorHeartbeatTracker.missedToEvict + 1);
      final candidates = mgr.evictionCandidates(futureMs);
      expect(candidates.length, equals(1));
    });

    test('Roster privacy: host sees full roster, spectator sees own only', () {
      final roster = SpectatorRosterPrivacy();
      final specKey = Uint8List.fromList(List.generate(32, (i) => i + 2));
      roster.addSpectator(specKey);
      final forHost = roster.viewFor(forIssuingPeer: true);
      expect(forHost.fullRoster.length, equals(1));
      final forSpec = roster.viewFor(
          forIssuingPeer: false, forSpectatorPubKey: specKey);
      expect(forSpec.ownJoinConfirmation, isNotNull);
      final forNonIssuing = roster.viewFor(forIssuingPeer: false);
      expect(forNonIssuing.fullRoster, isEmpty);
      expect(forNonIssuing.ownJoinConfirmation, isNull);
    });
  });
}
