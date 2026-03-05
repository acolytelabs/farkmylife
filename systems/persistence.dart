import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fark_my_life/core/enums.dart';
import 'package:fark_my_life/models/models.dart';
import 'package:fark_my_life/models/dice_tiers.dart';
import 'package:fark_my_life/models/game_history.dart';

/// Handles saving and loading game state to shared_preferences.
class GamePersistence {
  GamePersistence._();

  static const _keyPlayerGold = 'player_gold';
  static const _keyPlayerWins = 'player_wins';
  static const _keyPlayerLosses = 'player_losses';
  static const _keyPlayerDice = 'player_dice';
  static const _keyPlayerLoadouts = 'player_loadouts';
  static const _keyActiveLoadout = 'player_active_loadout';
  static const _keyPlayerHistory = 'player_history';
  static const _keyHasSave = 'has_save';

  /// Check if a save exists.
  static Future<bool> hasSave() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyHasSave) ?? false;
  }

  /// Save player data.
  static Future<void> savePlayer(PlayerData player) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHasSave, true);
    await prefs.setInt(_keyPlayerGold, player.gold);
    await prefs.setInt(_keyPlayerWins, player.wins);
    await prefs.setInt(_keyPlayerLosses, player.losses);

    // Serialize dice collection
    final diceJson = player.dice.map((d) => _serializeDie(d)).toList();
    await prefs.setString(_keyPlayerDice, jsonEncode(diceJson));

    // Serialize loadouts
    final loadoutsJson = player.loadouts.map((l) => l.toJson()).toList();
    await prefs.setString(_keyPlayerLoadouts, jsonEncode(loadoutsJson));
    await prefs.setInt(_keyActiveLoadout, player.activeLoadoutIndex);

    // Serialize play history
    await prefs.setString(_keyPlayerHistory, jsonEncode(player.history.toJson()));
  }

  /// Load player data into an existing PlayerData object.
  /// Returns true if save was found and loaded.
  static Future<bool> loadPlayer(PlayerData player) async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(_keyHasSave) ?? false)) return false;

    player.gold = prefs.getInt(_keyPlayerGold) ?? player.gold;
    player.wins = prefs.getInt(_keyPlayerWins) ?? player.wins;
    player.losses = prefs.getInt(_keyPlayerLosses) ?? player.losses;

    final diceStr = prefs.getString(_keyPlayerDice);
    if (diceStr != null) {
      try {
        final List<dynamic> diceJson = jsonDecode(diceStr);
        player.dice = diceJson.map((j) => _deserializeDie(j)).toList();
      } catch (_) {}
    }

    // Load loadouts
    final loadoutsStr = prefs.getString(_keyPlayerLoadouts);
    if (loadoutsStr != null) {
      try {
        final List<dynamic> loadoutsJson = jsonDecode(loadoutsStr);
        player.loadouts = loadoutsJson.map((j) => DiceLoadout.fromJson(j)).toList();
      } catch (_) {}
    }
    player.activeLoadoutIndex = prefs.getInt(_keyActiveLoadout) ?? 0;
    if (player.activeLoadoutIndex >= player.loadouts.length) {
      player.activeLoadoutIndex = 0;
    }

    // Rebuild default loadout to ensure it reflects current collection
    player.rebuildDefaultLoadout();

    // Load play history
    final historyStr = prefs.getString(_keyPlayerHistory);
    if (historyStr != null) {
      try { player.history = PlayHistory.fromJson(jsonDecode(historyStr)); } catch (_) {}
    }

    return true;
  }

  /// Clear all saved data.
  static Future<void> clearSave() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyHasSave);
    await prefs.remove(_keyPlayerGold);
    await prefs.remove(_keyPlayerWins);
    await prefs.remove(_keyPlayerLosses);
    await prefs.remove(_keyPlayerDice);
  }

  // ── Serialization helpers ──────────────────────────────────────────

  static Map<String, dynamic> _serializeDie(DiceItem die) {
    return {
      'material': die.material.index,
      'enchantment': die.enchantment?.index,
    };
  }

  static DiceItem _deserializeDie(dynamic json) {
    if (json is Map<String, dynamic>) {
      final matIdx = json['material'] as int? ?? 0;
      final enchIdx = json['enchantment'] as int?;

      final mat = matIdx < DiceMaterial.values.length
          ? DiceMaterial.values[matIdx]
          : DiceMaterial.oak;

      Enchantment? ench;
      if (enchIdx != null && enchIdx < Enchantment.values.length) {
        ench = Enchantment.values[enchIdx];
      }

      return DiceItem.fromMaterial(mat, enchantment: ench);
    }

    // Legacy format: try to migrate old DiceType-based saves
    if (json is Map && json.containsKey('type')) {
      return _migrateLegacyDie(json);
    }

    return DiceItem.wooden;
  }

  /// Migrate old DiceType-based saves to new material system.
  static DiceItem _migrateLegacyDie(Map json) {
    final typeIdx = json['type'] as int? ?? 0;
    // Old DiceType order: wooden, iron, bone, jade, golden, crystal, shadow, royal, dragon
    switch (typeIdx) {
      case 0: return DiceItem.fromMaterial(DiceMaterial.oak);
      case 1: return DiceItem.fromMaterial(DiceMaterial.iron);
      case 2: return DiceItem.fromMaterial(DiceMaterial.bone);
      case 3: return DiceItem.fromMaterial(DiceMaterial.jade);
      case 4: return DiceItem.fromMaterial(DiceMaterial.gold, enchantment: Enchantment.miserTouch);
      case 5: return DiceItem.fromMaterial(DiceMaterial.crystal, enchantment: Enchantment.secondWind);
      case 6: return DiceItem.fromMaterial(DiceMaterial.bronze, enchantment: Enchantment.boneCollector);
      case 7: return DiceItem.fromMaterial(DiceMaterial.gold, enchantment: Enchantment.luckyStreak);
      case 8: return DiceItem.fromMaterial(DiceMaterial.obsidian, enchantment: Enchantment.echo);
      default: return DiceItem.wooden;
    }
  }
}
