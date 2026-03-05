import 'dart:convert';
import 'dart:math';

// ═══════════════════════════════════════════════════════════════════════
// GAME HISTORY & STATS
// ═══════════════════════════════════════════════════════════════════════

/// Record of a single completed game.
class GameRecord {
  final String opponentId;
  final String opponentName;
  final bool won;
  final int betAmount;
  final int playerScore;
  final int opponentScore;
  final int targetScore;
  final bool wasTournament;
  final String? tournamentName;
  final DateTime playedAt;

  GameRecord({
    required this.opponentId,
    required this.opponentName,
    required this.won,
    required this.betAmount,
    required this.playerScore,
    required this.opponentScore,
    this.targetScore = 4000,
    this.wasTournament = false,
    this.tournamentName,
    DateTime? playedAt,
  }) : playedAt = playedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'oId': opponentId, 'oName': opponentName, 'won': won,
    'bet': betAmount, 'pScore': playerScore, 'oScore': opponentScore,
    'target': targetScore, 'tourney': wasTournament,
    'tName': tournamentName, 'at': playedAt.millisecondsSinceEpoch,
  };

  factory GameRecord.fromJson(Map<String, dynamic> j) => GameRecord(
    opponentId: j['oId'] ?? '', opponentName: j['oName'] ?? '',
    won: j['won'] ?? false, betAmount: j['bet'] ?? 0,
    playerScore: j['pScore'] ?? 0, opponentScore: j['oScore'] ?? 0,
    targetScore: j['target'] ?? 4000, wasTournament: j['tourney'] ?? false,
    tournamentName: j['tName'],
    playedAt: DateTime.fromMillisecondsSinceEpoch(j['at'] ?? 0),
  );
}

/// Per-opponent stats summary.
class OpponentRecord {
  final String id;
  final String name;
  int wins;
  int losses;
  int goldWon;
  int goldLost;

  OpponentRecord({
    required this.id, required this.name,
    this.wins = 0, this.losses = 0, this.goldWon = 0, this.goldLost = 0,
  });

  int get totalGames => wins + losses;
  double get winRate => totalGames > 0 ? wins / totalGames : 0;
  int get netGold => goldWon - goldLost;

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'w': wins, 'l': losses,
    'gw': goldWon, 'gl': goldLost,
  };

  factory OpponentRecord.fromJson(Map<String, dynamic> j) => OpponentRecord(
    id: j['id'] ?? '', name: j['name'] ?? '',
    wins: j['w'] ?? 0, losses: j['l'] ?? 0,
    goldWon: j['gw'] ?? 0, goldLost: j['gl'] ?? 0,
  );
}

/// Badge definitions.
class Badge {
  final String id;
  final String name;
  final String description;
  final String icon; // emoji/symbol

  const Badge(this.id, this.name, this.description, this.icon);
}

/// All available badges.
class Badges {
  static const firstWin = Badge('first_win', 'First Blood', 'Win your first game', '⚔');
  static const tenWins = Badge('ten_wins', 'Seasoned Roller', 'Win 10 games', '🎲');
  static const fiftyWins = Badge('fifty_wins', 'Dice Master', 'Win 50 games', '👑');
  static const richRoller = Badge('rich', 'Rich Roller', 'Accumulate 500g', '💰');
  static const highRoller = Badge('high_roller', 'High Roller', 'Win a 50g+ bet', '🎰');
  static const legendaryFind = Badge('legendary', 'Legend Found', 'Obtain a Legendary die', '🔮');
  static const tourneyWin = Badge('tourney_win', 'Champion', 'Win a tournament', '🏆');
  static const undefeated = Badge('undefeated', 'Undefeated', 'Win 5 games in a row', '🔥');
  static const collector = Badge('collector', 'Collector', 'Own 15+ dice', '📦');
  static const bustSurvivor = Badge('bust_save', 'Second Wind', 'Survive a bust with enchantment', '💨');
  static const allNpcs = Badge('all_npcs', 'Town Rival', 'Beat every NPC at least once', '🏘');

  static const List<Badge> all = [
    firstWin, tenWins, fiftyWins, richRoller, highRoller,
    legendaryFind, tourneyWin, undefeated, collector, bustSurvivor, allNpcs,
  ];
}

/// Record of a tournament victory.
class TournamentWinRecord {
  final String tournamentName;
  final String prizeDieName;
  final int prizeTierIndex;
  final DateTime wonAt;

