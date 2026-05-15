# Chess Recast P2P Wire Protocol — v0 Specification

**Status:** Phase 1 (implemented)  
**Run-id:** `p2p-20260515-113417-917436`  
**Source of truth:** `frontend/lib/services/p2p/protocol/frame.dart`

---

## §1 Frame Envelope

Every message on the DataChannel is a **CBOR-encoded map** (RFC 8949) with the
following mandatory keys:

| Key | CBOR type | Meaning |
|-----|-----------|---------|
| `v` | uint (1) | Protocol version. Must be `1`. |
| `t` | uint | Frame type identifier (see §2). |
| `n` | uint | Monotonic sequence number (per-direction, starting at 0). |
| `ts` | uint | Wall-clock timestamp (milliseconds since Unix epoch). |
| `p` | bytes | Payload bytes (CBOR-encoded map; contents depend on frame type). |

Serialisation rules:

- **Deterministic CBOR** (RFC 8949 §4.2) is mandatory for all frames.
- Map keys are sorted in byte-lexicographic order on their CBOR encodings.
- Integers use the shortest-form encoding.
- Definite-length collections only.
- **Floats are rejected** — any CBOR float triggers a `CborFloatRejectedError`.

---

## §2 Frame Type Registry

All 24 frame type identifiers:

| Hex | Decimal | Name | Direction |
|-----|---------|------|-----------|
| `0x01` | 1 | `HELLO` | initiator → responder |
| `0x02` | 2 | `HELLO_ACK` | responder → initiator |
| `0x10` | 16 | `MOVE` | either |
| `0x11` | 17 | `MOVE_ACK` | either |
| `0x20` | 32 | `RESIGN` | either |
| `0x21` | 33 | `RESIGN_ACK` | either |
| `0x30` | 48 | `DRAW_OFFER` | either |
| `0x31` | 49 | `DRAW_ACCEPT` | either |
| `0x32` | 50 | `DRAW_DECLINE` | either |
| `0x40` | 64 | `TAKEBACK_REQUEST` | either |
| `0x41` | 65 | `TAKEBACK_ACCEPT` | either |
| `0x42` | 66 | `TAKEBACK_DECLINE` | either |
| `0x50` | 80 | `CHAT` | either |
| `0x60` | 96 | `BYE` | either |
| `0x61` | 97 | `BYE_ACK` | either |
| `0x62` | 98 | `BYE_PART` | either (fragmented transcript part) |
| `0x63` | 99 | `BYE_FINAL` | either (last fragment + hash) |
| `0x70` | 112 | `PING` | either |
| `0x71` | 113 | `PONG` | either |
| `0x80` | 128 | `ERROR` | either |
| `0x90` | 144 | `REKEY` | either |
| `0x91` | 145 | `REKEY_ACK` | either |
| `0xA0` | 160 | `REPETITION_CLAIM` | either |
| `0xC0` | 192 | `KCI_MAC` | either |

---

## §3 HELLO / HELLO_ACK

### HELLO payload (`0x01`)

```
{
  'pub':   bytes,        // 32-byte ephemeral Ed25519 public key
  'nonce': bytes,        // 32-byte random nonce
  'mod':   uint,         // ModId (see §9)
  'sig':   bytes,        // 64-byte HMAC-SHA256 stub (Phase 1); real Ed25519 in Phase 2
}
```

### HELLO_ACK payload (`0x02`)

```
{
  'pub':   bytes,        // 32-byte ephemeral public key
  'nonce': bytes,        // 32-byte random nonce
  'sid':   bytes,        // 32-byte session ID (see §11)
  'sig':   bytes,        // 64-byte signature
}
```

Both parties must verify `sig` before transitioning from `handshake` state.

---

## §4 MOVE

### MOVE payload (`0x10`)

```
{
  'm': string,           // UCI move string in canonical form (see §9)
}
```

Average wire size: ≈ 34 bytes (KPI gate: ≤ 48 bytes).

### MOVE_ACK payload (`0x11`)

```
{
  'hash': bytes,         // 32-byte SHA-256 state hash (see §10) after the move
}
```

The state hash is carried in MOVE_ACK, not in MOVE, so the sender commits to
the resulting position after applying the move.

---

## §5 RESIGN

### RESIGN payload (`0x20`)

```
{
  'sig': bytes,          // 64-byte signature over (session_id || 'resign' || fen)
}
```

### RESIGN_ACK payload (`0x21`)

```
{}
```

---

## §6 CHAT

### CHAT payload (`0x50`)

```
{
  'msg': string,         // UTF-8 chat message (max 256 bytes after normalisation)
}
```

Rate limit: maximum 5 messages per 10-second window per direction.

---

## §7 BYE

### BYE payload (`0x60`) — small transcripts (< 12 KB)

```
{
  'result': string,      // '1-0' | '0-1' | '1/2-1/2'
  'moves':  list,        // list of UCI move strings
  'fens':   list,        // list of FEN strings (one per ply)
  'sig':    bytes,       // 64-byte transcript signature
}
```

### BYE_ACK payload (`0x61`)

```
{}
```

---

## §8 BYE Fragmentation

When the serialised BYE payload exceeds **12 288 bytes** (12 KB), the sender
fragments the payload:

- Fragment threshold: `kByeFragmentThresholdBytes = 12 * 1024` (12 288 bytes).
- Maximum fragment count: `kByeMaxFragments = 64`.

Each fragment is a `BYE_PART` frame (`0x62`) with payload:

```
{
  'idx':  uint,          // 0-based fragment index
  'tot':  uint,          // total number of data fragments
  'data': bytes,         // raw bytes slice of the original BYE payload
}
```

The final `BYE_FINAL` frame (`0x63`) carries only:

```
{
  'hash': bytes,         // SHA-256 of the complete reassembled payload
}
```

