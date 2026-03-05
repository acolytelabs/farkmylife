import 'dart:math';
import 'package:fark_my_life/core/enums.dart';
import 'package:fark_my_life/core/constants.dart';
import 'package:fark_my_life/models/models.dart';
import 'package:fark_my_life/models/dice_tiers.dart';

/// Manages loot drops after Farkle victories.
/// Uses the tiered material system with NPC-type-specific drop tables.
class LootSystem {
  LootSystem._();

  /// Roll for loot after beating an NPC. Returns null if no drop.
  static DiceItem? rollLootForNpc(Random rng, NpcType npcType) {
    double dropChance;
    List<double> tierWeights; // [T1, T2, T3, T4, T5]
    double enchantChance;

    switch (npcType) {
      case NpcType.farmer:
      case NpcType.villager:
      case NpcType.barmaid:
        dropChance = 0.20;
        tierWeights = [0.70, 0.25, 0.05, 0.0, 0.0];
        enchantChance = 0.05;
        break;
      case NpcType.guard:
        dropChance = 0.22;
        tierWeights = [0.50, 0.35, 0.15, 0.0, 0.0];
        enchantChance = 0.10;
        break;
      case NpcType.blacksmith:
        dropChance = 0.28;
        tierWeights = [0.30, 0.40, 0.25, 0.05, 0.0];
        enchantChance = 0.15;
        break;
      case NpcType.merchant:
        dropChance = 0.30;
        tierWeights = [0.20, 0.35, 0.30, 0.15, 0.0];
        enchantChance = 0.20;
        break;
      case NpcType.noble:
        dropChance = 0.40;
        tierWeights = [0.10, 0.20, 0.35, 0.25, 0.10];
        enchantChance = 0.35;
        break;
    }

    if (rng.nextDouble() > dropChance) return null;

    // Pick tier
    final tierRoll = rng.nextDouble();
    DiceTier tier;
    double cumulative = 0;
    if ((cumulative += tierWeights[0]) > tierRoll) {
      tier = DiceTier.common;
    } else if ((cumulative += tierWeights[1]) > tierRoll) {
      tier = DiceTier.uncommon;
    } else if ((cumulative += tierWeights[2]) > tierRoll) {
      tier = DiceTier.rare;
    } else if ((cumulative += tierWeights[3]) > tierRoll) {
      tier = DiceTier.epic;
    } else {
      tier = DiceTier.legendary;
    }

    // Pick random material within tier
    final materials = DiceMaterial.values
        .where((m) => DiceTiers.tierOf(m) == tier).toList();
    final mat = materials[rng.nextInt(materials.length)];

    // Enchantment roll (never on Tier I)
    Enchantment? ench;
    if (tier != DiceTier.common && rng.nextDouble() < enchantChance) {
      ench = _pickEnchantment(rng, tier);
    }

    return DiceItem(material: mat, enchantment: ench);
  }

  /// Legacy method for backward compat.
  static DiceItem? rollLoot(Random rng, {double dropChanceOverride = -1}) {
    return rollLootForNpc(rng, NpcType.villager);
  }

  static Enchantment? _pickEnchantment(Random rng, DiceTier tier) {
    final tierIdx = DiceTiers.tierIndex(tier);
    final eligible = Enchantment.values.where((e) {
      final minIdx = DiceTiers.tierIndex(DiceTiers.enchantmentMinTier(e));
      return minIdx <= tierIdx;
    }).toList();
    if (eligible.isEmpty) return null;
    return eligible[rng.nextInt(eligible.length)];
  }
}

/// Legacy loot table entry.
class LootEntry {
  final DiceType diceType;
  final double weight;
  const LootEntry(this.diceType, this.weight);
}
