// §11.1 — Time-control negotiation.
//
// HELLO.time_control is the source of truth. Supported tc_kinds: none,
// sudden_death, fischer, bronstein, byo_yomi.
// Validation in HELLO_ACK rejects invalid combinations.
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/clock/time_control.dart';

void main() {
  group('§11.1 tc_negotiation', () {
    test('none time control is valid', () {
      final tc = TimeControl.none();
      expect(tc.kind, equals(TcKind.none));
      final result = tc.validate();
      expect(result, equals(TcValidationResult.ok));
    });

    test('sudden death with positive bank is valid', () {
      final tc = TimeControl.suddenDeath(bankMs: 60000);
      expect(tc.kind, equals(TcKind.suddenDeath));
      expect(tc.validate(), equals(TcValidationResult.ok));
    });

    test('sudden death with zero bank is invalid', () {
      final tc = TimeControl.suddenDeath(bankMs: 0);
      expect(tc.validate(), equals(TcValidationResult.invalidTimeControl));
    });

    test('fischer with positive bank and increment is valid', () {
      final tc = TimeControl.fischer(bankMs: 180000, incrementMs: 2000);
      expect(tc.kind, equals(TcKind.fischer));
      expect(tc.validate(), equals(TcValidationResult.ok));
    });

    test('fischer with negative increment is invalid', () {
      final tc = TimeControl.fischer(bankMs: 60000, incrementMs: -1);
      expect(tc.validate(), equals(TcValidationResult.invalidTimeControl));
    });

    test('bronstein with positive bank and delay is valid', () {
      final tc = TimeControl.bronstein(bankMs: 120000, delayMs: 2000);
      expect(tc.kind, equals(TcKind.bronstein));
      expect(tc.validate(), equals(TcValidationResult.ok));
    });

    test('byo_yomi with at least one overtime period is valid', () {
      final tc = TimeControl.byoYomi(
        bankMs: 0,
        overtimePeriodMs: 30000,
        overtimePeriods: 3,
      );
      expect(tc.kind, equals(TcKind.byoYomi));
      expect(tc.validate(), equals(TcValidationResult.ok));
    });

    test('byo_yomi without overtime periods is invalid', () {
      final tc = TimeControl.byoYomi(
        bankMs: 0,
        overtimePeriodMs: 30000,
        overtimePeriods: 0, // invalid
      );
      expect(tc.validate(), equals(TcValidationResult.invalidTimeControl));
    });

    test('TimeControl serialises and deserialises round-trip', () {
      final tc = TimeControl.fischer(bankMs: 180000, incrementMs: 3000);
      final map = tc.toMap();
      final tc2 = TimeControl.fromMap(map);
      expect(tc2.kind, equals(tc.kind));
      expect(tc2.bankMs, equals(tc.bankMs));
      expect(tc2.incrementMs, equals(tc.incrementMs));
    });
  });
}
