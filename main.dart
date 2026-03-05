import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fark_my_life/core/constants.dart';
import 'package:fark_my_life/core/enums.dart';
import 'package:fark_my_life/models/models.dart';
import 'package:fark_my_life/models/dice_tiers.dart';
import 'package:fark_my_life/models/game_history.dart';
import 'package:fark_my_life/models/npc_definitions.dart';
import 'package:fark_my_life/entities/dice_renderer.dart';
import 'package:fark_my_life/screens/overworld_screen.dart';
import 'package:fark_my_life/screens/dialogue_screen.dart';
import 'package:fark_my_life/screens/farkle_screen.dart';
import 'package:fark_my_life/screens/inventory_screen.dart';
import 'package:fark_my_life/screens/tournament_screen.dart';
import 'package:fark_my_life/screens/shop_screen.dart';
import 'package:fark_my_life/screens/profile_screen.dart';
import 'package:fark_my_life/systems/persistence.dart';
import 'package:fark_my_life/systems/tournament.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const FarkMyLifeApp());
}

class FarkMyLifeApp extends StatelessWidget {
  const FarkMyLifeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fark My Life',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: 'monospace',
        scaffoldBackgroundColor: Colors.black,
      ),
      home: const GameShell(),
    );
  }
}

/// Top-level widget that manages game state and screen routing.
class GameShell extends StatefulWidget {
  const GameShell({super.key});

  @override
  State<GameShell> createState() => _GameShellState();
}

class _GameShellState extends State<GameShell> with SingleTickerProviderStateMixin {
  GameScreen currentScreen = GameScreen.title;
  late PlayerData player;
  late List<NpcData> npcs;
  late List<DiceTableData> diceTables;

  // Dialogue / Farkle state
  NpcData? dialogueNpc;
  int farkleBet = 0;

  // Observation state
  NpcData? _observeNpc1;
  NpcData? _observeNpc2;
  int _observeBet = 0;
  DiceTableData? _observeTable;

  // Profile viewing
  NpcData? _profileNpc;

  // Toast notification
  String? _toastMessage;
  Color _toastColor = GameColors.uiSuccess;

  // Tournament system
  final TournamentManager _tournament = TournamentManager();
  final ShopManager _shop = ShopManager();
  late AnimationController _shellTicker;

  @override
  void initState() {
    super.initState();
    _initializeGame();
    _loadSave();
    _shellTicker = AnimationController(
      vsync: this, duration: const Duration(days: 1),
    )..addListener(_onShellTick);
    _shellTicker.forward();
  }

  @override
  void dispose() {
    _shellTicker.dispose();
    super.dispose();
  }

  void _onShellTick() {
    const dt = 1 / 30; // 30fps for tournament is fine
    if (_tournament.isActive && currentScreen != GameScreen.farkle) {
      final changed = _tournament.tick(dt);
      if (changed && mounted) {
        setState(() {});
        // Save when tournament finishes
        if (!_tournament.isActive) {
          _saveGame();
        }
      }
    }
  }

  Future<void> _loadSave() async {
    final loaded = await GamePersistence.loadPlayer(player);
    await _tournament.load();
    if (loaded && mounted) {
      setState(() {}); // refresh UI with loaded data
    }
  }

  Future<void> _saveGame() async {
    await GamePersistence.savePlayer(player);
    await _tournament.save();
  }

  /// Called when the tournament has a player match ready.
  void _onTournamentPlayerMatch(TournamentMatch match) {
    final oppId = _tournament.currentPlayerOpponentId;
    if (oppId == null) return;

    NpcData? opponent;
    for (final npc in npcs) {
      if (npc.id == oppId) { opponent = npc; break; }
    }
    if (opponent == null) return;

    setState(() {
      dialogueNpc = opponent;
      farkleBet = 0; // Tournament games have no bet
      currentScreen = GameScreen.farkle;
    });
  }

  void _initializeGame() {
    player = PlayerData(x: 25, y: 19);  // central crossroads
    npcs = NpcFactory.createTownNpcs();
    diceTables = [
      DiceTableData(id: 0, x: 15, y: 17), // town square south
      DiceTableData(id: 1, x: 22, y: 16), // town square east
      DiceTableData(id: 2, x: 32, y: 15), // market
      DiceTableData(id: 3, x: 16, y: 29), // beer garden left
      DiceTableData(id: 4, x: 21, y: 29), // beer garden right
      DiceTableData(id: 5, x: 32, y: 22), // blacksmith courtyard
      DiceTableData(id: 6, x: 18, y: 32), // south park
      // Tournament grounds (4 tables for simultaneous QF matches)
      DiceTableData(id: 7, x: 30, y: 33),  // tournament NW
      DiceTableData(id: 8, x: 36, y: 33),  // tournament NE
      DiceTableData(id: 9, x: 30, y: 35),  // tournament SW
      DiceTableData(id: 10, x: 36, y: 35), // tournament SE
    ];

    // Wire tournament callbacks
    _tournament.onToast = (msg, color) =>
        _showToast(msg, color: color ?? GameColors.uiHighlight);
    _tournament.getNpcs = () => npcs;
    _tournament.getPlayer = () => player;
    _tournament.onPlayerMatchReady = _onTournamentPlayerMatch;
  }

  void _changeScreen(GameScreen screen) {
    setState(() => currentScreen = screen);
  }

  void _alertNpcsOfChallenger(DiceTableData table) {
    // 30% of map diagonal as max range
    const mapDiag = 63.0; // sqrt(50^2 + 38^2)
    const maxRange = mapDiag * 0.30; // ~19 tiles

    NpcData? bestNpc;
    double bestDist = double.infinity;

    for (final npc in npcs) {
      // Skip NPCs already engaged
      if (npc.state == NpcState.seated ||
          npc.state == NpcState.walkingToTable ||
          npc.state == NpcState.playingDice) continue;
      if (npc.gold < GameConstants.minBet) continue;

      final dx = npc.x - table.x;
      final dy = npc.y - table.y;
      final dist = sqrt(dx * dx + dy * dy);
      if (dist > maxRange) continue; // outside awareness range
      if (dist < bestDist) {
        bestDist = dist;
        bestNpc = npc;
      }
    }

    if (bestNpc != null) {
      if (table.seat(bestNpc.id)) {
        bestNpc.seatedAtTable = table.id;
        bestNpc.state = NpcState.walkingToTable;
        bestNpc.stateTimer = 0;
      }
    }
  }

