// ignore_for_file: constant_identifier_names

/// Tournament mode (§7 bullet-3).
///
/// Signed bracket served by signaling server.
/// Pairings: deterministic from bracket commitment + round number.
/// Results: signed by both peers.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// A bracket commitment (SHA-256 of canonical bracket JSON).
class BracketCommitment {
  final Uint8List hash; // 32 bytes

  const BracketCommitment(this.hash);

  factory BracketCommitment.fromJson(Map<String, dynamic> bracketJson) {
    final canonical = jsonEncode(bracketJson);
    final h = sha256.convert(utf8.encode(canonical));
    return BracketCommitment(Uint8List.fromList(h.bytes));
  }

  String get hex =>
      hash.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

/// A pairing in a tournament round.
class TournamentPairing {
  final String accountA;
  final String accountB;
  final int round;
  final int boardNumber;

  const TournamentPairing({
    required this.accountA,
    required this.accountB,
    required this.round,
    required this.boardNumber,
  });
}

/// Tournament session.
class TournamentSession {
  final BracketCommitment bracketCommitment;
  final int round;
  final bool chatLockedByDefault; // §7.9.8

  const TournamentSession({
    required this.bracketCommitment,
    required this.round,
    this.chatLockedByDefault = true,
  });

  /// Derive the pairing for [round] deterministically from the bracket commitment.
  ///
  /// [players] — ordered list of player account ids (must be stable).
  /// Returns a deterministic pairing list seeded from (bracketHash, round).
  List<TournamentPairing> pairingsForRound(List<String> players) {
    // Deterministic seed from commitment + round.
    final seed = sha256
        .convert(Uint8List.fromList([
          ...bracketCommitment.hash,
          ...utf8.encode(':round$round'),
        ]))
        .bytes;

    // Shuffle players deterministically using the seed.
    final shuffled = List<String>.from(players);
    _deterministicShuffle(shuffled, seed);

    final pairings = <TournamentPairing>[];
    for (var i = 0; i < shuffled.length - 1; i += 2) {
      pairings.add(TournamentPairing(
        accountA: shuffled[i],
        accountB: shuffled[i + 1],
        round: round,
        boardNumber: pairings.length + 1,
      ));
    }
    return pairings;
  }

  static void _deterministicShuffle(List<String> list, List<int> seed) {
    // Fisher-Yates using the seed bytes as PRNG state.
    var s = 0;
    for (var i = list.length - 1; i > 0; i--) {
      final j = seed[s % seed.length] % (i + 1);
      s++;
      final tmp = list[i];
      list[i] = list[j];
      list[j] = tmp;
    }
  }
}

/// A game result signed by both peers.
class SignedGameResult {
  final String winnerAccountId;
  final String loserAccountId;
  final String outcome; // 'checkmate', 'resignation', 'stalemate', etc.
  final Uint8List signatureA; // winner's signature
  final Uint8List signatureB; // loser's signature

  const SignedGameResult({
    required this.winnerAccountId,
    required this.loserAccountId,
    required this.outcome,
    required this.signatureA,
    required this.signatureB,
  });
}
