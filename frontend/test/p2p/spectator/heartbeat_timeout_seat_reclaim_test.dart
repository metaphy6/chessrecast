// §7.8.6 heartbeat timeout seat reclaim proof test.
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/spectator/spectator_heartbeat.dart';

void main() {
  group('SpectatorHeartbeatManager §7.8.6', () {
    test('registered spectator not evicted when heartbeat received in time', () {
      final mgr = SpectatorHeartbeatManager();
      final key = Uint8List.fromList(List.generate(32, (i) => i + 1));
      mgr.registerSpectator(spectatorPubKey: key, nowMs: 0);
      mgr.onHeartbeat(spectatorPubKey: key, nowMs: 100);
      final evict = mgr.evictionCandidates(200);
      expect(evict, isEmpty);
    });

    test('eviction candidate after 2 missed beats', () {
      final mgr = SpectatorHeartbeatManager();
      final key = Uint8List.fromList(List.generate(32, (i) => i + 5));
      mgr.registerSpectator(spectatorPubKey: key, nowMs: 0);
      // Advance past 2 heartbeat intervals without calling onHeartbeat.
      final futureMs = SpectatorHeartbeatTracker.heartbeatIntervalMs *
          (SpectatorHeartbeatTracker.missedToEvict + 1);
      final evict = mgr.evictionCandidates(futureMs);
      expect(evict.length, equals(1));
    });

    test('heartbeat interval is 30 s', () {
      expect(SpectatorHeartbeatTracker.heartbeatIntervalMs, equals(30000));
    });

    test('missed beats to evict is 2', () {
      expect(SpectatorHeartbeatTracker.missedToEvict, equals(2));
    });

    test('error code is SPECTATOR_HEARTBEAT_TIMEOUT', () {
      expect(kSpectatorHeartbeatTimeout, equals('SPECTATOR_HEARTBEAT_TIMEOUT'));
    });
  });
}
