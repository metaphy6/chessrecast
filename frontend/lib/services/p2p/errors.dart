/// P2P failure-mode catalog — Phase 10.
///
/// Defines every typed [P2PFailureCode] value across catalog versions v4–v9
/// (roadmap §10.0–§10.5), a severity tier for triage, and helpers that return
/// the user-visible message and recovery-hint ARB key for each code.
library;

// ─── severity ────────────────────────────────────────────────────────────────

/// Triage severity of a [P2PFailureCode].
enum P2PFailureSeverity {
  /// Data-loss, crypto-integrity, or invariant violation requiring immediate
  /// attention and possible forced session termination.
  critical,

  /// Connection or game-flow error that ends or degrades the session.
  error,

  /// Degraded-mode condition; the session may continue.
  warning,

  /// Informational event; no action required.
  info,
}

// ─── failure codes ───────────────────────────────────────────────────────────

/// Typed catalog of every P2P failure mode across roadmap §10.0–§10.5.
///
/// Code numbering follows the roadmap (F-PROTO-001, F-NET-001, …).
/// Where later catalog versions re-use a code number for a *different* failure,
/// the Dart name is made unique (e.g. [ipv6PmtuBlackHole] for v4 F-NET-007 and
/// [turnBandwidthExceeded] for v8 F-NET-007).
enum P2PFailureCode {
  // ── §10.0 protocol (F-PROTO-001–008) ───────────────────────────────────────
  /// F-PROTO-001 BAD_FRAME: CBOR parse failed.
  badFrame,

  /// F-PROTO-002 BAD_VERSION: unsupported wire version in HELLO.
  badVersion,

  /// F-PROTO-003 OUT_OF_SEQUENCE: move arrived out of order.
  outOfSequence,

  /// F-PROTO-004 ILLEGAL_MOVE: move rejected by engine.
  illegalMove,

  /// F-PROTO-005 MOD_MISMATCH: mod/variant mismatch.
  modMismatch,

  /// F-PROTO-006 CLOCK_STARVATION: clock channel starved.
  clockStarvation,

  /// F-PROTO-007 BACKPRESSURE_DROP: send queue overflowed; frame dropped.
  backpressureDrop,

  /// F-PROTO-008 MISMATCH: generic state mismatch.
  mismatch,

  // ── §10.0 network (F-NET-001–007) ──────────────────────────────────────────
  /// F-NET-001 ICE_FAILED: ICE negotiation failed.
  iceFailed,

  /// F-NET-002 ICE_DISCONNECTED: ICE connection dropped.
  iceDisconnected,

  /// F-NET-003 NETWORK_LOST: device lost network access.
  networkLost,

  /// F-NET-004 TURN_UNAVAILABLE: no TURN server reachable.
  turnUnavailable,

  /// F-NET-005 CAPTIVE_PORTAL: network behind captive portal.
  captivePortal,

  /// F-NET-006 NAT_HARD_BLOCK: symmetric NAT with no TURN fallback.
  natHardBlock,

  /// F-NET-007 (v4) IPV6_PMTU_BLACK_HOLE: path MTU black hole on IPv6.
  ipv6PmtuBlackHole,

  // ── §10.0 transport (F-XPORT-001–002) ──────────────────────────────────────
  /// F-XPORT-001 DATACHANNEL_CLOSED_UNEXPECTEDLY: data channel closed.
  datachannelClosedUnexpectedly,

  /// F-XPORT-002 SCTP_HANDSHAKE_TIMEOUT: SCTP handshake timed out.
  sctpHandshakeTimeout,

  // ── §10.0 signaling (F-SIG-001–006) ────────────────────────────────────────
  /// F-SIG-001 SIGNALING_5XX: signaling server returned 5xx.
  signaling5xx,

  /// F-SIG-002 SIGNALING_RATE_LIMITED: signaling rate limited.
  signalingRateLimited,

  /// F-SIG-003 SIGNALING_POW_REQUIRED: proof-of-work required.
  signalingPowRequired,

  /// F-SIG-004 OFFER_EXPIRED: invite offer expired.
  offerExpired,

  /// F-SIG-005 OFFER_DUPLICATE_ANSWER: duplicate answer for offer.
  offerDuplicateAnswer,

  /// F-SIG-006 ADMIN_DISABLED: feature disabled by administrator.
  adminDisabled,

  // ── §10.0 identity (F-ID-001–007) ──────────────────────────────────────────
  /// F-ID-001 KEY_GEN_FAILED: keypair generation failed.
  keyGenFailed,

  /// F-ID-002 KEY_STORAGE_UNAVAILABLE: secure key storage unavailable.
  keyStorageUnavailable,

  /// F-ID-003 BIOMETRIC_LOCKOUT: biometric authentication locked out.
  biometricLockout,

  /// F-ID-004 RECOVERY_BAD_CODE: invalid recovery code entered.
  recoveryBadCode,

  /// F-ID-005 RECOVERY_PARAM_MISMATCH: KDF params do not match saved state.
  recoveryParamMismatch,

  /// F-ID-006 REBIND_ATTESTATION_FAILED: device attestation failed on rebind.
  rebindAttestationFailed,

  /// F-ID-007 OLD_DEVICE_REJECTED_AFTER_REBIND: old device revoked.
  oldDeviceRejectedAfterRebind,

  // ── §10.0 push (F-PUSH-001–004) ────────────────────────────────────────────
  /// F-PUSH-001 PUSH_TOKEN_INVALID: push token is invalid or expired.
  pushTokenInvalid,

  /// F-PUSH-002 (v4) PUSH_PROVIDER_DOWN: push provider unreachable.
  pushProviderDown,

  /// F-PUSH-003 PUSH_DEFERRED_BY_OS: OS deferred push delivery.
  pushDeferredByOs,

  /// F-PUSH-004 PUSH_RECEIVED_NO_OFFER: push arrived but no offer found.
  pushReceivedNoOffer,

  // ── §10.0 lifecycle (F-LIFECYCLE-001–004) ──────────────────────────────────
  /// F-LIFECYCLE-001 APP_SUSPENDED_MID_HANDSHAKE: app backgrounded during connect.
  appSuspendedMidHandshake,

  /// F-LIFECYCLE-002 FOREGROUND_SERVICE_KILLED: Android foreground service killed.
  foregroundServiceKilled,

  /// F-LIFECYCLE-003 IOS_NSE_TIMEOUT: iOS Notification Service Extension timed out.
  iosNseTimeout,

  /// F-LIFECYCLE-004 DEEP_LINK_COLD_START_LOST: deep link lost on cold start.
  deepLinkColdStartLost,

  // ── §10.0 storage (F-STORE-001–003) ────────────────────────────────────────
  /// F-STORE-001 SAVED_GAMES_DB_CORRUPT: saved-games database is corrupt.
  savedGamesDbCorrupt,

  /// F-STORE-002 SAVED_GAMES_MIGRATION_FAILED: database migration failed.
  savedGamesMigrationFailed,

  /// F-STORE-003 DISK_FULL: device storage is full.
  diskFull,

  // ── §10.0 web / desktop / observability / chat / misc ──────────────────────
  /// F-WEB-001 WEBRTC_NOT_SUPPORTED: WebRTC not supported in this browser.
  webrtcNotSupported,

  /// F-WEB-002 WEBCRYPTO_NON_EXTRACTABLE_LIMIT: WebCrypto key export denied.
  webcryptoNonExtractableLimit,

  /// F-DESKTOP-001 LIBSECRET_UNAVAILABLE: libsecret / keychain unavailable.
  libsecretUnavailable,

  /// F-OBS-001 TELEMETRY_QUEUE_OVERFLOW: telemetry queue overflowed.
  telemetryQueueOverflow,

  /// F-CHAT-001 CHAT_FRAME_TOO_LARGE: chat message exceeds frame limit.
  chatFrameTooLarge,

  /// F-CHAT-002 CHAT_RATE_LIMIT_LOCAL: local chat rate limit reached.
  chatRateLimitLocal,

  /// F-LATEJOIN-001 LAMPORT_CONFLICT: Lamport clock conflict on late join.
  lamportConflict,

  /// F-FORENSIC-001 FORENSIC_BUNDLE_WRITE_FAILED: forensic bundle could not be written.
  forensicBundleWriteFailed,

  // ── §10.1 v5 — protocol (F-PROTO-009–015) ──────────────────────────────────
  /// F-PROTO-009 WIRE_VERSION_MISMATCH: wire version negotiation failed.
  wireVersionMismatch,

  /// F-PROTO-010 ENGINE_VERSION_MISMATCH: engine binary version mismatch.
  engineVersionMismatch,

  /// F-PROTO-011 MOD_CONFIG_REJECTED: mod configuration rejected by peer.
  modConfigRejected,

  /// F-PROTO-012 TIME_CONTROL_REJECTED: time control rejected by peer.
  timeControlRejected,

