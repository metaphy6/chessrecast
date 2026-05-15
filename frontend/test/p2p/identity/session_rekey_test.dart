import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/identity/identity.dart';

Uint8List _freshMaster() {
  final alice = SessionKdf.generateEphemeral();
  final bob = SessionKdf.generateEphemeral();
  final ecdh = SessionKdf.sharedSecret(
    myPrivateKey: alice.privateKey,
    theirPublicKey: bob.publicKey,
  );
  return SessionKdf.sessionMaster(ecdhSecret: ecdh, sessionId: alice.publicKey);
}

void main() {
  group('SessionRekey — re-key procedure (§2.10)', () {
    test('rekey returns a 32-byte new session master', () {
      final rekey = SessionRekey();
      final prevMaster = _freshMaster();
      final myNew = SessionKdf.generateEphemeral();
      final theirNew = SessionKdf.generateEphemeral();
      final result = rekey.rekey(
        prevSessionMaster: prevMaster,
        myNewPrivateKey: myNew.privateKey,
        theirNewPublicKey: theirNew.publicKey,
      );
      expect(result.newSessionMaster.length, equals(32));
    });

    test('rekey increments keygenCounter', () {
      final rekey = SessionRekey();
      expect(rekey.keygenCounter, equals(0));
      final master = _freshMaster();
      final my = SessionKdf.generateEphemeral();
      final their = SessionKdf.generateEphemeral();
      rekey.rekey(
        prevSessionMaster: master,
        myNewPrivateKey: my.privateKey,
        theirNewPublicKey: their.publicKey,
      );
      expect(rekey.keygenCounter, equals(1));
    });

    test('rekey zeroes the previous session master', () {
      final rekey = SessionRekey();
      final prevMaster = _freshMaster();
      final my = SessionKdf.generateEphemeral();
      final their = SessionKdf.generateEphemeral();
      rekey.rekey(
        prevSessionMaster: prevMaster,
        myNewPrivateKey: my.privateKey,
        theirNewPublicKey: their.publicKey,
      );
      // prevMaster should be zeroed (forward secrecy)
      expect(prevMaster.every((b) => b == 0), isTrue);
    });

    test('two consecutive rekeys produce different masters', () {
      final rekey = SessionRekey();
      final master1 = _freshMaster();
      final my1 = SessionKdf.generateEphemeral();
      final their1 = SessionKdf.generateEphemeral();
      final result1 = rekey.rekey(
        prevSessionMaster: master1,
        myNewPrivateKey: my1.privateKey,
        theirNewPublicKey: their1.publicKey,
      );
      final my2 = SessionKdf.generateEphemeral();
      final their2 = SessionKdf.generateEphemeral();
      final master2 = Uint8List.fromList(result1.newSessionMaster);
      final result2 = rekey.rekey(
        prevSessionMaster: master2,
        myNewPrivateKey: my2.privateKey,
        theirNewPublicKey: their2.publicKey,
      );
      expect(result1.newSessionMaster, isNot(equals(result2.newSessionMaster)));
      expect(result2.keygenCounter, equals(2));
    });

    test('RekeyResult carries keygenCounter', () {
      final rekey = SessionRekey();
      final master = _freshMaster();
      final my = SessionKdf.generateEphemeral();
      final their = SessionKdf.generateEphemeral();
      final result = rekey.rekey(
        prevSessionMaster: master,
        myNewPrivateKey: my.privateKey,
        theirNewPublicKey: their.publicKey,
      );
      expect(result.keygenCounter, equals(1));
    });
  });
}
