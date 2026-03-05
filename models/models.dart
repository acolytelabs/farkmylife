import 'dart:math';
import 'package:fark_my_life/core/enums.dart';
import 'package:fark_my_life/models/dice_tiers.dart';
import 'package:fark_my_life/models/game_history.dart';
import 'package:fark_my_life/core/constants.dart';
import 'package:flutter/painting.dart';

// ═══════════════════════════════════════════════════════════════════════
// DICE ITEM
// ═══════════════════════════════════════════════════════════════════════

/// A single die in the player's inventory.
/// Primary identity: material + optional enchantment.
/// Legacy getters (type, rarity) provided for backward compat with scoring engine.
class DiceItem {
  final DiceMaterial material;
  final Enchantment? enchantment;

  const DiceItem({
    required this.material,
    this.enchantment,
  });

  /// Construct from material with optional enchantment.
  const DiceItem.fromMaterial(this.material, {this.enchantment});

  // ── Derived properties ─────────────────────────────────────────────

  DiceTier get tier => DiceTiers.tierOf(material);

  String get name {
    final matName = DiceTiers.materialName(material);
    if (enchantment != null) {
      return '${DiceTiers.enchantmentName(enchantment!)} $matName Die';
    }
    return '$matName Die';
  }

  String get description {
    final statDesc = DiceTiers.materialStatDesc(material);
    if (enchantment != null) {
      return '$statDesc. ${DiceTiers.enchantmentDesc(enchantment!)}';
    }
    return statDesc;
  }

  Color get tierColor => TierColors.forTier(tier);

  // ── Legacy backward compat (used by farkle_engine scoring) ─────────

  /// Maps material to old DiceType for engine scoring compatibility.
  DiceType get type {
    switch (material) {
      case DiceMaterial.birch:
      case DiceMaterial.oak:
      case DiceMaterial.mahogany:
        return DiceType.wooden;
      case DiceMaterial.bone:
        return DiceType.bone;
      case DiceMaterial.stone:
        return DiceType.wooden; // stone has no old equivalent, treat as basic
      case DiceMaterial.iron:
        return DiceType.iron;
      case DiceMaterial.bronze:
        return DiceType.iron; // bronze maps to iron behavior
      case DiceMaterial.gold:
        return DiceType.golden;
      case DiceMaterial.jade:
        return DiceType.jade;
      case DiceMaterial.crystal:
        return DiceType.crystal;
      case DiceMaterial.obsidian:
        return DiceType.shadow; // obsidian maps to shadow behavior
    }
  }

  /// Maps tier to old DiceRarity.
  DiceRarity get rarity {
    switch (tier) {
      case DiceTier.common:    return DiceRarity.common;
      case DiceTier.uncommon:  return DiceRarity.uncommon;
      case DiceTier.rare:      return DiceRarity.rare;
      case DiceTier.epic:      return DiceRarity.epic;
      case DiceTier.legendary: return DiceRarity.legendary;
    }
  }

  Color get rarityColor => tierColor;

  // ── Common presets ─────────────────────────────────────────────────

  static const DiceItem wooden = DiceItem(material: DiceMaterial.oak);

  static const DiceItem iron = DiceItem(material: DiceMaterial.iron);
  static const DiceItem bone = DiceItem(material: DiceMaterial.bone);
  static const DiceItem jade = DiceItem(material: DiceMaterial.jade);
  static const DiceItem golden = DiceItem(material: DiceMaterial.gold, enchantment: Enchantment.miserTouch);
  static const DiceItem crystal = DiceItem(material: DiceMaterial.crystal, enchantment: Enchantment.secondWind);
  static const DiceItem shadow = DiceItem(material: DiceMaterial.obsidian, enchantment: Enchantment.boneCollector);
  static const DiceItem royal = DiceItem(material: DiceMaterial.gold, enchantment: Enchantment.luckyStreak);
  static const DiceItem dragon = DiceItem(material: DiceMaterial.obsidian, enchantment: Enchantment.echo);

