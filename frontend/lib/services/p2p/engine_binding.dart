import 'dart:typed_data';

import 'protocol/frame.dart' show ModId, MoveCanon, StateHasher;

// ─── Engine Binding Interface ─────────────────────────────────────────────────

/// Abstract interface for validating P2P moves via the chess engine.
///
/// Implementations:
/// - [LiveEngineBinding] — uses the native C engine via FFI.
/// - [MockEngineBinding] — pure-Dart stub for unit tests.
abstract class EngineBindingInterface {
  /// Returns true if [uciMove] is legal from position [fen] for [modId].
  bool isMoveLegal(String fen, ModId modId, String uciMove);

  /// Returns the canonical FEN after applying [uciMove] from [fen].
  ///
  /// Throws [IllegalMoveError] if the move is not legal.
  String applyMove(String fen, ModId modId, String uciMove);

  /// Computes the canonical state hash for [fen] and [modId].
  Uint8List stateHash(String fen, ModId modId, Uint8List modStateBytes);
}

/// Thrown when a remote peer sends an illegal move.
class IllegalMoveError implements Exception {
  final String uciMove;
  final String fen;
  final ModId modId;
  const IllegalMoveError(this.uciMove, this.fen, this.modId);

  @override
  String toString() =>
      'IllegalMoveError: move=$uciMove is not legal in fen=$fen mod=$modId';
}

// ─── Live Engine Binding ──────────────────────────────────────────────────────

/// Production engine binding using the Dart-side board / move-generation.
///
/// Note: This is a Phase 2 stub. The live board integration is deferred to
/// Phase 2 of the P2P roadmap. All tests use [MockEngineBinding].
class LiveEngineBinding implements EngineBindingInterface {
  const LiveEngineBinding();

  @override
  bool isMoveLegal(String fen, ModId modId, String uciMove) {
    throw UnimplementedError(
      'LiveEngineBinding is a Phase 2 stub. Use MockEngineBinding in tests.',
    );
  }

  @override
  String applyMove(String fen, ModId modId, String uciMove) {
    throw UnimplementedError(
      'LiveEngineBinding is a Phase 2 stub. Use MockEngineBinding in tests.',
    );
  }

  @override
  Uint8List stateHash(String fen, ModId modId, Uint8List modStateBytes) {
    return StateHasher.compute(fen, modId, modStateBytes);
  }
}

// ─── Mock Engine Binding ──────────────────────────────────────────────────────

/// Test stub for [EngineBindingInterface].
///
/// Accepts or rejects moves based on a configurable allow-list or predicate.
class MockEngineBinding implements EngineBindingInterface {
  /// If non-null, only moves in this set are considered legal.
  final Set<String>? legalMoves;

  /// If non-null, called to determine move legality.
  final bool Function(String fen, ModId mod, String uci)? isLegalFn;

  /// If non-null, called to apply a move and return the new FEN.
  final String Function(String fen, ModId mod, String uci)? applyFn;

  const MockEngineBinding({this.legalMoves, this.isLegalFn, this.applyFn});

  @override
  bool isMoveLegal(String fen, ModId modId, String uciMove) {
    final canonical = MoveCanon.canonicalise(uciMove);
    if (isLegalFn != null) return isLegalFn!(fen, modId, canonical);
    if (legalMoves != null) return legalMoves!.contains(canonical);
    return true; // default: all moves are legal
  }

  @override
  String applyMove(String fen, ModId modId, String uciMove) {
    if (!isMoveLegal(fen, modId, uciMove)) {
      throw IllegalMoveError(uciMove, fen, modId);
    }
    if (applyFn != null) return applyFn!(fen, modId, uciMove);
    // Stub: return unchanged FEN (test should override if FEN matters)
    return fen;
  }

  @override
  Uint8List stateHash(String fen, ModId modId, Uint8List modStateBytes) {
    return StateHasher.compute(fen, modId, modStateBytes);
  }
}

// ─── P2P Engine Binding (top-level) ──────────────────────────────────────────

/// Validates a remote move and rejects it via [IllegalMoveError] if illegal.
///
/// This is the entry point called by the session's MOVE handler.
void validateRemoteMove({
  required EngineBindingInterface binding,
  required String fen,
  required ModId modId,
  required String uciMove,
  required Uint8List modStateBytes,
}) {
  final canonical = MoveCanon.canonicalise(uciMove);
  if (!binding.isMoveLegal(fen, modId, canonical)) {
    throw IllegalMoveError(canonical, fen, modId);
  }
}
