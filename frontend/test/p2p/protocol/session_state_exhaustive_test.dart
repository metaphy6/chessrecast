import 'package:flutter_test/flutter_test.dart';
import '../../../lib/services/p2p/protocol/session.dart';

void main() {
  group('Session state exhaustive transitions (§1.2)', () {
    // All states × all events — verify that:
    //   1. Exactly the legal transitions succeed.
    //   2. All illegal transitions throw ProtocolStateError.
    //   3. No state is a deadlock (every state has at least one legal transition out).

    final allEvents = kAllSessionEvents;

    /// Build a session in [targetState] via the canonical path.
    Session _sessionInState(SessionState targetState) {
      final s = Session();
      switch (targetState) {
        case SessionState.idle:
          break;
        case SessionState.handshake:
          s.transition('start_handshake');
        case SessionState.playing:
          s.transition('start_handshake');
          s.transition('confirm');
        case SessionState.finished:
          s.transition('start_handshake');
          s.transition('confirm');
          s.transition('game_end');
        case SessionState.aborted:
          s.transition('start_handshake');
          s.transition('abort');
      }
      return s;
    }

    for (final state in SessionState.values) {
      group('from $state', () {
        for (final event in allEvents) {
          final s = _sessionInState(state);
          final legal = _isLegal(state, event);

          if (legal) {
            test('$event is accepted (→ ${_nextState(state, event)})', () {
              final session = _sessionInState(state);
              expect(() => session.transition(event), returnsNormally);
            });
          } else {
            test('$event throws ProtocolStateError', () {
              final session = _sessionInState(state);
              expect(
                () => session.transition(event),
                throwsA(isA<ProtocolStateError>()),
              );
            });
          }
        }
      });
    }

    test('no state is a deadlock (every state has ≥1 legal event)', () {
      for (final state in SessionState.values) {
        final legalCount = allEvents.where((e) => _isLegal(state, e)).length;
        expect(
          legalCount,
          greaterThan(0),
          reason: 'State $state has no legal outgoing transitions',
        );
      }
    });

    test('can reset from every terminal state back to idle', () {
      // finished and aborted both support reset
      for (final state in [SessionState.finished, SessionState.aborted]) {
        final s = _sessionInState(state);
        s.transition('reset');
        expect(s.state, SessionState.idle);
      }
    });
  });
}

bool _isLegal(SessionState state, String event) {
  switch (state) {
    case SessionState.idle:
      return event == 'start_handshake';
    case SessionState.handshake:
      return event == 'confirm' || event == 'abort';
    case SessionState.playing:
      return event == 'game_end' || event == 'mismatch' || event == 'abort';
    case SessionState.finished:
      return event == 'reset';
    case SessionState.aborted:
      return event == 'reset';
  }
}

SessionState _nextState(SessionState current, String event) {
  switch (current) {
    case SessionState.idle:
      return SessionState.handshake;
    case SessionState.handshake:
      if (event == 'confirm') return SessionState.playing;
      return SessionState.aborted;
    case SessionState.playing:
      if (event == 'game_end') return SessionState.finished;
      return SessionState.aborted;
    case SessionState.finished:
      return SessionState.idle;
    case SessionState.aborted:
      return SessionState.idle;
  }
}
