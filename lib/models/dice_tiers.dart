import 'dart:ui';

// ═══════════════════════════════════════════════════════════════════════
// MATERIAL TIER SYSTEM
// ═══════════════════════════════════════════════════════════════════════

/// Physical material a die is made from.
enum DiceMaterial {
  // Tier I — Common
  birch,
  oak,
  mahogany,
  // Tier II — Uncommon
  bone,
  stone,
  // Tier III — Rare
  iron,
  bronze,
  // Tier IV — Epic
  gold,
  jade,
  // Tier V — Legendary
  crystal,
  obsidian,
}

/// Quality tier (maps 1:1 with WoW-style item quality colors).
enum DiceTier {
  common,    // I  — gray
  uncommon,  // II — green
  rare,      // III — blue
  epic,      // IV — purple
  legendary, // V  — orange
}

/// Passive or active enchantment on a die.
enum Enchantment {
  // Passive (always active when equipped)
  ironclad,      // +10 bonus per scoring combo involving this die
  miserTouch,    // +15 gold bonus when scoring & passing, per Miser die
  stubborn,      // 25% chance this die doesn't re-roll (persists face)
  gamblersEdge,  // +50 to first scoring combo if turn score was 0
  boneCollector, // triples involving this die score +50
  luckyStreak,   // after 3 non-bust rolls, +2% weight toward 1s rest of turn

  // Active (per-game cooldown, tap-and-hold to trigger)
  secondWind,    // re-roll this single die after a roll, before bust check (1/game)
  shatter,       // opponent rolls 5 dice next roll instead of 6 (1/game)
  forge,         // set this die to any face value for one roll (1/game, Tier V only)
  phantom,       // score this die as if it shows a 1 (2/game)
  echo,          // duplicate last kept combination score (1/game, Tier V only)
}

// ═══════════════════════════════════════════════════════════════════════
// WOW-STYLE TIER COLORS
// ═══════════════════════════════════════════════════════════════════════

class TierColors {
  TierColors._();

  static const Color common    = Color(0xFF9d9d9d); // gray
  static const Color uncommon  = Color(0xFF1eff00); // green
  static const Color rare      = Color(0xFF0070dd); // blue
  static const Color epic      = Color(0xFFa335ee); // purple
  static const Color legendary = Color(0xFFff8000); // orange

