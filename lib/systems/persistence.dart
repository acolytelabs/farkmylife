import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fark_my_life/core/enums.dart';
import 'package:fark_my_life/models/models.dart';
import 'package:fark_my_life/models/dice_tiers.dart';
import 'package:fark_my_life/models/game_history.dart';

/// Handles saving and loading game state to shared_preferences.
/// Forward-compatible: new fields use defaults when missing from old saves.
/// Each field loads independently — corrupt data in one field doesn't lose others.
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
    return (prefs.getBool(_keyHasSave) ?? false) ||
           prefs.containsKey(_keyPlayerGold);
  }

  /// Save player data. Always writes all fields.
  static Future<void> savePlayer(PlayerData player) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHasSave, true);
    await prefs.setInt(_keyPlayerGold, player.gold);
    await prefs.setInt(_keyPlayerWins, player.wins);
    await prefs.setInt(_keyPlayerLosses, player.losses);

    final diceJson = player.dice.map((d) => _serializeDie(d)).toList();
    await prefs.setString(_keyPlayerDice, jsonEncode(diceJson));

    final loadoutsJson = player.loadouts.map((l) => l.toJson()).toList();
    await prefs.setString(_keyPlayerLoadouts, jsonEncode(loadoutsJson));
    await prefs.setInt(_keyActiveLoadout, player.activeLoadoutIndex);

    await prefs.setString(_keyPlayerHistory, jsonEncode(player.history.toJson()));
  }

  /// Load player data. Each field loads independently with fallbacks.
  static Future<bool> loadPlayer(PlayerData player) async {
    final prefs = await SharedPreferences.getInstance();
    final hasSaveFlag = prefs.getBool(_keyHasSave) ?? false;
    final hasAnyData = prefs.containsKey(_keyPlayerGold);
    if (!hasSaveFlag && !hasAnyData) return false;

    player.gold = prefs.getInt(_keyPlayerGold) ?? player.gold;
    player.wins = prefs.getInt(_keyPlayerWins) ?? player.wins;
    player.losses = prefs.getInt(_keyPlayerLosses) ?? player.losses;

    _tryLoad(prefs, _keyPlayerDice, (str) {
      final List<dynamic> diceJson = jsonDecode(str);
      final loaded = <DiceItem>[];
      for (final j in diceJson) {
        try { loaded.add(_deserializeDie(j)); }
        catch (_) { loaded.add(DiceItem.wooden); }
      }
      if (loaded.isNotEmpty) player.dice = loaded;
    });

    _tryLoad(prefs, _keyPlayerLoadouts, (str) {
      final List<dynamic> json = jsonDecode(str);
      player.loadouts = json.map((j) => DiceLoadout.fromJson(j)).toList();
    });
    player.activeLoadoutIndex = prefs.getInt(_keyActiveLoadout) ?? 0;
    if (player.loadouts.isEmpty) {
      player.loadouts = [DiceLoadout(name: 'Default', diceIndices: [0, 1, 2, 3, 4, 5])];
    }
    if (player.activeLoadoutIndex >= player.loadouts.length) {
      player.activeLoadoutIndex = 0;
    }
    player.rebuildDefaultLoadout();

    _tryLoad(prefs, _keyPlayerHistory, (str) {
      player.history = PlayHistory.fromJson(jsonDecode(str));
    });

    if (!hasSaveFlag) await prefs.setBool(_keyHasSave, true);

    return true;
  }

  static void _tryLoad(SharedPreferences prefs, String key, void Function(String) parser) {
    final str = prefs.getString(key);
    if (str == null) return;
    try { parser(str); } catch (_) {}
  }

  /// Clear all saved data.
  static Future<void> clearSave() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in [_keyHasSave, _keyPlayerGold, _keyPlayerWins, _keyPlayerLosses,
        _keyPlayerDice, _keyPlayerLoadouts, _keyActiveLoadout, _keyPlayerHistory]) {
      await prefs.remove(key);
    }
  }

  static Map<String, dynamic> _serializeDie(DiceItem die) {
    return {
      'material': die.material.index,
      'enchantment': die.enchantment?.index,
    };
  }

  static DiceItem _deserializeDie(dynamic json) {
    if (json is Map<String, dynamic>) {
      final matIdx = json['material'] as int? ?? 1;
      final enchIdx = json['enchantment'] as int?;
      final mat = matIdx < DiceMaterial.values.length
          ? DiceMaterial.values[matIdx] : DiceMaterial.oak;
      Enchantment? ench;
      if (enchIdx != null && enchIdx < Enchantment.values.length) {
        ench = Enchantment.values[enchIdx];
      }
      return DiceItem(material: mat, enchantment: ench);
    }
    return _migrateLegacyDie(json);
  }

  static DiceItem _migrateLegacyDie(dynamic json) {
    if (json is Map) {
      final typeStr = json['type']?.toString() ?? '';
      switch (typeStr) {
        case 'wooden': return DiceItem(material: DiceMaterial.oak);
        case 'iron': return DiceItem(material: DiceMaterial.iron);
        case 'bone': return DiceItem(material: DiceMaterial.bone);
        case 'jade': return DiceItem(material: DiceMaterial.jade);
        case 'golden': return DiceItem(material: DiceMaterial.gold, enchantment: Enchantment.miserTouch);
        case 'crystal': return DiceItem(material: DiceMaterial.crystal, enchantment: Enchantment.secondWind);
        case 'shadow': return DiceItem(material: DiceMaterial.bronze, enchantment: Enchantment.boneCollector);
        case 'royal': return DiceItem(material: DiceMaterial.gold, enchantment: Enchantment.luckyStreak);
        case 'dragon': return DiceItem(material: DiceMaterial.obsidian, enchantment: Enchantment.echo);
      }
    }
    return DiceItem.wooden;
  }
}
