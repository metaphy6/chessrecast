// §7.8.5 no spectator enumeration proof test (Dart side).
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/spectator/spectator_roster_privacy.dart';

void main() {
  group('SpectatorRosterPrivacy §7.8.5', () {
    test('host (issuing peer) sees full roster', () {
      final privacy = SpectatorRosterPrivacy();
      privacy.addSpectator(Uint8List.fromList(List.generate(32, (i) => i + 1)));
      privacy.addSpectator(Uint8List.fromList(List.generate(32, (i) => i + 2)));
      final view = privacy.viewFor(forIssuingPeer: true);
      expect(view.fullRoster.length, equals(2));
    });

    test('spectator sees only own join confirmation', () {
      final privacy = SpectatorRosterPrivacy();
      final myKey = Uint8List.fromList(List.generate(32, (i) => i + 10));
      final otherKey = Uint8List.fromList(List.generate(32, (i) => i + 20));
      privacy.addSpectator(myKey);
      privacy.addSpectator(otherKey);

      final view = privacy.viewFor(forIssuingPeer: false, forSpectatorPubKey: myKey);
      expect(view.ownJoinConfirmation, isNotNull);
    });

    test('non-issuing peer sees empty roster', () {
      final privacy = SpectatorRosterPrivacy();
      privacy.addSpectator(Uint8List.fromList(List.generate(32, (i) => i + 30)));
      final view = privacy.viewFor(forIssuingPeer: false);
      expect(view.fullRoster, isEmpty);
      expect(view.ownJoinConfirmation, isNull);
    });

    test('spectator cannot enumerate other spectators', () {
      final privacy = SpectatorRosterPrivacy();
      final myKey = Uint8List.fromList(List.generate(32, (_) => 0xAA));
      final enemyKey = Uint8List.fromList(List.generate(32, (_) => 0xBB));
      privacy.addSpectator(myKey);
      privacy.addSpectator(enemyKey);

      final view = privacy.viewFor(forIssuingPeer: false, forSpectatorPubKey: myKey);
      // view contains ownJoinConfirmation only; fullRoster is empty for non-issuing.
      expect(view.fullRoster, isEmpty);
    });
  });
}