  /// F-PROTO-013 COLOR_FLIP_REVEAL_MISMATCH: committed color reveal mismatch.
  colorFlipRevealMismatch,

  /// F-PROTO-014 TRANSCRIPT_SIGN_FAILED: transcript signature generation failed.
  transcriptSignFailed,

  /// F-PROTO-015 BYE_DISAGREEMENT: BYE reason code disagreement.
  byeDisagreement,

  // ── §10.1 v5 — clock (F-CLOCK-001–003) ────────────────────────────────────
  /// F-CLOCK-001 CLOCK_DESYNC_BEYOND_BUDGET: clocks drifted beyond tolerance.
  clockDesyncBeyondBudget,

  /// F-CLOCK-002 FLAG_FALL_DISAGREEMENT: flag-fall event disagreement.
  flagFallDisagreement,

  /// F-CLOCK-003 RESYNC_TIMEOUT: clock resync timed out.
  resyncTimeout,

  // ── §10.1 v5 — misc ────────────────────────────────────────────────────────
  /// F-XPORT-003 PERFECT_NEG_COLLISION_UNRESOLVED: role-negotiation collision.
  perfectNegCollisionUnresolved,

  /// F-SIG-007 OFFER_TOKEN_EXPIRED: offer token expired before use.
  offerTokenExpired,

  /// F-SIG-008 READ_ONLY_MODE_REJECTED_WRITE: write rejected in read-only mode.
  readOnlyModeRejectedWrite,

  /// F-SIG-009 REBIND_RACE_LOST: concurrent rebind race lost.
  rebindRaceLost,

  /// F-ID-008 KDF_VERSION_UNSUPPORTED: KDF version not supported.
  kdfVersionUnsupported,

  /// F-ID-009 BIP39_CHECKSUM_FAIL: BIP-39 mnemonic checksum failed.
  bip39ChecksumFail,

  /// F-ID-010 KDF_PARAMS_TOO_WEAK: KDF parameters below minimum strength.
  kdfParamsTooWeak,

  /// F-ID-011 XCHACHA_NONCE_REUSE_DETECTED: XChaCha20 nonce reuse detected.
  xchaChaNonceReuseDetected,

  /// F-INTEGRITY-001 STARTUP_INTEGRITY_FAIL: app integrity check failed at startup.
  startupIntegrityFail,

  /// F-WEB-003 WEB_PLATFORM_UNSUPPORTED_FEATURE: required feature unavailable.
  webPlatformUnsupportedFeature,

  /// F-DESKTOP-002 BIOMETRIC_NOT_AVAILABLE_DESKTOP: biometric not available on desktop.
  biometricNotAvailableDesktop,

  /// F-OBS-002 DIAG_LOG_DISK_FULL: diagnostic log disk full.
  diagLogDiskFull,

  /// F-OPS-001 KILL_SWITCH_ENGAGED: operator kill-switch activated.
  killSwitchEngaged,

  // ── §10.2 v6 — protocol (F-PROTO-016–022) ──────────────────────────────────
  /// F-PROTO-016 SEQ_CEILING_REACHED: sequence number ceiling reached.
  seqCeilingReached,

  /// F-PROTO-017 BYE_FRAGMENT_TIMEOUT: BYE fragment delivery timed out.
  byeFragmentTimeout,

  /// F-PROTO-018 BYE_FRAGMENT_OUT_OF_ORDER: BYE fragment arrived out of order.
  byeFragmentOutOfOrder,

  /// F-PROTO-019 BYE_FRAGMENT_OUT_OF_BOUNDS: BYE fragment index out of bounds.
  byeFragmentOutOfBounds,

  /// F-PROTO-020 FRAGMENT_NOT_ALLOWED: fragmentation not allowed for this message type.
  fragmentNotAllowed,

  /// F-PROTO-021 CRYPTO_SUITE_NOT_NEGOTIATED: crypto suite was not negotiated.
  cryptoSuiteNotNegotiated,

  /// F-PROTO-022 TRANSCRIPT_VERSION_UNSUPPORTED: transcript version unsupported.
  transcriptVersionUnsupported,

  // ── §10.2 v6 — misc ────────────────────────────────────────────────────────
  /// F-ID-012 KDF_DERIVATION_FAILED: key derivation failed.
  kdfDerivationFailed,

  /// F-ID-013 SECRET_ZEROISE_FAILED: could not securely erase secret material.
  secretZeroiseFailed,

  /// F-XPORT-004 DATACHANNEL_ID_COLLISION: data channel ID collision.
  datachannelIdCollision,

  /// F-XPORT-005 RESUMED_AS_NEW: channel resumed as a new session.
  resumedAsNew,

  /// F-CLOCK-004 MONOTONIC_CLOCK_UNAVAILABLE: monotonic clock unavailable.
  monotonicClockUnavailable,

  /// F-CLOCK-005 (v6) WALL_CLOCK_TAMPERED_DETECTED: wall-clock tampering detected.
  wallClockTamperedDetected,

  /// F-NET-008 (v6) METERED_NETWORK_USER_DECLINED: user declined metered network use.
  meteredNetworkUserDeclined,

  /// F-LIFECYCLE-005 OEM_BATTERY_OPT_BLOCKING: OEM battery optimisation blocking connection.
  oemBatteryOptBlocking,

  /// F-PUSH-005 APNS_SILENT_PUSH_DROPPED: APNs silent push dropped by OS.
  apnsSilentPushDropped,

  /// F-PUSH-006 FCM_TOKEN_REFRESHED: FCM token refreshed (informational).
  fcmTokenRefreshed,

  /// F-ID-014 RECOVERY_SCREEN_CAPTURED_DETECTED: screen capture detected on recovery screen.
  recoveryScreenCapturedDetected,

  /// F-CHAT-003 (v6) CHAT_BLOCKED_BY_USER: opponent has blocked you.
  chatBlockedByUser,

  /// F-CHAT-004 CHAT_REPORTED_AS_ABUSE: message reported as abuse.
  chatReportedAsAbuse,

  /// F-ONBOARD-001 AGE_GATE_BLOCKED: age gate check failed.
  ageGateBlocked,

  /// F-STORE-004 STORE_PRIVACY_MANIFEST_OUT_OF_DATE: App Store privacy manifest stale.
  storePrivacyManifestOutOfDate,

  /// F-SIG-010 DEVICE_CAP_EXCEEDED: per-user device cap exceeded.
  deviceCapExceeded,

  /// F-SIG-011 LONG_POLL_CAP_EXCEEDED: long-poll connection cap exceeded.
  longPollCapExceeded,

  /// F-SIG-012 SDP_TOO_LARGE: SDP offer/answer exceeds size limit.
  sdpTooLarge,

  /// F-SIG-013 SDP_FORBIDDEN_MEDIA_LINE: SDP contains disallowed media line.
  sdpForbiddenMediaLine,

  /// F-SPEC-001 SPECTATOR_CHAIN_REJECTED: spectator relay chain rejected.
  spectatorChainRejected,

  /// F-CONC-001 ISOLATE_CRASHED: Dart isolate crashed.
  isolateCrashed,

  /// F-CONC-002 SODIUM_INIT_FAILED: libsodium initialisation failed.
  sodiumInitFailed,

  // ── §10.3 v7 — storage (F-STORE-005–008) ───────────────────────────────────
  /// F-STORE-005 SQLCIPHER_KEY_UNWRAP_FAIL: SQLCipher key unwrap failed.
  sqlcipherKeyUnwrapFail,

  /// F-STORE-006 (v7) LOCAL_STORAGE_QUOTA_EXCEEDED: local storage quota exceeded.
  localStorageQuotaExceeded,

  /// F-STORE-007 (v7) LOCAL_STORAGE_AT_REST_BROKEN: at-rest encryption broken.
  localStorageAtRestBroken,

  /// F-STORE-008 BACKUP_ENCRYPTION_SALT_MISMATCH: backup encryption salt mismatch.
  backupEncryptionSaltMismatch,

  // ── §10.3 v7 — identity (F-ID-015–018) ────────────────────────────────────
  /// F-ID-015 KCI_VERIFY_FAILED: key compromise impersonation check failed.
  kciVerifyFailed,

  /// F-ID-016 SESSION_ID_COLLISION: session ID collision detected.
  sessionIdCollision,

  /// F-ID-017 SAFETY_NUMBERS_MISMATCH: safety numbers do not match.
  safetyNumbersMismatch,

  /// F-ID-018 RE_KEY_FAILED: session re-keying failed.
  reKeyFailed,

  // ── §10.3 v7 — protocol (F-PROTO-023–029) ──────────────────────────────────
  /// F-PROTO-023 CBOR_FLOAT_REJECTED: CBOR float type in payload rejected.
  cborFloatRejected,

  /// F-PROTO-024 HKDF_INFO_UNKNOWN: unknown HKDF info label.
  hkdfInfoUnknown,

  /// F-PROTO-025 OPPONENT_FINGERPRINT_DOWNGRADE_DETECTED: fingerprint downgrade attack.
  opponentFingerprintDowngradeDetected,

