// §7.9.5 ban list persists proof test.
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/spectator/ban_list.dart';

void main() {
  group('BanList persistence §7.9.5', () {
    test('ban survives multiple isBanned queries', () {
      final bl = BanList();
      final key = Uint8List.fromList(List.generate(32, (_) => 0x77));
      bl.ban(accountPubKey: key, nowMs: 0, reason: 'test');
      for (var i = 0; i < 10; i++) {
        expect(bl.isBanned(key), isTrue,
            reason: 'ban must persist across query \$i');
      }
    });

    test('unrelated accounts are not banned', () {
      final bl = BanList();
      final bad = Uint8List.fromList(List.generate(32, (_) => 0xFF));
      final good = Uint8List.fromList(List.generate(32, (_) => 0x01));
      bl.ban(accountPubKey: bad, nowMs: 0, reason: 'abuse');
      expect(bl.isBanned(good), isFalse);
    });

    test('empty BanList has no bans', () {
      expect(BanList().allBans, isEmpty);
    });

    test('ban list supports multiple simultaneous bans', () {
      final bl = BanList();
      final keys = List.generate(10, (i) =>
          Uint8List.fromList(List.generate(32, (_) => i + 1)));
      for (final k in keys) {
        bl.ban(accountPubKey: k, nowMs: 0, reason: 'bulk');
      }
      expect(bl.allBans.length, equals(10));
      for (final k in keys) {
        expect(bl.isBanned(k), isTrue);
      }
    });
  });
}
