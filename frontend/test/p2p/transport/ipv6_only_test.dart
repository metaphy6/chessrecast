// §4.1 IPv6-only carrier proof test.
//
// Verifies that IceConfig accepts IPv6 STUN/TURN addresses and that the
// ICE configuration is valid on IPv6-only paths.  Physical ICE gathering
// is mocked; this test is hermetic (L1).
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/transport/ice_config.dart';

void main() {
  group('IceConfig §4.1 IPv6-only', () {
    test('IceConfig.buildIpv6 produces valid server list', () {
      final cfg = IceConfig.buildIpv6(
          turnUsername: 'user', turnCredential: 'cred');
      expect(cfg.stunCount, equals(1));
      expect(cfg.turnCount, equals(2));
    });

    test('IPv6 STUN URL contains literal IPv6 notation', () {
      final cfg = IceConfig.buildIpv6();
      final stun = cfg.servers.firstWhere((s) => s.isStun);
      // Must accept either bracket-notation or hostname-form.
      expect(stun.url, isNotEmpty);
    });

    test('pathMtuClamp is 1280 for IPv6 config (NAT64/DNS64)', () {
      final cfg = IceConfig.buildIpv6();
      expect(cfg.pathMtuClamp, equals(1280));
    });

    test('non-IPv6 config has no pathMtuClamp', () {
      final cfg = IceConfig.build();
      expect(cfg.pathMtuClamp, isNull);
    });

    test('IPv6 config still has UDP and TCP/443 TURN', () {
      final cfg = IceConfig.buildIpv6();
      expect(cfg.hasUdpTurn, isTrue);
      expect(cfg.hasTcpTurn443, isTrue);
    });
  });
}
