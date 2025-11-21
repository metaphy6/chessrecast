// Allow modes_cache to use constructors, even though direct instantiation is discouraged.
// ignore_for_file: deprecated_member_use, deprecated_member_use_from_same_package
import 'classic.dart';
import 'diamonds.dart';
import 'friendly_fire.dart';
import 'heir.dart';
import 'kings_battle.dart';
import 'other_side.dart';
import 'royal_pawns.dart';
import 'save_the_king.dart';
import 'save_the_queen.dart';
import 'snare.dart';
import 'teleport.dart';
import 'truce.dart';

/// Centralized singleton cache for all game mode instances
///
/// IMPORTANT: Use the top-level `modes` alias (exported in `modes_cache.dart`) to access these
/// instances (e.g., `modes.snare`). Avoid constructing modes directly (e.g., `Snare()`) to
/// prevent subtle state differences and to keep code consistent.
class ModesCache {
  ModesCache._(); // private constructor - no instances

  static const Snare snare = Snare();
  static const Truce truce = Truce();
  static const Teleport teleport = Teleport();
  static const KingsBattle kingsBattle = KingsBattle();
  static const SaveTheQueen saveTheQueen = SaveTheQueen();
  static const SaveTheKing saveTheKing = SaveTheKing();
  static const OtherSide otherSide = OtherSide();
  static const Diamonds diamonds = Diamonds();
  static const FriendlyFire friendlyFire = FriendlyFire();
  static const RoyalPawns royalPawns = RoyalPawns();
  static const Classic classic = Classic();
  static const Heir heir = Heir();
}

/// Readable alias to prevent accidental direct instantiation
class ModesAlias {
  const ModesAlias();
  Snare get snare => ModesCache.snare;
  Truce get truce => ModesCache.truce;
  Teleport get teleport => ModesCache.teleport;
  KingsBattle get kingsBattle => ModesCache.kingsBattle;
  SaveTheQueen get saveTheQueen => ModesCache.saveTheQueen;
  SaveTheKing get saveTheKing => ModesCache.saveTheKing;
  OtherSide get otherSide => ModesCache.otherSide;
  Diamonds get diamonds => ModesCache.diamonds;
  FriendlyFire get friendlyFire => ModesCache.friendlyFire;
  RoyalPawns get royalPawns => ModesCache.royalPawns;
  Classic get classic => ModesCache.classic;
  Heir get heir => ModesCache.heir;
}

const modes = ModesAlias();
