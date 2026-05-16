// §5.5 FakeTransport — proof test (L5, hermetic).
//
// Verifies baseline in-memory pipe: zero loss, FIFO delivery, bidirectional,
// correct error on send-to-closed.
//
// FakeTransport uses a sync StreamController so send() delivers events
// synchronously into the listener — no microtask pump is needed.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/transport/fake/fake_transport.dart';

void main() {
  group('FakeTransport §5.5', () {
    test('delivers bytes from A to B in FIFO order', () async {
      final (a, b) = FakeTransport.pair();
      final received = <(String, Uint8List)>[];
      b.incoming.listen(received.add);

      final bytes1 = Uint8List.fromList([1, 2, 3]);
      final bytes2 = Uint8List.fromList([4, 5, 6]);
      a.send('chess', bytes1); // sync delivery
      a.send('chess', bytes2);

      expect(received.length, equals(2));
      expect(received[0].$1, equals('chess'));
      expect(received[0].$2, equals(bytes1));
      expect(received[1].$2, equals(bytes2));

      await a.close();
      await b.close();
    });

    test('delivers bytes from B to A', () async {
      final (a, b) = FakeTransport.pair();
      final received = <(String, Uint8List)>[];
      a.incoming.listen(received.add);

      b.send('clock', Uint8List.fromList([10, 20])); // sync delivery

      expect(received.length, equals(1));
      expect(received[0].$1, equals('clock'));
      expect(received[0].$2, equals(Uint8List.fromList([10, 20])));

      await a.close();
      await b.close();
    });

    test('preserves FIFO order for 20 sequential frames', () async {
      final (a, b) = FakeTransport.pair();
      final received = <int>[];
      b.incoming.listen((t) => received.add(t.$2[0]));

      for (var i = 0; i < 20; i++) {
        a.send('chess', Uint8List.fromList([i])); // sync delivery each
      }

      expect(received.length, equals(20));
      for (var i = 0; i < 20; i++) {
        expect(received[i], equals(i));
      }

      await a.close();
      await b.close();
    });

    test('zero loss — 100 frames all delivered', () async {
      final (a, b) = FakeTransport.pair();
      int count = 0;
      b.incoming.listen((_) => count++);

      for (var i = 0; i < 100; i++) {
        a.send('chess', Uint8List.fromList([i & 0xff]));
      }

      expect(count, equals(100));

      await a.close();
      await b.close();
    });

    // send() throws synchronously on a closed transport — no async needed.
    test('send on closed transport throws StateError', () {
      final (a, _) = FakeTransport.pair();
      a.close(); // sets _closed synchronously; no need to await
      expect(() => a.send('chess', Uint8List(0)), throwsStateError);
    });

    test('multiple channels delivered correctly', () async {
      final (a, b) = FakeTransport.pair();
      final chessFrames = <Uint8List>[];
      final clockFrames = <Uint8List>[];
      b.incoming.listen((t) {
        if (t.$1 == 'chess') chessFrames.add(t.$2);
        if (t.$1 == 'clock') clockFrames.add(t.$2);
      });

      a.send('chess', Uint8List.fromList([1]));
      a.send('clock', Uint8List.fromList([2]));
      a.send('chess', Uint8List.fromList([3]));

      expect(chessFrames.length, equals(2));
      expect(clockFrames.length, equals(1));

      await a.close();
      await b.close();
    });
  });
}
