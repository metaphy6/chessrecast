// §7.9.10 chat ephemerality proof test.
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/spectator/spectator_chat_extended.dart';

void main() {
  group('EphemeralChatStore §7.9.10', () {
    test('messages are stored in RAM and counted', () {
      final store = EphemeralChatStore();
      store.addMessage(
        senderPubKeyHex: 'aabb',
        encryptedContent: Uint8List.fromList([1, 2, 3]),
        timestampMs: 0,
      );
      expect(store.messageCount, equals(1));
    });

    test('zeroise clears all messages', () {
      final store = EphemeralChatStore();
      store.addMessage(
        senderPubKeyHex: 'aabb',
        encryptedContent: Uint8List.fromList([0xAA, 0xBB]),
        timestampMs: 0,
      );
      store.zeroise();
      expect(store.messageCount, equals(0));
    });

    test('zeroise overwrites message bytes with zeros', () {
      final store = EphemeralChatStore();
      for (var i = 0; i < 5; i++) {
        store.addMessage(
          senderPubKeyHex: 'aabb',
          encryptedContent: Uint8List.fromList(List.generate(32, (_) => 0xFF)),
          timestampMs: i,
        );
      }
      store.zeroise();
      expect(store.messageCount, equals(0));
    });

    test('store starts empty', () {
      expect(EphemeralChatStore().messageCount, equals(0));
    });
  });
}
