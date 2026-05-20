// §14.2 — Per-message local mute proof tests.
//
// Covers: new-contact soft-mute default, explicit hard-mute toggle,
// reveal-soft-mute transition, and shouldShowMessage semantics.
library;

import 'package:flutter_test/flutter_test.dart';
import '../../../lib/services/p2p/ui/chat_mute.dart';

void main() {
  group('§14.2 — ChatMuteService: new-contact default mute', () {
    late ChatMuteService service;

    setUp(() => service = ChatMuteService());

    test('stateFor returns unmuted for unknown fingerprint', () {
      expect(service.stateFor('fp-unknown'), equals(MuteState.unmuted));
    });

    test('applyNewContactDefault sets softMuted', () {
      service.applyNewContactDefault('fp-new');
      expect(service.stateFor('fp-new'), equals(MuteState.softMuted));
    });

    test('applyNewContactDefault is a no-op when state already set', () {
      service.setMute('fp-new', MuteState.hardMuted);
      service.applyNewContactDefault('fp-new'); // should not overwrite
      expect(service.stateFor('fp-new'), equals(MuteState.hardMuted));
    });

    test('shouldShowMessage returns false for softMuted', () {
      service.applyNewContactDefault('fp-new');
      expect(service.shouldShowMessage('fp-new'), isFalse);
    });

    test('revealSoftMuted transitions softMuted → unmuted', () {
      service.applyNewContactDefault('fp-new');
      service.revealSoftMuted('fp-new');
      expect(service.stateFor('fp-new'), equals(MuteState.unmuted));
      expect(service.shouldShowMessage('fp-new'), isTrue);
    });

    test('revealSoftMuted does not affect hardMuted state', () {
      service.setMute('fp-alice', MuteState.hardMuted);
      service.revealSoftMuted('fp-alice');
      expect(service.stateFor('fp-alice'), equals(MuteState.hardMuted));
    });

    test('toggleHardMute transitions unmuted → hardMuted', () {
      service.toggleHardMute('fp-alice');
      expect(service.stateFor('fp-alice'), equals(MuteState.hardMuted));
    });

    test('toggleHardMute transitions hardMuted → unmuted', () {
      service.setMute('fp-alice', MuteState.hardMuted);
      service.toggleHardMute('fp-alice');
      expect(service.stateFor('fp-alice'), equals(MuteState.unmuted));
    });

    test('shouldShowMessage returns false for hardMuted', () {
      service.setMute('fp-alice', MuteState.hardMuted);
      expect(service.shouldShowMessage('fp-alice'), isFalse);
    });

    test('shouldShowMessage returns true for unmuted', () {
      service.setMute('fp-alice', MuteState.unmuted);
      expect(service.shouldShowMessage('fp-alice'), isTrue);
    });

    test('reset clears all mute state', () {
      service.setMute('fp-alice', MuteState.hardMuted);
      service.applyNewContactDefault('fp-bob');
      service.reset();
      expect(service.stateFor('fp-alice'), equals(MuteState.unmuted));
      expect(service.stateFor('fp-bob'), equals(MuteState.unmuted));
    });
  });
}
