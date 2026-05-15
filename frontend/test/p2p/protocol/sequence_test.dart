import 'package:flutter_test/flutter_test.dart';
import '../../../lib/services/p2p/protocol/session.dart';
import '../../../lib/services/p2p/protocol/frame.dart';

void main() {
  group('Sequence number validation (§1.2 / §1 frame.n)', () {
    test('first frame (seq=1) is accepted', () {
      final s = Session();
      expect(s.validateAndRecordSequence(1, 1), isTrue);
    });

    test('strictly increasing sequence is accepted', () {
      final s = Session();
      s.validateAndRecordSequence(1, 1);
      s.validateAndRecordSequence(1, 2);
      s.validateAndRecordSequence(1, 10);
      expect(s.validateAndRecordSequence(1, 11), isTrue);
    });

    test('duplicate seq throws OutOfSequenceError', () {
      final s = Session();
      s.validateAndRecordSequence(0, 1);
      expect(
        () => s.validateAndRecordSequence(0, 1),
        throwsA(isA<OutOfSequenceError>()),
      );
    });

    test('out-of-order seq throws OutOfSequenceError', () {
      final s = Session();
      s.validateAndRecordSequence(0, 5);
      expect(
        () => s.validateAndRecordSequence(0, 3),
        throwsA(isA<OutOfSequenceError>()),
      );
    });

    test('seq=0 throws OutOfSequenceError (seq starts at 1)', () {
      final s = Session();
      expect(
        () => s.validateAndRecordSequence(0, 0),
        throwsA(isA<OutOfSequenceError>()),
      );
    });

    test('two directions are tracked independently', () {
      final s = Session();
      // Local direction (0) gets seq 1, 2
      s.validateAndRecordSequence(0, 1);
      s.validateAndRecordSequence(0, 2);
      // Remote direction (1) starts fresh from 1
      expect(s.validateAndRecordSequence(1, 1), isTrue);
      expect(s.validateAndRecordSequence(1, 2), isTrue);
      // Local direction (0) can still advance
      expect(s.validateAndRecordSequence(0, 3), isTrue);
    });

    test('OutOfSequenceError contains received and lastSeen values', () {
      final s = Session();
      s.validateAndRecordSequence(0, 5);
      try {
        s.validateAndRecordSequence(0, 3);
        fail('Expected OutOfSequenceError');
      } on OutOfSequenceError catch (e) {
        expect(e.received, 3);
        expect(e.lastSeen, 5);
        expect(e.toString(), contains('received'));
        expect(e.toString(), contains('last_seen'));
      }
    });

    test('sequence resets to 0 after session reset', () {
      final s = Session();
      s.transition('start_handshake');
      s.transition('confirm');
      s.validateAndRecordSequence(0, 100);
      s.transition('game_end');
      s.transition('reset');
      // After reset, seq 1 should be accepted again
      expect(s.validateAndRecordSequence(0, 1), isTrue);
    });
  });
}
