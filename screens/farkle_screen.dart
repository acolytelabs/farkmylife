import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fark_my_life/core/constants.dart';
import 'package:fark_my_life/core/enums.dart';
import 'package:fark_my_life/models/models.dart';
import 'package:fark_my_life/models/npc_definitions.dart';
import 'package:fark_my_life/systems/farkle_engine.dart';
import 'package:fark_my_life/systems/loot_system.dart';
import 'package:fark_my_life/entities/dice_renderer.dart';
import 'package:fark_my_life/models/dice_tiers.dart';

enum _Reaction { neutral, happy, excited, worried, shocked, smug, defeated }

class FarkleScreen extends StatefulWidget {
  final PlayerData player;
  final NpcData opponent;
  final int betAmount;
  final void Function(bool playerWon, DiceItem? loot) onGameEnd;

  /// If set, observation mode: both sides are AI-controlled.
  /// This NPC plays the "player 1" side; [opponent] plays "player 2" side.
  final NpcData? observeNpc1;
  /// Called when player exits observation early (ESC or Leave button).
  final VoidCallback? onLeaveObservation;
  /// How far along the NPC game is (0.0 = just started, 1.0 = nearly done).
  /// When > 0, the game fast-forwards by simulating turns silently.
  final double gameProgress;
  /// If non-null, this is a tournament match — shows round label.
  final String? tournamentRound;

  const FarkleScreen({
    super.key,
    required this.player,
    required this.opponent,
    required this.betAmount,
    required this.onGameEnd,
    this.observeNpc1,
    this.onLeaveObservation,
    this.gameProgress = 0.0,
    this.tournamentRound,
  });

  @override
  State<FarkleScreen> createState() => _FarkleScreenState();
}

