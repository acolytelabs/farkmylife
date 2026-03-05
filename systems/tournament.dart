import 'dart:convert';
import 'dart:math';
import 'dart:ui';
import 'package:fark_my_life/core/constants.dart';
import 'package:fark_my_life/core/enums.dart';
import 'package:fark_my_life/models/models.dart';
import 'package:fark_my_life/models/dice_tiers.dart';
import 'package:fark_my_life/models/game_history.dart';
import 'package:fark_my_life/systems/farkle_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ═══════════════════════════════════════════════════════════════════════
// TOURNAMENT PHASE
// ═══════════════════════════════════════════════════════════════════════

enum TournamentPhase {
  idle,           // No tournament — counter ticking
  announcing,     // 30s countdown, toast fired
  registration,   // 60s — player can enter, NPCs auto-register
  bracketSet,     // Instant — bracket randomized
  round1,         // Quarterfinals (4 matches)
  round2,         // Semifinals (2 matches)
  finalRound,     // Championship (1 match)
  awards,         // 5s — winner announced
}

// ═══════════════════════════════════════════════════════════════════════
// TOURNAMENT MATCH
// ═══════════════════════════════════════════════════════════════════════

class TournamentMatch {
  final String? entrant1Id; // null = bye
  final String? entrant2Id;
  String? winnerId;
  int score1 = 0;
  int score2 = 0;
  bool completed = false;

  TournamentMatch({this.entrant1Id, this.entrant2Id});

  /// True if this match involves the player.
  bool get isPlayerMatch =>
      entrant1Id == 'player' || entrant2Id == 'player';

  /// True if one side is a bye (null).
  bool get isBye => entrant1Id == null || entrant2Id == null;

  /// Resolve a bye instantly.
  void resolveBye() {
    if (!isBye) return;
    winnerId = entrant1Id ?? entrant2Id;
    completed = true;
  }

  Map<String, dynamic> toJson() => {
    'e1': entrant1Id, 'e2': entrant2Id,
    'w': winnerId, 's1': score1, 's2': score2, 'c': completed,
  };

  factory TournamentMatch.fromJson(Map<String, dynamic> j) {
    final m = TournamentMatch(entrant1Id: j['e1'], entrant2Id: j['e2']);
    m.winnerId = j['w'];
    m.score1 = j['s1'] ?? 0;
    m.score2 = j['s2'] ?? 0;
    m.completed = j['c'] ?? false;
    return m;
  }
}

// ═══════════════════════════════════════════════════════════════════════
// TOURNAMENT RECORD (persisted result of a completed tournament)
// ═══════════════════════════════════════════════════════════════════════

class TournamentRecord {
  final String winnerId;
  final String winnerName;
  final DiceItem prizeDie;
  final List<String> entrantIds;
  final List<String> entrantNames;
  final List<TournamentMatch> matches; // 7 matches: QF1-4, SF1-2, Final
  final int tournamentNumber;

  TournamentRecord({
    required this.winnerId,
    required this.winnerName,
    required this.prizeDie,
    required this.entrantIds,
    required this.entrantNames,
    required this.matches,
    required this.tournamentNumber,
  });

  Map<String, dynamic> toJson() => {
    'wId': winnerId, 'wName': winnerName,
    'prize': {'mat': prizeDie.material.index, 'ench': prizeDie.enchantment?.index},
    'eIds': entrantIds, 'eNames': entrantNames,
    'matches': matches.map((m) => m.toJson()).toList(),
    'num': tournamentNumber,
  };

