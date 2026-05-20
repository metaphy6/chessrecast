// §13.2.b3 — casual_mode capability test.
//
// casual_mode=true means both players agreed to a "friend game": takebacks
// are allowed and histogram sharing is disabled.  Both peers must opt in for
// the relaxed rules to apply; one-sided casual mode does not grant takebacks.
library;

import 'package:chessrecast/services/p2p/anti_cheat/casual_mode.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('§13.2.b3 — extractCasualMode', () {
    test('returns true when capabilities contain casual_mode: true', () {
      expect(extractCasualMode({kCasualModeKey: true}), isTrue);
    });

    test('returns false when capabilities are empty', () {
      expect(extractCasualMode({}), isFalse);
    });

    test('returns false when casual_mode: false', () {
      expect(extractCasualMode({kCasualModeKey: false}), isFalse);
    });
  });

  group('§13.2.b3 — buildCasualModeCapability', () {
    test('builds capability with casual_mode: true', () {
      final cap = buildCasualModeCapability(isCasual: true);
      expect(cap[kCasualModeKey], isTrue);
      expect(cap.keys, [kCasualModeKey]);
    });

    test('builds capability with casual_mode: false', () {
      final cap = buildCasualModeCapability(isCasual: false);
      expect(cap[kCasualModeKey], isFalse);
    });
  });

  group('§13.2.b3 — isTakebackAllowed (both must opt in)', () {
    test('allowed when both peers casual', () {
      expect(
        isTakebackAllowed(localCasualMode: true, remoteCasualMode: true),
        isTrue,
      );
    });

    test('not allowed when only local is casual', () {
      expect(
        isTakebackAllowed(localCasualMode: true, remoteCasualMode: false),
        isFalse,
      );
    });

    test('not allowed when only remote is casual', () {
      expect(
        isTakebackAllowed(localCasualMode: false, remoteCasualMode: true),
        isFalse,
      );
    });

    test('not allowed when neither is casual', () {
      expect(
        isTakebackAllowed(localCasualMode: false, remoteCasualMode: false),
        isFalse,
      );
    });
  });

  group('§13.2.b3 — isHistogramSharingEnabled (disabled for casual)', () {
    test('enabled when neither peer is casual', () {
      expect(
        isHistogramSharingEnabled(
          localCasualMode: false,
          remoteCasualMode: false,
        ),
        isTrue,
      );
    });

    test('disabled when local is casual', () {
      expect(
        isHistogramSharingEnabled(
          localCasualMode: true,
          remoteCasualMode: false,
        ),
        isFalse,
      );
    });

    test('disabled when remote is casual', () {
      expect(
        isHistogramSharingEnabled(
          localCasualMode: false,
          remoteCasualMode: true,
        ),
        isFalse,
      );
    });

    test('disabled when both are casual', () {
      expect(
        isHistogramSharingEnabled(
          localCasualMode: true,
          remoteCasualMode: true,
        ),
        isFalse,
      );
    });
  });

  group('§13.4.b2 — Stability: no exceptions escape from casual_mode', () {
    test('empty capabilities returns false without throwing', () {
      expect(() => extractCasualMode({}), returnsNormally);
    });

    test('unknown keys in capabilities do not throw', () {
      expect(() => extractCasualMode({'unknown_key': true}), returnsNormally);
    });
  });
}
