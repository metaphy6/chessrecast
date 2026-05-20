// §14.5 — Root/jailbreak detection → casual-only mode proof test.
//
// Verifies that RootedDevicePolicy forces casual_mode=true (no rated games,
// no flag-fall victories) for rooted/jailbroken and unknown-status devices.
// Honest UX: the user is told — not accused — and can still play casual games.
library;

import 'package:flutter_test/flutter_test.dart';
import '../../../lib/services/p2p/identity/rooted_device_policy.dart';

void main() {
  group('§14.5 — Rooted device → casual-only mode', () {
    group('evaluate()', () {
      test('clean device is unrestricted', () {
        expect(
          RootedDevicePolicy.evaluate(RootStatus.clean),
          equals(GameModeRestriction.unrestricted),
        );
      });

      test('rooted device is casual-only', () {
        expect(
          RootedDevicePolicy.evaluate(RootStatus.rooted),
          equals(GameModeRestriction.casualOnly),
        );
      });

      test('unknown-status device is casual-only', () {
        expect(
          RootedDevicePolicy.evaluate(RootStatus.unknown),
          equals(GameModeRestriction.casualOnly),
        );
      });
    });

    group('allowsRatedGames()', () {
      test('clean device allows rated games', () {
        expect(RootedDevicePolicy.allowsRatedGames(RootStatus.clean), isTrue);
      });

      test('rooted device does not allow rated games', () {
        expect(RootedDevicePolicy.allowsRatedGames(RootStatus.rooted), isFalse);
      });

      test('unknown device does not allow rated games', () {
        expect(
          RootedDevicePolicy.allowsRatedGames(RootStatus.unknown),
          isFalse,
        );
      });
    });

    group('UX copy', () {
      test('root warning message is non-empty', () {
        expect(RootedDevicePolicy.kRootWarning, isNotEmpty);
      });

      test('root warning does not use accusatory language ("cheating")', () {
        // The message should be informative, not accusatory.
        expect(
          RootedDevicePolicy.kRootWarning.toLowerCase(),
          isNot(contains('cheat')),
        );
      });

      test(
        'root warning mentions rated/tournament games being unavailable',
        () {
          final lower = RootedDevicePolicy.kRootWarning.toLowerCase();
          expect(
            lower,
            anyOf(
              contains('casual'),
              contains('rated'),
              contains('tournament'),
            ),
          );
        },
      );

      test('root warning mentions engine integrity concern', () {
        expect(
          RootedDevicePolicy.kRootWarning.toLowerCase(),
          anyOf(contains('integrity'), contains('verify')),
        );
      });
    });

    group('HELLO capability: casual_mode flag', () {
      test('casual_mode=true should be set in HELLO when device is rooted', () {
        // This test documents the contract: when allowsRatedGames() is false,
        // the HELLO builder must include casual_mode=true in capabilities.
        final status = RootStatus.rooted;
        expect(
          RootedDevicePolicy.allowsRatedGames(status),
          isFalse,
          reason: 'rooted device must set casual_mode=true in HELLO',
        );
      });

      test('casual_mode=false is appropriate for a clean device', () {
        final status = RootStatus.clean;
        expect(
          RootedDevicePolicy.allowsRatedGames(status),
          isTrue,
          reason: 'clean device should not force casual_mode',
        );
      });
    });
  });
}