class _FarkleScreenState extends State<FarkleScreen>
    with SingleTickerProviderStateMixin {
  late FarkleGameState _game;
  late AnimationController _ticker;
  final _rng = Random();
  final FocusNode _focusNode = FocusNode();

  bool _rolling = false;
  double _rollTimer = 0;
  bool _showingTurnResult = false;
  double _resultTimer = 0;

  bool _npcThinking = false;
  double _npcTimer = 0;
  int _npcStep = 0;

  ScoreResult? _lastScore;
  _Reaction _playerReaction = _Reaction.neutral;
  _Reaction _npcReaction = _Reaction.neutral;
  double _reactionTimer = 0;
  double _gameTime = 0;
  String _statusText = '';
  List<int> _savedDiceValues = [];

  List<Offset> _diceScatter = [];
  List<double> _diceRotations = [];
  String _npcChatter = '';

  // ── Separate dice ownership ──
  late List<FarkleDie> _playerDice;
  late List<FarkleDie> _npcDice;

  // ── Bust overlay on felt ──
  bool _showBustOverlay = false;
  String _bustText = '';
  bool _bustIsPlayer = true;

  // ── Dice visibility state ──
  bool _diceInPlay = false;
  bool _pendingDiceSwap = false;
  bool _pendingFarkle = false;
  int _bustLostPts = 0;
  bool _lastTurnWasBust = false;

  // ── Observation mode ──
  bool get _isObserving => widget.observeNpc1 != null;
  late NpcData _currentAi; // which NPC's AI is currently executing

  @override
  void initState() {
    super.initState();

    if (_isObserving) {
      // Both sides use wooden dice
      _playerDice = List.generate(6, (_) => FarkleDie(item: DiceItem.wooden));
      _npcDice = List.generate(6, (_) => FarkleDie(item: DiceItem.wooden));
      _game = FarkleGameState(
        player1Id: widget.observeNpc1!.id,
        player2Id: widget.opponent.id,
        betAmount: widget.betAmount,
        dice: _playerDice,
      );
      _currentAi = widget.observeNpc1!;

      // Pre-simulate turns based on how far along the NPC game is
      if (widget.gameProgress > 0.05) {
        _preSimulateTurns();
      }

      final p1Score = _game.player1Score;
      final p2Score = _game.player2Score;
      if (p1Score > 0 || p2Score > 0) {
        _statusText = '${widget.observeNpc1!.name} vs ${widget.opponent.name} — game in progress!';
      } else {
        _statusText = '${widget.observeNpc1!.name} vs ${widget.opponent.name}!';
      }
      _npcChatter = '"${NpcDialogues.forType(widget.observeNpc1!.type).randomGreeting(_rng)}"';
    } else {
      final pEquipped = widget.player.equippedDice;
      _playerDice = List.generate(6, (i) => FarkleDie(
        item: i < pEquipped.length ? pEquipped[i] : DiceItem.wooden,
      ));
      _npcDice = List.generate(6, (_) => FarkleDie(item: DiceItem.wooden));
      _game = FarkleGameState(
        player1Id: 'player',
        player2Id: widget.opponent.id,
        betAmount: widget.betAmount,
        dice: _playerDice,
      );
      _currentAi = widget.opponent;
      _statusText = 'Your turn! Roll the dice! [SPACE]';
      _npcChatter = NpcDialogues.forType(widget.opponent.type).randomGreeting(_rng);
    }

    _generateScatter(6);
    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(days: 1),
    )..addListener(_onTick);
    _ticker.forward();

    // In observation mode, start the current NPC's turn after a brief delay
    if (_isObserving) {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted && _game.phase != FarklePhase.gameOver) {
          final startingNpc = _game.isPlayer1Turn
              ? widget.observeNpc1!
              : widget.opponent;
          _startAiTurn(startingNpc);
        }
      });
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _ticker.dispose();
    super.dispose();
  }

  /// Swap the active dice set into _game.dice when turns change.
  void _swapDiceForCurrentTurn() {
    if (_game.isPlayer1Turn) {
      _game.dice = _playerDice;
    } else {
      _game.dice = _npcDice;
    }
  }

  /// Silently simulate turns to fast-forward an in-progress NPC game.
  void _preSimulateTurns() {
    final progress = widget.gameProgress.clamp(0.0, 0.95);
    final targetCombinedScore = (progress * 3000).toInt();
    final simRng = Random();
    final npc1 = widget.observeNpc1!;
    final npc2 = widget.opponent;

    int safetyLimit = 40;
    while (_game.player1Score + _game.player2Score < targetCombinedScore &&
           safetyLimit > 0 &&
           _game.phase != FarklePhase.gameOver) {
      safetyLimit--;

      final turnDice = _game.isPlayer1Turn ? _playerDice : _npcDice;
      _game.dice = turnDice;

      for (final d in turnDice) {
        d.held = false; d.selected = false; d.locked = false;
      }
      _game.turnScore = 0;
      _game.rollsThisTurn = 0;

      int rollLimit = 6;
      bool ended = false;
      while (rollLimit > 0) {
        rollLimit--;
        FarkleEngine.rollDice(_game, simRng);

        if (!FarkleEngine.hasAnyScoringDice(_game.dice)) {
          FarkleEngine.applyFarkle(_game);
          ended = true;
          break;
        }

        final currentNpc = _game.isPlayer1Turn ? npc1 : npc2;
        final selections = FarkleEngine.npcSelectDice(_game.dice, currentNpc.personality, skill: currentNpc.skill);
        for (final idx in selections) _game.dice[idx].selected = true;
        FarkleEngine.keepSelectedDice(_game);

        final opScore = _game.isPlayer1Turn ? _game.player2Score : _game.player1Score;
        final shouldContinue = FarkleEngine.npcShouldContinue(
          _game.turnScore, _game.currentPlayerScore, opScore,
          _game.availableDiceCount, currentNpc.personality,
          targetScore: _game.targetScore,
        );

        if (!shouldContinue) {
          FarkleEngine.bankScore(_game);
          ended = true;
          break;
        }

        if (_game.hotDice) {
          _game.hotDice = false;
          for (final d in turnDice) {
            d.held = false; d.selected = false; d.locked = false;
          }
        }
      }

      if (!ended && _game.turnScore > 0) {
        FarkleEngine.bankScore(_game);
      }

      if (_game.phase == FarklePhase.gameOver) break;
    }

    // Reset dice for the live portion (only if game didn't end)
    if (_game.phase != FarklePhase.gameOver) {
      final liveDice = _game.isPlayer1Turn ? _playerDice : _npcDice;
      _game.dice = liveDice;
      for (final d in liveDice) {
        d.held = false; d.selected = false; d.locked = false;
      }
      _game.turnScore = 0;
      _game.rollsThisTurn = 0;
      _game.phase = FarklePhase.rolling;
    }
  }

  void _generateScatter(int count) {
    const minSep = 82.0; // must be > die visual size (60px) + rotation margin
    final positions = <Offset>[];
    for (int i = 0; i < count; i++) {
      Offset candidate;
      int attempts = 0;
      do {
        candidate = Offset(
          (_rng.nextDouble() - 0.5) * 200,
          (_rng.nextDouble() - 0.5) * 150,
        );
        attempts++;
        bool overlaps = false;
        for (final placed in positions) {
          if ((candidate - placed).distance < minSep) {
            overlaps = true;
            break;
          }
        }
        if (!overlaps || attempts > 80) {
          if (overlaps && attempts > 80) {
            // Force placement on a ring to guarantee no overlap
            final angle = _rng.nextDouble() * 3.14159 * 2;
            candidate = Offset(
              cos(angle) * minSep * (i + 1) * 0.55,
              sin(angle) * minSep * (i + 1) * 0.55,
            );
          }
          positions.add(candidate);
          break;
        }
      } while (true);
    }
    _diceScatter = positions;
    _diceRotations = List.generate(count, (_) =>
      (_rng.nextDouble() - 0.5) * 0.18,
    );
  }

  void _onTick() {
    final dt = 1 / 60;
    _reactionTimer += dt;
    _gameTime += dt;
    if (_reactionTimer > 3.0) {
      _playerReaction = _Reaction.neutral;
      _npcReaction = _Reaction.neutral;
    }

    if (_rolling) {
      _rollTimer += dt;
      if (_rollTimer >= GameConstants.diceRollDuration) {
        _rolling = false;
        _rollTimer = 0;
        for (int i = 0; i < _game.dice.length && i < _savedDiceValues.length; i++) {
          if (!_game.dice[i].held && !_game.dice[i].locked) {
            _game.dice[i].value = _savedDiceValues[i];
          }
        }
        if (_game.isPlayer1Turn && !_isObserving) _afterRoll();
      } else {
        // Decelerating roll: dice "settle" progressively
        // progress 0.0 -> 1.0 over the roll duration
        final progress = _rollTimer / GameConstants.diceRollDuration;
        // Each die locks at a staggered point (die 0 at 55%, die 5 at 90%)
        for (int i = 0; i < _game.dice.length; i++) {
          final d = _game.dice[i];
          if (d.held || d.locked) continue;
          final lockPoint = 0.55 + (i * 0.07);
          if (progress >= lockPoint) {
            // This die has "settled" to its final value
            if (i < _savedDiceValues.length) d.value = _savedDiceValues[i];
          } else {
            // Still tumbling - decelerate the change rate
            // interval between changes grows as we approach lockPoint
            final dieProgress = progress / lockPoint;
            final changeInterval = 0.03 + dieProgress * 0.14; // 0.03s -> 0.17s
            final timeSinceStart = _rollTimer;
            // Only change on interval boundaries
            final tick = (timeSinceStart / changeInterval).floor();
            final prevTick = ((timeSinceStart - dt) / changeInterval).floor();
            if (tick != prevTick) {
              d.value = _rng.nextInt(6) + 1;
            }
          }
        }
      }
      setState(() {});
      return;
    }

    if (_showingTurnResult) {
      _resultTimer += dt;
      // Bust events get extra time so the user can read the overlay
      final duration = _showBustOverlay ? 2.8 : 1.5;
      if (_resultTimer >= duration) {
        _showingTurnResult = false;
        _showBustOverlay = false;
        _resultTimer = 0;
        // Apply deferred farkle NOW (after player has seen their dice)
        if (_pendingFarkle) {
          FarkleEngine.applyFarkle(_game);
          _pendingFarkle = false;
          _pendingDiceSwap = true;
        }
        // Perform deferred dice swap
        if (_pendingDiceSwap) {
          _swapDiceForCurrentTurn();
          _pendingDiceSwap = false;
        }
        _diceInPlay = false; // next turn starts with dice in corner
        _startNextPhase();
      }
      setState(() {});
      return;
    }

    if (_npcThinking) {
      _npcTimer += dt;
      if (_npcTimer >= GameConstants.npcTurnDelay) {
        _npcTimer = 0;
        _executeNpcStep();
      }
      setState(() {});
    }
  }

  // ── Keyboard cursor for mouseless play ──
  int _cursorIndex = 0; // 0-5, which die is highlighted

  // ── Keyboard ──────────────────────────────────────────────────────

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    // Observation mode: ESC to leave, everything else ignored
    if (_isObserving) {
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        widget.onLeaveObservation?.call();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    if (_rolling || _showingTurnResult || !_game.isPlayer1Turn) return KeyEventResult.ignored;
    if (_game.phase == FarklePhase.gameOver) return KeyEventResult.ignored;

    final key = event.logicalKey;

    // ── Arrow keys: navigate cursor through dice ──
    // Layout is 2 rows x 3 cols conceptually (scattered, but navigable)
    if (key == LogicalKeyboardKey.arrowRight) {
      setState(() => _cursorIndex = (_cursorIndex + 1) % 6);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      setState(() => _cursorIndex = (_cursorIndex - 1 + 6) % 6);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      // Move down a row (index +3, wrapping)
      setState(() => _cursorIndex = (_cursorIndex + 3) % 6);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      // Move up a row (index -3, wrapping)
      setState(() => _cursorIndex = (_cursorIndex - 3 + 6) % 6);
      return KeyEventResult.handled;
    }

    // ── E: toggle selection on cursor die ──
    if (key == LogicalKeyboardKey.keyE && _game.phase == FarklePhase.selecting) {
      if (_cursorIndex >= 0 && _cursorIndex < _game.dice.length) {
        final die = _game.dice[_cursorIndex];
        if (!die.held && !die.locked) {
          setState(() => die.selected = !die.selected);
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.handled;
    }

    // ── R or Enter: Roll dice ──
    if ((key == LogicalKeyboardKey.keyR || key == LogicalKeyboardKey.enter) &&
        _game.phase == FarklePhase.rolling) {
      _rollDice();
      return KeyEventResult.handled;
    }

    // ── Space: Keep & Roll (primary action during selection) ──
    if (key == LogicalKeyboardKey.space) {
      if (_game.phase == FarklePhase.rolling) {
        _rollDice();
        return KeyEventResult.handled;
      }
      if (_game.phase == FarklePhase.selecting && _game.selectedDice.isNotEmpty) {
        _keepAndRoll();
        return KeyEventResult.handled;
      }
      return KeyEventResult.handled;
    }

    // ── W: Score & Pass (bank) ──
    if (key == LogicalKeyboardKey.keyW &&
        _game.phase == FarklePhase.selecting &&
        (_game.turnScore > 0 || _game.selectedDice.isNotEmpty)) {
      _bankScore();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  // ── Player Actions ────────────────────────────────────────────────

  void _rollDice() {
    if (_rolling || _game.phase == FarklePhase.gameOver) return;
    if (!_game.isPlayer1Turn) return;
    _diceInPlay = true;
    _rolling = true;
    _rollTimer = 0;
    _lastScore = null;
    _generateScatter(6);
    FarkleEngine.rollDice(_game, _rng);
    _savedDiceValues = _game.dice.map((d) => d.value).toList();
    if (_rng.nextDouble() < 0.25) {
      _npcChatter = '"${NpcDialogues.forType(widget.opponent.type).randomTaunt(_rng)}"';
    }
    setState(() {});
  }

  void _setReaction({_Reaction? player, _Reaction? npc}) {
    if (player != null) _playerReaction = player;
    if (npc != null) _npcReaction = npc;
    _reactionTimer = 0;
  }

  void _triggerBust({required bool isPlayer, required String text}) {
    _showBustOverlay = true;
    _bustText = text;
    _bustIsPlayer = isPlayer;
    _showingTurnResult = true;
    _resultTimer = 0;
  }

  void _afterRoll() {
    if (!FarkleEngine.hasAnyScoringDice(_game.dice)) {
      _statusText = 'BUST! No scoring dice!';
      _game.farkled = true;
      _setReaction(player: _Reaction.shocked, npc: _Reaction.smug);
      _npcChatter = '"${NpcDialogues.forType(widget.opponent.type).randomTaunt(_rng)}"';
      _bustLostPts = _game.turnScore;
      // DON'T call applyFarkle yet — dice stay frozen where they landed
      _pendingFarkle = true;
      _lastTurnWasBust = true;
      _triggerBust(isPlayer: true, text: '\u{1F480} BUST!${_bustLostPts > 0 ? "\n$_bustLostPts points lost!" : "\nNo scoring dice!"}');
      setState(() {});
      return;
    }
    final availScore = FarkleEngine.scoreAllAvailable(_game.dice);
    if (availScore.score >= 500) {
      _statusText = '\u{1F525} ${availScore.score}+ pts available! Select scoring dice. [E] keep [W] score';
    } else {
      _statusText = 'Select dice with [E], then [SPC] Keep & Roll or [W] Score & Pass';
    }
    _game.phase = FarklePhase.selecting;
    setState(() {});
  }

  void _toggleDieSelection(int index) {
    if (_game.phase != FarklePhase.selecting || !_game.isPlayer1Turn) return;
    final die = _game.dice[index];
    if (die.held || die.locked) return;
    setState(() {
      die.selected = !die.selected;
      _lastScore = FarkleEngine.scoreSelectedDice(_game.dice);
    });
  }

  void _keepAndRoll() {
    if (_game.phase != FarklePhase.selecting || _game.selectedDice.isEmpty) return;
    final result = FarkleEngine.keepSelectedDice(_game);
    if (result.score <= 0) {
      _statusText = '\u26A0 Invalid selection! Pick scoring dice.';
      setState(() {}); return;
    }
    _lastScore = result;
    if (_game.hotDice) {
      _statusText = '\u{1F525}\u{1F525} HOT DICE! +${result.score} (Running: ${_game.turnScore}) \u2014 Roll all 6 again!';
      _setReaction(player: _Reaction.excited, npc: _Reaction.worried);
      _npcChatter = '"${NpcDialogues.forType(widget.opponent.type).randomTaunt(_rng)}"';
    } else {
      final remaining = _game.availableDiceCount;
      _statusText = '\u2713 Kept +${result.score} (Running: ${_game.turnScore}) \u2014 Rolling $remaining dice...';
    }
    _generateScatter(6);
    _game.phase = FarklePhase.rolling;
    _rollDice();
  }

  void _bankScore() {
    if (_game.phase != FarklePhase.selecting) return;
    if (_game.selectedDice.isNotEmpty) FarkleEngine.keepSelectedDice(_game);
    if (_game.turnScore == 0) {
      _statusText = '\u26A0 Select scoring dice first!';
      setState(() {}); return;
    }
    final bankedAmount = _game.turnScore;
    FarkleEngine.bankScore(_game);
    if (_game.phase == FarklePhase.gameOver) { _handleGameOver(); return; }
    _statusText = '\u{1F4B0} Scored $bankedAmount pts! Total: ${_game.player1Score}. ${widget.opponent.name}\'s turn...';
    _setReaction(player: _Reaction.happy, npc: _Reaction.worried);
    _npcChatter = '"${NpcDialogues.forType(widget.opponent.type).randomTaunt(_rng)}"';
    // Defer dice swap until result overlay clears
    _pendingDiceSwap = true;
    _diceInPlay = false;
    _lastTurnWasBust = false;
    _showingTurnResult = true;
    _resultTimer = 0;
    setState(() {});
  }

  // ── NPC Turn ──────────────────────────────────────────────────────

  // NPC dice selection queue (for one-by-one animation)
  List<int> _npcSelectionQueue = [];
  int _npcSelectionIndex = 0;
  double _npcSelectionTimer = 0;
  static const double _npcPickDelay = 0.35; // seconds between each die pick

  void _startAiTurn(NpcData npc) {
    _currentAi = npc;
    _npcThinking = true;
    _npcStep = 0;
    _npcTimer = 0;
    _statusText = '${npc.name} picks up dice...';
    if (_rng.nextDouble() < 0.4) {
      _npcChatter = '"${NpcDialogues.forType(npc.type).randomTaunt(_rng)}"';
    }
    setState(() {});
  }

  void _executeNpcStep() {
    final aiName = _currentAi.name;
    final dialogue = NpcDialogues.forType(_currentAi.type);
    final isAiOnP1Side = _game.isPlayer1Turn;

    switch (_npcStep) {
      case 0:
        _diceInPlay = true;
        _generateScatter(6);
        _rolling = true;
        _rollTimer = 0;
        FarkleEngine.rollDice(_game, _rng);
        _savedDiceValues = _game.dice.map((d) => d.value).toList();
        _npcStep = 1;
        break;

      case 1:
        // After roll settles, check for bust
        if (_rolling) return;
        if (!FarkleEngine.hasAnyScoringDice(_game.dice)) {
          _statusText = '$aiName BUSTED!';
          _npcChatter = '"${dialogue.randomLose(_rng)}"';
          if (isAiOnP1Side) {
            _setReaction(player: _Reaction.shocked, npc: _Reaction.happy);
          } else {
            _setReaction(player: _Reaction.happy, npc: _Reaction.shocked);
          }
          _npcThinking = false;
          _pendingFarkle = true;
          _lastTurnWasBust = true;
          _triggerBust(isPlayer: isAiOnP1Side, text: '\u{1F480} $aiName\nBUSTED!');
          return;
        }
        // Determine which dice to keep, but don't select yet — queue them
        _npcSelectionQueue = FarkleEngine.npcSelectDice(_game.dice, _currentAi.personality, skill: _currentAi.skill);
        // Sort by value for logical ordering: 1s first, then triples, then 5s
        _npcSelectionQueue.sort((a, b) {
          final va = _game.dice[a].value;
          final vb = _game.dice[b].value;
          // 1s first, then by value ascending
          if (va == 1 && vb != 1) return -1;
          if (vb == 1 && va != 1) return 1;
          return va.compareTo(vb);
        });
        _npcSelectionIndex = 0;
        _npcSelectionTimer = 0;
        _statusText = '$aiName considers their dice...';
        _npcStep = 15; // go to one-by-one selection step
        break;

      case 15:
        // Select dice one at a time — fast within groups, pause between groups
        _npcSelectionTimer += GameConstants.npcTurnDelay;

        // Determine delay: fast (0.08s) within a value group, slow (0.4s) between groups
        double delay = 0.4; // default pause between groups
        if (_npcSelectionIndex > 0 && _npcSelectionIndex < _npcSelectionQueue.length) {
          final prevIdx = _npcSelectionQueue[_npcSelectionIndex - 1];
          final curIdx = _npcSelectionQueue[_npcSelectionIndex];
          if (_game.dice[prevIdx].value == _game.dice[curIdx].value) {
            delay = 0.08; // same value = same group, select fast
          }
        }

        if (_npcSelectionTimer >= delay && _npcSelectionIndex < _npcSelectionQueue.length) {
          final idx = _npcSelectionQueue[_npcSelectionIndex];
          _game.dice[idx].selected = true;
          _npcSelectionIndex++;
          _npcSelectionTimer = 0;

          if (_npcSelectionIndex >= _npcSelectionQueue.length) {
            // All dice selected — show total and move on
            _lastScore = FarkleEngine.scoreSelectedDice(_game.dice);
            _statusText = '$aiName keeps ${_lastScore?.description ?? "dice"}';
            _npcStep = 2;
          } else {
            _statusText = '$aiName picks a ${_game.dice[idx].value}...';
          }
          setState(() {});
        }
        return; // don't advance to next step yet

      case 2:
        final result = FarkleEngine.keepSelectedDice(_game);
        if (_game.hotDice) {
          final wouldWin = (_game.currentPlayerScore + _game.turnScore) >= _game.targetScore;
          if (wouldWin) {
            final banked = _game.turnScore;
            FarkleEngine.bankScore(_game);
            _npcThinking = false;
            if (_game.phase == FarklePhase.gameOver) {
              _handleGameOver(); return;
            }
            _statusText = '\u{1F4B0} $aiName scores $banked for the win!';
            _npcChatter = '"${dialogue.randomWin(_rng)}"';
            if (isAiOnP1Side) {
              _setReaction(player: _Reaction.excited, npc: _Reaction.worried);
            } else {
              _setReaction(player: _Reaction.worried, npc: _Reaction.excited);
            }
            _pendingDiceSwap = true;
            _diceInPlay = false;
            _lastTurnWasBust = false;
            _showingTurnResult = true;
            _resultTimer = 0;
            break;
          }
          _statusText = '\u{1F525} $aiName got HOT DICE! +${result.score} (Running: ${_game.turnScore})';
          _npcChatter = '"${dialogue.randomTaunt(_rng)}"';
          if (isAiOnP1Side) {
            _setReaction(player: _Reaction.excited, npc: _Reaction.worried);
          } else {
            _setReaction(player: _Reaction.worried, npc: _Reaction.excited);
          }
          _generateScatter(6);
          _diceInPlay = false;
          _npcStep = 0;
          break;
        }
        final wouldWin = (_game.currentPlayerScore + _game.turnScore) >= _game.targetScore;
        final shouldContinue = !wouldWin && FarkleEngine.npcShouldContinue(
          _game.turnScore, _game.currentPlayerScore, _game.player1Score,
          _game.availableDiceCount, _currentAi.personality,
          targetScore: _game.targetScore,
        );
        if (shouldContinue && _game.availableDiceCount > 0) {
          _statusText = '$aiName rolls again... (Running: ${_game.turnScore})';
          _diceInPlay = false;
          _npcStep = 0;
        } else {
          final banked = _game.turnScore;
          FarkleEngine.bankScore(_game);
          if (_game.phase == FarklePhase.gameOver) {
            _npcThinking = false;
            _handleGameOver(); return;
          }
          final totalStr = isAiOnP1Side
              ? 'Total: ${_game.player1Score}'
              : 'Total: ${_game.player2Score}';
          _statusText = '\u{1F4B0} $aiName scores $banked! $totalStr';
          _npcChatter = '"${dialogue.randomWin(_rng)}"';
          if (isAiOnP1Side) {
            _setReaction(player: _Reaction.smug, npc: _Reaction.worried);
          } else {
            _setReaction(player: _Reaction.worried, npc: _Reaction.smug);
          }
          _npcThinking = false;
          _pendingDiceSwap = true;
          _diceInPlay = false;
          _lastTurnWasBust = false;
          _showingTurnResult = true;
          _resultTimer = 0;
        }
        break;
    }
    setState(() {});
  }

  // ── Game Flow ─────────────────────────────────────────────────────

  void _startNextPhase() {
    if (_game.phase == FarklePhase.gameOver) { _handleGameOver(); return; }
    if (_game.isPlayer1Turn) {
      if (_isObserving) {
        _startAiTurn(widget.observeNpc1!);
      } else {
        _statusText = 'Your turn! Roll the dice! [SPACE]';
        _game.phase = FarklePhase.rolling;
      }
    } else {
      _startAiTurn(widget.opponent);
    }
    setState(() {});
  }

  void _handleGameOver() {
    if (_isObserving) {
      final npc1Won = _game.winnerId == widget.observeNpc1!.id;
      final winnerName = npc1Won ? widget.observeNpc1!.name : widget.opponent.name;
      _statusText = '$winnerName wins!';
      _setReaction(
        player: npc1Won ? _Reaction.excited : _Reaction.defeated,
        npc: npc1Won ? _Reaction.defeated : _Reaction.excited,
      );
      _npcChatter = npc1Won
          ? '"${NpcDialogues.forType(widget.observeNpc1!.type).randomWin(_rng)}"'
          : '"${NpcDialogues.forType(widget.opponent.type).randomWin(_rng)}"';
      _game.phase = FarklePhase.gameOver;
      setState(() {});
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) widget.onGameEnd(npc1Won, null);
      });
      return;
    }

    final playerWon = _game.winnerId == 'player';
    DiceItem? loot;
    if (playerWon) {
      loot = LootSystem.rollLootForNpc(_rng, widget.opponent.type);
      _setReaction(player: _Reaction.excited, npc: _Reaction.defeated);
      _npcChatter = '"${NpcDialogues.forType(widget.opponent.type).randomLose(_rng)}"';
    } else {
      _setReaction(player: _Reaction.defeated, npc: _Reaction.excited);
      _npcChatter = '"${NpcDialogues.forType(widget.opponent.type).randomWin(_rng)}"';
    }
    _game.phase = FarklePhase.gameOver;
    setState(() {});
    Future.delayed(const Duration(seconds: 3), () {
      widget.onGameEnd(playerWon, loot);
    });
  }

  // ── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final npc1Name = _isObserving ? widget.observeNpc1!.name : 'YOU';
    final npc1Color = _isObserving ? widget.observeNpc1!.primaryColor : const Color(0xFF4488EE);
    final npc2Name = widget.opponent.name;
    final npc2Color = widget.opponent.primaryColor;

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.3), radius: 1.2,
            colors: [Color(0xFF2a1a10), Color(0xFF140a04), Color(0xFF0a0502)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _NpcBarWithChatter(
                    label: npc2Name.toUpperCase(),
                    score: _game.player2Score,
                    color: npc2Color,
                    isActive: !_game.isPlayer1Turn,
                    reaction: _npcReaction,
                    time: _gameTime,
                    targetScore: _game.targetScore,
                    betAmount: widget.betAmount,
                    chatter: _npcChatter,
                    tournamentRound: widget.tournamentRound,
                  ),
                  _TurnScoreDisplay(
                    turnScore: _game.turnScore,
                    isPlayerTurn: _game.isPlayer1Turn && !_isObserving,
                    npcName: _isObserving
                        ? (_game.isPlayer1Turn ? widget.observeNpc1!.name : npc2Name)
                        : npc2Name,
                    targetScore: _game.targetScore,
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: _FeltTable(
                      activeDice: _game.dice,
                      inactiveDice: _game.isPlayer1Turn ? _npcDice : _playerDice,
                      rolling: _rolling,
                      farkled: _game.farkled,
                      isNpcTurn: !_game.isPlayer1Turn,
                      scatter: _diceScatter,
                      rotations: _diceRotations,
                      onTapDie: !_isObserving && _game.isPlayer1Turn && _game.phase == FarklePhase.selecting
                          ? _toggleDieSelection : null,
                      lastScore: _lastScore,
                      showBustOverlay: _showBustOverlay,
                      bustText: _bustText,
                      bustIsPlayer: _bustIsPlayer,
                      diceInPlay: _diceInPlay,
                      inactiveBusted: _lastTurnWasBust,
                      gameTime: _gameTime,
                      cursorIndex: _game.isPlayer1Turn ? _cursorIndex : -1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _StatusBanner(text: _statusText, isFarkle: _showBustOverlay),
                  const SizedBox(height: 6),
                  if (!_isObserving && _game.phase != FarklePhase.gameOver &&
                      _game.isPlayer1Turn && !_rolling && !_showingTurnResult)
                    _ActionButtons(
                      phase: _game.phase,
                      hasSelection: _game.selectedDice.isNotEmpty,
                      turnScore: _game.turnScore,
                      selectionScore: _lastScore?.score ?? 0,
                      onRoll: _rollDice, onKeepAndRoll: _keepAndRoll, onBank: _bankScore,
                    ),
                  if (_game.phase == FarklePhase.gameOver)
                    _isObserving
                      ? _ObserveGameOverBanner(
                          npc1Won: _game.winnerId == widget.observeNpc1?.id,
                          npc1Name: widget.observeNpc1?.name ?? '',
                          npc2Name: npc2Name,
                          betAmount: widget.betAmount,
                        )
                      : _GameOverBanner(
                          playerWon: _game.winnerId == 'player',
                          npcName: npc2Name, betAmount: widget.betAmount,
                        ),
                  const SizedBox(height: 6),
                  _HorizPlayerBar(
                    label: npc1Name.toUpperCase(), score: _game.player1Score,
                    color: npc1Color, isActive: _game.isPlayer1Turn,
                    reaction: _playerReaction, time: _gameTime,
                    isPlayer: !_isObserving,
                    targetScore: _game.targetScore, betAmount: null,
                  ),
                ],
              ),
              // Observation overlay: "Watching" banner + Leave button
              if (_isObserving) ...[
                Positioned(
                  top: 0, left: 0, right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    color: const Color(0xCC000000),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.visibility, color: const Color(0xFFd4b040), size: 14),
                        const SizedBox(width: 6),
                        const Text('OBSERVING', style: TextStyle(color: Color(0xFFd4b040), fontSize: 11,
                          fontFamily: 'monospace', fontWeight: FontWeight.w700, letterSpacing: 1.5)),
                      ]),
                  ),
                ),
                Positioned(
                  top: 6, right: 8,
                  child: GestureDetector(
                    onTap: widget.onLeaveObservation,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xCC3a1a0a),
                        border: Border.all(color: const Color(0xFF8a6a3a)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                          Text('LEAVE', style: TextStyle(color: Color(0xFFb89868), fontSize: 10,
                            fontFamily: 'monospace', fontWeight: FontWeight.w700)),
                          SizedBox(width: 6),
                          Text('ESC', style: TextStyle(color: Color(0xFF6a5a40), fontSize: 9,
                            fontFamily: 'monospace', fontWeight: FontWeight.w600)),
                        ]),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// SUB-WIDGETS
