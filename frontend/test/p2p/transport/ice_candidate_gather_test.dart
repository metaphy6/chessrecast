// Tests for IceConfig — §4.1 Wire ICE proof test.
//
// Verifies: exactly 1 STUN server + 2 TURN servers (UDP + TCP/443),
// credential threading, and TURNS url structure.
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/transport/ice_config.dart';

void main() {
  group('IceConfig §4.1', () {
    test('build() yields exactly 1 STUN server', () {
      final cfg = IceConfig.build();
      expect(cfg.stunCount, equals(1));
    });

    test('build() yields exactly 2 TURN servers', () {
      final cfg = IceConfig.build();
      expect(cfg.turnCount, equals(2));
    });

    test('TURN servers include UDP variant on port 3478', () {
      final cfg = IceConfig.build();
      expect(cfg.hasUdpTurn, isTrue);
    });

    test('TURN servers include TCP/443 variant', () {
      final cfg = IceConfig.build();
      expect(cfg.hasTcpTurn443, isTrue);
    });

    test('TURN credentials are threaded to every TURN server', () {
      final cfg =
          IceConfig.build(turnUsername: 'u1', turnCredential: 'p1');
      final turns = cfg.servers.where((s) => s.isTurn).toList();
      expect(turns, isNotEmpty);
      for (final t in turns) {
        expect(t.username, equals('u1'));
        expect(t.credential, equals('p1'));
      }
    });

    test('build() returns static credentials when provided', () {
      final cfg = IceConfig.build(
          turnUsername: 'exp:alice', turnCredential: 'hmac-password');
      expect(cfg.servers.where((s) => s.isTurn).every((s) =>
          s.username != null && s.credential != null), isTrue);
    });

    test('STUN server has no credentials', () {
      final cfg = IceConfig.build(
          turnUsername: 'u', turnCredential: 'p');
      final stuns = cfg.servers.where((s) => s.isStun).toList();
      expect(stuns.every((s) => s.username == null && s.credential == null),
          isTrue);
    });

    test('server count total is exactly 3', () {
      final cfg = IceConfig.build();
      expect(cfg.servers.length, equals(3));
    });

    test('TURNS url list is a proper superset when withTurns=true', () {
      final base = IceConfig.build();
      final withTurns =
          IceConfig.build(includeTurns: true);
      expect(withTurns.servers.length,
          greaterThan(base.servers.length));
      expect(withTurns.turnsCount, greaterThan(0));
    });
  });
}
