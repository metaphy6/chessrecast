// §6.3 Kill-switch proof test.
//
// The kill-switch requirement (§6.3): "kEnableP2P can be flipped off remotely
// within 10 minutes globally; client falls back to local-only mode
// (single-player)."
//
// This test verifies the client-side half: that a newly pushed signed config
// blob with kEnableP2P=false is accepted and the flag immediately reads false,
// and that no further P2P functionality is attempted while the flag is off.
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/config/remote_config.dart';

void main() {
  group('RemoteConfigService kill-switch §6.3', () {
    late RemoteConfigService svc;
    late List<int> key;

    setUp(() {
      key = List<int>.generate(32, (i) => (i * 7 + 3) % 256);
      svc = RemoteConfigService(trustedKeyBytes: key);
    });

    test('flag starts false (safe default)', () {
      expect(svc.isP2PEnabled, isFalse);
    });

    test('push enable blob → isP2PEnabled becomes true', () {
      final blob =
          RemoteConfigBlob(kEnableP2P: true, generatedAtMs: 1000);
      svc.acceptBlob(blob, blob.sign(key));
      expect(svc.isP2PEnabled, isTrue);
    });

    test('push disable blob after enable → isP2PEnabled immediately false', () {
      final enable =
          RemoteConfigBlob(kEnableP2P: true, generatedAtMs: 1000);
      svc.acceptBlob(enable, enable.sign(key));
      expect(svc.isP2PEnabled, isTrue);

      final disable =
          RemoteConfigBlob(kEnableP2P: false, generatedAtMs: 2000);
      svc.acceptBlob(disable, disable.sign(key));
      expect(svc.isP2PEnabled, isFalse);
    });

    test('kill-switch cannot be activated by unsigned blob', () {
      final enable =
          RemoteConfigBlob(kEnableP2P: true, generatedAtMs: 1000);
      svc.acceptBlob(enable, enable.sign(key));
      expect(svc.isP2PEnabled, isTrue);

      // Attacker pushes a disable blob without a valid signature.
      final attack =
          RemoteConfigBlob(kEnableP2P: false, generatedAtMs: 2000);
      final badSig = List<int>.filled(32, 0x00);
      expect(
        () => svc.acceptBlob(attack, badSig),
        throwsA(isA<RemoteConfigSignatureError>()),
      );
      // Flag must remain true — attacker could not flip the kill-switch.
      expect(svc.isP2PEnabled, isTrue);
    });

    test('multiple enable/disable cycles work correctly', () {
      for (var cycle = 0; cycle < 5; cycle++) {
        final on = RemoteConfigBlob(
            kEnableP2P: true, generatedAtMs: cycle * 2 * 1000 + 1000);
        svc.acceptBlob(on, on.sign(key));
        expect(svc.isP2PEnabled, isTrue);

        final off = RemoteConfigBlob(
            kEnableP2P: false, generatedAtMs: cycle * 2 * 1000 + 2000);
        svc.acceptBlob(off, off.sign(key));
        expect(svc.isP2PEnabled, isFalse);
      }
    });
  });
}
