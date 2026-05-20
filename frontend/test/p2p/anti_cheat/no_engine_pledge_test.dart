// §13.2.b1 — no_engine_pledge in HELLO capabilities test.
//
// Verifies that no_engine_pledge.dart exposes the correct extraction and
// capability-building helpers that integrate with the HELLO wire message.
library;

import 'package:chessrecast/services/p2p/anti_cheat/no_engine_pledge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('§13.2.b1 — no_engine_pledge extraction', () {
    test('extracts true when capability set', () {
      final caps = {kNoEnginePledgeKey: true};
      expect(extractNoEnginePledge(caps), isTrue);
    });

    test('extracts false when capability absent', () {
      expect(extractNoEnginePledge({}), isFalse);
    });

    test('extracts false when capability explicitly false', () {
      final caps = {kNoEnginePledgeKey: false};
      expect(extractNoEnginePledge(caps), isFalse);
    });

    test('ignores unrelated capability keys', () {
      final caps = {kCasualModeKey: true};
      expect(extractNoEnginePledge(caps), isFalse);
    });
  });

  group('§13.2.b1 — buildNoEnginePledgeCapability', () {
    test('builds capability map when pledging', () {
      final cap = buildNoEnginePledgeCapability(pledges: true);
      expect(cap[kNoEnginePledgeKey], isTrue);
    });

    test('builds capability map when not pledging', () {
      final cap = buildNoEnginePledgeCapability(pledges: false);
      expect(cap[kNoEnginePledgeKey], isFalse);
    });

    test('returned map contains only the pledge key', () {
      final cap = buildNoEnginePledgeCapability(pledges: true);
      expect(cap.keys, [kNoEnginePledgeKey]);
    });
  });
}
