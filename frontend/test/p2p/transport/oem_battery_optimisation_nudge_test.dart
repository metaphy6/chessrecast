// §4.9 OEM battery-optimisation nudge test.
//
// Verifies the policy that detects known OEM battery optimisation modes
// (Xiaomi MIUI, Huawei EMUI, OnePlus OxygenOS) and emits a nudge to
// direct the user to the OEM-specific exemption screen.
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/transport/oem_lifecycle_policy.dart';

void main() {
  group('OemLifecyclePolicy §4.9 battery nudge', () {
    test('MIUI background kill triggers nudge', () {
      final policy = OemLifecyclePolicy(oem: OemVendor.xiaomiMiui);
      expect(policy.needsBatteryNudge, isTrue);
      expect(policy.nudgeSettingsRoute, contains('battery'));
    });

    test('EMUI Huawei background kill triggers nudge', () {
      final policy = OemLifecyclePolicy(oem: OemVendor.huaweiEmui);
      expect(policy.needsBatteryNudge, isTrue);
    });

    test('OxygenOS triggers nudge', () {
      final policy = OemLifecyclePolicy(oem: OemVendor.onePlusOxygenOs);
      expect(policy.needsBatteryNudge, isTrue);
    });

    test('stock Android does not need nudge', () {
      final policy = OemLifecyclePolicy(oem: OemVendor.stockAndroid);
      expect(policy.needsBatteryNudge, isFalse);
    });
  });
}
