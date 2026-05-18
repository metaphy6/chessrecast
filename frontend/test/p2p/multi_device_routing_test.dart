// §7 bullet-2 multi-device routing proof test.
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

import '../../lib/services/p2p/multi_device/multi_device_router.dart';

void main() {
  group('MultiDeviceRouter §7 bullet-2', () {
    Uint8List key(int b) => Uint8List.fromList(List.generate(32, (_) => b));

    test('registerDevice adds device', () {
      final router = MultiDeviceRouter();
      router.registerDevice(
          AccountDevice(devicePubKey: key(1), deviceName: 'phone'));
      expect(router.reachableDevices.length, equals(1));
    });

    test('unregisterDevice removes device', () {
      final router = MultiDeviceRouter();
      final k = key(2);
      router.registerDevice(AccountDevice(devicePubKey: k, deviceName: 'tablet'));
      router.unregisterDevice(k);
      expect(router.reachableDevices, isEmpty);
    });

    test('dispatchOffer returns all reachable devices', () {
      final router = MultiDeviceRouter();
      router.registerDevice(
          AccountDevice(devicePubKey: key(3), deviceName: 'phone'));
      router.registerDevice(
          AccountDevice(devicePubKey: key(4), deviceName: 'tablet'));
      final targets = router.dispatchOffer();
      expect(targets.length, equals(2));
    });

    test('dispatchOffer excludes unreachable devices', () {
      final router = MultiDeviceRouter();
      final k1 = key(5);
      final k2 = key(6);
      router.registerDevice(
          AccountDevice(devicePubKey: k1, deviceName: 'online'));
      router.registerDevice(
          AccountDevice(devicePubKey: k2, deviceName: 'offline'));
      router.markReachable(k2, reachable: false);
      final targets = router.dispatchOffer();
      expect(targets.length, equals(1));
      expect(targets.first.deviceName, equals('online'));
    });

    test('OfferRoutingResult values exist', () {
      expect(OfferRoutingResult.values,
          containsAll([OfferRoutingResult.dispatched, OfferRoutingResult.noReachableDevices]));
    });

    test('firstToAnswer returns winner and losers', () {
      final router = MultiDeviceRouter();
      final k1 = key(10);
      final k2 = key(11);
      final k3 = key(12);
      router.registerDevice(AccountDevice(devicePubKey: k1, deviceName: 'd1'));
      router.registerDevice(AccountDevice(devicePubKey: k2, deviceName: 'd2'));
      router.registerDevice(AccountDevice(devicePubKey: k3, deviceName: 'd3'));
      final result = router.firstToAnswer(k2);
      expect(result.winner.deviceName, equals('d2'));
      expect(result.losers.length, equals(2));
      expect(result.losers.every((d) => d.deviceName != 'd2'), isTrue);
    });

    test('markReachable false then true restores device to dispatch', () {
      final router = MultiDeviceRouter();
      final k = key(20);
      router.registerDevice(AccountDevice(devicePubKey: k, deviceName: 'flip'));
      router.markReachable(k, reachable: false);
      expect(router.dispatchOffer(), isEmpty);
      router.markReachable(k, reachable: true);
      expect(router.dispatchOffer().length, equals(1));
    });
  });
}