  void _showToast(String message, {Color color = GameColors.uiSuccess}) {
    setState(() {
      _toastMessage = message;
      _toastColor = color;
    });
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _toastMessage = null);
    });
  }

  void _startFarkleGame(NpcData npc, int bet) {
    // Unseat both player and NPC from any tables
    for (final t in diceTables) {
      t.unseat('player');
      t.unseat(npc.id);
    }
    npc.seatedAtTable = null;
    setState(() {
      dialogueNpc = npc;
      farkleBet = bet;
      currentScreen = GameScreen.farkle;
    });
  }

  void _onObserveEnd(bool npc1Won, DiceItem? _) {
    setState(() {
      if (_observeNpc1 != null && _observeNpc2 != null) {
        final winner = npc1Won ? _observeNpc1! : _observeNpc2!;
        final loser = npc1Won ? _observeNpc2! : _observeNpc1!;
        winner.gold = (winner.gold + _observeBet).clamp(0, winner.maxGold);
        loser.gold = (loser.gold - _observeBet).clamp(0, loser.maxGold);
        _showToast('${winner.name} won ${_observeBet}g from ${loser.name}!',
            color: GameColors.uiHighlight);
        // End the table's NPC game and return both NPCs home
        if (_observeTable != null) {
          _observeTable!.endNpcGame();
        }
        for (final npc in [_observeNpc1!, _observeNpc2!]) {
          if (_observeTable != null) _observeTable!.unseat(npc.id);
          npc.seatedAtTable = null;
          npc.x = npc.homeX;
          npc.y = npc.homeY;
          npc.state = NpcState.idle;
          npc.stateTimer = 0;
        }
      }
      _observeNpc1 = null;
      _observeNpc2 = null;
      _observeTable = null;
      _observeBet = 0;
      currentScreen = GameScreen.overworld;
    });
    _tournament.onGameCompleted();
    _shop.onGameCompleted(); // Observed NPC games count toward tournament trigger
    _tryNpcDicePurchase(_observeNpc1);
    _tryNpcDicePurchase(_observeNpc2);
  }

  void _tryNpcDicePurchase(NpcData? npc) {
    if (npc == null) return;
    final rng = Random();
    if (rng.nextDouble() > 0.10) return;
    final budget = (npc.gold * 0.3).floor();
    if (budget < 8) return;
    final bestTierIdx = npc.npcDice.map((d) => DiceTiers.tierIndex(d.tier)).reduce(max);
    final maxTierIdx = (bestTierIdx + 1).clamp(1, 5);
    final affordable = DiceMaterial.values.where((m) {
      final tIdx = DiceTiers.tierIndex(DiceTiers.tierOf(m));
      return tIdx <= maxTierIdx && DiceTiers.basePrice(m) <= budget;
    }).toList();
    if (affordable.isEmpty) return;
    final mat = affordable[rng.nextInt(affordable.length)];
    final newDie = DiceItem(material: mat);
    int worstIdx = 0;
    int worstTier = DiceTiers.tierIndex(npc.npcDice[0].tier);
    for (int i = 1; i < npc.npcDice.length; i++) {
      final t = DiceTiers.tierIndex(npc.npcDice[i].tier);
      if (t < worstTier) { worstTier = t; worstIdx = i; }
    }
    if (DiceTiers.tierIndex(DiceTiers.tierOf(mat)) > worstTier) {
      npc.npcDice[worstIdx] = newDie;
      npc.gold -= DiceTiers.basePrice(mat);
    }
  }

  void _leaveObservation() {
    // Player leaves early — NPCs continue their game on the overworld
    setState(() {
      _observeNpc1 = null;
      _observeNpc2 = null;
      _observeTable = null;
      _observeBet = 0;
      currentScreen = GameScreen.overworld;
    });
  }

  void _onFarkleEnd(bool playerWon, DiceItem? loot) {
    final wasTournamentMatch = _tournament.isActive &&
        _tournament.playerRegistered && !_tournament.playerEliminated &&
        farkleBet == 0;

    setState(() {
      // Record game in history
      if (dialogueNpc != null) {
        player.history.recordGame(GameRecord(
          opponentId: dialogueNpc!.id,
          opponentName: dialogueNpc!.name,
          won: playerWon,
          betAmount: farkleBet,
          playerScore: 0, opponentScore: 0, // TODO: pass actual scores
          wasTournament: wasTournamentMatch,
        ));
        // Check collection badges
        final hasLegendary = player.dice.any((d) => d.tier == DiceTier.legendary);
        final npcsBeaten = player.history.opponents.values.where((o) => o.wins > 0).length;
        player.history.checkCollectionBadges(
            player.dice.length, player.gold, hasLegendary, npcs.length, npcsBeaten);
        if (farkleBet >= 50 && playerWon) {
          player.history.earnedBadges.add(Badges.highRoller.id);
        }
      }

      if (wasTournamentMatch) {
        // Tournament match — no gold exchange, no loot, no W/L record
        _tournament.reportPlayerMatchResult(playerWon, 0, 0);
        if (playerWon) {
          _showToast('Tournament match won! Advancing...', color: GameColors.uiSuccess);
        }
        // Return to tournament screen to see bracket update
        currentScreen = GameScreen.tournament;
      } else {
        // Regular game — normal gold/loot flow
        if (playerWon) {
          player.gold += farkleBet;
          player.wins++;
          if (dialogueNpc != null) {
            dialogueNpc!.gold -= farkleBet;
            if (dialogueNpc!.gold < 0) dialogueNpc!.gold = 0;
          }
          _showToast('Victory! +${farkleBet}g', color: GameColors.uiSuccess);
        } else {
          player.gold -= farkleBet;
          if (player.gold < 0) player.gold = 0;
          player.losses++;
          if (dialogueNpc != null) {
            dialogueNpc!.gold += farkleBet;
          }
          _showToast('Defeat! -${farkleBet}g', color: GameColors.uiDanger);
        }

        if (loot != null) {
          player.dice.add(loot);
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) {
              _showToast('Loot: ${loot.name}!', color: _rarityColor(loot.rarity));
            }
          });
        }

        currentScreen = GameScreen.overworld;
      }

      // Return NPC to idle - fully reset their state
      if (dialogueNpc != null) {
        for (final t in diceTables) {
          t.unseat(dialogueNpc!.id);
          t.unseat('player');
        }
        dialogueNpc!.seatedAtTable = null;
        dialogueNpc!.x = dialogueNpc!.homeX;
        dialogueNpc!.y = dialogueNpc!.homeY;
        dialogueNpc!.state = NpcState.idle;
        dialogueNpc!.stateTimer = 0;
        dialogueNpc!.stuckTimer = 0;
      }

      dialogueNpc = null;
      farkleBet = 0;
    });
    _tournament.onGameCompleted();
    _shop.onGameCompleted();
    _saveGame();
  }

  Color _rarityColor(DiceRarity rarity) {
    switch (rarity) {
      case DiceRarity.common:
        return GameColors.tierCommon;
      case DiceRarity.uncommon:
        return GameColors.tierUncommon;
      case DiceRarity.rare:
        return GameColors.tierRare;
      case DiceRarity.epic:
        return GameColors.tierEpic;
      case DiceRarity.legendary:
        return GameColors.tierLegendary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _buildCurrentScreen(),
          // Show overworld HUD when on overworld or dialogue (dialogue overlays)
          if (currentScreen == GameScreen.overworld ||
              currentScreen == GameScreen.dialogue)
            _buildHud(),
          // Dialogue overlay on top of overworld
          if (currentScreen == GameScreen.dialogue && dialogueNpc != null)
            _buildDialogueOverlay(),
          if (_toastMessage != null) _buildToast(),
        ],
      ),
    );
  }

  Widget _buildDialogueOverlay() {
    return Positioned(
      left: 0, right: 0, bottom: 72, // above the action bar
      child: DialogueScreen(
        npc: dialogueNpc!,
        player: player,
        diceTables: diceTables,
        onClose: () {
          for (final t in diceTables) {
            t.unseat('player');
          }
          setState(() {
            dialogueNpc = null;
            currentScreen = GameScreen.overworld;
          });
        },
        onChallenge: (npc, bet) {
          _startFarkleGame(npc, bet);
        },
        onObserve: (table) {
          _showToast('Observation mode coming soon!',
              color: GameColors.uiMuted);
          _changeScreen(GameScreen.overworld);
        },
      ),
    );
  }

  Widget _buildCurrentScreen() {
    switch (currentScreen) {
      case GameScreen.title:
        return _TitleScreen(
          onStart: () => _changeScreen(GameScreen.overworld),
          onResetSave: () async {
            await GamePersistence.clearSave();
            _initializeGame();
            setState(() {});
          },
        );

      case GameScreen.overworld:
        return OverworldWidget(
          player: player,
          npcs: npcs,
          diceTables: diceTables,
          onInteractNpc: (npc) {
            if (npc.id == 'merchant_vex') {
              setState(() => currentScreen = GameScreen.shop);
            } else if (npc.state == NpcState.seated || npc.state == NpcState.playingDice) {
              // Seated NPC → challenge dialogue
              setState(() {
                dialogueNpc = npc;
                currentScreen = GameScreen.dialogue;
              });
            } else {
              // Standing NPC → show their profile
              setState(() {
                _profileNpc = npc;
                currentScreen = GameScreen.profile;
              });
            }
          },
          onInteractTable: (table) {
            // Clean ghost occupants - NPCs no longer at this table
            for (final sid in [table.occupant1Id, table.occupant2Id]) {
              if (sid == null || sid == 'player') continue;
              NpcData? occ;
              for (final n in npcs) { if (n.id == sid) { occ = n; break; } }
              if (occ == null ||
                  (occ.state != NpcState.seated &&
                   occ.state != NpcState.playingDice &&
                   occ.state != NpcState.walkingToTable)) {
                table.unseat(sid);
              }
            }
            if (table.isEmpty) {
              // Player sits at empty table
              table.seat('player');
              _showToast('Waiting for a challenger...',
                  color: GameColors.uiHighlight);
              // Immediately send the nearest available NPC to this table
              _alertNpcsOfChallenger(table);
            } else if (table.hasOneSeat) {
              // One person at table - figure out who
              final occupantId = table.occupant1Id ?? table.occupant2Id;
              if (occupantId == 'player') {
                // Player is sitting, no NPC yet - re-alert
                _alertNpcsOfChallenger(table);
                _showToast('Looking for a challenger...',
                    color: GameColors.uiMuted);
              } else {
                // NPC is sitting - open dialogue to challenge
                NpcData? tableNpc;
                for (final npc in npcs) {
                  if (npc.id == occupantId) {
                    tableNpc = npc;
                    break;
                  }
                }
                if (tableNpc != null) {
                  setState(() {
                    dialogueNpc = tableNpc;
                    currentScreen = GameScreen.dialogue;
                  });
                }
              }
            } else if (table.isFull) {
              // Full table - check if player is one of the occupants
              final playerAtTable =
                  table.occupant1Id == 'player' || table.occupant2Id == 'player';
              if (playerAtTable) {
                // Player + NPC - find the NPC and start dialogue
                final npcId = table.occupant1Id == 'player'
                    ? table.occupant2Id
                    : table.occupant1Id;
                NpcData? tableNpc;
                for (final npc in npcs) {
                  if (npc.id == npcId) {
                    tableNpc = npc;
                    break;
                  }
                }
                if (tableNpc != null) {
                  // Unseat player since we're entering dialogue
                  table.unseat('player');
                  setState(() {
                    dialogueNpc = tableNpc;
                    currentScreen = GameScreen.dialogue;
                  });
                }
              } else {
                // Two NPCs playing — launch observation mode
                NpcData? npc1, npc2;
                for (final npc in npcs) {
                  if (npc.id == table.occupant1Id) npc1 = npc;
                  if (npc.id == table.occupant2Id) npc2 = npc;
                }
                if (npc1 != null && npc2 != null) {
                  setState(() {
                    _observeNpc1 = npc1;
                    _observeNpc2 = npc2;
                    _observeBet = table.npcGameBet > 0 ? table.npcGameBet : 10;
                    _observeTable = table;
                    currentScreen = GameScreen.observing;
                  });
                } else {
                  _showToast('You watch the NPCs play dice...',
                      color: GameColors.uiMuted);
                }
              }
            }
          },
          onOpenInventory: () {
            setState(() => currentScreen = GameScreen.inventory);
          },
          onNpcGameResolved: (winner, loser, bet) {
            _showToast('$winner beat $loser for ${bet}g!',
                color: GameColors.uiMuted);
          },
          onInteractTournamentBoard: () {
            setState(() => currentScreen = GameScreen.tournament);
          },
          championName: _tournament.lastRecord?.winnerName,
          onCycleLoadout: () {
            final name = player.cycleLoadout();
            _showToast('Loadout: $name', color: GameColors.uiText);
            setState(() {});
            _saveGame();
          },
          onOpenProfile: () {
            setState(() {
              _profileNpc = null; // null = player profile
              currentScreen = GameScreen.profile;
            });
          },
        );

      case GameScreen.dialogue:
        // Overworld continues underneath; dialogue is overlaid via Stack
        return OverworldWidget(
          player: player,
          npcs: npcs,
          diceTables: diceTables,
          onInteractNpc: (_) {},
          onInteractTable: (_) {},
          onOpenInventory: () {},
          inputEnabled: false,
        );

      case GameScreen.farkle:
        if (dialogueNpc != null) {
          // Determine if this is a tournament match
          String? tourneyRound;
          if (_tournament.isActive && _tournament.playerRegistered &&
              !_tournament.playerEliminated && farkleBet == 0) {
            for (int i = 0; i < _tournament.matches.length; i++) {
              final m = _tournament.matches[i];
              if (m.isPlayerMatch && !m.completed) {
                tourneyRound = _tournament.roundLabel(i);
                break;
              }
            }
          }
          return FarkleScreen(
            player: player,
            opponent: dialogueNpc!,
            betAmount: farkleBet,
            onGameEnd: _onFarkleEnd,
            tournamentRound: tourneyRound,
          );
        }
        return _buildPlaceholder('DICE GAME');

      case GameScreen.observing:
        if (_observeNpc1 != null && _observeNpc2 != null) {
          // Calculate how far along the NPC game was when we started watching
          final progress = (_observeTable != null && _observeTable!.npcGameDuration > 0)
              ? (_observeTable!.npcGameTimer / _observeTable!.npcGameDuration).clamp(0.0, 0.95)
              : 0.0;
          return FarkleScreen(
            player: player,
            opponent: _observeNpc2!,
            betAmount: _observeBet,
            onGameEnd: _onObserveEnd,
            observeNpc1: _observeNpc1,
            onLeaveObservation: _leaveObservation,
            gameProgress: progress,
          );
        }
        return _buildPlaceholder('OBSERVING');

      case GameScreen.inventory:
        return InventoryScreen(
          player: player,
          onClose: () => _changeScreen(GameScreen.overworld),
        );

      case GameScreen.tournament:
        return TournamentScreen(
          tournament: _tournament,
          player: player,
          onClose: () => _changeScreen(GameScreen.overworld),
          onRegister: () {
            if (_tournament.registerPlayer()) {
              setState(() {});
              _saveGame();
            }
          },
        );

      case GameScreen.shop:
        return ShopScreen(
          player: player,
          shop: _shop,
          onClose: () => _changeScreen(GameScreen.overworld),
          onSave: () => _saveGame(),
        );

      case GameScreen.profile:
        if (_profileNpc != null) {
          // NPC profile
          return ProfileScreen(
            name: _profileNpc!.name,
            title: _profileNpc!.type.name.toUpperCase(),
            portraitColor: _profileNpc!.primaryColor,
            history: _profileNpc!.npcHistory,
            gold: _profileNpc!.gold,
            diceCount: _profileNpc!.npcDice.length,
            equippedDice: _profileNpc!.npcDice,
            isPlayer: false,
            onClose: () {
              _profileNpc = null;
              _changeScreen(GameScreen.overworld);
            },
          );
        }
        // Player profile
        return ProfileScreen(
          name: 'WANDERER',
          title: 'DICE ROLLER',
          portraitColor: const Color(0xFF4488cc),
          history: player.history,
          gold: player.gold,
          diceCount: player.dice.length,
          equippedDice: player.equippedDice,
          isPlayer: true,
          onClose: () => _changeScreen(GameScreen.overworld),
        );

      default:
        return _buildPlaceholder(currentScreen.name.toUpperCase());
    }
  }

  Widget _buildPlaceholder(String label) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(color: GameColors.uiText, fontSize: 18)),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => _changeScreen(GameScreen.overworld),
            child: const Text('Back to Overworld',
                style: TextStyle(color: GameColors.uiHighlight)),
          ),
        ],
      ),
    );
  }

  Widget _buildToast() {
    return Positioned(
      bottom: 84, // above the 72px action bar
      left: 0,
      right: 0,
      child: Center(
        child: AnimatedOpacity(
          opacity: _toastMessage != null ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.85),
              border: Border.all(color: _toastColor, width: 2),
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(
                    color: _toastColor.withValues(alpha: 0.3), blurRadius: 12),
              ],
            ),
            child: Text(
              _toastMessage ?? '',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: _toastColor,
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _tournamentPhaseShort() {
    switch (_tournament.phase) {
      case TournamentPhase.announcing:   return 'SOON';
      case TournamentPhase.registration: return 'REGISTER';
      case TournamentPhase.bracketSet:   return 'BRACKET';
      case TournamentPhase.round1:       return 'QF';
      case TournamentPhase.round2:       return 'SF';
      case TournamentPhase.finalRound:   return 'FINAL';
      case TournamentPhase.awards:       return 'AWARDS';
      default: return '';
    }
  }

  List<Widget> _buildNearbyNpcInfo() {
    // Find nearest NPC within interaction range
    const range = 2.5;
    NpcData? nearest;
    double nearestDist = range;
    for (final npc in npcs) {
      final dx = player.x - npc.x;
      final dy = player.y - npc.y;
      final d = sqrt(dx * dx + dy * dy);
      if (d < nearestDist) {
        nearestDist = d;
        nearest = npc;
      }
    }
    if (nearest == null) return [];

    return [
      GestureDetector(
        onTap: () {
          setState(() {
            _profileNpc = nearest;
            currentScreen = GameScreen.profile;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          margin: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(
            color: nearest.primaryColor.withOpacity(0.1),
            border: Border.all(color: nearest.primaryColor.withOpacity(0.5), width: 1.5),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 24, height: 24,
              decoration: BoxDecoration(
                border: Border.all(color: nearest.primaryColor, width: 1),
                borderRadius: BorderRadius.circular(2),
                color: const Color(0xFF1a1410),
              ),
              child: CustomPaint(painter: _MiniPortraitPainter(color: nearest.primaryColor)),
            ),
            const SizedBox(width: 4),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nearest.name, style: TextStyle(fontFamily: 'monospace', fontSize: 9,
                  fontWeight: FontWeight.bold, color: nearest.primaryColor)),
                Text('${nearest.type.name.toUpperCase()} · ${nearest.gold}g',
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 7,
                    color: GameColors.uiMuted)),
              ],
            ),
          ]),
        ),
      ),
    ];
  }

  Widget _buildHud() {
    final equipped = player.equippedDice;
    final tournamentActive = _tournament.isActive;

    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: Container(
        height: 72,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Color(0xFF1a1208), Color(0xFF0e0a04)],
          ),
          border: Border(top: BorderSide(color: Color(0xFF4a3a20), width: 2)),
        ),
        child: Row(
          children: [
            // ── PORTRAIT (tap to open profile) ──
            GestureDetector(
              onTap: () => _changeScreen(GameScreen.profile),
              child: Container(
                width: 60, height: 60,
                margin: const EdgeInsets.only(left: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFd4b040), width: 2),
                  borderRadius: BorderRadius.circular(4),
                  color: const Color(0xFF2a2018),
                ),
                child: CustomPaint(
                  painter: _MiniPortraitPainter(),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // ── STATS PANEL ──
            Expanded(
              flex: 3,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text('${player.gold}g',
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 14,
                        fontWeight: FontWeight.bold, color: GameColors.uiHighlight)),
                    const SizedBox(width: 12),
                    Text('${player.wins}W ${player.losses}L',
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 11,
                        color: GameColors.uiText)),
                  ]),
                  const SizedBox(height: 2),
                  // Loadout name
                  Text('Active Dice',
                    style: TextStyle(fontFamily: 'monospace', fontSize: 9,
                      color: GameColors.uiMuted)),
                  if (tournamentActive)
                    Text('TOURNAMENT ACTIVE',
                      style: TextStyle(fontFamily: 'monospace', fontSize: 8,
                        fontWeight: FontWeight.bold, color: GameColors.uiHighlight)),
                ],
              ),
            ),

            // ── DICE LOADOUT GRID (2×3) ──
            Container(
              width: 108, height: 60,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF0a0804),
                border: Border.all(color: const Color(0xFF3a2a18), width: 1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: Wrap(
                  spacing: 2, runSpacing: 2,
                  children: List.generate(6, (i) {
                    final die = i < equipped.length ? equipped[i] : null;
                    return Container(
                      width: 24, height: 24,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: die != null
                              ? TierColors.forTier(die.tier).withOpacity(0.5)
                              : const Color(0xFF2a2a2a),
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(2),
                        color: const Color(0xFF141008),
                      ),
                      child: die != null
                          ? CustomPaint(
                              painter: MiniMaterialDiePainter(
                                value: (i % 6) + 1,
                                material: die.material,
                                enchantment: die.enchantment,
                              ),
                            )
                          : null,
                    );
                  }),
                ),
              ),
            ),

            // ── CONTEXT ZONE (right) ──
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Nearby NPC info
                    ..._buildNearbyNpcInfo(),
                    // Tournament status indicator
                    if (tournamentActive)
                      GestureDetector(
                        onTap: () => _changeScreen(GameScreen.tournament),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          margin: const EdgeInsets.only(right: 4),
                          decoration: BoxDecoration(
                            color: GameColors.uiHighlight.withOpacity(0.1),
                            border: Border.all(color: GameColors.uiHighlight.withOpacity(0.6), width: 1.5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('TOURNEY', style: TextStyle(fontFamily: 'monospace',
                                  fontSize: 8, fontWeight: FontWeight.bold,
                                  color: GameColors.uiHighlight)),
                              Text(_tournamentPhaseShort(), style: const TextStyle(
                                  fontFamily: 'monospace', fontSize: 7,
                                  color: GameColors.uiText)),
                            ],
                          ),
                        ),
                      ),
                    if (!tournamentActive && _tournament.lastRecord != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        margin: const EdgeInsets.only(right: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0a0804),
                          border: Border.all(color: const Color(0xFF3a3a2a), width: 1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Next: ${TournamentManager.gamesToTrigger - _tournament.gameCounter}',
                          style: const TextStyle(fontFamily: 'monospace',
                              fontSize: 8, color: GameColors.uiMuted),
                        ),
                      ),
                    GestureDetector(
                      onTap: () => _changeScreen(GameScreen.inventory),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1a1208),
                          border: Border.all(color: const Color(0xFF4a3a20), width: 1.5),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('INV', style: TextStyle(fontFamily: 'monospace',
                                fontSize: 10, fontWeight: FontWeight.bold,
                                color: GameColors.uiText)),
                            Text('[I]', style: TextStyle(fontFamily: 'monospace',
                                fontSize: 8, color: GameColors.uiMuted)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Simple player portrait for the action bar.
class _MiniPortraitPainter extends CustomPainter {
  final Color color;
  _MiniPortraitPainter({this.color = const Color(0xFF4488cc)});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint();
    // Body
    p.color = color;
    canvas.drawRect(Rect.fromLTWH(size.width * 0.25, size.height * 0.4,
        size.width * 0.5, size.height * 0.55), p);
    // Head
    p.color = const Color(0xFFdbb888);
    canvas.drawRect(Rect.fromLTWH(size.width * 0.3, size.height * 0.1,
        size.width * 0.4, size.height * 0.35), p);
    // Hair
    p.color = const Color(0xFF5a3a1a);
    canvas.drawRect(Rect.fromLTWH(size.width * 0.28, size.height * 0.08,
        size.width * 0.44, size.height * 0.12), p);
    // Eyes
    p.color = const Color(0xFF2a2a2a);
    canvas.drawRect(Rect.fromLTWH(size.width * 0.35, size.height * 0.25, 3, 3), p);
    canvas.drawRect(Rect.fromLTWH(size.width * 0.55, size.height * 0.25, 3, 3), p);
  }

  @override
  bool shouldRepaint(covariant _MiniPortraitPainter old) => old.color != color;
}

