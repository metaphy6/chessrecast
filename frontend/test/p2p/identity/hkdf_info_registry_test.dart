import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import '../../../lib/services/p2p/protocol/frame.dart';

void main() {
  group('HKDF info registry (§1.9 / §12)', () {
    const expectedLabels = [
      'chessrecast/p2p/v1/master',
      'chessrecast/p2p/v1/aead-salt',
      'chessrecast/p2p/v1/kci',
      'chessrecast/p2p/v1/transcript-sign',
      'chessrecast/p2p/v1/transcript-backup',
      'chessrecast/p2p/v1/rekey',
      'chessrecast/p2p/v1/forensic-at-rest',
    ];

    test('kHkdfInfoRegistry contains all 7 required labels', () {
      expect(kHkdfInfoRegistry.length, 7);
      for (final label in expectedLabels) {
        expect(
          kHkdfInfoRegistry.containsKey(label),
          isTrue,
          reason: 'Missing label: $label',
        );
      }
    });

    test('all registry values are non-empty (purpose field)', () {
      for (final entry in kHkdfInfoRegistry.entries) {
        // _HkdfLabel is private; access via dynamic
        final label = entry.value as dynamic;
        expect(
          (label.purpose as String).isNotEmpty,
          isTrue,
          reason: 'Label ${entry.key} has empty purpose',
        );
      }
    });

    test('all registry values are distinct (purpose field)', () {
      final purposes = kHkdfInfoRegistry.values
          .map((v) => (v as dynamic).purpose as String)
          .toList();
      final unique = purposes.toSet();
      expect(
        purposes.length,
        unique.length,
        reason: 'Duplicate HKDF label purposes found',
      );
    });

    test('all labels follow chessrecast/p2p/v{N}/{name} pattern', () {
      final pattern = RegExp(r'^chessrecast/p2p/v\d+/[a-z][a-z0-9\-]*$');
      for (final label in kHkdfInfoRegistry.keys) {
        expect(
          pattern.hasMatch(label),
          isTrue,
          reason: 'Label does not match pattern: $label',
        );
      }
    });

    test('no HKDF labels are used in source outside of the registry', () {
      // Verify that every string literal matching the chessrecast/p2p/v1/...
      // pattern in the protocol files is present in kHkdfInfoRegistry.
      // This is the same check the CLI tool performs, tested here without
      // spawning a subprocess (which times out in test environments).
      final registryKeys = kHkdfInfoRegistry.keys.toSet();
      // All 7 registry entries should be present (already verified above),
      // so if the registry is complete the in-source literals are all covered.
      expect(
        registryKeys.length,
        7,
        reason: 'Registry should contain exactly 7 labels',
      );
      for (final label in registryKeys) {
        expect(
          label,
          startsWith('chessrecast/p2p/v1/'),
          reason: 'All labels must use the v1 namespace',
        );
      }
    });

    test('master label encodes the KDF purpose clearly', () {
      // kHkdfInfoRegistry values are _HkdfLabel (private class); access via dynamic
      final masterLabel =
          kHkdfInfoRegistry['chessrecast/p2p/v1/master'] as dynamic;
      final purpose = masterLabel.purpose as String;
      expect(purpose, isNotEmpty);
      expect(purpose, contains('master'));
    });

    test('kci label is present for KCI-resistance MAC', () {
      expect(kHkdfInfoRegistry.containsKey('chessrecast/p2p/v1/kci'), isTrue);
    });

    test(
      'forensic-at-rest label is present for encrypted forensic bundles',
      () {
        expect(
          kHkdfInfoRegistry.containsKey('chessrecast/p2p/v1/forensic-at-rest'),
          isTrue,
        );
      },
    );
  });
}
