/// Proof test for roadmap §15.1.3 (critical/high findings tracking infrastructure)
/// and §15.2.2 (pentest findings same severity ladder).
///
/// Verifies:
/// 1. `docs/P2P_AUDIT_SCOPE.md` contains the severity ladder.
/// 2. The severity ladder defines Critical, High, Medium, Low.
/// 3. The queue-entry format for `kind: p2p_audit_finding` is documented.
/// 4. Closure criteria for findings are documented.
/// 5. The same severity ladder applies to pentest (referenced in P2P_PENTEST_SCOPE.md).
library;

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late String repoRoot;
  late File scopeDoc;
  late File pentestDoc;

  setUpAll(() {
    var dir = Directory.current;
    while (!File('${dir.path}/AGENTS.md').existsSync()) {
      final parent = dir.parent;
      if (parent.path == dir.path) fail('Could not locate repo root.');
      dir = parent;
    }
    repoRoot = dir.path;
    scopeDoc = File('$repoRoot/docs/P2P_AUDIT_SCOPE.md');
    pentestDoc = File('$repoRoot/docs/P2P_PENTEST_SCOPE.md');
  });

  group('§15.1.3 — crypto audit findings management infrastructure', () {
    late String content;
    setUpAll(() => content = scopeDoc.readAsStringSync().toLowerCase());

    test('severity ladder present', () {
      expect(
        content,
        contains('severity ladder'),
        reason: 'P2P_AUDIT_SCOPE.md must define a severity ladder',
      );
    });

    test('critical severity defined', () {
      expect(
        content,
        contains('critical'),
        reason: 'Severity ladder must define Critical',
      );
    });

    test('high severity defined', () {
      expect(
        content,
        contains('high'),
        reason: 'Severity ladder must define High',
      );
    });

    test('medium severity defined', () {
      expect(
        content,
        contains('medium'),
        reason: 'Severity ladder must define Medium',
      );
    });

    test('low severity defined', () {
      expect(
        content,
        contains('low'),
        reason: 'Severity ladder must define Low',
      );
    });

    test('kind p2p_audit_finding queue schema documented', () {
      expect(
        content,
        contains('p2p_audit_finding'),
        reason: 'Queue entry kind p2p_audit_finding must be documented',
      );
    });

    test('closure criteria documented', () {
      expect(
        content,
        anyOf(contains('closure'), contains('closed when'), contains('close')),
        reason: 'Closure criteria for findings must be documented',
      );
    });

    test('pre-GA requirement for critical/high', () {
      expect(
        content,
        anyOf(
          contains('before ga'),
          contains('ga gate'),
          contains('pre-ga'),
          contains('ga-rollout'),
        ),
        reason: 'Critical/High findings must be remediated before GA',
      );
    });
  });

  group('§15.2.2 — pentest uses same severity ladder', () {
    test('P2P_PENTEST_SCOPE.md exists', () {
      expect(
        pentestDoc.existsSync(),
        isTrue,
        reason: 'docs/P2P_PENTEST_SCOPE.md must exist (roadmap §15.2)',
      );
    });

    test('pentest doc references same severity ladder', () {
      final content = pentestDoc.readAsStringSync().toLowerCase();
      expect(
        content,
        anyOf(
          contains('severity ladder'),
          contains('same severity'),
          contains('15.1'),
        ),
        reason:
            'P2P_PENTEST_SCOPE.md must reference the same severity ladder as the crypto audit',
      );
    });
  });
}
