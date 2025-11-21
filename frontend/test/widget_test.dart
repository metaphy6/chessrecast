// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chessrecast/main.dart';

void main() {
  testWidgets('Chess app loads successfully', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ChessRecastApp());

    // Verify that our chess app loads with the correct title
    expect(find.text('Chess Recast'), findsOneWidget);

    // Verify that the chess board is present (it should have chess squares)
    expect(find.byType(Container), findsWidgets);
  });
}