// ═══════════════════════════════════════════════════════════════════════

class _NpcBarWithChatter extends StatelessWidget {
  final String label;
  final int score, targetScore, betAmount;
  final Color color;
  final bool isActive;
  final _Reaction reaction;
  final double time;
  final String chatter;
  final String? tournamentRound;
  const _NpcBarWithChatter({
    required this.label, required this.score, required this.color,
    required this.isActive, required this.reaction, required this.time,
    required this.targetScore, required this.betAmount, required this.chatter,
    this.tournamentRound,
  });
  @override
  Widget build(BuildContext context) {
    final progress = (score / targetScore).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Color(0xFF1c1008), Color(0xFF140c06)])),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Container(width: 52, height: 52,
            decoration: BoxDecoration(
              border: Border.all(color: isActive ? color : const Color(0xFF3a2a1a), width: 2.5),
              borderRadius: BorderRadius.circular(8),
              boxShadow: isActive ? [BoxShadow(color: color.withOpacity(0.35), blurRadius: 12)] : null),
            child: ClipRRect(borderRadius: BorderRadius.circular(5.5),
              child: CustomPaint(painter: _LargePortraitPainter(color: color, reaction: reaction, time: time, isPlayer: false)))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              if (isActive) Container(width: 6, height: 6, margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(shape: BoxShape.circle, color: color,
                  boxShadow: [BoxShadow(color: color.withOpacity(0.6), blurRadius: 6)])),
              Text(label, style: TextStyle(
                color: isActive ? const Color(0xFFf0e8d0) : const Color(0xFF8a7a60),
                fontSize: 14, fontFamily: 'monospace', fontWeight: FontWeight.w700, letterSpacing: 0.5)),
            ]),
            const SizedBox(height: 6),
            ClipRRect(borderRadius: BorderRadius.circular(3),
              child: SizedBox(height: 5, child: Stack(children: [
                Container(color: const Color(0xFF0a0804)),
                FractionallySizedBox(alignment: Alignment.centerLeft, widthFactor: progress,
                  child: Container(decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [color.withOpacity(0.5), color])))),
              ]))),
          ])),
          const SizedBox(width: 16),
          Text('$score', style: TextStyle(color: Colors.white, fontSize: 32, fontFamily: 'monospace',
            fontWeight: FontWeight.w900, shadows: [Shadow(color: color.withOpacity(0.4), blurRadius: 8)])),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(color: const Color(0xFF0a0804),
              border: Border.all(color: tournamentRound != null
                  ? GameColors.uiHighlight.withOpacity(0.5) : const Color(0xFF4a3a28), width: 1),
              borderRadius: BorderRadius.circular(6)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(tournamentRound != null ? 'TOURNEY' : 'BET',
                style: TextStyle(color: tournamentRound != null
                    ? GameColors.uiHighlight.withOpacity(0.7) : const Color(0xFF6a5a40),
                  fontSize: 8, fontFamily: 'monospace', fontWeight: FontWeight.bold, letterSpacing: 1)),
              Text(tournamentRound ?? '${betAmount}g',
                style: TextStyle(color: tournamentRound != null
                    ? GameColors.uiHighlight : const Color(0xFFd4b878),
                  fontSize: tournamentRound != null ? 9 : 13,
                  fontFamily: 'monospace', fontWeight: FontWeight.w700)),
            ])),
        ]),
        if (chatter.isNotEmpty)
          Padding(padding: const EdgeInsets.only(left: 64, top: 4, bottom: 2),
            child: Text(chatter, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color.withOpacity(0.55), fontSize: 11, fontStyle: FontStyle.italic, height: 1.2))),
      ]));
  }
}

