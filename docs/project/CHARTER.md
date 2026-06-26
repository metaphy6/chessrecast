# 📜 Charter: chessrecast

## Vision

An offline-first, open-source chess app with novel rule variants and true peer-to-peer multiplayer — no account, no central game server required.

## Scope (in)

- A cross-platform Flutter app (Android, iOS, Linux, macOS, Windows, Web) embedding a native C chess engine via FFI.
- Seven chess rule variant **mods**: `heir`, `friendly_fire`, `kings_battle`, `mercenary`, `save_the_queen`, `succession`, `truce`.
- Peer-to-peer multiplayer via WebRTC data channels, brokered by a minimal Go signaling server.
- A bot-driven quality improvement loop (`bots/`) that autonomously audits and improves each mod's game quality.

## Scope (out)

- **No user accounts / cloud save** — all state is local or in a P2P session. Adding auth would require a separate service.
- **No chess AI opponent** — the native engine evaluates positions for move quality auditing only, not for playing against a human.
- **No tournament infrastructure** — matchmaking, ELO ranking, time controls, and spectating are all out of scope.
- **No Web backend beyond signaling** — the Go server brokers connections only; it never sees game moves.

## Audience

- **Primary**: casual chess players who want to try fresh rule variants with friends on any device.
- **Secondary**: chess modders and engine contributors who extend or audit the C evaluation code.
- **Operators**: the repository maintainer who runs the signaling server and the bot improvement loop.

## Success criteria

1. All seven mods pass the engine audit gate (KPI regression < 5%, zero blunders > 200 cp in the fixed opening slice).
2. Two players on different networks can complete a full P2P game with < 200 ms move RTT (LAN) / < 500 ms (WAN via STUN).
3. The Flutter app builds reproducibly on all six platforms with `make verify`.
4. `make doctor` exits 0 on a clean clone.

## Non-goals & explicit trade-offs

- Performance is secondary to correctness and auditability for the C engine. The engine runs on device; speed matters only enough to not block the UI thread.
- The signaling server is deliberately minimal (no persistence, no auth). Scaling it is a future concern.

## Constraints

- The C chess engine must compile with `clang` and `gcc` without external libraries (embedded targets).
- P2P multiplayer must work without any server-side game logic (regulatory + privacy requirement).
- The Flutter app must remain offline-capable for single-player mode even with no network.
