import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:crypto/crypto.dart';
import '../../../lib/services/p2p/protocol/frame.dart';

// Stub signing: HMAC-SHA256 padded to 64 bytes.
Uint8List _sign(Uint8List key, Uint8List message) {
  final hmac = Hmac(sha256, key);
  final h = hmac.convert(message).bytes;
  final sig64 = Uint8List(64)..setRange(0, h.length, h);
  return sig64;
}

/// Simulates the full transcript signing / counter-sign flow for BYE.
Map<String, dynamic> _buildByePayload({
  required String result,
  required List<String> moves,
  required Uint8List sessionId,
  required Uint8List signingKey,
}) {
  final payloadWithoutSig = CborCodec.encode({
    'result': result,
    'moves': moves,
  });
  final toSign = byeMessageToSign(sessionId, payloadWithoutSig);
  final sig = _sign(signingKey, toSign);
  return {'result': result, 'moves': moves, 'sig': sig};
}

void main() {
  group('Transcript signing — BYE signed frame (§1.8 / §7)', () {
    final sessionId = Uint8List(32)..fillRange(0, 32, 0x0A);
    final keyA = Uint8List(32)..fillRange(0, 32, 0xAA);
    final keyB = Uint8List(32)..fillRange(0, 32, 0xBB);
    final moves = ['e2e4', 'e7e5', 'g1f3', 'b8c6'];

    test('BYE frame is signed and sig survives round-trip', () {
      final payload = _buildByePayload(
        result: '1-0',
        moves: moves,
        sessionId: sessionId,
        signingKey: keyA,
      );

      final frame = Frame.withPayloadMap(
        FrameType.bye,
        payload,
        sequenceNum: 1,
      );
      final decoded = Frame.decode(frame.encode());
      expect(decoded.type, FrameType.bye);

      final dp = decoded.decodePayload();
      expect(dp['result'], '1-0');
      expect((dp['sig'] as Uint8List).length, 64);
    });

    test('BYE sig covers session_id — different session → different sig', () {
      final sid1 = Uint8List(32)..fillRange(0, 32, 0x01);
      final sid2 = Uint8List(32)..fillRange(0, 32, 0x02);
      final payload1 = CborCodec.encode({'result': '1-0', 'moves': moves});
      final payload2 = CborCodec.encode({'result': '1-0', 'moves': moves});

      final m1 = byeMessageToSign(sid1, payload1);
      final m2 = byeMessageToSign(sid2, payload2);

      int diff = 0;
      for (int i = 0; i < 32; i++) diff |= m1[i] ^ m2[i];
      expect(diff, isNot(0));
    });

    test('counter-signed transcript: B countersigns A\'s BYE', () {
      // A signs the BYE
      final payloadA = _buildByePayload(
        result: '1-0',
        moves: moves,
        sessionId: sessionId,
        signingKey: keyA,
      );
      final frameA = Frame.withPayloadMap(
        FrameType.bye,
        payloadA,
        sequenceNum: 1,
      );
      final encodedA = frameA.encode();

      // B receives A's BYE and countersigns: signs the message-to-sign over
      // the full A payload CBOR (excluding A's sig field), producing sigB.
      final aPayloadWithoutSig = CborCodec.encode({
        'result': '1-0',
        'moves': moves,
      });
      final toSignB = byeMessageToSign(sessionId, aPayloadWithoutSig);
      final sigB = _sign(keyB, toSignB);

      final countersignedPayload = {
        'result': '1-0',
        'moves': moves,
        'sig_a': payloadA['sig'],
        'sig_b': sigB,
      };
      final frameB = Frame.withPayloadMap(
        FrameType.bye,
        countersignedPayload,
        sequenceNum: 2,
      );
      final decoded = Frame.decode(frameB.encode()).decodePayload();

      expect((decoded['sig_a'] as Uint8List).length, 64);
      expect((decoded['sig_b'] as Uint8List).length, 64);
    });

    test('BYE payload with move list survives CBOR round-trip', () {
      final payload = {
        'result': '0-1',
        'moves': ['d2d4', 'd7d5', 'c2c4'],
        'sig': Uint8List(64),
      };
      final frame = Frame.withPayloadMap(
        FrameType.bye,
        payload,
        sequenceNum: 1,
      );
      final dp = Frame.decode(frame.encode()).decodePayload();
      expect(dp['result'], '0-1');
      expect((dp['moves'] as List).length, 3);
    });
  });
}