/// Pixel-art styled title screen.
class _TitleScreen extends StatefulWidget {
  final VoidCallback onStart;
  final VoidCallback? onResetSave;
  const _TitleScreen({required this.onStart, this.onResetSave});

  @override
  State<_TitleScreen> createState() => _TitleScreenState();
}

class _TitleScreenState extends State<_TitleScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  final _splashTexts = [
    'Every Roll Counts!', 'Fortune Favors the Bold!', 'Never Trust a Farmer\'s Dice!',
    'Hot Dice or Bust!', 'The Tavern Awaits!', 'Roll With Honor!',
    'Bones of Fortune!', 'One More Roll...', 'All In!',
    'The Dice Remember!', 'May the Pips Be With You!',
  ];
  late String _splash;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(days: 1))
      ..addListener(() => setState(() {}))
      ..forward();
    _splash = _splashTexts[Random().nextInt(_splashTexts.length)];
  }

  @override
  void dispose() { _anim.dispose(); super.dispose(); }

  double get t => DateTime.now().millisecondsSinceEpoch / 1000.0;

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.space ||
             event.logicalKey == LogicalKeyboardKey.enter)) {
          widget.onStart();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onStart,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── PANORAMA BACKGROUND ──
            CustomPaint(painter: _SplashPanoramaPainter(time: t), size: Size.infinite),

            // ── CONTENT OVERLAY ──
            Column(
              children: [
                const Spacer(flex: 2),
                // Title banner
                _buildTitle(),
                const SizedBox(height: 6),
                // Splash text (Minecraft-style rotating yellow text)
                _buildSplashText(),
                const Spacer(flex: 1),
                // Menu buttons
                _buildMenuButtons(),
                const Spacer(flex: 1),
                // Footer
                _buildFooter(),
                const SizedBox(height: 12),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitle() {
    final wobble = sin(t * 1.5) * 1.5;
    return Transform.translate(
      offset: Offset(0, wobble),
      child: Column(children: [
        // Main title with heavy shadow
        Text('FARK MY LIFE', style: TextStyle(
          fontFamily: 'monospace', fontSize: 42, fontWeight: FontWeight.w900,
          color: const Color(0xFFffe8a0),
          letterSpacing: 8,
          shadows: [
            Shadow(offset: const Offset(4, 4), color: const Color(0xFF2a1000), blurRadius: 0),
            Shadow(offset: const Offset(2, 2), color: const Color(0xFF8a5a10), blurRadius: 0),
            Shadow(offset: const Offset(0, 0), color: const Color(0xFFffe8a0), blurRadius: 16),
          ],
        )),
        const SizedBox(height: 2),
        // Subtitle
        Text('A  D I C E  R P G', style: TextStyle(
          fontFamily: 'monospace', fontSize: 12,
          color: const Color(0xFFc0a060), letterSpacing: 6,
          shadows: [Shadow(offset: const Offset(1, 1), color: Colors.black, blurRadius: 4)],
        )),
      ]),
    );
  }

  Widget _buildSplashText() {
    final scale = 1.0 + sin(t * 3.0) * 0.04;
    final angle = sin(t * 2.0) * 0.03;
    return Transform.rotate(
      angle: angle,
      child: Transform.scale(
        scale: scale,
        child: Text(_splash, style: TextStyle(
          fontFamily: 'monospace', fontSize: 14, fontWeight: FontWeight.bold,
          color: const Color(0xFFffff40),
          shadows: [Shadow(offset: const Offset(1, 1), color: Colors.black, blurRadius: 3)],
        )),
      ),
    );
  }

  Widget _buildMenuButtons() {
    return Column(children: [
      _SplashButton(label: 'ROLL THE DICE', onTap: widget.onStart, primary: true),
      const SizedBox(height: 10),
      if (widget.onResetSave != null) ...[
        _SplashButton(label: 'Reset Save', onTap: widget.onResetSave!, primary: false),
        const SizedBox(height: 6),
      ],
    ]);
  }

  Widget _buildFooter() {
    return Column(children: [
      Text('WASD Move  •  E Interact  •  I Inventory  •  P Profile',
        style: TextStyle(fontFamily: 'monospace', fontSize: 9,
          color: const Color(0xFF6a6a6a),
          shadows: [Shadow(offset: const Offset(1, 1), color: Colors.black, blurRadius: 2)])),
      const SizedBox(height: 4),
      Text('© 2026 — A game of bones and gold',
        style: TextStyle(fontFamily: 'monospace', fontSize: 8,
          color: const Color(0xFF4a4a4a))),
    ]);
  }
}

/// Minecraft-style panorama: procedural medieval landscape with castle, hills, tavern, floating dice.
class _SplashPanoramaPainter extends CustomPainter {
  final double time;
  _SplashPanoramaPainter({required this.time});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final p = Paint();

    // ── SKY: warm dusk gradient ──
    final skyGrad = LinearGradient(
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: [
        const Color(0xFF0a0820), const Color(0xFF1a1040),
        const Color(0xFF3a1830), const Color(0xFF6a2818),
        const Color(0xFFc85820),
      ],
      stops: const [0.0, 0.25, 0.5, 0.7, 0.95],
    );
    p.shader = skyGrad.createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), p);
    p.shader = null;

    // ── STARS ──
    final starPaint = Paint()..color = Colors.white;
    final starRng = Random(42);
    for (int i = 0; i < 60; i++) {
      final sx = starRng.nextDouble() * w;
      final sy = starRng.nextDouble() * h * 0.4;
      final twinkle = (0.3 + 0.7 * ((sin(time * 2.0 + i * 1.3) + 1) / 2)).clamp(0.0, 1.0);
      starPaint.color = Colors.white.withOpacity(twinkle * 0.8);
      canvas.drawCircle(Offset(sx, sy), starRng.nextDouble() * 1.2 + 0.3, starPaint);
    }

    // ── MOON ──
    p.color = const Color(0xFFfff8d0);
    canvas.drawCircle(Offset(w * 0.78, h * 0.15), 22, p);
    p.color = const Color(0xFFffe8a0).withOpacity(0.15);
    canvas.drawCircle(Offset(w * 0.78, h * 0.15), 36, p);

    // ── CLOUDS (parallax) ──
    _drawCloud(canvas, w, h, w * 0.2 + sin(time * 0.08) * 30, h * 0.12, 80);
    _drawCloud(canvas, w, h, w * 0.6 + sin(time * 0.05 + 2) * 40, h * 0.18, 100);
    _drawCloud(canvas, w, h, w * 0.9 + sin(time * 0.06 + 4) * 25, h * 0.08, 60);

    // ── FAR HILLS (dark silhouette) ──
    _drawHills(canvas, w, h, h * 0.55, const Color(0xFF1a1020), 0.3, 80);
    _drawHills(canvas, w, h, h * 0.60, const Color(0xFF2a1828), 0.5, 60);

    // ── CASTLE SILHOUETTE (left) ──
    _drawCastle(canvas, w * 0.12, h * 0.42, w, h);

    // ── NEAR HILLS ──
    _drawHills(canvas, w, h, h * 0.68, const Color(0xFF1a2810), 0.8, 40);

    // ── TAVERN (right side, warm glow) ──
    _drawTavern(canvas, w * 0.72, h * 0.62, w, h);

    // ── FOREGROUND HILL ──
    p.color = const Color(0xFF0a1808);
    final fgPath = Path()..moveTo(0, h * 0.82);
    for (double x = 0; x <= w; x += 4) {
      fgPath.lineTo(x, h * 0.82 + sin(x * 0.015) * 12 + sin(x * 0.04) * 5);
    }
    fgPath.lineTo(w, h); fgPath.lineTo(0, h);
    canvas.drawPath(fgPath, p);

    // ── FLOATING DICE in the sky ──
    _drawFloatingDie(canvas, w * 0.3, h * 0.32, 18, 5, time);
    _drawFloatingDie(canvas, w * 0.55, h * 0.25, 14, 3, time + 1.5);
    _drawFloatingDie(canvas, w * 0.42, h * 0.38, 12, 1, time + 3.0);

    // ── GROUND GRADIENT (darkens bottom) ──
    final groundGrad = LinearGradient(
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: [Colors.transparent, const Color(0xFF060408)],
    );
    p.shader = groundGrad.createShader(Rect.fromLTWH(0, h * 0.75, w, h * 0.25));
    canvas.drawRect(Rect.fromLTWH(0, h * 0.75, w, h * 0.25), p);
    p.shader = null;
  }

  void _drawCloud(Canvas canvas, double w, double h, double cx, double cy, double width) {
    final p = Paint()..color = const Color(0xFF2a2040).withOpacity(0.3);
    canvas.drawOval(Rect.fromCenter(center: Offset(cx, cy), width: width, height: width * 0.3), p);
    canvas.drawOval(Rect.fromCenter(center: Offset(cx - width * 0.2, cy + 3), width: width * 0.6, height: width * 0.25), p);
    canvas.drawOval(Rect.fromCenter(center: Offset(cx + width * 0.25, cy + 2), width: width * 0.5, height: width * 0.22), p);
  }

  void _drawHills(Canvas canvas, double w, double h, double baseY, Color color, double freq, double amp) {
    final p = Paint()..color = color;
    final path = Path()..moveTo(0, baseY);
    for (double x = 0; x <= w; x += 3) {
      path.lineTo(x, baseY + sin(x * 0.01 * freq) * amp + sin(x * 0.025 * freq + 1) * amp * 0.4);
    }
    path.lineTo(w, h); path.lineTo(0, h);
    canvas.drawPath(path, p);
  }

  void _drawCastle(Canvas canvas, double cx, double baseY, double w, double h) {
    final p = Paint()..color = const Color(0xFF0a0810);
    // Main keep
    canvas.drawRect(Rect.fromLTWH(cx - 20, baseY - 60, 40, 60), p);
    // Towers
    canvas.drawRect(Rect.fromLTWH(cx - 30, baseY - 80, 14, 80), p);
    canvas.drawRect(Rect.fromLTWH(cx + 16, baseY - 75, 14, 75), p);
    // Tower caps
    final capPath = Path()
      ..moveTo(cx - 33, baseY - 80)..lineTo(cx - 23, baseY - 95)..lineTo(cx - 13, baseY - 80);
    canvas.drawPath(capPath, p);
    final capPath2 = Path()
      ..moveTo(cx + 13, baseY - 75)..lineTo(cx + 23, baseY - 90)..lineTo(cx + 33, baseY - 75);
    canvas.drawPath(capPath2, p);
    // Battlements
    for (double bx = cx - 18; bx < cx + 18; bx += 8) {
      canvas.drawRect(Rect.fromLTWH(bx, baseY - 66, 5, 6), p);
    }
    // Window glow
    final glow = Paint()..color = const Color(0xFFffaa30).withOpacity(0.6 + sin(time * 2) * 0.2);
    canvas.drawRect(Rect.fromLTWH(cx - 5, baseY - 40, 4, 6), glow);
    canvas.drawRect(Rect.fromLTWH(cx + 3, baseY - 40, 4, 6), glow);
  }

  void _drawTavern(Canvas canvas, double cx, double baseY, double w, double h) {
    final p = Paint()..color = const Color(0xFF2a1808);
    // Building
    canvas.drawRect(Rect.fromLTWH(cx - 30, baseY - 28, 60, 28), p);
    // Roof
    final roofPath = Path()
      ..moveTo(cx - 35, baseY - 28)..lineTo(cx, baseY - 48)..lineTo(cx + 35, baseY - 28);
    p.color = const Color(0xFF4a2010);
    canvas.drawPath(roofPath, p);
    // Chimney
    p.color = const Color(0xFF3a1808);
    canvas.drawRect(Rect.fromLTWH(cx + 15, baseY - 52, 8, 24), p);
    // Chimney smoke
    final smoke = Paint()..color = const Color(0xFF888888).withOpacity(0.15);
    for (int i = 0; i < 4; i++) {
      final sy = baseY - 54 - i * 8 + sin(time * 1.5 + i) * 3;
      final sx = cx + 19 + sin(time * 0.8 + i * 0.7) * (3 + i * 2);
      canvas.drawCircle(Offset(sx, sy), 3.0 + i * 1.5, smoke);
    }
    // Windows with warm glow
    final windowGlow = Paint()..color = Color.lerp(
      const Color(0xFFff8820), const Color(0xFFffaa40),
      (sin(time * 3.0) + 1) / 2)!;
    canvas.drawRect(Rect.fromLTWH(cx - 20, baseY - 18, 8, 10), windowGlow);
    canvas.drawRect(Rect.fromLTWH(cx + 12, baseY - 18, 8, 10), windowGlow);
    // Door
    final door = Paint()..color = const Color(0xFF1a0c04);
    canvas.drawRect(Rect.fromLTWH(cx - 5, baseY - 16, 10, 16), door);
    // Door light spill
    final spill = Paint()..color = const Color(0xFFff8820).withOpacity(0.08);
    final spillPath = Path()
      ..moveTo(cx - 5, baseY)..lineTo(cx - 20, baseY + 10)
      ..lineTo(cx + 20, baseY + 10)..lineTo(cx + 5, baseY);
    canvas.drawPath(spillPath, spill);
    // Sign
    p.color = const Color(0xFF6a4a20);
    canvas.drawRect(Rect.fromLTWH(cx - 38, baseY - 22, 6, 10), p);
    p.color = const Color(0xFFc8a050);
    canvas.drawRect(Rect.fromLTWH(cx - 42, baseY - 24, 14, 6), p);
  }

  void _drawFloatingDie(Canvas canvas, double cx, double cy, double size, int face, double phase) {
    final bob = sin(phase * 0.8) * 8;
    final rot = sin(phase * 0.5) * 0.15;
    final dy = cy + bob;

    canvas.save();
    canvas.translate(cx, dy);
    canvas.rotate(rot);

    // Glow
    final glow = Paint()..color = const Color(0xFFffe080).withOpacity(0.2 + sin(phase * 1.5) * 0.1)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawRRect(RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: size + 8, height: size + 8),
      Radius.circular(size * 0.15)), glow);

    // Die body
    final body = Paint()..color = const Color(0xFFd4b878);
    canvas.drawRRect(RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: size, height: size),
      Radius.circular(size * 0.12)), body);

    // Pips
    final pip = Paint()..color = const Color(0xFF3a2008);
    final r = size * 0.08;
    final off = size * 0.25;
    final positions = <Offset>[];
    switch (face) {
      case 1: positions.add(Offset.zero); break;
      case 2: positions.addAll([Offset(-off, -off), Offset(off, off)]); break;
      case 3: positions.addAll([Offset(-off, -off), Offset.zero, Offset(off, off)]); break;
      case 4: positions.addAll([Offset(-off, -off), Offset(off, -off), Offset(-off, off), Offset(off, off)]); break;
      case 5: positions.addAll([Offset(-off, -off), Offset(off, -off), Offset.zero, Offset(-off, off), Offset(off, off)]); break;
      default: positions.addAll([Offset(-off, -off), Offset(off, -off), Offset(-off, 0), Offset(off, 0), Offset(-off, off), Offset(off, off)]); break;
    }
    for (final pos in positions) { canvas.drawCircle(pos, r, pip); }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SplashPanoramaPainter old) => true;
}

class _SplashButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final bool primary;
  const _SplashButton({required this.label, required this.onTap, this.primary = false});
  @override
  State<_SplashButton> createState() => _SplashButtonState();
}

class _SplashButtonState extends State<_SplashButton> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(
            horizontal: widget.primary ? 40 : 20,
            vertical: widget.primary ? 14 : 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: _hover
                ? [const Color(0xFF4a3a10), const Color(0xFF3a2a08)]
                : [const Color(0xFF2a1a08), const Color(0xFF1a1004)]),
            border: Border.all(
              color: _hover ? const Color(0xFFd4b040) : const Color(0xFF6a5020),
              width: widget.primary ? 3 : 2),
            borderRadius: BorderRadius.circular(2),
            boxShadow: _hover ? [
              BoxShadow(color: const Color(0xFFd4b040).withOpacity(0.3), blurRadius: 12),
            ] : [],
          ),
          child: Text(widget.label, style: TextStyle(
            fontFamily: 'monospace',
            fontSize: widget.primary ? 18 : 12,
            fontWeight: FontWeight.bold,
            color: _hover ? const Color(0xFFffe880) : const Color(0xFFc0a050),
            letterSpacing: widget.primary ? 4 : 2,
          )),
        ),
      ),
    );
  }
}
