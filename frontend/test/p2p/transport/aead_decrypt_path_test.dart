// §4.4 Integrity — AEAD decrypt path test.
//
// Verifies that the AeadDecryptPath model:
//   - validates AEAD before passing to engine
//   - drops with BAD_FRAME on AEAD failure
//   - validates CBOR after AEAD succeed
//   - drops with BAD_FRAME on bad CBOR
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/transport/aead_decrypt_path.dart';

void main() {
  group('AeadDecryptPath §4.4 integrity', () {
    test('valid AEAD + valid CBOR passes to engine', () {
      final path = AeadDecryptPath();
      final result = path.process(
        aeadOk: true,
        cborOk: true,
        payload: [0x01, 0x02],
      );
      expect(result.passed, isTrue);
      expect(result.dropReason, isNull);
    });

    test('AEAD failure drops with BAD_FRAME', () {
      final path = AeadDecryptPath();
      final result = path.process(
        aeadOk: false,
        cborOk: false,
        payload: [],
      );
      expect(result.passed, isFalse);
      expect(result.dropReason, equals('BAD_FRAME'));
    });

    test('CBOR failure after AEAD success drops with BAD_FRAME', () {
      final path = AeadDecryptPath();
      final result = path.process(
        aeadOk: true,
        cborOk: false,
        payload: [],
      );
      expect(result.passed, isFalse);
      expect(result.dropReason, equals('BAD_FRAME'));
    });

    test('CBOR validation runs AFTER AEAD (not before)', () {
      // If AEAD fails, cbor check must not run (short-circuit).
      int cborCallCount = 0;
      final path = AeadDecryptPath(
        onCborCheck: (_) {
          cborCallCount++;
          return true;
        },
      );
      path.process(aeadOk: false, cborOk: false, payload: []);
      expect(cborCallCount, equals(0));
    });
  });
}