  TournamentWinRecord({
    required this.tournamentName,
    required this.prizeDieName,
    required this.prizeTierIndex,
    DateTime? wonAt,
  }) : wonAt = wonAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'name': tournamentName, 'prize': prizeDieName,
    'tier': prizeTierIndex, 'at': wonAt.millisecondsSinceEpoch,
  };

  factory TournamentWinRecord.fromJson(Map<String, dynamic> j) => TournamentWinRecord(
    tournamentName: j['name'] ?? '', prizeDieName: j['prize'] ?? '',
    prizeTierIndex: j['tier'] ?? 0,
    wonAt: DateTime.fromMillisecondsSinceEpoch(j['at'] ?? 0),
  );
}

/// Full play history for a player (or NPC).
class PlayHistory {
  List<GameRecord> recentGames;
  Map<String, OpponentRecord> opponents;
  Set<String> earnedBadges;
  int totalGoldWon;
  int totalGoldLost;
  int longestWinStreak;
  int currentWinStreak;
  int tournamentsEntered;
  int tournamentsWon;
  int highestSingleTurnScore;
  int bustCount;
  int hotDiceCount;
  List<TournamentWinRecord> tournamentWins; // detailed tournament victories

  PlayHistory({
    List<GameRecord>? recentGames,
    Map<String, OpponentRecord>? opponents,
    Set<String>? earnedBadges,
    this.totalGoldWon = 0,
    this.totalGoldLost = 0,
    this.longestWinStreak = 0,
    this.currentWinStreak = 0,
    this.tournamentsEntered = 0,
    this.tournamentsWon = 0,
    this.highestSingleTurnScore = 0,
    this.bustCount = 0,
    this.hotDiceCount = 0,
    List<TournamentWinRecord>? tournamentWins,
  }) : recentGames = recentGames ?? [],
       opponents = opponents ?? {},
       earnedBadges = earnedBadges ?? {},
       tournamentWins = tournamentWins ?? [];

  /// Record a completed game.
  void recordGame(GameRecord game) {
    recentGames.add(game);
    if (recentGames.length > 50) recentGames.removeAt(0);

    // Update per-opponent record
    final opp = opponents.putIfAbsent(game.opponentId,
        () => OpponentRecord(id: game.opponentId, name: game.opponentName));
    if (game.won) {
      opp.wins++;
      opp.goldWon += game.betAmount;
      totalGoldWon += game.betAmount;
      currentWinStreak++;
      if (currentWinStreak > longestWinStreak) longestWinStreak = currentWinStreak;
    } else {
      opp.losses++;
      opp.goldLost += game.betAmount;
      totalGoldLost += game.betAmount;
      currentWinStreak = 0;
    }

    // Check badges
    _checkBadges();
  }

  void recordTurnScore(int score) {
    if (score > highestSingleTurnScore) highestSingleTurnScore = score;
  }

  void recordBust() => bustCount++;
  void recordHotDice() => hotDiceCount++;

  void _checkBadges() {
    final totalWins = opponents.values.fold<int>(0, (s, o) => s + o.wins);
    if (totalWins >= 1) earnedBadges.add(Badges.firstWin.id);
    if (totalWins >= 10) earnedBadges.add(Badges.tenWins.id);
    if (totalWins >= 50) earnedBadges.add(Badges.fiftyWins.id);
    if (currentWinStreak >= 5) earnedBadges.add(Badges.undefeated.id);
    if (tournamentsWon >= 1) earnedBadges.add(Badges.tourneyWin.id);
  }

  void checkCollectionBadges(int diceCount, int gold, bool hasLegendary, int npcCount, int npcsBeaten) {
    if (gold >= 50) earnedBadges.add(Badges.richRoller.id);
    if (diceCount >= 15) earnedBadges.add(Badges.collector.id);
    if (hasLegendary) earnedBadges.add(Badges.legendaryFind.id);
    if (npcsBeaten >= npcCount) earnedBadges.add(Badges.allNpcs.id);
  }

  int get totalWins => opponents.values.fold<int>(0, (s, o) => s + o.wins);
  int get totalLosses => opponents.values.fold<int>(0, (s, o) => s + o.losses);
  int get totalGames => totalWins + totalLosses;
  double get winRate => totalGames > 0 ? totalWins / totalGames : 0;
  int get netGold => totalGoldWon - totalGoldLost;

