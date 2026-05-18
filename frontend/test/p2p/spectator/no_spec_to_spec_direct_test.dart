// §7.9.1 no spec-to-spec direct channel proof test.
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/spectator/spectator_kdf.dart';

void main() {
  group('No spec-to-spec direct channel §7.9.1', () {
    test('SpectatorChatDir only has 3 variants', () {
      expect(SpectatorChatDir.values.length, equals(3));
    });

    test('specToHost direction is defined', () {
      expect(SpectatorChatDir.values, contains(SpectatorChatDir.specToHost));
    });

    test('hostToSpec direction is defined', () {
      expect(SpectatorChatDir.values, contains(SpectatorChatDir.hostToSpec));
    });

    test('hostToSpecBroadcast direction is defined', () {
      expect(SpectatorChatDir.values, contains(SpectatorChatDir.hostToSpecBroadcast));
    });

    test('K_view for two different spectators is different (no shared key)', () {
      final sessionMaster = Uint8List(32);
      final specA = Uint8List.fromList(List.generate(32, (i) => i + 1));
      final specB = Uint8List.fromList(List.generate(32, (i) => i + 50));
      final kvA = deriveKView(sessionMaster: sessionMaster, spectatorPubKey: specA);
      final kvB = deriveKView(sessionMaster: sessionMaster, spectatorPubKey: specB);
      expect(kvA, isNot(equals(kvB)));
    });
  });
}
