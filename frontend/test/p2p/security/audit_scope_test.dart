/// Proof test for roadmap §15.1.1 (engagement scope) and §15.1.2 (deliverables).
///
/// Verifies:
/// 1. `docs/P2P_AUDIT_SCOPE.md` exists and is non-empty.
/// 2. It covers all required cryptographic protocol topics.
/// 3. It specifies the deliverables (written report + severity list + remediation plan).
library;

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late String repoRoot;
  late File scopeDoc;

  setUpAll(() {
    var dir = Directory.current;
    while (!File('${dir.path}/AGENTS.md').existsSync()) {
      final parent = dir.parent;
      if (parent.path == dir.path) fail('Could not locate repo root.');
      dir = parent;
    }
    repoRoot = dir.path;
    scopeDoc = File('$repoRoot/docs/P2P_AUDIT_SCOPE.md');
  });

  test('P2P_AUDIT_SCOPE.md exists', () {
    expect(
      scopeDoc.existsSync(),
      isTrue,
      reason: 'docs/P2P_AUDIT_SCOPE.md must exist (roadmap §15.1.1)',
    );
  });

  test('P2P_AUDIT_SCOPE.md is non-empty', () {
    final content = scopeDoc.readAsStringSync();
    expect(content.length, greaterThan(500),
        reason: 'Scope document must be substantive (>500 chars)');
  });

  group('§15.1.1 — engagement scope covers cryptographic protocol topics', () {
    late String content;
    setUpAll(() => content = scopeDoc.readAsStringSync().toLowerCase());

    test('forward secrecy', () {
      expect(content, contains('forward secrecy'),
          reason: 'Scope must reference forward secrecy');
    });

    test('replay protection', () {
      expect(content, contains('replay protection'),
          reason: 'Scope must reference replay protection');
    });

    test('downgrade resistance', () {
      expect(content, contains('downgrade'),
          reason: 'Scope must reference downgrade resistance');
    });

    test('KDF parameter choice', () {
      expect(content, contains('kdf'),
          reason: 'Scope must reference KDF parameter choice');
    });

    test('AEAD nonce construction', () {
      expect(content, contains('aead'),
          reason: 'Scope must reference AEAD nonce construction');
    });

    test('signature ceremonies', () {
      expect(content, contains('signature'),
          reason: 'Scope must reference signature ceremonies');
    });

    test('references P2P_PROTOCOL.md', () {
      expect(content, contains('p2p_protocol'),
          reason: 'Scope must reference docs/P2P_PROTOCOL.md');
    });
  });

  group('§15.1.2 — deliverables specification present', () {
    late String content;
    setUpAll(() => content = scopeDoc.readAsStringSync().toLowerCase());

    test('written report deliverable', () {
      expect(content, anyOf(contains('written report'), contains('report covering')),
          reason: 'Deliverables must include a written report');
    });

    test('findings with severity', () {
      expect(
          content,
          anyOf(contains('severity'), contains('critical'), contains('findings')),
          reason: 'Deliverables must list findings with severity');
    });

    test('remediation plan', () {
      expect(content, anyOf(contains('remediation plan'), contains('remediation')),
          reason: 'Deliverables must include a remediation plan');
    });

    test('deliverables section heading present', () {
      final rawContent = scopeDoc.readAsStringSync();
      expect(rawContent, contains('Deliverables'),
          reason: 'A Deliverables section must exist');
    });
  });
}
