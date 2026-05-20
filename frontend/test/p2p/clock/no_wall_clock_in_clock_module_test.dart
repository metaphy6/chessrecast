// §11.7 CI grep gate — ensures no DateTime.now() / DateTime.timestamp() /
// calendar-derived arithmetic appears in the clock module.
//
// This test reads every .dart file under
// frontend/lib/services/p2p/clock/ and fails if any forbidden symbol is found.
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const clockModulePath = 'lib/services/p2p/clock';

  // Patterns forbidden inside the clock module.
  final forbidden = [
    RegExp(r'DateTime\.now\(\)'),
    RegExp(r'DateTime\.timestamp\(\)'),
    // Calendar-derived arithmetic via localeName is also banned.
    RegExp(r'Platform\.localeName'),
  ];

  test('no wall-clock symbols in clock module', () {
    final dir = Directory(clockModulePath);
    expect(
      dir.existsSync(),
      isTrue,
      reason: '$clockModulePath directory must exist',
    );

    final dartFiles = dir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();

    expect(
      dartFiles,
      isNotEmpty,
      reason: 'clock module must contain at least one .dart file',
    );

    final violations = <String>[];

    for (final file in dartFiles) {
      final lines = file.readAsLinesSync();
      for (int i = 0; i < lines.length; i++) {
        final line = lines[i];
        // Skip comment lines (they may explain why something is banned).
        if (line.trimLeft().startsWith('//')) continue;
        for (final pattern in forbidden) {
          if (pattern.hasMatch(line)) {
            violations.add('${file.path}:${i + 1}: $line');
          }
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'Clock module must not use wall-clock. Violations:\n${violations.join('\n')}',
    );
  });
}
