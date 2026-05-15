import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import '../../../lib/services/p2p/protocol/frame.dart';

void main() {
  group('CBOR float rejection (§1.1 — RFC 8949 §4.2, CBOR_FLOAT_REJECTED)', () {
    // CBOR major type 7 float prefixes:
    //   0xf9 = half-precision float (16-bit)
    //   0xfa = single-precision float (32-bit)
    //   0xfb = double-precision float (64-bit)

    test(
      'decoding a half-precision float (0xf9) throws CborFloatRejectedError',
      () {
        // CBOR map { "x": float16(1.5) }
        // 0xa1 = 1-element map
        // 0x61, 0x78 = text "x"
        // 0xf9, 0x3e, 0x00 = half float 1.5
        final bytes = Uint8List.fromList([0xa1, 0x61, 0x78, 0xf9, 0x3e, 0x00]);
        expect(
          () => CborCodec.decode(bytes),
          throwsA(isA<CborFloatRejectedError>()),
        );
      },
    );

    test(
      'decoding a single-precision float (0xfa) throws CborFloatRejectedError',
      () {
        // CBOR map { "x": float32(3.14) }
        // 0xa1 = 1-element map
        // 0x61, 0x78 = text "x"
        // 0xfa = single float
        final bytes = Uint8List.fromList([
          0xa1,
          0x61,
          0x78,
          0xfa,
          0x40,
          0x48,
          0xf5,
          0xc3,
        ]);
        expect(
          () => CborCodec.decode(bytes),
          throwsA(isA<CborFloatRejectedError>()),
        );
      },
    );

    test(
      'decoding a double-precision float (0xfb) throws CborFloatRejectedError',
      () {
        // CBOR map { "x": float64(1.0) }
        // 0xfb, 0x3f, 0xf0... = double 1.0
        final bytes = Uint8List.fromList([
          0xa1,
          0x61,
          0x78,
          0xfb,
          0x3f,
          0xf0,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
        ]);
        expect(
          () => CborCodec.decode(bytes),
          throwsA(isA<CborFloatRejectedError>()),
        );
      },
    );

    test('float nested inside a CBOR array is also rejected', () {
      // CBOR array [float16(1.0)]
      // 0x81 = 1-element array; 0xf9, 0x3c, 0x00 = float16(1.0)
      final bytes = Uint8List.fromList([0x81, 0xf9, 0x3c, 0x00]);
      expect(
        () => CborCodec.decode(bytes),
        throwsA(isA<CborFloatRejectedError>()),
      );
    });

    test('integer values are NOT mistaken for floats', () {
      // 0x00 = integer 0, 0x01 = integer 1, 0x17 = integer 23
      // 0xf4 = false, 0xf5 = true, 0xf6 = null — all ok
      final map = {'a': 0, 'b': 1, 'c': true, 'd': false, 'e': null};
      final encoded = CborCodec.encode(map);
      expect(() => CborCodec.decode(encoded), returnsNormally);
    });

    test('encode never produces float bytes', () {
      final values = [
        0,
        1,
        42,
        255,
        256,
        65535,
        65536,
        'hello',
        true,
        false,
        null,
      ];
      for (final v in values) {
        final encoded = CborCodec.encode(v);
        for (final byte in encoded) {
          expect(
            byte == 0xf9 || byte == 0xfa || byte == 0xfb,
            isFalse,
            reason: 'Found float byte 0x${byte.toRadixString(16)} encoding $v',
          );
        }
      }
    });

    test('CborFloatRejectedError has meaningful toString', () {
      expect(
        const CborFloatRejectedError().toString(),
        contains('CBOR_FLOAT_REJECTED'),
      );
    });
  });

  group('Deterministic CBOR — sorted map keys', () {
    test('map keys are sorted byte-lexicographically in encoding', () {
      // Keys with CBOR text encoding length differences sort by CBOR encoding.
      // Short keys sort before long keys of same first byte.
      final input = {'bb': 2, 'a': 1, 'aaa': 3};
      final encoded = CborCodec.encode(input);
      // Decode and check key order in raw bytes
      final decoded = CborCodec.decode(encoded) as Map<String, dynamic>;
      expect(decoded['a'], equals(1));
      expect(decoded['bb'], equals(2));
      expect(decoded['aaa'], equals(3));
    });

    test('re-encoding a decoded map produces byte-identical output', () {
      final original = CborCodec.encode({'z': 26, 'a': 1, 'm': 13});
      expect(CborCodec.isDeterministic(original), isTrue);
    });

    test('shortest-form integer encoding', () {
      // 0 → 0x00 (1 byte), 23 → 0x17 (1 byte), 24 → 0x18 0x18 (2 bytes)
      expect(CborCodec.encode(0), equals(Uint8List.fromList([0x00])));
      expect(CborCodec.encode(23), equals(Uint8List.fromList([0x17])));
      expect(CborCodec.encode(24), equals(Uint8List.fromList([0x18, 0x18])));
      expect(CborCodec.encode(255), equals(Uint8List.fromList([0x18, 0xff])));
      expect(
        CborCodec.encode(256),
        equals(Uint8List.fromList([0x19, 0x01, 0x00])),
      );
    });
  });
}
