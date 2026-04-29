// frontend/tool/scan_secrets.dart
//
// Scan a git diff for high-confidence secret patterns. Runs in pre-push and
// can be run ad-hoc by the agent. Intentionally conservative — false positives
// are better than leaked tokens.
//
// Usage (from frontend/):
//   dart run tool/scan_secrets.dart <git-range>
//
// Defaults to "staged + working tree vs HEAD" if no range is given.
// Exits 1 on findings.

import 'dart:io';

class _Pattern {
  final String name;
  final RegExp re;
  _Pattern(this.name, this.re);
}

final _patterns = <_Pattern>[
  _Pattern('AWS Access Key', RegExp(r'AKIA[0-9A-Z]{16}')),
  _Pattern(
    'AWS Secret Key',
    RegExp(
      r'''aws.{0,20}(secret|access).{0,20}["'][A-Za-z0-9/+=]{40}["']''',
      caseSensitive: false,
    ),
  ),
  _Pattern('GitHub PAT (classic)', RegExp(r'ghp_[A-Za-z0-9]{36}')),
  _Pattern('GitHub PAT (fine-grained)', RegExp(r'github_pat_[A-Za-z0-9_]{82}')),
  _Pattern('GitHub OAuth', RegExp(r'gho_[A-Za-z0-9]{36}')),
  _Pattern('Google API Key', RegExp(r'AIza[0-9A-Za-z\-_]{35}')),
  _Pattern('Slack token', RegExp(r'xox[abpr]-[0-9A-Za-z\-]{10,48}')),
  _Pattern('Stripe live key', RegExp(r'sk_live_[0-9A-Za-z]{24,}')),
  _Pattern(
    'Generic private key block',
    RegExp(r'-----BEGIN (RSA |EC |OPENSSH |DSA |PGP )?PRIVATE KEY-----'),
  ),
  _Pattern(
    'JWT-like',
    RegExp(r'eyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}'),
  ),
];

void main(List<String> args) async {
  final range = args.isNotEmpty ? args.first : 'HEAD';

  final proc = await Process.run('git', ['diff', range]);
  if (proc.exitCode != 0) {
    stderr.writeln('scan_secrets: git diff failed: ${proc.stderr}');
    exit(2);
  }
  final diff = proc.stdout as String;
  if (diff.trim().isEmpty) {
    stdout.writeln('scan_secrets: no diff vs $range — ok.');
    return;
  }

  final findings = <String>[];
  String? file;
  int lineNo = 0;
  for (final line in diff.split('\n')) {
    final m = RegExp(r'^\+\+\+ b/(.+)$').firstMatch(line);
    if (m != null) {
      file = m.group(1);
      continue;
    }
    final hunk = RegExp(r'^@@ .* \+(\d+)').firstMatch(line);
    if (hunk != null) {
      lineNo = int.parse(hunk.group(1)!);
      continue;
    }
    if (!line.startsWith('+') || line.startsWith('+++')) {
      if (line.startsWith(' ') || line.startsWith('+')) lineNo++;
      continue;
    }
    for (final p in _patterns) {
      if (p.re.hasMatch(line)) {
        findings.add('${file ?? "?"}:$lineNo  [${p.name}]  ${_redact(line)}');
      }
    }
    lineNo++;
  }

  if (findings.isEmpty) {
    stdout.writeln('scan_secrets: ok (range=$range).');
    return;
  }
  stderr.writeln('scan_secrets: ${findings.length} possible secret(s):');
  for (final f in findings) {
    stderr.writeln('  $f');
  }
  stderr.writeln(
    'Review carefully. If this is a false positive, add an explicit '
    'comment near the line documenting why.',
  );
  exit(1);
}

String _redact(String line) {
  final trimmed = line.trim();
  if (trimmed.length <= 24) return trimmed;
  return '${trimmed.substring(0, 8)}...[redacted]...${trimmed.substring(trimmed.length - 8)}';
}
