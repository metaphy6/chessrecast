/// Acceptance gate for Phase 18 — Privacy Engineering.
///
/// Verifies all §18.1–§18.7 boxes are ticked in P2P_ROADMAP.md, that both
/// privacy docs are published, and that the data-flow completeness CI gate
/// script exists and is executable — roadmap §18.8.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Directory _repoRoot() {
  var dir = Directory.fromUri(Platform.script).parent;
  while (dir.path != dir.parent.path) {
    if (File('${dir.path}/AGENTS.md').existsSync()) return dir;
    dir = dir.parent;
  }
  throw StateError('Could not find repo root');
}

void main() {
  late Directory repo;
  late String roadmap;

  setUpAll(() {
    repo = _repoRoot();
    final f = File('${repo.path}/docs/P2P_ROADMAP.md');
    expect(f.existsSync(), isTrue, reason: 'docs/P2P_ROADMAP.md must exist');
    roadmap = f.readAsStringSync();
  });

  group('§18.8 Acceptance gate — all Phase 18 boxes ticked', () {
    test('§18.1 CI gate box is ticked', () {
      _assertBoxesTicked(roadmap, '18.1', 1);
    });

    test('§18.2 T-PRIV threat model boxes are ticked', () {
      _assertBoxesTicked(roadmap, '18.2', 6);
    });

    test('§18.3 DSAR access box is ticked', () {
      _assertBoxesTicked(roadmap, '18.3', 1);
    });

    test('§18.4 portability boxes are ticked', () {
      _assertBoxesTicked(roadmap, '18.4', 6);
    });

    test('§18.5 erasure boxes are ticked', () {
      _assertBoxesTicked(roadmap, '18.5', 4);
    });

    test('§18.6 PIA boxes are ticked', () {
      _assertBoxesTicked(roadmap, '18.6', 2);
    });

    test('§18.7 quality attribute boxes are ticked', () {
      _assertBoxesTicked(roadmap, '18.7', 5);
    });

    test('docs/P2P_PRIVACY.md is published', () {
      expect(
        File('${repo.path}/docs/P2P_PRIVACY.md').existsSync(),
        isTrue,
        reason: 'docs/P2P_PRIVACY.md must be published',
      );
    });

    test('docs/P2P_PRIVACY_PIA.md is published', () {
      expect(
        File('${repo.path}/docs/P2P_PRIVACY_PIA.md').existsSync(),
        isTrue,
        reason: 'docs/P2P_PRIVACY_PIA.md must be published before beta opens',
      );
    });

    test('DSAR access flow is tested (proof file exists)', () {
      expect(
        File('${repo.path}/signaling/internal/dsar/dsar_test.go').existsSync(),
        isTrue,
        reason: 'DSAR access proof test must exist',
      );
    });

    test('portability export flow is tested (proof file exists)', () {
      expect(
        File(
          '${repo.path}/frontend/test/p2p/privacy/export_my_data_test.dart',
        ).existsSync(),
        isTrue,
        reason: 'export portability proof test must exist',
      );
    });

    test('erasure flow is tested (proof file exists)', () {
      expect(
        File(
          '${repo.path}/frontend/test/p2p/privacy/delete_account_test.dart',
        ).existsSync(),
        isTrue,
        reason: 'delete-account erasure proof test must exist',
      );
    });

    test('data-flow completeness CI gate script exists and is executable', () {
      final script = File(
        '${repo.path}/xops/p2p/data-flow-completeness-check.sh',
      );
      expect(
        script.existsSync(),
        isTrue,
        reason:
            'CI gate script must exist at xops/p2p/data-flow-completeness-check.sh',
      );
      final stat = script.statSync();
      // User-executable bit (mode & 0100 != 0).
      expect(
        (stat.mode & 0x49),
        isNonZero, // 0x49 = 0111 (any exec bit)
        reason: 'CI gate script must be executable',
      );
    });
  });
}

/// Extracts the §[section] block from [roadmap] and asserts that every `- [x]`
/// / `- [ ]` leaf has `[x]` (ticked).
///
/// Expects exactly [expectedCount] ticked boxes in that section.
void _assertBoxesTicked(String roadmap, String section, int expectedCount) {
  // Find the section header, then scan forward until the next ### or ## heading.
  final lines = roadmap.split('\n');
  final headerPattern = RegExp(r'^### ' + RegExp.escape(section) + r'\b');
  int sectionStart = -1;
  for (int i = 0; i < lines.length; i++) {
    if (headerPattern.hasMatch(lines[i])) {
      sectionStart = i;
      break;
    }
  }
  expect(
    sectionStart,
    isNot(-1),
    reason: 'Section §$section not found in roadmap',
  );

  int sectionEnd = lines.length;
  for (int i = sectionStart + 1; i < lines.length; i++) {
    if (lines[i].startsWith('### ') || lines[i].startsWith('## ')) {
      sectionEnd = i;
      break;
    }
  }

  final sectionLines = lines.sublist(sectionStart, sectionEnd);
  int unticked = 0;
  int ticked = 0;
  for (final line in sectionLines) {
    if (line.contains('- [x]')) ticked++;
    if (line.contains('- [ ]')) unticked++;
  }

  expect(
    unticked,
    equals(0),
    reason: 'All §$section boxes must be ticked; found $unticked unticked',
  );
  expect(
    ticked,
    greaterThanOrEqualTo(expectedCount),
    reason:
        'Expected ≥ $expectedCount ticked boxes in §$section; found $ticked',
  );
}

Matcher isNonZero = isNot(equals(0));
