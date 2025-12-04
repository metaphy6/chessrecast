# Database Move Streaming Analysis & Implementation Plan

## Current Architecture (Before)

### How Moves Are Currently Saved
1. **Move Execution** (`game/service.go:ProcessMove`)
   - Move is validated and executed on the board
   - Game state is updated (check for checkmate, draw, etc.)
   - Update is broadcast to WebSocket subscribers

2. **Move Recording** (`game/service.go:PlayBotVsBot` - line 627)
   - **ONLY called for bot vs bot games**
   - `storage.RecordMove(sessionID, move)` is called after successful move
   - Move is added to in-memory GameBuilder accumulator

3. **Game Completion** (`game/service.go:PlayBotVsBot` - line 652)
   - When game ends, `storage.EndGame()` is called
   - Complete game record (all moves) is sent to database via buffered channel
   - Database worker processes it asynchronously

### Issues with Current Approach
- ❌ **Only bot vs bot games are logged** - human player games aren't recorded at all
- ❌ **Buffered channel (100 capacity)** - not true real-time streaming
- ❌ **End-of-game batch write** - all moves saved together when game ends
- ❌ **No individual move timestamps** - can't replay game move-by-move with timing
- ❌ **In-memory accumulation** - if server crashes mid-game, moves are lost
- ❌ **No backpressure handling** - dropping records when buffer is full
- ❌ **Synchronous to async conversion** - moves recorded after game logic completes

## New Architecture (After - gRPC-style Streaming)

### Design Principles
1. **Real-time unidirectional streaming** - moves flow directly to DB as they happen
2. **Per-move persistence** - each move individually recorded immediately
3. **Backpressure handling** - proper queue management without dropping data
4. **Move timestamps** - capture exact move timing for game replay
5. **All games logged** - human vs AI, human vs human, bot vs bot
6. **Worker pool pattern** - multiple database workers for concurrent writes

### Implementation: Move Recording Stream

```
┌─────────────────────────────────────────────────────────────┐
│                      Game Service                            │
│  ┌──────────────────────────────────────────────────────┐   │
│  │ processMove():                                        │   │
│  │  1. Validate move                                    │   │
│  │  2. Execute on board                                │   │
│  │  3. Send to MoveRecorder.Channel (non-blocking)    │   │
│  │  4. Broadcast WebSocket update                      │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ MoveRecord
                              ▼
┌─────────────────────────────────────────────────────────────┐
│              MoveRecorder (Streaming Channel)                │
│  ┌──────────────────────────────────────────────────────┐   │
│  │ Buffered Channel: make(chan MoveRecord, 500)        │   │
│  │ • Larger buffer for bursty move patterns            │   │
│  │ • Non-blocking send (default case to continue game) │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ Stream of MoveRecords
                              ▼
┌─────────────────────────────────────────────────────────────┐
│           Worker Pool (3-5 goroutines)                      │
│  ┌──────────────────────────────────────────────────────┐   │
│  │ worker():                                             │   │
│  │  1. Receive MoveRecord from channel                  │   │
│  │  2. Insert into DB with timestamp                   │   │
│  │  3. Log success/failure                             │   │
│  │  (Repeat for each worker)                           │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
                    ┌──────────────────┐
                    │  PostgreSQL DB   │
                    │  move_records    │
                    │  (real-time)     │
                    └──────────────────┘
```

### Key Components

#### 1. **MoveRecord struct**
```go
type MoveRecord struct {
    GameID      string
    MoveNumber  int       // 1, 2, 3, ... (sequence)
    Move        *engine.Move
    Color       engine.Color
    Timestamp   time.Time // When move was made
}
```

#### 2. **MoveRecorder type**
```go
type MoveRecorder struct {
    moveChannel chan MoveRecord
    workers     int
    db          *pgxpool.Pool
    ctx         context.Context
    cancel      context.CancelFunc
}
```

#### 3. **New database table**
```sql
CREATE TABLE move_records (
    id BIGSERIAL PRIMARY KEY,
    game_id VARCHAR(36) NOT NULL,
    move_number INT NOT NULL,
    from_row INT NOT NULL,
    from_col INT NOT NULL,
    to_row INT NOT NULL,
    to_col INT NOT NULL,
    piece_type VARCHAR(10) NOT NULL,
    piece_color VARCHAR(10) NOT NULL,
    captured_piece VARCHAR(10),
    is_promotion BOOLEAN DEFAULT FALSE,
    promotion_type VARCHAR(10),
    is_castling BOOLEAN DEFAULT FALSE,
    move_timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    recorded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    FOREIGN KEY (game_id) REFERENCES game_records(game_id),
    UNIQUE(game_id, move_number)
);

CREATE INDEX idx_move_records_game_id ON move_records(game_id);
CREATE INDEX idx_move_records_timestamp ON move_records(move_timestamp);
```

### Performance Characteristics

| Metric | Current | New |
|--------|---------|-----|
| **Move-to-DB latency** | ~50-500ms (batch) | ~1-5ms (streaming) |
| **Write latency** | All at once (high spike) | Distributed over time |
| **Backpressure handling** | None (drops records) | Proper queue mgmt |
| **Data loss risk** | High (batch at end) | Low (per-move writes) |
| **Replay capability** | Limited (no timestamps) | Full (move timestamps) |
| **Concurrent writes** | 1 worker | N workers |
| **Memory overhead** | Accumulates all moves | Fixed channel size |

## Implementation Strategy

1. **Phase 1**: Create MoveRecorder with worker pool
2. **Phase 2**: Create move_records table schema
3. **Phase 3**: Update session to use MoveRecorder
4. **Phase 4**: Integrate with processMove() for real-time streaming
5. **Phase 5**: Update database queries for move analysis
6. **Phase 6**: Add game replay from move_records

## Benefits

✅ **Real-time**: Moves saved immediately as they happen
✅ **Scalable**: Worker pool handles concurrent games
✅ **Durable**: Per-move writes prevent data loss
✅ **Queryable**: Individual moves can be retrieved/analyzed
✅ **Replayable**: Complete game history with timestamps
✅ **All games**: Human and bot games both tracked
✅ **High performance**: Streaming pattern like gRPC
✅ **Backpressure**: Proper queue handling without dropping

---

## Next Steps
1. Implement MoveRecorder type and worker pool
2. Add streaming channel to Session
3. Update processMove() to send to recorder
4. Create move_records table migration
5. Add worker goroutines on session creation
6. Add graceful shutdown for pending records
