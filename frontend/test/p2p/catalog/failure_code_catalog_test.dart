// ignore_for_file: avoid_redundant_argument_values
/// Phase 10 — Failure-mode catalog proof tests.
///
/// Verifies that every failure code defined in [P2PFailureCode]:
///   (a) is a valid enum value,
///   (b) has a non-empty user-visible message key via [p2pFailureMessage],
///   (c) has a non-empty recovery hint key via [p2pFailureRecovery],
///   (d) has a defined [P2PFailureSeverity].
///
/// Tests are grouped by catalog section to match roadmap §10.0–§10.5.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:chessrecast/services/p2p/errors.dart';

void main() {
  // ─── helpers ──────────────────────────────────────────────────────────────

  void _check(P2PFailureCode code) {
    final msg = p2pFailureMessage(code);
    expect(msg, isNotEmpty, reason: '${code.name} must have a message key');

    final recovery = p2pFailureRecovery(code);
    expect(
      recovery,
      isNotEmpty,
      reason: '${code.name} must have a recovery hint key',
    );

    final severity = p2pFailureSeverity(code);
    expect(severity, isA<P2PFailureSeverity>());
  }

  // ─── §10.0 base catalog ───────────────────────────────────────────────────

  group('§10.0 protocol codes (F-PROTO-001–008)', () {
    test('F-PROTO-001 badFrame', () => _check(P2PFailureCode.badFrame));
    test('F-PROTO-002 badVersion', () => _check(P2PFailureCode.badVersion));
    test(
      'F-PROTO-003 outOfSequence',
      () => _check(P2PFailureCode.outOfSequence),
    );
    test(
      'F-PROTO-004 illegalMove',
      () => _check(P2PFailureCode.illegalMove),
    );
    test(
      'F-PROTO-005 modMismatch',
      () => _check(P2PFailureCode.modMismatch),
    );
    test(
      'F-PROTO-006 clockStarvation',
      () => _check(P2PFailureCode.clockStarvation),
    );
    test(
      'F-PROTO-007 backpressureDrop',
      () => _check(P2PFailureCode.backpressureDrop),
    );
    test('F-PROTO-008 mismatch', () => _check(P2PFailureCode.mismatch));
  });

  group('§10.0 network codes (F-NET-001–007)', () {
    test('F-NET-001 iceFailed', () => _check(P2PFailureCode.iceFailed));
    test(
      'F-NET-002 iceDisconnected',
      () => _check(P2PFailureCode.iceDisconnected),
    );
    test(
      'F-NET-003 networkLost',
      () => _check(P2PFailureCode.networkLost),
    );
    test(
      'F-NET-004 turnUnavailable',
      () => _check(P2PFailureCode.turnUnavailable),
    );
    test(
      'F-NET-005 captivePortal',
      () => _check(P2PFailureCode.captivePortal),
    );
    test(
      'F-NET-006 natHardBlock',
      () => _check(P2PFailureCode.natHardBlock),
    );
    test(
      'F-NET-007 ipv6PmtuBlackHole',
      () => _check(P2PFailureCode.ipv6PmtuBlackHole),
    );
  });

  group('§10.0 transport codes (F-XPORT-001–002)', () {
    test(
      'F-XPORT-001 datachannelClosedUnexpectedly',
      () => _check(P2PFailureCode.datachannelClosedUnexpectedly),
    );
    test(
      'F-XPORT-002 sctpHandshakeTimeout',
      () => _check(P2PFailureCode.sctpHandshakeTimeout),
    );
  });

  group('§10.0 signaling codes (F-SIG-001–006)', () {
    test(
      'F-SIG-001 signaling5xx',
      () => _check(P2PFailureCode.signaling5xx),
    );
    test(
      'F-SIG-002 signalingRateLimited',
      () => _check(P2PFailureCode.signalingRateLimited),
    );
    test(
      'F-SIG-003 signalingPowRequired',
      () => _check(P2PFailureCode.signalingPowRequired),
    );
    test(
      'F-SIG-004 offerExpired',
      () => _check(P2PFailureCode.offerExpired),
    );
    test(
      'F-SIG-005 offerDuplicateAnswer',
      () => _check(P2PFailureCode.offerDuplicateAnswer),
    );
    test(
      'F-SIG-006 adminDisabled',
      () => _check(P2PFailureCode.adminDisabled),
    );
  });

  group('§10.0 identity codes (F-ID-001–007)', () {
    test(
      'F-ID-001 keyGenFailed',
      () => _check(P2PFailureCode.keyGenFailed),
    );
    test(
      'F-ID-002 keyStorageUnavailable',
      () => _check(P2PFailureCode.keyStorageUnavailable),
    );
    test(
      'F-ID-003 biometricLockout',
      () => _check(P2PFailureCode.biometricLockout),
    );
    test(
      'F-ID-004 recoveryBadCode',
      () => _check(P2PFailureCode.recoveryBadCode),
    );
    test(
      'F-ID-005 recoveryParamMismatch',
      () => _check(P2PFailureCode.recoveryParamMismatch),
    );
    test(
      'F-ID-006 rebindAttestationFailed',
      () => _check(P2PFailureCode.rebindAttestationFailed),
    );
    test(
      'F-ID-007 oldDeviceRejectedAfterRebind',
      () => _check(P2PFailureCode.oldDeviceRejectedAfterRebind),
    );
  });

  group('§10.0 push codes (F-PUSH-001–004)', () {
    test(
      'F-PUSH-001 pushTokenInvalid',
      () => _check(P2PFailureCode.pushTokenInvalid),
    );
    test(
      'F-PUSH-002 pushProviderDown',
      () => _check(P2PFailureCode.pushProviderDown),
    );
    test(
      'F-PUSH-003 pushDeferredByOs',
      () => _check(P2PFailureCode.pushDeferredByOs),
    );
    test(
      'F-PUSH-004 pushReceivedNoOffer',
      () => _check(P2PFailureCode.pushReceivedNoOffer),
    );
  });

  group('§10.0 lifecycle codes (F-LIFECYCLE-001–004)', () {
    test(
      'F-LIFECYCLE-001 appSuspendedMidHandshake',
      () => _check(P2PFailureCode.appSuspendedMidHandshake),
    );
    test(
      'F-LIFECYCLE-002 foregroundServiceKilled',
      () => _check(P2PFailureCode.foregroundServiceKilled),
    );
    test(
      'F-LIFECYCLE-003 iosNseTimeout',
      () => _check(P2PFailureCode.iosNseTimeout),
    );
    test(
      'F-LIFECYCLE-004 deepLinkColdStartLost',
      () => _check(P2PFailureCode.deepLinkColdStartLost),
    );
  });

  group('§10.0 storage codes (F-STORE-001–003)', () {
    test(
      'F-STORE-001 savedGamesDbCorrupt',
      () => _check(P2PFailureCode.savedGamesDbCorrupt),
    );
    test(
      'F-STORE-002 savedGamesMigrationFailed',
      () => _check(P2PFailureCode.savedGamesMigrationFailed),
    );
    test('F-STORE-003 diskFull', () => _check(P2PFailureCode.diskFull));
  });

  group('§10.0 web/desktop/observability/chat/misc codes', () {
    test(
      'F-WEB-001 webrtcNotSupported',
      () => _check(P2PFailureCode.webrtcNotSupported),
    );
    test(
      'F-WEB-002 webcryptoNonExtractableLimit',
      () => _check(P2PFailureCode.webcryptoNonExtractableLimit),
    );
    test(
      'F-DESKTOP-001 libsecretUnavailable',
      () => _check(P2PFailureCode.libsecretUnavailable),
    );
    test(
      'F-OBS-001 telemetryQueueOverflow',
      () => _check(P2PFailureCode.telemetryQueueOverflow),
    );
    test(
      'F-CHAT-001 chatFrameTooLarge',
      () => _check(P2PFailureCode.chatFrameTooLarge),
    );
    test(
      'F-CHAT-002 chatRateLimitLocal',
      () => _check(P2PFailureCode.chatRateLimitLocal),
    );
    test(
      'F-LATEJOIN-001 lamportConflict',
      () => _check(P2PFailureCode.lamportConflict),
    );
    test(
      'F-FORENSIC-001 forensicBundleWriteFailed',
      () => _check(P2PFailureCode.forensicBundleWriteFailed),
    );
  });

  // ─── §10.1 v5 additions ───────────────────────────────────────────────────

  group('§10.1 v5 protocol codes (F-PROTO-009–015)', () {
    test(
      'F-PROTO-009 wireVersionMismatch',
      () => _check(P2PFailureCode.wireVersionMismatch),
    );
    test(
      'F-PROTO-010 engineVersionMismatch',
      () => _check(P2PFailureCode.engineVersionMismatch),
    );
    test(
      'F-PROTO-011 modConfigRejected',
      () => _check(P2PFailureCode.modConfigRejected),
    );
    test(
      'F-PROTO-012 timeControlRejected',
      () => _check(P2PFailureCode.timeControlRejected),
    );
    test(
      'F-PROTO-013 colorFlipRevealMismatch',
      () => _check(P2PFailureCode.colorFlipRevealMismatch),
    );
    test(
      'F-PROTO-014 transcriptSignFailed',
      () => _check(P2PFailureCode.transcriptSignFailed),
    );
    test(
      'F-PROTO-015 byeDisagreement',
      () => _check(P2PFailureCode.byeDisagreement),
    );
  });

  group('§10.1 v5 clock codes (F-CLOCK-001–003)', () {
    test(
      'F-CLOCK-001 clockDesyncBeyondBudget',
      () => _check(P2PFailureCode.clockDesyncBeyondBudget),
    );
    test(
      'F-CLOCK-002 flagFallDisagreement',
      () => _check(P2PFailureCode.flagFallDisagreement),
    );
    test(
      'F-CLOCK-003 resyncTimeout',
      () => _check(P2PFailureCode.resyncTimeout),
    );
  });

  group('§10.1 v5 misc codes', () {
    test(
      'F-XPORT-003 perfectNegCollisionUnresolved',
      () => _check(P2PFailureCode.perfectNegCollisionUnresolved),
    );
    test(
      'F-SIG-007 offerTokenExpired',
      () => _check(P2PFailureCode.offerTokenExpired),
    );
    test(
      'F-SIG-008 readOnlyModeRejectedWrite',
      () => _check(P2PFailureCode.readOnlyModeRejectedWrite),
    );
    test(
      'F-SIG-009 rebindRaceLost',
      () => _check(P2PFailureCode.rebindRaceLost),
    );
    test(
      'F-ID-008 kdfVersionUnsupported',
      () => _check(P2PFailureCode.kdfVersionUnsupported),
    );
    test(
      'F-ID-009 bip39ChecksumFail',
      () => _check(P2PFailureCode.bip39ChecksumFail),
    );
    test(
      'F-ID-010 kdfParamsTooWeak',
      () => _check(P2PFailureCode.kdfParamsTooWeak),
    );
    test(
      'F-ID-011 xchaChaNonceReuseDetected',
      () => _check(P2PFailureCode.xchaChaNonceReuseDetected),
    );
    test(
      'F-INTEGRITY-001 startupIntegrityFail',
      () => _check(P2PFailureCode.startupIntegrityFail),
    );
    test(
      'F-WEB-003 webPlatformUnsupportedFeature',
      () => _check(P2PFailureCode.webPlatformUnsupportedFeature),
    );
    test(
      'F-DESKTOP-002 biometricNotAvailableDesktop',
      () => _check(P2PFailureCode.biometricNotAvailableDesktop),
    );
    test(
      'F-OBS-002 diagLogDiskFull',
      () => _check(P2PFailureCode.diagLogDiskFull),
    );
    test(
      'F-OPS-001 killSwitchEngaged',
      () => _check(P2PFailureCode.killSwitchEngaged),
    );
  });

  // ─── §10.2 v6 additions ───────────────────────────────────────────────────

  group('§10.2 v6 protocol codes (F-PROTO-016–022)', () {
    test(
      'F-PROTO-016 seqCeilingReached',
      () => _check(P2PFailureCode.seqCeilingReached),
    );
    test(
      'F-PROTO-017 byeFragmentTimeout',
      () => _check(P2PFailureCode.byeFragmentTimeout),
    );
    test(
      'F-PROTO-018 byeFragmentOutOfOrder',
      () => _check(P2PFailureCode.byeFragmentOutOfOrder),
    );
    test(
      'F-PROTO-019 byeFragmentOutOfBounds',
      () => _check(P2PFailureCode.byeFragmentOutOfBounds),
    );
    test(
      'F-PROTO-020 fragmentNotAllowed',
      () => _check(P2PFailureCode.fragmentNotAllowed),
    );
    test(
      'F-PROTO-021 cryptoSuiteNotNegotiated',
      () => _check(P2PFailureCode.cryptoSuiteNotNegotiated),
    );
    test(
      'F-PROTO-022 transcriptVersionUnsupported',
      () => _check(P2PFailureCode.transcriptVersionUnsupported),
    );
  });

  group('§10.2 v6 misc codes', () {
    test(
      'F-ID-012 kdfDerivationFailed',
      () => _check(P2PFailureCode.kdfDerivationFailed),
    );
    test(
      'F-ID-013 secretZeroiseFailed',
      () => _check(P2PFailureCode.secretZeroiseFailed),
    );
    test(
      'F-XPORT-004 datachannelIdCollision',
      () => _check(P2PFailureCode.datachannelIdCollision),
    );
    test(
      'F-XPORT-005 resumedAsNew',
      () => _check(P2PFailureCode.resumedAsNew),
    );
    test(
      'F-CLOCK-004 monotonicClockUnavailable',
      () => _check(P2PFailureCode.monotonicClockUnavailable),
    );
    test(
      'F-CLOCK-005 wallClockTamperedDetected',
      () => _check(P2PFailureCode.wallClockTamperedDetected),
    );
    test(
      'F-NET-008 meteredNetworkUserDeclined',
      () => _check(P2PFailureCode.meteredNetworkUserDeclined),
    );
    test(
      'F-LIFECYCLE-005 oemBatteryOptBlocking',
      () => _check(P2PFailureCode.oemBatteryOptBlocking),
    );
    test(
      'F-PUSH-005 apnsSilentPushDropped',
      () => _check(P2PFailureCode.apnsSilentPushDropped),
    );
    test(
      'F-PUSH-006 fcmTokenRefreshed',
      () => _check(P2PFailureCode.fcmTokenRefreshed),
    );
    test(
      'F-ID-014 recoveryScreenCapturedDetected',
      () => _check(P2PFailureCode.recoveryScreenCapturedDetected),
    );
    test(
      'F-CHAT-003 chatBlockedByUser',
      () => _check(P2PFailureCode.chatBlockedByUser),
    );
    test(
      'F-CHAT-004 chatReportedAsAbuse',
      () => _check(P2PFailureCode.chatReportedAsAbuse),
    );
    test(
      'F-ONBOARD-001 ageGateBlocked',
      () => _check(P2PFailureCode.ageGateBlocked),
    );
    test(
      'F-STORE-004 storePrivacyManifestOutOfDate',
      () => _check(P2PFailureCode.storePrivacyManifestOutOfDate),
    );
    test(
      'F-SIG-010 deviceCapExceeded',
      () => _check(P2PFailureCode.deviceCapExceeded),
    );
    test(
      'F-SIG-011 longPollCapExceeded',
      () => _check(P2PFailureCode.longPollCapExceeded),
    );
    test(
      'F-SIG-012 sdpTooLarge',
      () => _check(P2PFailureCode.sdpTooLarge),
    );
    test(
      'F-SIG-013 sdpForbiddenMediaLine',
      () => _check(P2PFailureCode.sdpForbiddenMediaLine),
    );
    test(
      'F-SPEC-001 spectatorChainRejected',
      () => _check(P2PFailureCode.spectatorChainRejected),
    );
    test(
      'F-CONC-001 isolateCrashed',
      () => _check(P2PFailureCode.isolateCrashed),
    );
    test(
      'F-CONC-002 sodiumInitFailed',
      () => _check(P2PFailureCode.sodiumInitFailed),
    );
  });

  // ─── §10.3 v7 additions ───────────────────────────────────────────────────

  group('§10.3 v7 storage codes (F-STORE-005–008)', () {
    test(
      'F-STORE-005 sqlcipherKeyUnwrapFail',
      () => _check(P2PFailureCode.sqlcipherKeyUnwrapFail),
    );
    test(
      'F-STORE-006 localStorageQuotaExceeded',
      () => _check(P2PFailureCode.localStorageQuotaExceeded),
    );
    test(
      'F-STORE-007 localStorageAtRestBroken',
      () => _check(P2PFailureCode.localStorageAtRestBroken),
    );
    test(
      'F-STORE-008 backupEncryptionSaltMismatch',
      () => _check(P2PFailureCode.backupEncryptionSaltMismatch),
    );
  });

  group('§10.3 v7 identity codes (F-ID-015–018)', () {
    test(
      'F-ID-015 kciVerifyFailed',
      () => _check(P2PFailureCode.kciVerifyFailed),
    );
    test(
      'F-ID-016 sessionIdCollision',
      () => _check(P2PFailureCode.sessionIdCollision),
    );
    test(
      'F-ID-017 safetyNumbersMismatch',
      () => _check(P2PFailureCode.safetyNumbersMismatch),
    );
    test(
      'F-ID-018 reKeyFailed',
      () => _check(P2PFailureCode.reKeyFailed),
    );
  });

  group('§10.3 v7 protocol codes (F-PROTO-023–029)', () {
    test(
      'F-PROTO-023 cborFloatRejected',
      () => _check(P2PFailureCode.cborFloatRejected),
    );
    test(
      'F-PROTO-024 hkdfInfoUnknown',
      () => _check(P2PFailureCode.hkdfInfoUnknown),
    );
    test(
      'F-PROTO-025 opponentFingerprintDowngradeDetected',
      () => _check(P2PFailureCode.opponentFingerprintDowngradeDetected),
    );
    test(
      'F-PROTO-026 repetitionClaimRejected',
      () => _check(P2PFailureCode.repetitionClaimRejected),
    );
    test(
      'F-PROTO-027 deprecatedWireVersionRejected',
      () => _check(P2PFailureCode.deprecatedWireVersionRejected),
    );
    test(
      'F-PROTO-028 deprecatedCryptoSuiteRejected',
      () => _check(P2PFailureCode.deprecatedCryptoSuiteRejected),
    );
    test(
      'F-PROTO-029 deprecatedEngineReplayVersionRejected',
      () => _check(P2PFailureCode.deprecatedEngineReplayVersionRejected),
    );
  });

  group('§10.3 v7 misc codes', () {
    test(
      'F-NET-009 turnsHandshakeFailed',
      () => _check(P2PFailureCode.turnsHandshakeFailed),
    );
    test(
      'F-CLOCK-006 premoveInvalidated',
      () => _check(P2PFailureCode.premoveInvalidated),
    );
    test(
      'F-SIG-014 inviteLinkExpired',
      () => _check(P2PFailureCode.inviteLinkExpired),
    );
    test(
      'F-SIG-015 inviteLinkReplayed',
      () => _check(P2PFailureCode.inviteLinkReplayed),
    );
    test(
      'F-CHAT-005 handleImpersonationSuspected',
      () => _check(P2PFailureCode.handleImpersonationSuspected),
    );
    test(
      'F-OBS-003 transcriptRamCapOverflow',
      () => _check(P2PFailureCode.transcriptRamCapOverflow),
    );
    test(
      'F-OPS-002 cveRequiresForcedUpdate',
      () => _check(P2PFailureCode.cveRequiresForcedUpdate),
    );
    test(
      'F-OPS-003 keyRotationOverdue',
      () => _check(P2PFailureCode.keyRotationOverdue),
    );
    test(
      'F-OPS-004 backupRestoreDrillFailed',
      () => _check(P2PFailureCode.backupRestoreDrillFailed),
    );
    test(
      'F-OPS-005 operatorOnCallUnreachable',
      () => _check(P2PFailureCode.operatorOnCallUnreachable),
    );
  });

  // ─── §10.4 v8 additions ───────────────────────────────────────────────────

  group('§10.4 v8 protocol codes (F-PROTO-030–037)', () {
    test(
      'F-PROTO-030 validateApplyRaceDetected',
      () => _check(P2PFailureCode.validateApplyRaceDetected),
    );
    test(
      'F-PROTO-031 ffiFuzzFoundDivergence',
      () => _check(P2PFailureCode.ffiFuzzFoundDivergence),
    );
    test(
      'F-PROTO-032 helloTsOutOfWindow',
      () => _check(P2PFailureCode.helloTsOutOfWindow),
    );
    test(
      'F-PROTO-033 signedTimeFetchFailed',
      () => _check(P2PFailureCode.signedTimeFetchFailed),
    );
    test(
      'F-PROTO-034 multiDeviceRaceLost',
      () => _check(P2PFailureCode.multiDeviceRaceLost),
    );
    test(
      'F-PROTO-035 configBlobVersionUnsupported',
      () => _check(P2PFailureCode.configBlobVersionUnsupported),
    );
    test(
      'F-PROTO-036 spectatorChainDepthNonzeroRejected',
      () => _check(P2PFailureCode.spectatorChainDepthNonzeroRejected),
    );
    test(
      'F-PROTO-037 backfillOversizeRejected',
      () => _check(P2PFailureCode.backfillOversizeRejected),
    );
  });

  group('§10.4 v8 misc codes', () {
    test(
      'F-START-001 startupSelfTestFail',
      () => _check(P2PFailureCode.startupSelfTestFail),
    );
    test(
      'F-START-002 nativeLibIntegrityFail',
      () => _check(P2PFailureCode.nativeLibIntegrityFail),
    );
    test(
      'F-PUSH-007 pushCoalesced',
      () => _check(P2PFailureCode.pushCoalesced),
    );
    test(
      'F-NET-010 turnBandwidthExceeded',
      () => _check(P2PFailureCode.turnBandwidthExceeded),
    );
    test(
      'F-NET-011 iceVpnLeakUserDeclined',
      () => _check(P2PFailureCode.iceVpnLeakUserDeclined),
    );
    test(
      'F-STORE-009 schemaSkipVersionFail',
      () => _check(P2PFailureCode.schemaSkipVersionFail),
    );
    test(
      'F-TEL-001 dpBudgetExceeded',
      () => _check(P2PFailureCode.dpBudgetExceeded),
    );
    test(
      'F-TEL-002 telemetryEnvelopeVersionUnsupported',
      () => _check(P2PFailureCode.telemetryEnvelopeVersionUnsupported),
    );
    test(
      'F-STUDY-001 studyLoadVersionMismatch',
      () => _check(P2PFailureCode.studyLoadVersionMismatch),
    );
    test(
      'F-STUDY-002 exportSidecarMissing',
      () => _check(P2PFailureCode.exportSidecarMissing),
    );
    test(
      'F-STUDY-003 studyPgnParseFail',
      () => _check(P2PFailureCode.studyPgnParseFail),
    );
    test(
      'F-STUDY-004 studyReplayHashDivergence',
      () => _check(P2PFailureCode.studyReplayHashDivergence),
    );
    test(
      'F-LIFE-005 bgTaskDeniedByOs',
      () => _check(P2PFailureCode.bgTaskDeniedByOs),
    );
    test(
      'F-NET-012 loadShedDropped',
      () => _check(P2PFailureCode.loadShedDropped),
    );
    test(
      'F-CLOCK-007 rageQuitForfeitFired',
      () => _check(P2PFailureCode.rageQuitForfeitFired),
    );
    test(
      'F-STORE-010 legitimateRestoreMergeDeclined',
      () => _check(P2PFailureCode.legitimateRestoreMergeDeclined),
    );
    test(
      'F-CHAT-006v8 reportTargetRateLimited',
      () => _check(P2PFailureCode.reportTargetRateLimited),
    );
  });

  // ─── §10.5 v9 additions (spectator + chat) ────────────────────────────────

  group('§10.5 v9 spectator codes (F-SPEC-001–014)', () {
    test(
      'F-SPEC-002 spectatorCapacityFull',
      () => _check(P2PFailureCode.spectatorCapacityFull),
    );
    test(
      'F-SPEC-003 spectatorWaitlistExpired',
      () => _check(P2PFailureCode.spectatorWaitlistExpired),
    );
    test(
      'F-SPEC-004 spectatorAuthRequired',
      () => _check(P2PFailureCode.spectatorAuthRequired),
    );
    test(
      'F-SPEC-005 spectatorJoinRateLimited',
      () => _check(P2PFailureCode.spectatorJoinRateLimited),
    );
    test(
      'F-SPEC-006 spectatorKicked',
      () => _check(P2PFailureCode.spectatorKicked),
    );
    test(
      'F-SPEC-007 spectatorBanned',
      () => _check(P2PFailureCode.spectatorBanned),
    );
    test(
      'F-SPEC-008 spectatorMuted',
      () => _check(P2PFailureCode.spectatorMuted),
    );
    test(
      'F-SPEC-009 spectatorGloballyMuted',
      () => _check(P2PFailureCode.spectatorGloballyMuted),
    );
    test(
      'F-SPEC-010 spectatorShedForPerf',
      () => _check(P2PFailureCode.spectatorShedForPerf),
    );
    test(
      'F-SPEC-011 spectatorRelayUnavailable',
      () => _check(P2PFailureCode.spectatorRelayUnavailable),
    );
    test(
      'F-SPEC-012 backfillQueueOverflow',
      () => _check(P2PFailureCode.backfillQueueOverflow),
    );
    test(
      'F-SPEC-013 spectatorHeartbeatTimeout',
      () => _check(P2PFailureCode.spectatorHeartbeatTimeout),
    );
    test(
      'F-SPEC-014 spectatorKeyRotationRequired',
      () => _check(P2PFailureCode.spectatorKeyRotationRequired),
    );
    test(
      'F-SPEC-015 spectatorDatachannelBackpressure',
      () => _check(P2PFailureCode.spectatorDatachannelBackpressure),
    );
  });

  group('§10.5 v9 chat codes (F-CHAT-007–020)', () {
    test(
      'F-CHAT-007 chatRateLimited',
      () => _check(P2PFailureCode.chatRateLimited),
    );
    test(
      'F-CHAT-008 chatMessageOversized',
      () => _check(P2PFailureCode.chatMessageOversized),
    );
    test(
      'F-CHAT-009 chatSlowModeActive',
      () => _check(P2PFailureCode.chatSlowModeActive),
    );
    test(
      'F-CHAT-010 chatAutoThrottledClockPressure',
      () => _check(P2PFailureCode.chatAutoThrottledClockPressure),
    );
    test(
      'F-CHAT-011 chatReceiverOverflow',
      () => _check(P2PFailureCode.chatReceiverOverflow),
    );
    test(
      'F-CHAT-012 chatReportFiled',
      () => _check(P2PFailureCode.chatReportFiled),
    );
    test(
      'F-CHAT-013 chatTournamentLocked',
      () => _check(P2PFailureCode.chatTournamentLocked),
    );
    test(
      'F-CHAT-014 chatHostBroadcastDroppedLowPriority',
      () => _check(P2PFailureCode.chatHostBroadcastDroppedLowPriority),
    );
    test(
      'F-CHAT-015 chatDecodeErrorDiscarded',
      () => _check(P2PFailureCode.chatDecodeErrorDiscarded),
    );
    test(
      'F-CHAT-016 chatNfcNormalisationFail',
      () => _check(P2PFailureCode.chatNfcNormalisationFail),
    );
    test(
      'F-CHAT-017 chatHomoglyphBlocked',
      () => _check(P2PFailureCode.chatHomoglyphBlocked),
    );
  });

  // ─── cross-cutting: severity contract ─────────────────────────────────────

  group('severity contract', () {
    test('critical codes have severity critical', () {
      final critical = [
        P2PFailureCode.secretZeroiseFailed,
        P2PFailureCode.xchaChaNonceReuseDetected,
        P2PFailureCode.sessionIdCollision,
        P2PFailureCode.validateApplyRaceDetected,
        P2PFailureCode.sodiumInitFailed,
      ];
      for (final code in critical) {
        expect(
          p2pFailureSeverity(code),
          equals(P2PFailureSeverity.critical),
          reason: '${code.name} must be severity=critical',
        );
      }
    });

    test('informational codes have severity info', () {
      final info = [
        P2PFailureCode.fcmTokenRefreshed,
        P2PFailureCode.pushCoalesced,
        P2PFailureCode.wallClockTamperedDetected,
        P2PFailureCode.premoveInvalidated,
      ];
      for (final code in info) {
        expect(
          p2pFailureSeverity(code),
          equals(P2PFailureSeverity.info),
          reason: '${code.name} must be severity=info',
        );
      }
    });
  });

  // ─── completeness: every value covered ────────────────────────────────────

  group('completeness', () {
    test('all enum values have non-empty message and recovery keys', () {
      for (final code in P2PFailureCode.values) {
        final msg = p2pFailureMessage(code);
        expect(msg, isNotEmpty, reason: '${code.name} missing message key');
        final rec = p2pFailureRecovery(code);
        expect(rec, isNotEmpty, reason: '${code.name} missing recovery key');
      }
    });
  });
}
