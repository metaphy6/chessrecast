"""
WebSocket server for live training game streaming.
Broadcasts game state to connected Flutter clients in real-time.
"""
import asyncio
import websockets
import json
import threading
from typing import Set, Dict, Any
from datetime import datetime


class TrainingWebSocketServer:
    """WebSocket server for streaming live training games"""
    
    def __init__(self, host='0.0.0.0', port=8765):
        self.host = host
        self.port = port
        self.clients: Set[websockets.WebSocketServerProtocol] = set()
        self.current_game: Dict[str, Any] = {}
        self.loop = None
        self.server = None
        self.running = False
        # Validation error tracking
        self.validation_error_occurred = False
        self.last_validation_error: Dict[str, Any] = {}
        self._validation_error_count = 0
        self._validation_error_suppressed = 0
    
    def has_validation_error(self) -> bool:
        """Check if a validation error was reported by a client"""
        return self.validation_error_occurred
    
    def clear_validation_error(self):
        """Clear the validation error flag (e.g., when starting a new game)"""
        if self._validation_error_suppressed > 0:
            print(f"   ⚠️  ({self._validation_error_suppressed} validation errors were suppressed)")
        self.validation_error_occurred = False
        self.last_validation_error = {}
        self._validation_error_count = 0
        self._validation_error_suppressed = 0
        
    async def register(self, websocket):
        """Register new client connection"""
        self.clients.add(websocket)
        print(f"📡 Client connected. Total clients: {len(self.clients)}")
        
        # Send current game state to new client if a game is in progress
        if self.current_game and self.current_game.get('status') == 'in_progress':
            try:
                await websocket.send(json.dumps({
                    'type': 'game_state',
                    'data': self.current_game
                }))
                print(f"📤 Sent current game state to new client ({len(self.current_game.get('moves', []))} moves)")
            except Exception as e:
                print(f"Error sending game state to new client: {e}")
    
    async def unregister(self, websocket):
        """Unregister client connection"""
        self.clients.discard(websocket)
        print(f"📡 Client disconnected. Total clients: {len(self.clients)}")
    
    async def handle_client(self, websocket, path=None):
        """Handle client connection"""
        await self.register(websocket)
        try:
            async for message in websocket:
                # Handle incoming messages if needed
                try:
                    data = json.loads(message)
                    if data.get('type') == 'ping':
                        await websocket.send(json.dumps({'type': 'pong'}))
                    elif data.get('type') == 'get_state':
                        # Send current game state if available
                        if self.current_game and self.current_game.get('status') == 'in_progress':
                            await websocket.send(json.dumps({
                                'type': 'game_state',
                                'data': self.current_game
                            }))
                    elif data.get('type') == 'validation_error':
                        # Client reported an invalid move
                        self._handle_validation_error(data.get('data', {}))
                except Exception as e:
                    print(f"Error handling client message: {e}")
        except websockets.exceptions.ConnectionClosed:
            pass
        finally:
            await self.unregister(websocket)
    
    def _handle_validation_error(self, error_data: Dict[str, Any]):
        """Handle validation error from Flutter client"""
        self._validation_error_count += 1
        
        move_num = error_data.get('move_number', '?')
        move_uci = error_data.get('move_uci', '?')
        error_msg = error_data.get('error_message', 'Unknown error')
        expected_fen = error_data.get('expected_fen', '')
        received_fen = error_data.get('received_fen', '')
        
        # Only print first 3 validation errors per game, then summarize
        if self._validation_error_count <= 3:
            print(f"\n{'='*60}")
            print(f"🚨 VALIDATION ERROR FROM FLUTTER CLIENT ({self._validation_error_count})")
            print(f"{'='*60}")
            print(f"   Move #{move_num}: {move_uci}")
            print(f"   Error: {error_msg}")
            print(f"   Expected FEN: {expected_fen}")
            print(f"   Received FEN: {received_fen}")
            print(f"{'='*60}\n")
        elif self._validation_error_count == 4:
            print(f"⚠️  Further validation errors suppressed (likely stale client board). Reconnect Flutter app to fix.")
        else:
            self._validation_error_suppressed += 1
        
        # Log to file
        try:
            with open('/workspace/validation_errors.log', 'a') as f:
                f.write(f"{datetime.now().isoformat()} | Move #{move_num} {move_uci} | {error_msg}\n")
                f.write(f"  Expected: {expected_fen}\n")
                f.write(f"  Received: {received_fen}\n\n")
        except Exception as e:
            print(f"⚠️ Failed to log validation error: {e}")
        
        # Signal to stop the game
        self.validation_error_occurred = True
        self.last_validation_error = error_data
    
    async def broadcast(self, message: Dict[str, Any]):
        """Broadcast message to all connected clients"""
        if self.clients:
            message_json = json.dumps(message)
            disconnected = set()
            
            for client in self.clients:
                try:
                    await client.send(message_json)
                except websockets.exceptions.ConnectionClosed:
                    disconnected.add(client)
            
            # Remove disconnected clients
            self.clients -= disconnected
    
    def start_game(self, iteration: int, game_num: int, mode: str = 'mercenary'):
        """Signal start of new game"""
        self.current_game = {
            'iteration': iteration,
            'game_number': game_num,
            'mode': mode,
            'timestamp': datetime.now().isoformat(),
            'moves': [],
            'result': None,
            'status': 'in_progress'
        }
        
        # Broadcast game start
        if self.loop and self.running:
            asyncio.run_coroutine_threadsafe(
                self.broadcast({
                    'type': 'game_start',
                    'data': {
                        'iteration': iteration,
                        'game_number': game_num,
                        'mode': mode,
                        'timestamp': self.current_game['timestamp']
                    }
                }),
                self.loop
            )
    
    def send_move(self, move_num: int, move_uci: str, turn: str, 
                  fen: str, value: float, top_moves: list):
        """Send move update to all clients"""
        move_data = {
            'number': move_num,
            'move': move_uci,
            'turn': turn,
            'fen': fen,
            'value': value,
            'top_moves': top_moves
        }
        
        self.current_game['moves'].append(move_data)
        
        # Broadcast move
        if self.loop and self.running:
            asyncio.run_coroutine_threadsafe(
                self.broadcast({
                    'type': 'move',
                    'data': move_data
                }),
                self.loop
            )
    
    def end_game(self, result: str):
        """Signal end of game"""
        self.current_game['result'] = result
        self.current_game['status'] = 'completed'
        
        # Broadcast game end
        if self.loop and self.running:
            asyncio.run_coroutine_threadsafe(
                self.broadcast({
                    'type': 'game_end',
                    'data': {
                        'result': result,
                        'total_moves': len(self.current_game['moves'])
                    }
                }),
                self.loop
            )
    
    async def _run_server(self):
        """Run the WebSocket server"""
        self.server = await websockets.serve(
            self.handle_client,
            self.host,
            self.port
        )
        self.running = True
        print(f"🌐 WebSocket server started on ws://{self.host}:{self.port}")
        await asyncio.Future()  # Run forever
    
    def start_server_thread(self):
        """Start WebSocket server in background thread"""
        def run_server():
            self.loop = asyncio.new_event_loop()
            asyncio.set_event_loop(self.loop)
            self.loop.run_until_complete(self._run_server())
        
        thread = threading.Thread(target=run_server, daemon=True)
        thread.start()
        return thread
    
    def stop(self):
        """Stop the WebSocket server"""
        self.running = False
        if self.server:
            self.server.close()


# Global instance
_ws_server = None


def get_websocket_server() -> TrainingWebSocketServer:
    """Get or create global WebSocket server instance"""
    global _ws_server
    if _ws_server is None:
        _ws_server = TrainingWebSocketServer()
        _ws_server.start_server_thread()
    return _ws_server
