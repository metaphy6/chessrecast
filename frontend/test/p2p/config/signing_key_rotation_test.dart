// §8.8 / leaf 8.8.b5 — Signing-key rotation test.
//
// Verifies that RemoteConfigService supports the "one-step-back trust window":
//   - A blob signed with the CURRENT key is accepted.
//   - A blob signed with the PREVIOUS (rotated-out) key is also accepted.
//   - A blob signed with an UNKNOWN key is rejected.
//   - After the trust-window expires (previous key removed), the old signature
//     is rejected.
//   - A service with a single key still works normally (backward compat).
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/config/remote_config.dart';

void main() {
  // Two fixed 32-byte keys for deterministic tests.
  final oldKey = List<int>.generate(32, (i) => i + 1);     // key epoch 1
  final newKey = List<int>.generate(32, (i) => i + 33);    // key epoch 2
  final unknownKey = List<int>.generate(32, (i) => i + 65); // not trusted

  RemoteConfigBlob makeBlob({bool enable = true, int offsetMs = 0}) =>
      RemoteConfigBlob(
        kEnableP2P: enable,
        generatedAtMs: DateTime.now().millisecondsSinceEpoch + offsetMs,
      );

  // ── Single-key backward-compatibility ────────────────────────────────────
  test('single-key service still works (backward compat)', () {
    final svc = RemoteConfigService(trustedKeyBytes: newKey);
    final blob = makeBlob(enable: true);
    svc.acceptBlob(blob, blob.sign(newKey));
    expect(svc.isP2PEnabled, isTrue);
  });

  // ── Multi-key trust window ────────────────────────────────────────────────
  group('RemoteConfigService signing-key rotation (§8.8.b5)', () {
    test('blob signed with current key is accepted', () {
      final svc = RemoteConfigService(
        trustedKeyBytes: newKey,
        previousKeyBytes: oldKey,
      );
      final blob = makeBlob(enable: true);
      svc.acceptBlob(blob, blob.sign(newKey));
      expect(svc.isP2PEnabled, isTrue);
    });

    test('blob signed with previous (rotated-out) key is accepted within window', () {
      final svc = RemoteConfigService(
        trustedKeyBytes: newKey,
        previousKeyBytes: oldKey,
      );
      final blob = makeBlob(enable: true);
      svc.acceptBlob(blob, blob.sign(oldKey));
      expect(svc.isP2PEnabled, isTrue);
    });

    test('blob signed with unknown key is rejected', () {
      final svc = RemoteConfigService(
        trustedKeyBytes: newKey,
        previousKeyBytes: oldKey,
      );
      final blob = makeBlob(enable: true);
      expect(
        () => svc.acceptBlob(blob, blob.sign(unknownKey)),
        throwsA(isA<RemoteConfigSignatureError>()),
      );
      expect(svc.isP2PEnabled, isFalse);
    });

    test('after trust window closes (previous key removed), old signature is rejected', () {
      // Simulate the trust-window expiry by creating a service with only the
      // new key (previousKeyBytes: null).
      final svc = RemoteConfigService(trustedKeyBytes: newKey);
      final blob = makeBlob(enable: true);
      expect(
        () => svc.acceptBlob(blob, blob.sign(oldKey)),
        throwsA(isA<RemoteConfigSignatureError>()),
      );
      expect(svc.isP2PEnabled, isFalse);
    });

    test('rotation: enable with old key, then re-enable with new key', () {
      final svc = RemoteConfigService(
        trustedKeyBytes: newKey,
        previousKeyBytes: oldKey,
      );

      // Before rotation — old key works.
      final blob1 = makeBlob(enable: true, offsetMs: 0);
      svc.acceptBlob(blob1, blob1.sign(oldKey));
      expect(svc.isP2PEnabled, isTrue);

      // After rotation — new key also works (overrides with a later timestamp).
      final blob2 = makeBlob(enable: false, offsetMs: 1);
      svc.acceptBlob(blob2, blob2.sign(newKey));
      expect(svc.isP2PEnabled, isFalse);
    });
  });
}
