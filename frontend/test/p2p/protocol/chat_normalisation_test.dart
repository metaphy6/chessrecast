import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import '../../../lib/services/p2p/protocol/frame.dart';

// Helper: build a CHAT frame payload.
Map<String, dynamic> _buildChatPayload(String text) {
  return {'text': text};
}

void main() {
  group('Chat normalisation — NFC + 512-byte limit (§1.6 / §6)', () {
    test('ASCII message survives CBOR round-trip intact', () {
      const msg = 'Hello, world!';
      final payload = _buildChatPayload(msg);
      final frame = Frame.withPayloadMap(
        FrameType.chat,
        payload,
        sequenceNum: 1,
      );
      final dp = Frame.decode(frame.encode()).decodePayload();
      expect(dp['text'], msg);
    });

    test('UTF-8 message (CJK) survives CBOR round-trip intact', () {
      const msg = '你好世界'; // CJK characters
      final payload = _buildChatPayload(msg);
      final frame = Frame.withPayloadMap(
        FrameType.chat,
        payload,
        sequenceNum: 1,
      );
      final dp = Frame.decode(frame.encode()).decodePayload();
      expect(dp['text'], msg);
    });

    test('NFC-normalised form is preserved on round-trip', () {
      // "é" as NFC (U+00E9) vs NFD (e + combining accent U+0301)
      // We represent the text as a single NFC codepoint.
      const nfcText = '\u00e9'; // é as NFC
      final payload = _buildChatPayload(nfcText);
      final frame = Frame.withPayloadMap(
        FrameType.chat,
        payload,
        sequenceNum: 1,
      );
      final dp = Frame.decode(frame.encode()).decodePayload();
      // After round-trip the text should be unchanged (NFC form preserved)
      expect(dp['text'], nfcText);
      // The round-tripped text is exactly 1 codepoint
      expect((dp['text'] as String).runes.length, 1);
    });

    test('message exactly at 512-byte limit is allowed', () {
      // Build a string that UTF-8 encodes to exactly 512 bytes
      final text = 'a' * 512;
      final bytes = utf8.encode(text);
      expect(bytes.length, 512);
      // A real protocol layer would enforce this limit; here we test the
      // frame codec doesn't truncate.
      final payload = _buildChatPayload(text);
      final frame = Frame.withPayloadMap(
        FrameType.chat,
        payload,
        sequenceNum: 1,
      );
      final dp = Frame.decode(frame.encode()).decodePayload();
      expect((dp['text'] as String).length, 512);
    });

    test(
      'message over 512 UTF-8 bytes should be rejected by the protocol layer',
      () {
        // This test verifies that 513-byte text is representable in CBOR (codec
        // does not enforce the limit — that is the application layer's job).
        // The purpose is to document that the codec is not the enforcement point.
        final overLimit = 'a' * 513;
        final payload = _buildChatPayload(overLimit);
        // Frame codec must NOT truncate or throw — it is the app layer's job
        expect(
          () => Frame.withPayloadMap(FrameType.chat, payload, sequenceNum: 1),
          returnsNormally,
        );
      },
    );

    test('empty message survives round-trip', () {
      const msg = '';
      final payload = _buildChatPayload(msg);
      final frame = Frame.withPayloadMap(
        FrameType.chat,
        payload,
        sequenceNum: 1,
      );
      final dp = Frame.decode(frame.encode()).decodePayload();
      expect(dp['text'], '');
    });

    test('message with emoji survives round-trip', () {
      const msg = 'Great move! 🎉♟️';
      final payload = _buildChatPayload(msg);
      final frame = Frame.withPayloadMap(
        FrameType.chat,
        payload,
        sequenceNum: 1,
      );
      final dp = Frame.decode(frame.encode()).decodePayload();
      expect(dp['text'], msg);
    });
  });
}