  /// F-PROTO-026 REPETITION_CLAIM_REJECTED: threefold-repetition claim rejected.
  repetitionClaimRejected,

  /// F-PROTO-027 DEPRECATED_WIRE_VERSION_REJECTED: deprecated wire version rejected.
  deprecatedWireVersionRejected,

  /// F-PROTO-028 DEPRECATED_CRYPTO_SUITE_REJECTED: deprecated crypto suite rejected.
  deprecatedCryptoSuiteRejected,

  /// F-PROTO-029 DEPRECATED_ENGINE_REPLAY_VERSION_REJECTED: deprecated replay version.
  deprecatedEngineReplayVersionRejected,

  // ── §10.3 v7 — misc ────────────────────────────────────────────────────────
  /// F-NET-009 TURNS_HANDSHAKE_FAILED: TURN-S TLS handshake failed.
  turnsHandshakeFailed,

  /// F-CLOCK-006 PREMOVE_INVALIDATED: premove invalidated by opponent's reply.
  premoveInvalidated,

  /// F-SIG-014 INVITE_LINK_EXPIRED: invite link has expired.
  inviteLinkExpired,

  /// F-SIG-015 INVITE_LINK_REPLAYED: invite link already used.
  inviteLinkReplayed,

  /// F-CHAT-005 HANDLE_IMPERSONATION_SUSPECTED: handle impersonation suspected.
  handleImpersonationSuspected,

  /// F-OBS-003 TRANSCRIPT_RAM_CAP_OVERFLOW: in-RAM transcript cap overflowed.
  transcriptRamCapOverflow,

  /// F-OPS-002 CVE_REQUIRES_FORCED_UPDATE: CVE requires forced app update.
  cveRequiresForcedUpdate,

  /// F-OPS-003 KEY_ROTATION_OVERDUE: scheduled key rotation overdue.
  keyRotationOverdue,

  /// F-OPS-004 BACKUP_RESTORE_DRILL_FAILED: backup restore drill failed.
  backupRestoreDrillFailed,

  /// F-OPS-005 OPERATOR_ON_CALL_UNREACHABLE: on-call operator unreachable.
  operatorOnCallUnreachable,

  // ── §10.4 v8 — protocol (F-PROTO-030–037) ──────────────────────────────────
  /// F-PROTO-030 VALIDATE_APPLY_RACE_DETECTED: validate/apply race condition.
  validateApplyRaceDetected,

  /// F-PROTO-031 FFI_FUZZ_FOUND_DIVERGENCE: fuzzer found state divergence.
  ffiFuzzFoundDivergence,

  /// F-PROTO-032 HELLO_TS_OUT_OF_WINDOW: HELLO timestamp outside allowed window.
  helloTsOutOfWindow,

  /// F-PROTO-033 SIGNED_TIME_FETCH_FAILED: signed time server fetch failed.
  signedTimeFetchFailed,

  /// F-PROTO-034 MULTI_DEVICE_RACE_LOST: multi-device session race lost.
  multiDeviceRaceLost,

  /// F-PROTO-035 CONFIG_BLOB_VERSION_UNSUPPORTED: config blob version unsupported.
  configBlobVersionUnsupported,

  /// F-PROTO-036 SPECTATOR_CHAIN_DEPTH_NONZERO_REJECTED: spectator chain depth rejected.
  spectatorChainDepthNonzeroRejected,

  /// F-PROTO-037 BACKFILL_OVERSIZE_REJECTED: backfill payload too large.
  backfillOversizeRejected,

  // ── §10.4 v8 — misc ────────────────────────────────────────────────────────
  /// F-START-001 STARTUP_SELF_TEST_FAIL: startup self-test failed.
  startupSelfTestFail,

  /// F-START-002 NATIVE_LIB_INTEGRITY_FAIL: native library integrity check failed.
  nativeLibIntegrityFail,

  /// F-PUSH-007 (v8) PUSH_COALESCED: push notification coalesced by OS.
  pushCoalesced,

  /// F-NET-010 (v8) TURN_BANDWIDTH_EXCEEDED: TURN relay bandwidth exceeded.
  turnBandwidthExceeded,

  /// F-NET-011 (v8) ICE_VPN_LEAK_USER_DECLINED: user declined VPN leak risk.
  iceVpnLeakUserDeclined,

  /// F-STORE-009 (v8) SCHEMA_SKIP_VERSION_FAIL: schema version skip not allowed.
  schemaSkipVersionFail,

  /// F-TEL-001 DP_BUDGET_EXCEEDED: differential-privacy budget exhausted.
  dpBudgetExceeded,

  /// F-TEL-002 TELEMETRY_ENVELOPE_VERSION_UNSUPPORTED: telemetry envelope version.
  telemetryEnvelopeVersionUnsupported,

  /// F-STUDY-001 STUDY_LOAD_VERSION_MISMATCH: study file version mismatch.
  studyLoadVersionMismatch,

  /// F-STUDY-002 EXPORT_SIDECAR_MISSING: export sidecar file missing.
  exportSidecarMissing,

  /// F-STUDY-003 STUDY_PGN_PARSE_FAIL: PGN parse failed in study mode.
  studyPgnParseFail,

  /// F-STUDY-004 STUDY_REPLAY_HASH_DIVERGENCE: replay hash mismatch in study.
  studyReplayHashDivergence,

  /// F-LIFE-005 BG_TASK_DENIED_BY_OS: background task denied by OS.
  bgTaskDeniedByOs,

  /// F-NET-012 LOAD_SHED_DROPPED: connection dropped due to server load shedding.
  loadShedDropped,

  /// F-CLOCK-007 (v8) RAGE_QUIT_FORFEIT_FIRED: rage-quit forfeit timer fired.
  rageQuitForfeitFired,

  /// F-STORE-010 (v8) LEGITIMATE_RESTORE_MERGE_DECLINED: user declined merge on restore.
  legitimateRestoreMergeDeclined,

  /// F-CHAT-006 (v8) REPORT_TARGET_RATE_LIMITED: report action rate limited.
  reportTargetRateLimited,

  // ── §10.5 v9 — spectator (F-SPEC-002–015) ──────────────────────────────────
  /// F-SPEC-002 SPECTATOR_CAPACITY_FULL: spectator capacity reached.
  spectatorCapacityFull,

  /// F-SPEC-003 SPECTATOR_WAITLIST_EXPIRED: spectator waitlist entry expired.
  spectatorWaitlistExpired,

  /// F-SPEC-004 SPECTATOR_AUTH_REQUIRED: authentication required to spectate.
  spectatorAuthRequired,

  /// F-SPEC-005 SPECTATOR_JOIN_RATE_LIMITED: spectator join rate limited.
  spectatorJoinRateLimited,

  /// F-SPEC-006 SPECTATOR_KICKED: spectator was kicked by host.
  spectatorKicked,

  /// F-SPEC-007 SPECTATOR_BANNED: spectator is banned.
  spectatorBanned,

  /// F-SPEC-008 SPECTATOR_MUTED: spectator is muted by host.
  spectatorMuted,

  /// F-SPEC-009 SPECTATOR_GLOBALLY_MUTED: spectator is globally muted.
  spectatorGloballyMuted,

  /// F-SPEC-010 SPECTATOR_SHED_FOR_PERF: spectator dropped for performance.
  spectatorShedForPerf,

  /// F-SPEC-011 SPECTATOR_RELAY_UNAVAILABLE: spectator relay unavailable.
  spectatorRelayUnavailable,

  /// F-SPEC-012 BACKFILL_QUEUE_OVERFLOW: spectator backfill queue overflowed.
  backfillQueueOverflow,

  /// F-SPEC-013 SPECTATOR_HEARTBEAT_TIMEOUT: spectator heartbeat timed out.
  spectatorHeartbeatTimeout,

  /// F-SPEC-014 SPECTATOR_KEY_ROTATION_REQUIRED: spectator key rotation required.
  spectatorKeyRotationRequired,

  /// F-SPEC-015 SPECTATOR_DATACHANNEL_BACKPRESSURE: spectator data channel backpressure.
  spectatorDatachannelBackpressure,

  // ── §10.5 v9 — chat (F-CHAT-007–017) ───────────────────────────────────────
  /// F-CHAT-007 CHAT_RATE_LIMITED: chat rate limited by server.
  chatRateLimited,

  /// F-CHAT-008 CHAT_MESSAGE_OVERSIZED: chat message too long.
  chatMessageOversized,

  /// F-CHAT-009 CHAT_SLOW_MODE_ACTIVE: chat slow mode is active.
  chatSlowModeActive,

  /// F-CHAT-010 CHAT_AUTO_THROTTLED_CLOCK_PRESSURE: chat throttled due to clock pressure.
  chatAutoThrottledClockPressure,

  /// F-CHAT-011 CHAT_RECEIVER_OVERFLOW: chat receiver queue overflowed.
  chatReceiverOverflow,

