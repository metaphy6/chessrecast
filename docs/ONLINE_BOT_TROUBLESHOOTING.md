# Online Bot Integration - Troubleshooting & Testing Guide

## Issue Fixed

**Problem**: When making moves against the online bot, no response was received from the backend.

**Root Cause**: The `OnlineController` was not being instantiated correctly, so moves were being processed locally instead of being sent to the backend.

## Changes Made

### 1. Fixed Controller Instantiation (`lib/ui/game_page.dart`)
- Game page now checks if `isOnline` flag is set in route arguments
- Instantiates `OnlineController` for online games
- Falls back to regular `Controller` for offline games

### 2. Override `makeMove` Method (`lib/management/online_controller.dart`)
- Added override of `makeMove()` to intercept all moves
- Routes moves to backend when in online mode (`_isOnlineMode` = true)
- Falls back to local processing if offline or no game ID
- Added extensive debug logging to track move flow

### 3. Enhanced Debug Logging
- Added logs to show when controller switches between online/offline mode
- Tracks game ID and player ID
- Shows move submissions to backend
- Displays backend responses

## How to Test

### 1. Start the Backend

```bash
cd backend
docker-compose up -d
```

Verify it's running:
```bash
curl http://localhost:8080/health
```

Expected: `{"status":"ok","timestamp":"..."}`

### 2. Run Flutter App

```bash
flutter run
```

### 3. Test Online Bot Game

1. In the app, tap **"🌐 Play Online vs Bot"**
2. Select:
   - **Difficulty**: 5 (Intermediate)
   - **Game Mode**: Classic
3. Tap **"Start Game"**
4. Watch the logs for:
   ```
   ✅ OnlineController: Logged in as Guest_...
   🎮 OnlineController: Creating game - mode: classic, bot: 5
   ✅ OnlineController: Game created: <game-id>
   🔌 WebSocket: Connecting to ws://localhost:8080/api/v1/ws/game/<game-id>
   ✅ WebSocket: Connected successfully
   ```

5. Make a move (e.g., e2 → e4):
   ```
   🎯 OnlineController: makeMove called
   🎯 OnlineController: isOnlineMode = true
   🎯 OnlineController: gameId = <game-id>
   🌐 OnlineController: Routing to backend
   📤 OnlineController: Sending move: e2 -> e4
   ✅ OnlineController: Move accepted by backend
   📥 OnlineController: Response: {...}
   ```

6. Check for bot response:
   ```
   📨 WebSocket: Received message
   📨 WebSocket: Parsed data: move_made
   ♟️ OnlineController: Move made - <from> -> <to>
   ```

### 4. Check Backend Logs

In another terminal:
```bash
cd backend
docker-compose logs -f api
```

Look for:
```
POST /api/v1/auth/guest 200
POST /api/v1/games 200
WebSocket connection established
POST /api/v1/games/<id>/moves 200
Bot calculating move...
Broadcasting move update
```

## Debugging Steps

### If No Move is Sent to Backend

**Check 1**: Verify OnlineController is being used
```
Look for: "🎯 OnlineController: makeMove called"
NOT: "🎯 CONTROLLER: makeMove called" (this is base class)
```

**Check 2**: Verify online mode is active
```
Look for: "isOnlineMode = true"
If false, check route arguments when navigating
```

**Check 3**: Verify game ID exists
```
Look for: "gameId = <some-id>"
If empty, game creation failed
```

### If Backend Rejects Move

**Check 1**: Invalid move format
```
Backend expects algebraic notation: "e2", "e4"
Not array indices: [1, 4]
```

**Check 2**: Move validation failed
```
Backend validates moves server-side
Check backend logs for validation errors
```

**Check 3**: Wrong game mode
```
Each mode has different rules
Verify mode matches between Flutter and backend
```

### If No Bot Response

**Check 1**: WebSocket connected
```
Look for: "✅ WebSocket: Connected successfully"
```

**Check 2**: Bot difficulty set
```
Game was created with botDifficulty parameter
Backend should auto-calculate bot moves
```

**Check 3**: Backend processing
```
Check backend logs for "Bot calculating move"
May take 1-5 seconds depending on difficulty
```

## Expected Flow

```
User Taps Square
    ↓
Controller.onSquareSelected()
    ↓
Controller._attemptMove()
    ↓
Controller.makeMove()  ← This is where routing happens
    ↓
OnlineController.makeMove() override
    ↓
[Check isOnlineMode && gameId]
    ↓
OnlineController.makeMoveOnline()
    ↓
ApiService.makeMove()
    ↓ HTTP POST
Backend API
    ↓
Chess Engine validates
    ↓
Bot calculates response (if bot game)
    ↓
WebSocket broadcasts update
    ↓
GameWebSocket.onGameUpdate()
    ↓
OnlineController._handleGameUpdate()
    ↓
Board updates with new state
```

## Common Issues & Solutions

### Issue: "Backend server is not reachable"
**Solution**: 
- Check Docker: `docker ps` (should show 3 containers)
- Test health: `curl http://localhost:8080/health`
- Check port 8080 is not in use by another app

### Issue: "WebSocket: Connection error"
**Solution**:
- Verify game ID is valid
- Check WebSocket URL in `game_websocket.dart`
- Backend WebSocket endpoint: `/api/v1/ws/game/:id`

### Issue: "Move failed: Invalid move"
**Solution**:
- Verify move is legal for the selected game mode
- Check it's your turn (not bot's turn)
- Ensure algebraic notation is correct

### Issue: Moves work but no bot response
**Solution**:
- Check if game was created with `botDifficulty`
- Backend logs should show "Bot calculating move"
- WebSocket should broadcast bot's move
- May need to implement FEN parsing for full sync

## Next Steps

### Implement FEN Parsing
The backend returns board state in FEN (Forsyth-Edwards Notation). Currently, `_updateBoardFromBackend()` logs but doesn't parse it.

**Add FEN parser to ChessBoard**:
```dart
factory ChessBoard.fromFEN(String fen, ModesEnum gameType) {
  // Parse FEN string and create board
  // Format: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
}
```

### Add Move History
Backend tracks full move history. Display it in UI:
```dart
GET /api/v1/games/:id
Response: { ..., "moves": ["e2e4", "e7e5", ...] }
```

### Multiplayer Support
Human vs Human games:
- Remove bot difficulty when creating game
- Both players connect via WebSocket
- Each player's moves broadcast to opponent

## Testing Checklist

- [ ] Backend starts successfully
- [ ] Health endpoint returns OK
- [ ] Guest login works
- [ ] Game creation returns game ID
- [ ] WebSocket connects successfully
- [ ] First move sends to backend
- [ ] Backend accepts move (200 response)
- [ ] Bot calculates response
- [ ] WebSocket receives bot move
- [ ] Board updates with bot move
- [ ] Can play full game
- [ ] All 12 game modes work
- [ ] All 10 difficulty levels work

## Logs to Monitor

**Flutter (VS Code Debug Console)**:
```
🎮 Creating game
✅ Game created
🔌 WebSocket connected
📤 Sending move
✅ Move accepted
📨 Received update
```

**Backend (Docker logs)**:
```bash
docker-compose logs -f api | grep -E "(POST|WebSocket|Bot|move)"
```

---

**Status**: Integration should now work correctly. Moves will be sent to backend and bot responses will be received via WebSocket.
