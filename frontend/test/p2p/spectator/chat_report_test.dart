// §7.9.7 chat report proof test (Dart side).
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/spectator/spectator_chat_extended.dart';

void main() {
  group('ChatReportManager §7.9.7', () {
    test('filing a report succeeds on first attempt', () {
      final mgr = ChatReportManager();
      final payload = ChatReportPayload(
        reporterPubKeyHex: 'aabb',
        targetPubKeyHex: 'ccdd',
        gameId: 'g1',
        messageHash: 'aabbccdd',
      );
      final result = mgr.fileReport(payload, 0);
      expect(result, equals('CHAT_REPORT_FILED'));
    });

    test('5 reports in 24 h are accepted', () {
      final mgr = ChatReportManager();
      const reporter = 'heavy_reporter';
      for (var i = 0; i < ChatReportManager.maxReportsPerDay; i++) {
        final result = mgr.fileReport(
          ChatReportPayload(
            reporterPubKeyHex: reporter,
            targetPubKeyHex: 'target_\$i',
            gameId: 'g\$i',
            messageHash: 'hash\$i',
          ),
          i * 1000,
        );
        expect(result, equals('CHAT_REPORT_FILED'));
      }
    });

    test('6th report in 24 h is rate-limited', () {
      final mgr = ChatReportManager();
      const reporter = 'overreporter';
      for (var i = 0; i < ChatReportManager.maxReportsPerDay; i++) {
        mgr.fileReport(
          ChatReportPayload(
            reporterPubKeyHex: reporter,
            targetPubKeyHex: 'target',
            gameId: 'g',
            messageHash: 'hash\$i',
          ),
          0,
        );
      }
      final result = mgr.fileReport(
        ChatReportPayload(
          reporterPubKeyHex: reporter,
          targetPubKeyHex: 'target',
          gameId: 'g',
          messageHash: 'hash_extra',
        ),
        0,
      );
      expect(result, equals('CHAT_REPORT_RATE_LIMITED'));
    });

    test('first report auto-mutes the target', () {
      final mgr = ChatReportManager();
      mgr.fileReport(
        ChatReportPayload(
          reporterPubKeyHex: 'r1',
          targetPubKeyHex: 'auto_mute_target',
          gameId: 'g',
          messageHash: 'h1',
        ),
        0,
      );
      expect(mgr.isAutoMuted('auto_mute_target'), isTrue);
    });
  });
}
