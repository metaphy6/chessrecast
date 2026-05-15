// Proof test for roadmap §0.6.bullet-4 — total P2P quota constant.
//
// Verifies that SavedGamesLocal.maxTotalBytes is 250 MB
// and that the constant relationship holds: warnDbBytes < maxDbBytes < maxTotalBytes.

import 'package:flutter_test/flutter_test.dart';
import 'package:chessrecast/services/saved_games_local.dart';

void main() {
  test('1. maxTotalBytes is 250 MB', () {
    expect(SavedGamesLocal.maxTotalBytes, 250 * 1024 * 1024);
  });

  test('2. maxDbBytes is less than maxTotalBytes', () {
    expect(SavedGamesLocal.maxDbBytes, lessThan(SavedGamesLocal.maxTotalBytes));
  });

  test('3. warnDbBytes is less than maxDbBytes', () {
    expect(SavedGamesLocal.warnDbBytes, lessThan(SavedGamesLocal.maxDbBytes));
  });

  test('4. warnGames is less than maxGames', () {
    expect(SavedGamesLocal.warnGames, lessThan(SavedGamesLocal.maxGames));
  });
}
