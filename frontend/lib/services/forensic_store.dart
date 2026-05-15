/// Encrypted forensic-bundle store.
///
/// AES-256-GCM equivalent of libsodium crypto_secretstream (Phase-0).
/// Key derivation upgraded in Phase 2.1 to use device identity.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart';
import 'package:path/path.dart' as path_pkg;

class ForensicStore {
  static const _keyFile = '.forensic_kek';
  static const _keyBytes = 32;
  static const _nonceBytes = 12;

  final String _docsDir;
  Key? _kek;

  ForensicStore({required String docsDir}) : _docsDir = docsDir;

  Future<void> init() async {
    final forensicDir = Directory(_forensicsPath);
    await _loadOrCreateKek();
  }

  Future<void> writeBundle({
    required String sessionId,
    required Uint8List payload,
  }) async {
    final ciphertext = _encrypt(payload);
    final file = File(_bundlePath(sessionId));
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(ciphertext);
  }

  Future<Uint8List?> readBundle({required String sessionId}) async {
    final file = File(_bundlePath(sessionId));
    try {
      return _decrypt(file.readAsStringSync());
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteBundle({required String sessionId}) async {
    final dir = Directory(_sessionDir(sessionId));
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  }

  List<String> listSessions() {
    final base = Directory(_forensicsPath);
    return base
        .listSync()
        .whereType<Directory>()
        .map((d) => path_pkg.basename(d.path))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Retention policy
  // ---------------------------------------------------------------------------

  /// Maximum number of forensic bundles to retain (FIFO).
  static const int maxBundles = 50;

  /// Enforce the [maxBundles] FIFO cap.
  ///
  /// Returns the number of sessions that were evicted.  Sessions are ordered by
  /// the mtime of their `bundle.enc` file; oldest are deleted first.
  Future<int> enforceRetentionPolicy() async {
    final base = Directory(_forensicsPath);
    if (!base.existsSync()) return 0;

    final sessions = base.listSync().whereType<Directory>().map((d) {
      final f = File(path_pkg.join(d.path, 'bundle.enc'));
      final mtime = f.existsSync()
          ? f.statSync().modified
          : DateTime.fromMillisecondsSinceEpoch(0);
      return (dir: d, mtime: mtime);
    }).toList()..sort((a, b) => a.mtime.compareTo(b.mtime)); // oldest first

    if (sessions.length <= maxBundles) return 0;

    final evict = sessions.sublist(0, sessions.length - maxBundles);
    for (final s in evict) {
      s.dir.deleteSync(recursive: true);
    }
    return evict.length;
  }

  String get _forensicsPath => path_pkg.join(_docsDir, 'p2p', 'forensics');
  String _sessionDir(String sid) => path_pkg.join(_forensicsPath, sid);
  String _bundlePath(String sid) =>
      path_pkg.join(_sessionDir(sid), 'bundle.enc');
  String _kekPath() => path_pkg.join(_docsDir, 'p2p', _keyFile);

  Future<void> _loadOrCreateKek() async {
    final kekFile = File(_kekPath());
    if (kekFile.existsSync()) {
      _kek = Key(base64.decode(kekFile.readAsStringSync().trim()));
    } else {
      final rng = Random.secure();
      final keyBytes = Uint8List.fromList(
        List.generate(_keyBytes, (_) => rng.nextInt(256)),
      );
      _kek = Key(keyBytes);
      kekFile.parent.createSync(recursive: true);
      kekFile.writeAsStringSync(base64.encode(keyBytes));
    }
  }

  String _encrypt(Uint8List plaintext) {
    final rng = Random.secure();
    final iv = IV(
      Uint8List.fromList(List.generate(_nonceBytes, (_) => rng.nextInt(256))),
    );
    final encrypter = Encrypter(AES(_kek!, mode: AESMode.gcm));
    final encrypted = encrypter.encrypt(base64.encode(plaintext), iv: iv);
    final combined = Uint8List(_nonceBytes + encrypted.bytes.length as int);
    combined.setRange(0, _nonceBytes, iv.bytes);
    combined.setRange(_nonceBytes, combined.length, encrypted.bytes);
    return base64Url.encode(combined);
  }

  Uint8List _decrypt(String ciphertext) {
    final combined = base64Url.decode(ciphertext);
    final iv = IV(Uint8List.fromList(combined.sublist(0, _nonceBytes)));
    final enc = Encrypted(combined.sublist(_nonceBytes));
    final encrypter = Encrypter(AES(_kek!, mode: AESMode.gcm));
    return base64.decode(encrypter.decrypt(enc, iv: iv));
  }
}
