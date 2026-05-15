import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

import 'frame.dart';

// ─── Session State Machine ────────────────────────────────────────────────────

/// Legal session states per §state-machine of P2P_PROTOCOL.md.
enum SessionState { idle, handshake, playing, finished, aborted }

/// Thrown when an illegal session transition is attempted.
class ProtocolStateError implements Exception {
  final SessionState current;
  final String event;
  const ProtocolStateError(this.current, this.event);

  @override
  String toString() =>
      'ProtocolStateError: cannot handle "$event" in state $current';
}

/// Legal transitions map:
///   idle → handshake (on HELLO send/receive)
///   handshake → playing (on HELLO_CONFIRM)
///   handshake → aborted (on timeout / mismatch)
///   playing → finished (on BYE / game end)
///   playing → aborted (on MISMATCH / crash)
///   finished → idle (reset)
///   aborted → idle (reset)
const Map<SessionState, Set<String>> _legalTransitions = {
  SessionState.idle: {'start_handshake'},
  SessionState.handshake: {'confirm', 'abort'},
  SessionState.playing: {'game_end', 'mismatch', 'abort'},
  SessionState.finished: {'reset'},
  SessionState.aborted: {'reset'},
};

/// All possible events across all states (for exhaustive analysis).
const Set<String> kAllSessionEvents = {
  'start_handshake',
  'confirm',
  'abort',
  'game_end',
  'mismatch',
  'reset',
};

/// P2P session managing state machine + per-direction sequence numbers.
class Session {
  SessionState _state = SessionState.idle;

  // Per-direction last-seen sequence numbers (direction: 0=local, 1=remote).
  final Map<int, int> _lastSeenSeq = {0: 0, 1: 0};

  // Forensic bundle: last 64 frames per direction.
  final List<Frame> _localFrames = [];
  final List<Frame> _remoteFrames = [];
  static const int _maxForensicFrames = 64;

  // Locally-assigned session metadata (set at handshake).
  String? modId;
  Uint8List? sessionId;

  SessionState get state => _state;

  /// Process an event, transitioning state or throwing [ProtocolStateError].
  void transition(String event) {
    final allowed = _legalTransitions[_state];
    if (allowed == null || !allowed.contains(event)) {
      throw ProtocolStateError(_state, event);
    }
    switch (event) {
      case 'start_handshake':
        _state = SessionState.handshake;
      case 'confirm':
        _state = SessionState.playing;
      case 'abort':
        _state = SessionState.aborted;
      case 'game_end':
        _state = SessionState.finished;
      case 'mismatch':
        _state = SessionState.aborted;
      case 'reset':
        _state = SessionState.idle;
        _lastSeenSeq[0] = 0;
        _lastSeenSeq[1] = 0;
        _localFrames.clear();
        _remoteFrames.clear();
    }
  }

  /// Validate a sequence number for [direction] (0=local outgoing, 1=remote incoming).
  ///
  /// Returns true if valid (strictly greater than last seen).
  /// Throws [OutOfSequenceError] if sequence is not strictly increasing.
  bool validateAndRecordSequence(int direction, int seq) {
    final last = _lastSeenSeq[direction] ?? 0;
    if (seq <= last) {
      throw OutOfSequenceError(seq, last);
    }
    _lastSeenSeq[direction] = seq;
    return true;
  }

  /// Record a local (outgoing) frame for forensic bundle.
  void recordLocalFrame(Frame frame) {
    _localFrames.add(frame);
    if (_localFrames.length > _maxForensicFrames) {
      _localFrames.removeAt(0);
    }
  }

  /// Record a remote (incoming) frame for forensic bundle.
  void recordRemoteFrame(Frame frame) {
    _remoteFrames.add(frame);
    if (_remoteFrames.length > _maxForensicFrames) {
      _remoteFrames.removeAt(0);
    }
  }

  /// Get a snapshot of recent frames for a MISMATCH forensic bundle.
  ForensicBundle buildForensicBundle({
    required List<String> localMoveList,
    required List<String> remoteMoveList,
    required String modIdStr,
    required String nativeLibSha,
  }) {
    return ForensicBundle(
      sessionId: sessionId ?? Uint8List(0),
      localFrames: List.unmodifiable(_localFrames),
      remoteFrames: List.unmodifiable(_remoteFrames),
      localMoveList: localMoveList,
      remoteMoveList: remoteMoveList,
      modId: modIdStr,
      nativeLibSha: nativeLibSha,
    );
  }
}

// ─── Forensic Bundle ─────────────────────────────────────────────────────────

/// Snapshot written on MISMATCH per §1.2 of P2P_PROTOCOL.md.
class ForensicBundle {
  final Uint8List sessionId;
  final List<Frame> localFrames;
  final List<Frame> remoteFrames;
  final List<String> localMoveList;
  final List<String> remoteMoveList;
  final String modId;
  final String nativeLibSha;

  const ForensicBundle({
    required this.sessionId,
    required this.localFrames,
    required this.remoteFrames,
    required this.localMoveList,
    required this.remoteMoveList,
    required this.modId,
    required this.nativeLibSha,
  });

  /// Serialise to JSON for on-disk storage.
  Map<String, dynamic> toJson() {
    return {
      'session_id': _bytesToHex(sessionId),
      'mod_id': modId,
      'native_lib_sha': nativeLibSha,
      'local_move_list': localMoveList,
      'remote_move_list': remoteMoveList,
      'local_frames_count': localFrames.length,
      'remote_frames_count': remoteFrames.length,
      'local_frames': localFrames
          .map((f) => {'type': f.type.name, 'seq': f.sequenceNum})
          .toList(),
      'remote_frames': remoteFrames
          .map((f) => {'type': f.type.name, 'seq': f.sequenceNum})
          .toList(),
    };
  }

  static String _bytesToHex(Uint8List bytes) {
    final buf = StringBuffer();
    for (final b in bytes) {
      buf.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return buf.toString();
  }

  /// Write forensic bundle to disk at:
  ///   <appDocDir>/p2p/forensics/<session-id-hex>/bundle.json
  ///
  /// For testing, [overrideDir] can be provided to write to a temp directory.
  Future<File> writeToDisk({Directory? overrideDir}) async {
    final base = overrideDir ?? await getApplicationDocumentsDirectory();
    final sessionHex = _bytesToHex(sessionId).isNotEmpty
        ? _bytesToHex(sessionId)
        : 'unknown';
    final dir = Directory(
        '${base.path}/p2p/forensics/$sessionHex');
    await dir.create(recursive: true);
    final file = File('${dir.path}/bundle.json');
    await file.writeAsString(jsonEncode(toJson()));
    return file;
  }
}

// ─── Forensic Store ──────────────────────────────────────────────────────────

/// SHA-256 of the native library binary for inclusion in forensic bundles.
///
/// In tests this returns a constant placeholder.
Future<String> computeNativeLibSha({String? overridePath}) async {
  try {
    final path = overridePath;
    if (path != null) {
      final file = File(path);
      if (!file.existsSync()) return 'unknown';
      final bytes = await file.readAsBytes();
      final digest = sha256.convert(bytes);
      return digest.toString();
    }
    return 'unknown'; // not computed in tests without override
  } catch (_) {
    return 'unknown';
  }
}