  /// All legacy dice definitions for lookup (used by old loot system).
  static const Map<DiceType, DiceItem> all = {
    DiceType.wooden: wooden,
    DiceType.iron: iron,
    DiceType.bone: bone,
    DiceType.jade: jade,
    DiceType.golden: golden,
    DiceType.crystal: crystal,
    DiceType.shadow: shadow,
    DiceType.royal: royal,
    DiceType.dragon: dragon,
  };
}

// ═══════════════════════════════════════════════════════════════════════
// PLAYER DATA
// ═══════════════════════════════════════════════════════════════════════

class PlayerData {
  double x;
  double y;
  Direction facing;
  int gold;
  List<DiceItem> dice;
  int wins;
  int losses;

  // Loadout system: each loadout is a list of 6 indices into dice collection
  List<DiceLoadout> loadouts;
  int activeLoadoutIndex;

  // Play history and stats
  PlayHistory history;

  PlayerData({
    this.x = 20.0,
    this.y = 20.0,
    this.facing = Direction.down,
    this.gold = GameConstants.startingGold,
    List<DiceItem>? dice,
    this.wins = 0,
    this.losses = 0,
    List<DiceLoadout>? loadouts,
    this.activeLoadoutIndex = 0,
    PlayHistory? history,
  }) : dice = dice ??
            List.generate(
                GameConstants.startingDiceCount, (_) => DiceItem.wooden),
       loadouts = loadouts ?? [DiceLoadout(name: 'Default', diceIndices: [0, 1, 2, 3, 4, 5])],
       history = history ?? PlayHistory();

  /// The 6 dice currently equipped based on active loadout.
  List<DiceItem> get equippedDice {
    if (loadouts.isEmpty || activeLoadoutIndex >= loadouts.length) {
      return dice.take(6).toList();
    }
    final loadout = loadouts[activeLoadoutIndex];
    return loadout.diceIndices
        .where((i) => i >= 0 && i < dice.length)
        .map((i) => dice[i])
        .toList()
      ..addAll(List.generate(
          (6 - loadout.diceIndices.where((i) => i >= 0 && i < dice.length).length).clamp(0, 6),
          (_) => DiceItem.wooden));
  }

  /// Cycle to next loadout. Returns new loadout name.
  String cycleLoadout() {
    if (loadouts.length <= 1) return loadouts.isNotEmpty ? loadouts[0].name : 'Default';
    activeLoadoutIndex = (activeLoadoutIndex + 1) % loadouts.length;
    return loadouts[activeLoadoutIndex].name;
  }

  /// Auto-generate a "Best" loadout from highest tier dice.
  void rebuildDefaultLoadout() {
    if (dice.isEmpty) return;
    // Sort by tier (descending), then enchanted > not
    final indexed = List.generate(dice.length, (i) => i);
    indexed.sort((a, b) {
      final tierCmp = DiceTiers.tierIndex(dice[b].tier)
          .compareTo(DiceTiers.tierIndex(dice[a].tier));
      if (tierCmp != 0) return tierCmp;
      return (dice[b].enchantment != null ? 1 : 0)
          .compareTo(dice[a].enchantment != null ? 1 : 0);
    });
    final best6 = indexed.take(6).toList();
    if (loadouts.isNotEmpty) {
      loadouts[0] = DiceLoadout(name: 'Best', diceIndices: best6);
    } else {
      loadouts.add(DiceLoadout(name: 'Best', diceIndices: best6));
    }
  }

  /// Tile coordinates (integer).
  int get tileX => x.floor();
  int get tileY => y.floor();
}

/// A named loadout of 6 dice (indices into PlayerData.dice).
class DiceLoadout {
  String name;
  List<int> diceIndices; // 6 indices into PlayerData.dice

  DiceLoadout({required this.name, required this.diceIndices});

  Map<String, dynamic> toJson() => {'name': name, 'idx': diceIndices};

