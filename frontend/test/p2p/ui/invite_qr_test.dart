// §6.7.4 QR-code fallback proof test.
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/sharing/invite_share_service.dart';

void main() {
  group('QR fallback §6.7.4', () {
    const link = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnop';

    test('buildQrPayload returns the invite link unchanged', () {
      final svc = InviteShareService();
      expect(svc.buildQrPayload(link), equals(link));
    });

    test('QR payload is non-empty for a real-length invite token', () {
      final svc = InviteShareService();
      // A real invite token is 112 base64url chars.
      final token = 'A' * 112;
      expect(svc.buildQrPayload(token), isNotEmpty);
    });

    test('QR payload contains no spaces or padding (URL-safe)', () {
      final svc = InviteShareService();
      final payload = svc.buildQrPayload(link);
      expect(payload, isNot(contains(' ')));
      expect(payload, isNot(contains('=')));
    });
  });
}
