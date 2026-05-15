import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import '../../../lib/services/p2p/protocol/frame.dart';

void main() {
  group('Frame codec — encode/decode round-trip (§1.1 / §1)', () {
    test('MOVE frame round-trip preserves all envelope fields', () {
      final payload = CborCodec.encode({'uci': 'e2e4', 'hash': Uint8List(32)});

      final frame = Frame(
        type: FrameType.move,
        sequenceNum: 42,
        wallClock: 1700000000000,
        payload: payload,
      );

      final encoded = frame.encode();
      final decoded = Frame.decode(encoded);

      expect(decoded.version, Frame.wireVersion);
      expect(decoded.type, FrameType.move);
      expect(decoded.sequenceNum, 42);
      expect(decoded.wallClock, 1700000000000);
    });

    test('Frame.withPayloadMap round-trip', () {
      final payloadMap = {'uci': 'g1f3', 'hash': Uint8List(32), 'seq': 5};

      final frame = Frame.withPayloadMap(
        FrameType.moveAck,
        payloadMap,
        sequenceNum: 5,
      );

      final encoded = frame.encode();
      final decoded = Frame.decode(encoded);
      final dp = decoded.decodePayload();

      expect(dp['uci'], 'g1f3');
      expect(dp['seq'], 5);
      expect((dp['hash'] as Uint8List).length, 32);
    });

    test('all 24 FrameType variants have distinct IDs', () {
      final ids = FrameType.values.map((t) => t.id).toSet();
      expect(ids.length, FrameType.values.length);
    });

    test('FrameType.fromId returns null for unknown ids', () {
      expect(FrameType.fromId(0x00), isNull);
      expect(FrameType.fromId(0xFF), isNull);
    });

    test('FrameType.fromId returns correct type for each known id', () {
      for (final t in FrameType.values) {
        expect(FrameType.fromId(t.id), t);
      }
    });

    test('Frame.decode throws FormatException for malformed CBOR', () {
      final bad = Uint8List.fromList([0xFF, 0xFF, 0xFF]);
      expect(() => Frame.decode(bad), throwsA(isA<FormatException>()));
    });

    test('Frame.decode throws FormatException for missing field v', () {
      // Map without 'v' field
      final m = CborCodec.encode({
        't': FrameType.move.id,
        'n': 1,
        'ts': 0,
        'p': CborCodec.encode({'uci': 'e2e4'}),
      });
      expect(() => Frame.decode(m), throwsA(isA<FormatException>()));
    });

    test('Frame.decode throws FormatException for unknown type', () {
      final m = CborCodec.encode({
        'v': 1,
        't': 0xFE,
        'n': 1,
        'ts': 0,
        'p': CborCodec.encode({'uci': 'e2e4'}),
      });
      expect(() => Frame.decode(m), throwsA(isA<FormatException>()));
    });

    test('CBOR encoding is deterministic across two calls', () {
      final payload = CborCodec.encode({'uci': 'e2e4', 'hash': Uint8List(32)});
      final frame = Frame(
        type: FrameType.move,
        sequenceNum: 1,
        wallClock: 1000,
        payload: payload,
      );
      expect(frame.encode(), equals(frame.encode()));
    });

    test('large sequence number survives round-trip', () {
      const bigSeq = 0xFFFFFFFF;
      final payload = CborCodec.encode({'x': 0});
      final frame = Frame(
        type: FrameType.ping,
        sequenceNum: bigSeq,
        wallClock: 0,
        payload: payload,
      );
      final decoded = Frame.decode(frame.encode());
      expect(decoded.sequenceNum, bigSeq);
    });

    test('ModId.fromInt round-trips all values', () {
      for (final m in ModId.values) {
        expect(ModId.fromInt(m.id), m);
      }
    });

    test('ModId.fromInt throws for unknown id', () {
      expect(() => ModId.fromInt(99), throwsArgumentError);
    });
  });
}
