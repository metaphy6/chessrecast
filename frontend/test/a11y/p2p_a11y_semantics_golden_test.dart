// Roadmap §8.6 / leaf 8.6.b4
// A11y semantics survive Flutter SDK upgrades.
//
// These tests use SemanticsHandle to assert the semantic tree shape
// produced by P2P widgets. They are "golden" in the sense that they encode
// the expected semantic structure as explicit assertions — if a Flutter SDK
// upgrade changes how Semantics nodes are merged or labelled, these tests
// catch the regression before it ships.
//
// No image files are used; assertions are against the SemanticsData API
// so they survive rendering changes while still catching semantic regressions.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chessrecast/ui/p2p_connection_state.dart';
import 'package:chessrecast/ui/recovery_word_entry.dart';

// Helper: find all SemanticsNodes matching a predicate.
List<SemanticsNode> _walkSemantics(
  SemanticsNode root,
  bool Function(SemanticsNode) test,
) {
  final result = <SemanticsNode>[];
  void walk(SemanticsNode node) {
    if (test(node)) result.add(node);
    node.visitChildren((child) {
      walk(child);
      return true;
    });
  }

  walk(root);
  return result;
}

void main() {
  group('P2pConnectionStateBadge — semantic golden', () {
    testWidgets('connecting state: liveRegion + non-empty label', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: P2pConnectionStateBadge(state: P2pConnectionState.connecting),
          ),
        ),
      );

      final root =
          tester.binding.pipelineOwner.semanticsOwner!.rootSemanticsNode!;
      final liveRegions = _walkSemantics(
        root,
        (n) => n.getSemanticsData().hasFlag(SemanticsFlag.isLiveRegion),
      );

      expect(
        liveRegions,
        isNotEmpty,
        reason: 'Expected at least one liveRegion node for connecting state',
      );

      for (final node in liveRegions) {
        final label = node.getSemanticsData().label;
        expect(
          label,
          isNotEmpty,
          reason: 'liveRegion node must have non-empty label',
        );
      }

      handle.dispose();
    });

    testWidgets('all states: non-empty accessible label', (tester) async {
      for (final state in P2pConnectionState.values) {
        final handle = tester.ensureSemantics();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: P2pConnectionStateBadge(state: state)),
          ),
        );

        final root =
            tester.binding.pipelineOwner.semanticsOwner!.rootSemanticsNode!;
        final allNodes = _walkSemantics(root, (_) => true);
        final hasLabel = allNodes.any(
          (n) => n.getSemanticsData().label.isNotEmpty,
        );

        expect(
          hasLabel,
          isTrue,
          reason: 'State $state: no semantic node with non-empty label found',
        );

        handle.dispose();
      }
    });
  });

  group('RecoveryWordEntryWidget — semantic golden', () {
    testWidgets('word-1 field has textField semantics with label "Word 1"', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecoveryWordEntryWidget(
              wordIndex: 1,
              controller: TextEditingController(),
              onChanged: (_) {},
            ),
          ),
        ),
      );

      final root =
          tester.binding.pipelineOwner.semanticsOwner!.rootSemanticsNode!;
      final textFields = _walkSemantics(
        root,
        (n) => n.getSemanticsData().hasFlag(SemanticsFlag.isTextField),
      );

      expect(
        textFields,
        isNotEmpty,
        reason: 'Expected a text-field semantics node for word entry',
      );

      // Find one that mentions "Word 1" (label or hint).
      final wordNode = textFields.firstWhere(
        (n) =>
            n.getSemanticsData().label.contains('Word 1') ||
            n.getSemanticsData().hint.contains('Word 1'),
        orElse: () => textFields.first,
      );
      final data = wordNode.getSemanticsData();
      final combined = '${data.label} ${data.hint}';
      expect(
        combined.trim(),
        contains('Word 1'),
        reason: 'Word entry field must announce "Word 1" in label or hint',
      );

      handle.dispose();
    });

    testWidgets('each widget uses its own word index in semantics', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: List.generate(
                3,
                (i) => RecoveryWordEntryWidget(
                  wordIndex: i + 1,
                  controller: TextEditingController(),
                  onChanged: (_) {},
                ),
              ),
            ),
          ),
        ),
      );

      final root =
          tester.binding.pipelineOwner.semanticsOwner!.rootSemanticsNode!;
      for (var idx = 1; idx <= 3; idx++) {
        final label = 'Word $idx';
        final nodes = _walkSemantics(
          root,
          (n) =>
              n.getSemanticsData().label.contains(label) ||
              n.getSemanticsData().hint.contains(label),
        );
        expect(
          nodes,
          isNotEmpty,
          reason: '"$label" not found in semantic tree',
        );
      }

      handle.dispose();
    });
  });
}
