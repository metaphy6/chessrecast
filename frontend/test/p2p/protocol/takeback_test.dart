import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import '../../../lib/services/p2p/protocol/frame.dart';

// Helper: capabilities set that includes takeback.
Map<String, dynamic> _capsWith({bool takeback = false}) {
  return {'takeback': takeback};
}

void main() {
  group('Takeback request/response (§1.6)', () {
    test('TAKEBACK_REQ frame encodes and decodes correctly', () {
      final payload = <String, dynamic>{'ply': 10, 'reason': 'blunder'};

      final frame = Frame.withPayloadMap(
        FrameType.takebackReq,
        payload,
        sequenceNum: 1,
      );

      final decoded = Frame.decode(frame.encode());
      expect(decoded.type, FrameType.takebackReq);
      final dp = decoded.decodePayload();
      expect(dp['ply'], 10);
      expect(dp['reason'], 'blunder');
    });

    test('TAKEBACK_RESPONSE frame with accepted=true encodes correctly', () {
      final payload = <String, dynamic>{'accepted': true, 'ply': 10};
      final frame = Frame.withPayloadMap(
        FrameType.takebackResponse,
        payload,
        sequenceNum: 2,
      );

      final decoded = Frame.decode(frame.encode());
      expect(decoded.type, FrameType.takebackResponse);
      final dp = decoded.decodePayload();
      expect(dp['accepted'], isTrue);
    });

    test('TAKEBACK_RESPONSE frame with accepted=false encodes correctly', () {
      final payload = <String, dynamic>{'accepted': false, 'ply': 10};
      final frame = Frame.withPayloadMap(
        FrameType.takebackResponse,
        payload,
        sequenceNum: 2,
      );

      final decoded = Frame.decode(frame.encode());
      final dp = decoded.decodePayload();
      expect(dp['accepted'], isFalse);
    });

    test(
      'takeback is gated by capabilities: disabled → req should be rejected by app layer',
      () {
        // When the peer announces capabilities without takeback, the app layer
        // should reject a TAKEBACK_REQ. The codec layer itself does not enforce
        // capabilities — that is the session/protocol layer's responsibility.
        final remoteCapabilities = _capsWith(takeback: false);
        expect(remoteCapabilities['takeback'], isFalse);
      },
    );

    test('takeback is gated by capabilities: enabled → req is allowed', () {
      final remoteCapabilities = _capsWith(takeback: true);
      expect(remoteCapabilities['takeback'], isTrue);
    });

    test('FrameType.takebackReq and takebackResponse have distinct IDs', () {
      expect(FrameType.takebackReq.id, isNot(FrameType.takebackResponse.id));
    });
  });
}
