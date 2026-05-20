// §13.2.b1 — no_engine_pledge capability helpers.
//
// A player can include `no_engine_pledge: true` in their HELLO.capabilities
// map to signal a soft pledge not to use external engine assistance.  This is
// a social / gentleman's agreement — it is not cryptographically enforceable.
//
// The module intentionally has zero dependencies on Flutter/UI or on the P2P
// transport layer so that it can be unit-tested without a running engine.
library;

/// Capabilities key used in the HELLO wire message.
const String kNoEnginePledgeKey = 'no_engine_pledge';

/// Convenience re-export so that callers can refer to the casual-mode key
/// from a single import when handling HELLO.capabilities.
const String kCasualModeKey = 'casual_mode';

/// Returns `true` when [capabilities] contains [kNoEnginePledgeKey]: `true`.
///
/// Missing or explicitly-`false` entries both return `false`.
bool extractNoEnginePledge(Map<String, bool> capabilities) =>
    capabilities[kNoEnginePledgeKey] ?? false;

/// Builds the single-entry capabilities fragment for the HELLO message.
///
/// ```dart
/// final hello = HelloMessage(
///   ...
///   capabilities: {
///     ...buildNoEnginePledgeCapability(pledges: true),
///   },
/// );
/// ```
Map<String, bool> buildNoEnginePledgeCapability({required bool pledges}) =>
    {kNoEnginePledgeKey: pledges};
