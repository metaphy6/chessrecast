// DiagLog — 256 KB in-memory ring-buffer diagnostic log (§8.3 / leaf 8.3.b1).
//
// Contract:
//   • Total byte size of all stored entries is always ≤ 256 KB.
//   • When a new entry would push the total past the limit, the oldest
//     entries are evicted until enough space is freed.
//   • export() returns a single newline-joined string of all current entries.
//   • All methods are synchronous and run on the caller's isolate (UI-safe,
//     since there is no file I/O here — persistence is handled separately by
//     the export/send-diagnostics flow).
//
// PII policy: callers are responsible for redacting PII before appending.
// The DiagLog does NOT inspect or filter entry content.

/// A fixed-capacity (256 KB) rotating in-memory diagnostic log.
class DiagLog {
  static const int _maxBytes = 256 * 1024; // 256 KB

  final List<String> _entries = [];
  int _totalBytes = 0;

  /// All entries currently held in the buffer, oldest first.
  List<String> get entries => List.unmodifiable(_entries);

  /// Current total byte count of all entries.
  int get totalBytes => _totalBytes;

  /// Appends [entry] to the log, evicting oldest entries if needed to stay
  /// within the 256 KB budget.
  void append(String entry) {
    final entryBytes = entry.codeUnits.length;

    // Evict oldest entries until the new entry fits.
    while (_entries.isNotEmpty && _totalBytes + entryBytes > _maxBytes) {
      final evicted = _entries.removeAt(0);
      _totalBytes -= evicted.codeUnits.length;
    }

    // If the single entry is itself larger than the buffer, we store it
    // truncated to exactly the budget (truncate at the byte level).
    if (entryBytes > _maxBytes) {
      final truncated = String.fromCharCodes(
        entry.codeUnits.take(_maxBytes).toList(),
      );
      _entries.add(truncated);
      _totalBytes += truncated.codeUnits.length;
      return;
    }

    _entries.add(entry);
    _totalBytes += entryBytes;
  }

  /// Returns a newline-separated string of all current log entries.
  /// Safe to call on any isolate; no I/O is performed.
  String export() => _entries.join('\n');

  /// Removes all entries from the buffer.
  void clear() {
    _entries.clear();
    _totalBytes = 0;
  }
}
