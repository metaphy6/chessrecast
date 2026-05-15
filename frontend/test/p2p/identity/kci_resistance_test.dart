import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/identity/identity.dart';

void main() {
  group('KCI resistance (§2.9)', () {
    late Uint8List sessionMaster;

    setUp(() {
      final alice = SessionKdf.generateEphemeral();
      final bob = SessionKdf.generateEphemeral();
      final ecdh = SessionKdf.sharedSecret(
        myPrivateKey: alice.privateKey,
        theirPublicKey: bob.publicKey,
      );
      sessionMaster = SessionKdf.sessionMaster(
        ecdhSecret: ecdh,
        sessionId: alice.publicKey,
      );
    });

    test('generateMac returns 32-byte MAC', () {
      final auth = KciAuthenticator(sessionMaster: sessionMaster);
      final transcriptHash = Uint8List(32)..fillRange(0, 32, 0x42);
      final mac = auth.generateMac(transcriptHash);
      expect(mac.length, equals(32));
    });

    test('verifyMac succeeds for correct transcript', () {
      final auth = KciAuthenticator(sessionMaster: sessionMaster);
      final transcriptHash = Uint8List(32)..fillRange(0, 32, 0x42);
      final mac = auth.generateMac(transcriptHash);
      // Should not throw
      auth.verifyMac(transcriptHash, mac);
    });

    test('verifyMac throws KciVerifyFailedError for tampered MAC', () {
      final auth = KciAuthenticator(sessionMaster: sessionMaster);
      final transcriptHash = Uint8List(32)..fillRange(0, 32, 0x42);
      final mac = auth.generateMac(transcriptHash);
      final tamperedMac = Uint8List.fromList(mac);
      tamperedMac[0] ^= 0xFF;
      expect(
        () => auth.verifyMac(transcriptHash, tamperedMac),
        throwsA(isA<KciVerifyFailedError>()),
      );
    });

    test('verifyMac throws KciVerifyFailedError for tampered transcript', () {
      final auth = KciAuthenticator(sessionMaster: sessionMaster);
      final transcriptHash = Uint8List(32)..fillRange(0, 32, 0x42);
      final mac = auth.generateMac(transcriptHash);
      final tamperedHash = Uint8List.fromList(transcriptHash);
      tamperedHash[0] ^= 0x01;
      expect(
        () => auth.verifyMac(tamperedHash, mac),
        throwsA(isA<KciVerifyFailedError>()),
      );
    });

    test('KCI key is separate from AEAD keys (key separation)', () {
      final auth = KciAuthenticator(sessionMaster: sessionMaster);
      final bundle = SessionKdf.deriveSubkeys(sessionMaster);
      // The KCI key is derived from session master too, but should differ
      expect(auth.kKci, isNot(equals(bundle.kAeadChessA2b)));
      expect(auth.kKci, isNot(equals(bundle.kTranscriptKdf)));
    });

    test('different session masters produce different KCI keys', () {
      final alice2 = SessionKdf.generateEphemeral();
      final bob2 = SessionKdf.generateEphemeral();
      final ecdh2 = SessionKdf.sharedSecret(
        myPrivateKey: alice2.privateKey,
        theirPublicKey: bob2.publicKey,
      );
      final sessionMaster2 = SessionKdf.sessionMaster(
        ecdhSecret: ecdh2,
        sessionId: alice2.publicKey,
      );
      final auth1 = KciAuthenticator(sessionMaster: sessionMaster);
      final auth2 = KciAuthenticator(sessionMaster: sessionMaster2);
      expect(auth1.kKci, isNot(equals(auth2.kKci)));
    });
  });
}
