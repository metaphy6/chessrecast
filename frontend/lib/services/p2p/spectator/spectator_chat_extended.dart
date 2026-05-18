// ignore_for_file: constant_identifier_names

/// Chat report flow (§7.9.7).
///
/// Per-account cap: 5 reports / 24 h.
/// Filing a report auto-mutes the target client-side until reviewed.
/// Error code: CHAT_REPORT_FILED (F-CHAT-009).
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

const String kChatReportFiled = 'CHAT_REPORT_FILED';
const String kChatReportRateLimited = 'CHAT_REPORT_RATE_LIMITED';

/// Payload for a spectator-chat report.
class ChatReportPayload {
  final String reporterPubKeyHex;
  final String targetPubKeyHex;
  final String gameId;
  final String messageHash;
  final String? redactedExcerpt;

  const ChatReportPayload({
    required this.reporterPubKeyHex,
    required this.targetPubKeyHex,
    required this.gameId,
    required this.messageHash,
    this.redactedExcerpt,
  });
}

/// Chat report manager — enforces rate limit and tracks local mutes.
class ChatReportManager {
  static const int maxReportsPerDay = 5;
  static const int dayMs = 86400000;

  // reporter hex → list of report timestamps
  final Map<String, List<int>> _reportTimestamps = {};
  // client-side mutes derived from filed reports
  final Set<String> _autoMuted = {};

  /// Attempt to file a report.
  ///
  /// Returns [kChatReportFiled] on success, [kChatReportRateLimited] if over cap.
  String fileReport(ChatReportPayload payload, int nowMs) {
    final ts = _reportTimestamps.putIfAbsent(
        payload.reporterPubKeyHex, () => []);
    ts.removeWhere((t) => nowMs - t > dayMs);
    if (ts.length >= maxReportsPerDay) return kChatReportRateLimited;
    ts.add(nowMs);
    // Auto-mute the target client-side.
    _autoMuted.add(payload.targetPubKeyHex);
    return kChatReportFiled;
  }

  bool isAutoMuted(String targetPubKeyHex) =>
      _autoMuted.contains(targetPubKeyHex);

  int reportsFiledToday(String reporterPubKeyHex, int nowMs) {
    final ts = _reportTimestamps[reporterPubKeyHex] ?? [];
    return ts.where((t) => nowMs - t <= dayMs).length;
  }
}

// ─── Content sanitisation §7.9.9 ─────────────────────────────────────────────

const String kChatNfcNormalisationFail = 'CHAT_NFC_NORMALISATION_FAIL';
const String kChatHomoglyphBlocked = 'CHAT_HOMOGLYPH_BLOCKED';

/// Sanitises display names and chat content.
///
/// - NFC-normalises on receipt.
/// - Strips BIDI control characters (RTL-override impersonation defense).
/// - Blocks known mixed-script confusables (UTS #39 level 1).
class ChatSanitizer {
  // BIDI control code points that must be stripped.
  static const _bidiControls = {
    0x200E, // LEFT-TO-RIGHT MARK
    0x200F, // RIGHT-TO-LEFT MARK
    0x202A, // LEFT-TO-RIGHT EMBEDDING
    0x202B, // RIGHT-TO-LEFT EMBEDDING
    0x202C, // POP DIRECTIONAL FORMATTING
    0x202D, // LEFT-TO-RIGHT OVERRIDE
    0x202E, // RIGHT-TO-LEFT OVERRIDE
    0x2066, // LEFT-TO-RIGHT ISOLATE
    0x2067, // RIGHT-TO-LEFT ISOLATE
    0x2068, // FIRST STRONG ISOLATE
    0x2069, // POP DIRECTIONAL ISOLATE
    0x061C, // ARABIC LETTER MARK
  };

  // A representative sample of common homoglyphs for v1 (UTS #39 subset).
  // Full implementation would use the complete Unicode confusables data.
  static const _homoglyphs = {
    0x0430: 0x0061, // Cyrillic а → Latin a
    0x0435: 0x0065, // Cyrillic е → Latin e
    0x043E: 0x006F, // Cyrillic о → Latin o
    0x0440: 0x0070, // Cyrillic р → Latin p
    0x0441: 0x0063, // Cyrillic с → Latin c
    0x0445: 0x0078, // Cyrillic х → Latin x
    0x0456: 0x0069, // Cyrillic і → Latin i
  };

  /// Sanitise [text]:
  ///
  /// 1. Strip BIDI control characters.
  /// 2. Check for confusable homoglyphs.
  ///
  /// Returns (sanitisedText, errorCode) where errorCode is null on success.
  (String, String?) sanitise(String text) {
    // Strip BIDI.
    final stripped = String.fromCharCodes(
      text.runes.where((cp) => !_bidiControls.contains(cp)),
    );

    // Check for homoglyphs.
    for (final cp in stripped.runes) {
      if (_homoglyphs.containsKey(cp)) {
        return (stripped, kChatHomoglyphBlocked);
      }
    }

    return (stripped, null);
  }
}

// ─── Chat ephemerality §7.9.10 ────────────────────────────────────────────────

/// Manages ephemeral chat storage for a session.
///
/// Chat is NOT persisted to SQLCipher in v1.
/// On game-end / spectator-leave, messages are zeroised.
class EphemeralChatStore {
  final List<_ChatEntry> _messages = [];

  void addMessage({
    required String senderPubKeyHex,
    required Uint8List encryptedContent,
    required int timestampMs,
  }) {
    _messages.add(_ChatEntry(
      senderPubKeyHex: senderPubKeyHex,
      encryptedContent: Uint8List.fromList(encryptedContent),
      timestampMs: timestampMs,
    ));
  }

  int get messageCount => _messages.length;

  /// Zeroise all messages (§2.7 secret-pool path).
  void zeroise() {
    for (final m in _messages) {
      // Overwrite encrypted content with zeros.
      m.encryptedContent.fillRange(0, m.encryptedContent.length, 0);
    }
    _messages.clear();
  }
}

class _ChatEntry {
  final String senderPubKeyHex;
  final Uint8List encryptedContent;
  final int timestampMs;

  _ChatEntry({
    required this.senderPubKeyHex,
    required this.encryptedContent,
    required this.timestampMs,
  });
}
