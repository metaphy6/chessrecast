// Proof test for roadmap leaf 8.2.b1:
// Connection-state UI: every state has a Semantics label;
// live-region announcements on state change.
//
// Verifies that P2pConnectionStateBadge:
//   1. produces a non-empty semantics label for each of the 6 connection states,
//   2. uses liveRegion=true so screen readers announce changes automatically,
//   3. updates its label when the state prop changes.

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chessrecast/ui/p2p_connection_state.dart';

void main() {
  group('P2pConnectionStateBadge accessibility', () {
    testWidgets('all states produce a non-empty semantics label', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      for (final state in P2pConnectionState.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: P2pConnectionStateBadge(state: state)),
          ),
        );
        expect(
          find.bySemanticsLabel(state.accessibilityLabel),
          findsOneWidget,
          reason:
              '${state.name} state must produce exactly one semantics node with its label',
        );
      }
      handle.dispose();
    });

    testWidgets(
      'badge is a liveRegion so state changes are announced to screen readers',
      (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: P2pConnectionStateBadge(
                state: P2pConnectionState.connecting,
              ),
            ),
          ),
        );
        final node = tester.getSemantics(
          find.bySemanticsLabel(
            P2pConnectionState.connecting.accessibilityLabel,
          ),
        );
        expect(
          node.hasFlag(SemanticsFlag.isLiveRegion),
          isTrue,
          reason:
              'liveRegion must be true so VoiceOver/TalkBack announces changes',
        );
        handle.dispose();
      },
    );

    testWidgets('semantics label changes when state changes', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: P2pConnectionStateBadge(state: P2pConnectionState.connecting),
          ),
        ),
      );
      expect(
        find.bySemanticsLabel(P2pConnectionState.connecting.accessibilityLabel),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(P2pConnectionState.connected.accessibilityLabel),
        findsNothing,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: P2pConnectionStateBadge(state: P2pConnectionState.connected),
          ),
        ),
      );
      expect(
        find.bySemanticsLabel(P2pConnectionState.connected.accessibilityLabel),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(P2pConnectionState.connecting.accessibilityLabel),
        findsNothing,
      );

      handle.dispose();
    });

    testWidgets('connecting label contains "Connecting" text', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: P2pConnectionStateBadge(state: P2pConnectionState.connecting),
          ),
        ),
      );
      final node = tester.getSemantics(
        find.bySemanticsLabel(P2pConnectionState.connecting.accessibilityLabel),
      );
      expect(node.label, contains('Connecting'));
      handle.dispose();
    });
  });
}
