import 'package:flutter_test/flutter_test.dart';
import '../../../lib/services/p2p/protocol/session.dart';
import '../../../lib/services/p2p/protocol/frame.dart';

void main() {
  group('Session state machine (§1.2)', () {
    test('initial state is idle', () {
      final s = Session();
      expect(s.state, SessionState.idle);
    });

    test('idle → handshake on start_handshake', () {
      final s = Session();
      s.transition('start_handshake');
      expect(s.state, SessionState.handshake);
    });

    test('handshake → playing on confirm', () {
      final s = Session();
      s.transition('start_handshake');
      s.transition('confirm');
      expect(s.state, SessionState.playing);
    });

    test('handshake → aborted on abort', () {
      final s = Session();
      s.transition('start_handshake');
      s.transition('abort');
      expect(s.state, SessionState.aborted);
    });

    test('playing → finished on game_end', () {
      final s = Session();
      s.transition('start_handshake');
      s.transition('confirm');
      s.transition('game_end');
      expect(s.state, SessionState.finished);
    });

    test('playing → aborted on mismatch', () {
      final s = Session();
      s.transition('start_handshake');
      s.transition('confirm');
      s.transition('mismatch');
      expect(s.state, SessionState.aborted);
    });

    test('playing → aborted on abort', () {
      final s = Session();
      s.transition('start_handshake');
      s.transition('confirm');
      s.transition('abort');
      expect(s.state, SessionState.aborted);
    });

    test('finished → idle on reset', () {
      final s = Session();
      s.transition('start_handshake');
      s.transition('confirm');
      s.transition('game_end');
      s.transition('reset');
      expect(s.state, SessionState.idle);
    });

    test('aborted → idle on reset', () {
      final s = Session();
      s.transition('start_handshake');
      s.transition('abort');
      s.transition('reset');
      expect(s.state, SessionState.idle);
    });

    group('illegal transitions raise ProtocolStateError', () {
      test('idle cannot confirm', () {
        final s = Session();
        expect(
          () => s.transition('confirm'),
          throwsA(isA<ProtocolStateError>()),
        );
      });

      test('idle cannot game_end', () {
        final s = Session();
        expect(
          () => s.transition('game_end'),
          throwsA(isA<ProtocolStateError>()),
        );
      });

      test('handshake cannot game_end', () {
        final s = Session();
        s.transition('start_handshake');
        expect(
          () => s.transition('game_end'),
          throwsA(isA<ProtocolStateError>()),
        );
      });

      test('handshake cannot reset', () {
        final s = Session();
        s.transition('start_handshake');
        expect(() => s.transition('reset'), throwsA(isA<ProtocolStateError>()));
      });

      test('playing cannot start_handshake', () {
        final s = Session();
        s.transition('start_handshake');
        s.transition('confirm');
        expect(
          () => s.transition('start_handshake'),
          throwsA(isA<ProtocolStateError>()),
        );
      });

      test('playing cannot confirm', () {
        final s = Session();
        s.transition('start_handshake');
        s.transition('confirm');
        expect(
          () => s.transition('confirm'),
          throwsA(isA<ProtocolStateError>()),
        );
      });

      test('finished cannot abort', () {
        final s = Session();
        s.transition('start_handshake');
        s.transition('confirm');
        s.transition('game_end');
        expect(() => s.transition('abort'), throwsA(isA<ProtocolStateError>()));
      });

      test('aborted cannot game_end', () {
        final s = Session();
        s.transition('start_handshake');
        s.transition('abort');
        expect(
          () => s.transition('game_end'),
          throwsA(isA<ProtocolStateError>()),
        );
      });
    });

    test('ProtocolStateError has meaningful toString', () {
      final e = const ProtocolStateError(SessionState.idle, 'confirm');
      expect(e.toString(), contains('ProtocolStateError'));
      expect(e.toString(), contains('confirm'));
      expect(e.toString(), contains('idle'));
    });
  });
}
