// §4.2 DataChannel configuration proof test.
//
// Verifies that the two required channels are spec-compliant:
//   chess — ordered, reliable, unlimited retransmits
//   clock — unordered, unreliable, max-retransmits=0
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/transport/datachannel_config.dart';

void main() {
  group('DataChannelConfig §4.2', () {
    test('chess channel is ordered', () {
      expect(DataChannelConfig.chess.ordered, isTrue);
    });

    test('chess channel has unlimited retransmits (reliable)', () {
      expect(DataChannelConfig.chess.maxRetransmits, isNull);
    });

    test('clock channel is unordered', () {
      expect(DataChannelConfig.clock.ordered, isFalse);
    });

    test('clock channel has maxRetransmits=0 (fire-and-forget)', () {
      expect(DataChannelConfig.clock.maxRetransmits, equals(0));
    });

    test('chess channel label is "chess"', () {
      expect(DataChannelConfig.chess.label, equals('chess'));
    });

    test('clock channel label is "clock"', () {
      expect(DataChannelConfig.clock.label, equals('clock'));
    });

    test('chess channel id is 1', () {
      expect(DataChannelConfig.chess.id, equals(1));
    });

    test('clock channel id is 2', () {
      expect(DataChannelConfig.clock.id, equals(2));
    });

    test('both channels use negotiated=true (avoids out-of-band setup)', () {
      expect(DataChannelConfig.chess.negotiated, isTrue);
      expect(DataChannelConfig.clock.negotiated, isTrue);
    });
  });
}
