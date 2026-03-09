// Allow mods_cache to use constructors, even though direct instantiation is discouraged.
// ignore_for_file: deprecated_member_use, deprecated_member_use_from_same_package
import 'classic.dart';
import 'friendly_fire.dart';
import 'heir.dart';
import 'kings_battle.dart';
import 'mercenary.dart';
import 'save_the_queen.dart';
import 'succession.dart';
import 'truce.dart';

/// Centralized singleton cache for all Game Mod instances
///
/// IMPORTANT: Use the top-level `mods` alias (exported in `mods_cache.dart`) to access these
/// instances. Avoid constructing mods directly to prevent subtle state differences
/// and to keep code consistent.
class ModsCache {
  ModsCache._(); // private constructor - no instances

  static const Truce truce = Truce();
  static const KingsBattle kingsBattle = KingsBattle();
  static const SaveTheQueen saveTheQueen = SaveTheQueen();
  static const Succession succession = Succession();
  static const FriendlyFire friendlyFire = FriendlyFire();
  static const Mercenary mercenary = Mercenary();
  static const Classic classic = Classic();
  static const Heir heir = Heir();
}

/// Readable alias to prevent accidental direct instantiation
class ModsAlias {
  const ModsAlias();
  Truce get truce => ModsCache.truce;
  KingsBattle get kingsBattle => ModsCache.kingsBattle;
  SaveTheQueen get saveTheQueen => ModsCache.saveTheQueen;
  Succession get succession => ModsCache.succession;
  FriendlyFire get friendlyFire => ModsCache.friendlyFire;
  Mercenary get mercenary => ModsCache.mercenary;
  Classic get classic => ModsCache.classic;
  Heir get heir => ModsCache.heir;
}

const mods = ModsAlias();
