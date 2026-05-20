// §14.2 — Per-message local mute.
//
// A "mute" is distinct from a block (§14.1):
//   - Mute: hides incoming chat without ending the session; reversible mid-game;
//     the opponent is NOT notified.
//   - Block: ends the current session and prevents future matches.
//
// New-contact policy: a device fingerprint never seen before starts in
// `softMuted` mode — messages are delivered but not auto-shown until the
// user explicitly taps "show chat".
library;

/// Mute state for an opponent in the current session.
enum MuteState {
  /// Messages arrive and are shown normally.
  unmuted,

  /// Messages arrive but are not automatically shown (new-contact default).
  /// User can tap to reveal the chat pane.
  softMuted,

  /// User explicitly muted; messages are hidden, not shown on tap.
  hardMuted,
}

/// Service that manages per-session and per-fingerprint mute preferences.
///
/// The mute state is reset at the end of each session (not persisted across
/// games); only the `isNewContact` flag is checked from persistent storage by
/// the caller.
final class ChatMuteService {
  final Map<String, MuteState> _states = {};

  /// Return the current [MuteState] for [opponentFingerprint].
  ///
  /// Defaults to [MuteState.unmuted] if no state has been set.
  MuteState stateFor(String opponentFingerprint) =>
      _states[opponentFingerprint] ?? MuteState.unmuted;

  /// Apply the new-contact soft-mute heuristic for [opponentFingerprint].
  ///
  /// Should be called at session start when the fingerprint has never been
  /// seen before.  If the state is already set (e.g. user pre-muted) this is
  /// a no-op.
  void applyNewContactDefault(String opponentFingerprint) {
    _states.putIfAbsent(opponentFingerprint, () => MuteState.softMuted);
  }

  /// Explicitly set [state] for [opponentFingerprint].
  void setMute(String opponentFingerprint, MuteState state) {
    _states[opponentFingerprint] = state;
  }

  /// Toggle hard-mute for [opponentFingerprint].
  ///
  /// If currently [MuteState.hardMuted], transitions to [MuteState.unmuted].
  /// Otherwise transitions to [MuteState.hardMuted].
  void toggleHardMute(String opponentFingerprint) {
    final current = stateFor(opponentFingerprint);
    _states[opponentFingerprint] = current == MuteState.hardMuted
        ? MuteState.unmuted
        : MuteState.hardMuted;
  }

  /// Reveal the chat pane for a [MuteState.softMuted] opponent.
  ///
  /// Transitions `softMuted → unmuted`; other states are unchanged.
  void revealSoftMuted(String opponentFingerprint) {
    if (stateFor(opponentFingerprint) == MuteState.softMuted) {
      _states[opponentFingerprint] = MuteState.unmuted;
    }
  }

  /// Returns `true` when incoming chat messages should be shown to the user.
  bool shouldShowMessage(String opponentFingerprint) {
    return stateFor(opponentFingerprint) == MuteState.unmuted;
  }

  /// Clear all mute state (call at session end).
  void reset() => _states.clear();
}
