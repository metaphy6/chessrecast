/// Proof test for roadmap §15.5.1 — Phase 15 acceptance gate.
///
/// Verifies that ALL Phase 15 artifacts are present and substantive:
/// - docs/p2p/P2P_AUDIT_SCOPE.md    (§15.1.1, §15.1.2)
/// - docs/p2p/P2P_AUDIT_HISTORY.md  (§15.1.4)
/// - docs/p2p/P2P_PENTEST_SCOPE.md  (§15.2.1)
/// - frontend/web/.well-known/security.txt  (§15.3.1)
/// - docs/p2p/P2P_BUG_BOUNTY.md     (§15.3.2–15.3.5)
///
/// Additionally verifies that all mandatory field content is present
/// (the individual leaf tests cover detailed assertions; this gate
/// confirms the full suite of Phase 15 deliverables is intact).
library;

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late String repoRoot;

  setUpAll(() {
    var dir = Directory.current;
    while (!File('${dir.path}/AGENTS.md').existsSync()) {
      final parent = dir.parent;
      if (parent.path == dir.path) fail('Could not locate repo root.');
      dir = parent;
    }
    repoRoot = dir.path;
  });

  group('§15.5.1 — Phase 15 acceptance gate: all artifacts present', () {
    test('P2P_AUDIT_SCOPE.md exists (§15.1.1, §15.1.2)', () {
      expect(
        File('$repoRoot/docs/p2p/P2P_AUDIT_SCOPE.md').existsSync(),
        isTrue,
        reason: 'docs/p2p/P2P_AUDIT_SCOPE.md must exist',
      );
    });

    test('P2P_AUDIT_SCOPE.md has findings management section (§15.1.3)', () {
      final content = File(
        '$repoRoot/docs/p2p/P2P_AUDIT_SCOPE.md',
      ).readAsStringSync().toLowerCase();
      expect(
        content,
        anyOf(
          contains('findings management'),
          contains('severity ladder'),
          contains('p2p_audit_finding'),
        ),
      );
    });

    test('P2P_AUDIT_HISTORY.md exists (§15.1.4)', () {
      expect(
        File('$repoRoot/docs/p2p/P2P_AUDIT_HISTORY.md').existsSync(),
        isTrue,
        reason: 'docs/p2p/P2P_AUDIT_HISTORY.md must exist',
      );
    });

    test('P2P_PENTEST_SCOPE.md exists (§15.2.1)', () {
      expect(
        File('$repoRoot/docs/p2p/P2P_PENTEST_SCOPE.md').existsSync(),
        isTrue,
        reason: 'docs/p2p/P2P_PENTEST_SCOPE.md must exist',
      );
    });

    test('security.txt exists with Contact and Expires (§15.3.1)', () {
      final f = File('$repoRoot/frontend/web/.well-known/security.txt');
      expect(
        f.existsSync(),
        isTrue,
        reason: 'frontend/web/.well-known/security.txt must exist',
      );
      final content = f.readAsStringSync();
      expect(content, contains('Contact:'));
      expect(content, contains('Expires:'));
    });

    test(
      'P2P_BUG_BOUNTY.md exists with SLA, scope, disclosure sections (§15.3.2–15.3.5)',
      () {
        final f = File('$repoRoot/docs/p2p/P2P_BUG_BOUNTY.md');
        expect(
          f.existsSync(),
          isTrue,
          reason: 'docs/p2p/P2P_BUG_BOUNTY.md must exist',
        );
        final content = f.readAsStringSync().toLowerCase();
        expect(
          content,
          anyOf(contains('sla'), contains('triage')),
          reason: 'Bug bounty doc must define triage SLA',
        );
        expect(
          content,
          anyOf(contains('scope'), contains('in scope')),
          reason: 'Bug bounty doc must define scope',
        );
        expect(
          content,
          anyOf(contains('disclosure'), contains('coordinated disclosure')),
          reason: 'Bug bounty doc must define disclosure process',
        );
      },
    );

    test('P2P_AUDIT_SCOPE.md has all quality attributes (§15.4.1–15.4.5)', () {
      final content = File(
        '$repoRoot/docs/p2p/P2P_AUDIT_SCOPE.md',
      ).readAsStringSync().toLowerCase();
      expect(content, contains('parallel')); // §15.4.1 performance
      expect(content, contains('queue')); // §15.4.2 efficiency
      expect(content, contains('regression test')); // §15.4.3 stability
      expect(content, contains('reproducib')); // §15.4.4 reliability
      expect(
        content,
        anyOf(
          contains('paid for'),
          contains('engaged for'),
          contains('zero findings'),
        ),
      ); // §15.4.5 integrity
    });
  });
}
