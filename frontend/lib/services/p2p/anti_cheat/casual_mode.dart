// §13.2.b3 — casual_mode capability helpers.
//
// When both peers exchange `casual_mode: true` in their HELLO.capabilities,
// the session operates under "friend-game" rules: takebacks are permitted and
// the post-game move-time histogram is not shared.  One-sided casual mode is
// not sufficient — both players must opt in.
//
// The module has zero Flutter/transport dependencies for unit-testability.
library;

/// Capabilities key used in the HELLO wire message.
const String kCasualModeKey = 'casual_mode';

/// Returns `true` when [capabilities] contains [kCasualModeKey]: `true`.
bool extractCasualMode(Map<String, bool> capabilities) =>
    capabilities[kCasualModeKey] ?? false;

/// Builds the single-entry capabilities fragment for the HELLO message.
Map<String, bool> buildCasualModeCapability({required bool isCasual}) => {
  kCasualModeKey: isCasual,
};

/// Returns `true` when **both** peers opted into casual mode.
///
/// Takebacks may only be offered / accepted in a session where both sides
/// agreed to casual rules; one-sided casual mode does not grant takebacks.
bool isTakebackAllowed({
  required bool localCasualMode,
  required bool remoteCasualMode,
}) => localCasualMode && remoteCasualMode;

/// Returns `true` when histogram sharing should be enabled for this session.
///
/// Histogram sharing is disabled if **either** peer is in casual mode,
/// because casual play explicitly de-emphasises move-time scrutiny.
bool isHistogramSharingEnabled({
  required bool localCasualMode,
  required bool remoteCasualMode,
}) => !localCasualMode && !remoteCasualMode;
