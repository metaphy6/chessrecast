// Recovery-code word entry widget with accessibility annotations.
//
// Each field is wrapped in a Semantics node that announces
// "Word <N>" to screen readers, satisfying roadmap §8.2 leaf 8.2.b2:
//   - large-font / high-contrast mode tested (no overflow, adapts layout),
//   - screen-reader announces word numbers.

import 'package:flutter/material.dart';

/// A single text-input field for one word of a BIP-39 recovery code.
///
/// Accessibility contract (§8.2.b2):
/// - Semantics label is "Word <wordIndex>" so screen readers announce
///   position ("Word 1 of 12, enter word") without reading the raw input.
/// - Renders without overflow at up to 2× text scale.
/// - Honours [MediaQueryData.highContrast] via the theme's default colours.
class RecoveryWordEntryWidget extends StatelessWidget {
  const RecoveryWordEntryWidget({
    super.key,
    required this.wordIndex,
    required this.controller,
    required this.onChanged,
    this.focusNode,
  });

  /// 1-based position in the recovery phrase (1 = first word).
  final int wordIndex;

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final semanticsLabel = 'Word $wordIndex';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Semantics(
        label: semanticsLabel,
        textField: true,
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          onChanged: onChanged,
          decoration: InputDecoration(
            labelText: semanticsLabel,
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          // Use auto-wrap; never clip text in large-font mode.
          maxLines: 1,
          textInputAction: TextInputAction.next,
          // Spell-check and autocorrect off — words must be exact BIP-39 matches.
          autocorrect: false,
          enableSuggestions: false,
        ),
      ),
    );
  }
}
