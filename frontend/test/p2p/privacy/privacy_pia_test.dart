/// Proof test for roadmap §18.6 — Privacy Impact Assessment.
///
/// Verifies that docs/P2P_PRIVACY_PIA.md exists and contains all required
/// PIA template sections before the beta opens.
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
  late String piaContent;

  setUpAll(() {
    final repo = _repoRoot();
    final doc = File('${repo.path}/docs/P2P_PRIVACY_PIA.md');
    expect(doc.existsSync(), isTrue,
        reason: 'docs/P2P_PRIVACY_PIA.md must exist (§18.6)');
    piaContent = doc.readAsStringSync();
  });

  group('§18.6 P2P_PRIVACY_PIA.md required sections', () {
    test('contains lawful basis section', () {
      expect(piaContent, containsAny(['Lawful basis', 'lawful basis', 'Lawful Basis']),
          reason: 'PIA must document the lawful basis (consent + legitimate interest)');
    });

    test('contains data categories section', () {
      expect(piaContent, containsAny(['Data categories', 'data categories', 'Data Categories']),
          reason: 'PIA must list data categories');
    });

    test('contains recipients section', () {
      expect(piaContent, containsAny(['Recipients', 'recipients']),
          reason: 'PIA must document data recipients');
    });

    test('contains retention section', () {
      expect(piaContent, containsAny(['Retention', 'retention']),
          reason: 'PIA must document retention periods');
    });

    test('contains data transfers / residency section', () {
      expect(piaContent, containsAny(['Transfer', 'transfer', 'residency', 'Residency']),
          reason: 'PIA must address data transfers and residency');
    });

    test('contains DPO contact section', () {
      expect(piaContent, containsAny(['DPO', 'Data Protection Officer', 'dpo']),
          reason: 'PIA must document DPO contact information');
    });

    test('contains user rights section', () {
      expect(piaContent, containsAny(['User rights', 'user rights', 'Rights']),
          reason: 'PIA must document user rights (access, portability, erasure, objection)');
    });

    test('contains DPIA risk ratings', () {
      expect(piaContent, containsAny(['DPIA', 'risk rating', 'Risk rating', 'Risk Rating']),
          reason: 'PIA must include DPIA risk ratings');
    });

    test('contains mitigations section', () {
      expect(piaContent, containsAny(['Mitigation', 'mitigation']),
          reason: 'PIA must document mitigations');
    });

    test('contains reviewer attestation', () {
      expect(piaContent, containsAny(['reviewer', 'Reviewer', 'self-attest', 'attest']),
          reason: 'PIA must include reviewer attestation (operator may self-attest for solo deployment)');
    });
  });
}

Matcher containsAny(List<String> values) => _ContainsAnyMatcher(values);

class _ContainsAnyMatcher extends Matcher {
  final List<String> _values;
  const _ContainsAnyMatcher(this._values);

  @override
  bool matches(dynamic item, Map<dynamic, dynamic> matchState) {
    if (item is! String) return false;
    return _values.any((v) => item.contains(v));
  }

  @override
  Description describe(Description description) =>
      description.add('contains any of $_values');
}