class _HorizPlayerBar extends StatelessWidget {
  final String label;
  final int score, targetScore;
  final int? betAmount;
  final Color color;
  final bool isActive, isPlayer;
  final _Reaction reaction;
  final double time;
  const _HorizPlayerBar({
    required this.label, required this.score, required this.color,
    required this.isActive, required this.reaction, required this.time,
    required this.isPlayer, required this.targetScore, required this.betAmount,
  });
  @override
  Widget build(BuildContext context) {
    final progress = (score / targetScore).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Color(0xFF140c06), Color(0xFF1c1008)])),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Container(width: 52, height: 52,
          decoration: BoxDecoration(
            border: Border.all(color: isActive ? color : const Color(0xFF3a2a1a), width: 2.5),
            borderRadius: BorderRadius.circular(8),
            boxShadow: isActive ? [BoxShadow(color: color.withOpacity(0.35), blurRadius: 12)] : null),
          child: ClipRRect(borderRadius: BorderRadius.circular(5.5),
            child: CustomPaint(painter: _LargePortraitPainter(color: color, reaction: reaction, time: time, isPlayer: isPlayer)))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            if (isActive) Container(width: 6, height: 6, margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(shape: BoxShape.circle, color: color,
                boxShadow: [BoxShadow(color: color.withOpacity(0.6), blurRadius: 6)])),
            Text(label, style: TextStyle(
              color: isActive ? const Color(0xFFf0e8d0) : const Color(0xFF8a7a60),
              fontSize: 14, fontFamily: 'monospace', fontWeight: FontWeight.w700, letterSpacing: 0.5)),
          ]),
          const SizedBox(height: 6),
          ClipRRect(borderRadius: BorderRadius.circular(3),
            child: SizedBox(height: 5, child: Stack(children: [
              Container(color: const Color(0xFF0a0804)),
              FractionallySizedBox(alignment: Alignment.centerLeft, widthFactor: progress,
                child: Container(decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [color.withOpacity(0.5), color])))),
            ]))),
        ])),
        const SizedBox(width: 16),
        Text('$score', style: TextStyle(color: Colors.white, fontSize: 32, fontFamily: 'monospace',
          fontWeight: FontWeight.w900, shadows: [Shadow(color: color.withOpacity(0.4), blurRadius: 8)])),
      ]));
  }
}

