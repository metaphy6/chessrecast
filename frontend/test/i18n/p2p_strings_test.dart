// Proof test for roadmap leaf 8.1.b1:
// All P2P UI strings are in frontend/lib/l10n/ ARB files.
// RTL locale (ar) key-set must match English (en) key-set.
//
// This test is intentionally file-system based so it runs without Flutter
// bindings and works in headless CI.

import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P2P ARB strings', () {
    late Map<String, dynamic> enArb;

    setUpAll(() {
      final enFile = File('lib/l10n/app_en.arb');
      expect(
        enFile.existsSync(),
        isTrue,
        reason: 'lib/l10n/app_en.arb must exist',
      );
      enArb = jsonDecode(enFile.readAsStringSync()) as Map<String, dynamic>;
    });

    test('app_en.arb contains all required P2P string keys', () {
      const requiredKeys = [
        // Connection states
        'p2pConnecting',
        'p2pConnected',
        'p2pDisconnected',
        'p2pReconnecting',
        'p2pFailed',
        'p2pWaiting',
        // Lobby / invite
        'p2pInviteFriend',
        'p2pShareLink',
        'p2pJoinGame',
        'p2pCancelInvite',
        // Recovery code
        'p2pRecoveryCodeTitle',
        'p2pRecoveryCodeInstructions',
        'p2pRecoveryCodeCopy', // intentionally omitted in impl per spec (no clipboard)
        'p2pRecoveryCodeVerify',
        'p2pRecoveryCodeSuccess',
        'p2pRecoveryWordlistFallbackNote',
        // Game events
        'p2pOpponentLeft',
        'p2pYouLeft',
        'p2pGameDraw',
        'p2pGameResign',
        // Error / failure messages
        'p2pErrorIceFailed',
        'p2pErrorVersionMismatch',
        'p2pErrorModMismatch',
        'p2pErrorGeneric',
      ];

      for (final key in requiredKeys) {
        expect(
          enArb.containsKey(key),
          isTrue,
          reason: 'app_en.arb must contain key "$key"',
        );
      }
    });

    test('app_en.arb has no empty string values', () {
      for (final entry in enArb.entries) {
        if (entry.key.startsWith('@')) continue; // metadata keys
        if (entry.value is String) {
          expect(
            (entry.value as String).isNotEmpty,
            isTrue,
            reason: 'Key "${entry.key}" must not be empty',
          );
        }
      }
    });

    test('app_ar.arb (RTL) key-set matches app_en.arb', () {
      final arFile = File('lib/l10n/app_ar.arb');
      expect(
        arFile.existsSync(),
        isTrue,
        reason: 'lib/l10n/app_ar.arb must exist for RTL verification',
      );
      final arArb = jsonDecode(arFile.readAsStringSync()) as Map<String, dynamic>;

      final enKeys = enArb.keys.where((k) => !k.startsWith('@')).toSet();
      final arKeys = arArb.keys.where((k) => !k.startsWith('@')).toSet();

      final missing = enKeys.difference(arKeys);
      expect(
        missing,
        isEmpty,
        reason: 'Arabic ARB is missing keys present in English: $missing',
      );
    });

    test('app_en.arb has @@locale set to en', () {
      expect(enArb['@@locale'], equals('en'));
    });

    test('app_ar.arb has @@locale set to ar', () {
      final arFile = File('lib/l10n/app_ar.arb');
      final arArb = jsonDecode(arFile.readAsStringSync()) as Map<String, dynamic>;
      expect(arArb['@@locale'], equals('ar'));
    });
  });
}
