import 'dart:math';
import 'package:fark_my_life/core/constants.dart';
import 'package:fark_my_life/core/enums.dart';
import 'package:fark_my_life/models/models.dart';
import 'package:fark_my_life/models/dice_tiers.dart';

/// Result of scoring a set of dice.
class ScoreResult {
  final int score;
  final List<int> scoringIndices; // which dice contributed
  final String description;
  final bool isHotDice; // all dice scored

  const ScoreResult({
    required this.score,
    required this.scoringIndices,
    required this.description,
    this.isHotDice = false,
  });

  static const ScoreResult farkle = ScoreResult(
    score: 0,
    scoringIndices: [],
    description: 'BUST!',
  );
}

/// Core Farkle scoring engine with dice bonus support.
class FarkleEngine {
  FarkleEngine._();

  /// Score the currently selected dice. Returns 0 if invalid selection.
  static ScoreResult scoreSelectedDice(List<FarkleDie> allDice) {
    final selected = <FarkleDie>[];
    final selectedIndices = <int>[];

    for (int i = 0; i < allDice.length; i++) {
      if (allDice[i].selected && !allDice[i].locked) {
        selected.add(allDice[i]);
        selectedIndices.add(i);
      }
    }

    if (selected.isEmpty) {
      return const ScoreResult(score: 0, scoringIndices: [], description: '');
    }

    final values = selected.map((d) => d.value).toList()..sort();
    final items = selected.map((d) => d.item).toList();

    return _calculateScore(values, items, selectedIndices);
  }

  /// Check if ANY scoring dice exist in the rolled (non-held, non-locked) dice.
  /// Returns true if at least one die can score.
  static bool hasAnyScoringDice(List<FarkleDie> allDice) {
    final available = <int>[];
    for (final d in allDice) {
      if (!d.held && !d.locked) {
        available.add(d.value);
      }
    }
    if (available.isEmpty) return false;

    // Check for 1s or 5s
    if (available.contains(1) || available.contains(5)) return true;

    // Check for three-of-a-kind
    final counts = _countValues(available);
    for (final count in counts.values) {
      if (count >= 3) return true;
    }

    // Check for straight (exactly 6 dice, 1-2-3-4-5-6)
    if (available.length == 6) {
      final sorted = List<int>.from(available)..sort();
      if (sorted[0] == 1 && sorted[1] == 2 && sorted[2] == 3 &&
          sorted[3] == 4 && sorted[4] == 5 && sorted[5] == 6) {
        return true;
      }
    }

    // Check for three pairs (exactly 6 dice)
    if (available.length == 6) {
      final sortedCounts = counts.values.toList()..sort();
      if (sortedCounts.length == 3 &&
          sortedCounts.every((c) => c == 2)) {
        return true;
      }
    }

    return false;
  }

  /// Score all available (non-held, non-locked) dice to check for Farkle.
  static ScoreResult scoreAllAvailable(List<FarkleDie> allDice) {
    final available = <FarkleDie>[];
    final indices = <int>[];
    for (int i = 0; i < allDice.length; i++) {
      if (!allDice[i].held && !allDice[i].locked) {
        available.add(allDice[i]);
        indices.add(i);
      }
    }

    if (available.isEmpty) {
      return ScoreResult.farkle;
    }

    final values = available.map((d) => d.value).toList()..sort();
    final items = available.map((d) => d.item).toList();

    return _calculateScore(values, items, indices);
  }

