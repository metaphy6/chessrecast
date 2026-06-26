/// Proof test for roadmap §18.1 — data-flow completeness CI gate.
///
/// Verifies that:
///   1. [xops/p2p/data-flow-completeness-check.sh] exists and is executable.
///   2. [docs/p2p/P2P_PRIVACY.md] contains a `## Data-flow inventory` section.
///   3. All 11 required data-class rows are present in the inventory.
///   4. The completeness-check script exits 0 (no undocumented P2P writes).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Data classes mandated by roadmap §18.1 inventory table.
const _requiredDataClasses = [
  'Account pubkey',
  'Device pubkey',
  'Wrapped recovery blob',
  'Transcript',
  'Chat history (player)',
  'Chat history (spectator)',
  'Push token',
  'Telemetry batch',
  'Abuse report bundle',
  'Diag bundle (opt-in)',
  'Forensic bundle',
];

Directory _repoRoot() {
  var dir = Directory.fromUri(Platform.script).parent;
  while (dir.path != dir.parent.path) {
    if (File('${dir.path}/AGENTS.md').existsSync()) return dir;
    dir = dir.parent;
  }
  throw StateError('Could not find repo root (no AGENTS.md found)');
}

void main() {
  late Directory repo;

  setUpAll(() {
    repo = _repoRoot();
  });

  test('data-flow-completeness-check.sh exists and is executable', () {
    final script = File(
      '${repo.path}/xops/p2p/data-flow-completeness-check.sh',
    );
    expect(
      script.existsSync(),
      isTrue,
      reason:
          'xops/p2p/data-flow-completeness-check.sh must exist (roadmap §18.1)',
    );
    final stat = script.statSync();
    // mode bit 0111 (rwx) for owner
    expect(
      stat.mode & 0x40,
      isNonZero,
      reason: 'data-flow-completeness-check.sh must be executable',
    );
  });

  test('P2P_PRIVACY.md has a Data-flow inventory section', () {
    final privacyDoc = File('${repo.path}/docs/p2p/P2P_PRIVACY.md');
    expect(
      privacyDoc.existsSync(),
      isTrue,
      reason: 'docs/p2p/P2P_PRIVACY.md must exist',
    );
    final content = privacyDoc.readAsStringSync();
    expect(
      content,
      contains('## Data-flow inventory'),
      reason:
          'P2P_PRIVACY.md must contain a "## Data-flow inventory" section (roadmap §18.1)',
    );
  });

  group('P2P_PRIVACY.md inventory table contains all required data classes', () {
    late String privacyContent;

    setUpAll(() {
      final privacyDoc = File('${repo.path}/docs/p2p/P2P_PRIVACY.md');
      if (privacyDoc.existsSync()) {
        privacyContent = privacyDoc.readAsStringSync();
      } else {
        privacyContent = '';
      }
    });

    for (final dataClass in _requiredDataClasses) {
      test('inventory contains "$dataClass"', () {
        expect(
          privacyContent,
          contains(dataClass),
          reason:
              'P2P_PRIVACY.md data-flow inventory must include data class "$dataClass" (roadmap §18.1)',
        );
      });
    }
  });

  test(
    'data-flow-completeness-check.sh exits 0 (no undocumented P2P writes)',
    () async {
      final script = File(
        '${repo.path}/xops/p2p/data-flow-completeness-check.sh',
      );
      if (!script.existsSync()) {
        fail(
          'Script does not exist — implement xops/p2p/data-flow-completeness-check.sh first',
        );
      }
      final result = await Process.run('bash', [
        script.path,
        '--repo-root=${repo.path}',
      ], workingDirectory: repo.path);
      if (result.exitCode != 0) {
        fail(
          'data-flow-completeness-check.sh failed (exit ${result.exitCode}):\n'
          '${result.stdout}\n${result.stderr}',
        );
      }
    },
  );
}
