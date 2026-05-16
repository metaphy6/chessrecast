/// AEAD decrypt path model.
///
/// §4.4 — Every DataChannel message must pass through an AEAD
/// (Authenticated Encryption with Associated Data) check before the
/// payload is forwarded to the chess engine.  If the AEAD tag is
/// invalid the message is dropped with reason 'BAD_FRAME'.
/// CBOR validation happens AFTER (and only if) AEAD succeeds.
library;

/// The result of processing an incoming DataChannel message through
/// the AEAD + CBOR pipeline.
class DecryptResult {
  final bool passed;
  final String? dropReason;
  final List<int>? payload;

  const DecryptResult._({
    required this.passed,
    this.dropReason,
    this.payload,
  });
}

class AeadDecryptPath {
  /// Optional override for the CBOR validation step, used in tests to
  /// count invocations and verify short-circuit behaviour.
  final bool Function(List<int>)? onCborCheck;

  AeadDecryptPath({this.onCborCheck});

  DecryptResult process({
    required bool aeadOk,
    required bool cborOk,
    required List<int> payload,
  }) {
    // Step 1: AEAD integrity check (short-circuits on failure).
    if (!aeadOk) {
      return const DecryptResult._(passed: false, dropReason: 'BAD_FRAME');
    }

    // Step 2: CBOR structural validation.
    final cborPassed = onCborCheck != null ? onCborCheck!(payload) : cborOk;
    if (!cborPassed) {
      return const DecryptResult._(passed: false, dropReason: 'BAD_FRAME');
    }

    return DecryptResult._(passed: true, payload: payload);
  }
}