  /// Calculate score for a set of dice values with tier and enchantment bonuses.
  static ScoreResult _calculateScore(
      List<int> values, List<DiceItem> items, List<int> indices) {
    final n = values.length;
    final counts = _countValues(values);
    int totalScore = 0;
    final descriptions = <String>[];
    final scoringIdx = <int>{};

    // ── Check special combos first (require all 6 dice) ──────

    // Straight: 1-2-3-4-5-6
    if (n == 6) {
      final sorted = List<int>.from(values)..sort();
      if (sorted[0] == 1 && sorted[1] == 2 && sorted[2] == 3 &&
          sorted[3] == 4 && sorted[4] == 5 && sorted[5] == 6) {
        scoringIdx.addAll(indices);
        return ScoreResult(
          score: 1500,
          scoringIndices: scoringIdx.toList(),
          description: 'STRAIGHT! 1500',
          isHotDice: true,
        );
      }

      // Three pairs
      final sortedCounts = counts.values.toList()..sort();
      if (sortedCounts.length == 3 && sortedCounts.every((c) => c == 2)) {
        scoringIdx.addAll(indices);
        return ScoreResult(
          score: 1500,
          scoringIndices: scoringIdx.toList(),
          description: 'THREE PAIRS! 1500',
          isHotDice: true,
        );
      }
    }

    // ── N-of-a-kind ──────────────────────────────────────────

    final usedValues = <int>{};

    for (final entry in counts.entries) {
      final face = entry.key;
      final count = entry.value;

      if (count >= 3) {
        usedValues.add(face);

        // Base triple score
        int tripleScore;
        if (face == 1) {
          tripleScore = 1000;
        } else {
          tripleScore = face * 100;
        }

        // Shadow/Obsidian enchantment: Bone Collector — triples involving this die +50
        for (int i = 0; i < values.length; i++) {
          if (values[i] == face && items[i].enchantment == Enchantment.boneCollector) {
            tripleScore += 50;
            descriptions.add('+50 Bone Collector');
            break;
          }
        }

        // Tier V (Legendary): triples gain +25
        for (int i = 0; i < values.length; i++) {
          if (values[i] == face && items[i].tier == DiceTier.legendary) {
            tripleScore += 25;
            descriptions.add('+25 Legendary');
            break;
          }
        }

        // Jade die (via backward compat type): +100 for three-of-a-kind
        for (int i = 0; i < values.length; i++) {
          if (values[i] == face && items[i].type == DiceType.jade) {
            tripleScore += 100;
            descriptions.add('+100 Jade');
            break;
          }
        }

        // Multiplier for 4/5/6 of a kind
        switch (count) {
          case 4: tripleScore *= 2; break;
          case 5: tripleScore *= 4; break;
          case 6: tripleScore *= 8; break;
        }

        totalScore += tripleScore;
        descriptions.add('${count}x $face = $tripleScore');

        // Mark scoring indices
        int marked = 0;
        for (int i = 0; i < values.length; i++) {
          if (values[i] == face && marked < count) {
            scoringIdx.add(indices[i]);
            marked++;
          }
        }
      }
    }

    // ── Single 1s and 5s (not already counted in triples) ────

    for (int i = 0; i < values.length; i++) {
      if (usedValues.contains(values[i])) continue;

      if (values[i] == 1) {
        // Base 100; Tier III (Iron/Bronze) via compat: 150; Tier IV (Epic): 110
        int score = 100;
        if (items[i].type == DiceType.iron) {
          score = 150; // Iron/Bronze backward compat
        } else if (items[i].tier == DiceTier.epic) {
          score = 110; // Tier IV score bump
        }
        totalScore += score;
        scoringIdx.add(indices[i]);
        if (score != 100) descriptions.add('1 = $score');
      } else if (values[i] == 5) {
        // Base 50; Tier II (Bone) via compat: 75; Tier IV (Epic): 55
        int score = 50;
        if (items[i].type == DiceType.bone) {
          score = 75; // Bone backward compat
        } else if (items[i].tier == DiceTier.epic) {
          score = 55; // Tier IV score bump
        }
        totalScore += score;
        scoringIdx.add(indices[i]);
        if (score != 50) descriptions.add('5 = $score');
      }
    }

    // ── Ironclad enchantment: +10 per scoring combo involving this die ──
    for (int i = 0; i < values.length; i++) {
      if (scoringIdx.contains(indices[i]) && items[i].enchantment == Enchantment.ironclad) {
        totalScore += 10;
      }
    }

    // ── Gambler's Edge: +50 to first scoring combo if turn score was 0 ──
    // (handled at the keepSelectedDice level, not here — needs turn context)

    // Check if non-scoring dice remain
    if (scoringIdx.isEmpty) {
      return ScoreResult.farkle;
    }

    final isHotDice = scoringIdx.length == n && n == 6;

    return ScoreResult(
      score: totalScore,
      scoringIndices: scoringIdx.toList(),
      description: descriptions.join(' + '),
      isHotDice: isHotDice,
    );
  }

  static Map<int, int> _countValues(List<int> values) {
    final counts = <int, int>{};
    for (final v in values) {
      counts[v] = (counts[v] ?? 0) + 1;
    }
    return counts;
  }

  // ═══════════════════════════════════════════════════════════════════
  // NPC AI
  // ═══════════════════════════════════════════════════════════════════

