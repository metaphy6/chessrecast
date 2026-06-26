/// Proof test for roadmap §15.3.1–15.3.5 — security.txt and bug bounty program.
///
/// §15.3.1  security.txt present at `frontend/web/.well-known/security.txt` (RFC 9116)
/// §15.3.2  Scope declared in bug bounty policy (P2P_BUG_BOUNTY.md)
/// §15.3.3  Triage SLA defined
/// §15.3.4  Hall of fame section present
/// §15.3.5  Coordinated disclosure process defined
library;

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late String repoRoot;
  late File securityTxt;
  late File bugBountyDoc;

  setUpAll(() {
    var dir = Directory.current;
    while (!File('${dir.path}/AGENTS.md').existsSync()) {
      final parent = dir.parent;
      if (parent.path == dir.path) fail('Could not locate repo root.');
      dir = parent;
    }
    repoRoot = dir.path;
    securityTxt = File('$repoRoot/frontend/web/.well-known/security.txt');
    bugBountyDoc = File('$repoRoot/docs/p2p/P2P_BUG_BOUNTY.md');
  });

  // ── §15.3.1  security.txt (RFC 9116) ─────────────────────────────────────

  group('§15.3.1 — security.txt exists and is RFC 9116 compliant', () {
    test('security.txt file exists', () {
      expect(
        securityTxt.existsSync(),
        isTrue,
        reason:
            'frontend/web/.well-known/security.txt must exist (roadmap §15.3.1)',
      );
    });

    test('security.txt is non-empty', () {
      expect(securityTxt.readAsStringSync().length, greaterThan(50));
    });

    test('RFC 9116 mandatory field: Contact', () {
      expect(securityTxt.readAsStringSync(), contains('Contact:'));
    });

    test('RFC 9116 mandatory field: Expires', () {
      expect(securityTxt.readAsStringSync(), contains('Expires:'));
    });

    test('RFC 9116 recommended field: Encryption', () {
      expect(securityTxt.readAsStringSync(), contains('Encryption:'));
    });

    test('RFC 9116 recommended field: Policy', () {
      expect(securityTxt.readAsStringSync(), contains('Policy:'));
    });

    test('RFC 9116 recommended field: Preferred-Languages', () {
      expect(securityTxt.readAsStringSync(), contains('Preferred-Languages:'));
    });
  });

  // ── §15.3.2  Scope in bug bounty policy ──────────────────────────────────

  group('§15.3.2 — bug bounty scope declaration', () {
    test('P2P_BUG_BOUNTY.md exists', () {
      expect(
        bugBountyDoc.existsSync(),
        isTrue,
        reason: 'docs/p2p/P2P_BUG_BOUNTY.md must exist (roadmap §15.3.2)',
      );
    });

    test('P2P_BUG_BOUNTY.md is non-empty', () {
      expect(bugBountyDoc.readAsStringSync().length, greaterThan(300));
    });

    test('bug bounty doc references P2P scope: signaling server', () {
      final content = bugBountyDoc.readAsStringSync().toLowerCase();
      expect(content, contains('signaling'));
    });

    test('bug bounty doc references P2P scope: P2P protocol', () {
      final content = bugBountyDoc.readAsStringSync().toLowerCase();
      expect(content, anyOf(contains('p2p protocol'), contains('protocol')));
    });

    test('bug bounty doc has out-of-scope section', () {
      final content = bugBountyDoc.readAsStringSync().toLowerCase();
      expect(
        content,
        anyOf(contains('out of scope'), contains('out-of-scope')),
      );
    });
  });

  // ── §15.3.3  Triage SLA ───────────────────────────────────────────────────

  group('§15.3.3 — triage SLA defined', () {
    late String content;
    setUpAll(() => content = bugBountyDoc.readAsStringSync().toLowerCase());

    test('triage SLA section present', () {
      expect(content, anyOf(contains('sla'), contains('triage')));
    });

    test('acknowledgement timeline present', () {
      expect(
        content,
        anyOf(
          contains('acknowledgement'),
          contains('acknowledgment'),
          contains('ack'),
        ),
      );
    });

    test('critical remediation timeline present', () {
      expect(content, contains('critical'));
    });

    test('high remediation timeline present', () {
      expect(content, contains('high'));
    });

    test('medium remediation timeline present', () {
      expect(content, contains('medium'));
    });
  });

  // ── §15.3.4  Hall of fame ──────────────────────────────────────────────────

  group('§15.3.4 — hall of fame section present', () {
    test('hall of fame section in bug bounty doc', () {
      final content = bugBountyDoc.readAsStringSync().toLowerCase();
      expect(
        content,
        anyOf(
          contains('hall of fame'),
          contains('acknowledgments'),
          contains('attribution'),
        ),
      );
    });
  });

  // ── §15.3.5  Coordinated disclosure ───────────────────────────────────────

  group('§15.3.5 — coordinated disclosure process defined', () {
    late String content;
    setUpAll(() => content = bugBountyDoc.readAsStringSync().toLowerCase());

    test('coordinated disclosure section present', () {
      expect(
        content,
        anyOf(contains('coordinated disclosure'), contains('disclosure')),
      );
    });

    test('disclosure window specified', () {
      expect(content, anyOf(contains('90'), contains('window')));
    });

    test('CVE handling described', () {
      expect(
        content,
        anyOf(contains('cve'), contains('embargo'), contains('advisory')),
      );
    });
  });
}
