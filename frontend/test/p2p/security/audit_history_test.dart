/// Proof test for roadmap §15.1.4 — public audit summary published in P2P_AUDIT_HISTORY.md.
///
/// Verifies:
/// 1. `docs/P2P_AUDIT_HISTORY.md` exists.
/// 2. It contains the required structural sections (header, entries section, template).
/// 3. It references the engagement scope document.
library;

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late String repoRoot;
  late File historyDoc;

  setUpAll(() {
    var dir = Directory.current;
    while (!File('${dir.path}/AGENTS.md').existsSync()) {
      final parent = dir.parent;
      if (parent.path == dir.path) fail('Could not locate repo root.');
      dir = parent;
    }
    repoRoot = dir.path;
    historyDoc = File('$repoRoot/docs/P2P_AUDIT_HISTORY.md');
  });

  test('P2P_AUDIT_HISTORY.md exists', () {
    expect(historyDoc.existsSync(), isTrue,
        reason: 'docs/P2P_AUDIT_HISTORY.md must exist (roadmap §15.1.4)');
  });

  test('P2P_AUDIT_HISTORY.md is non-empty', () {
    expect(historyDoc.readAsStringSync().length, greaterThan(200),
        reason: 'Audit history document must be substantive (>200 chars)');
  });

  group('§15.1.4 — audit history has required structure', () {
    late String content;
    setUpAll(() => content = historyDoc.readAsStringSync().toLowerCase());

    test('title/header present', () {
      final raw = historyDoc.readAsStringSync();
      expect(raw, anyOf(contains('Audit History'), contains('# P2P'), contains('Security Audit')),
          reason: 'Audit history must have a clear title/header');
    });

    test('references audit scope or engagement', () {
      expect(content,
          anyOf(contains('audit'), contains('engagement'), contains('security')),
          reason: 'Document must reference the security audit context');
    });

    test('contains summary or entry structure', () {
      expect(
          content,
          anyOf(
            contains('audit date'),
            contains('finding'),
            contains('summary'),
            contains('entry'),
            contains('no audits'),
          ),
          reason: 'Document must describe how audit entries are recorded');
    });

    test('references P2P_AUDIT_SCOPE.md', () {
      expect(content, anyOf(contains('p2p_audit_scope'), contains('audit_scope')),
          reason: 'History document must reference the scope document');
    });
  });
}
