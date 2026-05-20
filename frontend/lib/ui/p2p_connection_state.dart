// P2P connection-state badge widget with accessibility labels.
//
// Every state produces a `Semantics(label: ..., liveRegion: true)` node so
// that screen readers (TalkBack, VoiceOver) automatically announce state
// transitions — satisfying roadmap §8.2 leaf 8.2.b1.
//
// The `accessibilityLabel` on each enum value is the canonical English text.
// When AppLocalizations is wired up, callers should override the label via
// the optional [label] parameter using the localised string.

import 'package:flutter/material.dart';

/// The six user-visible P2P connection states.
enum P2pConnectionState {
  connecting,
  connected,
  disconnected,
  reconnecting,
  failed,
  waiting,
}

/// English accessibility label for each connection state.
/// Real apps should pass the localised string from AppLocalizations instead.
extension P2pConnectionStateLabel on P2pConnectionState {
  String get accessibilityLabel => const {
    P2pConnectionState.connecting: 'Connecting…',
    P2pConnectionState.connected: 'Connected',
    P2pConnectionState.disconnected: 'Disconnected',
    P2pConnectionState.reconnecting: 'Reconnecting…',
    P2pConnectionState.failed: 'Connection failed',
    P2pConnectionState.waiting: 'Waiting for opponent…',
  }[this]!;
}

/// A small status badge that renders the current P2P connection state as an
/// icon + text row, wrapped in `Semantics(liveRegion: true)` so that screen
/// readers announce every state change without user interaction.
///
/// Colour is never the sole visual indicator: an icon and a text label are
/// always present (§8.2.b3 — colour-blind safety).
class P2pConnectionStateBadge extends StatelessWidget {
  const P2pConnectionStateBadge({super.key, required this.state, this.label});

  final P2pConnectionState state;

  /// Override the accessibility label with a localised string.
  /// Defaults to [P2pConnectionStateLabel.accessibilityLabel].
  final String? label;

  @override
  Widget build(BuildContext context) {
    final effectiveLabel = label ?? state.accessibilityLabel;
    return Semantics(
      label: effectiveLabel,
      liveRegion: true,
      // ExcludeSemantics prevents child Text/Icon nodes from creating
      // duplicate semantics entries; the badge is described solely by
      // [effectiveLabel] above.
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_iconForState(state), size: 14, color: _colorForState(state)),
            const SizedBox(width: 4),
            Text(
              effectiveLabel,
              style: TextStyle(fontSize: 12, color: _colorForState(state)),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconForState(P2pConnectionState s) {
    switch (s) {
      case P2pConnectionState.connecting:
        return Icons.sync;
      case P2pConnectionState.connected:
        return Icons.check_circle_outline;
      case P2pConnectionState.disconnected:
        return Icons.cancel_outlined;
      case P2pConnectionState.reconnecting:
        return Icons.refresh;
      case P2pConnectionState.failed:
        return Icons.error_outline;
      case P2pConnectionState.waiting:
        return Icons.hourglass_empty;
    }
  }

  Color _colorForState(P2pConnectionState s) {
    switch (s) {
      case P2pConnectionState.connected:
        return const Color(0xFF2E7D32); // green
      case P2pConnectionState.failed:
      case P2pConnectionState.disconnected:
        return const Color(0xFFC62828); // red
      case P2pConnectionState.connecting:
      case P2pConnectionState.reconnecting:
      case P2pConnectionState.waiting:
        return const Color(0xFFE65100); // amber/orange
    }
  }
}
