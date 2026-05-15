import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import '../../../lib/services/p2p/protocol/frame.dart';

void main() {
  group('BYE disagreement — both peers keep transcripts (§1.8 / §7)', () {
    final movesA = ['e2e4', 'e7e5', 'g1f3'];
    final movesB = ['e2e4', 'e7e5', 'g1f3', 'b8c6']; // B has one extra move

    test('peers can send conflicting BYE frames (different result/move lists)', () {
      final byeA = {
        'result': '1-0',
        'moves': movesA,
        'sig': Uint8List(64),
      };
      final byeB = {
        'result': '0-1',
        'moves': movesB,
        'sig': Uint8List(64),
      };

      final frameA = Frame.withPayloadMap(FrameType.bye, byeA, sequenceNum: 1);
      final frameB = Frame.withPayloadMap(FrameType.bye, byeB, sequenceNum: 1);

      // Both frames decode successfully
      final dpA = Frame.decode(frameA.encode()).decodePayload();
      final dpB = Frame.decode(frameB.encode()).decodePayload();

      expect(dpA['result'], '1-0');
      expect(dpB['result'], '0-1');

      // They disagree on result and move count
      expect(dpA['result'], isNot(dpB['result']));
      expect((dpA['moves'] as List).length,
          isNot((dpB['moves'] as List).length));
    });

    test('MISMATCH frame can reference both transcripts', () {
      // When peers disagree, a MISMATCH frame carries both signed transcripts
      final mismatchPayload = <String, dynamic>{
        'local_result': '1-0',
        'local_moves': movesA,
        'remote_result': '0-1',
        'remote_moves': movesB,
        'local_sig': Uint8List(64),
        'remote_sig': Uint8List(64),
      };

      final frame = Frame.withPayloadMap(
          FrameType.mismatch, mismatchPayload, sequenceNum: 1);
      final dp = Frame.decode(frame.encode()).decodePayload();

      expect(dp['local_result'], '1-0');
      expect(dp['remote_result'], '0-1');
      expect((dp['local_sig'] as Uint8List).length, 64);
      expect((dp['remote_sig'] as Uint8List).length, 64);
    });

    test('agreeing BYE frames have the same result', () {
      final result = '1/2-1/2';
      final byeA = {'result': result, 'moves': movesA, 'sig': Uint8List(64)};
      final byeB = {'result': result, 'moves': movesA, 'sig': Uint8List(64)};

      final dpA = Frame.decode(
              Frame.withPayloadMap(FrameType.bye, byeA, sequenceNum: 1).encode())
          .decodePayload();
      final dpB = Frame.decode(
              Frame.withPayloadMap(FrameType.bye, byeB, sequenceNum: 1).encode())
          .decodePayload();

      expect(dpA['result'], dpB['result']);
    });
  });
}
