// ignore_for_file: constant_identifier_names

/// Multi-device per-account routing (§7 bullet-2).
///
/// Same account key on N devices; signaling routes offers to all reachable
/// devices; first-to-answer wins; others abort gracefully.
library;

import 'dart:typed_data';

/// Represents one device registered under an account.
class AccountDevice {
  final Uint8List devicePubKey;
  final String deviceName;
  bool isReachable;

  AccountDevice({
    required this.devicePubKey,
    required this.deviceName,
    this.isReachable = true,
  });
}

/// Result of multi-device offer routing.
enum OfferRoutingResult {
  /// An offer was dispatched to ≥ 1 reachable device.
  dispatched,

  /// No devices are reachable.
  noReachableDevices,
}

/// Routes offers to all reachable devices under an account.
class MultiDeviceRouter {
  final List<AccountDevice> _devices = [];

  void registerDevice(AccountDevice device) {
    _devices.add(device);
  }

  void unregisterDevice(Uint8List devicePubKey) {
    _devices.removeWhere((d) => _eq(d.devicePubKey, devicePubKey));
  }

  void markReachable(Uint8List devicePubKey, {required bool reachable}) {
    for (final d in _devices) {
      if (_eq(d.devicePubKey, devicePubKey)) {
        d.isReachable = reachable;
      }
    }
  }

  List<AccountDevice> get reachableDevices =>
      _devices.where((d) => d.isReachable).toList();

  /// Dispatch offer to all reachable devices.
  ///
  /// Returns the list of devices the offer was sent to.
  List<AccountDevice> dispatchOffer() {
    final targets = reachableDevices;
    return targets;
  }

  /// Called when a device answers. Returns the winner and the losers (to abort).
  ({AccountDevice winner, List<AccountDevice> losers}) firstToAnswer(
    Uint8List answeringDevicePubKey,
  ) {
    final winner = _devices.firstWhere(
      (d) => _eq(d.devicePubKey, answeringDevicePubKey),
    );
    final losers = _devices
        .where((d) => !_eq(d.devicePubKey, answeringDevicePubKey) && d.isReachable)
        .toList();
    return (winner: winner, losers: losers);
  }

  static bool _eq(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
