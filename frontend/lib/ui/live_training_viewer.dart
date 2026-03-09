import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../board/utils/exporter.dart';
import '../mods/mods_enum.dart';
import 'piece_renderer.dart';

class LiveTrainingViewer extends StatefulWidget {
  const LiveTrainingViewer({super.key});

  @override
  State<LiveTrainingViewer> createState() => _LiveTrainingViewerState();
}

class _LiveTrainingViewerState extends State<LiveTrainingViewer> {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  final ScrollController _movesScrollController = ScrollController();
  bool isConnected = false;
  String connectionStatus = 'Disconnected';
  Timer? _reconnectTimer;
  int _reconnectAttempt = 0;
  static const int _maxReconnectAttempt = 20;
  bool _userDisconnected = false; // true when user pressed Disconnect

  // Current game state
  int? currentIteration;
  int? currentGameNumber;
  int? totalGamesPerIteration;
  String? currentMode;
  List<GameMove> moves = [];
  String? gameResult;

  // Board state (tracked independently from FEN for validation)
  ChessBoard displayBoard = ChessBoard.initial();
  ChessBoard validationBoard = ChessBoard.initial(); // For move validation

  // Error tracking
  List<MoveValidationError> validationErrors = [];
  bool validationEnabled = true;

  // Connection settings
  final TextEditingController _hostController = TextEditingController(
    text: '10.0.2.2',
  );
  final TextEditingController _portController = TextEditingController(
    text: '8765',
  );

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _subscription?.cancel();
    _subscription = null;
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    _hostController.dispose();
    _portController.dispose();
    _movesScrollController.dispose();
    super.dispose();
  }

  void _connect() {
    final host = _hostController.text;
    final port = _portController.text;
    _userDisconnected = false;

    // Clean up any previous connection
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _subscription?.cancel();
    _subscription = null;
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;

    if (mounted) {
      setState(() {
        connectionStatus = 'Connecting to $host:$port...';
      });
    }

    try {
      _channel = WebSocketChannel.connect(Uri.parse('ws://$host:$port'));

      // Wait for the WebSocket handshake to actually complete before
      // declaring the connection open.  Without this, `isConnected` is
      // set to true while the TCP/WS handshake is still in progress —
      // causing writes to a half-open sink that freeze the UI.
      _channel!.ready
          .then((_) {
            if (!mounted) return;
            _reconnectAttempt = 0;

            _subscription = _channel!.stream.listen(
              (message) {
                if (mounted) {
                  _handleMessage(message);
                }
              },
              onError: (error) {
                print('❌ WebSocket error: $error');
                _handleConnectionLost('Error: $error');
              },
              onDone: () {
                print('📡 WebSocket closed');
                _handleConnectionLost('Server closed connection');
              },
              cancelOnError: false,
            );

            if (mounted) {
              setState(() {
                connectionStatus = 'Connected to $host:$port';
                isConnected = true;
              });
            }
            print('✅ Connected to ws://$host:$port');
          })
          .catchError((error) {
            print('❌ WebSocket handshake failed: $error');
            _handleConnectionLost('Handshake failed');
          });
    } catch (e) {
      print('❌ Connection failed: $e');
      _handleConnectionLost('Failed: $e');
    }
  }

  /// Called when the connection drops unexpectedly (error, onDone, handshake
  /// failure).  Cleans up stale references and schedules an automatic
  /// reconnect with exponential backoff (1s → 2s → 4s … → 30s).
  void _handleConnectionLost(String reason) {
    _subscription?.cancel();
    _subscription = null;
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;

    if (mounted) {
      setState(() {
        isConnected = false;
        connectionStatus = reason;
      });
    }

    // Auto-reconnect unless the user deliberately disconnected
    if (!_userDisconnected && mounted) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_reconnectAttempt >= _maxReconnectAttempt) {
      if (mounted) {
        setState(() {
          connectionStatus =
              'Gave up reconnecting after $_maxReconnectAttempt attempts';
        });
      }
      return;
    }

    final delaySec = (_reconnectAttempt < 5)
        ? 1 +
              _reconnectAttempt // 1, 2, 3, 4, 5
        : (5 * (1 << (_reconnectAttempt - 5))).clamp(
            5,
            30,
          ); // 5, 10, 20, 30, 30…
    _reconnectAttempt++;

    if (mounted) {
      setState(() {
        connectionStatus =
            'Reconnecting in ${delaySec}s (attempt $_reconnectAttempt)...';
      });
    }

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: delaySec), () {
      if (mounted && !_userDisconnected) {
        _connect();
      }
    });
  }

  void _disconnect() {
    print('🔌 Disconnecting...');
    _userDisconnected = true;

    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _subscription?.cancel();
    _subscription = null;

    try {
      _channel?.sink.close();
    } catch (e) {
      print('Error closing WebSocket: $e');
    }
    _channel = null;

    if (mounted) {
      setState(() {
        connectionStatus = 'Disconnected';
        isConnected = false;
        currentIteration = null;
        currentGameNumber = null;
        currentMode = null;
        moves = [];
        gameResult = null;
        displayBoard = ChessBoard.initial();
      });
    }
  }

  void _handleMessage(dynamic message) {
    if (!mounted) return;

    try {
      final parsed = jsonDecode(message);
      final type = parsed['type'];
      final data = parsed['data'] ?? parsed;

      print('📨 Received: $type');

      switch (type) {
        case 'game_start':
          _handleGameStart(data);
          break;
        case 'move':
          _handleMove(data);
          break;
        case 'game_end':
          _handleGameEnd(data);
          break;
        case 'game_state':
          _handleGameState(data);
          break;
        default:
          print('Unknown message type: $type');
      }
    } catch (e, stackTrace) {
      print('❌ Error handling message: $e');
      print('Stack trace: $stackTrace');
    }
  }

  void _handleGameStart(Map<String, dynamic> data) {
    print(
      '🎮 Game Start: Iteration ${data['iteration']}, Game ${data['game_number']}',
    );
    if (!mounted) return;

    final mode = data['mode'];
    final gameType = mode == 'mercenary'
        ? ModsEnum.mercenary
        : ModsEnum.classic;

    setState(() {
      currentIteration = data['iteration'];
      currentGameNumber = data['game_number'];
      totalGamesPerIteration = data['total_games'];
      currentMode = mode;
      moves = [];
      gameResult = null;
      displayBoard = ChessBoard.initial(gameType: gameType);
      validationBoard = ChessBoard.initial(
        gameType: gameType,
      ); // Reset with correct mode
      validationErrors = []; // Clear errors for new game
    });
  }

  void _handleMove(Map<String, dynamic> data) {
    if (!mounted) return;

    try {
      final move = GameMove.fromJson(data);

      print('📥 Received move #${move.number}: ${move.move}');
      print(
        '   Current mode: $currentMode, Validation enabled: $validationEnabled',
      );

      // Validate move if enabled and we have a mode
      if (validationEnabled && currentMode == 'mercenary') {
        print('🔍 Validating move #${move.number}: ${move.move}');
        print('   Current validation board FEN: ${validationBoard.toFEN()}');
        final validationResult = _validateMercenaryMove(move);
        if (!validationResult.isValid) {
          // Log validation error
          final error = MoveValidationError(
            moveNumber: move.number,
            moveUci: move.move,
            expectedFen: validationBoard.toFEN(),
            receivedFen: move.fen ?? '',
            errorMessage: validationResult.errorMessage,
            timestamp: DateTime.now(),
          );
          validationErrors.add(error);
          print('❌ VALIDATION ERROR: ${validationResult.errorMessage}');
          print('   Move: ${move.move} (#${move.number})');
          print('   Expected FEN: ${validationBoard.toFEN()}');
          print('   Received FEN: ${move.fen}');

          // Send error signal to server
          _sendValidationError(error);

          // IMPORTANT: Still update validation board from FEN to stay in sync
          // Otherwise validation board gets stuck and all future moves will fail
          if (move.fen != null && move.fen!.isNotEmpty) {
            try {
              validationBoard = ChessBoard.fromFEN(
                move.fen!,
                gameType: ModsEnum.mercenary,
              );
              print(
                '   ⚠️ Updated validation board from FEN to continue validation',
              );
            } catch (e) {
              print('   ⚠️ Failed to update validation board from FEN: $e');
            }
          }
        } else {
          print('✅ Move #${move.number} validated successfully');
          // Move was valid - update validation board from server's FEN (authoritative)
          if (move.fen != null && move.fen!.isNotEmpty) {
            try {
              final oldFen = validationBoard.toFEN();
              validationBoard = ChessBoard.fromFEN(
                move.fen!,
                gameType: ModsEnum.mercenary,
              );
              final newFen = validationBoard.toFEN();
              print('   Updated validation board from FEN');
              print('   Old: $oldFen');
              print('   New: $newFen');
            } catch (e, stack) {
              print('   ⚠️ Failed to update validation board from FEN: $e');
              print('   Stack: $stack');
              // Fallback: Apply move manually
              _applyMoveToValidationBoard(move.move);
            }
          } else {
            print('   ⚠️ No FEN in move data, applying manually');
            // No FEN available - apply move manually
            _applyMoveToValidationBoard(move.move);
          }
        }
      }

      // Use FEN directly if available (more reliable for custom game mods like Mercenary)
      if (move.fen != null && move.fen!.isNotEmpty) {
        try {
          final gameType = currentMode == 'mercenary'
              ? ModsEnum.mercenary
              : ModsEnum.classic;
          displayBoard = ChessBoard.fromFEN(move.fen!, gameType: gameType);
        } catch (e) {
          print('⚠️ Error parsing FEN, falling back to move: $e');
          // Fallback to applying move
          if (move.move.isNotEmpty && move.move.length >= 4) {
            _applyMoveToBoard(move.move);
          }
        }
      } else {
        // Fallback: Apply move to board
        if (move.move.isNotEmpty && move.move.length >= 4) {
          _applyMoveToBoard(move.move);
        }
      }

      setState(() {
        moves.add(move);
      });

      // Auto-scroll to show latest move
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_movesScrollController.hasClients) {
          _movesScrollController.animateTo(
            _movesScrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      print('❌ Error handling move: $e');
    }
  }

  /// Validate a Mercenary Mod move
  MoveValidationResult _validateMercenaryMove(GameMove move) {
    if (move.move.isEmpty || move.move.length < 4) {
      return MoveValidationResult(
        isValid: false,
        errorMessage: 'Invalid move format: ${move.move}',
      );
    }

    try {
      final from = Position.fromAlgebraic(move.move.substring(0, 2));
      final to = Position.fromAlgebraic(move.move.substring(2, 4));
      final piece = validationBoard.getPieceAt(from);

      if (piece == null) {
        return MoveValidationResult(
          isValid: false,
          errorMessage: 'No piece at ${move.move.substring(0, 2)} to move',
        );
      }

      // Check if it's the correct turn
      final isWhiteTurn = validationBoard.currentPlayer == PieceColor.white;
      if ((piece.color == PieceColor.white) != isWhiteTurn) {
        return MoveValidationResult(
          isValid: false,
          errorMessage:
              'Wrong color moving: ${piece.color} on ${isWhiteTurn ? "white" : "black"}\'s turn',
        );
      }

      // Get legal moves for this piece (includes king-safety filtering).
      // getValidMovesFor already delegates to Mercenary pawn rules via
      // _getPawnMoves → mods.mercenary.getPawnMoves, then filters out
      // moves that leave the king in check — so it works for ALL pieces.
      final legalMoves = validationBoard.getValidMovesFor(from);

      // Check if the move is in legal moves
      final isLegal = legalMoves.any((m) => m.from == from && m.to == to);

      if (!isLegal) {
        // Check if king is currently in check
        final kingInCheck = validationBoard.isKingInCheck(piece.color);

        // Try to understand why the move is illegal
        if (kingInCheck) {
          return MoveValidationResult(
            isValid: false,
            errorMessage:
                'Move ${move.move} - king is in check and this move doesn\'t resolve it',
          );
        }

        // Check if it would leave king in check
        final wouldBeCheck = _wouldLeaveKingInCheck(piece, from, to);
        if (wouldBeCheck) {
          return MoveValidationResult(
            isValid: false,
            errorMessage: 'Move ${move.move} would leave king in check',
          );
        }

        return MoveValidationResult(
          isValid: false,
          errorMessage:
              'Illegal move ${move.move} for ${piece.type.name} at ${from.algebraic}',
        );
      }

      return MoveValidationResult(isValid: true);
    } catch (e) {
      return MoveValidationResult(
        isValid: false,
        errorMessage: 'Validation error: $e',
      );
    }
  }

  /// Check if a move would leave the king in check
  bool _wouldLeaveKingInCheck(ChessPiece piece, Position from, Position to) {
    try {
      final chessMove = ChessMove.simple(from: from, to: to, piece: piece);
      final newBoard = validationBoard.makeMove(chessMove);
      return newBoard.isKingInCheck(piece.color);
    } catch (e) {
      return false;
    }
  }

  /// Send validation error to server
  void _sendValidationError(MoveValidationError error) {
    if (_channel == null || !isConnected) return;
    try {
      _channel!.sink.add(
        jsonEncode({
          'type': 'validation_error',
          'data': {
            'move_number': error.moveNumber,
            'move_uci': error.moveUci,
            'expected_fen': error.expectedFen,
            'received_fen': error.receivedFen,
            'error_message': error.errorMessage,
            'timestamp': error.timestamp.toIso8601String(),
          },
        }),
      );
      print('📤 Sent validation error to server');
    } catch (e) {
      print('⚠️ Failed to send validation error: $e');
    }
  }

  void _handleGameEnd(Map<String, dynamic> data) {
    print('🏁 Game End: ${data['result']}');
    if (!mounted) return;

    setState(() {
      gameResult = data['result'];
    });
  }

  void _handleGameState(Map<String, dynamic> data) {
    print(
      '📊 Game State: Iteration ${data['iteration']}, Game ${data['game_number']}, ${data['moves']?.length ?? 0} moves',
    );
    if (!mounted) return;

    final mode = data['mode'];
    final gameType = mode == 'mercenary'
        ? ModsEnum.mercenary
        : ModsEnum.classic;

    // Parse moves
    final parsedMoves =
        (data['moves'] as List?)?.map((m) => GameMove.fromJson(m)).toList() ??
        [];

    // Use the FEN from the last move if available (most reliable for Mercenary Mod)
    if (parsedMoves.isNotEmpty && parsedMoves.last.fen != null) {
      try {
        displayBoard = ChessBoard.fromFEN(
          parsedMoves.last.fen!,
          gameType: gameType,
        );
        // CRITICAL: Also sync validation board so mid-game connections validate correctly
        validationBoard = ChessBoard.fromFEN(
          parsedMoves.last.fen!,
          gameType: gameType,
        );
        validationErrors = []; // Clear stale errors from previous game
        print(
          '✅ Loaded board + validation board from FEN: ${parsedMoves.last.fen}',
        );
      } catch (e) {
        print('⚠️ Error loading FEN, replaying moves: $e');
        // Fallback: Reset and replay all moves on BOTH boards
        displayBoard = ChessBoard.initial(gameType: gameType);
        validationBoard = ChessBoard.initial(gameType: gameType);
        validationErrors = [];
        for (var move in parsedMoves) {
          if (move.move.isNotEmpty && move.move.length >= 4) {
            _applyMoveToBoard(move.move);
            _applyMoveToValidationBoard(move.move);
          }
        }
      }
    } else {
      // No FEN available - reset and replay all moves on BOTH boards
      displayBoard = ChessBoard.initial(gameType: gameType);
      validationBoard = ChessBoard.initial(gameType: gameType);
      validationErrors = [];
      for (var move in parsedMoves) {
        if (move.move.isNotEmpty && move.move.length >= 4) {
          _applyMoveToBoard(move.move);
          _applyMoveToValidationBoard(move.move);
        }
      }
    }

    setState(() {
      currentIteration = data['iteration'];
      currentGameNumber = data['game_number'];
      totalGamesPerIteration = data['total_games'];
      currentMode = mode;
      gameResult = data['result'];
      moves = parsedMoves;
    });

    // Scroll to end
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_movesScrollController.hasClients) {
        _movesScrollController.jumpTo(
          _movesScrollController.position.maxScrollExtent,
        );
      }
    });

    print('✅ Loaded game state: ${moves.length} moves replayed');
  }

  void _applyMoveToBoard(String uciMove) {
    try {
      final from = Position.fromAlgebraic(uciMove.substring(0, 2));
      final to = Position.fromAlgebraic(uciMove.substring(2, 4));

      final piece = displayBoard.getPieceAt(from);
      if (piece != null) {
        ChessMove chessMove;

        // Handle promotion
        if (uciMove.length == 5) {
          chessMove = ChessMove.promotion(
            from: from,
            to: to,
            piece: piece,
            promotionPiece: uciMove[4].toUpperCase(),
          );
        } else {
          chessMove = ChessMove(from: from, to: to, piece: piece);
        }

        displayBoard = displayBoard.makeMove(chessMove);
      }
    } catch (e) {
      print('⚠️ Error applying move $uciMove: $e');
    }
  }

  void _applyMoveToValidationBoard(String uciMove) {
    try {
      final from = Position.fromAlgebraic(uciMove.substring(0, 2));
      final to = Position.fromAlgebraic(uciMove.substring(2, 4));

      final piece = validationBoard.getPieceAt(from);
      if (piece == null) {
        print(
          '⚠️ Warning: No piece at ${uciMove.substring(0, 2)} when applying move to validation board',
        );
        print('   Validation board FEN: ${validationBoard.toFEN()}');
        print('   Move: $uciMove');
        return;
      }

      // Get the target piece for capture
      final targetPiece = validationBoard.getPieceAt(to);

      ChessMove chessMove;

      // Handle promotion
      if (uciMove.length == 5) {
        chessMove = ChessMove.promotion(
          from: from,
          to: to,
          piece: piece,
          promotionPiece: uciMove[4].toUpperCase(),
          capturedPiece: targetPiece,
        );
      } else {
        chessMove = ChessMove(
          from: from,
          to: to,
          piece: piece,
          capturedPiece: targetPiece,
        );
      }

      validationBoard = validationBoard.makeMove(chessMove);
      print(
        '✅ Applied move $uciMove to validation board, new FEN: ${validationBoard.toFEN()}',
      );
    } catch (e, stackTrace) {
      print('⚠️ Error applying move to validation board $uciMove: $e');
      print('Stack trace: $stackTrace');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A2A3E),
        title: Row(
          children: [
            const Text('🔴 Live'),
            if (currentIteration != null) ...[
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Iter $currentIteration • Game $currentGameNumber',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ],
        ),
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: isConnected
                  ? Colors.green.withValues(alpha: 0.2)
                  : Colors.red.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isConnected ? Colors.green : Colors.red,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isConnected ? Colors.green : Colors.red,
                    shape: BoxShape.circle,
                    boxShadow: isConnected
                        ? [
                            BoxShadow(
                              color: Colors.green.withValues(alpha: 0.5),
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  isConnected ? 'LIVE' : 'OFF',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isConnected ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Connection bar (compact)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFF252538),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: TextField(
                      controller: _hostController,
                      decoration: const InputDecoration(
                        labelText: 'Host',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 0,
                        ),
                        labelStyle: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      enabled: !isConnected,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 70,
                  height: 36,
                  child: TextField(
                    controller: _portController,
                    decoration: const InputDecoration(
                      labelText: 'Port',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 0,
                      ),
                      labelStyle: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    enabled: !isConnected,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 36,
                  child: ElevatedButton(
                    onPressed: isConnected ? _disconnect : _connect,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isConnected
                          ? Colors.red.shade700
                          : Colors.green.shade700,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: Text(
                      isConnected ? 'Stop' : 'Connect',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Main content
          Expanded(
            child: currentIteration == null
                ? _buildWaitingState()
                : _buildGameViewer(),
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isConnected ? Icons.hourglass_empty : Icons.cloud_off,
            size: 64,
            color: Colors.white30,
          ),
          const SizedBox(height: 16),
          Text(
            isConnected ? 'Waiting for training data...' : 'Not connected',
            style: const TextStyle(color: Colors.white70, fontSize: 18),
          ),
          if (isConnected) ...[
            const SizedBox(height: 8),
            const Text(
              'Training games will appear here',
              style: TextStyle(color: Colors.white38, fontSize: 14),
            ),
            const SizedBox(height: 16),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGameViewer() {
    return Column(
      children: [
        // Big chess board (takes most space)
        Expanded(
          flex: 3,
          child: Container(
            padding: const EdgeInsets.all(8),
            child: Center(
              child: AspectRatio(
                aspectRatio: 1.0,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.purple, width: 3),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.purple.withValues(alpha: 0.3),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: _buildChessBoard(),
                  ),
                ),
              ),
            ),
          ),
        ),
        // Info bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: const Color(0xFF252538),
          child: Row(
            children: [
              // Live indicator
              if (gameResult == null)
                Container(
                  margin: const EdgeInsets.only(right: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withValues(alpha: 0.5),
                              blurRadius: 6,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'LIVE',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              // Move count
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.cyan.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${moves.length} moves',
                  style: const TextStyle(
                    color: Colors.cyan,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
              // Result or current player
              if (gameResult != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: gameResult == '1-0'
                        ? Colors.white.withValues(alpha: 0.2)
                        : gameResult == '0-1'
                        ? Colors.grey.withValues(alpha: 0.2)
                        : Colors.orange.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    gameResult == '1-0'
                        ? '⚪ White wins'
                        : gameResult == '0-1'
                        ? '⚫ Black wins'
                        : '🤝 Draw',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              else
                Text(
                  moves.isEmpty
                      ? '⚪ White to move'
                      : moves.last.turn == 'white'
                      ? '⚫ Black to move'
                      : '⚪ White to move',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
            ],
          ),
        ),
        // Horizontal scrolling move flow (chat-like)
        Container(
          height: 80,
          color: const Color(0xFF1A1A2E),
          child: moves.isEmpty
              ? const Center(
                  child: Text(
                    'Moves will appear here...',
                    style: TextStyle(color: Colors.white30, fontSize: 12),
                  ),
                )
              : ListView.builder(
                  controller: _movesScrollController,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  itemCount: moves.length,
                  itemBuilder: (context, index) {
                    final move = moves[index];
                    final isLatest = index == moves.length - 1;
                    return Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isLatest
                            ? Colors.purple.withValues(alpha: 0.4)
                            : move.turn == 'white'
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.grey.shade800.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: isLatest
                            ? Border.all(color: Colors.purple, width: 2)
                            : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: move.turn == 'white'
                                      ? Colors.white
                                      : Colors.grey.shade700,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white24),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '${move.number}',
                                  style: TextStyle(
                                    color: move.turn == 'white'
                                        ? Colors.black
                                        : Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                move.move,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: isLatest
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            move.value >= 0
                                ? '+${move.value.toStringAsFixed(2)}'
                                : move.value.toStringAsFixed(2),
                            style: TextStyle(
                              color: move.value > 0.1
                                  ? Colors.green.shade300
                                  : move.value < -0.1
                                  ? Colors.red.shade300
                                  : Colors.white54,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildChessBoard() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.maxWidth < constraints.maxHeight
            ? constraints.maxWidth
            : constraints.maxHeight;
        final squareSize = size / 8;

        return SizedBox(
          width: size,
          height: size,
          child: Column(
            children: List.generate(8, (row) {
              final rank = 7 - row;
              return Row(
                children: List.generate(8, (col) {
                  final file = col;
                  final isLight = (row + col) % 2 == 0;
                  final position = Position(rank, file);
                  final piece = displayBoard.getPieceAt(position);

                  return SizedBox(
                    width: squareSize,
                    height: squareSize,
                    child: Container(
                      color: isLight
                          ? const Color(0xFFEEEED2)
                          : const Color(0xFF769656),
                      child: piece != null
                          ? _buildPiece(piece, squareSize)
                          : null,
                    ),
                  );
                }),
              );
            }),
          ),
        );
      },
    );
  }

  Widget _buildPiece(ChessPiece piece, double size) {
    // Use the same beautiful SVG piece rendering as the rest of the app
    return Center(child: piece.toWidget(size: size * 0.85));
  }
}

class GameMove {
  final int number;
  final String move;
  final String turn;
  final double value;
  final String? fen; // FEN after this move was made
  final List<Map<String, dynamic>> topMoves;

  GameMove({
    required this.number,
    required this.move,
    required this.turn,
    required this.value,
    this.fen,
    required this.topMoves,
  });

  factory GameMove.fromJson(Map<String, dynamic> json) {
    try {
      final topMovesRaw = json['top_moves'] ?? json['top_3_moves'] ?? [];
      final topMoves = <Map<String, dynamic>>[];

      for (var item in topMovesRaw) {
        if (item is Map) {
          topMoves.add(Map<String, dynamic>.from(item));
        }
      }

      return GameMove(
        number: json['number'] ?? json['move_num'] ?? 0,
        move: json['move'] ?? json['move_uci'] ?? '',
        turn: json['turn'] ?? 'white',
        value: (json['value'] ?? json['position_value'] ?? 0.0).toDouble(),
        fen: json['fen'] as String?,
        topMoves: topMoves,
      );
    } catch (e) {
      print('Error parsing GameMove: $e');
      return GameMove(
        number: 0,
        move: '',
        turn: 'white',
        value: 0.0,
        fen: null,
        topMoves: [],
      );
    }
  }
}

/// Result of move validation
class MoveValidationResult {
  final bool isValid;
  final String errorMessage;

  MoveValidationResult({required this.isValid, this.errorMessage = ''});
}

/// Validation error for logging
class MoveValidationError {
  final int moveNumber;
  final String moveUci;
  final String expectedFen;
  final String receivedFen;
  final String errorMessage;
  final DateTime timestamp;

  MoveValidationError({
    required this.moveNumber,
    required this.moveUci,
    required this.expectedFen,
    required this.receivedFen,
    required this.errorMessage,
    required this.timestamp,
  });

  @override
  String toString() => 'Move #$moveNumber ($moveUci): $errorMessage';
}
