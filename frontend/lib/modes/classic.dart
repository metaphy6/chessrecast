import 'game_mode.dart';

/// CLASSIC MODE: Standard chess rules
///
/// All methods return null to use default behavior
class Classic extends GameMode {
  @Deprecated(
    'Use the `modes.classic` alias from modes_cache.dart instead of direct instantiation',
  )
  const Classic();
  // Uses all default implementations
}
