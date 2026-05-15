import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import '../../../lib/services/p2p/protocol/frame.dart';

void main() {
  group('Color flip commit-reveal protocol (§1.6 / §13)', () {
    final rng = Random(0xC01041);

    Uint8List _randomBytes(int len) {
      final b = Uint8List(len);
      for (int i = 0; i < len; i++) b[i] = rng.nextInt(256);
      return b;
    }

    test(
      'honest path: verifyReveal returns true for matching r and commit',
      () {
        final r = _randomBytes(32);
        final commit = ColorFlip.computeCommit(r);
        expect(ColorFlip.verifyReveal(commit, r), isTrue);
      },
    );

    test('bad reveal: r has one byte flipped → verifyReveal returns false', () {
      final r = _randomBytes(32);
      final commit = ColorFlip.computeCommit(r);
      final badR = Uint8List.fromList(r);
      badR[7] ^= 0xFF;
      expect(ColorFlip.verifyReveal(commit, badR), isFalse);
    });

    test('wrong r → verifyReveal returns false', () {
      final r = _randomBytes(32);
      final commit = ColorFlip.computeCommit(r);
      final wrongR = _randomBytes(32);
      expect(ColorFlip.verifyReveal(commit, wrongR), isFalse);
    });

    test('resolveColor is deterministic for same r values', () {
      final rA = _randomBytes(32);
      final rB = _randomBytes(32);
      final c1 = ColorFlip.resolveColor(rA, rB);
      final c2 = ColorFlip.resolveColor(rA, rB);
      expect(c1, c2);
    });

    test('resolveColor returns 0 or 1', () {
      for (int i = 0; i < 20; i++) {
        final rA = _randomBytes(32);
        final rB = _randomBytes(32);
        final color = ColorFlip.resolveColor(rA, rB);
        expect(color == 0 || color == 1, isTrue);
      }
    });

    test('buildCommitPayload includes hash field as Uint8List of 32 bytes', () {
      final r = _randomBytes(32);
      final payload = ColorFlip.buildCommitPayload(ColorFlip.computeCommit(r));
      expect(payload['hash'], isA<Uint8List>());
      expect((payload['hash'] as Uint8List).length, 32);
    });

    test('buildRevealPayload includes r field', () {
      final r = _randomBytes(32);
      final payload = ColorFlip.buildRevealPayload(r);
      expect((payload['r'] as Uint8List).length, 32);
    });

    test('color-flip payloads survive CBOR round-trip', () {
      final r = _randomBytes(32);
      final commit = ColorFlip.computeCommit(r);

      final commitPayload = ColorFlip.buildCommitPayload(commit);
      final commitFrame = Frame.withPayloadMap(
        FrameType.colorFlipCommit,
        commitPayload,
        sequenceNum: 1,
      );
      final decodedCommit = Frame.decode(commitFrame.encode()).decodePayload();
      final recoveredCommit = decodedCommit['hash'] as Uint8List;
      expect(ColorFlip.verifyReveal(recoveredCommit, r), isTrue);

      final revealPayload = ColorFlip.buildRevealPayload(r);
      final revealFrame = Frame.withPayloadMap(
        FrameType.colorFlipReveal,
        revealPayload,
        sequenceNum: 2,
      );
      final decodedReveal = Frame.decode(revealFrame.encode()).decodePayload();
      final recoveredR = decodedReveal['r'] as Uint8List;
      expect(ColorFlip.verifyReveal(commit, recoveredR), isTrue);
    });

    test('peer reveals early (before other peer): still verifiable', () {
      // Peer A reveals r before peer B has committed — r is still verifiable
      // against the commit A sent.
      final rA = _randomBytes(32);
      final commitA = ColorFlip.computeCommit(rA);
      // B hasn't committed yet; A reveals anyway
      expect(ColorFlip.verifyReveal(commitA, rA), isTrue);
    });
  });
}
