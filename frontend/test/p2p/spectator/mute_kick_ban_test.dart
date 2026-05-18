// §7.9.5 mute, kick, ban proof test.
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/spectator/ban_list.dart';

void main() {
  group('SpectatorModerationSession §7.9.5 mute/kick', () {
    test('muted spectator shows as muted', () {
      final session = SpectatorModerationSession();
      final key = Uint8List.fromList(List.generate(32, (_) => 0x01));
      session.mute(key);
      expect(session.isMuted(key), isTrue);
    });

    test('unmuted spectator is no longer muted', () {
      final session = SpectatorModerationSession();
      final key = Uint8List.fromList(List.generate(32, (_) => 0x02));
      session.mute(key);
      session.unmute(key);
      expect(session.isMuted(key), isFalse);
    });

    test('kicked spectator shows as kicked', () {
      final session = SpectatorModerationSession();
      final key = Uint8List.fromList(List.generate(32, (_) => 0x03));
      session.kick(key);
      expect(session.isKicked(key), isTrue);
    });

    test('kicked spectator error code is SPECTATOR_KICKED', () {
      expect(kSpectatorKicked, equals('SPECTATOR_KICKED'));
    });

    test('other spectators are unaffected by mute', () {
      final session = SpectatorModerationSession();
      final bad = Uint8List.fromList(List.generate(32, (_) => 0xAA));
      final good = Uint8List.fromList(List.generate(32, (_) => 0xBB));
      session.mute(bad);
      expect(session.isMuted(good), isFalse);
    });
  });

  group('BanList §7.9.5 persistent ban', () {
    test('banned account is detected', () {
      final bl = BanList();
      final key = Uint8List.fromList(List.generate(32, (_) => 0xDE));
      bl.ban(accountPubKey: key, nowMs: 0, reason: 'harassment');
      expect(bl.isBanned(key), isTrue);
    });

    test('unbanned account is no longer banned', () {
      final bl = BanList();
      final key = Uint8List.fromList(List.generate(32, (_) => 0xAA));
      bl.ban(accountPubKey: key, nowMs: 0);
      bl.unban(key);
      expect(bl.isBanned(key), isFalse);
    });

    test('allBans returns all banned accounts', () {
      final bl = BanList();
      bl.ban(accountPubKey: Uint8List.fromList(List.generate(32, (_) => 1)), nowMs: 0);
      bl.ban(accountPubKey: Uint8List.fromList(List.generate(32, (_) => 2)), nowMs: 0);
      expect(bl.allBans.length, equals(2));
    });

    test('ban record preserves reason and timestamp', () {
      final before = DateTime.now().millisecondsSinceEpoch;
      final bl = BanList();
      final key = Uint8List.fromList(List.generate(32, (_) => 0x42));
      bl.ban(accountPubKey: key, nowMs: before, reason: 'spamming');
      final record = bl.allBans.first;
      expect(record.reason, equals('spamming'));
      expect(record.bannedAtMs, greaterThanOrEqualTo(before));
    });
  });
}