The receiver reassembles fragments by `idx` order and verifies the hash before
processing the BYE payload.

---

## §9 Move Canonicalisation

All UCI move strings are normalised before signing or hashing:

- King moves that also castle are tagged with `K` prefix: `Ke1g1` (not `e1g1`).
- Promotion pieces are lowercase: `e7e8q` (not `e7e8Q`).
- Squares use standard algebraic notation: file (`a`–`h`) + rank (`1`–`8`).

Valid move syntax: `[K]<from><to>[promo]` where `<from>` and `<to>` are two-char
squares. King tag and promo suffix are optional.

---

## §10 State Hash

The state hash is a **32-byte SHA-256** digest over:

```
UTF-8(fen) || uint8(modId) || modStateBytes
```

Where:
- `fen` is the full FEN string of the position after the move.
- `modId` is a single byte (0–7, see §14).
- `modStateBytes` is any additional mod-specific state (empty for classic).

Computed by `StateHasher.compute(fen, modId, modStateBytes)`.

---

## §11 Session ID

The session ID is a **32-byte SHA-256** derived from the HELLO exchange:

```
SHA-256(sorted_concat(pubA, pubB) || nonceA || nonceB)
```

Where the two public keys are sorted byte-lexicographically before
concatenation. This ensures both peers derive the same session ID regardless
of who initiated.

Derived by `SessionIdDeriver.derive({ephPubA, ephPubB, nonceA, nonceB})`.

---

## §12 HKDF Info Label Registry

Seven labels are defined for HKDF-SHA256 key derivation. All labels follow the
pattern `chessrecast/p2p/v{N}/{name}`:

| Label | Purpose | Output bytes |
|-------|---------|-------------|
| `chessrecast/p2p/v1/master` | Master session key derivation | 32 |
| `chessrecast/p2p/v1/aead-salt` | AEAD salt for HKDF-Expand | 12 |
| `chessrecast/p2p/v1/kci` | KCI-resistance MAC key | 32 |
| `chessrecast/p2p/v1/transcript-sign` | Transcript signing key | 64 |
| `chessrecast/p2p/v1/transcript-backup` | Encrypted forensic backup key | 32 |
| `chessrecast/p2p/v1/rekey` | Re-key derivation | 32 |
| `chessrecast/p2p/v1/forensic-at-rest` | Forensic bundle at-rest encryption | 32 |

Accessible via `kHkdfInfoRegistry` (type `Map<String, _HkdfLabel>`). Values
are the private `_HkdfLabel` class with fields `.purpose` (String) and
`.outputLength` (int).

---

## §13 Color Flip

Starting color is determined after HELLO_ACK by `ColorFlip.assignColors`:

- Input: `sidA` bytes (first peer), `sidB` bytes (second peer).
- If `sidA < sidB` (byte-lexicographic), A plays White; otherwise B plays White.
- This is deterministic and consistent for both peers from the same session ID.

---

## §14 Draw Offer Lifecycle

Draw offers follow a three-message lifecycle:

1. `DRAW_OFFER` (`0x30`) — sender proposes a draw.
2. `DRAW_ACCEPT` (`0x31`) — receiver agrees → game ends as draw.
3. `DRAW_DECLINE` (`0x32`) — receiver declines → game continues.

Rules:
- An offer expires after the opponent's next move (if no response).
- A player may not re-offer immediately after decline (one-ply gap required).
- `DrawOfferLifecycle` tracks pending offer state and enforces these rules.

---

## §15 Repetition Claims

When a player claims a draw by repetition:

1. Send `REPETITION_CLAIM` (`0xA0`) with payload `{'hash': bytes, 'count': uint}`.
2. The receiver calls `RepetitionDetector.verifyRepetitionClaim(hash, count)`.
3. If `count >= 3`, the claim is valid and the game ends as draw.

The `RepetitionDetector` tracks positions via their 32-byte state hashes
(see §10). Methods: `push(Uint8List hash)`, `countOccurrences(Uint8List hash)`,
`verifyRepetitionClaim(Uint8List hash, int occurrences)`, `reset()`.

---

## §16 Error Codes

`ERROR` frame (`0x80`) payload:

```
{
  'code': uint,          // error code (see table)
  'msg':  string,        // human-readable description
}
```

| Code | Name | Meaning |
|------|------|---------|
| 1 | `ILLEGAL_MOVE` | Received move failed legality check |
| 2 | `OUT_OF_SEQUENCE` | Frame sequence number gap detected |
| 3 | `PROTOCOL_ERROR` | Malformed frame or schema violation |
| 4 | `SESSION_ID_MISMATCH` | Session IDs do not agree |
| 5 | `REKEY_REQUIRED` | Key rotation must complete before proceeding |
| 6 | `FRAGMENT_NOT_ALLOWED` | BYE payload too small for fragmentation |
| 7 | `FRAGMENT_LIMIT_EXCEEDED` | Payload exceeds 64-fragment maximum |

---

## Appendix A — ModId Encoding

| Byte | Dart enum value |
|------|----------------|
| 0 | `classic` |
| 1 | `heir` |
| 2 | `friendlyFire` |
| 3 | `kingsBattle` |
| 4 | `mercenary` |
| 5 | `saveTheQueen` |
| 6 | `succession` |
| 7 | `truce` |

---

## Appendix B — KPI Targets (Phase 1)

| Metric | Gate |
|--------|------|
| Frame encode P99 latency | ≤ 150 µs (10k iterations) |
| Frame decode P99 latency | ≤ 150 µs (10k iterations) |
| Average MOVE frame size | ≤ 48 bytes |
| Frame round-trip P99 | ≤ 2 000 µs |

Baseline file: `agent/baselines/p2p_protocol.json`.
