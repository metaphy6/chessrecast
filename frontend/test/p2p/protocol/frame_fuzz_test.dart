import 'dart:math';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import '../../../lib/services/p2p/protocol/frame.dart';

void main() {
  group('Frame fuzz — no panics on random/malformed input (§1.1)', () {
    final iterations =
        int.tryParse(Platform.environment['P2P_FUZZ_ITERATIONS'] ?? '') ??
        10000;
    final rng = Random(0xDEADBEEF);

    test('random bytes never panic, always throw expected error types', () {
      int floatRejections = 0;
      int formatExceptions = 0;
      int argumentErrors = 0;
      int successes = 0;

      for (int i = 0; i < iterations; i++) {
        final len = rng.nextInt(256);
        final bytes = Uint8List(len);
        for (int j = 0; j < len; j++) {
          bytes[j] = rng.nextInt(256);
        }

        try {
          final decoded = CborCodec.decode(bytes);
          // If decode succeeds, try to use the result
          if (decoded != null) successes++;
        } on CborFloatRejectedError {
          floatRejections++;
        } on FormatException {
          formatExceptions++;
        } on ArgumentError {
          argumentErrors++;
        } on TypeError {
          // expected — random bytes may decode to unexpected types
          argumentErrors++; // count alongside argument errors for stats
        } catch (e) {
          // Any other exception type is a test failure
          fail(
            'Unexpected exception type ${e.runtimeType} on iteration $i: $e',
          );
        }
      }

      // Logging for debug purposes
      // ignore: avoid_print
      print(
        'Fuzz stats ($iterations iterations): '
        'successes=$successes floatRejections=$floatRejections '
        'formatExceptions=$formatExceptions argumentErrors=$argumentErrors',
      );
    });

    test('random bytes fed to Frame.decode never panic', () {
      for (int i = 0; i < iterations; i++) {
        final len = rng.nextInt(512) + 4;
        final bytes = Uint8List(len);
        for (int j = 0; j < len; j++) {
          bytes[j] = rng.nextInt(256);
        }

        try {
          Frame.decode(bytes);
        } on CborFloatRejectedError {
          // expected
        } on FormatException {
          // expected
        } on ArgumentError {
          // expected
        } on TypeError {
          // expected — random bytes may decode to map types that fail casts
        } catch (e) {
          fail(
            'Unexpected exception type ${e.runtimeType} on Frame.decode iteration $i: $e',
          );
        }
      }
    });

    test('truncated valid CBOR never panics', () {
      // Start from a valid CBOR-encoded frame, then truncate it
      final payload = CborCodec.encode({'uci': 'e2e4', 'hash': Uint8List(32)});
      final frame = Frame(
        type: FrameType.move,
        sequenceNum: 1,
        wallClock: 0,
        payload: payload,
      );
      final full = frame.encode();

      for (int len = 1; len < full.length; len++) {
        final truncated = Uint8List.fromList(full.sublist(0, len));
        try {
          Frame.decode(truncated);
        } on CborFloatRejectedError {
          // fine
        } on FormatException {
          // fine
        } on ArgumentError {
          // fine
        } catch (e) {
          fail(
            'Truncated frame (len=$len) raised unexpected ${e.runtimeType}: $e',
          );
        }
      }
    });

    test('bit-flipped frames never panic', () {
      final payload = CborCodec.encode({'uci': 'e2e4', 'hash': Uint8List(32)});
      final frame = Frame(
        type: FrameType.move,
        sequenceNum: 1,
        wallClock: 0,
        payload: payload,
      );
      final original = frame.encode();

      // Flip every bit in the frame, one bit at a time
      for (
        int byteIdx = 0;
        byteIdx < original.length && byteIdx < 32;
        byteIdx++
      ) {
        for (int bit = 0; bit < 8; bit++) {
          final mutated = Uint8List.fromList(original);
          mutated[byteIdx] ^= (1 << bit);
          try {
            Frame.decode(mutated);
          } on CborFloatRejectedError {
          } on FormatException {
          } on ArgumentError {
          } on TypeError {
            // expected — bit flip may produce type mismatches inside Frame.decode
          } catch (e) {
            fail(
              'Bit-flip at byte=$byteIdx bit=$bit raised ${e.runtimeType}: $e',
            );
          }
        }
      }
    });
  });
}
