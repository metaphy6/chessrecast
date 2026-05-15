import 'package:flutter_test/flutter_test.dart';
import '../../lib/services/p2p/protocol/frame.dart';

void main() {
  group('MoveCanon — move canonicalisation (§1.3 / §9)', () {
    group('standard UCI moves', () {
      test('pawn push is lowercase', () {
        expect(MoveCanon.canonicalise('e2e4'), 'e2e4');
        expect(MoveCanon.canonicalise('E2E4'), 'e2e4');
      });

      test('minor piece move is lowercase', () {
        expect(MoveCanon.canonicalise('g1f3'), 'g1f3');
        expect(MoveCanon.canonicalise('G1F3'), 'g1f3');
      });

      test('promotion to queen is lowercase', () {
        expect(MoveCanon.canonicalise('a7a8Q'), 'a7a8q');
        expect(MoveCanon.canonicalise('a7a8q'), 'a7a8q');
      });

      test('promotion to rook is lowercase', () {
        expect(MoveCanon.canonicalise('h7h8R'), 'h7h8r');
      });

      test('promotion to bishop is lowercase', () {
        expect(MoveCanon.canonicalise('b7b8B'), 'b7b8b');
      });

      test('promotion to knight is lowercase', () {
        expect(MoveCanon.canonicalise('c7c8N'), 'c7c8n');
      });

      test('castling moves are lowercase', () {
        expect(MoveCanon.canonicalise('e1g1'), 'e1g1');
        expect(MoveCanon.canonicalise('e1c1'), 'e1c1');
        expect(MoveCanon.canonicalise('e8g8'), 'e8g8');
        expect(MoveCanon.canonicalise('e8c8'), 'e8c8');
      });

      test('empty string returns empty string', () {
        expect(MoveCanon.canonicalise(''), '');
      });
    });

    group('mod-tagged king moves (heir mod)', () {
      test('K prefix is preserved as uppercase', () {
        expect(MoveCanon.canonicalise('Ka7a8'), 'Ka7a8');
      });

      test('lowercase k prefix becomes uppercase K', () {
        expect(MoveCanon.canonicalise('ka7a8'), 'Ka7a8');
      });

      test('body of tagged king move is lowercase', () {
        expect(MoveCanon.canonicalise('KE5F6'), 'Ke5f6');
      });
    });

    group('isValidSyntax', () {
      test('valid standard moves pass', () {
        expect(MoveCanon.isValidSyntax('e2e4'), isTrue);
        expect(MoveCanon.isValidSyntax('a7a8q'), isTrue);
        expect(MoveCanon.isValidSyntax('h1h8'), isTrue);
      });

      test('invalid moves fail', () {
        expect(MoveCanon.isValidSyntax(''), isFalse);
        expect(MoveCanon.isValidSyntax('e2e9'), isFalse); // row 9 invalid
        expect(MoveCanon.isValidSyntax('i2e4'), isFalse); // col i invalid
        expect(MoveCanon.isValidSyntax('e2e4z'), isFalse); // bad promo piece
        expect(MoveCanon.isValidSyntax('e2'), isFalse);   // too short
      });

      test('valid tagged king moves pass', () {
        expect(MoveCanon.isValidSyntax('Ka7a8'), isTrue);
        expect(MoveCanon.isValidSyntax('Ke5f6'), isTrue);
      });

      test('tagged king with promotion does not pass', () {
        // K-tagged king can't promote
        expect(MoveCanon.isValidSyntax('Ka7a8q'), isFalse);
      });
    });

    group('canonicalise is idempotent', () {
      final moves = ['e2e4', 'a7a8q', 'Ka7a8', 'g1f3', 'e1g1'];
      for (final m in moves) {
        test('canonicalise("$m") is idempotent', () {
          expect(MoveCanon.canonicalise(MoveCanon.canonicalise(m)), m);
        });
      }
    });
  });
}
