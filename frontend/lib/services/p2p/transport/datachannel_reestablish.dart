/// DataChannel re-establishment manager.
///
/// §4.7 — After a hard ICE restart, both DataChannels must be re-created
/// with the same ids and labels.  Any in-flight messages queued during
/// the teardown period are flushed once the channel re-opens.
library;

import 'datachannel_config.dart';

class DataChannelReestablish {
  final List<DataChannelSpec> _pendingRecreations = [];
  final List<List<int>> _pendingMessages = [];
  int _flushedCount = 0;

  List<DataChannelSpec> get pendingRecreations =>
      List.unmodifiable(_pendingRecreations);

  List<List<int>> get pendingMessages => List.unmodifiable(_pendingMessages);

  int get flushedCount => _flushedCount;

  /// Called when a DataChannel has been closed (e.g. during ICE restart).
  /// Records the spec so the channel can be re-created with the same params.
  void onChannelClosed({required DataChannelSpec spec}) {
    _pendingRecreations.add(spec);
  }

  /// Queues a message that arrived while the channel was closed.
  void onInFlightMessage({required List<int> message}) {
    _pendingMessages.add(message);
  }

  /// Called once the channel has been successfully re-opened.
  /// Flushes any queued messages and removes the spec from the pending list.
  void onChannelOpened({required DataChannelSpec spec}) {
    _flushedCount += _pendingMessages.length;
    _pendingMessages.clear();
    _pendingRecreations.removeWhere((s) => s.id == spec.id);
  }
}
