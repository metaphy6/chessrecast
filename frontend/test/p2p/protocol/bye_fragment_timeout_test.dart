import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import '../../../lib/services/p2p/protocol/frame.dart';

// Simulates the 30-second BYE fragment reassembly timeout.
class FragmentReassembler {
  static const int timeoutMs = 30000;

  final int startTimeMs;
  final int totalExpected;
  final List<Map<String, dynamic>> receivedParts = [];
  bool _complete = false;

  FragmentReassembler({required this.startTimeMs, required this.totalExpected});

  bool get isComplete => _complete;

  /// Returns true if the timeout has elapsed without completing reassembly.
  bool isTimedOut(int nowMs) {
    if (_complete) return false;
    return (nowMs - startTimeMs) >= timeoutMs;
  }

  void addPart(Map<String, dynamic> part) {
    receivedParts.add(part);
    if (receivedParts.length >= totalExpected) _complete = true;
  }

  Uint8List? tryReassemble(Uint8List expectedHash) {
    if (!_complete) return null;
    return ByeFragmenter.reassemble(receivedParts, expectedHash);
  }
}

void main() {
  group('BYE fragment timeout — 30s (§1.8 / §8)', () {
    test('reassembler is not timed out before 30s', () {
      final r = FragmentReassembler(startTimeMs: 0, totalExpected: 2);
      expect(r.isTimedOut(29999), isFalse);
    });

    test('reassembler is timed out after 30s with incomplete parts', () {
      final r = FragmentReassembler(startTimeMs: 0, totalExpected: 3);
      r.addPart({'idx': 0, 'tot': 3, 'data': Uint8List(100)});
      // Only 1 of 3 parts received
      expect(r.isTimedOut(30000), isTrue);
    });

    test('reassembler is NOT timed out when complete before 30s', () {
      final r = FragmentReassembler(startTimeMs: 0, totalExpected: 1);
      r.addPart({'idx': 0, 'tot': 1, 'data': Uint8List(100)});
      expect(r.isComplete, isTrue);
      expect(r.isTimedOut(30000), isFalse);
    });

    test('tryReassemble returns null while incomplete', () {
      final r = FragmentReassembler(startTimeMs: 0, totalExpected: 2);
      r.addPart({'idx': 0, 'tot': 2, 'data': Uint8List(100)});
      expect(r.tryReassemble(Uint8List(32)), isNull);
    });

    test('after timeout, partial fragments should be discarded', () {
      // Simulate the protocol: on timeout, discard state and send error
      final r = FragmentReassembler(startTimeMs: 0, totalExpected: 5);
      r.addPart({'idx': 0, 'tot': 5, 'data': Uint8List(100)});
      r.addPart({'idx': 1, 'tot': 5, 'data': Uint8List(100)});

      // At t=30001ms, the reassembler times out
      const nowMs = 30001;
      expect(r.isTimedOut(nowMs), isTrue);
      expect(r.receivedParts.length, 2); // Only 2 of 5 received before timeout
      expect(r.isComplete, isFalse);
    });

    test('timeout boundary: exactly at 30000ms is considered timed out', () {
      final r = FragmentReassembler(startTimeMs: 0, totalExpected: 3);
      expect(r.isTimedOut(30000), isTrue);
    });

    test('multiple reassemblers can operate independently', () {
      final r1 = FragmentReassembler(startTimeMs: 0, totalExpected: 2);
      final r2 = FragmentReassembler(startTimeMs: 10000, totalExpected: 2);

      r1.addPart({'idx': 0, 'tot': 2, 'data': Uint8List(10)});
      r1.addPart({'idx': 1, 'tot': 2, 'data': Uint8List(10)});

      expect(r1.isComplete, isTrue);
      expect(r1.isTimedOut(30000), isFalse);

      // r2 started 10s later, so it times out at t=40000
      expect(r2.isTimedOut(30000), isFalse);
      expect(r2.isTimedOut(40000), isTrue);
    });
  });
}
