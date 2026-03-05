import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fark_my_life/core/constants.dart';
import 'package:fark_my_life/core/enums.dart';
import 'package:fark_my_life/models/models.dart';
import 'package:fark_my_life/models/game_history.dart';
import 'package:fark_my_life/systems/audio.dart';
import 'package:fark_my_life/world/town_map.dart';
import 'package:fark_my_life/world/tile_renderer.dart';
import 'package:fark_my_life/world/world_painter.dart';
import 'package:fark_my_life/entities/sprite_renderer.dart';

/// The main overworld game widget with keyboard input and rendering.
class OverworldWidget extends StatefulWidget {
  final PlayerData player;
  final List<NpcData> npcs;
  final List<DiceTableData> diceTables;
  final void Function(NpcData npc) onInteractNpc;
  final void Function(DiceTableData table) onInteractTable;
  final VoidCallback onOpenInventory;
  final void Function(String winner, String loser, int bet)? onNpcGameResolved;
  final VoidCallback? onInteractTournamentBoard;
  final String? championName;
  final String? championId;
  final VoidCallback? onCycleLoadout;
  final VoidCallback? onOpenProfile;
  final bool inputEnabled;

  const OverworldWidget({
    super.key,
    required this.player,
    required this.npcs,
    required this.diceTables,
    required this.onInteractNpc,
    required this.onInteractTable,
    required this.onOpenInventory,
    this.onNpcGameResolved,
    this.onInteractTournamentBoard,
    this.championName,
    this.championId,
    this.onCycleLoadout,
    this.onOpenProfile,
    this.inputEnabled = true,
  });

  @override
  State<OverworldWidget> createState() => _OverworldWidgetState();
}