  factory DiceLoadout.fromJson(Map<String, dynamic> j) => DiceLoadout(
    name: j['name'] ?? 'Loadout',
    diceIndices: List<int>.from(j['idx'] ?? [0, 1, 2, 3, 4, 5]),
  );
}

// ═══════════════════════════════════════════════════════════════════════
// NPC DATA
// ═══════════════════════════════════════════════════════════════════════

class NpcData {
  final String id;
  final String name;
  final NpcType type;
  final Personality personality;

  double x;
  double y;
  double homeX;
  double homeY;
  Direction facing;
  NpcState state;

  int gold;
  final int maxGold;
  double diceChance; // 0-1, probability of seeking a dice table
  double skill; // 0-1, how good at spotting scoring combos (1.0 = perfect)

  // Movement / AI
  double stateTimer;
  double wanderTargetX;
  double wanderTargetY;
  int? seatedAtTable; // index of dice table, or null
  double stuckTimer = 0; // how long NPC hasn't moved while trying to

  // Animation
  double animTimer;
  int animFrame;

  // NPC dice loadout (starts as 6x wooden, upgrades over time)
  List<DiceItem> npcDice;

  // NPC play history
  PlayHistory npcHistory = PlayHistory();

  NpcData({
    required this.id,
    required this.name,
    required this.type,
    required this.personality,
    required this.x,
    required this.y,
    required this.gold,
    required this.maxGold,
    this.diceChance = 0.3,
    double? skill,
    this.facing = Direction.down,
    this.state = NpcState.idle,
    this.stateTimer = 0,
    this.animTimer = 0,
    this.animFrame = 0,
    this.seatedAtTable,
  })  : homeX = x,
        homeY = y,
        wanderTargetX = x,
        wanderTargetY = y,
        skill = skill ?? _defaultSkill(type),
        npcDice = _generateNpcDice(type, gold);

  static double _defaultSkill(NpcType type) {
    switch (type) {
      case NpcType.noble:      return 0.98; // almost never misses
      case NpcType.merchant:   return 0.90;
      case NpcType.blacksmith: return 0.82;
      case NpcType.guard:      return 0.78;
      case NpcType.barmaid:    return 0.72;
      case NpcType.villager:   return 0.65;
      case NpcType.farmer:     return 0.60; // occasionally misses combos
    }
  }

  /// Generate starting dice for an NPC based on their type and wealth.
  static List<DiceItem> _generateNpcDice(NpcType type, int gold) {
    final rng = Random();
    // Base tier distribution depends on NPC type
    int maxTier;
    double upgradedChance;
    double enchantChance;

    switch (type) {
      case NpcType.noble:
        maxTier = 5; upgradedChance = 0.7; enchantChance = 0.25;
        break;
      case NpcType.merchant:
        maxTier = 4; upgradedChance = 0.5; enchantChance = 0.15;
        break;
      case NpcType.blacksmith:
        maxTier = 3; upgradedChance = 0.5; enchantChance = 0.10;
        break;
      case NpcType.guard:
        maxTier = 3; upgradedChance = 0.35; enchantChance = 0.08;
        break;
      case NpcType.farmer:
      case NpcType.villager:
      case NpcType.barmaid:
        maxTier = 2; upgradedChance = 0.25; enchantChance = 0.05;
        break;
    }

    return List.generate(6, (_) {
      if (rng.nextDouble() < upgradedChance) {
        // Roll a tier between 2 and maxTier
        final tierIdx = 2 + rng.nextInt(maxTier - 1);
        final tier = DiceTier.values[tierIdx.clamp(0, 4)];
        final materials = DiceMaterial.values
            .where((m) => DiceTiers.tierOf(m) == tier).toList();
        final mat = materials[rng.nextInt(materials.length)];

        Enchantment? ench;
        if (tier != DiceTier.common && rng.nextDouble() < enchantChance) {
          final tIdx = DiceTiers.tierIndex(tier);
          final eligible = Enchantment.values.where((e) =>
              DiceTiers.tierIndex(DiceTiers.enchantmentMinTier(e)) <= tIdx).toList();
          if (eligible.isNotEmpty) ench = eligible[rng.nextInt(eligible.length)];
        }
        return DiceItem(material: mat, enchantment: ench);
      }
      // Common die — random wood variant
      final woods = [DiceMaterial.birch, DiceMaterial.oak, DiceMaterial.mahogany];
      return DiceItem(material: woods[rng.nextInt(woods.length)]);
    });
  }

