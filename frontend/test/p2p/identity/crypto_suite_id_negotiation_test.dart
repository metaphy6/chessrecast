import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/identity/identity.dart';

void main() {
  group('CryptoSuiteId — negotiation (§2.6)', () {
    test('negotiate returns classical suite when both peers agree', () {
      final suite = CryptoSuiteId.negotiate(
        CryptoSuiteId.kSuiteClassical,
        CryptoSuiteId.kSuiteClassical,
      );
      expect(suite.value, equals(CryptoSuiteId.kSuiteClassical));
    });

    test('negotiate throws CryptoSuiteNotNegotiatedError on mismatch', () {
      expect(
        () => CryptoSuiteId.negotiate(0x01, 0x02),
        throwsA(isA<CryptoSuiteNotNegotiatedError>()),
      );
    });

    test('negotiate throws on unknown suite ID', () {
      expect(
        () => CryptoSuiteId.negotiate(0xFF, 0xFF),
        throwsA(isA<CryptoSuiteNotNegotiatedError>()),
      );
    });

    test('kSuiteClassical is 0x01', () {
      expect(CryptoSuiteId.kSuiteClassical, equals(0x01));
    });

    test('isKnown is true for kSuiteClassical, false for unknown', () {
      expect(CryptoSuiteId(CryptoSuiteId.kSuiteClassical).isKnown, isTrue);
      expect(CryptoSuiteId(0xFF).isKnown, isFalse);
    });

    test('CryptoSuiteNotNegotiatedError message contains both suite IDs', () {
      try {
        CryptoSuiteId.negotiate(0x01, 0x02);
        fail('Expected exception');
      } on CryptoSuiteNotNegotiatedError catch (e) {
        expect(e.toString(), contains('0x1'));
        expect(e.toString(), contains('0x2'));
      }
    });
  });
}
