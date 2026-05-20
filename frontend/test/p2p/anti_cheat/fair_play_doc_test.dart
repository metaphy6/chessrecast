// §13.1.b1 + §13.1.b2 + §13.3.b1 + §13.5.b1 — P2P_FAIR_PLAY.md proof test.
//
// Phase 13 is a documentation phase. The proof that each leaf is complete is
// that docs/P2P_FAIR_PLAY.md exists and contains the required declarations.
//
// §13.1.b1 — External-engine assistance is out of scope and documented.
// §13.1.b2 — Rating system is out of scope; documented as OQ-10.
// §13.3.b1 — Future federated-rating door is documented for reference.
// §13.5.b1 — Acceptance gate: P2P_FAIR_PLAY.md published, casual-play
//            disclosure statement present.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

File get _fairPlayDoc {
  // When run from frontend/ via `flutter test`, cwd is the frontend/ dir.
  final cwd = Directory.current.path;
  return File('$cwd/../docs/P2P_FAIR_PLAY.md');
}

String get _content => _fairPlayDoc.readAsStringSync().toLowerCase();

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('§13.1.b1 — External-engine assistance out-of-scope', () {
    test('P2P_FAIR_PLAY.md exists', () {
      expect(
        _fairPlayDoc.existsSync(),
        isTrue,
        reason: 'docs/P2P_FAIR_PLAY.md must be published',
      );
    });

    test('declares external-engine assistance is out of scope', () {
      expect(
        _content,
        contains('external engine'),
        reason: 'P2P_FAIR_PLAY.md must document external-engine scope',
      );
    });

    test('mentions no central observer', () {
      expect(
        _content,
        contains('central observer'),
        reason: 'P2P_FAIR_PLAY.md must explain why detection is impossible',
      );
    });

    test('includes casual-play disclosure statement', () {
      expect(
        _content,
        contains('casual play'),
        reason: 'P2P_FAIR_PLAY.md must include the casual-play disclosure copy',
      );
    });
  });

  group('§13.1.b2 — Rating system out of scope', () {
    test('mentions rating system as out of scope', () {
      expect(
        _content,
        contains('rating system'),
        reason: 'P2P_FAIR_PLAY.md must document rating-system scope',
      );
    });

    test('references OQ-10 open question', () {
      // Case-sensitive: "OQ-10" is an identifier, not prose.
      expect(
        _fairPlayDoc.readAsStringSync(),
        contains('OQ-10'),
        reason: 'P2P_FAIR_PLAY.md must reference OQ-10',
      );
    });
  });

  group('§13.3.b1 — Future federated-rating door', () {
    test('mentions federation as future rating path', () {
      expect(
        _content,
        contains('federat'),
        reason:
            'P2P_FAIR_PLAY.md must document the federated-rating future path',
      );
    });
  });

  group('§13.4.b3 — Reliability: docs reflect enforceability accurately', () {
    test('contains no marketing claim of cheat-proof play', () {
      // The doc must NOT claim the system is cheat-proof.
      expect(
        _content,
        isNot(contains('cheat-proof')),
        reason: 'P2P_FAIR_PLAY.md must not claim cheat-proof play',
      );
    });
  });

  group('§13.5.b1 — Acceptance gate', () {
    test('disclosure copy for first P2P launch is present', () {
      // The roadmap requires that the casual-play disclosure is surfaced
      // on first P2P launch.  P2P_FAIR_PLAY.md must contain the verbatim
      // copy that the UI will display.
      expect(
        _content,
        contains('no anti-cheat'),
        reason: 'P2P_FAIR_PLAY.md must contain the UI disclosure copy',
      );
    });
  });
}
