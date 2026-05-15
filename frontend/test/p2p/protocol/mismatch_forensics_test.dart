import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import '../../../lib/services/p2p/protocol/session.dart';
import '../../../lib/services/p2p/protocol/frame.dart';

void main() {
  group('Mismatch forensic bundle (§1.2)', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('p2p_forensic_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    test('buildForensicBundle captures up to 64 local and remote frames', () {
      final s = Session();
      s.transition('start_handshake');
      s.transition('confirm');

      // Record 70 local + 70 remote frames; should see only last 64 each
      final emptyPayload = CborCodec.encode({'x': 0});
      for (int i = 1; i <= 70; i++) {
        s.recordLocalFrame(
          Frame(
            type: FrameType.move,
            sequenceNum: i,
            wallClock: 0,
            payload: emptyPayload,
          ),
        );
        s.recordRemoteFrame(
          Frame(
            type: FrameType.moveAck,
            sequenceNum: i,
            wallClock: 0,
            payload: emptyPayload,
          ),
        );
      }

      final bundle = s.buildForensicBundle(
        localMoveList: ['e2e4', 'd2d4'],
        remoteMoveList: ['e7e5'],
        modIdStr: 'classic',
        nativeLibSha: 'test-sha',
      );

      expect(bundle.localFrames.length, 64);
      expect(bundle.remoteFrames.length, 64);
      expect(bundle.localMoveList, ['e2e4', 'd2d4']);
      expect(bundle.remoteMoveList, ['e7e5']);
      expect(bundle.modId, 'classic');
      expect(bundle.nativeLibSha, 'test-sha');
    });

    test('buildForensicBundle with no frames has empty lists', () {
      final s = Session();
      final bundle = s.buildForensicBundle(
        localMoveList: [],
        remoteMoveList: [],
        modIdStr: 'heir',
        nativeLibSha: 'sha',
      );
      expect(bundle.localFrames, isEmpty);
      expect(bundle.remoteFrames, isEmpty);
    });

    test('ForensicBundle.toJson serialises correctly', () {
      final sessionId = Uint8List(32)..fillRange(0, 32, 0x01);
      final emptyPayload = CborCodec.encode({'x': 0});
      final bundle = ForensicBundle(
        sessionId: sessionId,
        localFrames: [
          Frame(
            type: FrameType.move,
            sequenceNum: 1,
            wallClock: 0,
            payload: emptyPayload,
          ),
        ],
        remoteFrames: [],
        localMoveList: ['e2e4'],
        remoteMoveList: ['e7e5'],
        modId: 'truce',
        nativeLibSha: 'abc123',
      );

      final json = bundle.toJson();
      expect(json['mod_id'], 'truce');
      expect(json['native_lib_sha'], 'abc123');
      expect(json['local_move_list'], ['e2e4']);
      expect(json['remote_move_list'], ['e7e5']);
      expect(json['local_frames_count'], 1);
      expect(json['remote_frames_count'], 0);
      expect(
        (json['session_id'] as String).length,
        64,
      ); // 32 bytes → 64 hex chars
    });

    test('ForensicBundle.writeToDisk writes bundle.json to temp dir', () async {
      final sessionId = Uint8List(4)..fillRange(0, 4, 0xAB);
      final bundle = ForensicBundle(
        sessionId: sessionId,
        localFrames: [],
        remoteFrames: [],
        localMoveList: [],
        remoteMoveList: [],
        modId: 'succession',
        nativeLibSha: 'sha256abc',
      );

      final file = await bundle.writeToDisk(overrideDir: tempDir);
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();
      expect(content, contains('succession'));
      expect(content, contains('sha256abc'));
      expect(content, contains('abababab'));
    });

    test('frame ring buffer drops oldest frames after 64', () {
      final s = Session();
      final emptyPayload = CborCodec.encode({'x': 0});
      for (int i = 1; i <= 100; i++) {
        s.recordLocalFrame(
          Frame(
            type: FrameType.move,
            sequenceNum: i,
            wallClock: 0,
            payload: emptyPayload,
          ),
        );
      }
      final bundle = s.buildForensicBundle(
        localMoveList: [],
        remoteMoveList: [],
        modIdStr: 'classic',
        nativeLibSha: '',
      );
      // Should have the last 64 frames (seq 37..100)
      expect(bundle.localFrames.length, 64);
      expect(bundle.localFrames.first.sequenceNum, 37);
      expect(bundle.localFrames.last.sequenceNum, 100);
    });
  });
}