  /// F-CHAT-012 CHAT_REPORT_FILED: a chat report was filed.
  chatReportFiled,

  /// F-CHAT-013 CHAT_TOURNAMENT_LOCKED: chat locked during tournament.
  chatTournamentLocked,

  /// F-CHAT-014 CHAT_HOST_BROADCAST_DROPPED_LOW_PRIORITY: host broadcast dropped.
  chatHostBroadcastDroppedLowPriority,

  /// F-CHAT-015 CHAT_DECODE_ERROR_DISCARDED: chat frame decode error, discarded.
  chatDecodeErrorDiscarded,

  /// F-CHAT-016 CHAT_NFC_NORMALISATION_FAIL: NFC normalisation of chat text failed.
  chatNfcNormalisationFail,

  /// F-CHAT-017 CHAT_HOMOGLYPH_BLOCKED: chat message blocked for homoglyph abuse.
  chatHomoglyphBlocked,
}

// ─── helpers ─────────────────────────────────────────────────────────────────

/// Returns the English user-visible message for [code].
///
/// Used directly in the UI and mirrored as an ARB key in `app_en.arb`.
// ignore: long-method
String p2pFailureMessage(P2PFailureCode code) {
  switch (code) {
    // §10.0 protocol
    case P2PFailureCode.badFrame:
      return 'Connection error — please try again.';
    case P2PFailureCode.badVersion:
      return 'Please update the app to connect to this game.';
    case P2PFailureCode.outOfSequence:
      return 'Move arrived out of order. Reconnecting…';
    case P2PFailureCode.illegalMove:
      return 'An illegal move was detected. The game cannot continue.';
    case P2PFailureCode.modMismatch:
      return 'Mod mismatch — both players must choose the same game variant.';
    case P2PFailureCode.clockStarvation:
      return 'Clock sync lost. The game is paused.';
    case P2PFailureCode.backpressureDrop:
      return 'Network congested — some messages were dropped.';
    case P2PFailureCode.mismatch:
      return 'Game state mismatch. Please restart the game.';
    // §10.0 network
    case P2PFailureCode.iceFailed:
      return 'Could not establish a connection. Please try again.';
    case P2PFailureCode.iceDisconnected:
      return 'Connection lost. Attempting to reconnect…';
    case P2PFailureCode.networkLost:
      return 'No internet connection. Please check your network.';
    case P2PFailureCode.turnUnavailable:
      return 'Relay server unavailable. Try again later.';
    case P2PFailureCode.captivePortal:
      return 'A sign-in page is blocking the connection. Open your browser.';
    case P2PFailureCode.natHardBlock:
      return 'Your network blocks peer connections. Use a different network.';
    case P2PFailureCode.ipv6PmtuBlackHole:
      return 'Network path issue detected. Switching to backup route.';
    // §10.0 transport
    case P2PFailureCode.datachannelClosedUnexpectedly:
      return 'Connection channel closed unexpectedly. Reconnecting…';
    case P2PFailureCode.sctpHandshakeTimeout:
      return 'Connection timed out. Please try again.';
    // §10.0 signaling
    case P2PFailureCode.signaling5xx:
      return 'Server error. Please try again in a moment.';
    case P2PFailureCode.signalingRateLimited:
      return 'Too many requests. Please wait a moment and try again.';
    case P2PFailureCode.signalingPowRequired:
      return 'Verifying you\'re human… this may take a moment.';
    case P2PFailureCode.offerExpired:
      return 'This invite link has expired. Ask your opponent for a new one.';
    case P2PFailureCode.offerDuplicateAnswer:
      return 'Someone already joined this game. Ask for a new invite.';
    case P2PFailureCode.adminDisabled:
      return 'This feature has been temporarily disabled.';
    // §10.0 identity
    case P2PFailureCode.keyGenFailed:
      return 'Could not create your identity. Please restart the app.';
    case P2PFailureCode.keyStorageUnavailable:
      return 'Secure storage is unavailable on this device.';
    case P2PFailureCode.biometricLockout:
      return 'Biometric authentication is locked. Use your PIN instead.';
    case P2PFailureCode.recoveryBadCode:
      return 'Invalid recovery words. Please check them and try again.';
    case P2PFailureCode.recoveryParamMismatch:
      return 'Recovery failed — parameters do not match your backup.';
    case P2PFailureCode.rebindAttestationFailed:
      return 'Device verification failed. Please contact support.';
    case P2PFailureCode.oldDeviceRejectedAfterRebind:
      return 'Your old device has been revoked. Use your new device.';
    // §10.0 push
    case P2PFailureCode.pushTokenInvalid:
      return 'Push notifications unavailable. Check app notification settings.';
    case P2PFailureCode.pushProviderDown:
      return 'Push service temporarily unavailable. Direct connection in use.';
    case P2PFailureCode.pushDeferredByOs:
      return 'Invite notification delayed by your device.';
    case P2PFailureCode.pushReceivedNoOffer:
      return 'Invite notification arrived but the offer was not found.';
    // §10.0 lifecycle
    case P2PFailureCode.appSuspendedMidHandshake:
      return 'App was backgrounded during connection. Please try again.';
    case P2PFailureCode.foregroundServiceKilled:
      return 'Background service was stopped. Game cannot continue.';
    case P2PFailureCode.iosNseTimeout:
      return 'Notification handler timed out. Reopen the app to reconnect.';
    case P2PFailureCode.deepLinkColdStartLost:
      return 'Invite link was lost on app start. Ask for a new invite.';
    // §10.0 storage
    case P2PFailureCode.savedGamesDbCorrupt:
      return 'Saved games database is corrupted. Games may be lost.';
    case P2PFailureCode.savedGamesMigrationFailed:
      return 'Could not upgrade saved games. Please reinstall the app.';
    case P2PFailureCode.diskFull:
      return 'Your device storage is full. Please free up space.';
    // §10.0 web/desktop/misc
    case P2PFailureCode.webrtcNotSupported:
      return 'Your browser does not support peer connections. Use a modern browser.';
    case P2PFailureCode.webcryptoNonExtractableLimit:
      return 'Browser security policy prevents key export. Use the app.';
    case P2PFailureCode.libsecretUnavailable:
      return 'System keychain is unavailable. Enable it and try again.';
    case P2PFailureCode.telemetryQueueOverflow:
      return 'Diagnostics buffer full. Some telemetry will be dropped.';
    case P2PFailureCode.chatFrameTooLarge:
      return 'Message too long. Please shorten it and try again.';
    case P2PFailureCode.chatRateLimitLocal:
      return 'Sending too fast. Please slow down.';
    case P2PFailureCode.lamportConflict:
      return 'Clock conflict on join. Reconnecting…';
    case P2PFailureCode.forensicBundleWriteFailed:
      return 'Could not save game report.';
    // §10.1 v5 protocol
    case P2PFailureCode.wireVersionMismatch:
      return 'Protocol version mismatch. Please update the app.';
    case P2PFailureCode.engineVersionMismatch:
      return 'Engine version mismatch. Both players must use the same app version.';
    case P2PFailureCode.modConfigRejected:
      return 'Game configuration rejected by your opponent.';
    case P2PFailureCode.timeControlRejected:
      return 'Time control rejected. Please agree on a time control and retry.';
    case P2PFailureCode.colorFlipRevealMismatch:
      return 'Color assignment failed. Please restart the game.';
    case P2PFailureCode.transcriptSignFailed:
      return 'Could not sign game transcript. Result may not be recorded.';
    case P2PFailureCode.byeDisagreement:
      return 'Could not agree on game end reason.';
    // §10.1 v5 clock
    case P2PFailureCode.clockDesyncBeyondBudget:
      return 'Clocks have drifted too far apart. Game paused for resync.';
    case P2PFailureCode.flagFallDisagreement:
      return 'Time flag disagreement detected. Seeking resolution…';
    case P2PFailureCode.resyncTimeout:
      return 'Clock resync timed out. Game ended.';
    // §10.1 v5 misc
    case P2PFailureCode.perfectNegCollisionUnresolved:
      return 'Connection role collision. Please retry.';
    case P2PFailureCode.offerTokenExpired:
      return 'Invite token has expired. Request a new invite.';
    case P2PFailureCode.readOnlyModeRejectedWrite:
      return 'Server is in read-only mode. Try again shortly.';
    case P2PFailureCode.rebindRaceLost:
      return 'Another device completed login first. Try again.';
    case P2PFailureCode.kdfVersionUnsupported:
      return 'Identity format not supported. Please update the app.';
    case P2PFailureCode.bip39ChecksumFail:
      return 'Recovery words are invalid. Check each word carefully.';
    case P2PFailureCode.kdfParamsTooWeak:
      return 'Security parameters below minimum. Please re-create your identity.';
    case P2PFailureCode.xchaChaNonceReuseDetected:
      return 'Critical security error detected. Session terminated.';
    case P2PFailureCode.startupIntegrityFail:
      return 'App integrity check failed. Please reinstall the app.';
    case P2PFailureCode.webPlatformUnsupportedFeature:
      return 'A required feature is unavailable in this browser. Use the app.';
    case P2PFailureCode.biometricNotAvailableDesktop:
      return 'Biometric authentication is not available on this device.';
    case P2PFailureCode.diagLogDiskFull:
      return 'Diagnostic log storage full. Oldest logs will be overwritten.';
    case P2PFailureCode.killSwitchEngaged:
      return 'This feature has been remotely disabled. Please update the app.';
    // §10.2 v6 protocol
    case P2PFailureCode.seqCeilingReached:
      return 'Message sequence limit reached. Game ended.';
    case P2PFailureCode.byeFragmentTimeout:
      return 'End-of-game handshake timed out.';
    case P2PFailureCode.byeFragmentOutOfOrder:
      return 'End-of-game fragment arrived out of order.';
    case P2PFailureCode.byeFragmentOutOfBounds:
      return 'End-of-game fragment index invalid.';
    case P2PFailureCode.fragmentNotAllowed:
      return 'Message fragmentation not permitted for this message type.';
    case P2PFailureCode.cryptoSuiteNotNegotiated:
      return 'Encryption suite could not be agreed upon. Please reconnect.';
    case P2PFailureCode.transcriptVersionUnsupported:
      return 'Game transcript format not supported. Please update the app.';
    // §10.2 v6 misc
    case P2PFailureCode.kdfDerivationFailed:
      return 'Key derivation failed. Please try again.';
    case P2PFailureCode.secretZeroiseFailed:
      return 'Critical security error: secrets could not be cleared.';
    case P2PFailureCode.datachannelIdCollision:
      return 'Channel ID conflict. Reconnecting…';
    case P2PFailureCode.resumedAsNew:
      return 'Session resumed as a new connection.';
    case P2PFailureCode.monotonicClockUnavailable:
      return 'Device clock is unreliable. Game clock may be inaccurate.';
    case P2PFailureCode.wallClockTamperedDetected:
      return 'Device clock anomaly detected.';
    case P2PFailureCode.meteredNetworkUserDeclined:
      return 'Connection cancelled — metered network use was declined.';
    case P2PFailureCode.oemBatteryOptBlocking:
      return 'Battery optimisation is blocking the connection. Disable it for this app.';
    case P2PFailureCode.apnsSilentPushDropped:
      return 'Invite notification was suppressed by your device.';
    case P2PFailureCode.fcmTokenRefreshed:
      return 'Notification token refreshed.';
    case P2PFailureCode.recoveryScreenCapturedDetected:
      return 'Screen capture detected. Close the screenshot tool and try again.';
    case P2PFailureCode.chatBlockedByUser:
      return 'You cannot send messages to this player.';
    case P2PFailureCode.chatReportedAsAbuse:
      return 'Your message was reported. Chat has been paused.';
    case P2PFailureCode.ageGateBlocked:
      return 'You must meet the age requirement to use this feature.';
    case P2PFailureCode.storePrivacyManifestOutOfDate:
      return 'App store privacy manifest is out of date. Update required.';
    case P2PFailureCode.deviceCapExceeded:
      return 'Maximum number of devices reached. Remove a device to continue.';
    case P2PFailureCode.longPollCapExceeded:
      return 'Too many open connections. Please close other sessions.';
    case P2PFailureCode.sdpTooLarge:
      return 'Connection description too large. Please try a different network.';
    case P2PFailureCode.sdpForbiddenMediaLine:
      return 'Connection description contains disallowed content.';
    case P2PFailureCode.spectatorChainRejected:
      return 'Could not join as spectator — chain rejected.';
    case P2PFailureCode.isolateCrashed:
      return 'A background process crashed. Please restart the app.';
    case P2PFailureCode.sodiumInitFailed:
      return 'Encryption library failed to initialise. Please reinstall the app.';
    // §10.3 v7 storage
    case P2PFailureCode.sqlcipherKeyUnwrapFail:
      return 'Database decryption failed. Your recovery words may be needed.';
    case P2PFailureCode.localStorageQuotaExceeded:
      return 'Local storage quota exceeded. Free up space and try again.';
    case P2PFailureCode.localStorageAtRestBroken:
      return 'Stored data is no longer accessible. Recovery may be needed.';
    case P2PFailureCode.backupEncryptionSaltMismatch:
      return 'Backup encryption mismatch. This backup cannot be restored.';
    // §10.3 v7 identity
    case P2PFailureCode.kciVerifyFailed:
      return 'Identity verification failed. Possible impersonation attempt.';
    case P2PFailureCode.sessionIdCollision:
      return 'Critical error: duplicate session ID detected.';
    case P2PFailureCode.safetyNumbersMismatch:
      return 'Safety numbers do not match. Do not continue until verified.';
    case P2PFailureCode.reKeyFailed:
      return 'Session key rotation failed. Please reconnect.';
    // §10.3 v7 protocol
    case P2PFailureCode.cborFloatRejected:
      return 'Invalid message format received. Please update the app.';
    case P2PFailureCode.hkdfInfoUnknown:
      return 'Unknown cryptographic context label. Please update the app.';
    case P2PFailureCode.opponentFingerprintDowngradeDetected:
      return 'Security downgrade detected. Connection refused for your safety.';
    case P2PFailureCode.repetitionClaimRejected:
      return 'Threefold-repetition draw claim rejected by opponent.';
    case P2PFailureCode.deprecatedWireVersionRejected:
      return 'Your app uses an outdated protocol. Please update.';
    case P2PFailureCode.deprecatedCryptoSuiteRejected:
      return 'Your app uses a deprecated security suite. Please update.';
    case P2PFailureCode.deprecatedEngineReplayVersionRejected:
      return 'Replay format is outdated. Please update the app.';
    // §10.3 v7 misc
    case P2PFailureCode.turnsHandshakeFailed:
      return 'Encrypted relay handshake failed. Trying another server…';
    case P2PFailureCode.premoveInvalidated:
      return 'Your premove was invalidated by the opponent\'s reply.';
    case P2PFailureCode.inviteLinkExpired:
      return 'This invite link has expired. Ask for a new one.';
    case P2PFailureCode.inviteLinkReplayed:
      return 'This invite link has already been used.';
    case P2PFailureCode.handleImpersonationSuspected:
      return 'This player\'s handle looks suspicious. Verify before continuing.';
    case P2PFailureCode.transcriptRamCapOverflow:
      return 'Game history too large for memory. Saving to disk.';
    case P2PFailureCode.cveRequiresForcedUpdate:
      return 'A security update is required. Please update the app now.';
    case P2PFailureCode.keyRotationOverdue:
      return 'Security key rotation is overdue. Please open the app.';
    case P2PFailureCode.backupRestoreDrillFailed:
      return 'Backup restore test failed. Check your recovery words.';
    case P2PFailureCode.operatorOnCallUnreachable:
      return 'Unable to reach on-call support. Try again later.';
    // §10.4 v8 protocol
    case P2PFailureCode.validateApplyRaceDetected:
      return 'Critical game engine race condition detected.';
    case P2PFailureCode.ffiFuzzFoundDivergence:
      return 'Engine state divergence detected. Game ended.';
    case P2PFailureCode.helloTsOutOfWindow:
      return 'Connection timestamp outside allowed window. Check your device clock.';
    case P2PFailureCode.signedTimeFetchFailed:
      return 'Could not fetch trusted time. Check your connection.';
    case P2PFailureCode.multiDeviceRaceLost:
      return 'Another device connected first. Close this session and try again.';
    case P2PFailureCode.configBlobVersionUnsupported:
      return 'Configuration format not supported. Please update the app.';
    case P2PFailureCode.spectatorChainDepthNonzeroRejected:
      return 'Spectator chain depth not permitted.';
    case P2PFailureCode.backfillOversizeRejected:
      return 'Game history too large for spectator join.';
    // §10.4 v8 misc
    case P2PFailureCode.startupSelfTestFail:
      return 'App startup self-test failed. Please reinstall.';
    case P2PFailureCode.nativeLibIntegrityFail:
      return 'Game engine integrity check failed. Please reinstall.';
    case P2PFailureCode.pushCoalesced:
      return 'Some invite notifications were grouped by your device.';
    case P2PFailureCode.turnBandwidthExceeded:
      return 'Relay bandwidth limit reached. Connection degraded.';
    case P2PFailureCode.iceVpnLeakUserDeclined:
      return 'Connection cancelled — VPN leak risk was declined.';
    case P2PFailureCode.schemaSkipVersionFail:
      return 'Database upgrade path not supported. Please reinstall.';
    case P2PFailureCode.dpBudgetExceeded:
      return 'Analytics privacy budget exhausted. Some data will not be sent.';
    case P2PFailureCode.telemetryEnvelopeVersionUnsupported:
      return 'Diagnostics format not supported. Please update the app.';
    case P2PFailureCode.studyLoadVersionMismatch:
      return 'Study file format is from a newer version of the app.';
    case P2PFailureCode.exportSidecarMissing:
      return 'Export file is incomplete — sidecar missing.';
    case P2PFailureCode.studyPgnParseFail:
      return 'Could not parse the PGN file. Check the file format.';
    case P2PFailureCode.studyReplayHashDivergence:
      return 'Study replay verification failed. The file may be corrupted.';
    case P2PFailureCode.bgTaskDeniedByOs:
      return 'Background task was denied by your device. Enable background activity.';
    case P2PFailureCode.loadShedDropped:
      return 'Server is busy. Your connection was temporarily dropped.';
    case P2PFailureCode.rageQuitForfeitFired:
      return 'Forfeit timer has fired due to inactivity.';
    case P2PFailureCode.legitimateRestoreMergeDeclined:
      return 'Game data merge was declined. Restore cancelled.';
    case P2PFailureCode.reportTargetRateLimited:
      return 'You have filed too many reports recently. Try again later.';
    // §10.5 v9 spectator
    case P2PFailureCode.spectatorCapacityFull:
      return 'Spectator capacity is full for this game.';
    case P2PFailureCode.spectatorWaitlistExpired:
      return 'Your spot on the spectator waitlist has expired.';
    case P2PFailureCode.spectatorAuthRequired:
      return 'You must sign in to spectate this game.';
    case P2PFailureCode.spectatorJoinRateLimited:
      return 'Too many spectators joining at once. Please try again shortly.';
    case P2PFailureCode.spectatorKicked:
      return 'You were removed from spectating this game.';
    case P2PFailureCode.spectatorBanned:
      return 'You are banned from spectating this game.';
    case P2PFailureCode.spectatorMuted:
      return 'Your spectator chat has been muted by the host.';
    case P2PFailureCode.spectatorGloballyMuted:
      return 'Your chat access has been globally restricted.';
    case P2PFailureCode.spectatorShedForPerf:
      return 'Spectator connection dropped to maintain game performance.';
    case P2PFailureCode.spectatorRelayUnavailable:
      return 'Spectator relay is unavailable. Try again later.';
    case P2PFailureCode.backfillQueueOverflow:
      return 'Game history queue full. Some moves may not be shown.';
    case P2PFailureCode.spectatorHeartbeatTimeout:
      return 'Spectator connection timed out.';
    case P2PFailureCode.spectatorKeyRotationRequired:
      return 'Spectator key rotation required. Reconnecting…';
    case P2PFailureCode.spectatorDatachannelBackpressure:
      return 'Spectator data channel is congested. Moves may be delayed.';
    // §10.5 v9 chat
    case P2PFailureCode.chatRateLimited:
      return 'Chat rate limit reached. Please wait before sending more messages.';
    case P2PFailureCode.chatMessageOversized:
      return 'Message is too long. Please shorten it.';
    case P2PFailureCode.chatSlowModeActive:
      return 'Slow mode is active. You can send one message every few seconds.';
    case P2PFailureCode.chatAutoThrottledClockPressure:
      return 'Chat paused — game clock is under pressure.';
    case P2PFailureCode.chatReceiverOverflow:
      return 'Chat inbox full — some messages may have been dropped.';
    case P2PFailureCode.chatReportFiled:
      return 'Report submitted. Thank you.';
    case P2PFailureCode.chatTournamentLocked:
      return 'Chat is locked during this tournament.';
    case P2PFailureCode.chatHostBroadcastDroppedLowPriority:
      return 'Host broadcast message was dropped due to low priority.';
    case P2PFailureCode.chatDecodeErrorDiscarded:
      return 'A chat message could not be decoded and was discarded.';
    case P2PFailureCode.chatNfcNormalisationFail:
      return 'Message contains characters that could not be normalised.';
    case P2PFailureCode.chatHomoglyphBlocked:
      return 'Message blocked — it appears to use deceptive lookalike characters.';
  }
}

