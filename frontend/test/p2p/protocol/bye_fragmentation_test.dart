import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import '../../../lib/services/p2p/protocol/frame.dart';

void main() {
  group('BYE fragmentation — 600-ply game (§1.8 / §7-8)', () {
    // Build a large BYE payload representing ~600 plies of move + FEN data.
    // A real 600-ply transcript includes one FEN per ply (~70 bytes each) plus
    // UCI move strings → ~44KB total, comfortably over the 12KB threshold.
    Uint8List _buildLargeByePayload() {
      final rng = Random(42);
      final moves = <String>[];
      final fens = <String>[];
      const cols = 'abcdefgh';
      // A realistic-length FEN string for each ply
      const sampleFen =
          'rnbqkbnr/pp1ppppp/8/2p5/4P3/5N2/PPPP1PPP/RNBQKB1R b KQkq - 1 2';
      for (int i = 0; i < 600; i++) {
        final fc = cols[rng.nextInt(8)];
        final fr = rng.nextInt(8) + 1;
        final tc = cols[rng.nextInt(8)];
        final tr = rng.nextInt(8) + 1;
        moves.add('$fc$fr$tc$tr');
        // Include FEN-per-ply so transcript exceeds 12KB fragmentation threshold
        fens.add('$sampleFen $i');
      }

      return CborCodec.encode({
        'result': '1-0',
        'moves': moves,
        'fens': fens,
        'sig': Uint8List(64),
      });
    }

    test('600-ply BYE payload exceeds 12KB fragmentation threshold', () {
      final payload = _buildLargeByePayload();
      expect(payload.length, greaterThan(kByeFragmentThresholdBytes));
    });

    test('fragment returns BYE_PART payloads + final hash', () {
      final payload = _buildLargeByePayload();
      final parts = ByeFragmenter.fragment(payload);

      // All but the last part have data + idx + tot
      for (int i = 0; i < parts.length - 1; i++) {
        expect(parts[i].containsKey('idx'), isTrue);
        expect(parts[i].containsKey('tot'), isTrue);
        expect(parts[i].containsKey('data'), isTrue);
      }
      // Last entry is the BYE_FINAL hash
      expect(parts.last.containsKey('hash'), isTrue);
      expect((parts.last['hash'] as Uint8List).length, 32);
    });

    test('fragment count is within the 64-part limit', () {
      final payload = _buildLargeByePayload();
      final parts = ByeFragmenter.fragment(payload);
      // parts.length = N data parts + 1 hash entry
      // Data parts should be ≤ 64
      final dataParts = parts.where((p) => p.containsKey('data')).toList();
      expect(dataParts.length, lessThanOrEqualTo(kByeMaxFragments));
    });

    test('reassemble recovers the original payload bytes', () {
      final payload = _buildLargeByePayload();
      final parts = ByeFragmenter.fragment(payload);

      final hashEntry = parts.last;
      final expectedHash = hashEntry['hash'] as Uint8List;
      final dataParts = parts.where((p) => p.containsKey('data')).toList();

      final reassembled = ByeFragmenter.reassemble(dataParts, expectedHash);
      expect(reassembled.length, payload.length);
      expect(reassembled, equals(payload));
    });

    test('fragment and reassemble are inverses (small edge case at threshold)', () {
      // Build payload just over 12KB
      final payload = Uint8List(kByeFragmentThresholdBytes + 1)
        ..fillRange(0, kByeFragmentThresholdBytes + 1, 0xAB);
      final parts = ByeFragmenter.fragment(payload);
      final hashEntry = parts.last;
      final expectedHash = hashEntry['hash'] as Uint8List;
      final dataParts = parts.where((p) => p.containsKey('data')).toList();
      final reassembled = ByeFragmenter.reassemble(dataParts, expectedHash);
      expect(reassembled, equals(payload));
    });

    test('FragmentNotAllowedError thrown for payload ≤ threshold', () {
      final smallPayload = Uint8List(100);
      expect(
        () => ByeFragmenter.fragment(smallPayload),
        throwsA(isA<FragmentNotAllowedError>()),
      );
    });

    test('reassemble with wrong hash throws FormatException', () {
      final payload = _buildLargeByePayload();
      final parts = ByeFragmenter.fragment(payload);
      final dataParts = parts.where((p) => p.containsKey('data')).toList();
      final badHash = Uint8List(32)..fillRange(0, 32, 0xFF);
      expect(
        () => ByeFragmenter.reassemble(dataParts, badHash),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
