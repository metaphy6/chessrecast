import 'package:flutter_test/flutter_test.dart';
import '../../../lib/services/p2p/protocol/frame.dart';

void main() {
  group('DrawOfferLifecycle (§1.6 / §14)', () {
    test('initial state is none', () {
      final lc = DrawOfferLifecycle();
      expect(lc.state, DrawOfferState.none);
    });

    test('can offer when no offer is pending', () {
      final lc = DrawOfferLifecycle();
      expect(lc.canOffer(0, 0), isTrue);
    });

    test('sendOffer transitions state to pending', () {
      final lc = DrawOfferLifecycle();
      lc.sendOffer(0, 0);
      expect(lc.state, DrawOfferState.pending);
    });

    test('cannot offer again while pending', () {
      final lc = DrawOfferLifecycle();
      lc.sendOffer(0, 10);
      expect(lc.canOffer(0, 11), isFalse);
    });

    test('offer expires after 60s (tick returns true)', () {
      final lc = DrawOfferLifecycle();
      lc.sendOffer(0, 5);
      expect(lc.state, DrawOfferState.pending);
      // Tick at 60000ms — offer should expire
      final expired = lc.tick(60000);
      expect(expired, isTrue);
      expect(lc.state, DrawOfferState.expired);
    });

    test('offer does not expire before 60s', () {
      final lc = DrawOfferLifecycle();
      lc.sendOffer(0, 5);
      final expired = lc.tick(59999);
      expect(expired, isFalse);
      expect(lc.state, DrawOfferState.pending);
    });

    test('retractOnMove transitions pending offer to none', () {
      final lc = DrawOfferLifecycle();
      lc.sendOffer(0, 5);
      lc.retractOnMove();
      expect(lc.state, DrawOfferState.none);
    });

    test('retractOnMove on none does not throw', () {
      final lc = DrawOfferLifecycle();
      expect(() => lc.retractOnMove(), returnsNormally);
    });

    test('onResponse resets pending offer to none', () {
      final lc = DrawOfferLifecycle();
      lc.sendOffer(0, 5);
      lc.onResponse();
      expect(lc.state, DrawOfferState.none);
    });

    test('throttle: cannot re-offer within 10 plies', () {
      final lc = DrawOfferLifecycle();
      lc.sendOffer(0, 10);
      lc.retractOnMove(); // state back to none
      // Only 5 plies later — still within throttle window
      expect(lc.canOffer(1000, 15), isFalse);
    });

    test('throttle: can re-offer after 10 plies', () {
      final lc = DrawOfferLifecycle();
      lc.sendOffer(0, 10);
      lc.retractOnMove();
      // 10+ plies later
      expect(lc.canOffer(1000, 20), isTrue);
    });

    test('opponentClockLt30s bypasses throttle', () {
      final lc = DrawOfferLifecycle();
      lc.sendOffer(0, 10);
      lc.retractOnMove();
      // Only 1 ply later but opponent is in time pressure
      expect(lc.canOffer(1000, 11, opponentClockLt30s: true), isTrue);
    });
  });
}
