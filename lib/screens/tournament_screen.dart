import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fark_my_life/core/constants.dart';
import 'package:fark_my_life/core/enums.dart';
import 'package:fark_my_life/models/models.dart';
import 'package:fark_my_life/models/dice_tiers.dart';
import 'package:fark_my_life/systems/tournament.dart';
import 'package:fark_my_life/entities/dice_renderer.dart';

/// Full-screen tournament overlay — shows bracket, registration, and awards.
class TournamentScreen extends StatelessWidget {
  final TournamentManager tournament;
  final PlayerData player;
  final VoidCallback? onClose;
  final VoidCallback onRegister;
  final List<NpcData> Function()? getNpcs;
  final int? previewCountdown;
  final String? previewOpponent;

  const TournamentScreen({
    super.key,
    required this.tournament,
    required this.player,
    required this.onClose,
    required this.onRegister,
    this.getNpcs,
    this.previewCountdown,
    this.previewOpponent,
  });

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.escape) {
            if (onClose != null) onClose!();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.keyE ||
              event.logicalKey == LogicalKeyboardKey.space) {
            if (tournament.canRegister) {
              onRegister();
              return KeyEventResult.handled;
            }
            // E exits if not registering
            if (onClose != null) onClose!();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0a0a14), Color(0xFF14101e), Color(0xFF0a0a14)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              // Bracket preview countdown
              if (previewCountdown != null && previewOpponent != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [GameColors.uiHighlight.withOpacity(0.15), const Color(0xFF1a1008), GameColors.uiHighlight.withOpacity(0.15)])),
                  child: Text(
                    '⚔  YOUR MATCH vs ${previewOpponent!.toUpperCase()} in ${previewCountdown}s  ⚔',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontFamily: 'serif', fontSize: 14,
                      fontWeight: FontWeight.bold, color: GameColors.uiHighlight, letterSpacing: 1))),
              const SizedBox(height: 8),
              Expanded(child: _buildBody()),
              if (previewCountdown == null) _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final isActive = tournament.isActive;
    final phaseText = _phaseLabel(tournament.phase);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: GameColors.uiBorder, width: 2)),
      ),
      child: Row(
        children: [
          Text(
            isActive ? tournament.tournamentName.toUpperCase() : 'TOURNAMENT BOARD',
            style: const TextStyle(
              fontFamily: 'serif', fontSize: 16, fontWeight: FontWeight.bold,
              color: GameColors.uiHighlight, letterSpacing: 3,
            ),
          ),
          const SizedBox(width: 16),
          if (isActive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: GameColors.uiHighlight.withOpacity(0.15),
                border: Border.all(color: GameColors.uiHighlight.withOpacity(0.5)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                phaseText,
                style: const TextStyle(
                  fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold,
                  color: GameColors.uiHighlight,
                ),
              ),
            ),
          const Spacer(),
          if (tournament.phase == TournamentPhase.announcing ||
              tournament.phase == TournamentPhase.registration)
            Text(
              '${tournament.timeRemaining.ceil()}s',
              style: const TextStyle(
                fontFamily: 'monospace', fontSize: 16, fontWeight: FontWeight.bold,
                color: GameColors.uiDanger,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (tournament.phase) {
      case TournamentPhase.idle:
        return _buildIdleView();
      case TournamentPhase.announcing:
      case TournamentPhase.registration:
        return _buildRegistrationView();
      case TournamentPhase.bracketSet:
      case TournamentPhase.round1:
      case TournamentPhase.round2:
      case TournamentPhase.finalRound:
        return _buildBracketView();
      case TournamentPhase.awards:
        return _buildAwardsView();
    }
  }

  // ── IDLE: Show last tournament results ─────────────────────────────

  Widget _buildIdleView() {
    final record = tournament.lastRecord;
    tournament.ensureUpcomingPrizes();
    final upcoming = tournament.upcomingPrizes;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        if (record != null) ...[
          const Text('LAST TOURNAMENT', style: TextStyle(
            fontFamily: 'serif', fontSize: 13, fontWeight: FontWeight.bold,
            color: GameColors.uiMuted, letterSpacing: 2)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: GameColors.uiHighlight.withOpacity(0.08),
              border: Border.all(color: GameColors.uiHighlight.withOpacity(0.4)),
              borderRadius: BorderRadius.circular(6)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('👑 ', style: TextStyle(fontSize: 14)),
              Text('${record.winnerName}', style: const TextStyle(fontFamily: 'serif', fontSize: 14,
                fontWeight: FontWeight.bold, color: GameColors.uiHighlight)),
              Text('  —  ${record.prizeDie.name}', style: TextStyle(fontFamily: 'monospace',
                fontSize: 10, color: record.prizeDie.tierColor)),
            ]),
          ),
          const SizedBox(height: 12),
          Expanded(child: _buildMiniBracket(record.matches, record.entrantNames)),
        ] else
          const Spacer(),
        const SizedBox(height: 8),
        // Upcoming prizes
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF141018),
            border: Border.all(color: const Color(0xFF3a3020)),
            borderRadius: BorderRadius.circular(6)),
          child: Column(children: [
            const Text('UPCOMING PRIZES', style: TextStyle(fontFamily: 'serif', fontSize: 11,
              fontWeight: FontWeight.bold, color: Color(0xFFc0a040), letterSpacing: 2)),
            const SizedBox(height: 6),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(upcoming.length.clamp(0, 3), (i) {
                final die = upcoming[i];
                return Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(i == 0 ? 'NEXT' : i == 1 ? 'THEN' : 'AFTER',
                    style: TextStyle(fontFamily: 'monospace', fontSize: 7,
                      color: i == 0 ? GameColors.uiHighlight : GameColors.uiMuted)),
                  const SizedBox(height: 3),
                  SizedBox(width: 32, height: 32, child: CustomPaint(
                    painter: MiniMaterialDiePainter(
                      value: (i * 2 + 1) % 6 + 1, material: die.material,
                      enchantment: die.enchantment))),
                  const SizedBox(height: 2),
                  Text(die.name, style: TextStyle(fontFamily: 'monospace', fontSize: 7,
                    color: die.tierColor, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
                ]);
              }),
            ),
          ]),
        ),
        const SizedBox(height: 6),
        Text('Next tournament in ${tournament.gamesUntilNext} games.',
          style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: GameColors.uiMuted)),
      ]),
    );
  }

  // ── REGISTRATION: Prize + register button + entrants ───────────────

  Widget _buildRegistrationView() {
    final prize = tournament.prizeDie;
    final canReg = tournament.canRegister;
    final canAfford = player.gold >= TournamentManager.entryFee;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Prize display
          if (prize != null) ...[
            const Text('PRIZE', style: TextStyle(fontFamily: 'monospace',
                fontSize: 12, color: GameColors.uiMuted, letterSpacing: 2)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [prize.tierColor.withOpacity(0.1), Colors.transparent],
                ),
                border: Border.all(color: prize.tierColor.withOpacity(0.6), width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  // Die visual
                  SizedBox(
                    width: 48, height: 48,
                    child: CustomPaint(
                      painter: MiniMaterialDiePainter(
                        value: 6, material: prize.material,
                        enchantment: prize.enchantment,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(prize.name,
                      style: TextStyle(fontFamily: 'monospace', fontSize: 15,
                          fontWeight: FontWeight.bold, color: prize.tierColor)),
                  Text('[Tier ${DiceTiers.tierLabel(prize.tier)}]',
                      style: TextStyle(fontFamily: 'monospace', fontSize: 11,
                          color: prize.tierColor.withOpacity(0.7))),
                  if (prize.enchantment != null) ...[
                    const SizedBox(height: 4),
                    Text(DiceTiers.enchantmentDesc(prize.enchantment!),
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 10,
                            color: GameColors.uiText)),
                  ],
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Register button
          if (canReg)
            GestureDetector(
              onTap: canAfford ? onRegister : null,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: canAfford
                        ? [const Color(0xFF2a5a2a), const Color(0xFF1a3a1a)]
                        : [const Color(0xFF3a3a3a), const Color(0xFF2a2a2a)],
                  ),
                  border: Border.all(
                    color: canAfford ? const Color(0xFF44aa44) : const Color(0xFF555555),
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  canAfford
                      ? '[E] ENTER THE LISTS — ${TournamentManager.entryFee}g'
                      : 'NOT ENOUGH GOLD (need ${TournamentManager.entryFee}g)',
                  style: TextStyle(
                    fontFamily: 'monospace', fontSize: 14, fontWeight: FontWeight.bold,
                    color: canAfford ? const Color(0xFF88ff88) : const Color(0xFF888888),
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),

          if (tournament.playerRegistered)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: GameColors.uiSuccess.withOpacity(0.15),
                border: Border.all(color: GameColors.uiSuccess),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('REGISTERED',
                  style: TextStyle(fontFamily: 'monospace', fontSize: 14,
                      fontWeight: FontWeight.bold, color: GameColors.uiSuccess)),
            ),

          const SizedBox(height: 16),

          // Entrant list
          const Text('ENTRANTS', style: TextStyle(fontFamily: 'monospace',
              fontSize: 11, color: GameColors.uiMuted, letterSpacing: 2)),
          const SizedBox(height: 4),
          Expanded(
            child: ListView.builder(
              itemCount: tournament.entrantNames.length,
              itemBuilder: (ctx, i) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  '${i + 1}. ${tournament.entrantNames[i]}',
                  style: TextStyle(
                    fontFamily: 'monospace', fontSize: 12,
                    color: tournament.entrantIds[i] == 'player'
                        ? GameColors.uiHighlight : GameColors.uiText,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── BRACKET VIEW ───────────────────────────────────────────────────

  Widget _buildBracketView() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: _buildMiniBracket(tournament.matches, tournament.entrantNames,
          highlightCurrent: true),
    );
  }

  Widget _buildMiniBracket(List<TournamentMatch> matches, List<String> names,
      {bool highlightCurrent = false}) {
    if (matches.length < 7) {
      return const Center(child: Text('Building bracket...',
          style: TextStyle(fontFamily: 'monospace', color: GameColors.uiMuted)));
    }

    return Row(
      children: [
        // Quarterfinals
        Expanded(flex: 3, child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _matchCard(matches[0], 'QF1', highlightCurrent),
            _matchCard(matches[1], 'QF2', highlightCurrent),
            _matchCard(matches[2], 'QF3', highlightCurrent),
            _matchCard(matches[3], 'QF4', highlightCurrent),
          ],
        )),
        // Connector lines
        const SizedBox(width: 4),
        // Semifinals
        Expanded(flex: 3, child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _matchCard(matches[4], 'SF1', highlightCurrent),
            const SizedBox(height: 40),
            _matchCard(matches[5], 'SF2', highlightCurrent),
          ],
        )),
        const SizedBox(width: 4),
        // Final
        Expanded(flex: 3, child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _matchCard(matches[6], 'FINAL', highlightCurrent),
          ],
        )),
      ],
    );
  }

  Widget _matchCard(TournamentMatch match, String label, bool highlightCurrent) {
    final isActive = !match.completed &&
        match.entrant1Id != null && match.entrant2Id != null;
    final isCurrent = highlightCurrent && isActive;
    final name1 = _shortName(match.entrant1Id);
    final name2 = _shortName(match.entrant2Id);
    final isFinal = label == 'FINAL';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: isCurrent
            ? GameColors.uiHighlight.withOpacity(0.1)
            : isFinal && match.completed
                ? const Color(0xFF1a1a08)
                : const Color(0xFF1a1420),
        border: Border.all(
          color: isCurrent ? GameColors.uiHighlight
              : isFinal && match.completed ? const Color(0xFF8a7a20)
              : match.completed ? const Color(0xFF3a3a3a)
              : const Color(0xFF4a3a28),
          width: (isCurrent || isFinal) ? 2 : 1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(fontFamily: 'serif', fontSize: 8,
              fontWeight: FontWeight.bold,
              color: isCurrent ? GameColors.uiHighlight
                  : isFinal ? const Color(0xFFc0a040) : GameColors.uiMuted,
              letterSpacing: 1)),
          const SizedBox(height: 3),
          _entrantRow(match.entrant1Id, name1, match.winnerId == match.entrant1Id, match.completed, match.score1),
          Container(height: 1, color: const Color(0xFF2a2a2a), margin: const EdgeInsets.symmetric(vertical: 2)),
          _entrantRow(match.entrant2Id, name2, match.winnerId == match.entrant2Id, match.completed, match.score2),
        ],
      ),
    );
  }

  Widget _entrantRow(String? id, String name, bool isWinner, bool completed, int score) {
    final isPlayer = id == 'player';
    final isBye = name == 'BYE' || (id?.startsWith('bye') ?? false) || id == null;

    // BYEs are always muted, never winners visually
    if (isBye) {
      return Row(children: [
        Expanded(child: Text('—', style: TextStyle(
          fontFamily: 'monospace', fontSize: 10, color: const Color(0xFF3a3a3a)))),
      ]);
    }

    final color = isWinner && completed ? GameColors.uiSuccess
        : completed ? const Color(0xFF6a5a40)
        : isPlayer ? const Color(0xFF60a0ff)
        : GameColors.uiText;
    Color portraitColor = isPlayer ? const Color(0xFF4488cc) : const Color(0xFF8a7a60);
    for (final npc in (getNpcs?.call() ?? <NpcData>[])) {
      if (npc.id == id) { portraitColor = npc.primaryColor; break; }
    }

    return Row(children: [
      Container(
        width: 16, height: 16,
        margin: const EdgeInsets.only(right: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF1a1410),
          border: Border.all(color: isWinner && completed
              ? GameColors.uiSuccess.withOpacity(0.5)
              : portraitColor.withOpacity(0.3), width: 1),
          borderRadius: BorderRadius.circular(2)),
        child: CustomPaint(painter: _TinyPortrait(color: portraitColor)),
      ),
      Expanded(child: Text(name, style: TextStyle(
        fontFamily: 'monospace', fontSize: 10,
        fontWeight: isWinner ? FontWeight.bold : FontWeight.normal,
        color: color))),
      if (completed && score > 0)
        Text('$score', style: TextStyle(fontFamily: 'monospace', fontSize: 9,
          color: isWinner ? GameColors.uiSuccess : const Color(0xFF5a5040))),
      if (isWinner && completed && !isBye)
        const Padding(padding: EdgeInsets.only(left: 3),
          child: Text('👑', style: TextStyle(fontSize: 8))),
    ]);
  }
  Widget _buildAwardsView() {
    final winnerId = tournament.matches.isNotEmpty
        ? tournament.matches.last.winnerId : null;
    final winnerIdx = tournament.entrantIds.indexOf(winnerId ?? '');
    final winnerName = winnerId == 'player' ? 'YOU' :
        (winnerIdx >= 0 && winnerIdx < tournament.entrantNames.length
            ? tournament.entrantNames[winnerIdx]
            : '???');
    final isPlayerWin = winnerId == 'player';
    final prize = tournament.prizeDie;

    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isPlayerWin
                ? [const Color(0xFF0a2a0a), const Color(0xFF0a1a0a)]
                : [const Color(0xFF1a1a08), const Color(0xFF0a0a04)],
          ),
          border: Border.all(
            color: isPlayerWin ? GameColors.uiSuccess : GameColors.uiHighlight,
            width: 3,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: (isPlayerWin ? GameColors.uiSuccess : GameColors.uiHighlight)
                  .withOpacity(0.3),
              blurRadius: 20,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isPlayerWin ? 'VICTORY!' : 'TOURNAMENT COMPLETE',
              style: TextStyle(
                fontFamily: 'monospace', fontSize: 24, fontWeight: FontWeight.w900,
                color: isPlayerWin ? GameColors.uiSuccess : GameColors.uiHighlight,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 12),
            Text('Champion: $winnerName',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 16,
                    color: GameColors.uiText)),
            if (prize != null) ...[
              const SizedBox(height: 16),
              Text('Prize: ${prize.name}',
                  style: TextStyle(fontFamily: 'monospace', fontSize: 15,
                      fontWeight: FontWeight.bold, color: prize.tierColor)),
              Text('[Tier ${DiceTiers.tierLabel(prize.tier)}]',
                  style: TextStyle(fontFamily: 'monospace', fontSize: 11,
                      color: prize.tierColor.withOpacity(0.7))),
            ],
          ],
        ),
      ),
    );
  }

  // ── FOOTER ─────────────────────────────────────────────────────────

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: GameColors.uiBorder, width: 2)),
      ),
      child: Row(
        children: [
          Text(
            tournament.canRegister ? '[E] Register  •  [ESC] Close' : '[ESC] Close',
            style: const TextStyle(fontFamily: 'monospace', fontSize: 10,
                color: GameColors.uiMuted),
          ),
          const Spacer(),
          GestureDetector(
            onTap: onClose,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(color: GameColors.uiBorder, width: 2),
                borderRadius: BorderRadius.circular(2),
                color: const Color(0xFF2a1a00),
              ),
              child: const Text('CLOSE',
                  style: TextStyle(fontFamily: 'monospace', fontSize: 13,
                      fontWeight: FontWeight.bold, color: GameColors.uiHighlight,
                      letterSpacing: 2)),
            ),
          ),
        ],
      ),
    );
  }

  // ── HELPERS ────────────────────────────────────────────────────────

  String _phaseLabel(TournamentPhase phase) {
    switch (phase) {
      case TournamentPhase.idle:         return 'IDLE';
      case TournamentPhase.announcing:   return 'ANNOUNCING';
      case TournamentPhase.registration: return 'REGISTRATION';
      case TournamentPhase.bracketSet:   return 'BRACKET SET';
      case TournamentPhase.round1:       return 'QUARTERFINALS';
      case TournamentPhase.round2:       return 'SEMIFINALS';
      case TournamentPhase.finalRound:   return 'FINAL';
      case TournamentPhase.awards:       return 'AWARDS';
    }
  }

  String _shortName(String? id) {
    if (id == null) return 'BYE';
    if (id == 'player') return 'YOU';
    if (id.startsWith('bye')) return 'BYE';
    final idx = tournament.entrantIds.indexOf(id);
    if (idx >= 0 && idx < tournament.entrantNames.length) {
      return tournament.entrantNames[idx];
    }
    return id.split('_').last;
  }
}

class _TinyPortrait extends CustomPainter {
  final Color color;
  _TinyPortrait({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint();
    p.color = color;
    canvas.drawRect(Rect.fromLTWH(size.width * 0.25, size.height * 0.45,
        size.width * 0.5, size.height * 0.5), p);
    p.color = const Color(0xFFdbb888);
    canvas.drawRect(Rect.fromLTWH(size.width * 0.3, size.height * 0.1,
        size.width * 0.4, size.height * 0.35), p);
    p.color = const Color(0xFF2a2a2a);
    canvas.drawRect(Rect.fromLTWH(size.width * 0.35, size.height * 0.22, 2, 2), p);
    canvas.drawRect(Rect.fromLTWH(size.width * 0.55, size.height * 0.22, 2, 2), p);
  }

  @override
  bool shouldRepaint(covariant _TinyPortrait old) => old.color != color;
}
