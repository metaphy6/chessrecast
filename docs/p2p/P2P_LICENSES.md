# P2P Dependency Licences

This document records the SPDX licence identifier and source for every direct
dependency of the chessrecast P2P stack. It satisfies roadmap §8.4 / leaf 8.4.b3.

All listed licences are compatible with the project licence (MIT).

## Flutter / Dart client

| Package | Version (approx) | SPDX | Source |
|---|---|---|---|
| flutter (SDK) | stable | BSD-3-Clause | https://github.com/flutter/flutter |
| package:web_socket_channel | ^3.x | BSD-3-Clause | https://pub.dev/packages/web_socket_channel |
| package:http | ^1.x | BSD-3-Clause | https://pub.dev/packages/http |
| package:sqflite | ^2.x | MIT | https://pub.dev/packages/sqflite |
| package:path_provider | ^2.x | BSD-3-Clause | https://pub.dev/packages/path_provider |
| package:crypto | ^3.x | BSD-3-Clause | https://pub.dev/packages/crypto |
| package:cryptography | ^2.x | Apache-2.0 | https://pub.dev/packages/cryptography |
| package:encrypt | ^5.x | BSD-3-Clause | https://pub.dev/packages/encrypt |
| package:ffi | ^2.x | BSD-3-Clause | https://pub.dev/packages/ffi |

## Go signaling server

| Module | SPDX | Source |
|---|---|---|
| Go stdlib | BSD-3-Clause | https://go.dev |
| golang.org/x/net | BSD-3-Clause | https://pkg.go.dev/golang.org/x/net |
| github.com/pion/webrtc | MIT | https://github.com/pion/webrtc |

## Native / system libraries

| Library | SPDX | Source |
|---|---|---|
| libsodium | ISC | https://libsodium.gitbook.io/doc/ |
| coturn | BSD-3-Clause | https://github.com/coturn/coturn |
| Valkey (optional TURN cache) | BSD-3-Clause | https://valkey.io |
| litestream (optional WAL streaming) | Apache-2.0 | https://litestream.io |

## Copyleft policy

No GPL, LGPL, AGPL, SSPL, BUSL, or CC-BY-SA licenced dependencies are
permitted. The `xops/p2p/check-licenses.sh` script enforces this at CI time.
If a new dependency is added, update this table and re-run the script.
