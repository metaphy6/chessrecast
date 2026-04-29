// frontend/tool/check_test_diff.dart
//
// Static lint over a git diff to catch the agent silently weakening tests
// to clear a gate. Per AGENTS.md §3 and copilot-instructions.md → Hard rules
// → 10, the following changes are forbidden in any agent-authored commit:
//
//   * adding `skip:` / `@Skip` / `markTestSkipped(...)` to a test,
//   * removing an `expect(` line,
//   * replacing a strict matcher with a loose one (e.g. `equals(x)` -> `isNotNull`),
//   * deleting a `_test.dart` file without an accompanying queue entry of
//     kind: kpi_regression or kind: shared_edit.
//
// Usage (run from frontend/):
//   dart run tool/check_test_diff.dart <git-range>
//
// Examples:
//   dart run tool/check_test_diff.dart origin/main...HEAD
//   dart run tool/check_test_diff.dart HEAD~1...HEAD
//
// Exits non-zero if any forbidden pattern is detected. The pre-push hook
// invokes this; the agent should also run it before declaring a slash command
// complete.

import 'dart:io';

final _addedSkip = RegExp(
  r'^\+.*(\bskip:\s*true\b|@Skip\b|markTestSkipped\s*\()',
);
final _addedLooseMatcher = RegExp(
  r'^\+.*expect\s*\([^,]+,\s*(isNotNull|isNotEmpty|anything|isA<[^>]+>\(\)|isTrue|isFalse)\s*\)',
);
final _removedExpect = RegExp(r'^-\s*expect\s*\(');
final _filePragma = RegExp(r'^\+\+\+ b/(.+)$');
final _testFile = RegExp(r'(^|/)test/.*_test\.dart$');

void main(List<String> args) async {
  final range = args.isNotEmpty ? args.first : 'origin/main...HEAD';

  final proc = await Process.run('git', [
    'diff',
    '--unified=0',
    range,
    '--',
    '*_test.dart',
  ]);
  if (proc.exitCode != 0) {
    stderr.writeln('check_test_diff: git diff failed: ${proc.stderr}');
    exit(2);
  }
  final diff = proc.stdout as String;
  if (diff.trim().isEmpty) {
    stdout.writeln('check_test_diff: no test diffs in $range — ok.');
    return;
  }

  final findings = <String>[];
  String? currentFile;
  int addedExpect = 0;
  int removedExpect = 0;

  for (final line in diff.split('\n')) {
    final fm = _filePragma.firstMatch(line);
    if (fm != null) {
      currentFile = fm.group(1);
      continue;
    }
    if (currentFile == null || !_testFile.hasMatch(currentFile)) continue;

    if (_addedSkip.hasMatch(line)) {
      findings.add('SKIP added in $currentFile: ${line.trim()}');
    }
    if (_addedLooseMatcher.hasMatch(line)) {
      findings.add('LOOSENED matcher in $currentFile: ${line.trim()}');
    }
    if (line.startsWith('+') && line.contains('expect(')) addedExpect++;
    if (_removedExpect.hasMatch(line)) removedExpect++;
  }

  // Net loss of expect() calls is a red flag.
  if (removedExpect > addedExpect) {
    findings.add(
      'NET LOSS of expect() lines: removed=$removedExpect added=$addedExpect '
      '(if a test is genuinely obsolete, document it in the commit message and '
      'file a kind: kpi_regression / shared_edit queue entry).',
    );
  }

  // Detect deleted test files.
  final deleted = await Process.run('git', [
    'diff',
    '--name-only',
    '--diff-filter=D',
    range,
    '--',
    '*_test.dart',
  ]);
  final deletedFiles = (deleted.stdout as String)
      .split('\n')
      .where((s) => s.trim().isNotEmpty)
      .toList();
  if (deletedFiles.isNotEmpty) {
    findings.add(
      'DELETED test files: ${deletedFiles.join(', ')} '
      '(forbidden without an explicit queue entry).',
    );
  }

  if (findings.isEmpty) {
    stdout.writeln('check_test_diff: ok (range=$range).');
    return;
  }

  stderr.writeln('check_test_diff: ${findings.length} finding(s) in $range:');
  for (final f in findings) {
    stderr.writeln('  - $f');
  }
  stderr.writeln(
    'See AGENTS.md §3 / .github/copilot-instructions.md → Hard rules → 10.',
  );
  exit(1);
}
