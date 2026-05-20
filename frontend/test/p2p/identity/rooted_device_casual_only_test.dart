// T-N-009 §9.9 — Rooted/jailbroken device → casual-only mode.
//
// Proof: RootedDevicePolicy.evaluate() returns casualOnly for rooted/unknown
// devices and unrestricted for clean devices.  allowsRatedGames() blocks rated
// starts on rooted devices.
import 'package:flutter_test/flutter_test.dart';
import '../../../lib/services/p2p/identity/rooted_device_policy.dart';

void main() {
  group('T-N-009 §9.9 — Rooted device → casual-only mode', () {
    test('clean device gets unrestricted mode', () {
      expect(
        RootedDevicePolicy.evaluate(RootStatus.clean),
        equals(GameModeRestriction.unrestricted),
      );
    });

    test('rooted device gets casualOnly restriction', () {
      expect(
        RootedDevicePolicy.evaluate(RootStatus.rooted),
        equals(GameModeRestriction.casualOnly),
      );
    });

    test('unknown root status gets casualOnly restriction (fail-safe)', () {
      expect(
        RootedDevicePolicy.evaluate(RootStatus.unknown),
        equals(GameModeRestriction.casualOnly),
        reason: 'unknown root status must be treated conservatively',
      );
    });

    test('clean device allows rated games', () {
      expect(RootedDevicePolicy.allowsRatedGames(RootStatus.clean), isTrue);
    });

    test('rooted device does NOT allow rated games', () {
      expect(
        RootedDevicePolicy.allowsRatedGames(RootStatus.rooted),
        isFalse,
        reason: 'rated games blocked on rooted device',
      );
    });

    test('unknown root status does NOT allow rated games', () {
      expect(
        RootedDevicePolicy.allowsRatedGames(RootStatus.unknown),
        isFalse,
      );
    });

    test('kRootWarning message is non-empty', () {
      expect(RootedDevicePolicy.kRootWarning, isNotEmpty);
    });

    test('kRootWarning mentions rated and tournament', () {
      final w = RootedDevicePolicy.kRootWarning.toLowerCase();
      expect(w, contains('rated'));
      expect(w, contains('tournament'));
    });
  });
}
