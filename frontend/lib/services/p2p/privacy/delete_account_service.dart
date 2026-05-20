/// Delete-account service — roadmap §18.5 Right to Erasure.
///
/// Client-side component that:
///   1. Builds a signed deletion request (Ed25519 signature placeholder).
///   2. Wipes all local storage (SQLCipher DB, SecureStorage, caches).
///   3. Tracks deletion state so the UI can show a permanent confirmation.
///
/// **Ed25519 note:** Full Ed25519 signing requires a key-management package
/// (e.g. `cryptography`). The current implementation generates a keyed-HMAC
/// over the canonical request bytes, which is verifiable server-side.
/// Switching to real Ed25519 requires a `kind: shared_edit` pubspec queue entry.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;

/// A deletion request that will be uploaded to the server.
class ClientDeletionRequest {
  /// The hex-encoded Ed25519 public key of the account.
  final String accountPubkey;

  /// HMAC-SHA256 signature over `'delete:' + accountPubkey + ':' + timestamp`.
  /// In production this is an Ed25519 signature; the HMAC is a stand-in until
  /// the crypto package dependency is approved.
  final Uint8List signature;

  /// ISO-8601 timestamp for replay-protection.
  final String timestamp;

  const ClientDeletionRequest({
    required this.accountPubkey,
    required this.signature,
    required this.timestamp,
  });
}

/// Abstraction over the local storage layer — injectable in tests.
abstract class LocalStoreFacade {
  Future<void> wipeSQLCipher();
  Future<void> wipeSecureStorage();
  Future<void> wipeCaches();
}

/// Production local-store implementation (no-op for now; real wiring to
/// SQLCipher / FlutterSecureStorage added in the integration phase).
class _ProductionLocalStore implements LocalStoreFacade {
  const _ProductionLocalStore();

  @override
  Future<void> wipeSQLCipher() async {
    // TODO: call sqflite_common_ffi deleteDatabase on the app DB path.
  }

  @override
  Future<void> wipeSecureStorage() async {
    // TODO: call FlutterSecureStorage.deleteAll().
  }

  @override
  Future<void> wipeCaches() async {
    // TODO: call path_provider temporaryDirectory + clearDir().
  }
}

/// Client-side service for the "Delete my account" flow (§18.5).
class DeleteAccountService {
  final LocalStoreFacade _store;
  bool _deleted = false;

  DeleteAccountService._({required LocalStoreFacade store}) : _store = store;

  /// Production constructor.
  factory DeleteAccountService() =>
      DeleteAccountService._(store: const _ProductionLocalStore());

  /// Test constructor — accepts an injectable [LocalStoreFacade] mock.
  factory DeleteAccountService.forTest({required LocalStoreFacade localStore}) =>
      DeleteAccountService._(store: localStore);

  /// Whether the local account has been permanently deleted.
  bool get isDeleted => _deleted;

  /// Build a deletion request signed with the given [deviceKeyBytes].
  ///
  /// Signs `'delete:' + accountPubkey + ':' + timestamp` with HMAC-SHA256
  /// keyed by [deviceKeyBytes].
  ClientDeletionRequest buildDeletionRequest({
    required String accountPubkey,
    required List<int> deviceKeyBytes,
  }) {
    final timestamp = DateTime.now().toUtc().toIso8601String();
    final message = utf8.encode('delete:$accountPubkey:$timestamp');
    final sig = crypto.Hmac(crypto.sha256, deviceKeyBytes).convert(message);
    return ClientDeletionRequest(
      accountPubkey: accountPubkey,
      signature: Uint8List.fromList(sig.bytes),
      timestamp: timestamp,
    );
  }

  /// Wipe all local storage for this account.
  ///
  /// Calls [wipeSQLCipher], [wipeSecureStorage], and [wipeCaches] on the
  /// injected store facade in sequence.
  Future<void> wipeLocalData() async {
    await _store.wipeSQLCipher();
    await _store.wipeSecureStorage();
    await _store.wipeCaches();
  }

  /// Mark the account as permanently deleted.
  ///
  /// Idempotent — safe to call multiple times.
  void markDeleted() {
    _deleted = true;
  }
}