/// Returns the English recovery-hint text for [code].
///
/// Mirrored as an ARB key in `app_en.arb`.
// ignore: long-method
String p2pFailureRecovery(P2PFailureCode code) {
  switch (code) {
    // §10.0 protocol
    case P2PFailureCode.badFrame:
      return 'Restart the game or check your connection.';
    case P2PFailureCode.badVersion:
      return 'Update the app from the store and try again.';
    case P2PFailureCode.outOfSequence:
      return 'Wait for the reconnect to complete.';
    case P2PFailureCode.illegalMove:
      return 'Contact support if this happens repeatedly.';
    case P2PFailureCode.modMismatch:
      return 'Both players must select the same mod in the lobby.';
    case P2PFailureCode.clockStarvation:
      return 'Check your connection. The game will resume when clocks sync.';
    case P2PFailureCode.backpressureDrop:
      return 'Move to a better network if possible.';
    case P2PFailureCode.mismatch:
      return 'Restart the game. If this persists, reinstall the app.';
    // §10.0 network
    case P2PFailureCode.iceFailed:
      return 'Check your internet connection and firewall settings.';
    case P2PFailureCode.iceDisconnected:
      return 'Wait for automatic reconnect, or restart the game.';
    case P2PFailureCode.networkLost:
      return 'Reconnect to Wi-Fi or mobile data.';
    case P2PFailureCode.turnUnavailable:
      return 'Try again in a few minutes.';
    case P2PFailureCode.captivePortal:
      return 'Open a browser, sign in to the network, then return to the app.';
    case P2PFailureCode.natHardBlock:
      return 'Try a different Wi-Fi network or mobile data.';
    case P2PFailureCode.ipv6PmtuBlackHole:
      return 'The app will retry automatically. No action needed.';
    // §10.0 transport
    case P2PFailureCode.datachannelClosedUnexpectedly:
      return 'Wait for automatic reconnect.';
    case P2PFailureCode.sctpHandshakeTimeout:
      return 'Check your connection and try again.';
    // §10.0 signaling
    case P2PFailureCode.signaling5xx:
      return 'Wait a moment then retry.';
    case P2PFailureCode.signalingRateLimited:
      return 'Wait 60 seconds before retrying.';
    case P2PFailureCode.signalingPowRequired:
      return 'No action needed — the app will complete verification automatically.';
    case P2PFailureCode.offerExpired:
      return 'Ask your opponent to share a new invite link.';
    case P2PFailureCode.offerDuplicateAnswer:
      return 'Ask your opponent to create a new game.';
    case P2PFailureCode.adminDisabled:
      return 'Check for an app update or try again later.';
    // §10.0 identity
    case P2PFailureCode.keyGenFailed:
      return 'Restart the app. If the issue persists, reinstall.';
    case P2PFailureCode.keyStorageUnavailable:
      return 'Enable device lock screen and try again.';
    case P2PFailureCode.biometricLockout:
      return 'Use your PIN or password to unlock.';
    case P2PFailureCode.recoveryBadCode:
      return 'Re-enter your recovery words carefully in order.';
    case P2PFailureCode.recoveryParamMismatch:
      return 'Use the same app version that created the backup.';
    case P2PFailureCode.rebindAttestationFailed:
      return 'Contact support with your user ID.';
    case P2PFailureCode.oldDeviceRejectedAfterRebind:
      return 'Sign in on your new device.';
    // §10.0 push
    case P2PFailureCode.pushTokenInvalid:
      return 'Enable notifications for the app in system settings.';
    case P2PFailureCode.pushProviderDown:
      return 'Share the invite link directly.';
    case P2PFailureCode.pushDeferredByOs:
      return 'Check your notification settings and try again.';
    case P2PFailureCode.pushReceivedNoOffer:
      return 'Ask your opponent to resend the invite.';
    // §10.0 lifecycle
    case P2PFailureCode.appSuspendedMidHandshake:
      return 'Keep the app in the foreground during connection.';
    case P2PFailureCode.foregroundServiceKilled:
      return 'Disable battery optimisation for this app.';
    case P2PFailureCode.iosNseTimeout:
      return 'Tap the notification to open the app and reconnect.';
    case P2PFailureCode.deepLinkColdStartLost:
      return 'Ask your opponent for a fresh invite.';
    // §10.0 storage
    case P2PFailureCode.savedGamesDbCorrupt:
      return 'Reinstall the app to rebuild the database.';
    case P2PFailureCode.savedGamesMigrationFailed:
      return 'Reinstall the app. Old saved games may be lost.';
    case P2PFailureCode.diskFull:
      return 'Delete unused apps or files and try again.';
    // §10.0 web/desktop/misc
    case P2PFailureCode.webrtcNotSupported:
      return 'Use Chrome, Firefox, or Safari — or download the mobile app.';
    case P2PFailureCode.webcryptoNonExtractableLimit:
      return 'Download the mobile app for full functionality.';
    case P2PFailureCode.libsecretUnavailable:
      return 'Install and start a keychain service (e.g. GNOME Keyring).';
    case P2PFailureCode.telemetryQueueOverflow:
      return 'No action needed.';
    case P2PFailureCode.chatFrameTooLarge:
      return 'Keep messages under 500 characters.';
    case P2PFailureCode.chatRateLimitLocal:
      return 'Wait a second between messages.';
    case P2PFailureCode.lamportConflict:
      return 'The app will resolve this automatically. Wait a moment.';
    case P2PFailureCode.forensicBundleWriteFailed:
      return 'Check device storage space.';
    // §10.1 v5 protocol
    case P2PFailureCode.wireVersionMismatch:
      return 'Both players must use the same app version.';
    case P2PFailureCode.engineVersionMismatch:
      return 'Both players should update to the latest version.';
    case P2PFailureCode.modConfigRejected:
      return 'Confirm configuration settings with your opponent.';
    case P2PFailureCode.timeControlRejected:
      return 'Select the same time control and retry.';
    case P2PFailureCode.colorFlipRevealMismatch:
      return 'Start a new game.';
    case P2PFailureCode.transcriptSignFailed:
      return 'The game was played but may not be saved. Check storage.';
    case P2PFailureCode.byeDisagreement:
      return 'The result will be reviewed. No action needed.';
    // §10.1 v5 clock
    case P2PFailureCode.clockDesyncBeyondBudget:
      return 'Wait for the app to resync clocks automatically.';
    case P2PFailureCode.flagFallDisagreement:
      return 'The result is under review.';
    case P2PFailureCode.resyncTimeout:
      return 'Start a new game.';
    // §10.1 v5 misc
    case P2PFailureCode.perfectNegCollisionUnresolved:
      return 'Tap Retry to reconnect.';
    case P2PFailureCode.offerTokenExpired:
      return 'Request a new invite from your opponent.';
    case P2PFailureCode.readOnlyModeRejectedWrite:
      return 'Try again in a few minutes.';
    case P2PFailureCode.rebindRaceLost:
      return 'Try again on this device.';
    case P2PFailureCode.kdfVersionUnsupported:
      return 'Update to the latest app version.';
    case P2PFailureCode.bip39ChecksumFail:
      return 'Re-enter each word exactly as written.';
    case P2PFailureCode.kdfParamsTooWeak:
      return 'Delete and re-create your identity with the latest app.';
    case P2PFailureCode.xchaChaNonceReuseDetected:
      return 'Reinstall the app immediately.';
    case P2PFailureCode.startupIntegrityFail:
      return 'Download a fresh copy of the app from the official store.';
    case P2PFailureCode.webPlatformUnsupportedFeature:
      return 'Switch to the latest Chrome, Firefox, or Safari.';
    case P2PFailureCode.biometricNotAvailableDesktop:
      return 'Use your password to authenticate.';
    case P2PFailureCode.diagLogDiskFull:
      return 'Free up device storage.';
    case P2PFailureCode.killSwitchEngaged:
      return 'Update the app and try again.';
    // §10.2 v6 protocol
    case P2PFailureCode.seqCeilingReached:
      return 'Start a new game.';
    case P2PFailureCode.byeFragmentTimeout:
      return 'The game result is saved. Start a new game.';
    case P2PFailureCode.byeFragmentOutOfOrder:
      return 'Wait for the app to resolve this automatically.';
    case P2PFailureCode.byeFragmentOutOfBounds:
      return 'Update the app.';
    case P2PFailureCode.fragmentNotAllowed:
      return 'Update the app.';
    case P2PFailureCode.cryptoSuiteNotNegotiated:
      return 'Both players must use the same app version.';
    case P2PFailureCode.transcriptVersionUnsupported:
      return 'Update the app to the latest version.';
    // §10.2 v6 misc
    case P2PFailureCode.kdfDerivationFailed:
      return 'Restart the app and try again.';
    case P2PFailureCode.secretZeroiseFailed:
      return 'Reinstall the app immediately.';
    case P2PFailureCode.datachannelIdCollision:
      return 'The app will reconnect automatically.';
    case P2PFailureCode.resumedAsNew:
      return 'Continue playing normally.';
    case P2PFailureCode.monotonicClockUnavailable:
      return 'Avoid modifying the system clock while playing.';
    case P2PFailureCode.wallClockTamperedDetected:
      return 'Set your device clock to the correct time.';
    case P2PFailureCode.meteredNetworkUserDeclined:
      return 'Connect to Wi-Fi or enable mobile data usage for this app.';
    case P2PFailureCode.oemBatteryOptBlocking:
      return 'Go to Settings → Battery → disable optimisation for this app.';
    case P2PFailureCode.apnsSilentPushDropped:
      return 'Enable background app refresh in iOS Settings.';
    case P2PFailureCode.fcmTokenRefreshed:
      return 'No action needed.';
    case P2PFailureCode.recoveryScreenCapturedDetected:
      return 'Close any screenshot or screen-recording tools.';
    case P2PFailureCode.chatBlockedByUser:
      return 'No action needed.';
    case P2PFailureCode.chatReportedAsAbuse:
      return 'Review the community guidelines.';
    case P2PFailureCode.ageGateBlocked:
      return 'No action available.';
    case P2PFailureCode.storePrivacyManifestOutOfDate:
      return 'Update the app from the App Store.';
    case P2PFailureCode.deviceCapExceeded:
      return 'Remove an old device from your account settings.';
    case P2PFailureCode.longPollCapExceeded:
      return 'Close other sessions or browser tabs.';
    case P2PFailureCode.sdpTooLarge:
      return 'Disable VPN or browser extensions and try again.';
    case P2PFailureCode.sdpForbiddenMediaLine:
      return 'Update the app or contact support.';
    case P2PFailureCode.spectatorChainRejected:
      return 'Try rejoining as a spectator.';
    case P2PFailureCode.isolateCrashed:
      return 'Restart the app.';
    case P2PFailureCode.sodiumInitFailed:
      return 'Reinstall the app from the official store.';
    // §10.3 v7 storage
    case P2PFailureCode.sqlcipherKeyUnwrapFail:
      return 'Use your recovery words to restore access.';
    case P2PFailureCode.localStorageQuotaExceeded:
      return 'Delete unused files and clear app cache.';
    case P2PFailureCode.localStorageAtRestBroken:
      return 'Reinstall the app and restore from backup.';
    case P2PFailureCode.backupEncryptionSaltMismatch:
      return 'Use a backup created on the same device.';
    // §10.3 v7 identity
    case P2PFailureCode.kciVerifyFailed:
      return 'Verify your opponent\'s identity out-of-band before continuing.';
    case P2PFailureCode.sessionIdCollision:
      return 'Restart the app immediately.';
    case P2PFailureCode.safetyNumbersMismatch:
      return 'Confirm safety numbers with your opponent via a separate channel.';
    case P2PFailureCode.reKeyFailed:
      return 'Reconnect to the game.';
    // §10.3 v7 protocol
    case P2PFailureCode.cborFloatRejected:
      return 'Update the app.';
    case P2PFailureCode.hkdfInfoUnknown:
      return 'Update the app to the latest version.';
    case P2PFailureCode.opponentFingerprintDowngradeDetected:
      return 'Do not reconnect. Report to support.';
    case P2PFailureCode.repetitionClaimRejected:
      return 'The game will continue. You may appeal the result after.';
    case P2PFailureCode.deprecatedWireVersionRejected:
      return 'Update the app from the store.';
    case P2PFailureCode.deprecatedCryptoSuiteRejected:
      return 'Update the app — an older security method was removed.';
    case P2PFailureCode.deprecatedEngineReplayVersionRejected:
      return 'Update the app.';
    // §10.3 v7 misc
    case P2PFailureCode.turnsHandshakeFailed:
      return 'Check that your network does not block TLS on port 443.';
    case P2PFailureCode.premoveInvalidated:
      return 'No action needed — the premove was cleared.';
    case P2PFailureCode.inviteLinkExpired:
      return 'Ask your opponent to share a fresh invite link.';
    case P2PFailureCode.inviteLinkReplayed:
      return 'Ask for a new invite.';
    case P2PFailureCode.handleImpersonationSuspected:
      return 'Verify your opponent\'s identity before sharing personal details.';
    case P2PFailureCode.transcriptRamCapOverflow:
      return 'No action needed.';
    case P2PFailureCode.cveRequiresForcedUpdate:
      return 'Update from the app store immediately.';
    case P2PFailureCode.keyRotationOverdue:
      return 'Open the app to complete the rotation.';
    case P2PFailureCode.backupRestoreDrillFailed:
      return 'Verify your recovery words are correct.';
    case P2PFailureCode.operatorOnCallUnreachable:
      return 'Try again later or check the status page.';
    // §10.4 v8 protocol
    case P2PFailureCode.validateApplyRaceDetected:
      return 'Restart the app and report this incident.';
    case P2PFailureCode.ffiFuzzFoundDivergence:
      return 'Update the app. This issue has been reported automatically.';
    case P2PFailureCode.helloTsOutOfWindow:
      return 'Set your device clock to the correct automatic time.';
    case P2PFailureCode.signedTimeFetchFailed:
      return 'Check your internet connection and try again.';
    case P2PFailureCode.multiDeviceRaceLost:
      return 'Use the other device that joined first.';
    case P2PFailureCode.configBlobVersionUnsupported:
      return 'Update the app.';
    case P2PFailureCode.spectatorChainDepthNonzeroRejected:
      return 'Try spectating via a direct link.';
    case P2PFailureCode.backfillOversizeRejected:
      return 'Join games that are still in the early moves.';
    // §10.4 v8 misc
    case P2PFailureCode.startupSelfTestFail:
      return 'Reinstall from the official store.';
    case P2PFailureCode.nativeLibIntegrityFail:
      return 'Reinstall from the official store.';
    case P2PFailureCode.pushCoalesced:
      return 'Check the notification for the latest invite.';
    case P2PFailureCode.turnBandwidthExceeded:
      return 'Move to a better network or wait for congestion to clear.';
    case P2PFailureCode.iceVpnLeakUserDeclined:
      return 'Enable WebRTC leak protection in your VPN, then reconnect.';
    case P2PFailureCode.schemaSkipVersionFail:
      return 'Reinstall the app.';
    case P2PFailureCode.dpBudgetExceeded:
      return 'No action needed.';
    case P2PFailureCode.telemetryEnvelopeVersionUnsupported:
      return 'Update the app.';
    case P2PFailureCode.studyLoadVersionMismatch:
      return 'Update the app to open this study file.';
    case P2PFailureCode.exportSidecarMissing:
      return 'Re-export the file and try again.';
    case P2PFailureCode.studyPgnParseFail:
      return 'Validate the PGN file with an external tool.';
    case P2PFailureCode.studyReplayHashDivergence:
      return 'Re-export the study from the source.';
    case P2PFailureCode.bgTaskDeniedByOs:
      return 'Enable background activity for this app in system settings.';
    case P2PFailureCode.loadShedDropped:
      return 'Try again in a moment.';
    case P2PFailureCode.rageQuitForfeitFired:
      return 'Return to the game to avoid forfeits in the future.';
    case P2PFailureCode.legitimateRestoreMergeDeclined:
      return 'You can retry the merge from Settings → Restore.';
    case P2PFailureCode.reportTargetRateLimited:
      return 'Wait before filing another report.';
    // §10.5 v9 spectator
    case P2PFailureCode.spectatorCapacityFull:
      return 'Try joining again later or watch a different game.';
    case P2PFailureCode.spectatorWaitlistExpired:
      return 'Re-join the waitlist.';
    case P2PFailureCode.spectatorAuthRequired:
      return 'Sign in and try again.';
    case P2PFailureCode.spectatorJoinRateLimited:
      return 'Wait a moment and try again.';
    case P2PFailureCode.spectatorKicked:
      return 'Contact the host if you believe this was in error.';
    case P2PFailureCode.spectatorBanned:
      return 'Contact support if you believe this is a mistake.';
    case P2PFailureCode.spectatorMuted:
      return 'You can still watch the game.';
    case P2PFailureCode.spectatorGloballyMuted:
      return 'Contact support to appeal.';
    case P2PFailureCode.spectatorShedForPerf:
      return 'Try rejoining. Game performance should improve soon.';
    case P2PFailureCode.spectatorRelayUnavailable:
      return 'Try again later.';
    case P2PFailureCode.backfillQueueOverflow:
      return 'Refresh the spectator view.';
    case P2PFailureCode.spectatorHeartbeatTimeout:
      return 'Tap Reconnect to continue watching.';
    case P2PFailureCode.spectatorKeyRotationRequired:
      return 'The app will reconnect automatically.';
    case P2PFailureCode.spectatorDatachannelBackpressure:
      return 'Move to a faster network if possible.';
    // §10.5 v9 chat
    case P2PFailureCode.chatRateLimited:
      return 'Wait before sending more messages.';
    case P2PFailureCode.chatMessageOversized:
      return 'Keep messages under the character limit.';
    case P2PFailureCode.chatSlowModeActive:
      return 'Wait for the slow-mode timer before sending again.';
    case P2PFailureCode.chatAutoThrottledClockPressure:
      return 'Chat will resume when the clock situation eases.';
    case P2PFailureCode.chatReceiverOverflow:
      return 'No action needed.';
    case P2PFailureCode.chatReportFiled:
      return 'No further action needed from you.';
    case P2PFailureCode.chatTournamentLocked:
      return 'Chat will unlock when the tournament ends.';
    case P2PFailureCode.chatHostBroadcastDroppedLowPriority:
      return 'Retry the broadcast.';
    case P2PFailureCode.chatDecodeErrorDiscarded:
      return 'Ask the sender to resend.';
    case P2PFailureCode.chatNfcNormalisationFail:
      return 'Remove special characters and try again.';
    case P2PFailureCode.chatHomoglyphBlocked:
      return 'Retype the message using standard characters.';
  }
}

