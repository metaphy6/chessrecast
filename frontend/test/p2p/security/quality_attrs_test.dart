/// Proof test for roadmap §15.4.1–15.4.5 — quality attributes declared in P2P_AUDIT_SCOPE.md §5.
///
/// §15.4.1  Performance — engagement runs in parallel, does not block other phases
/// §15.4.2  Efficiency  — findings tracked as queue entries with proof-test references
/// §15.4.3  Stability   — every remediation carries a regression test
/// §15.4.4  Reliability — audit report reproducibly verifiable against audited commit SHA
/// §15.4.5  Integrity   — firm paid for its time, not its findings
library;

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late String repoRoot;
  late File auditScopeDoc;

  setUpAll(() {
    var dir = Directory.current;
    while (!File('${dir.path}/AGENTS.md').existsSync()) {
      final parent = dir.parent;
      if (parent.path == dir.path) fail('Could not locate repo root.');
      dir = parent;
    }
    repoRoot = dir.path;
    auditScopeDoc = File('$repoRoot/docs/p2p/P2P_AUDIT_SCOPE.md');
  });

  test('P2P_AUDIT_SCOPE.md exists', () {
    expect(
      auditScopeDoc.existsSync(),
      isTrue,
      reason: 'docs/p2p/P2P_AUDIT_SCOPE.md must exist',
    );
  });

  // §15.4.1  Performance ─────────────────────────────────────────────────────

  group('§15.4.1 — Performance: engagement runs in parallel', () {
    test('§5 Quality Commitments section present', () {
      final raw = auditScopeDoc.readAsStringSync();
      expect(raw, anyOf(contains('Quality'), contains('Performance')));
    });

    test('"parallel" keyword present', () {
      final content = auditScopeDoc.readAsStringSync().toLowerCase();
      expect(content, contains('parallel'));
    });

    test('does not block other phases statement present', () {
      final content = auditScopeDoc.readAsStringSync().toLowerCase();
      expect(
        content,
        anyOf(
          contains('does not block'),
          contains('not block'),
          contains('block any other'),
        ),
      );
    });
  });

  // §15.4.2  Efficiency ──────────────────────────────────────────────────────

  group('§15.4.2 — Efficiency: findings tracked as queue entries', () {
    test('"queue entries" or "queue" keyword present', () {
      final content = auditScopeDoc.readAsStringSync().toLowerCase();
      expect(content, anyOf(contains('queue entries'), contains('queue')));
    });

    test('"proof-test" or "proof test" reference present', () {
      final content = auditScopeDoc.readAsStringSync().toLowerCase();
      expect(
        content,
        anyOf(
          contains('proof-test'),
          contains('proof test'),
          contains('proof test references'),
        ),
      );
    });
  });

  // §15.4.3  Stability ───────────────────────────────────────────────────────

  group('§15.4.3 — Stability: remediation carries a regression test', () {
    test('"regression test" keyword present', () {
      final content = auditScopeDoc.readAsStringSync().toLowerCase();
      expect(content, contains('regression test'));
    });

    test('tests-with-code rule referenced', () {
      final content = auditScopeDoc.readAsStringSync().toLowerCase();
      expect(
        content,
        anyOf(
          contains('tests-with-code'),
          contains('tests with code'),
          contains('agents.md'),
        ),
      );
    });
  });

  // §15.4.4  Reliability ─────────────────────────────────────────────────────

  group('§15.4.4 — Reliability: report reproducibly verifiable', () {
    test('"reproducibly verifiable" or "reproducible" present', () {
      final content = auditScopeDoc.readAsStringSync().toLowerCase();
      expect(
        content,
        anyOf(
          contains('reproducibly verifiable'),
          contains('reproducibly'),
          contains('reproducible'),
        ),
      );
    });

    test('"audited commit sha" or "commit sha" present', () {
      final content = auditScopeDoc.readAsStringSync().toLowerCase();
      expect(
        content,
        anyOf(
          contains('audited commit sha'),
          contains('commit sha'),
          contains('commit sha'),
        ),
      );
    });
  });

  // §15.4.5  Integrity ───────────────────────────────────────────────────────

  group('§15.4.5 — Integrity: firm paid for time not findings', () {
    test('"paid for" its time present', () {
      final content = auditScopeDoc.readAsStringSync().toLowerCase();
      expect(
        content,
        anyOf(
          contains('paid for'),
          contains('paid for its time'),
          contains('zero findings'),
        ),
      );
    });
  });
}
