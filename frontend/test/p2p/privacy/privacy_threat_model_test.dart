/// Proof test for roadmap §18.2 — Privacy threat model T-PRIV-001 through T-PRIV-006.
///
/// Verifies that docs/P2P_PRIVACY.md documents each privacy threat with its
/// mitigation. Only T-PRIV-002 carries a Go-side proof test for the traffic-
/// padding implementation; the remaining entries are documentation gates.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Directory _repoRoot() {
  var dir = Directory.fromUri(Platform.script).parent;
  while (dir.path != dir.parent.path) {
    if (File('${dir.path}/AGENTS.md').existsSync()) return dir;
    dir = dir.parent;
  }
  throw StateError('Could not find repo root (no AGENTS.md found)');
}

void main() {
  late String privacyContent;
  late Directory repo;

  setUpAll(() {
    repo = _repoRoot();
    final doc = File('${repo.path}/docs/P2P_PRIVACY.md');
    expect(doc.existsSync(), isTrue, reason: 'docs/P2P_PRIVACY.md must exist');
    privacyContent = doc.readAsStringSync();
  });

  group('§18.2 T-PRIV threat entries are documented in P2P_PRIVACY.md', () {
    test('T-PRIV-001: Cross-session linkage via stable fingerprint', () {
      expect(
        privacyContent,
        contains('T-PRIV-001'),
        reason: 'T-PRIV-001 must be documented in P2P_PRIVACY.md',
      );
      expect(
        privacyContent,
        contains('cross-session'),
        reason: 'T-PRIV-001 must describe the cross-session linkage threat',
      );
    });

    test('T-PRIV-002: Traffic analysis on signaling endpoints', () {
      expect(
        privacyContent,
        contains('T-PRIV-002'),
        reason: 'T-PRIV-002 must be documented in P2P_PRIVACY.md',
      );
      expect(
        privacyContent,
        contains('traffic'),
        reason: 'T-PRIV-002 must describe traffic analysis mitigation',
      );
    });

    test('T-PRIV-002: traffic_padding_test.go exists', () {
      final testFile = File(
        '${repo.path}/signaling/internal/privacy/traffic_padding_test.go',
      );
      expect(
        testFile.existsSync(),
        isTrue,
        reason:
            'signaling/internal/privacy/traffic_padding_test.go must exist (roadmap §18.2 T-PRIV-002 proof)',
      );
    });

    test('T-PRIV-003: Spectator-presence inference via TURN patterns', () {
      expect(
        privacyContent,
        contains('T-PRIV-003'),
        reason: 'T-PRIV-003 must be documented in P2P_PRIVACY.md',
      );
      expect(
        privacyContent,
        containsAny(['spectator', 'Spectator']),
        reason: 'T-PRIV-003 must mention spectator presence inference',
      );
    });

    test('T-PRIV-004: Export-my-data as social-engineering vector', () {
      expect(
        privacyContent,
        contains('T-PRIV-004'),
        reason: 'T-PRIV-004 must be documented in P2P_PRIVACY.md',
      );
      expect(
        privacyContent,
        contains('export'),
        reason: 'T-PRIV-004 must describe the export social-engineering risk',
      );
    });

    test('T-PRIV-005: Telemetry cross-correlation across DP windows', () {
      expect(
        privacyContent,
        contains('T-PRIV-005'),
        reason: 'T-PRIV-005 must be documented in P2P_PRIVACY.md',
      );
      expect(
        privacyContent,
        contains('telemetry'),
        reason: 'T-PRIV-005 must describe the telemetry cross-correlation risk',
      );
    });

    test('T-PRIV-006: Push-token reuse across account rotations', () {
      expect(
        privacyContent,
        contains('T-PRIV-006'),
        reason: 'T-PRIV-006 must be documented in P2P_PRIVACY.md',
      );
      expect(
        privacyContent,
        contains('push'),
        reason: 'T-PRIV-006 must describe the push-token reuse risk',
      );
    });
  });
}

/// Convenience matcher extension.
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