  // Serialization
  Map<String, dynamic> toJson() => {
    'games': recentGames.map((g) => g.toJson()).toList(),
    'opps': opponents.map((k, v) => MapEntry(k, v.toJson())),
    'badges': earnedBadges.toList(),
    'gw': totalGoldWon, 'gl': totalGoldLost,
    'streak': longestWinStreak, 'cStreak': currentWinStreak,
    'tEntered': tournamentsEntered, 'tWon': tournamentsWon,
    'highTurn': highestSingleTurnScore,
    'busts': bustCount, 'hotDice': hotDiceCount,
    'tWins': tournamentWins.map((w) => w.toJson()).toList(),
  };

  factory PlayHistory.fromJson(Map<String, dynamic> j) {
    final games = (j['games'] as List?)
        ?.map((g) => GameRecord.fromJson(g)).toList() ?? [];
    final opps = (j['opps'] as Map<String, dynamic>?)
        ?.map((k, v) => MapEntry(k, OpponentRecord.fromJson(v))) ?? {};
    final tWins = (j['tWins'] as List?)
        ?.map((w) => TournamentWinRecord.fromJson(w)).toList() ?? [];
    return PlayHistory(
      recentGames: games,
      opponents: opps,
      earnedBadges: Set<String>.from(j['badges'] ?? []),
      totalGoldWon: j['gw'] ?? 0,
      totalGoldLost: j['gl'] ?? 0,
      longestWinStreak: j['streak'] ?? 0,
      currentWinStreak: j['cStreak'] ?? 0,
      tournamentsEntered: j['tEntered'] ?? 0,
      tournamentsWon: j['tWon'] ?? 0,
      highestSingleTurnScore: j['highTurn'] ?? 0,
      bustCount: j['busts'] ?? 0,
      hotDiceCount: j['hotDice'] ?? 0,
      tournamentWins: tWins,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// TOURNAMENT NAME GENERATOR
// ═══════════════════════════════════════════════════════════════════════

class TournamentNames {
  TournamentNames._();

  static const _prefixes = [
    'The Grand', 'The Royal', 'The Noble', 'The Honored',
    'The Gallant', 'The Valiant', 'The Sovereign', 'The August',
    'The Hallowed', 'The Illustrious', 'The Exalted', 'The Esteemed',
  ];

  static const _themes = [
    'Tourney', 'Joust', 'Trial', 'Challenge', 'Contest',
    'Invitational', 'Championship', 'Gauntlet', 'Crucible',
    'Proving', 'Reckoning', 'Ordeal',
  ];

  static const _ofThings = [
    'of the Crown', 'of the Realm', 'of the Keep', 'of the Throne',
    'of Valor', 'of Fortune', 'of Honor', 'of the Rose',
    'of the Chalice', 'of the Iron Gate', 'of Bones and Gold',
    'of the Silver Hand', 'of the Crimson Banner', 'of Dawn',
    'of the Ashen Table', 'of the Last Stand', 'of the Old Guard',
    'of Whispered Odds', 'of the Fallen Dice', 'of the Gilded Stag',
  ];

  static const _seasons = [
    'Spring', 'Summer', 'Autumn', 'Winter',
    'Harvest', 'Midwinter', 'Midsummer', 'Solstice',
  ];

  /// Generate a random tournament name.
  static String generate(Random rng, int tournamentNumber) {
    final style = rng.nextInt(4);
    switch (style) {
      case 0:
        // "The Grand Tourney of the Crown"
        return '${_prefixes[rng.nextInt(_prefixes.length)]} '
            '${_themes[rng.nextInt(_themes.length)]} '
            '${_ofThings[rng.nextInt(_ofThings.length)]}';
      case 1:
        // "The Autumn Reckoning"
        return 'The ${_seasons[rng.nextInt(_seasons.length)]} '
            '${_themes[rng.nextInt(_themes.length)]}';
      case 2:
        // "Tourney of Honor III"
        final roman = _toRoman(tournamentNumber);
        return '${_themes[rng.nextInt(_themes.length)]} '
            '${_ofThings[rng.nextInt(_ofThings.length)]} $roman';
      default:
        // "The Hallowed Gauntlet"
        return '${_prefixes[rng.nextInt(_prefixes.length)]} '
            '${_themes[rng.nextInt(_themes.length)]}';
    }
  }

  static String _toRoman(int n) {
    if (n <= 0) return '';
    final vals = [100, 90, 50, 40, 10, 9, 5, 4, 1];
    final syms = ['C', 'XC', 'L', 'XL', 'X', 'IX', 'V', 'IV', 'I'];
    var result = '';
    var remaining = n;
    for (int i = 0; i < vals.length; i++) {
      while (remaining >= vals[i]) {
        result += syms[i];
        remaining -= vals[i];
      }
    }
    return result;
  }
}
