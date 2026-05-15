import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import '../../../lib/services/p2p/protocol/frame.dart';

void main() {
  group('CborCodec.isDeterministic (§1.1 — RFC 8949 §4.2)', () {
    test('freshly encoded map is deterministic', () {
      final encoded = CborCodec.encode({'z': 26, 'a': 1, 'm': 13});
      expect(CborCodec.isDeterministic(encoded), isTrue);
    });

    test('freshly encoded nested map is deterministic', () {
      final encoded = CborCodec.encode({
        'inner': {'c': 3, 'a': 1, 'b': 2},
        'outer': 42,
      });
      expect(CborCodec.isDeterministic(encoded), isTrue);
    });

    test('freshly encoded Frame is deterministic', () {
      final payload =
          CborCodec.encode({'uci': 'e2e4', 'hash': Uint8List(32)});
      final frame = Frame(
          type: FrameType.move, sequenceNum: 1, wallClock: 0, payload: payload);
      final encoded = frame.encode();
      expect(CborCodec.isDeterministic(encoded), isTrue);
    });

    test('CBOR with unsorted map keys is NOT deterministic', () {
      // Hand-craft CBOR with keys in wrong order: {'b': 2, 'a': 1}
      // The deterministic order should be: 'a' before 'b'.
      // 0xa2 = 2-element map
      // 0x61, 0x62, 0x02 = key "b", value 2
      // 0x61, 0x61, 0x01 = key "a", value 1
      final nonDeterministic = Uint8List.fromList(
          [0xa2, 0x61, 0x62, 0x02, 0x61, 0x61, 0x01]);
      expect(CborCodec.isDeterministic(nonDeterministic), isFalse);
    });

    test('malformed CBOR returns false from isDeterministic', () {
      expect(CborCodec.isDeterministic(Uint8List.fromList([0xFF])), isFalse);
    });

    test('empty bytes return false from isDeterministic', () {
      expect(CborCodec.isDeterministic(Uint8List(0)), isFalse);
    });

    test('non-shortest integer (extra leading zero byte) is not deterministic',
        () {
      // CBOR 0x18 0x01 encodes integer 1 as 1-byte argument, but the
      // deterministic form of 1 is just 0x01 (direct in major byte).
      // 0x18 0x01 = integer 1 using 1-byte arg (non-shortest).
      final nonShortest = Uint8List.fromList([0x18, 0x01]);
      expect(CborCodec.isDeterministic(nonShortest), isFalse);
    });

    test('various frame types all produce deterministic CBOR', () {
      for (final ft in FrameType.values) {
        final frame = Frame.withPayloadMap(
          ft,
          {'t': ft.id},
          sequenceNum: 1,
        );
        final encoded = frame.encode();
        expect(CborCodec.isDeterministic(encoded), isTrue,
            reason: 'Frame type ${ft.name} was not deterministic');
      }
    });
  });
}