  int get tileX => x.floor();
  int get tileY => y.floor();

  /// How much this NPC is willing to bet.
  int get suggestedBet =>
      (gold * GameConstants.suggestedBetRatio).clamp(GameConstants.minBet, gold).toInt();

  /// Color for this NPC's sprite body.
  Color get primaryColor {
    switch (type) {
      case NpcType.merchant:
        return GameColors.merchantPrimary;
      case NpcType.guard:
        return GameColors.guardPrimary;
      case NpcType.villager:
        return GameColors.villagerPrimary;
      case NpcType.noble:
        return GameColors.noblePrimary;
      case NpcType.blacksmith:
        return GameColors.blacksmithPrimary;
      case NpcType.farmer:
        return GameColors.farmerPrimary;
      case NpcType.barmaid:
        return GameColors.barmaidPrimary;
    }
  }

  Color get secondaryColor {
    switch (type) {
      case NpcType.merchant:
        return GameColors.merchantSecondary;
      case NpcType.guard:
        return GameColors.guardSecondary;
      case NpcType.villager:
        return GameColors.villagerSecondary;
      case NpcType.noble:
        return GameColors.nobleSecondary;
      case NpcType.blacksmith:
        return GameColors.blacksmithSecondary;
      case NpcType.farmer:
        return GameColors.farmerSecondary;
      case NpcType.barmaid:
        return GameColors.barmaidSecondary;
    }
  }

