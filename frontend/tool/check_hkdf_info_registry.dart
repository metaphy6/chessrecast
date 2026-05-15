#!/usr/bin/env dart
// frontend/tool/check_hkdf_info_registry.dart
//
// CI gate: walks frontend/lib/services/p2p/** and checks that every HKDF
// info-string literal matching "chessrecast/p2p/v\d+/[^"]+" is registered
// in the HKDF registry (kHkdfInfoRegistry in frame.dart).
//
// Usage:
//   dart run frontend/tool/check_hkdf_info_registry.dart
//   exit 0 = all labels registered
//   exit 1 = unregistered label found

import 'dart:io';

// Registry copied from frame.dart to avoid importing Flutter in a CLI tool.
// Keep in sync with kHkdfInfoRegistry.
const Set<String> _registeredLabels = {
  'chessrecast/p2p/v1/master',
  'chessrecast/p2p/v1/aead-salt',
  'chessrecast/p2p/v1/kci',
  'chessrecast/p2p/v1/transcript-sign',
  'chessrecast/p2p/v1/transcript-backup',
  'chessrecast/p2p/v1/rekey',
  'chessrecast/p2p/v1/forensic-at-rest',
};

final _labelPattern = RegExp(r'"(chessrecast/p2p/v\d+/[^"]+)"');

Future<int> main(List<String> args) async {
  final rootDir = args.isNotEmpty ? args[0] : 'lib/services/p2p';
  final dir = Directory(rootDir);
  if (!dir.existsSync()) {
    stderr.writeln('Directory not found: $rootDir');
    return 1;
  }

  final unregistered = <String>{};
  final files = dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'));

  for (final file in files) {
    final content = file.readAsStringSync();
    for (final match in _labelPattern.allMatches(content)) {
      final label = match.group(1)!;
      if (!_registeredLabels.contains(label)) {
        unregistered.add('${file.path}: $label');
      }
    }
  }

  if (unregistered.isEmpty) {
    stdout.writeln('check_hkdf_info_registry: all labels registered. OK');
    return 0;
  }

  stderr.writeln('check_hkdf_info_registry: UNREGISTERED HKDF labels found:');
  for (final u in unregistered) {
    stderr.writeln('  $u');
  }
  return 1;
}
