// §7 bullet-4 late-join / reconnect proof test.
import 'package:flutter_test/flutter_test.dart';

import '../../lib/services/p2p/late_join/late_join_sync.dart';

void main() {
  group('LateJoinMoveLog §7 bullet-4', () {
    test('recordLocal increments lamport clock', () {
      final log = LateJoinMoveLog();
      expect(log.lamportClock, equals(0));
      log.recordLocal('e2e4', 'h1');
      expect(log.lamportClock, equals(1));
      log.recordLocal('e7e5', 'h2');
      expect(log.lamportClock, equals(2));
    });

    test('recordLocal returns assigned clock value', () {
      final log = LateJoinMoveLog();
      final c1 = log.recordLocal('e2e4', 'h1');
      expect(c1, equals(1));
      final c2 = log.recordLocal('d2d4', 'h2');
      expect(c2, equals(2));
    });

    test('log is unmodifiable', () {
      final log = LateJoinMoveLog();
      log.recordLocal('e2e4', 'h1');
      expect(() => log.log.add(const LamportMove(
        lamportClock: 999,
        uciMove: 'x',
        boardStateHash: 'y',
      )), throwsUnsupportedError);
    });

    test('receiveRemoteLog merges new moves without conflict', () {
      final log = LateJoinMoveLog();
      log.recordLocal('e2e4', 'h1');
      final remote = [
        const LamportMove(lamportClock: 2, uciMove: 'e7e5', boardStateHash: 'h2'),
        const LamportMove(lamportClock: 3, uciMove: 'd2d4', boardStateHash: 'h3'),
      ];
      final err = log.receiveRemoteLog(remote);
      expect(err, isNull);
      expect(log.log.length, equals(3));
    });

    test('receiveRemoteLog detects conflict', () {
      final log = LateJoinMoveLog();
      log.recordLocal('e2e4', 'h1');
      // Remote claims clock=1 was a different move.
      final remote = [
        const LamportMove(lamportClock: 1, uciMove: 'd2d4', boardStateHash: 'h_x'),
      ];
      final err = log.receiveRemoteLog(remote);
      expect(err, equals('LAMPORT_CONFLICT'));
    });

    test('backfillFrom returns moves from that clock onward', () {
      final log = LateJoinMoveLog();
      log.recordLocal('e2e4', 'h1');
      log.recordLocal('e7e5', 'h2');
      log.recordLocal('d2d4', 'h3');
      final backfill = log.backfillFrom(2);
      expect(backfill.length, equals(2));
      expect(backfill.first.lamportClock, equals(2));
    });

    test('backfillFrom(1) returns all moves', () {
      final log = LateJoinMoveLog();
      log.recordLocal('e2e4', 'h1');
      log.recordLocal('d2d4', 'h2');
      expect(log.backfillFrom(1).length, equals(2));
    });

    test('kLamportConflict constant is LAMPORT_CONFLICT', () {
      expect(kLamportConflict, equals('LAMPORT_CONFLICT'));
    });

    test('receiveRemoteLog advances lamport clock to max+1', () {
      final log = LateJoinMoveLog();
      log.recordLocal('e2e4', 'h1'); // clock=1
      final remote = [
        const LamportMove(lamportClock: 10, uciMove: 'e7e5', boardStateHash: 'hr'),
      ];
      log.receiveRemoteLog(remote);
      expect(log.lamportClock, greaterThan(10));
    });
  });
}
