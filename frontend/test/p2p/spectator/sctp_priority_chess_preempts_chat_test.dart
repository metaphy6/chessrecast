// §7.10.1 SCTP priority chess preempts chat proof test.
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/spectator/spectator_perf.dart';

void main() {
  group('SctpStreamPriority §7.10.1 chess preempts chat', () {
    test('chess stream is 1', () {
      expect(SctpStreamPriority.chessStream, equals(1));
    });

    test('chat stream is 7', () {
      expect(SctpStreamPriority.chatStream, equals(7));
    });

    test('chess priority is high', () {
      expect(SctpStreamPriority.chessPriority, equals('high'));
    });

    test('chat priority is low', () {
      expect(SctpStreamPriority.chatPriority, equals('low'));
    });

    test('chess stream has lower ID (higher priority) than chat stream', () {
      expect(SctpStreamPriority.chessStream,
          lessThan(SctpStreamPriority.chatStream));
    });
  });
}