  static Color forTier(DiceTier tier) {
    switch (tier) {
      case DiceTier.common:    return common;
      case DiceTier.uncommon:  return uncommon;
      case DiceTier.rare:      return rare;
      case DiceTier.epic:      return epic;
      case DiceTier.legendary: return legendary;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════
// ENCHANTMENT COLORS (for shimmer / border glow)
// ═══════════════════════════════════════════════════════════════════════

class EnchantmentColors {
  EnchantmentColors._();

  static const Map<Enchantment, Color> colors = {
    Enchantment.ironclad:      Color(0xFF6888b0), // steel blue
    Enchantment.miserTouch:    Color(0xFFd4a830), // coin gold
    Enchantment.stubborn:      Color(0xFFc87030), // rust orange
    Enchantment.gamblersEdge:  Color(0xFF50b860), // lucky green
    Enchantment.boneCollector: Color(0xFFd8d0c0), // marrow white
    Enchantment.luckyStreak:   Color(0xFFd850a0), // hot pink
    Enchantment.secondWind:    Color(0xFF40c8e8), // sky cyan
    Enchantment.shatter:       Color(0xFFe04040), // crack red
    Enchantment.forge:         Color(0xFFe88020), // forge orange
    Enchantment.phantom:       Color(0xFF9060d0), // ghost purple
    Enchantment.echo:          Color(0xFFb0b8c8), // mirror silver
  };

  static Color forEnchantment(Enchantment e) => colors[e] ?? const Color(0xFFffffff);
}

// ═══════════════════════════════════════════════════════════════════════
// LOOKUP HELPERS
// ═══════════════════════════════════════════════════════════════════════

class DiceTiers {
  DiceTiers._();

  static DiceTier tierOf(DiceMaterial mat) {
    switch (mat) {
      case DiceMaterial.birch:
      case DiceMaterial.oak:
      case DiceMaterial.mahogany:
        return DiceTier.common;
      case DiceMaterial.bone:
      case DiceMaterial.stone:
        return DiceTier.uncommon;
      case DiceMaterial.iron:
      case DiceMaterial.bronze:
        return DiceTier.rare;
      case DiceMaterial.gold:
      case DiceMaterial.jade:
        return DiceTier.epic;
      case DiceMaterial.crystal:
      case DiceMaterial.obsidian:
        return DiceTier.legendary;
    }
  }

  /// Tier index 1–5 for display and comparison.
  static int tierIndex(DiceTier tier) {
    switch (tier) {
      case DiceTier.common:    return 1;
      case DiceTier.uncommon:  return 2;
      case DiceTier.rare:      return 3;
      case DiceTier.epic:      return 4;
      case DiceTier.legendary: return 5;
    }
  }

  /// Roman numeral label.
  static String tierLabel(DiceTier tier) {
    switch (tier) {
      case DiceTier.common:    return 'I';
      case DiceTier.uncommon:  return 'II';
      case DiceTier.rare:      return 'III';
      case DiceTier.epic:      return 'IV';
      case DiceTier.legendary: return 'V';
    }
  }

  /// Human-readable material name.
  static String materialName(DiceMaterial mat) {
    switch (mat) {
      case DiceMaterial.birch:    return 'Birch';
      case DiceMaterial.oak:      return 'Oak';
      case DiceMaterial.mahogany: return 'Mahogany';
      case DiceMaterial.bone:     return 'Bone';
      case DiceMaterial.stone:    return 'Stone';
      case DiceMaterial.iron:     return 'Iron';
      case DiceMaterial.bronze:   return 'Bronze';
      case DiceMaterial.gold:     return 'Gold';
      case DiceMaterial.jade:     return 'Jade';
      case DiceMaterial.crystal:  return 'Crystal';
      case DiceMaterial.obsidian: return 'Obsidian';
    }
  }

  /// Human-readable enchantment name.
  static String enchantmentName(Enchantment e) {
    switch (e) {
      case Enchantment.ironclad:      return 'Ironclad';
      case Enchantment.miserTouch:    return "Miser's Touch";
      case Enchantment.stubborn:      return 'Stubborn';
      case Enchantment.gamblersEdge:  return "Gambler's Edge";
      case Enchantment.boneCollector: return 'Bone Collector';
      case Enchantment.luckyStreak:   return 'Lucky Streak';
      case Enchantment.secondWind:    return 'Second Wind';
      case Enchantment.shatter:       return 'Shatter';
      case Enchantment.forge:         return 'Forge';
      case Enchantment.phantom:       return 'Phantom';
      case Enchantment.echo:          return 'Echo';
    }
  }

  /// Short enchantment description.
  static String enchantmentDesc(Enchantment e) {
    switch (e) {
      case Enchantment.ironclad:      return '+10 per scoring combo with this die';
      case Enchantment.miserTouch:    return '+15g bonus when scoring & passing';
      case Enchantment.stubborn:      return '25% chance face persists across re-rolls';
      case Enchantment.gamblersEdge:  return '+50 to first combo if turn score is 0';
      case Enchantment.boneCollector: return 'Triples with this die score +50';
      case Enchantment.luckyStreak:   return 'After 3 safe rolls, +2% weight toward 1s';
      case Enchantment.secondWind:    return 'Re-roll this die after rolling (1/game)';
      case Enchantment.shatter:       return 'Opponent rolls 5 dice next turn (1/game)';
      case Enchantment.forge:         return 'Set this die to any face (1/game)';
      case Enchantment.phantom:       return 'Score as 1 regardless of face (2/game)';
      case Enchantment.echo:          return 'Double last kept score (1/game)';
    }
  }

  /// Whether an enchantment is active (has a cooldown) vs passive.
  static bool isActiveEnchantment(Enchantment e) {
    switch (e) {
      case Enchantment.secondWind:
      case Enchantment.shatter:
      case Enchantment.forge:
      case Enchantment.phantom:
      case Enchantment.echo:
        return true;
      default:
        return false;
    }
  }

  /// Minimum tier required for an enchantment.
  static DiceTier enchantmentMinTier(Enchantment e) {
    switch (e) {
      case Enchantment.ironclad:      return DiceTier.uncommon;
      case Enchantment.gamblersEdge:  return DiceTier.uncommon;
      case Enchantment.miserTouch:    return DiceTier.rare;
      case Enchantment.stubborn:      return DiceTier.rare;
      case Enchantment.secondWind:    return DiceTier.rare;
      case Enchantment.boneCollector: return DiceTier.epic;
      case Enchantment.luckyStreak:   return DiceTier.epic;
      case Enchantment.shatter:       return DiceTier.epic;
      case Enchantment.phantom:       return DiceTier.epic;
      case Enchantment.forge:         return DiceTier.legendary;
      case Enchantment.echo:          return DiceTier.legendary;
    }
  }

  /// Material stat description for display.
  static String materialStatDesc(DiceMaterial mat) {
    final tier = tierOf(mat);
    switch (tier) {
      case DiceTier.common:
        return 'Standard odds (16.6% per face)';
      case DiceTier.uncommon:
        return '+1% chance to roll a 5';
      case DiceTier.rare:
        return '+1% chance to roll a 1';
      case DiceTier.epic:
        return '1s score 110, 5s score 55';
      case DiceTier.legendary:
        return '+1.5% chance for 1s, triples +25';
    }
  }

  /// Base shop price for a material.
  static int basePrice(DiceMaterial mat) {
    switch (mat) {
      case DiceMaterial.birch:    return 1;
      case DiceMaterial.oak:      return 1;
      case DiceMaterial.mahogany: return 2;
      case DiceMaterial.bone:     return 3;
      case DiceMaterial.stone:    return 4;
      case DiceMaterial.iron:     return 6;
      case DiceMaterial.bronze:   return 10;
      case DiceMaterial.gold:     return 25;
      case DiceMaterial.jade:     return 15;
      case DiceMaterial.crystal:  return 40;
      case DiceMaterial.obsidian: return 60;
    }
  }

  /// Get face probabilities for a material [face1..face6] as percentages.
  static List<double> faceOdds(DiceMaterial mat) {
    final tier = tierOf(mat);
    const base = 16.667; // 1/6
    switch (tier) {
      case DiceTier.common:
        return List.filled(6, base);
      case DiceTier.uncommon:
        // +1% to face 5
        final other = (100.0 - 17.6) / 5;
        return [other, other, other, other, 17.6, other];
      case DiceTier.rare:
        // +1% to face 1
        final other = (100.0 - 17.6) / 5;
        return [17.6, other, other, other, other, other];
      case DiceTier.epic:
        return List.filled(6, base); // fair odds, score bonus instead
      case DiceTier.legendary:
        // +1.5% to face 1
        final other = (100.0 - 18.1) / 5;
        return [18.1, other, other, other, other, other];
    }
  }
}

/// Procedural naming for enchanted dice — medieval/chivalric themed.
/// Two dice with identical material+enchantment always get the same name.
class DiceNames {
  DiceNames._();

  /// Generate a lore name for a die based on its properties.
  static String loreName(DiceMaterial material, Enchantment? enchantment) {
    if (enchantment == null) {
      return '${DiceTiers.materialName(material)} Die';
    }
    // Deterministic name from material+enchantment combo
    return _enchantedNames[enchantment]?[material] ??
        '${DiceTiers.enchantmentName(enchantment)} ${DiceTiers.materialName(material)} Die';
  }

  static const Map<Enchantment, Map<DiceMaterial, String>> _enchantedNames = {
    Enchantment.ironclad: {
      DiceMaterial.bone:     "The Sentinel's Knuckle",
      DiceMaterial.stone:    "The Warden's Mark",
      DiceMaterial.iron:     "The Knight's Oath",
      DiceMaterial.bronze:   "The Bastion",
      DiceMaterial.gold:     "The Gilded Bulwark",
      DiceMaterial.jade:     "The Jade Rampart",
      DiceMaterial.crystal:  "The Crystal Aegis",
      DiceMaterial.obsidian: "The Black Garrison",
    },
    Enchantment.miserTouch: {
      DiceMaterial.iron:     "The Tax Collector",
      DiceMaterial.bronze:   "The Merchant's Tithe",
      DiceMaterial.gold:     "The Midas Bone",
      DiceMaterial.jade:     "The Emerald Purse",
      DiceMaterial.crystal:  "The Diamond Treasury",
      DiceMaterial.obsidian: "The Obsidian Coffer",
    },
    Enchantment.stubborn: {
      DiceMaterial.iron:     "The Immovable",
      DiceMaterial.bronze:   "The Resolute",
      DiceMaterial.gold:     "The Sovereign's Will",
      DiceMaterial.jade:     "The Rooted Stone",
      DiceMaterial.crystal:  "The Eternal Facet",
      DiceMaterial.obsidian: "The Stubborn Dark",
    },
    Enchantment.gamblersEdge: {
      DiceMaterial.bone:     "The Rogue's Favor",
      DiceMaterial.stone:    "The Lucky Stone",
      DiceMaterial.iron:     "The Brigand's Coin",
      DiceMaterial.bronze:   "The Hustler's Bronze",
      DiceMaterial.gold:     "The Fortune's Kiss",
      DiceMaterial.jade:     "The Serpent's Eye",
      DiceMaterial.crystal:  "The Glass Gambit",
      DiceMaterial.obsidian: "The Midnight Wager",
    },
    Enchantment.boneCollector: {
      DiceMaterial.gold:     "The Reliquary",
      DiceMaterial.jade:     "The Jade Ossuary",
      DiceMaterial.crystal:  "The Crystal Crypt",
      DiceMaterial.obsidian: "The Bone Throne",
    },
    Enchantment.luckyStreak: {
      DiceMaterial.gold:     "The Champion's Streak",
      DiceMaterial.jade:     "The Green Flame",
      DiceMaterial.crystal:  "The Blazing Prism",
      DiceMaterial.obsidian: "The Black Comet",
    },
    Enchantment.secondWind: {
      DiceMaterial.iron:     "The Last Breath",
      DiceMaterial.bronze:   "The Second Chance",
      DiceMaterial.gold:     "The Phoenix Bone",
      DiceMaterial.jade:     "The Jade Revival",
      DiceMaterial.crystal:  "The Resurrection",
      DiceMaterial.obsidian: "The Revenant",
    },
    Enchantment.shatter: {
      DiceMaterial.gold:     "The Siege Engine",
      DiceMaterial.jade:     "The Jade Hammer",
      DiceMaterial.crystal:  "The Prismatic Lance",
      DiceMaterial.obsidian: "The Doombreaker",
    },
    Enchantment.forge: {
      DiceMaterial.crystal:  "The Sovereign's Forge",
      DiceMaterial.obsidian: "The Obsidian Anvil",
    },
    Enchantment.phantom: {
      DiceMaterial.gold:     "The Ghost Crown",
      DiceMaterial.jade:     "The Wraith Jade",
      DiceMaterial.crystal:  "The Phantom Glass",
      DiceMaterial.obsidian: "The Shade's Die",
    },
    Enchantment.echo: {
      DiceMaterial.crystal:  "The Echoing Prism",
      DiceMaterial.obsidian: "The Void Mirror",
    },
  };
}
