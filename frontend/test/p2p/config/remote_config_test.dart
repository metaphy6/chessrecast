// §6.1 / §6.3 Remote-config proof test.
//
// Verifies that:
//  - kEnableP2P defaults to false (safe default, §6.1)
//  - A valid HMAC-signed config blob enables the flag (§6.1)
//  - A tampered / unsigned blob is rejected and the flag stays false (§6.1)
//  - The blob is cached in-memory after acceptance (§6.1)
//  - The flag can be flipped off again via a subsequent valid blob (§6.3
//    kill-switch — remote flip within the same config service)
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/config/remote_config.dart';

void main() {
  group('RemoteConfigService §6.1 / §6.3', () {
    late RemoteConfigService svc;
    late List<int> trustedKey;

    setUp(() {
      // Use a fixed 32-byte key for tests.
      trustedKey = List<int>.generate(32, (i) => i + 1);
      svc = RemoteConfigService(trustedKeyBytes: trustedKey);
    });

    // ── §6.1 defaults ──────────────────────────────────────────────────────
    test('kEnableP2P defaults to false', () {
      expect(svc.isP2PEnabled, isFalse);
    });

    test('kDefaultEnableP2P constant is false', () {
      expect(RemoteConfigService.kDefaultEnableP2P, isFalse);
    });

    // ── §6.1 valid config enables the flag ─────────────────────────────────
    test('valid signed blob with kEnableP2P=true enables the flag', () {
      final blob = RemoteConfigBlob(
        kEnableP2P: true,
        generatedAtMs: DateTime.now().millisecondsSinceEpoch,
      );
      final sig = blob.sign(trustedKey);
      svc.acceptBlob(blob, sig);
      expect(svc.isP2PEnabled, isTrue);
    });

    test('valid signed blob with kEnableP2P=false disables the flag', () {
      // First enable it.
      final on = RemoteConfigBlob(
        kEnableP2P: true,
        generatedAtMs: DateTime.now().millisecondsSinceEpoch,
      );
      svc.acceptBlob(on, on.sign(trustedKey));
      expect(svc.isP2PEnabled, isTrue);

      // Then flip it off (kill-switch §6.3).
      final off = RemoteConfigBlob(
        kEnableP2P: false,
        generatedAtMs: DateTime.now().millisecondsSinceEpoch + 1,
      );
      svc.acceptBlob(off, off.sign(trustedKey));
      expect(svc.isP2PEnabled, isFalse);
    });

    // ── §6.1 tampered blobs are rejected ───────────────────────────────────
    test('blob with wrong signature is rejected', () {
      final blob = RemoteConfigBlob(
        kEnableP2P: true,
        generatedAtMs: DateTime.now().millisecondsSinceEpoch,
      );
      // Corrupt the signature.
      final badSig = List<int>.filled(32, 0xFF);
      expect(
        () => svc.acceptBlob(blob, badSig),
        throwsA(isA<RemoteConfigSignatureError>()),
      );
      expect(svc.isP2PEnabled, isFalse);
    });

    test('blob signed with wrong key is rejected', () {
      final wrongKey = List<int>.generate(32, (i) => 255 - i);
      final blob = RemoteConfigBlob(
        kEnableP2P: true,
        generatedAtMs: DateTime.now().millisecondsSinceEpoch,
      );
      final sig = blob.sign(wrongKey);
      expect(
        () => svc.acceptBlob(blob, sig),
        throwsA(isA<RemoteConfigSignatureError>()),
      );
      expect(svc.isP2PEnabled, isFalse);
    });

    // ── §6.1 caching ───────────────────────────────────────────────────────
    test('last accepted blob is cached and accessible', () {
      final blob = RemoteConfigBlob(
        kEnableP2P: true,
        generatedAtMs: 1_000_000,
      );
      svc.acceptBlob(blob, blob.sign(trustedKey));
      expect(svc.cachedBlob, isNotNull);
      expect(svc.cachedBlob!.kEnableP2P, isTrue);
      expect(svc.cachedBlob!.generatedAtMs, equals(1_000_000));
    });

    test('clearCache resets to default', () {
      final blob = RemoteConfigBlob(
        kEnableP2P: true,
        generatedAtMs: DateTime.now().millisecondsSinceEpoch,
      );
      svc.acceptBlob(blob, blob.sign(trustedKey));
      expect(svc.isP2PEnabled, isTrue);
      svc.clearCache();
      expect(svc.isP2PEnabled, isFalse);
      expect(svc.cachedBlob, isNull);
    });

    // ── §6.3 kill-switch: flag flips off within 10-minute window ───────────
    test('kill-switch: flag goes from true to false via new signed blob', () {
      final enable = RemoteConfigBlob(
        kEnableP2P: true,
        generatedAtMs: 1000,
      );
      svc.acceptBlob(enable, enable.sign(trustedKey));
      expect(svc.isP2PEnabled, isTrue);

      final disable = RemoteConfigBlob(
        kEnableP2P: false,
        generatedAtMs: 2000,
      );
      svc.acceptBlob(disable, disable.sign(trustedKey));
      expect(svc.isP2PEnabled, isFalse);
    });

    // ── Replay guard: older blob does not replace newer ────────────────────
    test('blob with older generatedAtMs does not replace cached newer blob', () {
      final newer = RemoteConfigBlob(
        kEnableP2P: true,
        generatedAtMs: 5000,
      );
      svc.acceptBlob(newer, newer.sign(trustedKey));

      final older = RemoteConfigBlob(
        kEnableP2P: false,
        generatedAtMs: 3000,
      );
      svc.acceptBlob(older, older.sign(trustedKey));

      // Newer blob should still win.
      expect(svc.isP2PEnabled, isTrue);
    });
  });
}