class _TurnScoreDisplay extends StatelessWidget {
  final int turnScore;
  final bool isPlayerTurn;
  final String npcName;
  final int targetScore;
  const _TurnScoreDisplay({required this.turnScore, required this.isPlayerTurn,
    required this.npcName, this.targetScore = 4000});
  @override
  Widget build(BuildContext context) {
    final label = isPlayerTurn ? 'YOUR TURN' : "${npcName}'s TURN";
    final labelColor = isPlayerTurn ? const Color(0xFF6eaaff) : const Color(0xFFff9944);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(gradient: LinearGradient(colors: [
        Colors.transparent, const Color(0xFF0a0804).withOpacity(0.9), Colors.transparent])),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: TextStyle(color: labelColor, fontSize: 12, fontFamily: 'monospace',
          fontWeight: FontWeight.w700, letterSpacing: 1)),
        const SizedBox(width: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(color: const Color(0xFF0a0804),
            border: Border.all(color: const Color(0xFFc8a850), width: 1.5), borderRadius: BorderRadius.circular(4)),
          child: Text('TURN: $turnScore', style: const TextStyle(
            color: Color(0xFFf0d870), fontSize: 16, fontFamily: 'monospace', fontWeight: FontWeight.w900))),
        const SizedBox(width: 10),
        Text('GOAL: $targetScore', style: const TextStyle(
          color: Color(0xFF8a7a60), fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.w600)),
      ]));
  }
}

class _FeltTable extends StatelessWidget {
  final List<FarkleDie> activeDice;
  final List<FarkleDie> inactiveDice;
  final bool rolling, farkled, isNpcTurn;
  final List<Offset> scatter;
  final List<double> rotations;
  final void Function(int)? onTapDie;
  final ScoreResult? lastScore;
  final bool showBustOverlay;
  final String bustText;
  final bool bustIsPlayer;
  final bool diceInPlay;
  final bool inactiveBusted;
  final double gameTime;
  final int cursorIndex;