  /// NPC decides which dice to select. Skill affects combo detection.
  static List<int> npcSelectDice(List<FarkleDie> dice, Personality personality, {double skill = 0.85}) {
    final rng = Random();
    final available = <int, FarkleDie>{};
    for (int i = 0; i < dice.length; i++) {
      if (!dice[i].held && !dice[i].locked) {
        available[i] = dice[i];
      }
    }

    final values = available.values.map((d) => d.value).toList();
    final counts = _countValues(values);
    final selections = <int>[];

    // Check for straights and three-pairs (6-dice combos) — skill-gated
    if (available.length == 6) {
      final sorted = List<int>.from(values)..sort();
      final isStraight = sorted[0] == 1 && sorted[1] == 2 && sorted[2] == 3 &&
          sorted[3] == 4 && sorted[4] == 5 && sorted[5] == 6;
      final sortedCounts = counts.values.toList()..sort();
      final isThreePairs = sortedCounts.length == 3 && sortedCounts.every((c) => c == 2);

      // High-skill NPCs notice these; low-skill may miss them
      if (isStraight && rng.nextDouble() < skill) {
        return available.keys.toList(); // take all 6
      }
      if (isThreePairs && rng.nextDouble() < skill * 0.9) {
        return available.keys.toList(); // take all 6
      }
    }

    // Take triples+ (very rarely missed — only extremely low skill)
    for (final entry in counts.entries) {
      if (entry.value >= 3) {
        if (rng.nextDouble() < skill * 1.1) { // almost always noticed
          int taken = 0;
          for (final idx in available.keys) {
            if (available[idx]!.value == entry.key && taken < entry.value) {
              selections.add(idx);
              taken++;
            }
          }
        }
      }
    }

    // Take 1s and 5s not already in triples — skill affects noticing stray 5s
    final tripleValues = counts.entries
        .where((e) => e.value >= 3)
        .map((e) => e.key)
        .toSet();

    for (final idx in available.keys) {
      if (selections.contains(idx)) continue;
      final val = available[idx]!.value;
      if (tripleValues.contains(val)) continue;
      if (val == 1) {
        // 1s are always noticed (too valuable to miss)
        selections.add(idx);
      } else if (val == 5) {
        // 5s occasionally missed by low-skill NPCs
        if (rng.nextDouble() < skill + 0.15) {
          selections.add(idx);
        }
      }
    }

    // If we somehow selected nothing but there ARE scoring dice, take at least a 1 or 5
    if (selections.isEmpty) {
      for (final idx in available.keys) {
        final val = available[idx]!.value;
        if (val == 1 || val == 5) { selections.add(idx); break; }
      }
    }

    return selections;
  }

  /// NPC decides whether to roll again or bank.
  static bool npcShouldContinue(
    int turnScore,
    int bankScore,
    int opponentScore,
    int diceRemaining,
    Personality personality, {
    int targetScore = 4000,
  }) {
    final target = targetScore;

    // If banking would win, always bank
    if (bankScore + turnScore >= target) return false;

    // Hard safety floors - never risk big scores on few dice
    if (turnScore >= 800) return false;
    if (turnScore >= 500 && diceRemaining <= 2) return false;
    if (turnScore >= 300 && diceRemaining <= 1) return false;

    // Bust probabilities by dice count (mathematical)
    const bustProb = <int, double>{
      1: 0.667, 2: 0.444, 3: 0.278, 4: 0.157, 5: 0.077, 6: 0.023,
    };
    // Average gain per non-bust roll
    const avgGain = <int, double>{
      1: 83, 2: 125, 3: 175, 4: 225, 5: 275, 6: 350,
    };

    final dice = diceRemaining.clamp(1, 6);
    final pBust = bustProb[dice] ?? 0.5;
    final gain = avgGain[dice] ?? 150.0;

    // Personality risk tolerance
    final riskTolerance = personality == Personality.cautious
        ? 0.6 : personality == Personality.bold ? 1.4 : 1.0;

    // Expected value calculation
    final evGain = gain * (1.0 - pBust) * riskTolerance;
    final evLoss = pBust * turnScore;

    // Situational adjustments
    double modifier = 1.0;
    // Desperate: far behind with low turn score - push harder
    if (bankScore < opponentScore - 800 && turnScore < 400) {
      modifier = 1.6;
    }
    // Comfortable lead - bank earlier
    if (bankScore > opponentScore + 600 && turnScore >= 200) {
      modifier = 0.6;
    }

    return evGain * modifier > evLoss;
  }

  // ═══════════════════════════════════════════════════════════════════
  // GAME FLOW HELPERS
  // ═══════════════════════════════════════════════════════════════════

  /// Roll all non-held, non-locked dice.
  static void rollDice(FarkleGameState game, Random rng) {
    for (final d in game.dice) {
      d.roll(rng);
    }
    game.rollsThisTurn++;
  }

  /// Lock selected dice (keep them for scoring) and add to turn score.
  static ScoreResult keepSelectedDice(FarkleGameState game) {
    final result = scoreSelectedDice(game.dice);
    if (result.score > 0) {
      game.turnScore += result.score;

      // Lock the selected dice
      for (final d in game.dice) {
        if (d.selected) {
          d.held = true;
          d.locked = true;
          d.selected = false;
        }
      }

      // Check for hot dice (all 6 locked)
      if (game.dice.every((d) => d.locked)) {
        game.hotDice = true;
        // Reset all dice for another roll
        for (final d in game.dice) {
          d.held = false;
          d.locked = false;
          d.selected = false;
        }
      }
    }
    return result;
  }

