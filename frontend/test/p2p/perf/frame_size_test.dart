import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import '../../../lib/services/p2p/protocol/frame.dart';

void main() {
  group('Frame size (§1.5 — average MOVE frame ≤ 48 bytes)', () {
    const int moveSamples = 100;
    const int maxAvgBytes = 48;

    // MOVE payload per §4: {'m': '<uci>'} only.
    // State hash is in MOVE_ACK (type 0x11), not in MOVE itself.
    test('average MOVE frame wire size ≤ $maxAvgBytes bytes', () {
      final moves = [
        'e2e4', 'e7e5', 'g1f3', 'b8c6', 'd2d4', 'e5d4', 'f3d4', 'g8f6',
        'b1c3', 'f8b4', 'f1b5', 'a7a6', 'b5a4', 'b7b5', 'a4b3', 'e8g8',
        'e1g1', 'f8e8', 'a2a3', 'b4c3', 'b2c3', 'a6a5', 'f1e1', 'd7d6',
      ];

      int totalBytes = 0;
      int count = 0;

      for (int i = 0; i < moveSamples; i++) {
        final uci = moves[i % moves.length];
        final payload = CborCodec.encode({'m': uci});
        final frame = Frame(
          type: FrameType.move,
          sequenceNum: i + 1,
          wallClock: 1700000000000 + i * 1000,
          payload: payload,
        );
        final encoded = frame.encode();
        totalBytes += encoded.length;
        count++;
      }

      final avg = totalBytes / count;
      // ignore: avoid_print
      print(
          'Average MOVE frame size: ${avg.toStringAsFixed(1)} bytes over $count samples');

      expect(avg, lessThanOrEqualTo(maxAvgBytes.toDouble()),
          reason:
              'Average MOVE frame size ${avg.toStringAsFixed(1)} bytes exceeds $maxAvgBytes bytes');
    });

    test('a minimal MOVE frame (short UCI, no extras) is well under 48 bytes', () {
      final payload = CborCodec.encode({'m': 'e2e4'});
      final frame = Frame(
        type: FrameType.move,
        sequenceNum: 1,
        wallClock: 1700000000000,
        payload: payload,
      );
      final size = frame.encode().length;
      // ignore: avoid_print
      print('Minimal MOVE frame: $size bytes');
      expect(size, lessThanOrEqualTo(maxAvgBytes));
    });

    test('CBOR payload for MOVE frame is compact (< 12 bytes)', () {
      // {'m': 'e2e4'} CBOR: map(1) + 'm'(2) + 'e2e4'(5) = 8 bytes
      final payload = CborCodec.encode({'m': 'e2e4'});
      // ignore: avoid_print
      print('MOVE payload bytes: ${payload.length}');
      expect(payload.length, lessThanOrEqualTo(12),
          reason: 'MOVE payload of ${payload.length} bytes is larger than expected');
    });

    test('MOVE-ACK frame carrying 32-byte state hash is ≤ 72 bytes', () {
      // The MOVE_ACK (0x11) carries the state hash for verification.
      final ackPayload = CborCodec.encode({
        'h': Uint8List(32), // 32-byte state hash
        'n': 1,             // seq being acked
      });
      final ackFrame = Frame(
        type: FrameType.moveAck,
        sequenceNum: 1,
        wallClock: 1700000000000,
        payload: ackPayload,
      );
      final size = ackFrame.encode().length;
      // ignore: avoid_print
      print('MOVE-ACK frame with hash: $size bytes');
      expect(size, lessThanOrEqualTo(72));
    });
  });
}