  const _FeltTable({
    required this.activeDice, required this.inactiveDice,
    required this.rolling, required this.farkled, required this.isNpcTurn,
    required this.scatter, required this.rotations,
    this.onTapDie, this.lastScore,
    this.showBustOverlay = false, this.bustText = '', this.bustIsPlayer = true,
    this.diceInPlay = true, this.inactiveBusted = false,
    this.gameTime = 0,
    this.cursorIndex = -1,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        gradient: const RadialGradient(center: Alignment(0, 0), radius: 0.9,
          colors: [Color(0xFF1a4a2a), Color(0xFF0f3018), Color(0xFF0a2010)]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF6a4a28), width: 4),
        boxShadow: const [
          BoxShadow(color: Color(0x44000000), blurRadius: 20, spreadRadius: -5),
          BoxShadow(color: Color(0xFF3a2a18), blurRadius: 1, spreadRadius: 1),
        ],
      ),
      child: LayoutBuilder(builder: (context, constraints) {
        final areaW = constraints.maxWidth;
        final areaH = constraints.maxHeight;

        final heldIndices = <int>[];
        final rollableIndices = <int>[];
        for (int i = 0; i < activeDice.length; i++) {
          if (activeDice[i].held || activeDice[i].locked) {
            heldIndices.add(i);
          } else {
            rollableIndices.add(i);
          }
        }

        final diceZoneW = areaW - 155; // wider scoring panel
        final baseCx = isNpcTurn ? diceZoneW * 0.35 : diceZoneW * 0.45;
        final baseCy = isNpcTurn ? areaH * 0.32 : areaH * 0.55;

        return Stack(children: [
          // Wood trims
          Positioned(top: 8, left: 16, right: 16, child: Container(height: 3,
            decoration: BoxDecoration(gradient: LinearGradient(colors: [
              Colors.transparent, const Color(0xFF8a6a38).withOpacity(0.3), Colors.transparent])))),
          Positioned(bottom: 8, left: 16, right: 16, child: Container(height: 3,
            decoration: BoxDecoration(gradient: LinearGradient(colors: [
              Colors.transparent, const Color(0xFF8a6a38).withOpacity(0.3), Colors.transparent])))),

          // ── Inactive player's dice bundled in their corner (hide during bust and before first roll) ──
          if (!showBustOverlay && (activeDice.isNotEmpty && inactiveDice.isNotEmpty) &&
              inactiveDice.any((d) => d.value > 0 && (d.held || d.locked)))
            ..._buildInactiveDiceBundle(areaW, areaH),

          // ── Embedded scoring reference (wider, with mini dice) ──
          Positioned(right: 8, top: 8, bottom: 8, child: Container(
            width: 145,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF0d2e16).withOpacity(0.75),
              border: Border(left: BorderSide(color: const Color(0xFF8a6a38).withOpacity(0.4), width: 1.5)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('SCORING', style: TextStyle(
                color: const Color(0xFFb89a50).withOpacity(0.85), fontSize: 12,
                fontFamily: 'monospace', fontWeight: FontWeight.bold, letterSpacing: 1.5)),
              Padding(padding: const EdgeInsets.symmetric(vertical: 4),
                child: Container(height: 1, color: const Color(0xFF8a6a38).withOpacity(0.3))),
              Expanded(child: ListView(padding: EdgeInsets.zero, children: [
                _DiceScoreRow(diceValues: const [1], label: '\u00D71', pts: '100'),
                _DiceScoreRow(diceValues: const [5], label: '\u00D71', pts: '50'),
                const SizedBox(height: 4),
                _DiceScoreRow(diceValues: const [1, 1, 1], label: '', pts: '1000'),
                _DiceScoreRow(diceValues: const [2, 2, 2], label: '', pts: '200'),
                _DiceScoreRow(diceValues: const [3, 3, 3], label: '', pts: '300'),
                _DiceScoreRow(diceValues: const [4, 4, 4], label: '', pts: '400'),
                _DiceScoreRow(diceValues: const [5, 5, 5], label: '', pts: '500'),
                _DiceScoreRow(diceValues: const [6, 6, 6], label: '', pts: '600'),
                const SizedBox(height: 4),
                _DiceScoreRow(diceValues: const [0, 0, 0, 0], label: '4\u00D7', pts: '\u00D72'),
                _DiceScoreRow(diceValues: const [0, 0, 0, 0, 0], label: '5\u00D7', pts: '\u00D74'),
                _DiceScoreRow(diceValues: const [0, 0, 0, 0, 0, 0], label: '6\u00D7', pts: '\u00D78'),
                const SizedBox(height: 4),
                _DiceScoreRow(diceValues: const [1, 2, 3, 4, 5, 6], label: '', pts: '1500'),
                _TextScoreRow('3 Pairs', '1500'),
                _TextScoreRow('Hot Dice', 'Roll 6!'),
              ])),
              Padding(padding: const EdgeInsets.only(top: 4), child: Text(
                '[SPC] Roll/Keep  [E] Select  [W] Score', style: TextStyle(
                  color: const Color(0xFF6a8a5a).withOpacity(0.5), fontSize: 8,
                  fontFamily: 'monospace', height: 1.4))),
            ]),
          )),

          // ── Active dice ──
          // During bust: dice stay exactly where they are (overlay goes on top)
          // Not yet rolled: show ready pile in corner
          // In play: scattered on the table
          if (!diceInPlay && !showBustOverlay)
            ..._buildReadyDiceBundle(areaW, areaH),

          if (diceInPlay) ...[
            for (int si = 0; si < rollableIndices.length; si++)
              _buildScatteredDie(rollableIndices[si], si, baseCx, baseCy, diceZoneW, areaH),
            for (int di = 0; di < heldIndices.length; di++)
              _buildHeldDie(heldIndices[di], di, diceZoneW, areaH),
          ],

          // (Score preview removed — scoring is a player skill)

          // ── BUST OVERLAY (on-felt) ──
          if (showBustOverlay)
            Positioned.fill(child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.black.withOpacity(0.45),
              ),
              child: Center(child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFF2a0808).withOpacity(0.9),
                  border: Border.all(color: GameColors.uiDanger, width: 3),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: GameColors.uiDanger.withOpacity(0.6), blurRadius: 30)],
                ),
                child: Text(bustText, textAlign: TextAlign.center, style: const TextStyle(
                  color: GameColors.uiDanger, fontSize: 22,
                  fontFamily: 'monospace', fontWeight: FontWeight.bold, height: 1.3)),
              )),
            )),
        ]);
      }),
    );
  }

  /// Build the inactive player's dice: neat row if they banked, messy cluster if they busted.
  List<Widget> _buildInactiveDiceBundle(double areaW, double areaH) {
    final isPlayerInactive = isNpcTurn;
    final count = min(inactiveDice.length, 6);

    if (!inactiveBusted) {
      // ── Neat single row: banked successfully, show last scored state ──
      final anchorX = isPlayerInactive ? 14.0 : 14.0;
      final anchorY = isPlayerInactive ? areaH - 50.0 : 14.0;

      return List.generate(count, (i) {
        final dx = anchorX + i * 36.0;
        return Positioned(
          left: dx.clamp(4.0, areaW - 180.0),
          top: anchorY.clamp(4.0, areaH - 40.0),
          child: Opacity(opacity: 0.35,
            child: SizedBox(width: 32, height: 32,
              child: CustomPaint(
                painter: MaterialDiePainter(
                  value: inactiveDice[i].value,
                  material: inactiveDice[i].item.material,
                  isScored: true,
                ),
              ),
            ),
          ),
        );
      });
    } else {
      // ── Messy cluster: busted, dice left where they fell ──
      final anchorX = isPlayerInactive ? 30.0 : 20.0;
      final anchorY = isPlayerInactive ? areaH - 80.0 : 16.0;

      const offsets = [
        Offset(0, 0), Offset(28, -6), Offset(54, 3),
        Offset(10, 26), Offset(38, 22), Offset(62, 28),
      ];
      const rots = [0.08, -0.12, 0.05, -0.1, 0.15, -0.06];

      return List.generate(count, (i) {
        final dx = anchorX + offsets[i].dx;
        final dy = anchorY + offsets[i].dy;
        return Positioned(
          left: dx.clamp(4.0, areaW - 170.0),
          top: dy.clamp(4.0, areaH - 50.0),
          child: Transform.rotate(
            angle: rots[i],
            child: Opacity(opacity: 0.30,
              child: SizedBox(width: 32, height: 32,
                child: CustomPaint(
                  painter: MaterialDiePainter(
                    value: inactiveDice[i].value,
                    material: inactiveDice[i].item.material,
                    isScored: true,
                  ),
                ),
              ),
            ),
          ),
        );
      });
    }
  }

  Widget _buildScatteredDie(int dieIdx, int scatterIdx,
      double baseCx, double baseCy, double clampW, double clampH) {
    final si = scatterIdx.clamp(0, scatter.length - 1);
    final dx = (baseCx + scatter[si].dx - 30).clamp(12.0, clampW - 72.0);
    final dy = (baseCy + scatter[si].dy - 30).clamp(24.0, clampH - 72.0);
    final rot = si < rotations.length ? rotations[si] : 0.0;
    return Positioned(left: dx, top: dy, child: Transform.rotate(angle: rot,
      child: MaterialDie(
        die: activeDice[dieIdx],
        rolling: rolling && !activeDice[dieIdx].held && !activeDice[dieIdx].locked,
        onTap: onTapDie != null && !activeDice[dieIdx].held && !activeDice[dieIdx].locked
            ? () => onTapDie!(dieIdx) : null,
        gameTime: gameTime,
        isCursorTarget: cursorIndex == dieIdx,
      ),
    ));
  }

  Widget _buildHeldDie(int dieIdx, int stackIdx, double clampW, double clampH) {
    // Scatter held dice in keeper's corner — no overlaps
    const heldOffsets = [
      Offset(0, 0), Offset(64, -12), Offset(30, 60),
      Offset(96, 22), Offset(4, -60), Offset(72, 54),
    ];
    const heldRots = [0.06, -0.09, 0.12, -0.05, 0.08, -0.11];
    final oi = stackIdx.clamp(0, 5);

    final baseX = isNpcTurn ? 12.0 : clampW - 130.0;
    final baseY = isNpcTurn ? 12.0 : clampH - 100.0;
    final dx = (baseX + heldOffsets[oi].dx).clamp(4.0, clampW - 64.0);
    final dy = (baseY + heldOffsets[oi].dy).clamp(4.0, clampH - 64.0);

    return Positioned(left: dx, top: dy,
      child: Transform.rotate(angle: heldRots[oi],
        child: Opacity(opacity: 0.45, child: MaterialDie(die: activeDice[dieIdx], rolling: false, onTap: null, isInactive: true, gameTime: gameTime)),
      ),
    );
  }


  /// Active player's dice sitting in a ready pile before being rolled.
  List<Widget> _buildReadyDiceBundle(double areaW, double areaH) {
    // Player's ready pile: bottom-left; NPC's: top-left
    final anchorX = isNpcTurn ? 20.0 : 24.0;
    final anchorY = isNpcTurn ? 16.0 : areaH - 85.0;

    const offsets = [
      Offset(0, 0), Offset(30, -5), Offset(58, 4),
      Offset(12, 28), Offset(42, 24), Offset(68, 30),
    ];
    const rots = [0.05, -0.08, 0.1, -0.06, 0.12, -0.04];

    return List.generate(min(activeDice.length, 6), (i) {
      final dx = anchorX + offsets[i].dx;
      final dy = anchorY + offsets[i].dy;
      return Positioned(
        left: dx.clamp(4.0, areaW - 180.0),
        top: dy.clamp(4.0, areaH - 50.0),
        child: Transform.rotate(angle: rots[i],
          child: Opacity(opacity: 0.7,
            child: MaterialDie(die: activeDice[i], rolling: false, onTap: null, gameTime: gameTime)),
        ),
      );
    });
  }
}

