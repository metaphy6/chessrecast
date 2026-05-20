// §14.7 — Mid-game block: no UI crash, clean state-machine transition.
//
// Verifies that issuing a block mid-game:
//   1. Terminates the session with reason kBlockByeReason.
//   2. Adds the fingerprint to the BlockList.
//   3. Does not crash (no exception propagated to the test).
//
// This is a service-layer test. Widget rendering is out of scope here.
library;

import 'package:flutter_test/flutter_test.dart';
import '../../../lib/services/p2p/ui/block_list.dart';

/// Minimal simulation of a peer session state machine for testing the block
/// mid-game transition. In production, the real PeerSession would be used.
enum _SessionState { connected, ended }

class _MockPeerSession {
  _SessionState state = _SessionState.connected;
  String? byeReason;

  /// Simulate the mid-game block action.
  void blockOpponent({
    required BlockList blockList,
    required String opponentFingerprint,
  }) {
    if (state != _SessionState.connected) {
      throw StateError('Session is not connected; cannot block.');
    }
    // Add to block list.
    blockList.block(opponentFingerprint, kind: BlockKind.device);
    // Send BYE.
    byeReason = kBlockByeReason;
    state = _SessionState.ended;
  }
}

void main() {
  group('§14.7 — Mid-game block: state-machine', () {
    test('block action ends the session with kBlockByeReason', () {
      final session = _MockPeerSession();
      final blockList = BlockList();

      session.blockOpponent(
        blockList: blockList,
        opponentFingerprint: 'fp-opponent',
      );

      expect(session.state, equals(_SessionState.ended));
      expect(session.byeReason, equals(kBlockByeReason));
    });

    test('block action adds fingerprint to BlockList', () {
      final session = _MockPeerSession();
      final blockList = BlockList();

      session.blockOpponent(
        blockList: blockList,
        opponentFingerprint: 'fp-opponent',
      );

      expect(blockList.isBlocked('fp-opponent'), isTrue);
    });

    test('block action does not throw', () {
      final session = _MockPeerSession();
      final blockList = BlockList();

      expect(
        () => session.blockOpponent(
          blockList: blockList,
          opponentFingerprint: 'fp-xyz',
        ),
        returnsNormally,
      );
    });

    test('blocking an already-ended session throws StateError', () {
      final session = _MockPeerSession()..state = _SessionState.ended;
      final blockList = BlockList();

      expect(
        () => session.blockOpponent(
          blockList: blockList,
          opponentFingerprint: 'fp-xyz',
        ),
        throwsStateError,
      );
    });

    test('consecutive blocks of different opponents do not interfere', () {
      final session1 = _MockPeerSession();
      final session2 = _MockPeerSession();
      final blockList = BlockList();

      session1.blockOpponent(blockList: blockList, opponentFingerprint: 'fp-A');
      session2.blockOpponent(blockList: blockList, opponentFingerprint: 'fp-B');

      expect(blockList.isBlocked('fp-A'), isTrue);
      expect(blockList.isBlocked('fp-B'), isTrue);
      expect(session1.byeReason, equals(kBlockByeReason));
      expect(session2.byeReason, equals(kBlockByeReason));
    });
  });
}