/// Returns the triage [P2PFailureSeverity] for [code].
P2PFailureSeverity p2pFailureSeverity(P2PFailureCode code) {
  switch (code) {
    // ── critical ──────────────────────────────────────────────────────────────
    case P2PFailureCode.xchaChaNonceReuseDetected:
    case P2PFailureCode.secretZeroiseFailed:
    case P2PFailureCode.sessionIdCollision:
    case P2PFailureCode.validateApplyRaceDetected:
    case P2PFailureCode.sodiumInitFailed:
    case P2PFailureCode.opponentFingerprintDowngradeDetected:
    case P2PFailureCode.startupIntegrityFail:
    case P2PFailureCode.startupSelfTestFail:
    case P2PFailureCode.nativeLibIntegrityFail:
      return P2PFailureSeverity.critical;

    // ── informational ─────────────────────────────────────────────────────────
    case P2PFailureCode.fcmTokenRefreshed:
    case P2PFailureCode.pushCoalesced:
    case P2PFailureCode.wallClockTamperedDetected:
    case P2PFailureCode.premoveInvalidated:
    case P2PFailureCode.resumedAsNew:
    case P2PFailureCode.telemetryQueueOverflow:
    case P2PFailureCode.dpBudgetExceeded:
    case P2PFailureCode.transcriptRamCapOverflow:
    case P2PFailureCode.chatReportFiled:
    case P2PFailureCode.rageQuitForfeitFired:
    case P2PFailureCode.backfillQueueOverflow:
      return P2PFailureSeverity.info;

    // ── warning ───────────────────────────────────────────────────────────────
    case P2PFailureCode.backpressureDrop:
    case P2PFailureCode.captivePortal:
    case P2PFailureCode.ipv6PmtuBlackHole:
    case P2PFailureCode.pushDeferredByOs:
    case P2PFailureCode.pushReceivedNoOffer:
    case P2PFailureCode.apnsSilentPushDropped:
    case P2PFailureCode.oemBatteryOptBlocking:
    case P2PFailureCode.diagLogDiskFull:
    case P2PFailureCode.monotonicClockUnavailable:
    case P2PFailureCode.storePrivacyManifestOutOfDate:
    case P2PFailureCode.forensicBundleWriteFailed:
    case P2PFailureCode.lamportConflict:
    case P2PFailureCode.chatRateLimitLocal:
    case P2PFailureCode.chatFrameTooLarge:
    case P2PFailureCode.byeDisagreement:
    case P2PFailureCode.flagFallDisagreement:
    case P2PFailureCode.clockDesyncBeyondBudget:
    case P2PFailureCode.transcriptSignFailed:
    case P2PFailureCode.colorFlipRevealMismatch:
    case P2PFailureCode.seqCeilingReached:
    case P2PFailureCode.byeFragmentTimeout:
    case P2PFailureCode.byeFragmentOutOfOrder:
    case P2PFailureCode.byeFragmentOutOfBounds:
    case P2PFailureCode.datachannelIdCollision:
    case P2PFailureCode.turnBandwidthExceeded:
    case P2PFailureCode.loadShedDropped:
    case P2PFailureCode.bgTaskDeniedByOs:
    case P2PFailureCode.spectatorShedForPerf:
    case P2PFailureCode.spectatorDatachannelBackpressure:
    case P2PFailureCode.chatAutoThrottledClockPressure:
    case P2PFailureCode.chatReceiverOverflow:
    case P2PFailureCode.chatHostBroadcastDroppedLowPriority:
    case P2PFailureCode.chatDecodeErrorDiscarded:
    case P2PFailureCode.backfillOversizeRejected:
    case P2PFailureCode.telemetryEnvelopeVersionUnsupported:
    case P2PFailureCode.keyRotationOverdue:
      return P2PFailureSeverity.warning;

    // ── error (default) ───────────────────────────────────────────────────────
    default:
      return P2PFailureSeverity.error;
  }
}
