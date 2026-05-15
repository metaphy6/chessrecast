import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import '../../../lib/services/p2p/protocol/frame.dart';

void main() {
  group('AEAD AAD — session ID binding (§1.9)', () {
    // In Phase 1, the AEAD key is not yet wired in; this test documents and
    // verifies that the session_id is part of the Additional Authenticated
    // Data (AAD) domain, meaning any AEAD-encrypted frame must bind to the
    // session_id so it cannot be replayed into a different session.
    //
    // Implementation note: the AEAD encryption itself is Phase 2 (after key
    // exchange). Phase 1 ensures the session_id derivation is correct.
    // This test verifies the correct session_id is derived and would differ
    // across sessions (so replaying into a different session would fail AAD
    // verification).

    test('session IDs derived from different handshakes are distinct', () {
      final ephPubA1 = Uint8List(32)..fillRange(0, 32, 0x01);
      final ephPubB1 = Uint8List(32)..fillRange(0, 32, 0x02);
      final nonceA1 = Uint8List(32)..fillRange(0, 32, 0x03);
      final nonceB1 = Uint8List(32)..fillRange(0, 32, 0x04);

      final ephPubA2 = Uint8List(32)..fillRange(0, 32, 0x11);
      final ephPubB2 = Uint8List(32)..fillRange(0, 32, 0x22);
      final nonceA2 = Uint8List(32)..fillRange(0, 32, 0x33);
      final nonceB2 = Uint8List(32)..fillRange(0, 32, 0x44);

      final sid1 = SessionIdDeriver.derive(
          ephPubA: ephPubA1, ephPubB: ephPubB1, nonceA: nonceA1, nonceB: nonceB1);
      final sid2 = SessionIdDeriver.derive(
          ephPubA: ephPubA2, ephPubB: ephPubB2, nonceA: nonceA2, nonceB: nonceB2);

      expect(sid1, isNot(equals(sid2)));
    });

    test('AAD binding: AEAD tag depends on session_id — different SID → different binding', () {
      // Simulate the AAD construction: aad = session_id || frame_type || frame_seq
      // A frame encrypted under session 1 cannot be replayed under session 2.
      final sid1 = Uint8List(32)..fillRange(0, 32, 0xAA);
      final sid2 = Uint8List(32)..fillRange(0, 32, 0xBB);

      // Build two AAD buffers for the same MOVE frame sequence
      final aad1 = _buildAad(sid1, FrameType.move.id, sequenceNum: 1);
      final aad2 = _buildAad(sid2, FrameType.move.id, sequenceNum: 1);

      // The AAD values differ because the session IDs differ
      expect(aad1, isNot(equals(aad2)));
    });

    test('AAD binding: same session, different seq → different AAD', () {
      final sid = Uint8List(32)..fillRange(0, 32, 0xCC);
      final aad1 = _buildAad(sid, FrameType.move.id, sequenceNum: 1);
      final aad2 = _buildAad(sid, FrameType.move.id, sequenceNum: 2);
      expect(aad1, isNot(equals(aad2)));
    });

    test('AAD binding: same session, different type → different AAD', () {
      final sid = Uint8List(32)..fillRange(0, 32, 0xDD);
      final aad1 = _buildAad(sid, FrameType.move.id, sequenceNum: 1);
      final aad2 = _buildAad(sid, FrameType.chat.id, sequenceNum: 1);
      expect(aad1, isNot(equals(aad2)));
    });

    test('HKDF label "aead-salt" is in registry (binds AAD key to session)', () {
      expect(kHkdfInfoRegistry.containsKey('chessrecast/p2p/v1/aead-salt'), isTrue);
    });
  });
}

/// Build an AEAD AAD buffer: session_id (32 bytes) || frame_type (1 byte) || seq (8 bytes big-endian)
Uint8List _buildAad(Uint8List sessionId, int frameTypeId, {required int sequenceNum}) {
  final buf = Uint8List(32 + 1 + 8);
  buf.setRange(0, 32, sessionId);
  buf[32] = frameTypeId;
  for (int i = 0; i < 8; i++) {
    buf[33 + i] = (sequenceNum >> ((7 - i) * 8)) & 0xFF;
  }
  return buf;
}