  /// Risk tolerance multiplier for Farkle AI.
  double get riskFactor {
    switch (personality) {
      case Personality.cautious:
        return 0.3;
      case Personality.normal:
        return 0.5;
      case Personality.bold:
        return 0.7;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════
// DICE TABLE DATA
// ═══════════════════════════════════════════════════════════════════════

class DiceTableData {
  final int id;
  final double x;
  final double y;
  final List<Offset> seatOffsets; // relative offsets for seats

  String? occupant1Id; // NPC id or 'player'
  String? occupant2Id;

  // ── NPC-vs-NPC game tracking ──
  double npcGameTimer = 0;       // how long game has been running
  double npcGameDuration = 0;    // total game length (set when game starts)
  int npcGameBet = 0;            // bet amount for this game
  bool npcGameActive = false;    // true while NPCs are playing

  DiceTableData({
    required this.id,
    required this.x,
    required this.y,
    List<Offset>? seatOffsets,
    this.occupant1Id,
    this.occupant2Id,
  }) : seatOffsets = seatOffsets ??
            const [Offset(-1, 0), Offset(1, 0)]; // left & right seats

  bool get isEmpty => occupant1Id == null && occupant2Id == null;
  bool get hasOneSeat => occupant1Id != null && occupant2Id == null ||
      occupant1Id == null && occupant2Id != null;
  bool get isFull => occupant1Id != null && occupant2Id != null;

  int get occupantCount => (occupant1Id != null ? 1 : 0) + (occupant2Id != null ? 1 : 0);

  /// Try to seat someone. Returns true if successful.
  bool seat(String entityId) {
    if (occupant1Id == null) {
      occupant1Id = entityId;
      return true;
    } else if (occupant2Id == null) {
      occupant2Id = entityId;
      return true;
    }
    return false;
  }

  /// Remove someone from the table.
  void unseat(String entityId) {
    if (occupant1Id == entityId) occupant1Id = null;
    if (occupant2Id == entityId) occupant2Id = null;
    // If table is now empty or half-empty, cancel any NPC game
    if (!isFull) {
      npcGameActive = false;
      npcGameTimer = 0;
      npcGameDuration = 0;
      npcGameBet = 0;
    }
  }

  /// Start an NPC-vs-NPC game at this table.
  void startNpcGame(int bet, double duration) {
    npcGameBet = bet;
    npcGameDuration = duration;
    npcGameTimer = 0;
    npcGameActive = true;
  }

  /// End the NPC game and reset tracking.
  void endNpcGame() {
    npcGameActive = false;
    npcGameTimer = 0;
    npcGameDuration = 0;
    npcGameBet = 0;
  }

  /// Get the seat position for a given seat index (0 or 1).
  Offset seatWorldPos(int seatIndex) {
    final offset = seatOffsets[seatIndex.clamp(0, seatOffsets.length - 1)];
    return Offset(x + offset.dx, y + offset.dy);
  }
}

// ═══════════════════════════════════════════════════════════════════════
// FARKLE GAME STATE
// ═══════════════════════════════════════════════════════════════════════

/// Represents a single die on the Farkle table.
class FarkleDie {
  int value;
  bool held; // kept from previous roll
  bool selected; // selected this roll
  bool locked; // scored and locked
  final DiceItem item; // the actual die item (for bonuses)

  FarkleDie({
    this.value = 1,
    this.held = false,
    this.selected = false,
    this.locked = false,
    this.item = DiceItem.wooden,
  });

  void roll(Random rng) {
    if (!held && !locked) {
      value = _biasedRoll(rng, item);
      selected = false;
    }
  }

  /// Roll with material tier weighting.
  static int _biasedRoll(Random rng, DiceItem die) {
    final tier = die.tier;
    switch (tier) {
      case DiceTier.uncommon:
        // +1% chance to roll a 5 (17.6% for 5, 16.48% for others)
        return _weightedRoll(rng, 5, 0.01);
      case DiceTier.rare:
        // +1% chance to roll a 1 (17.6% for 1, 16.48% for others)
        return _weightedRoll(rng, 1, 0.01);
      case DiceTier.legendary:
        // +1.5% chance for 1s
        return _weightedRoll(rng, 1, 0.015);
      default:
        // Common and Epic: uniform distribution
        return rng.nextInt(6) + 1;
    }
  }

  /// Roll with bias toward a specific face.
  static int _weightedRoll(Random rng, int favored, double extraChance) {
    // favored face gets (1/6 + extraChance), others share the rest equally
    final favoredProb = (1.0 / 6.0) + extraChance;
    final roll = rng.nextDouble();
    if (roll < favoredProb) return favored;
    // Distribute remaining probability among other 5 faces
    final remaining = 1.0 - favoredProb;
    final perFace = remaining / 5.0;
    double cumulative = favoredProb;
    int face = 0;
    for (int f = 1; f <= 6; f++) {
      if (f == favored) continue;
      cumulative += perFace;
      if (roll < cumulative) { face = f; break; }
      face = f; // fallback to last
    }
    return face;
  }
}

/// Full state of a Farkle game in progress.
class FarkleGameState {
  final String player1Id; // 'player' or NPC id
  final String player2Id;
  final int betAmount;
  final int targetScore; // score needed to win (scales with bet)

  List<FarkleDie> dice;
  FarklePhase phase;
  bool isPlayer1Turn;

  int player1Score;
  int player2Score;
  int turnScore; // accumulated this turn before banking
  int rollsThisTurn;

  bool farkled;
  bool hotDice; // all 6 scored
  bool crystalUsed; // Second Wind / crystal die used
  Set<Enchantment> usedEnchantments; // active enchantments that have been triggered

  String? winnerId;
  String statusMessage;

  FarkleGameState({
    required this.player1Id,
    required this.player2Id,
    required this.betAmount,
    int? targetScore,
    List<FarkleDie>? dice,
    this.phase = FarklePhase.rolling,
    this.isPlayer1Turn = true,
    this.player1Score = 0,
    this.player2Score = 0,
    this.turnScore = 0,
    this.rollsThisTurn = 0,
    this.farkled = false,
    this.hotDice = false,
    this.crystalUsed = false,
    Set<Enchantment>? usedEnchantments,
    this.winnerId,
    this.statusMessage = 'Roll the dice!',
  }) : targetScore = targetScore ?? _calcTargetScore(betAmount),
       dice = dice ?? List.generate(6, (_) => FarkleDie()),
       usedEnchantments = usedEnchantments ?? {};

  /// Target score scales with bet: cheap games are shorter.
  /// 5g → 1000, 15g → 1200, 25g → 2000, 50g+ → 4000, tournament (0g) → 4000
  static int _calcTargetScore(int bet) {
    if (bet <= 0) return GameConstants.farkleWinScore; // tournament
    final raw = (bet * 80).clamp(1000, GameConstants.farkleWinScore);
    // Round to nearest 500
    return ((raw + 250) ~/ 500) * 500;
  }

  /// Check if an active enchantment can still be used.
  bool canUseEnchantment(Enchantment e) {
    if (!DiceTiers.isActiveEnchantment(e)) return false;
    if (usedEnchantments.contains(e)) return false;
    // Phantom gets 2 uses
    if (e == Enchantment.phantom) {
      final useCount = usedEnchantments.where((u) => u == e).length;
      return useCount < 2;
    }
    return true;
  }

  String get currentPlayerId => isPlayer1Turn ? player1Id : player2Id;
  int get currentPlayerScore => isPlayer1Turn ? player1Score : player2Score;

  void setCurrentPlayerScore(int score) {
    if (isPlayer1Turn) {
      player1Score = score;
    } else {
      player2Score = score;
    }
  }

  /// Switch to the other player's turn.
  void switchTurn() {
    isPlayer1Turn = !isPlayer1Turn;
    turnScore = 0;
    rollsThisTurn = 0;
    farkled = false;
    hotDice = false;
    crystalUsed = false;
    for (final d in dice) {
      d.held = false;
      d.selected = false;
      d.locked = false;
    }
  }

  /// Number of dice available to roll (not held/locked).
  int get availableDiceCount =>
      dice.where((d) => !d.held && !d.locked).length;

  /// Dice that are free to roll.
  List<FarkleDie> get rollableDice =>
      dice.where((d) => !d.held && !d.locked).toList();

  /// Dice currently selected by the player.
  List<FarkleDie> get selectedDice => dice.where((d) => d.selected).toList();
}

// ═══════════════════════════════════════════════════════════════════════
// NPC DIALOGUE
// ═══════════════════════════════════════════════════════════════════════

class NpcDialogue {
  final List<String> greetings;
  final List<String> taunts;
  final List<String> onWin;
  final List<String> onLose;
  final List<String> observing;
  final List<String> busy;

  const NpcDialogue({
    required this.greetings,
    required this.taunts,
    required this.onWin,
    required this.onLose,
    required this.observing,
    required this.busy,
  });

  String randomGreeting(Random rng) => greetings[rng.nextInt(greetings.length)];
  String randomTaunt(Random rng) => taunts[rng.nextInt(taunts.length)];
  String randomWin(Random rng) => onWin[rng.nextInt(onWin.length)];
  String randomLose(Random rng) => onLose[rng.nextInt(onLose.length)];
  String randomObserving(Random rng) => observing[rng.nextInt(observing.length)];
  String randomBusy(Random rng) => busy[rng.nextInt(busy.length)];
}

// ═══════════════════════════════════════════════════════════════════════
// LOOT TABLE ENTRY
// ═══════════════════════════════════════════════════════════════════════

class LootEntry {
  final DiceType diceType;
  final double weight; // relative probability

  const LootEntry(this.diceType, this.weight);
}
