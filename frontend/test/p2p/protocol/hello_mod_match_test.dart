// T-P-005 §9.2 — HELLO includes signed mod id; mismatch → abort.
//
// Proof: validateHelloModId() succeeds when both peers pick the same mod,
// throws ModMismatchError when they differ, and rejects signature forgeries.
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../../lib/services/p2p/protocol/hello_mod_validator.dart';

bool _stubVerify(Uint8List pk, Uint8List msg, Uint8List sig) {
  final hmac = Hmac(sha256, pk);
  final expected = hmac.convert(msg).bytes;
  for (var i = 0; i < expected.length; i++) {
    if (sig[i] != expected[i]) return false;
  }
  return true;
}

void main() {
  final sessionId = Uint8List(32)..fillRange(0, 32, 0x1A);
  final remoteKey = Uint8List(32)..fillRange(0, 32, 0xCC);

  group('T-P-005 §9.2 — HELLO includes signed mod id; mismatch → abort', () {
    test('kValidModIds contains all seven mods', () {
      const expected = {
        'heir', 'friendly_fire', 'kings_battle', 'mercenary',
        'save_the_queen', 'succession', 'truce',
      };
      expect(kValidModIds, equals(expected));
    });

    test('matching mod id with valid signature returns true', () {
      const mod = 'mercenary';
      final sig = signHelloModPayload(
        modId: mod,
        sessionId: sessionId,
        signingKey: remoteKey,
      );
      final ok = validateHelloModId(
        localModId: mod,
        remoteModId: mod,
        remoteSessionId: sessionId,
        remotePubKey: remoteKey,
        remoteModSig: sig,
        verifyFn: _stubVerify,
      );
      expect(ok, isTrue);
    });

    test('different mod ids throw ModMismatchError', () {
      const localMod = 'heir';
      const remoteMod = 'truce';
      final sig = signHelloModPayload(
        modId: remoteMod,
        sessionId: sessionId,
        signingKey: remoteKey,
      );
      expect(
        () => validateHelloModId(
          localModId: localMod,
          remoteModId: remoteMod,
          remoteSessionId: sessionId,
          remotePubKey: remoteKey,
          remoteModSig: sig,
          verifyFn: _stubVerify,
        ),
        throwsA(isA<ModMismatchError>()),
        reason: 'mod mismatch must throw ModMismatchError → abort',
      );
    });

    test('ModMismatchError message includes both mod ids', () {
      try {
        final sig = signHelloModPayload(
          modId: 'truce',
          sessionId: sessionId,
          signingKey: remoteKey,
        );
        validateHelloModId(
          localModId: 'heir',
          remoteModId: 'truce',
          remoteSessionId: sessionId,
          remotePubKey: remoteKey,
          remoteModSig: sig,
          verifyFn: _stubVerify,
        );
        fail('Expected ModMismatchError');
      } on ModMismatchError catch (e) {
        expect(e.toString(), contains('heir'));
        expect(e.toString(), contains('truce'));
      }
    });

    test('matching mod id with forged signature returns false', () {
      const mod = 'friendly_fire';
      // Forge a signature with a different key.
      final wrongKey = Uint8List(32)..fillRange(0, 32, 0x00);
      final forgery = signHelloModPayload(
        modId: mod,
        sessionId: sessionId,
        signingKey: wrongKey,
      );
      final ok = validateHelloModId(
        localModId: mod,
        remoteModId: mod,
        remoteSessionId: sessionId,
        remotePubKey: remoteKey, // actual key — HMAC won't match
        remoteModSig: forgery,
        verifyFn: _stubVerify,
      );
      expect(ok, isFalse, reason: 'forged mod sig must be rejected');
    });

    test('mod payload includes domain separator and session id', () {
      const mod = 'kings_battle';
      final payload = buildHelloModPayload(modId: mod, sessionId: sessionId);
      // Domain separator starts at byte 0.
      const dom = 'chessrecast:hello:mod:v1';
      for (var i = 0; i < dom.length; i++) {
        expect(payload[i], equals(dom.codeUnitAt(i)));
      }
      // Session ID follows.
      final offset = dom.length;
      for (var i = 0; i < 32; i++) {
        expect(payload[offset + i], equals(sessionId[i]));
      }
    });
  });
}
