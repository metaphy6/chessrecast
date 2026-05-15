#!/usr/bin/env dart
// ignore_for_file: avoid_print

/// Lint tool: forbid String-typed parameters for secret material (§2.7.bullet-2).
///
/// Flags any function/method whose parameter name matches the secret-material
/// pattern (`*Key|*Secret|*Password|*Mnemonic|*Wordlist|*Kek|*Seed`) but is
/// typed as `String` rather than `Uint8List` or `List<int>`.
///
/// Usage:
///   dart run tool/forbid_string_for_secrets.dart [--path lib/]
///
/// CI: dart run tool/forbid_string_for_secrets.dart --path lib/services/p2p
///
/// Exit code:
///   0 = no violations
///   1 = violations found (fails CI)

import 'dart:io';

// Matches: String someKey, String someSecret, String password, etc.
final _pattern = RegExp(
  r'\bString\s+\w*(?:Key|Secret|Password|Mnemonic|Wordlist|Kek|Seed|PrivKey|PubKey)\b',
  caseSensitive: false,
);

void main(List<String> args) {
  final dir = _parsePathArg(args) ?? 'lib/';
  final files = Directory(dir)
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  int violations = 0;
  for (final file in files) {
    final lines = file.readAsLinesSync();
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (_pattern.hasMatch(line)) {
        print(
          '${file.path}:${i + 1}: VIOLATION — String used for secret '
          'parameter: ${line.trim()}',
        );
        violations++;
      }
    }
  }

  if (violations == 0) {
    print(
      'forbid_string_for_secrets: OK — no String-typed secret parameters found '
      'in $dir',
    );
    exit(0);
  } else {
    print(
      'forbid_string_for_secrets: $violations violation(s) found. '
      'Use Uint8List for secret material instead of String.',
    );
    exit(1);
  }
}

String? _parsePathArg(List<String> args) {
  for (int i = 0; i < args.length; i++) {
    if (args[i] == '--path' && i + 1 < args.length) return args[i + 1];
    if (args[i].startsWith('--path='))
      return args[i].substring('--path='.length);
  }
  return null;
}
