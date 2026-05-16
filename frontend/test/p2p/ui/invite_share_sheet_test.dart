// §6.7.3 Share-sheet integration proof test.
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/sharing/invite_share_service.dart';

// Stub adapter for testing — simulates a successful share-sheet presentation.
class _SuccessAdapter implements ShareAdapter {
  int callCount = 0;
  String? lastText;

  @override
  Future<bool> share(String text) async {
    callCount++;
    lastText = text;
    return true;
  }
}

// Stub adapter that simulates a share-sheet failure (e.g. not supported).
class _FailAdapter implements ShareAdapter {
  @override
  Future<bool> share(String text) async => false;
}

const _testLink = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz01234567890123456789012345678901234567890123456789012345';

void main() {
  group('InviteShareService §6.7.3', () {
    test('returns presented when adapter succeeds', () async {
      final svc = InviteShareService(adapter: _SuccessAdapter());
      final outcome = await svc.shareLinkViaSheet(_testLink);
      expect(outcome, equals(ShareOutcome.presented));
    });

    test('adapter receives the invite link verbatim', () async {
      final adapter = _SuccessAdapter();
      final svc = InviteShareService(adapter: adapter);
      await svc.shareLinkViaSheet(_testLink);
      expect(adapter.lastText, equals(_testLink));
    });

    test('returns qrFallback when no adapter is set', () async {
      final svc = InviteShareService();
      final outcome = await svc.shareLinkViaSheet(_testLink);
      expect(outcome, equals(ShareOutcome.qrFallback));
    });

    test('returns qrFallback when adapter fails', () async {
      final svc = InviteShareService(adapter: _FailAdapter());
      final outcome = await svc.shareLinkViaSheet(_testLink);
      expect(outcome, equals(ShareOutcome.qrFallback));
    });

    test('never auto-sends — adapter.share is not called at construction', () {
      final adapter = _SuccessAdapter();
      // Constructing the service must not trigger a share call.
      InviteShareService(adapter: adapter);
      expect(adapter.callCount, equals(0));
    });
  });
}
