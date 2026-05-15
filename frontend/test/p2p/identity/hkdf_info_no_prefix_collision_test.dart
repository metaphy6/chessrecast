import 'package:flutter_test/flutter_test.dart';
import '../../../lib/services/p2p/protocol/frame.dart';

void main() {
  group('HKDF info labels — no prefix collision (§1.9 / §12)', () {
    test('no label is a prefix of another label', () {
      final labels = kHkdfInfoRegistry.keys.toList();

      for (int i = 0; i < labels.length; i++) {
        for (int j = 0; j < labels.length; j++) {
          if (i == j) continue;
          expect(
            labels[j].startsWith(labels[i]),
            isFalse,
            reason: '"${labels[i]}" is a prefix of "${labels[j]}" — '
                'this creates an ambiguity in concatenated HKDF contexts',
          );
        }
      }
    });

    test('no label purpose is a prefix of another purpose (value uniqueness)', () {
      final purposes = kHkdfInfoRegistry.values
          .map((v) => (v as dynamic).purpose as String)
          .toList();

      for (int i = 0; i < purposes.length; i++) {
        for (int j = 0; j < purposes.length; j++) {
          if (i == j) continue;
          expect(
            purposes[j].startsWith(purposes[i]),
            isFalse,
            reason: '"${purposes[i]}" is a prefix of "${purposes[j]}" — '
                'HKDF purpose domain collision risk',
          );
        }
      }
    });

    test('every label key ends with a distinct suffix component', () {
      // The last path component of each label must be unique so that
      // e.g. "master" and "master-v2" cannot be confused.
      final labels = kHkdfInfoRegistry.keys.toList();
      final suffixes = labels.map((l) => l.split('/').last).toList();
      final unique = suffixes.toSet();
      expect(unique.length, suffixes.length,
          reason: 'Duplicate suffix components: $suffixes');
    });

    test('label lengths are all within 64 bytes (HKDF context safety)', () {
      for (final label in kHkdfInfoRegistry.keys) {
        expect(label.length, lessThanOrEqualTo(64),
            reason: 'Label too long: $label (${label.length} bytes)');
      }
    });

    test('labels are safe ASCII (no control chars, no whitespace)', () {
      final safeAscii = RegExp(r'^[\x21-\x7E/]+$');
      for (final label in kHkdfInfoRegistry.keys) {
        expect(safeAscii.hasMatch(label), isTrue,
            reason: 'Label contains unsafe characters: $label');
      }
    });
  });
}