/// Score row with mini dice sprites showing the combination.
class _DiceScoreRow extends StatelessWidget {
  final List<int> diceValues; // 0 = wildcard/any die
  final String label;
  final String pts;
  const _DiceScoreRow({required this.diceValues, required this.label, required this.pts});

  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(children: [
        // Mini dice sprites
        ...diceValues.map((v) => Padding(
          padding: const EdgeInsets.only(right: 2),
          child: SizedBox(width: 14, height: 14,
            child: CustomPaint(painter: _MiniDiePainter(value: v))),
        )),
        if (label.isNotEmpty) Padding(
          padding: const EdgeInsets.only(left: 2),
          child: Text(label, style: TextStyle(
            color: const Color(0xFFa0c890).withOpacity(0.6), fontSize: 8, fontFamily: 'monospace')),
        ),
        const Spacer(),
        Text(pts, style: const TextStyle(
          color: Color(0xFFd4b860), fontSize: 10,
          fontFamily: 'monospace', fontWeight: FontWeight.bold)),
      ]),
    );
  }
}

/// Fallback text-only score row for combos that don't translate to dice visuals.
class _TextScoreRow extends StatelessWidget {
  final String label, value;
  const _TextScoreRow(this.label, this.value);
  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Flexible(child: Text(label, style: TextStyle(
          color: const Color(0xFFa0c890).withOpacity(0.7), fontSize: 10, fontFamily: 'monospace'))),
        Text(value, style: const TextStyle(
          color: Color(0xFFd4b860), fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
      ]),
    );
  }
}

/// Tiny 14x14 die painter for the scoring reference panel.
class _MiniDiePainter extends CustomPainter {
  final int value; // 0 = wildcard (question mark)
  _MiniDiePainter({required this.value});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    // Birch wood background
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(2)),
      Paint()..color = const Color(0xFFD8C8A0));
    // Border
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(2)),
      Paint()..color = const Color(0xFF8A7A58)..style = PaintingStyle.stroke..strokeWidth = 0.8);

    if (value == 0) {
      // Wildcard: small "?" mark
      final tp = TextPainter(
        text: TextSpan(text: '?', style: TextStyle(
          color: const Color(0xFF5A4030), fontSize: size.width * 0.6, fontWeight: FontWeight.bold)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset((size.width - tp.width) / 2, (size.height - tp.height) / 2));
      return;
    }

    // Burned pips
    final cx = size.width / 2, cy = size.height / 2;
    final r = size.width * 0.09;
    final off = size.width * 0.25;
    final p = Paint()..color = const Color(0xFF4A2810);

    final positions = <Offset>[];
    switch (value) {
      case 1: positions.add(Offset(cx, cy)); break;
      case 2: positions.addAll([Offset(cx - off, cy - off), Offset(cx + off, cy + off)]); break;
      case 3: positions.addAll([Offset(cx - off, cy - off), Offset(cx, cy), Offset(cx + off, cy + off)]); break;
      case 4: positions.addAll([Offset(cx - off, cy - off), Offset(cx + off, cy - off), Offset(cx - off, cy + off), Offset(cx + off, cy + off)]); break;
      case 5: positions.addAll([Offset(cx - off, cy - off), Offset(cx + off, cy - off), Offset(cx, cy), Offset(cx - off, cy + off), Offset(cx + off, cy + off)]); break;
      case 6: positions.addAll([Offset(cx - off, cy - off), Offset(cx + off, cy - off), Offset(cx - off, cy), Offset(cx + off, cy), Offset(cx - off, cy + off), Offset(cx + off, cy + off)]); break;
    }
    for (final pos in positions) canvas.drawCircle(pos, r, p);
  }

  @override
  bool shouldRepaint(covariant _MiniDiePainter old) => old.value != value;
}

// ═══════════════════════════════════════════════════════════════════════
// REMAINING WIDGETS (status, buttons, game over, portraits)
// ═══════════════════════════════════════════════════════════════════════

class _StatusBanner extends StatelessWidget {
  final String text;
  final bool isFarkle;
  const _StatusBanner({required this.text, required this.isFarkle});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isFarkle ? const Color(0xFF2a0808) : const Color(0xFF0a0804),
        border: Border.all(color: isFarkle ? const Color(0xFFcc3030) : const Color(0xFF3a2a18), width: 1.5),
        borderRadius: BorderRadius.circular(6),
        boxShadow: isFarkle ? [BoxShadow(color: const Color(0xFFcc3030).withOpacity(0.25), blurRadius: 10)] : null),
      child: Text(text, textAlign: TextAlign.center, style: TextStyle(
        color: isFarkle ? const Color(0xFFff6060) : const Color(0xFFb8a878),
        fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.w600, height: 1.3)));
  }
}

class _ActionButtons extends StatelessWidget {
  final FarklePhase phase;
  final bool hasSelection;
  final int turnScore;
  final int selectionScore; // score of currently selected dice
  final VoidCallback onRoll, onKeepAndRoll, onBank;
  const _ActionButtons({
    required this.phase, required this.hasSelection, required this.turnScore,
    this.selectionScore = 0,
    required this.onRoll, required this.onKeepAndRoll, required this.onBank,
  });
  @override
  Widget build(BuildContext context) {
    final bankTotal = turnScore + selectionScore;
    final bankLabel = bankTotal > 0 ? 'SCORE $bankTotal' : 'SCORE & PASS';
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        if (phase == FarklePhase.rolling)
          _GameButton(label: 'ROLL', shortcut: 'SPC', color: const Color(0xFF5588dd), onTap: onRoll),
        if (phase == FarklePhase.selecting) ...[
          _GameButton(label: 'KEEP & ROLL', shortcut: 'SPC',
            color: hasSelection ? const Color(0xFF44aa44) : const Color(0xFF3a3a3a),
            onTap: hasSelection ? onKeepAndRoll : null),
          const SizedBox(width: 10),
          _GameButton(label: bankLabel, shortcut: 'W',
            color: turnScore > 0 || hasSelection ? const Color(0xFFcc9933) : const Color(0xFF3a3a3a),
            onTap: turnScore > 0 || hasSelection ? onBank : null),
        ],
      ]));
  }
}

class _GameButton extends StatefulWidget {
  final String label, shortcut;
  final Color color;
  final VoidCallback? onTap;
  const _GameButton({required this.label, required this.shortcut, required this.color, this.onTap});
  @override
  State<_GameButton> createState() => _GameButtonState();
}
class _GameButtonState extends State<_GameButton> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final c = enabled ? widget.color : const Color(0xFF2a2a2a);
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) { setState(() => _pressed = false); widget.onTap?.call(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(duration: const Duration(milliseconds: 80),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: _pressed ? [c.withOpacity(0.25), c.withOpacity(0.10)]
              : [c.withOpacity(0.20), c.withOpacity(0.05)]),
          border: Border.all(color: c, width: enabled ? 2 : 1),
          borderRadius: BorderRadius.circular(8),
          boxShadow: enabled && !_pressed ? [BoxShadow(color: c.withOpacity(0.25), blurRadius: 10)] : null),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(widget.label, style: TextStyle(color: enabled ? c : const Color(0xFF4a4a4a),
            fontSize: 13, fontFamily: 'monospace', fontWeight: FontWeight.w800, letterSpacing: 0.5)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(color: c.withOpacity(enabled ? 0.15 : 0.05),
              borderRadius: BorderRadius.circular(3), border: Border.all(color: c.withOpacity(0.3), width: 0.5)),
            child: Text(widget.shortcut, style: TextStyle(
              color: (enabled ? c : const Color(0xFF4a4a4a)).withOpacity(0.7),
              fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.w600))),
        ])));
  }
}

