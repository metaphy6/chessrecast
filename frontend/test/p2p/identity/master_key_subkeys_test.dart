import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/identity/identity.dart';

void main() {
  group('MasterKey — 6 sub-keys are all distinct (§2.3 key separation)', () {
    test('all sub-keys have length 32', () {
      final alice = SessionKdf.generateEphemeral();
      final bob = SessionKdf.generateEphemeral();
      final ecdh = SessionKdf.sharedSecret(
        myPrivateKey: alice.privateKey,
        theirPublicKey: bob.publicKey,
      );
      final master = SessionKdf.sessionMaster(
        ecdhSecret: ecdh,
        sessionId: alice.publicKey,
      );
      final bundle = SessionKdf.deriveSubkeys(master);
      for (final k in bundle.allKeys) {
        expect(k.length, equals(32));
      }
    });

    test('all 6 sub-keys are distinct from each other', () {
      final alice = SessionKdf.generateEphemeral();
      final bob = SessionKdf.generateEphemeral();
      final ecdh = SessionKdf.sharedSecret(
        myPrivateKey: alice.privateKey,
        theirPublicKey: bob.publicKey,
      );
      final master = SessionKdf.sessionMaster(
        ecdhSecret: ecdh,
        sessionId: alice.publicKey,
      );
      final bundle = SessionKdf.deriveSubkeys(master);
      final keys = bundle.allKeys;
      // Check every pair is different
      for (int i = 0; i < keys.length; i++) {
        for (int j = i + 1; j < keys.length; j++) {
          expect(
            keys[i],
            isNot(equals(keys[j])),
            reason: 'Sub-keys $i and $j must not be equal',
          );
        }
      }
    });

    test('sub-keys differ between sessions', () {
      final aliceA = SessionKdf.generateEphemeral();
      final bobA = SessionKdf.generateEphemeral();
      final aliceB = SessionKdf.generateEphemeral();
      final bobB = SessionKdf.generateEphemeral();

      final ecdhA = SessionKdf.sharedSecret(
        myPrivateKey: aliceA.privateKey,
        theirPublicKey: bobA.publicKey,
      );
      final ecdhB = SessionKdf.sharedSecret(
        myPrivateKey: aliceB.privateKey,
        theirPublicKey: bobB.publicKey,
      );

      final masterA = SessionKdf.sessionMaster(
        ecdhSecret: ecdhA,
        sessionId: aliceA.publicKey,
      );
      final masterB = SessionKdf.sessionMaster(
        ecdhSecret: ecdhB,
        sessionId: aliceB.publicKey,
      );

      final bundleA = SessionKdf.deriveSubkeys(masterA);
      final bundleB = SessionKdf.deriveSubkeys(masterB);

      expect(bundleA.kAeadChessA2b, isNot(equals(bundleB.kAeadChessA2b)));
    });

    test('kAeadChessA2b != kAeadChessB2a (direction separation)', () {
      final alice = SessionKdf.generateEphemeral();
      final bob = SessionKdf.generateEphemeral();
      final ecdh = SessionKdf.sharedSecret(
        myPrivateKey: alice.privateKey,
        theirPublicKey: bob.publicKey,
      );
      final master = SessionKdf.sessionMaster(
        ecdhSecret: ecdh,
        sessionId: alice.publicKey,
      );
      final bundle = SessionKdf.deriveSubkeys(master);
      expect(bundle.kAeadChessA2b, isNot(equals(bundle.kAeadChessB2a)));
    });
  });
}
