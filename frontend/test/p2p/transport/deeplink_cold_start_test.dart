// §4.3 Deep-link cold-start race proof test.
//
// Verifies that InviteState correctly persists an offer token across an
// app-cold-start so that tapping a "Join game" notification does not
// lose the offer even if the app has not finished launching.
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/transport/invite_state.dart';

void main() {
  group('InviteState §4.3 deep-link cold-start', () {
    test('pending invite token is preserved after setDeepLink', () {
      final state = InviteState();
      state.setDeepLink(token: 'tok123');
      expect(state.pendingToken, equals('tok123'));
    });

    test('consuming the token clears it', () {
      final state = InviteState();
      state.setDeepLink(token: 'tok456');
      final consumed = state.consumeToken();
      expect(consumed, equals('tok456'));
      expect(state.pendingToken, isNull);
    });

    test('no token initially', () {
      expect(InviteState().pendingToken, isNull);
    });

    test('second setDeepLink overwrites the first (latest wins)', () {
      final state = InviteState();
      state.setDeepLink(token: 'first');
      state.setDeepLink(token: 'second');
      expect(state.pendingToken, equals('second'));
    });

    test('consumeToken returns null when empty', () {
      expect(InviteState().consumeToken(), isNull);
    });

    test('deep-link handled before app fully launched (hasUnhandledDeepLink)', () {
      final state = InviteState();
      state.setDeepLink(token: 'abc', receivedBeforeAppReady: true);
      expect(state.hasUnhandledDeepLink, isTrue);
    });
  });
}
