// §14.6 — Social engineering / URL-shortener warning proof test.
library;

import 'package:flutter_test/flutter_test.dart';
import '../../../lib/services/p2p/ui/social_engineering_detector.dart';

void main() {
  group('§14.6 — URL shortener detection', () {
    test('bit.ly URL triggers urlShortener detection', () {
      final result = scanMessage('Check this out: https://bit.ly/3xFunny');
      expect(result.detected, isTrue);
      expect(result.kind, equals(SocialEngineeringKind.urlShortener));
    });

    test('tinyurl.com URL triggers urlShortener detection', () {
      final result = scanMessage('Follow me here: http://tinyurl.com/abc123');
      expect(result.detected, isTrue);
      expect(result.kind, equals(SocialEngineeringKind.urlShortener));
    });

    test('t.co URL triggers urlShortener detection', () {
      final result = scanMessage('Link: t.co/xyz');
      expect(result.detected, isTrue);
      expect(result.kind, equals(SocialEngineeringKind.urlShortener));
    });

    test('ow.ly triggers urlShortener detection', () {
      final result = scanMessage('ow.ly/def456 — click this');
      expect(result.detected, isTrue);
      expect(result.kind, equals(SocialEngineeringKind.urlShortener));
    });

    test('clean chess message is not flagged', () {
      final result = scanMessage('e4 e5 Nf3 Nc6 — great opening!');
      expect(result.detected, isFalse);
    });

    test('full domain URL (not a shortener) is clean', () {
      final result = scanMessage('Visit https://www.chess.org for rules');
      expect(result.detected, isFalse);
    });

    test('incoming URL shortener triggers phishing warning copy', () {
      final copy = warningCopyFor(
        kind: SocialEngineeringKind.urlShortener,
        direction: MessageDirection.incoming,
      );
      expect(copy, contains('shortened link'));
      expect(copy.toLowerCase(), contains('reveal link'));
    });

    test('outgoing URL shortener triggers "are you sure?" warning', () {
      final copy = warningCopyFor(
        kind: SocialEngineeringKind.urlShortener,
        direction: MessageDirection.outgoing,
      );
      expect(copy.toLowerCase(), contains('are you sure'));
    });

    test('kRequireRevealForLinks is true — links are never auto-clickable', () {
      expect(kRequireRevealForLinks, isTrue);
    });
  });

  group('§14.6 — Seed/recovery phrase detection', () {
    test('seed phrase request is detected', () {
      final result = scanMessage(
        'Please send me your seed phrase to recover the game.',
      );
      expect(result.detected, isTrue);
      expect(
        result.kind,
        equals(SocialEngineeringKind.credentialHarvestPhrase),
      );
    });

    test('recovery phrase mention is detected', () {
      final result = scanMessage('I need your recovery phrase.');
      expect(result.detected, isTrue);
      expect(result.kind, equals(SocialEngineeringKind.seedPhraseRequest));
    });

    test('password request is detected', () {
      final result = scanMessage('What is your password?');
      expect(result.detected, isTrue);
      expect(result.kind, equals(SocialEngineeringKind.passwordRequest));
    });

    test(
      'incoming credential-harvest triggers warning with "sensitive information"',
      () {
        final copy = warningCopyFor(
          kind: SocialEngineeringKind.credentialHarvestPhrase,
          direction: MessageDirection.incoming,
        );
        expect(copy.toLowerCase(), contains('sensitive information'));
        expect(copy.toLowerCase(), contains('never share'));
      },
    );
  });

  group('§14.6 — Mnemonic sequence detection', () {
    // A 12-word sequence looks like a BIP-39 mnemonic.
    test('12-word sequence is detected as mnemonic', () {
      const words =
          'apple banana cherry door eight fence grape hotel index jump king lion';
      final result = scanMessage(words);
      expect(result.detected, isTrue);
      expect(result.kind, equals(SocialEngineeringKind.mnemonicSequence));
    });

    test('5-word phrase is not flagged as mnemonic', () {
      final result = scanMessage('good game well played thanks');
      expect(result.detected, isFalse);
    });
  });

  group('§14.6 — Severity ordering', () {
    test(
      'credential-harvest takes priority over URL shortener in same message',
      () {
        final result = scanMessage('Send me your seed phrase at bit.ly/abc');
        expect(result.detected, isTrue);
        // Credential-harvest has higher severity than URL shortener.
        expect(
          result.kind,
          equals(SocialEngineeringKind.credentialHarvestPhrase),
        );
      },
    );
  });
}
