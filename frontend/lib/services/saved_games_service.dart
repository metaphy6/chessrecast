import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';

import 'saved_game.dart';

/// Singleton service for persisting saved games to app's documents directory.
class SavedGamesService extends GetxService {
  static const _dirName = 'saved_games';

  final RxList<SavedGame> games = <SavedGame>[].obs;

  Directory? _storageDir;

  @override
  void onInit() {
    super.onInit();
    _loadAll();
  }

  Future<Directory> _getDir() async {
    if (_storageDir != null) return _storageDir!;
    final appDir = await getApplicationDocumentsDirectory();
    _storageDir = Directory('${appDir.path}/$_dirName');
    if (!await _storageDir!.exists()) {
      await _storageDir!.create(recursive: true);
    }
    return _storageDir!;
  }

  Future<void> _loadAll() async {
    try {
      final dir = await _getDir();
      final files = dir.listSync().whereType<File>().where(
        (f) => f.path.endsWith('.json'),
      );
      final loaded = <SavedGame>[];
      for (final file in files) {
        try {
          final content = await file.readAsString();
          loaded.add(SavedGame.fromJsonString(content));
        } catch (e) {
          debugPrint('[SavedGames] Failed to load ${file.path}: $e');
        }
      }
      // Sort newest first
      loaded.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      games.assignAll(loaded);
      debugPrint('[SavedGames] Loaded ${loaded.length} games');
    } catch (e) {
      debugPrint('[SavedGames] Error loading games: $e');
    }
  }

  Future<void> saveGame(SavedGame game) async {
    try {
      final dir = await _getDir();
      final file = File('${dir.path}/${game.id}.json');
      await file.writeAsString(game.toJsonString());
      // Insert at top (newest first)
      games.insert(0, game);
      debugPrint('[SavedGames] Saved game ${game.id}');
    } catch (e) {
      debugPrint('[SavedGames] Error saving game: $e');
    }
  }

  Future<void> deleteGame(String id) async {
    try {
      final dir = await _getDir();
      final file = File('${dir.path}/$id.json');
      if (await file.exists()) {
        await file.delete();
      }
      games.removeWhere((g) => g.id == id);
      debugPrint('[SavedGames] Deleted game $id');
    } catch (e) {
      debugPrint('[SavedGames] Error deleting game: $e');
    }
  }

  Future<void> deleteAll() async {
    try {
      final dir = await _getDir();
      final files = dir.listSync().whereType<File>();
      for (final file in files) {
        await file.delete();
      }
      games.clear();
      debugPrint('[SavedGames] Deleted all games');
    } catch (e) {
      debugPrint('[SavedGames] Error deleting all games: $e');
    }
  }
}
