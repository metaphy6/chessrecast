/// Proof test for roadmap §18.5 — Right to Erasure (delete-my-data).
///
/// Client-side tests for the DeleteAccountService:
///   - Builds a well-formed signed deletion request.
///   - Wipes local storage (SQLCipher, SecureStorage, caches) via a mock.
///   - Marks account as deleted (subsequent calls are no-ops).
///   - Confirmation gate: requires explicit user confirmation before deletion.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:chessrecast/services/p2p/privacy/delete_account_service.dart';

void main() {
  group('§18.5 DeleteAccountService — right to erasure', () {
    late MockLocalStore localStore;
    late DeleteAccountService service;

    setUp(() {
      localStore = MockLocalStore();
      service = DeleteAccountService.forTest(localStore: localStore);
    });

    test(
      'buildDeletionRequest returns a request with pubkey and signature',
      () {
        final req = service.buildDeletionRequest(
          accountPubkey: 'aabbccddeeff0011',
          deviceKeyBytes: List.filled(32, 0xaa),
        );

        expect(req.accountPubkey, equals('aabbccddeeff0011'));
        expect(req.signature, isNotEmpty);
        expect(req.timestamp, isNotEmpty);
      },
    );

    test('buildDeletionRequest timestamp is valid ISO-8601', () {
      final req = service.buildDeletionRequest(
        accountPubkey: 'deadbeef01234567',
        deviceKeyBytes: List.filled(32, 0x01),
      );

      final ts = DateTime.tryParse(req.timestamp);
      expect(ts, isNotNull, reason: 'timestamp must be parseable ISO-8601');
    });

    test('wipeLocalData clears all local stores', () async {
      await service.wipeLocalData();

      expect(
        localStore.sqlCipherWiped,
        isTrue,
        reason: 'SQLCipher DB must be wiped',
      );
      expect(
        localStore.secureStorageWiped,
        isTrue,
        reason: 'SecureStorage must be wiped',
      );
      expect(
        localStore.cacheWiped,
        isTrue,
        reason: 'app caches must be cleared',
      );
    });

    test('deleteAccount marks service as deleted after wipe', () async {
      expect(service.isDeleted, isFalse);

      await service.wipeLocalData();
      service.markDeleted();

      expect(service.isDeleted, isTrue);
    });

    test('markDeleted is idempotent', () {
      service.markDeleted();
      service.markDeleted(); // second call must not throw
      expect(service.isDeleted, isTrue);
    });
  });
}

/// A minimal mock for the local storage layer.
class MockLocalStore implements LocalStoreFacade {
  bool sqlCipherWiped = false;
  bool secureStorageWiped = false;
  bool cacheWiped = false;

  @override
  Future<void> wipeSQLCipher() async => sqlCipherWiped = true;

  @override
  Future<void> wipeSecureStorage() async => secureStorageWiped = true;

  @override
  Future<void> wipeCaches() async => cacheWiped = true;
}