class _OverworldWidgetState extends State<OverworldWidget>
    with SingleTickerProviderStateMixin {
  late List<List<TileType>> _map;
  late AnimationController _ticker;
  double _time = 0;

  // Input state
  final Set<LogicalKeyboardKey> _keysPressed = {};
  double _animTimer = 0;
  int _animFrame = 0;

  // Interaction prompt
  String? _interactionPrompt;
  dynamic _interactionTarget; // NpcData or DiceTableData

  // Separate dice-seek timers per NPC (fixes timer conflict)
  final Map<String, double> _diceSeekTimers = {};
  String? _rematchNpcId;
  double _rematchTimer = 0;

  // NPC reaction bubbles: npcId -> (text, remaining time)
  final Map<String, _NpcBubble> _npcBubbles = {};

  void _showNpcBubble(String npcId, String text, {double duration = 2.5}) {
    _npcBubbles[npcId] = _NpcBubble(text, duration);
  }

  // Player seated at table
  int? _playerSeatedAtTable;
  double _playerWaitTimer = 0; // periodic re-ping timer when player waits at table

  @override
  void initState() {
    super.initState();
    _map = TownMap.generate();
    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(days: 1), // runs forever
    )..addListener(_onTick);
    _ticker.forward();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick() {
    final dt = 1 / 60; // ~60fps
    _time += dt;
    _updatePlayer(dt);
    _updateNpcs(dt);
    _checkInteractions();
    // Tick rematch bubble timer
    if (_rematchTimer > 0) {
      _rematchTimer -= dt;
      if (_rematchTimer <= 0) _rematchNpcId = null;
    }
    // Tick reaction bubbles
    final expiredBubbles = <String>[];
    for (final entry in _npcBubbles.entries) {
      entry.value.timer -= dt;
      if (entry.value.timer <= 0) expiredBubbles.add(entry.key);
    }
    for (final id in expiredBubbles) _npcBubbles.remove(id);
    // Random idle chatter (very occasional)
    if (Random().nextDouble() < 0.001) { // ~once per 16 seconds
      final idle = widget.npcs.where((n) => n.state == NpcState.idle || n.state == NpcState.wandering).toList();
      if (idle.isNotEmpty) {
        final npc = idle[Random().nextInt(idle.length)];
        final texts = ["...", "♪", "Hmm.", "*yawn*", "!", "?", "Nice day.", "..zzz"];
        _showNpcBubble(npc.id, texts[Random().nextInt(texts.length)], duration: 2.0);
      }
    }
    setState(() {});
  }

  void _updatePlayer(double dt) {
    if (!widget.inputEnabled) {
      _keysPressed.clear();
      return;
    }
    final player = widget.player;
    double dx = 0, dy = 0;

    if (_keysPressed.contains(LogicalKeyboardKey.keyW) ||
        _keysPressed.contains(LogicalKeyboardKey.arrowUp)) {
      dy = -1;
      player.facing = Direction.up;
    }
    if (_keysPressed.contains(LogicalKeyboardKey.keyS) ||
        _keysPressed.contains(LogicalKeyboardKey.arrowDown)) {
      dy = 1;
      player.facing = Direction.down;
    }
    if (_keysPressed.contains(LogicalKeyboardKey.keyA) ||
        _keysPressed.contains(LogicalKeyboardKey.arrowLeft)) {
      dx = -1;
      player.facing = Direction.left;
    }
    if (_keysPressed.contains(LogicalKeyboardKey.keyD) ||
        _keysPressed.contains(LogicalKeyboardKey.arrowRight)) {
      dx = 1;
      player.facing = Direction.right;
    }

    if (dx != 0 || dy != 0) {
      // Normalize diagonal
      if (dx != 0 && dy != 0) {
        dx *= 0.707;
        dy *= 0.707;
      }

      final isSprinting = _keysPressed.contains(LogicalKeyboardKey.shiftLeft) ||
          _keysPressed.contains(LogicalKeyboardKey.shiftRight);
      final speed = GameConstants.playerSpeed * (isSprinting ? 1.8 : 1.0);
      final newX = player.x + dx * speed * dt;
      final newY = player.y + dy * speed * dt;

      // Collision check (try x and y separately for sliding)
      if (_canMoveTo(newX, player.y)) {
        player.x = newX;
      }
      if (_canMoveTo(player.x, newY)) {
        player.y = newY;
      }

      // Walk animation
      _animTimer += dt;
      if (_animTimer >= GameConstants.walkAnimSpeed) {
        _animTimer = 0;
        _animFrame = (_animFrame + 1) % 2;
      }
    } else {
      _animFrame = 0;
      _animTimer = 0;
    }
  }

  bool _canMoveTo(double x, double y) {
    // Check all 4 corners of the character's collision box
    // Player hitbox is roughly 10×10 pixels (in tile coords: ~0.6×0.6)
    const margin = 0.2;
    final points = [
      [x + margin, y + margin],
      [x + 1 - margin, y + margin],
      [x + margin, y + 1 - margin],
      [x + 1 - margin, y + 1 - margin],
    ];

    for (final pt in points) {
      final tx = pt[0].floor();
      final ty = pt[1].floor();
      if (tx < 0 || tx >= _map[0].length || ty < 0 || ty >= _map.length) {
        return false;
      }
      if (!_map[ty][tx].isPassable) {
        return false;
      }
    }
    return true;
  }

  void _updateNpcs(double dt) {
    // ── Global ghost cleanup ──
    // 1. NPCs in seated/playingDice must be near their table
    for (final npc in widget.npcs) {
      if ((npc.state == NpcState.seated || npc.state == NpcState.playingDice) &&
          npc.seatedAtTable != null && npc.seatedAtTable! < widget.diceTables.length) {
        final table = widget.diceTables[npc.seatedAtTable!];
        final dist = _distance(npc.x, npc.y, table.x, table.y);
        if (dist > 3.0) {
          table.unseat(npc.id);
          if (table.npcGameActive) table.endNpcGame();
          npc.seatedAtTable = null;
          npc.state = NpcState.idle;
          npc.stateTimer = 0;
          npc.x = npc.homeX;
          npc.y = npc.homeY;
        }
      }
    }

    // 2. Tables with active games must have both occupants actually present
    for (final table in widget.diceTables) {
      if (!table.npcGameActive) continue;
      // Verify both occupants exist and are in playingDice state near the table
      bool valid = true;
      for (final occId in [table.occupant1Id, table.occupant2Id]) {
        if (occId == null || occId == 'player') continue;
        NpcData? occ;
        for (final n in widget.npcs) { if (n.id == occId) { occ = n; break; } }
        if (occ == null || occ.state != NpcState.playingDice ||
            _distance(occ.x, occ.y, table.x, table.y) > 3.0) {
          valid = false;
          break;
        }
      }
      if (!valid) {
        // Kill the ghost game and reset occupants
        table.endNpcGame();
        for (final occId in [table.occupant1Id, table.occupant2Id]) {
          if (occId == null || occId == 'player') continue;
          table.unseat(occId);
          for (final n in widget.npcs) {
            if (n.id == occId && n.state == NpcState.playingDice) {
              n.seatedAtTable = null;
              n.state = NpcState.idle;
              n.stateTimer = 0;
              n.x = n.homeX;
              n.y = n.homeY;
              break;
            }
          }
        }
      }
    }

    for (final npc in widget.npcs) {
      // Separate dice-seek timer
      _diceSeekTimers[npc.id] = (_diceSeekTimers[npc.id] ?? 0) + dt;

      switch (npc.state) {
        case NpcState.idle:
          npc.stateTimer += dt;
          npc.animFrame = 0; // Stand still
          if (npc.stateTimer > 2.0) {
            npc.stateTimer = 0;
            // 40% chance to work, 60% chance to wander
            final rng = Random();
            if (rng.nextDouble() < 0.4) {
              _startNpcWork(npc);
            } else {
              _startNpcWander(npc);
            }
          }
          break;

        case NpcState.working:
          npc.stateTimer += dt;
          npc.animTimer += dt;
          if (npc.animTimer >= 0.4) {
            npc.animTimer = 0;
            npc.animFrame = (npc.animFrame + 1) % 2;
            // Occasionally turn to face a different direction
            if (Random().nextDouble() < 0.15) {
              npc.facing = Direction.values[Random().nextInt(4)];
            }
          }
          if (npc.stateTimer > 4.0 + Random().nextDouble() * 6) {
            npc.state = NpcState.idle;
            npc.stateTimer = 0;
          }
          break;

        case NpcState.wandering:
          npc.stateTimer += dt;
          _moveNpcToward(npc, npc.wanderTargetX, npc.wanderTargetY, dt);
          final dist = _distance(npc.x, npc.y, npc.wanderTargetX, npc.wanderTargetY);
          if (dist < 0.3 || npc.stateTimer > 8.0) {
            // Arrived or timed out
            npc.state = NpcState.idle;
            npc.stateTimer = 0;
          }
          break;

        case NpcState.walkingToTable:
          npc.stateTimer += dt;
          if (npc.seatedAtTable != null &&
              npc.seatedAtTable! < widget.diceTables.length) {
            final table = widget.diceTables[npc.seatedAtTable!];
            final seatPos = table.seatWorldPos(
                table.occupant1Id == npc.id ? 0 : 1);
            final tableDist = _distance(npc.x, npc.y, table.x, table.y);

            // Snap to seat when close enough (2.5 tiles) or timed out
            if (tableDist < 2.5 || npc.stateTimer > 12.0) {
              npc.state = NpcState.seated;
              npc.x = seatPos.dx;
              npc.y = seatPos.dy;
              npc.stateTimer = 0;
              npc.animFrame = 0;
              final tdx = table.x.toDouble() - npc.x;
              final tdy = table.y.toDouble() - npc.y;
              if (tdx.abs() > tdy.abs()) {
                npc.facing = tdx > 0 ? Direction.right : Direction.left;
              } else {
                npc.facing = tdy > 0 ? Direction.down : Direction.up;
              }

              final playerHere = table.occupant1Id == 'player' || table.occupant2Id == 'player';
              if (playerHere) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  widget.onInteractTable(table);
                });
              }
            } else {
              // Walk toward a point near the seat (not the table tile itself)
              final approachX = seatPos.dx;
              final approachY = seatPos.dy;
              _moveNpcToward(npc, approachX.toDouble(), approachY.toDouble(), dt);
            }
          } else {
            // Invalid table reference — reset
            npc.seatedAtTable = null;
            npc.state = NpcState.idle;
            npc.stateTimer = 0;
          }
          break;

        case NpcState.seated:
          npc.stateTimer += dt;
          npc.animFrame = 0;
          if (npc.seatedAtTable != null &&
              npc.seatedAtTable! < widget.diceTables.length) {
            final table = widget.diceTables[npc.seatedAtTable!];
            final isPlayerAtSameTable =
                table.occupant1Id == 'player' || table.occupant2Id == 'player';

            // Two NPCs at table — only start when BOTH are physically seated
            final bothNpcs = table.isFull &&
                table.occupant1Id != 'player' &&
                table.occupant2Id != 'player';

            if (bothNpcs && npc.stateTimer > 3.0 && !table.npcGameActive) {
              // Only seat 1 NPC triggers the transition (prevents double-fire)
              if (table.occupant1Id == npc.id) {
                // Verify BOTH NPCs are in seated state (not still walking)
                NpcData? other;
                for (final n in widget.npcs) {
                  if (n.id == table.occupant2Id) { other = n; break; }
                }
                if (other == null ||
                    npc.state != NpcState.seated ||
                    other.state != NpcState.seated) {
                  break; // wait until both are seated
                }

                // Verify physical proximity
                final npcDist = _distance(npc.x, npc.y, table.x, table.y);
                final otherDist = _distance(other.x, other.y, table.x, table.y);

                if (npcDist > 2.5 || otherDist > 2.5) {
                  // Ghost occupant — one NPC isn't actually here, clean up
                  if (npcDist > 2.5) {
                    table.unseat(npc.id);
                    npc.seatedAtTable = null;
                    npc.state = NpcState.idle;
                    npc.stateTimer = 0;
                  }
                  if (other != null && otherDist > 2.5) {
                    table.unseat(other.id);
                    other.seatedAtTable = null;
                    other.state = NpcState.idle;
                    other.stateTimer = 0;
                  }
                  break;
                }

                final rng = Random();
                final bet = 1 + rng.nextInt(3); // 1-3g for NPC games
                final duration = 35.0 + rng.nextDouble() * 25.0; // 35-60s
                table.startNpcGame(bet, duration);

                // Transition both NPCs to playingDice
                npc.state = NpcState.playingDice;
                npc.stateTimer = 0;
                for (final other in widget.npcs) {
                  if (other.id == table.occupant2Id) {
                    other.state = NpcState.playingDice;
                    other.stateTimer = 0;
                    break;
                  }
                }
              }
              break;
            }

            // Leave if alone too long (no one to play with)
            final leaveTime = isPlayerAtSameTable ? 90.0 : 30.0;
            if (npc.stateTimer > leaveTime && !bothNpcs) {
              table.unseat(npc.id);
              npc.seatedAtTable = null;
              npc.state = NpcState.returning;
              npc.stateTimer = 0;
              _diceSeekTimers[npc.id] = -15.0;
            }
          }
          break;

        case NpcState.playingDice:
          // Animate: subtle bobbing to show activity
          npc.animTimer += dt;
          if (npc.animTimer >= 0.6) {
            npc.animTimer = 0;
            npc.animFrame = (npc.animFrame + 1) % 2;
          }
          npc.stateTimer += dt;

          // Hard safety timeout: no game should last more than 90 seconds
          if (npc.stateTimer > 90.0) {
            if (npc.seatedAtTable != null && npc.seatedAtTable! < widget.diceTables.length) {
              final table = widget.diceTables[npc.seatedAtTable!];
              table.unseat(npc.id);
              if (table.npcGameActive) table.endNpcGame();
            }
            npc.seatedAtTable = null;
            npc.state = NpcState.returning;
            npc.stateTimer = 0;
            _diceSeekTimers[npc.id] = -20.0;
            break;
          }

          // Only seat 1 NPC manages the game timer
          if (npc.seatedAtTable != null &&
              npc.seatedAtTable! < widget.diceTables.length) {
            final table = widget.diceTables[npc.seatedAtTable!];

            // If game already ended (occupant1 resolved it), leave immediately
            if (!table.npcGameActive && npc.stateTimer > 1.0) {
              table.unseat(npc.id);
              npc.seatedAtTable = null;
              npc.state = NpcState.returning;
              npc.stateTimer = 0;
              _diceSeekTimers[npc.id] = -20.0;
              break;
            }

            if (table.npcGameActive && table.occupant1Id == npc.id) {
              table.npcGameTimer += dt;

              // Sync scores from live game state if active
              if (table.liveGameState != null) {
                table.npcScore1 = table.liveGameState!.player1Score;
                table.npcScore2 = table.liveGameState!.player2Score;
              } else {
                // Simulate score progression when no live game
                final progress = (table.npcGameTimer / table.npcGameDuration).clamp(0.0, 1.0);
                final targetTotal = (GameConstants.farkleWinScore * progress).round();
                if (table.npcScore1 + table.npcScore2 < targetTotal) {
                  final rng = Random();
                  if (rng.nextBool()) {
                    table.npcScore1 += (100 + rng.nextInt(200));
                  } else {
                    table.npcScore2 += (100 + rng.nextInt(200));
                  }
                }
              }

              // Auto-resolve when game duration expires
              if (table.npcGameTimer >= table.npcGameDuration) {
                NpcData? otherNpc;
                for (final other in widget.npcs) {
                  if (other.id == table.occupant2Id) { otherNpc = other; break; }
                }

                // Winner based on dice skill (higher diceChance = better player)
                final rng = Random();
                final npc1Skill = npc.diceChance + rng.nextDouble() * 0.3;
                final npc2Skill = (otherNpc?.diceChance ?? 0.5) + rng.nextDouble() * 0.3;
                final npcWon = npc1Skill >= npc2Skill;
                final betSize = table.npcGameBet;

                if (npcWon) {
                  npc.gold = (npc.gold + betSize).clamp(0, npc.maxGold);
                  otherNpc?.gold = ((otherNpc?.gold ?? 0) - betSize).clamp(0, otherNpc?.maxGold ?? 999);
                } else {
                  npc.gold = (npc.gold - betSize).clamp(0, npc.maxGold);
                  otherNpc?.gold = ((otherNpc?.gold ?? 0) + betSize).clamp(0, otherNpc?.maxGold ?? 999);
                }

                // End game
                table.endNpcGame();

                if (widget.onNpcGameResolved != null && otherNpc != null) {
                  final winner = npcWon ? npc : otherNpc;
                  final loser = npcWon ? otherNpc : npc;
                  widget.onNpcGameResolved!(winner.name, loser.name, betSize);
                  // Record to both NPCs' histories
                  winner.npcHistory.recordGame(GameRecord(
                    opponentId: loser.id, opponentName: loser.name,
                    won: true, betAmount: betSize, playerScore: 0, opponentScore: 0));
                  loser.npcHistory.recordGame(GameRecord(
                    opponentId: winner.id, opponentName: winner.name,
                    won: false, betAmount: betSize, playerScore: 0, opponentScore: 0));
                  // Reaction bubbles
                  final winTexts = ['Ha!', 'Yes!', '💰', 'Easy.', '😏'];
                  final loseTexts = ['Ugh.', '...', '😤', 'Next time.', 'Curses!'];
                  _showNpcBubble(winner.id, winTexts[rng.nextInt(winTexts.length)]);
                  _showNpcBubble(loser.id, loseTexts[rng.nextInt(loseTexts.length)]);
                }

                // Rematch chance: 40% if both have gold, otherwise leave
                final canRematch = npc.gold >= 1 && (otherNpc?.gold ?? 0) >= 1;
                final wantsRematch = canRematch && rng.nextDouble() < 0.40;

                if (wantsRematch && otherNpc != null) {
                  // Stay seated, start a new game after a brief pause
                  npc.state = NpcState.seated;
                  npc.stateTimer = 0; // will take 3+ seconds to start new game
                  otherNpc.state = NpcState.seated;
                  otherNpc.stateTimer = 0;
                  // Mark for rematch chat bubble
                  _rematchNpcId = npcWon ? otherNpc.id : npc.id;
                  _rematchTimer = 3.0; // show bubble for 3 seconds
                } else {
                  // Both NPCs leave
                  for (final leaver in [npc, otherNpc]) {
                    if (leaver != null) {
                      table.unseat(leaver.id);
                      leaver.seatedAtTable = null;
                      leaver.state = NpcState.returning;
                      leaver.stateTimer = 0;
                      _diceSeekTimers[leaver.id] = -25.0;
                    }
                  }
                }
              }
            }
          }
          break;

        case NpcState.returning:
          // Walk home smoothly
          npc.stateTimer += dt;
          _moveNpcToward(npc, npc.homeX, npc.homeY, dt);
          final homeDist = _distance(npc.x, npc.y, npc.homeX, npc.homeY);
          if (homeDist < 0.5 || npc.stateTimer > 15.0) {
            // Arrived home (or stuck too long — snap)
            if (npc.stateTimer > 15.0) {
              npc.x = npc.homeX;
              npc.y = npc.homeY;
            }
            npc.state = NpcState.idle;
            npc.stateTimer = 0;
            npc.stuckTimer = 0;
          }
          break;
      }

      // Separate dice-seek check (using dedicated timer with cooldown)
      if (npc.state == NpcState.idle || npc.state == NpcState.wandering ||
          npc.state == NpcState.working) {
        final seekTimer = _diceSeekTimers[npc.id] ?? 0;
        // Check if player is waiting at a table — seek much faster
        bool playerWaiting = false;
        for (final t in widget.diceTables) {
          if ((t.occupant1Id == 'player' || t.occupant2Id == 'player') && !t.isFull) {
            playerWaiting = true;
            break;
          }
        }
        final seekThreshold = playerWaiting ? 4.0 : 8.0;
        if (seekTimer > seekThreshold) {
          _diceSeekTimers[npc.id] = 0;
          // Cap: max 6 NPCs at tables at any time
          final seatedCount = widget.npcs
              .where((n) => n.state == NpcState.seated ||
                            n.state == NpcState.walkingToTable ||
                            n.state == NpcState.playingDice)
              .length;
          if (seatedCount < 6) {
            _maybeSeekDiceTable(npc);
          }
        }
      }
    }
  }

  void _startNpcWork(NpcData npc) {
    // Just start working in place - NPC does "activity" at current position
    npc.state = NpcState.working;
    npc.stateTimer = 0;
    npc.animTimer = 0;
    // Face a random direction for variety
    final rng = Random();
    npc.facing = Direction.values[rng.nextInt(4)];
  }

  void _startNpcWander(NpcData npc) {
    final rng = Random();
    final radius = GameConstants.npcWanderRadius;

    // Try up to 8 times to find a passable target
    for (int attempt = 0; attempt < 8; attempt++) {
      final wx = npc.homeX + (rng.nextDouble() * 2 - 1) * radius;
      final wy = npc.homeY + (rng.nextDouble() * 2 - 1) * radius;
      final tx = wx.clamp(1, _map[0].length - 2.0).floor();
      final ty = wy.clamp(1, _map.length - 2.0).floor();

      if (tx >= 0 && tx < _map[0].length && ty >= 0 && ty < _map.length &&
          _map[ty][tx].isPassable) {
        npc.wanderTargetX = wx.clamp(1, _map[0].length - 2.0);
        npc.wanderTargetY = wy.clamp(1, _map.length - 2.0);
        npc.state = NpcState.wandering;
        npc.stateTimer = 0;
        return;
      }
    }
    // Couldn't find passable target — stay idle
  }

  void _moveNpcToward(NpcData npc, double targetX, double targetY, double dt) {
    final dx = targetX - npc.x;
    final dy = targetY - npc.y;
    final dist = sqrt(dx * dx + dy * dy);

    if (dist < 0.1) {
      npc.stuckTimer = 0;
      return;
    }

    final speed = GameConstants.npcSpeed;
    final moveX = (dx / dist) * speed * dt;
    final moveY = (dy / dist) * speed * dt;

    // Update facing
    if (dx.abs() > dy.abs()) {
      npc.facing = dx > 0 ? Direction.right : Direction.left;
    } else {
      npc.facing = dy > 0 ? Direction.down : Direction.up;
    }

    final newX = npc.x + moveX;
    final newY = npc.y + moveY;
    final ntx = newX.floor();
    final nty = newY.floor();

    bool moved = false;

    // Try full movement
    if (ntx >= 0 && ntx < _map[0].length && nty >= 0 && nty < _map.length &&
        _map[nty][ntx].isPassable) {
      npc.x = newX;
      npc.y = newY;
      moved = true;
    } else {
      // Try sliding along X axis
      final sxX = npc.x + moveX;
      final stx = sxX.floor();
      final sty = npc.y.floor();
      if (stx >= 0 && stx < _map[0].length && sty >= 0 && sty < _map.length &&
          _map[sty][stx].isPassable) {
        npc.x = sxX;
        moved = true;
      }
      // Try sliding along Y axis
      final syY = npc.y + moveY;
      final stx2 = npc.x.floor();
      final sty2 = syY.floor();
      if (stx2 >= 0 && stx2 < _map[0].length && sty2 >= 0 && sty2 < _map.length &&
          _map[sty2][stx2].isPassable) {
        npc.y = syY;
        moved = true;
      }
    }

    // Stuck detection — if NPC can't move for too long, teleport
    if (!moved) {
      npc.stuckTimer += dt;
      if (npc.stuckTimer > 2.0) {
        // Teleport to target if it's passable, else teleport home
        final tx = targetX.floor();
        final ty = targetY.floor();
        if (tx >= 0 && tx < _map[0].length && ty >= 0 && ty < _map.length &&
            _map[ty][tx].isPassable) {
          npc.x = targetX;
          npc.y = targetY;
        } else {
          npc.state = NpcState.returning;
          npc.stateTimer = 0;
        }
        npc.stuckTimer = 0;
      }
    } else {
      npc.stuckTimer = 0;
    }

    // Walk animation
    npc.animTimer += dt;
    if (npc.animTimer >= GameConstants.walkAnimSpeed * 1.5) {
      npc.animTimer = 0;
      npc.animFrame = (npc.animFrame + 1) % 2;
    }
  }

  void _maybeSeekDiceTable(NpcData npc) {
    if (npc.gold < GameConstants.minBet) return;

    final rng = Random();
    const mapDiag = 63.0; // sqrt(50^2 + 38^2)
    const maxRange = mapDiag * 0.40; // ~25 tiles awareness radius

    // Check if player is seated at a table
    bool playerAtAnyTable = false;
    int? playerTableId;
    for (final t in widget.diceTables) {
      if (t.occupant1Id == 'player' || t.occupant2Id == 'player') {
        playerAtAnyTable = true;
        playerTableId = t.id;
        break;
      }
    }

    // Much higher chance when player is waiting at a table
    // NPCs also have solid base chance to seek games on their own
    final effectiveChance = playerAtAnyTable
        ? 0.85 // very likely to respond to player's challenge
        : npc.diceChance + 0.15; // base bump so even cautious NPCs play

    if (rng.nextDouble() > effectiveChance) return;

    // Find best table within range
    // Priority: player's table > NPC-occupied table > empty table
    DiceTableData? bestTable;
    double bestDist = double.infinity;
    int bestPriority = 0; // 0=empty, 1=npc waiting, 2=player waiting

    for (final table in widget.diceTables) {
      if (table.isFull) continue;
      if (table.npcGameActive) continue; // game in progress
      final dist = _distance(npc.x, npc.y, table.x, table.y);
      if (dist > maxRange) continue;

      int priority = 0;
      if (playerTableId != null && table.id == playerTableId) {
        priority = 2; // player's table - highest priority
      } else if (table.hasOneSeat) {
        priority = 1; // NPC waiting - prefer joining them
      }

      if (priority > bestPriority || (priority == bestPriority && dist < bestDist)) {
        bestTable = table;
        bestDist = dist;
        bestPriority = priority;
      }
    }

    if (bestTable != null) {
      if (bestTable.seat(npc.id)) {
        npc.seatedAtTable = bestTable.id;
        // Snap directly to seat position
        final seatIdx = bestTable.occupant1Id == npc.id ? 0 : 1;
        final seatPos = bestTable.seatWorldPos(seatIdx);
        npc.x = seatPos.dx;
        npc.y = seatPos.dy;
        npc.state = NpcState.seated;
        npc.stateTimer = 0;
        npc.animFrame = 0;
        // Face toward table
        final tdx = bestTable.x.toDouble() - npc.x;
        final tdy = bestTable.y.toDouble() - npc.y;
        if (tdx.abs() > tdy.abs()) {
          npc.facing = tdx > 0 ? Direction.right : Direction.left;
        } else {
          npc.facing = tdy > 0 ? Direction.down : Direction.up;
        }
        GameAudio.chairScoot();
      }
    }
  }

  double _distance(double x1, double y1, double x2, double y2) {
    final dx = x2 - x1;
    final dy = y2 - y1;
    return sqrt(dx * dx + dy * dy);
  }

  void _checkInteractions() {
    final player = widget.player;
    _interactionPrompt = null;
    _interactionTarget = null;

    final range = GameConstants.interactionRange;

    // Check tournament board
    const boardX = 20.0;
    const boardY = 15.0;
    if (_distance(player.x, player.y, boardX, boardY) < range) {
      _interactionPrompt = '[E] Tournament Board';
      _interactionTarget = 'tournament_board';
      return;
    }

    // Check dice tables FIRST — tables take priority over seated NPCs
    for (final table in widget.diceTables) {
      if (_distance(player.x, player.y, table.x, table.y) < range) {
        if (table.isFull) {
          _interactionPrompt = '[E] Watch game';
        } else if (table.hasOneSeat) {
          final occupantId = table.occupant1Id ?? table.occupant2Id;
          if (occupantId == 'player') {
            _interactionPrompt = '[E] Wait for challenger...';
          } else {
            // NPC is seated — challenge them
            NpcData? npc;
            for (final n in widget.npcs) {
              if (n.id == occupantId) { npc = n; break; }
            }
            _interactionPrompt = '[E] Challenge ${npc?.name ?? "opponent"}';
          }
        } else {
          _interactionPrompt = '[E] Sit down';
        }
        _interactionTarget = table;
        return;
      }
    }

    // Check NPCs (only if not near a table)
    for (final npc in widget.npcs) {
      if (_distance(player.x, player.y, npc.x, npc.y) < range) {
        if (npc.state == NpcState.seated || npc.state == NpcState.playingDice) {
          if (npc.seatedAtTable != null &&
              npc.seatedAtTable! < widget.diceTables.length) {
            final table = widget.diceTables[npc.seatedAtTable!];
            if (table.isFull && npc.state == NpcState.playingDice) {
              _interactionPrompt = '[E] Watch game';
            } else {
              _interactionPrompt = '[E] Challenge ${npc.name}';
            }
            _interactionTarget = table;
            return;
          }
        }
        if (npc.id == 'merchant_vex') {
          _interactionPrompt = '[E] Browse Shop';
        } else {
          _interactionPrompt = '[E] ${npc.name} — Profile';
        }
        _interactionTarget = npc;
        return;
      }
    }
  }

  void _handleInteraction() {
    if (_interactionTarget == 'tournament_board') {
      widget.onInteractTournamentBoard?.call();
    } else if (_interactionTarget is NpcData) {
      widget.onInteractNpc(_interactionTarget as NpcData);
    } else if (_interactionTarget is DiceTableData) {
      widget.onInteractTable(_interactionTarget as DiceTableData);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: widget.inputEnabled,
      onKeyEvent: (node, event) {
        if (!widget.inputEnabled) return KeyEventResult.ignored;
        if (event is KeyDownEvent) {
          _keysPressed.add(event.logicalKey);

          // Handle single-press keys
          if (event.logicalKey == LogicalKeyboardKey.keyE ||
              event.logicalKey == LogicalKeyboardKey.space) {
            _handleInteraction();
          }
          if (event.logicalKey == LogicalKeyboardKey.keyI) {
            widget.onOpenInventory();
          }
          if (event.logicalKey == LogicalKeyboardKey.keyP) {
            widget.onOpenProfile?.call();
          }
          if (event.logicalKey == LogicalKeyboardKey.keyQ ||
              event.logicalKey == LogicalKeyboardKey.tab) {
            widget.onCycleLoadout?.call();
          }
        } else if (event is KeyUpEvent) {
          _keysPressed.remove(event.logicalKey);
        }
        return KeyEventResult.handled;
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final viewportSize = Size(constraints.maxWidth, constraints.maxHeight);

          // Camera centered on player
          final cameraX = widget.player.x - viewportSize.width / (2 * GameConstants.scaledTile);
          final cameraY = widget.player.y - viewportSize.height / (2 * GameConstants.scaledTile);

          return Stack(
            children: [
              // World + entities
              CustomPaint(
                size: viewportSize,
                painter: _GamePainter(
                  map: _map,
                  cameraX: cameraX,
                  cameraY: cameraY,
                  time: _time,
                  player: widget.player,
                  npcs: widget.npcs,
                  playerAnimFrame: _animFrame,
                  viewportSize: viewportSize,
                  rematchNpcId: _rematchNpcId,
                  npcBubbles: _npcBubbles,
                  championId: widget.championId,
                ),
              ),

              // Interaction prompt
              if (_interactionPrompt != null)
                Positioned(
                  bottom: 90,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: GameColors.uiBg,
                        border:
                            Border.all(color: GameColors.uiBorder, width: 2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _interactionPrompt!,
                        style: const TextStyle(
                          color: GameColors.uiText,
                          fontSize: 14,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              // (Champion banner removed — shown on tournament board instead)
            ],
          );
        },
      ),
    );
  }
}

/// Combines world tiles + entity sprites into one paint pass.
class _GamePainter extends CustomPainter {
  final List<List<TileType>> map;
  final double cameraX;
  final double cameraY;
  final double time;
  final PlayerData player;
  final List<NpcData> npcs;
  final int playerAnimFrame;
  final Size viewportSize;
  final String? rematchNpcId;
  final Map<String, _NpcBubble> npcBubbles;
  final String? championId;

  _GamePainter({
    required this.map,
    required this.cameraX,
    required this.cameraY,
    required this.time,
    required this.player,
    required this.npcs,
    required this.playerAnimFrame,
    required this.viewportSize,
    this.rematchNpcId,
    this.npcBubbles = const {},
    this.championId,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final ts = GameConstants.scaledTile;

    // ── Draw world tiles ─────────────────────────────────────────
    final startTileX = cameraX.floor() - 1;
    final startTileY = cameraY.floor() - 1;
    final endTileX = startTileX + (size.width / ts).ceil() + 2;
    final endTileY = startTileY + (size.height / ts).ceil() + 2;

    for (int ty = startTileY; ty <= endTileY; ty++) {
      for (int tx = startTileX; tx <= endTileX; tx++) {
        final sx = (tx - cameraX) * ts;
        final sy = (ty - cameraY) * ts;

        if (tx < 0 || tx >= map[0].length || ty < 0 || ty >= map.length) {
          canvas.drawRect(
            Rect.fromLTWH(sx, sy, ts, ts),
            Paint()..color = Colors.black,
          );
          continue;
        }

        TileRenderer.drawTile(canvas, map[ty][tx], sx, sy,
            tileX: tx, tileY: ty, time: time);
      }
    }

    // ── Draw entities sorted by Y (painter's algorithm) ──────────
    final entities = <_EntityDraw>[];

    // Player
    entities.add(_EntityDraw(
      y: player.y,
      draw: (c) {
        final sx = (player.x - cameraX) * ts;
        final sy = (player.y - cameraY) * ts;
        SpriteRenderer.drawCharacter(
          c, sx, sy,
          bodyColor: const Color(0xFF3060B0),
          accentColor: const Color(0xFF204080),
          facing: player.facing,
          animFrame: playerAnimFrame,
          isPlayer: true,
        );
        // Crown if player is reigning champion
        if (championId == 'player') {
          final crownX = sx + ts / 2;
          final crownY = sy - 10.0;
          final cp = Paint()..color = const Color(0xFFffd700);
          c.drawRect(Rect.fromCenter(center: Offset(crownX, crownY + 2), width: 10, height: 4), cp);
          final crownPath = Path()
            ..moveTo(crownX - 5, crownY + 0.5)
            ..lineTo(crownX - 4, crownY - 3)
            ..lineTo(crownX - 1.5, crownY - 0.5)
            ..lineTo(crownX, crownY - 4)
            ..lineTo(crownX + 1.5, crownY - 0.5)
            ..lineTo(crownX + 4, crownY - 3)
            ..lineTo(crownX + 5, crownY + 0.5)
            ..close();
          c.drawPath(crownPath, cp);
          c.drawCircle(Offset(crownX, crownY - 2.5), 1, Paint()..color = const Color(0xFFff3030));
          c.drawCircle(Offset(crownX - 3, crownY - 1.5), 0.8, Paint()..color = const Color(0xFF40c0ff));
          c.drawCircle(Offset(crownX + 3, crownY - 1.5), 0.8, Paint()..color = const Color(0xFF40c0ff));
        }
      },
    ));

    // NPCs
    for (final npc in npcs) {
      entities.add(_EntityDraw(
        y: npc.y,
        draw: (c) {
          final sx = (npc.x - cameraX) * ts;
          final sy = (npc.y - cameraY) * ts;

          // Skip if off-screen
          if (sx < -ts || sx > size.width + ts ||
              sy < -ts || sy > size.height + ts) {
            return;
          }

          // Show name only when close to player
          final dist = sqrt(
              (player.x - npc.x) * (player.x - npc.x) +
              (player.y - npc.y) * (player.y - npc.y));
          final showName = dist < 4.0;

          SpriteRenderer.drawCharacter(
            c, sx, sy,
            bodyColor: npc.primaryColor,
            accentColor: npc.secondaryColor,
            facing: npc.facing,
            animFrame: npc.animFrame,
            nameTag: showName ? npc.name : null,
            isSeated: npc.state == NpcState.seated ||
                      npc.state == NpcState.playingDice,
          );

          // Crown over reigning tournament champion
          if (championId == npc.id) {
            final crownX = sx + ts / 2;
            final crownY = sy - 10.0;
            final cp = Paint()..color = const Color(0xFFffd700);
            // Crown base
            c.drawRect(Rect.fromCenter(center: Offset(crownX, crownY + 2), width: 10, height: 4), cp);
            // Crown points
            final crownPath = Path()
              ..moveTo(crownX - 5, crownY + 0.5)
              ..lineTo(crownX - 4, crownY - 3)
              ..lineTo(crownX - 1.5, crownY - 0.5)
              ..lineTo(crownX, crownY - 4)
              ..lineTo(crownX + 1.5, crownY - 0.5)
              ..lineTo(crownX + 4, crownY - 3)
              ..lineTo(crownX + 5, crownY + 0.5)
              ..close();
            c.drawPath(crownPath, cp);
            // Gems
            c.drawCircle(Offset(crownX, crownY - 2.5), 1, Paint()..color = const Color(0xFFff3030));
            c.drawCircle(Offset(crownX - 3, crownY - 1.5), 0.8, Paint()..color = const Color(0xFF40c0ff));
            c.drawCircle(Offset(crownX + 3, crownY - 1.5), 0.8, Paint()..color = const Color(0xFF40c0ff));
          }

          // Draw indicator above seated/playing NPCs
          if (npc.state == NpcState.seated) {
            // Waiting — pulsing dice icon
            final pulse = (0.6 + 0.4 * sin(time * 3.0 + npc.x));
            final glowPaint = Paint()
              ..color = Color.fromRGBO(255, 215, 0, 0.3 * pulse)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
            c.drawCircle(Offset(sx + ts / 2, sy - 4), 8, glowPaint);
            final iconPaint = Paint()
              ..color = Color.fromRGBO(255, 215, 0, pulse);
            final iconRect = RRect.fromRectAndRadius(
              Rect.fromCenter(
                  center: Offset(sx + ts / 2, sy - 4),
                  width: 10, height: 10),
              const Radius.circular(2),
            );
            c.drawRRect(iconRect, iconPaint);
            final dotPaint = Paint()
              ..color = Color.fromRGBO(0, 0, 0, pulse);
            c.drawCircle(Offset(sx + ts / 2, sy - 4), 1.5, dotPaint);
          } else if (npc.state == NpcState.playingDice) {
            // Actively playing — bouncing dice pair
            final bounce = sin(time * 5.0 + npc.x * 2.0).abs() * 3.0;
            final alpha = (0.7 + 0.3 * sin(time * 4.0 + npc.y));
            final diePaint = Paint()
              ..color = Color.fromRGBO(255, 255, 240, alpha);
            final dotP = Paint()
              ..color = Color.fromRGBO(40, 20, 10, alpha);
            // Left die
            final lx = sx + ts / 2 - 7;
            final ly = sy - 6 - bounce;
            c.drawRRect(RRect.fromRectAndRadius(
              Rect.fromLTWH(lx, ly, 8, 8), const Radius.circular(1.5)),
              diePaint);
            c.drawCircle(Offset(lx + 4, ly + 4), 1.2, dotP);
            // Right die
            final rx = sx + ts / 2 + 1;
            final ry = sy - 5 - bounce * 0.7;
            c.drawRRect(RRect.fromRectAndRadius(
              Rect.fromLTWH(rx, ry, 8, 8), const Radius.circular(1.5)),
              diePaint);
            c.drawCircle(Offset(rx + 2.5, ry + 2.5), 1.0, dotP);
            c.drawCircle(Offset(rx + 5.5, ry + 5.5), 1.0, dotP);
          }

          // Rematch chat bubble
          if (rematchNpcId == npc.id) {
            final bx = sx + ts / 2;
            final by = sy - 14.0;
            // Speech bubble background
            final bubblePaint = Paint()..color = const Color(0xE0f0e8d0);
            final bubbleRect = RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset(bx, by), width: 42, height: 14),
              const Radius.circular(4));
            c.drawRRect(bubbleRect, bubblePaint);
            // Bubble tail
            final tailPath = Path()
              ..moveTo(bx - 3, by + 7)
              ..lineTo(bx, by + 12)
              ..lineTo(bx + 3, by + 7);
            c.drawPath(tailPath, bubblePaint);
            // Border
            final borderPaint = Paint()
              ..color = const Color(0xFF4a3a20)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1;
            c.drawRRect(bubbleRect, borderPaint);
            // "Again?" text (tiny dots simulating text)
            final textPaint = Paint()..color = const Color(0xFF3a2a10);
            for (double tx = bx - 14; tx < bx + 14; tx += 3.5) {
              c.drawCircle(Offset(tx, by), 1.0, textPaint);
            }
          }

          // General reaction bubble
          final bubble = npcBubbles[npc.id];
          if (bubble != null && rematchNpcId != npc.id) {
            final bx = sx + ts / 2;
            final by = sy - 16.0;
            final fadeAlpha = bubble.timer < 0.5 ? bubble.timer / 0.5 : 1.0;
            // Bubble background
            final bubblePaint = Paint()..color = Color.fromRGBO(240, 232, 208, 0.9 * fadeAlpha);
            final textWidth = bubble.text.length * 4.5 + 10;
            final bubbleRect = RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset(bx, by), width: textWidth, height: 14),
              const Radius.circular(4));
            c.drawRRect(bubbleRect, bubblePaint);
            // Bubble tail
            final tailPath = Path()
              ..moveTo(bx - 3, by + 7)..lineTo(bx, by + 11)..lineTo(bx + 3, by + 7);
            c.drawPath(tailPath, bubblePaint);
            // Border
            final borderP = Paint()
              ..color = Color.fromRGBO(74, 58, 32, 0.8 * fadeAlpha)
              ..style = PaintingStyle.stroke..strokeWidth = 0.8;
            c.drawRRect(bubbleRect, borderP);
            // Text as dots (pixel style)
            final textP = Paint()..color = Color.fromRGBO(58, 42, 16, fadeAlpha);
            final chars = bubble.text.length;
            final startX = bx - (chars * 2.2);
            for (int ci = 0; ci < chars; ci++) {
              c.drawCircle(Offset(startX + ci * 4.5, by), 1.0, textP);
            }
          }
        },
      ));
    }

    entities.sort((a, b) => a.y.compareTo(b.y));
    for (final e in entities) {
      e.draw(canvas);
    }
  }

  @override
  bool shouldRepaint(covariant _GamePainter old) => true;
}

class _EntityDraw {
  final double y;
  final void Function(Canvas) draw;
  _EntityDraw({required this.y, required this.draw});
}

class _NpcBubble {
  final String text;
  double timer;
  _NpcBubble(this.text, this.timer);
}
