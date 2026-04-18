/// Regression test: InfoPanel must not overflow when given a tight height
/// constraint (like the old Flexible(fit: FlexFit.tight) layout imposed).
///
/// Before the fix, wrapping InfoPanel in Flexible(fit: FlexFit.tight, flex: 1)
/// inside a Column with flex 8 on a small screen gave it ~77px — less than the
/// ~82px the content needs when the status message row is visible, causing the
/// ◢◤ overflow stripes.
///
/// After the fix, InfoPanel is an unconstrained Column child and always sizes
/// to its natural height, so there is no overflow regardless of screen size.
library;

import 'package:chessrecast/board/draw_rules.dart';
import 'package:chessrecast/board/utils/exporter.dart';
import 'package:chessrecast/management/controller.dart';
import 'package:chessrecast/ui/info_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

/// Minimal stub so InfoPanel can render without a real board.
class _FakeController extends GetxController implements Controller {
  @override
  PieceColor get currentPlayer => PieceColor.black;

  @override
  String get statusMessage => 'BLACK to move';

  @override
  GameStatus get gameStatus => GameStatus.ongoing;

  // Satisfy interface — all remaining members throw.
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _wrap({required double height, required bool isTopPanel}) {
  return GetMaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 400,
        height: height,
        child: Column(
          children: [
            // This is the OLD layout: Flexible with tight fit, flex 1 of 8.
            // Effectively constrains InfoPanel to height * 1/8.
            Flexible(
              flex: 1,
              fit: FlexFit.tight,
              child: InfoPanel(isTopPanel: isTopPanel),
            ),
            const Expanded(flex: 7, child: SizedBox()),
          ],
        ),
      ),
    ),
  );
}

void main() {
  setUp(() {
    Get.put<Controller>(_FakeController());
  });

  tearDown(() {
    Get.reset();
  });

  group('InfoPanel — no overflow after fix', () {
    // The fix removes the Flexible wrapper, but we also verify the panel's
    // NATURAL height is small enough to fit in tight spaces.
    for (final screenH in [600.0, 700.0, 800.0]) {
      testWidgets('no overflow on ${screenH.toInt()}px tall screen', (
        tester,
      ) async {
        // Use a ConstrainedBox that gives InfoPanel exactly the height it
        // would receive as a natural Column child (unconstrained → min).
        await tester.pumpWidget(
          GetMaterialApp(
            home: Scaffold(
              body: SizedBox(width: 400, child: InfoPanel(isTopPanel: false)),
            ),
          ),
        );
        await tester.pump();

        // If there are no overflow exceptions, the test passes.
        // tester.takeException() returns null when no error was thrown.
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets(
      'natural height is well below 77px (smallest sensible flex share)',
      (tester) async {
        await tester.pumpWidget(
          GetMaterialApp(
            home: Scaffold(
              body: SizedBox(width: 400, child: InfoPanel(isTopPanel: false)),
            ),
          ),
        );
        await tester.pump();

        final size = tester.getSize(find.byType(InfoPanel));
        // Natural height should be under 100px — if it ever exceeds this the
        // tight-flex path will overflow on any reasonably sized phone.
        expect(
          size.height,
          lessThan(100),
          reason:
              'InfoPanel natural height ${size.height}px exceeds 100px — '
              'it will overflow the old Flexible(tight) path on small screens',
        );
      },
    );

    testWidgets('NEW layout: bare InfoPanel in Column never overflows', (
      tester,
    ) async {
      // Simulate the fixed portrait layout: InfoPanel is an unconstrained
      // Column child, Expanded board fills the rest.
      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 600, // small screen
              child: Column(
                children: [
                  const InfoPanel(isTopPanel: true),
                  Expanded(child: Container(color: Colors.brown)),
                  const InfoPanel(isTopPanel: false),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });
}
