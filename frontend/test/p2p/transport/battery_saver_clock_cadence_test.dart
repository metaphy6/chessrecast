// §4.8 Battery saver clock cadence test.
//
// When OS battery saver is active, the clock heartbeat interval is
// reduced to lower CPU/wake-lock frequency.
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/transport/network_monitor.dart';

void main() {
  group('BatterySaverClockPolicy §4.8', () {
    test('normal cadence is 250 ms', () {
      expect(BatterySaverClockPolicy.normalCadenceMs, equals(250));
    });

    test('battery-saver cadence is 1000 ms', () {
      expect(BatterySaverClockPolicy.batterySaverCadenceMs, equals(1000));
    });

    test('battery-saver cadence is >= 4x normal', () {
      expect(BatterySaverClockPolicy.batterySaverCadenceMs,
          greaterThanOrEqualTo(BatterySaverClockPolicy.normalCadenceMs * 4));
    });

    test('policy returns saver cadence when saver is on', () {
      final policy = BatterySaverClockPolicy();
      expect(
        policy.cadenceMs(batterySaverActive: true),
        equals(BatterySaverClockPolicy.batterySaverCadenceMs),
      );
    });

    test('policy returns normal cadence when saver is off', () {
      final policy = BatterySaverClockPolicy();
      expect(
        policy.cadenceMs(batterySaverActive: false),
        equals(BatterySaverClockPolicy.normalCadenceMs),
      );
    });
  });
}