  /// Bank the current turn score and switch turns.
  static void bankScore(FarkleGameState game) {
    int bankBonus = 0;

    // Miser's Touch enchantment: +15 when banking per Miser die
    for (final d in game.dice) {
      if (d.item.enchantment == Enchantment.miserTouch && d.locked) {
        bankBonus += 15;
      }
    }

    // Golden die backward compat (maps to Miser's Touch): +50 when banking
    for (final d in game.dice) {
      if (d.item.type == DiceType.golden && d.locked && d.item.enchantment != Enchantment.miserTouch) {
        bankBonus += 50;
      }
    }

    // Dragon die / Hot dice bonus: +500 on hot dice
    if (game.hotDice) {
      for (final d in game.dice) {
        if (d.item.type == DiceType.dragon) {
          bankBonus += 500;
        }
      }
    }

    final totalTurnScore = game.turnScore + bankBonus;
    game.setCurrentPlayerScore(game.currentPlayerScore + totalTurnScore);

    // Check win condition
    if (game.currentPlayerScore >= game.targetScore) {
      game.winnerId = game.currentPlayerId;
      game.phase = FarklePhase.gameOver;
      return;
    }

    game.switchTurn();
  }

  /// Apply Farkle (lose turn score, switch turns).
  static void applyFarkle(FarkleGameState game) {
    game.farkled = true;
    game.turnScore = 0;

    // Second Wind enchantment: free re-roll on Bust (once per game)
    // Also handles Crystal die backward compat
    if (!game.crystalUsed) {
      bool hasSecondWind = false;
      for (final d in game.dice) {
        if (d.item.enchantment == Enchantment.secondWind ||
            d.item.type == DiceType.crystal) {
          hasSecondWind = true;
          break;
        }
      }
      if (hasSecondWind) {
        game.crystalUsed = true;
        game.farkled = false;
        game.statusMessage = 'Second Wind! Roll again!';
        return;
      }
    }

    game.switchTurn();
  }

  // ═══════════════════════════════════════════════════════════════════
  // ACTIVE ENCHANTMENT ABILITIES
  // ═══════════════════════════════════════════════════════════════════

  /// Forge: set a specific die to any value (1/game, Tier V only).
  static bool useForge(FarkleGameState game, int dieIndex, int desiredValue) {
    if (dieIndex < 0 || dieIndex >= game.dice.length) return false;
    final die = game.dice[dieIndex];
    if (die.item.enchantment != Enchantment.forge) return false;
    if (game.usedEnchantments.contains(Enchantment.forge)) return false;
    if (die.held || die.locked) return false;
    if (desiredValue < 1 || desiredValue > 6) return false;

    die.value = desiredValue;
    game.usedEnchantments.add(Enchantment.forge);
    game.statusMessage = 'Forge: die set to $desiredValue!';
    return true;
  }

  /// Phantom: score a die as if it shows 1 (2/game, Tier IV+).
  static bool usePhantom(FarkleGameState game, int dieIndex) {
    if (dieIndex < 0 || dieIndex >= game.dice.length) return false;
    final die = game.dice[dieIndex];
    if (die.item.enchantment != Enchantment.phantom) return false;
    final useCount = game.usedEnchantments.where((e) => e == Enchantment.phantom).length;
    if (useCount >= 2) return false;
    if (die.held || die.locked) return false;

    die.value = 1; // Override to show as 1
    game.usedEnchantments.add(Enchantment.phantom);
    game.statusMessage = 'Phantom: die becomes a 1!';
    return true;
  }

  /// Shatter: opponent rolls 5 dice next turn (1/game, Tier IV+).
  /// Applied when banking — reduces opponent's next roll to 5 dice.
  static bool useShatter(FarkleGameState game) {
    if (game.usedEnchantments.contains(Enchantment.shatter)) return false;
    bool hasShatter = false;
    for (final d in game.dice) {
      if (d.item.enchantment == Enchantment.shatter && d.locked) {
        hasShatter = true;
        break;
      }
    }
    if (!hasShatter) return false;

    game.usedEnchantments.add(Enchantment.shatter);
    game.statusMessage = 'Shatter! Opponent loses a die next turn!';
    // The actual reduction is handled by checking usedEnchantments in switchTurn
    return true;
  }

  /// Echo: double the score of the last kept combination (1/game, Tier V).
  static bool useEcho(FarkleGameState game, int lastKeptScore) {
    if (game.usedEnchantments.contains(Enchantment.echo)) return false;
    bool hasEcho = false;
    for (final d in game.dice) {
      if (d.item.enchantment == Enchantment.echo && d.locked) {
        hasEcho = true;
        break;
      }
    }
    if (!hasEcho) return false;

    game.turnScore += lastKeptScore;
    game.usedEnchantments.add(Enchantment.echo);
    game.statusMessage = 'Echo! Score doubled: +$lastKeptScore!';
    return true;
  }
}
