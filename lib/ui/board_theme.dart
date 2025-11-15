import 'package:flutter/material.dart';

/// Available board themes with different color schemes
enum BoardTheme {
  brown('Brown', 'Classic brown wood board'),
  darkBrown('Dark Brown', 'Deep mahogany wood board'),
  green('Green', 'Tournament green board'),
  orange('Orange', 'Warm orange board');

  final String displayName;
  final String description;

  const BoardTheme(this.displayName, this.description);

  /// Get the asset path for this board theme
  String get assetPath {
    switch (this) {
      case BoardTheme.brown:
        return 'assets/images/boards/brown_board.png';
      case BoardTheme.darkBrown:
        return 'assets/images/boards/dark_brown_board.png';
      case BoardTheme.green:
        return 'assets/images/boards/green_board.png';
      case BoardTheme.orange:
        return 'assets/images/boards/orange_board.png';
    }
  }

  /// Get the board image widget with caching
  Widget getImage({BoxFit fit = BoxFit.cover}) {
    return Image.asset(
      assetPath,
      fit: fit,
      cacheWidth: 1024, // Cache at reasonable resolution
      cacheHeight: 1024,
      filterQuality: FilterQuality.medium, // Balance quality and performance
      gaplessPlayback: true, // Prevent flicker on theme changes
      isAntiAlias: false, // Disable for better raster performance
    );
  }
}
