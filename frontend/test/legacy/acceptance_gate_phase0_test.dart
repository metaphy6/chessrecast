/// Proof test for roadmap §0.5 — Acceptance gate.
///
/// Verifies that every Phase 0 pre-condition is met before the phase is
/// declared complete:
///   1. The "P2P preview not yet shipped" banner exists in README.md.
///   2. All actionable checkboxes in sections §0.1–§0.4 of the roadmap
///      are ticked `[x]` (no open `[ ]` boxes remaining in those sections).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late String repoRoot;

  setUpAll(() {
    // flutter test is run from frontend/.
    // Repo root is one level up.
    repoRoot = p.normalize(p.join(Directory.current.path, '..'));
  });

  test('README.md contains the P2P preview banner', () {
    final readme = File(p.join(repoRoot, 'README.md'));
    expect(readme.existsSync(), isTrue, reason: 'README.md must exist');
    final content = readme.readAsStringSync();
    expect(
      content,
      contains('P2P preview not yet shipped'),
      reason:
          'README.md must contain the "P2P preview not yet shipped" banner',
    );
  });

  test('all §0.1–§0.4 roadmap boxes are ticked [x]', () {
    final roadmap = File(p.join(repoRoot, 'docs', 'P2P_ROADMAP.md'));
    expect(roadmap.existsSync(), isTrue, reason: 'P2P_ROADMAP.md must exist');

    final lines = roadmap.readAsLinesSync();

    // Collect lines from sections 0.1–0.4 (stop at 0.5).
    var inScope = false;
    final openBoxes = <String>[];

    for (final line in lines) {
      // Start collecting at any of the 0.1–0.4 section headers.
      if (RegExp(r'^### 0\.[1234][ \t]').hasMatch(line)) {
        inScope = true;
        continue;
      }
      // Stop when we hit 0.5 or later.
      if (RegExp(r'^### 0\.[5-9][ \t]|^## ').hasMatch(line)) {
        if (inScope) break; // past the 0.4 boundary
      }
      if (!inScope) continue;

      // Any checkbox line that is NOT ticked is a failure.
      if (line.trimLeft().startsWith('- [ ]')) {
        openBoxes.add(line.trim());
      }
    }

    expect(
      openBoxes,
      isEmpty,
      reason:
          'All §0.1–§0.4 boxes must be [x] before the acceptance gate can pass.\n'
          'Remaining open boxes:\n${openBoxes.join('\n')}',
    );
  });
}