class _GameOverBanner extends StatelessWidget {
  final bool playerWon;
  final String npcName;
  final int betAmount;
  const _GameOverBanner({required this.playerWon, required this.npcName, required this.betAmount});
  @override
  Widget build(BuildContext context) {
    final accent = playerWon ? const Color(0xFF44cc44) : const Color(0xFFcc4040);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: playerWon
          ? [const Color(0xFF0a2a0a), const Color(0xFF0a1a0a)]
          : [const Color(0xFF2a0a0a), const Color(0xFF1a0808)]),
        border: Border.all(color: accent, width: 2), borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: accent.withOpacity(0.3), blurRadius: 16)]),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(playerWon ? 'VICTORY' : 'DEFEAT', style: TextStyle(color: accent, fontSize: 28,
          fontFamily: 'monospace', fontWeight: FontWeight.w900, letterSpacing: 4,
          shadows: [Shadow(color: accent.withOpacity(0.5), blurRadius: 12)])),
        const SizedBox(height: 8),
        Text(playerWon ? 'You won ${betAmount}g from $npcName!' : '$npcName takes ${betAmount}g from you!',
          style: const TextStyle(color: Color(0xFFc8b898), fontSize: 13, fontFamily: 'monospace')),
      ]));
  }
}

class _ObserveGameOverBanner extends StatelessWidget {
  final bool npc1Won;
  final String npc1Name, npc2Name;
  final int betAmount;
  const _ObserveGameOverBanner({
    required this.npc1Won, required this.npc1Name, required this.npc2Name, required this.betAmount});
  @override
  Widget build(BuildContext context) {
    final winnerName = npc1Won ? npc1Name : npc2Name;
    final loserName = npc1Won ? npc2Name : npc1Name;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF0a1a2a), Color(0xFF080e18)]),
        border: Border.all(color: const Color(0xFFd4b040), width: 2), borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: const Color(0xFFd4b040).withOpacity(0.2), blurRadius: 16)]),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('GAME OVER', style: TextStyle(color: Color(0xFFd4b040), fontSize: 24,
          fontFamily: 'monospace', fontWeight: FontWeight.w900, letterSpacing: 3)),
        const SizedBox(height: 8),
        Text('$winnerName beat $loserName for ${betAmount}g!',
          style: const TextStyle(color: Color(0xFFc8b898), fontSize: 13, fontFamily: 'monospace')),
      ]));
  }
}

class _LargePortraitPainter extends CustomPainter {
  final Color color;
  final _Reaction reaction;
  final double time;
  final bool isPlayer;
  _LargePortraitPainter({required this.color, required this.reaction, required this.time, required this.isPlayer});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..shader = RadialGradient(colors: [color.withOpacity(0.15), const Color(0xFF0a0804)])
        .createShader(Rect.fromLTWH(0, 0, size.width, size.height)));

    final bob = sin(time * 2) * 1.5;
    final headR = size.width * 0.28;
    final headY = cy - size.height * 0.05 + bob;

    canvas.drawRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(cx - headR * 1.3, headY + headR * 0.9, headR * 2.6, size.height),
      const Radius.circular(8)),
      Paint()..color = isPlayer ? const Color(0xFF2255AA) : color);

    canvas.drawCircle(Offset(cx, headY), headR, Paint()..color = const Color(0xFFE8C498));
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, headY - 2), radius: headR),
      3.14, 3.14, true, Paint()..color = isPlayer ? const Color(0xFF5A3510) : Color.lerp(color, Colors.brown, 0.5)!);

    final eyePaint = Paint()..color = Colors.black;
    final eyeY = headY - headR * 0.1;
    final eyeSpread = headR * 0.35;
    final er = headR * 0.1;

    switch (reaction) {
      case _Reaction.neutral:
        canvas.drawCircle(Offset(cx - eyeSpread, eyeY), er, eyePaint);
        canvas.drawCircle(Offset(cx + eyeSpread, eyeY), er, eyePaint);
        final wp = Paint()..color = Colors.white;
        canvas.drawCircle(Offset(cx - eyeSpread + 1, eyeY - 1), er * 0.4, wp);
        canvas.drawCircle(Offset(cx + eyeSpread + 1, eyeY - 1), er * 0.4, wp);
        break;
      case _Reaction.happy: case _Reaction.excited:
        eyePaint.style = PaintingStyle.stroke; eyePaint.strokeWidth = 2;
        canvas.drawArc(Rect.fromCenter(center: Offset(cx - eyeSpread, eyeY), width: er * 3, height: er * 2.5), 3.14, 3.14, false, eyePaint);
        canvas.drawArc(Rect.fromCenter(center: Offset(cx + eyeSpread, eyeY), width: er * 3, height: er * 2.5), 3.14, 3.14, false, eyePaint);
        break;
      case _Reaction.worried:
        canvas.drawCircle(Offset(cx - eyeSpread, eyeY + 1), er * 0.8, eyePaint);
        canvas.drawCircle(Offset(cx + eyeSpread, eyeY + 1), er * 0.8, eyePaint);
        eyePaint.style = PaintingStyle.stroke; eyePaint.strokeWidth = 1.5;
        canvas.drawLine(Offset(cx - eyeSpread - er, eyeY - er * 2), Offset(cx - eyeSpread + er, eyeY - er * 2.5), eyePaint);
        canvas.drawLine(Offset(cx + eyeSpread - er, eyeY - er * 2.5), Offset(cx + eyeSpread + er, eyeY - er * 2), eyePaint);
        break;
      case _Reaction.shocked:
        canvas.drawCircle(Offset(cx - eyeSpread, eyeY), er * 1.5, eyePaint);
        canvas.drawCircle(Offset(cx + eyeSpread, eyeY), er * 1.5, eyePaint);
        final wp = Paint()..color = Colors.white;
        canvas.drawCircle(Offset(cx - eyeSpread + 1, eyeY - 1), er * 0.5, wp);
        canvas.drawCircle(Offset(cx + eyeSpread + 1, eyeY - 1), er * 0.5, wp);
        break;
      case _Reaction.smug:
        eyePaint.style = PaintingStyle.stroke; eyePaint.strokeWidth = 2;
        canvas.drawLine(Offset(cx - eyeSpread - er, eyeY), Offset(cx - eyeSpread + er, eyeY), eyePaint);
        canvas.drawLine(Offset(cx + eyeSpread - er, eyeY), Offset(cx + eyeSpread + er, eyeY), eyePaint);
        break;
      case _Reaction.defeated:
        eyePaint.style = PaintingStyle.stroke; eyePaint.strokeWidth = 1.5;
        for (final ex in [cx - eyeSpread, cx + eyeSpread]) {
          canvas.drawLine(Offset(ex - er, eyeY - er), Offset(ex + er, eyeY + er), eyePaint);
          canvas.drawLine(Offset(ex + er, eyeY - er), Offset(ex - er, eyeY + er), eyePaint);
        }
        break;
    }

    final mouthY = headY + headR * 0.35;
    final mp = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 1.5;
    switch (reaction) {
      case _Reaction.neutral:
        canvas.drawLine(Offset(cx - er * 1.5, mouthY), Offset(cx + er * 1.5, mouthY), mp); break;
      case _Reaction.happy:
        canvas.drawArc(Rect.fromCenter(center: Offset(cx, mouthY - 1), width: er * 4, height: er * 3), 0, 3.14, false, mp); break;
      case _Reaction.excited:
        mp.style = PaintingStyle.fill;
        canvas.drawOval(Rect.fromCenter(center: Offset(cx, mouthY), width: er * 3, height: er * 2.5), mp); break;
      case _Reaction.worried:
        canvas.drawArc(Rect.fromCenter(center: Offset(cx, mouthY + er * 2), width: er * 3, height: er * 2), 3.14, 3.14, false, mp); break;
      case _Reaction.shocked:
        mp.style = PaintingStyle.fill;
        canvas.drawCircle(Offset(cx, mouthY), er * 1.2, mp); break;
      case _Reaction.smug:
        canvas.drawArc(Rect.fromCenter(center: Offset(cx + er * 0.5, mouthY - 1), width: er * 3.5, height: er * 2.5), 0, 2.5, false, mp); break;
      case _Reaction.defeated:
        canvas.drawArc(Rect.fromCenter(center: Offset(cx, mouthY + er * 2), width: er * 4, height: er * 3), 3.14, 3.14, false, mp); break;
    }
  }

  @override
  bool shouldRepaint(covariant _LargePortraitPainter old) => true;
}
