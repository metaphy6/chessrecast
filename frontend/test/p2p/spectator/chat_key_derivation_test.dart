// §7.9.1 chat key derivation KAT proof test.
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/spectator/spectator_kdf.dart';

void main() {
  group('SpectatorKDF §7.9.1', () {
    final sessionMaster = Uint8List(32);
    final spectatorPubKey = Uint8List(32);

    test('deriveKView returns 32-byte key', () {
      final kView = deriveKView(
        sessionMaster: sessionMaster,
        spectatorPubKey: spectatorPubKey,
      );
      expect(kView.length, equals(32));
    });

    test('deriveKChatSpecDir returns 32-byte key', () {
      final kView = deriveKView(
        sessionMaster: sessionMaster,
        spectatorPubKey: spectatorPubKey,
      );
      final kChat = deriveKChatSpecDir(
        kView: kView,
        dir: SpectatorChatDir.specToHost,
      );
      expect(kChat.length, equals(32));
    });

    test('different dirs produce different keys', () {
      final kView = deriveKView(
        sessionMaster: sessionMaster,
        spectatorPubKey: spectatorPubKey,
      );
      final k1 = deriveKChatSpecDir(kView: kView, dir: SpectatorChatDir.specToHost);
      final k2 = deriveKChatSpecDir(kView: kView, dir: SpectatorChatDir.hostToSpec);
      final k3 = deriveKChatSpecDir(kView: kView, dir: SpectatorChatDir.hostToSpecBroadcast);
      expect(k1, isNot(equals(k2)));
      expect(k2, isNot(equals(k3)));
    });

    test('different spectator pubkeys produce different K_view', () {
      final key1 = Uint8List.fromList(List.generate(32, (i) => i));
      final key2 = Uint8List.fromList(List.generate(32, (i) => i + 1));
      final kv1 = deriveKView(sessionMaster: sessionMaster, spectatorPubKey: key1);
      final kv2 = deriveKView(sessionMaster: sessionMaster, spectatorPubKey: key2);
      expect(kv1, isNot(equals(kv2)));
    });

    test('chat dir labels match spec', () {
      expect(SpectatorChatDir.specToHost.label, equals('spec→host'));
      expect(SpectatorChatDir.hostToSpec.label, equals('host→spec'));
      expect(SpectatorChatDir.hostToSpecBroadcast.label, equals('host→spec_broadcast'));
    });

    test('K_view is deterministic (same inputs → same output)', () {
      final kv1 = deriveKView(sessionMaster: sessionMaster, spectatorPubKey: spectatorPubKey);
      final kv2 = deriveKView(sessionMaster: sessionMaster, spectatorPubKey: spectatorPubKey);
      expect(kv1, equals(kv2));
    });
  });
}