  factory TournamentRecord.fromJson(Map<String, dynamic> j) {
    final prizeJ = j['prize'] as Map<String, dynamic>;
    final mat = DiceMaterial.values[prizeJ['mat'] ?? 1];
    Enchantment? ench;
    if (prizeJ['ench'] != null) ench = Enchantment.values[prizeJ['ench']];

    return TournamentRecord(
      winnerId: j['wId'] ?? '',
      winnerName: j['wName'] ?? '',
      prizeDie: DiceItem(material: mat, enchantment: ench),
      entrantIds: List<String>.from(j['eIds'] ?? []),
      entrantNames: List<String>.from(j['eNames'] ?? []),
      matches: (j['matches'] as List?)
          ?.map((m) => TournamentMatch.fromJson(m))
          .toList() ?? [],
      tournamentNumber: j['num'] ?? 0,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// TOURNAMENT MANAGER
// ═══════════════════════════════════════════════════════════════════════

class TournamentManager {
  static const int gamesToTrigger = 5;
  static const int entryFee = 15;
  static const double announceDuration = 30.0;
  static const double registrationDuration = 60.0;
  static const double npcMatchDuration = 4.0; // seconds per NPC match
  static const double awardsDuration = 5.0;

  final Random _rng = Random();

  // ── Current state ──────────────────────────────────────────────────
  TournamentPhase phase = TournamentPhase.idle;
  double phaseTimer = 0;
  int gameCounter = 0; // games since last tournament

  // ── Active tournament data ─────────────────────────────────────────
  List<String> entrantIds = [];     // 8 slots (may contain 'player')
  List<String> entrantNames = [];   // parallel display names
  List<TournamentMatch> matches = []; // 7 matches: [QF1,QF2,QF3,QF4, SF1,SF2, FINAL]
  DiceItem? prizeDie;
  String tournamentName = '';
  bool playerRegistered = false;
  bool playerEliminated = false;
  int currentMatchIndex = 0;
  int tournamentCount = 0;

  // ── Last completed tournament ──────────────────────────────────────
  TournamentRecord? lastRecord;

  // ── Callbacks (set by GameShell) ───────────────────────────────────
  void Function(String message, Color? color)? onToast;
  void Function(TournamentMatch match)? onPlayerMatchReady;
  List<NpcData> Function()? getNpcs;
  PlayerData Function()? getPlayer;

  // ═════════════════════════════════════════════════════════════════════
  // GAME COUNTER
  // ═════════════════════════════════════════════════════════════════════

  /// Called after every completed dice game (player or NPC).
  void onGameCompleted() {
    gameCounter++;
    if (phase == TournamentPhase.idle && gameCounter >= gamesToTrigger) {
      _startAnnouncing();
    }
  }

  // ═════════════════════════════════════════════════════════════════════
  // TICK (called from game loop)
  // ═════════════════════════════════════════════════════════════════════

  /// Advance tournament state. Returns true if a state change occurred.
  bool tick(double dt) {
    if (phase == TournamentPhase.idle) return false;

    phaseTimer += dt;
    switch (phase) {
      case TournamentPhase.announcing:
        if (phaseTimer >= announceDuration) {
          _startRegistration();
          return true;
        }
        break;

      case TournamentPhase.registration:
        if (phaseTimer >= registrationDuration) {
          _closeRegistration();
          return true;
        }
        break;

      case TournamentPhase.bracketSet:
        // Instant — advance immediately
        _startRound1();
        return true;

      case TournamentPhase.round1:
      case TournamentPhase.round2:
      case TournamentPhase.finalRound:
        return _tickMatches(dt);

      case TournamentPhase.awards:
        if (phaseTimer >= awardsDuration) {
          _finishTournament();
          return true;
        }
        break;

      default:
        break;
    }
    return false;
  }

  // ═════════════════════════════════════════════════════════════════════
  // PHASE TRANSITIONS
  // ═════════════════════════════════════════════════════════════════════

  void _startAnnouncing() {
    phase = TournamentPhase.announcing;
    phaseTimer = 0;
    gameCounter = 0;
    playerRegistered = false;
    playerEliminated = false;
    currentMatchIndex = 0;
    entrantIds = [];
    entrantNames = [];
    matches = [];
    tournamentCount++;

    // Generate name and prize
    tournamentName = TournamentNames.generate(_rng, tournamentCount);
    prizeDie = _generatePrize();

    final prizeName = prizeDie!.name;
    onToast?.call('$tournamentName — Prize: $prizeName', GameColors.uiHighlight);
  }

  void _startRegistration() {
    phase = TournamentPhase.registration;
    phaseTimer = 0;

    // Auto-register NPCs
    _registerNpcs();

    onToast?.call('Registration open! Enter the Lists at the Tournament Board.', GameColors.uiHighlight);
  }

  /// Player calls this to register.
  bool registerPlayer() {
    if (phase != TournamentPhase.registration) return false;
    if (playerRegistered) return false;

    final player = getPlayer?.call();
    if (player == null || player.gold < entryFee) return false;

    player.gold -= entryFee;
    playerRegistered = true;

    // Insert player at a random position (will be shuffled at bracket time)
    entrantIds.insert(0, 'player');
    entrantNames.insert(0, 'YOU');

    onToast?.call('Registered! Entry fee: ${entryFee}g. Good luck!', GameColors.uiSuccess);
    return true;
  }

  void _registerNpcs() {
    final npcs = getNpcs?.call() ?? [];
    final slotsNeeded = 8 - (playerRegistered ? 1 : 0);

    // Filter eligible NPCs
    final eligible = npcs.where((n) =>
        n.gold >= entryFee &&
        n.state != NpcState.playingDice &&
        n.state != NpcState.walkingToTable &&
        n.type != NpcType.barmaid
    ).toList();

    // Sort by diceChance (gamblers first) with randomization
    eligible.sort((a, b) {
      final aScore = a.diceChance + _rng.nextDouble() * 0.3;
      final bScore = b.diceChance + _rng.nextDouble() * 0.3;
      return bScore.compareTo(aScore);
    });

    // Take up to slotsNeeded
    final registrants = eligible.take(slotsNeeded).toList();
    for (final npc in registrants) {
      npc.gold -= entryFee;
      entrantIds.add(npc.id);
      entrantNames.add(npc.name);
    }
  }

  void _closeRegistration() {
    // If player didn't register, add one more NPC if possible
    if (!playerRegistered && entrantIds.length < 8) {
      final npcs = getNpcs?.call() ?? [];
      for (final npc in npcs) {
        if (entrantIds.contains(npc.id)) continue;
        if (npc.gold >= entryFee && npc.state != NpcState.playingDice) {
          npc.gold -= entryFee;
          entrantIds.add(npc.id);
          entrantNames.add(npc.name);
          if (entrantIds.length >= 8) break;
        }
      }
    }

    // Pad with nulls (byes) if < 8
    while (entrantIds.length < 8) {
      entrantIds.add('bye_${entrantIds.length}');
      entrantNames.add('BYE');
    }

    // Shuffle for random seeding
    final indices = List.generate(8, (i) => i);
    indices.shuffle(_rng);
    final shuffledIds = indices.map((i) => entrantIds[i]).toList();
    final shuffledNames = indices.map((i) => entrantNames[i]).toList();
    entrantIds = shuffledIds;
    entrantNames = shuffledNames;

    // Build bracket: 7 matches
    // QF: [0]v[7], [3]v[4], [1]v[6], [2]v[5]
    // SF: winner(QF1)v winner(QF2), winner(QF3)v winner(QF4)
    // Final: winner(SF1) v winner(SF2)
    matches = [
      TournamentMatch(entrant1Id: _realId(0), entrant2Id: _realId(7)), // QF1
      TournamentMatch(entrant1Id: _realId(3), entrant2Id: _realId(4)), // QF2
      TournamentMatch(entrant1Id: _realId(1), entrant2Id: _realId(6)), // QF3
      TournamentMatch(entrant1Id: _realId(2), entrant2Id: _realId(5)), // QF4
      TournamentMatch(), // SF1 — filled after QF
      TournamentMatch(), // SF2 — filled after QF
      TournamentMatch(), // Final — filled after SF
    ];

    // Resolve byes immediately
    for (final m in matches.take(4)) {
      if (m.isBye) m.resolveBye();
    }

    phase = TournamentPhase.bracketSet;
    phaseTimer = 0;

    onToast?.call('Bracket set! ${entrantIds.where((id) => !id.startsWith("bye")).length} entrants.', GameColors.uiHighlight);
  }

  String? _realId(int seedIdx) {
    final id = entrantIds[seedIdx];
    return id.startsWith('bye') ? null : id;
  }

  void _startRound1() {
    phase = TournamentPhase.round1;
    phaseTimer = 0;
    currentMatchIndex = 0; // QF1
  }

  // ═════════════════════════════════════════════════════════════════════
  // MATCH PROGRESSION
  // ═════════════════════════════════════════════════════════════════════

  bool _tickMatches(double dt) {
    final roundStart = phase == TournamentPhase.round1 ? 0
        : phase == TournamentPhase.round2 ? 4
        : 6;
    final roundEnd = phase == TournamentPhase.round1 ? 4
        : phase == TournamentPhase.round2 ? 6
        : 7;

    // Find the next incomplete match in this round
    int? activeIdx;
    for (int i = roundStart; i < roundEnd; i++) {
      if (!matches[i].completed) {
        activeIdx = i;
        break;
      }
    }

    if (activeIdx == null) {
      // All matches in this round complete — advance
      return _advanceRound(roundEnd);
    }

    final match = matches[activeIdx];

    // Fill in entrants for SF/Final from previous round winners
    if (activeIdx >= 4 && match.entrant1Id == null && match.entrant2Id == null) {
      _populateLaterRound(activeIdx);
      if (match.isBye) {
        match.resolveBye();
        return true;
      }
    }

    // Player match — pause and let GameShell handle it
    if (match.isPlayerMatch && !playerEliminated) {
      onPlayerMatchReady?.call(match);
      return false; // Don't auto-advance; wait for player game to complete
    }

    // NPC-vs-NPC: simulate on timer
    if (phaseTimer >= npcMatchDuration) {
      _simulateNpcMatch(match);
      phaseTimer = 0;
      return true;
    }

    return false;
  }

  void _populateLaterRound(int matchIdx) {
    switch (matchIdx) {
      case 4: // SF1 = winner(QF1) vs winner(QF2)
        matches[4] = TournamentMatch(
            entrant1Id: matches[0].winnerId, entrant2Id: matches[1].winnerId);
        break;
      case 5: // SF2 = winner(QF3) vs winner(QF4)
        matches[5] = TournamentMatch(
            entrant1Id: matches[2].winnerId, entrant2Id: matches[3].winnerId);
        break;
      case 6: // Final = winner(SF1) vs winner(SF2)
        matches[6] = TournamentMatch(
            entrant1Id: matches[4].winnerId, entrant2Id: matches[5].winnerId);
        break;
    }
    if (matches[matchIdx].isBye) matches[matchIdx].resolveBye();
  }

  bool _advanceRound(int roundEnd) {
    if (roundEnd == 4) {
      phase = TournamentPhase.round2;
      phaseTimer = 0;
      return true;
    } else if (roundEnd == 6) {
      phase = TournamentPhase.finalRound;
      phaseTimer = 0;
      return true;
    } else {
      // Tournament over
      _startAwards();
      return true;
    }
  }

  void _startAwards() {
    phase = TournamentPhase.awards;
    phaseTimer = 0;

    final winnerId = matches[6].winnerId;
    final winnerName = _nameForId(winnerId);

    // Award prize
    if (winnerId == 'player' && prizeDie != null) {
      getPlayer?.call()?.dice.add(prizeDie!);
      onToast?.call('YOU WIN THE TOURNAMENT! Prize: ${prizeDie!.name}', GameColors.tierLegendary);
    } else {
      onToast?.call('$winnerName wins Tournament #$tournamentCount!', GameColors.uiHighlight);
    }

    // Build record
    lastRecord = TournamentRecord(
      winnerId: winnerId ?? '',
      winnerName: winnerName,
      prizeDie: prizeDie ?? DiceItem.wooden,
      entrantIds: List.from(entrantIds),
      entrantNames: List.from(entrantNames),
      matches: List.from(matches),
      tournamentNumber: tournamentCount,
    );
  }

  void _finishTournament() {
    phase = TournamentPhase.idle;
    phaseTimer = 0;
    gameCounter = 0;
    _saveTournament();
  }

  // ═════════════════════════════════════════════════════════════════════
  // MATCH SIMULATION (NPC vs NPC using EV model)
  // ═════════════════════════════════════════════════════════════════════

  void _simulateNpcMatch(TournamentMatch match) {
    if (match.entrant1Id == null || match.entrant2Id == null) {
      match.resolveBye();
      return;
    }

    // Run a full simulated Farkle game using the engine
    final target = GameConstants.farkleWinScore;
    int score1 = 0, score2 = 0;
    bool isP1Turn = _rng.nextBool(); // random starting player

    // Get personalities for AI decisions
    final npcs = getNpcs?.call() ?? [];
    final npc1 = npcs.where((n) => n.id == match.entrant1Id).firstOrNull;
    final npc2 = npcs.where((n) => n.id == match.entrant2Id).firstOrNull;
    final p1 = npc1?.personality ?? Personality.normal;
    final p2 = npc2?.personality ?? Personality.normal;

    // Simulate up to 200 turns to prevent infinite loops
    for (int turn = 0; turn < 200; turn++) {
      final personality = isP1Turn ? p1 : p2;
      final myScore = isP1Turn ? score1 : score2;
      final oppScore = isP1Turn ? score2 : score1;

      final turnPoints = _simulateTurn(personality, myScore, oppScore);
      if (isP1Turn) {
        score1 += turnPoints;
      } else {
        score2 += turnPoints;
      }

      if (score1 >= target || score2 >= target) break;
      isP1Turn = !isP1Turn;
    }

    match.score1 = score1;
    match.score2 = score2;
    match.winnerId = score1 >= score2 ? match.entrant1Id : match.entrant2Id;
    match.completed = true;

    final winnerName = _nameForId(match.winnerId);
    final loserName = _nameForId(
        match.winnerId == match.entrant1Id ? match.entrant2Id : match.entrant1Id);
    onToast?.call('$winnerName defeats $loserName ($score1–$score2)', null);
  }

  /// Simulate one turn, returns points scored (0 = bust).
  int _simulateTurn(Personality personality, int bankScore, int oppScore) {
    int turnScore = 0;
    int diceCount = 6;

    for (int roll = 0; roll < 20; roll++) {
      // Roll dice
      final values = List.generate(diceCount, (_) => _rng.nextInt(6) + 1);

      // Check for scoring
      final counts = <int, int>{};
      for (final v in values) counts[v] = (counts[v] ?? 0) + 1;

      // Quick bust check: any 1s, 5s, or triples?
      final has1 = values.contains(1);
      final has5 = values.contains(5);
      final hasTriple = counts.values.any((c) => c >= 3);

      if (!has1 && !has5 && !hasTriple) {
        return 0; // Bust
      }

      // Greedy scoring: take triples, then 1s and 5s
      int rollPoints = 0;
      int diceUsed = 0;

      for (final entry in counts.entries) {
        if (entry.value >= 3) {
          final base = entry.key == 1 ? 1000 : entry.key * 100;
          final mult = entry.value == 4 ? 2 : entry.value == 5 ? 4 : entry.value == 6 ? 8 : 1;
          rollPoints += base * mult;
          diceUsed += entry.value;
        }
      }

      // Remaining 1s and 5s (not in triples)
      for (final entry in counts.entries) {
        if (entry.value < 3) {
          if (entry.key == 1) {
            rollPoints += 100 * entry.value;
            diceUsed += entry.value;
          } else if (entry.key == 5) {
            rollPoints += 50 * entry.value;
            diceUsed += entry.value;
          }
        }
      }

      turnScore += rollPoints;
      diceCount -= diceUsed;
      if (diceCount <= 0) diceCount = 6; // Hot dice

      // EV decision: continue or bank?
      final shouldContinue = FarkleEngine.npcShouldContinue(
        turnScore, bankScore, oppScore, diceCount, personality,
      );

      if (!shouldContinue) return turnScore;

      // If banking would win, always bank
      if (bankScore + turnScore >= GameConstants.farkleWinScore) return turnScore;
    }

    return turnScore;
  }

  /// Report a player match result back to the tournament.
  void reportPlayerMatchResult(bool playerWon, int playerScore, int oppScore) {
    // Find the active player match
    for (final match in matches) {
      if (match.isPlayerMatch && !match.completed) {
        match.score1 = match.entrant1Id == 'player' ? playerScore : oppScore;
        match.score2 = match.entrant2Id == 'player' ? playerScore : oppScore;
        match.winnerId = playerWon ? 'player' :
            (match.entrant1Id == 'player' ? match.entrant2Id : match.entrant1Id);
        match.completed = true;

        if (!playerWon) {
          playerEliminated = true;
          onToast?.call('Eliminated from tournament! Spectate remaining matches.', GameColors.uiDanger);
        }
        break;
      }
    }
  }

  // ═════════════════════════════════════════════════════════════════════
  // PRIZE GENERATION
  // ═════════════════════════════════════════════════════════════════════

  DiceItem _generatePrize() {
    // Tier roll: 15% T1, 30% T2, 30% T3, 18% T4, 7% T5
    final tierRoll = _rng.nextDouble();
    DiceTier tier;
    if (tierRoll < 0.15)       tier = DiceTier.common;
    else if (tierRoll < 0.45)  tier = DiceTier.uncommon;
    else if (tierRoll < 0.75)  tier = DiceTier.rare;
    else if (tierRoll < 0.93)  tier = DiceTier.epic;
    else                       tier = DiceTier.legendary;

    // Pick random material within tier
    final materials = DiceMaterial.values
        .where((m) => DiceTiers.tierOf(m) == tier).toList();
    final mat = materials[_rng.nextInt(materials.length)];

    // Enchantment roll: 10% T1, 20% T2, 30% T3, 40% T4, 60% T5
    final enchChance = tier == DiceTier.common ? 0.10
        : tier == DiceTier.uncommon ? 0.20
        : tier == DiceTier.rare ? 0.30
        : tier == DiceTier.epic ? 0.40
        : 0.60;

    Enchantment? ench;
    if (_rng.nextDouble() < enchChance && tier != DiceTier.common) {
      ench = _pickEnchantment(tier);
    }

    return DiceItem(material: mat, enchantment: ench);
  }

  Enchantment? _pickEnchantment(DiceTier tier) {
    final tierIdx = DiceTiers.tierIndex(tier);
    final eligible = Enchantment.values.where((e) {
      final minTierIdx = DiceTiers.tierIndex(DiceTiers.enchantmentMinTier(e));
      return minTierIdx <= tierIdx;
    }).toList();

    if (eligible.isEmpty) return null;
    return eligible[_rng.nextInt(eligible.length)];
  }

  // ═════════════════════════════════════════════════════════════════════
  // HELPERS
  // ═════════════════════════════════════════════════════════════════════

  String _nameForId(String? id) {
    if (id == null || id.startsWith('bye')) return 'BYE';
    if (id == 'player') return 'YOU';
    final idx = entrantIds.indexOf(id);
    if (idx >= 0 && idx < entrantNames.length) return entrantNames[idx];
    // Fallback: check NPC list
    final npcs = getNpcs?.call() ?? [];
    return npcs.where((n) => n.id == id).firstOrNull?.name ?? id;
  }

  /// Get the NPC opponent for the current player match.
  String? get currentPlayerOpponentId {
    for (final match in matches) {
      if (match.isPlayerMatch && !match.completed) {
        return match.entrant1Id == 'player' ? match.entrant2Id : match.entrant1Id;
      }
    }
    return null;
  }

  /// Get the round label for a match index.
  String roundLabel(int matchIdx) {
    if (matchIdx < 4) return 'QUARTERFINAL';
    if (matchIdx < 6) return 'SEMIFINAL';
    return 'FINAL';
  }

  /// Seconds remaining in current timed phase.
  double get timeRemaining {
    switch (phase) {
      case TournamentPhase.announcing:
        return (announceDuration - phaseTimer).clamp(0, announceDuration);
      case TournamentPhase.registration:
        return (registrationDuration - phaseTimer).clamp(0, registrationDuration);
      case TournamentPhase.awards:
        return (awardsDuration - phaseTimer).clamp(0, awardsDuration);
      default: return 0;
    }
  }

  /// Whether the tournament is in any active state.
  bool get isActive => phase != TournamentPhase.idle;

  /// Whether the player can still register.
  bool get canRegister =>
      phase == TournamentPhase.registration && !playerRegistered;

  // ═════════════════════════════════════════════════════════════════════
  // PERSISTENCE
  // ═════════════════════════════════════════════════════════════════════

  static const _keyLastRecord = 'tournament_last_record';
  static const _keyGameCounter = 'tournament_game_counter';
  static const _keyTournamentCount = 'tournament_count';

  Future<void> _saveTournament() async {
    final prefs = await SharedPreferences.getInstance();
    if (lastRecord != null) {
      await prefs.setString(_keyLastRecord, jsonEncode(lastRecord!.toJson()));
    }
    await prefs.setInt(_keyGameCounter, gameCounter);
    await prefs.setInt(_keyTournamentCount, tournamentCount);
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    gameCounter = prefs.getInt(_keyGameCounter) ?? 0;
    tournamentCount = prefs.getInt(_keyTournamentCount) ?? 0;

    final recordStr = prefs.getString(_keyLastRecord);
    if (recordStr != null) {
      try {
        lastRecord = TournamentRecord.fromJson(jsonDecode(recordStr));
      } catch (_) {
        lastRecord = null;
      }
    }
  }

  Future<void> save() async => _saveTournament();
}
