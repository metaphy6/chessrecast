// Proof test for roadmap leaf 8.2.b2:
// Recovery-code entry: large-font / high-contrast mode tested;
// screen-reader announces word numbers.
//
// Tests the RecoveryWordEntryWidget which renders individual word input
// fields annotated with word-number semantics labels.

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chessrecast/ui/recovery_word_entry.dart';

void main() {
  group('RecoveryWordEntryWidget accessibility', () {
    testWidgets('word-number semantics label is announced per field', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: RecoveryWordEntryWidget(
            wordIndex: 1,
            controller: TextEditingController(),
            onChanged: (_) {},
          ),
        ),
      ));
      // Screen reader must announce "Word 1" (or similar) for each field.
      expect(
        find.bySemanticsLabel(RegExp(r'[Ww]ord\s*1')),
        findsWidgets,
        reason: 'Field for word 1 must expose "Word 1" in its semantics label',
      );
      handle.dispose();
    });

    testWidgets('widget renders in large-font mode without overflow', (tester) async {
      // Set textScaler to 2.0 (large-font / accessibility mode).
      await tester.pumpWidget(MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RecoveryWordEntryWidget(
                wordIndex: 3,
                controller: TextEditingController(),
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      ));
      // Must not throw a RenderFlex overflow error.
      expect(tester.takeException(), isNull);
    });

    testWidgets('widget renders in high-contrast mode', (tester) async {
      await tester.pumpWidget(MediaQuery(
        data: const MediaQueryData(highContrast: true),
        child: MaterialApp(
          home: Scaffold(
            body: RecoveryWordEntryWidget(
              wordIndex: 2,
              controller: TextEditingController(),
              onChanged: (_) {},
            ),
          ),
        ),
      ));
      expect(tester.takeException(), isNull);
    });

    testWidgets('multiple fields each announce their own word number', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              for (int i = 1; i <= 3; i++)
                RecoveryWordEntryWidget(
                  wordIndex: i,
                  controller: TextEditingController(),
                  onChanged: (_) {},
                ),
            ],
          ),
        ),
      ));
      for (int i = 1; i <= 3; i++) {
        expect(
          find.bySemanticsLabel(RegExp('Word\\s*$i', caseSensitive: false)),
          findsWidgets,
          reason: 'Field for word $i must expose "Word $i" in its semantics label',
        );
      }
      handle.dispose();
    });
  });
}
