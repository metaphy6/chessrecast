# P2P NAT Matrix

This document records the NAT type combinations observed in testing and their
connection outcomes for Chess Recast's WebRTC peer-to-peer transport.

## NAT Type Definitions

| Type | Description |
|---|---|
| `fullCone` | All traffic from any external host is forwarded; easiest NAT for WebRTC. |
| `addressRestrictedCone` | Only hosts the device has previously sent to can send back. |
| `portRestrictedCone` | Stricter than address restricted: both IP and port must match. |
| `symmetric` | Each outbound flow gets a different external port; hardest for WebRTC. |

## Combination → Relay Decision

The `NatMatrix.requiresTurn()` function in
`frontend/lib/services/p2p/transport/nat_matrix.dart` governs which combinations
require a TURN relay.

| Peer A | Peer B | Requires TURN? | Notes |
|---|---|---|---|
| `fullCone` | `fullCone` | No | Direct P2P works. |
| `fullCone` | `addressRestrictedCone` | No | STUN enough. |
| `fullCone` | `portRestrictedCone` | No | STUN enough. |
| `fullCone` | `symmetric` | No | Asymmetric — full-cone host can accept. |
| `addressRestrictedCone` | `addressRestrictedCone` | No | STUN enough. |
| `addressRestrictedCone` | `portRestrictedCone` | No | STUN enough. |
| `addressRestrictedCone` | `symmetric` | No | Usually works with STUN. |
| `portRestrictedCone` | `portRestrictedCone` | No | Requires careful coordination; usually works. |
| `portRestrictedCone` | `symmetric` | **Often Yes** | Port-prediction unreliable; prefer TURN. |
| `symmetric` | `symmetric` | **Yes** | Both change ports per flow; TURN required. |

> **Implementation note:** `NatMatrix.requiresTurn(a, b)` currently only flags
> `symmetric × symmetric` as definitively requiring TURN.  The
> `portRestrictedCone × symmetric` case is handled by the ICE agent's
> connectivity-check timeout: it will naturally fall back to TURN after the
> direct-path check fails.

## IPv6 Considerations

IPv6 networks typically do not use NAT at all (public addresses are used end-
to-end), which removes the TURN requirement for most IPv6 peers.  The
`IceConfig.buildIpv6()` factory therefore omits the `requiresTurn` override but
still clamps PMTU to 1280 bytes to handle IPv6-over-IPv4 tunnels.

See `frontend/lib/services/p2p/transport/ice_config.dart` for the
`buildIpv6()` factory and the `pathMtuClamp` property.

## Thermal Matrix (§4.4)

Sustained high CPU temperatures reduce ICE connectivity-check throughput.
The following operating temperature ranges affect P2P reliability:

| Device State | Expected Impact |
|---|---|
| Normal (< 37 °C) | No impact; full ICE throughput. |
| Warm (37–42 °C) | Minor frame drops; clock cadence may auto-reduce. |
| Hot (> 42 °C) | OS may throttle network; session may degrade. |
| Thermal shutdown (> 47 °C) | Connection lost; session torn down gracefully. |

Thermal monitoring is handled at the OS level; the P2P layer observes
`PlatformChannel` battery/thermal events and pauses the clock heartbeat
when the device is in Warm or Hot state with battery-saver active.

## DPI / Deep Packet Inspection Notes (§4.10)

Some enterprise firewalls and mobile carrier DPI engines block:
- Plain TURN UDP (port 3478) — flagged as "media relay"
- DTLS fingerprint patterns — flagged as unrecognised TLS

Mitigation: TURNS (TURN over TLS port 5349) is indistinguishable from
HTTPS traffic and passes virtually all DPI filters.  The
`TurnsAutoPromote` class in
`frontend/lib/services/p2p/transport/turns_policy.dart` automatically
adds the `turns:` URL to the ICE server list when the connectivity probe
determines that plain TURN is blocked.
