import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fark_my_life/core/constants.dart';
import 'package:fark_my_life/core/enums.dart';
import 'package:fark_my_life/models/models.dart';
import 'package:fark_my_life/models/dice_tiers.dart';
import 'package:fark_my_life/models/game_history.dart';

/// WC3-inspired player/NPC profile screen.
class ProfileScreen extends StatelessWidget {
  final String name;
  final String title; // e.g. "WANDERER" or "MERCHANT"
  final Color portraitColor;
  final PlayHistory history;
  final int gold;
  final int diceCount;
  final List<DiceItem>? equippedDice;
  final bool isPlayer;
  final VoidCallback onClose;

  const ProfileScreen({
    super.key,
    required this.name,
    required this.title,
    required this.portraitColor,
    required this.history,
    required this.gold,
    this.diceCount = 6,
    this.equippedDice,
    this.isPlayer = true,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.escape ||
             event.logicalKey == LogicalKeyboardKey.keyP)) {
          onClose();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Color(0xFF0c0a14), Color(0xFF141018), Color(0xFF0c0a14)],
          ),
        ),
        child: SafeArea(child: Row(children: [
          // ── LEFT PANEL: Portrait + Info + Play History ──
          Expanded(flex: 5, child: _buildLeftPanel()),
          // ── Divider ──
          Container(width: 2, color: const Color(0xFF3a2a18)),
          // ── RIGHT PANEL: Opponent Records + Badges ──
          Expanded(flex: 5, child: _buildRightPanel()),
        ])),
      ),
    );
  }

  Widget _buildLeftPanel() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Portrait + Name ──
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Portrait frame
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFc0a050), width: 3),
              borderRadius: BorderRadius.circular(4),
              color: const Color(0xFF1a1410),
              boxShadow: [BoxShadow(color: portraitColor.withOpacity(0.3), blurRadius: 12)],
            ),
            child: CustomPaint(painter: _ProfilePortraitPainter(color: portraitColor)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Name:', style: _labelStyle()),
            Text(name, style: TextStyle(fontFamily: 'monospace', fontSize: 18,
              fontWeight: FontWeight.bold, color: GameColors.uiHighlight)),
            const SizedBox(height: 4),
            Text(title, style: TextStyle(fontFamily: 'monospace', fontSize: 10,
              color: const Color(0xFF8a7a50), fontWeight: FontWeight.w600, letterSpacing: 2)),
            const SizedBox(height: 4),
            Text('${gold}g', style: const TextStyle(fontFamily: 'monospace', fontSize: 14,
              color: GameColors.uiHighlight, fontWeight: FontWeight.bold)),
          ])),
        ]),

        const SizedBox(height: 12),
        Container(height: 1, color: const Color(0xFF3a2a18)),
        const SizedBox(height: 8),

        // ── Overall Stats ──
        Text('Play History:', style: _headerStyle()),
        const SizedBox(height: 8),
        _buildStatTable(),

        const SizedBox(height: 12),
        Container(height: 1, color: const Color(0xFF3a2a18)),
        const SizedBox(height: 8),

        // ── Additional Stats ──
        Text('Records:', style: _headerStyle()),
        const SizedBox(height: 6),
        _statLine('Highest Turn Score', '${history.highestSingleTurnScore}'),
        _statLine('Total Busts', '${history.bustCount}'),
        _statLine('Hot Dice Rolled', '${history.hotDiceCount}'),
        _statLine('Longest Win Streak', '${history.longestWinStreak}'),
        _statLine('Net Gold', '${history.netGold >= 0 ? "+" : ""}${history.netGold}g'),
        _statLine('Tournaments Entered', '${history.tournamentsEntered}'),
        _statLine('Tournaments Won', '${history.tournamentsWon}'),

        const Spacer(),
        // Close button
        GestureDetector(
          onTap: onClose,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: GameColors.uiBorder, width: 2),
              borderRadius: BorderRadius.circular(2),
              color: const Color(0xFF2a1a00)),
            child: const Text('Back', style: TextStyle(fontFamily: 'monospace',
              fontSize: 14, fontWeight: FontWeight.bold, color: GameColors.uiHighlight)),
          ),
        ),
      ]),
    );
  }

  Widget _buildStatTable() {
    // WC3-style wins/losses/win% table
    final opponents = history.opponents.values.toList()
      ..sort((a, b) => b.totalGames.compareTo(a.totalGames));

    // Group by NPC type (simulated — we just show per-opponent)
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Header row
      Row(children: [
        SizedBox(width: 90, child: Text('Opponent:', style: _colHeaderStyle())),
        SizedBox(width: 40, child: Text('Wins:', style: _colHeaderStyle())),
        SizedBox(width: 50, child: Text('Losses:', style: _colHeaderStyle())),
        SizedBox(width: 50, child: Text('Win %:', style: _colHeaderStyle())),
      ]),
      const SizedBox(height: 2),
      // Per-opponent rows (show top 6)
      ...opponents.take(6).map((o) => Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Row(children: [
          SizedBox(width: 90, child: Text(o.name, style: _valueStyle(
            color: o.wins > o.losses ? GameColors.uiSuccess : GameColors.uiText))),
          SizedBox(width: 40, child: Text('${o.wins}', style: _valueStyle(color: GameColors.uiSuccess))),
          SizedBox(width: 50, child: Text('${o.losses}', style: _valueStyle(
            color: o.losses > 0 ? GameColors.uiDanger : GameColors.uiText))),
          SizedBox(width: 50, child: Text('${(o.winRate * 100).toStringAsFixed(1)}%',
            style: _valueStyle(color: o.winRate >= 0.5 ? GameColors.uiSuccess : GameColors.uiDanger))),
        ]),
      )),
      if (opponents.isEmpty)
        Text('No games played yet.', style: _valueStyle(color: GameColors.uiMuted)),
      const SizedBox(height: 4),
      // Total row
      Container(height: 1, color: const Color(0xFF2a2218)),
      const SizedBox(height: 2),
      Row(children: [
        SizedBox(width: 90, child: Text('Total:', style: _colHeaderStyle())),
        SizedBox(width: 40, child: Text('${history.totalWins}',
          style: _valueStyle(color: GameColors.uiSuccess))),
        SizedBox(width: 50, child: Text('${history.totalLosses}',
          style: _valueStyle(color: history.totalLosses > 0 ? GameColors.uiDanger : GameColors.uiText))),
        SizedBox(width: 50, child: Text('${(history.winRate * 100).toStringAsFixed(1)}%',
          style: _valueStyle(color: history.winRate >= 0.5 ? GameColors.uiSuccess : GameColors.uiDanger))),
      ]),
    ]);
  }

  Widget _buildRightPanel() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Badges ──
        Text('Badges:', style: _headerStyle()),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6,
          children: Badges.all.map((badge) {
            final earned = history.earnedBadges.contains(badge.id);
            return Tooltip(
              message: '${badge.name}: ${badge.description}',
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: earned ? const Color(0xFF2a2010) : const Color(0xFF0a0a08),
                  border: Border.all(
                    color: earned ? const Color(0xFFc0a040) : const Color(0xFF2a2a2a), width: 1.5),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: earned ? [
                    BoxShadow(color: const Color(0xFFc0a040).withOpacity(0.2), blurRadius: 4),
                  ] : null,
                ),
                child: Center(
                  child: Text(earned ? badge.icon : '?',
                    style: TextStyle(fontSize: earned ? 16 : 12,
                      color: earned ? Colors.white : const Color(0xFF3a3a3a))),
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 16),
        Container(height: 1, color: const Color(0xFF3a2a18)),
        const SizedBox(height: 8),

        // ── Recent Games ──
        Text('Recent Games:', style: _headerStyle()),
        const SizedBox(height: 6),
        Expanded(
          child: history.recentGames.isEmpty
              ? Center(child: Text('No games yet.', style: _valueStyle(color: GameColors.uiMuted)))
              : ListView.builder(
                  itemCount: history.recentGames.length,
                  itemBuilder: (ctx, i) {
                    // Show most recent first
                    final game = history.recentGames[history.recentGames.length - 1 - i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 3),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: game.won ? const Color(0xFF0a1a0a) : const Color(0xFF1a0a0a),
                        border: Border.all(
                          color: game.won
                              ? GameColors.uiSuccess.withOpacity(0.3)
                              : GameColors.uiDanger.withOpacity(0.3)),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Row(children: [
                        Text(game.won ? 'W' : 'L', style: TextStyle(
                          fontFamily: 'monospace', fontSize: 10, fontWeight: FontWeight.bold,
                          color: game.won ? GameColors.uiSuccess : GameColors.uiDanger)),
                        const SizedBox(width: 6),
                        Expanded(child: Text(
                          'vs ${game.opponentName}${game.wasTournament ? " ⚔" : ""}',
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 9,
                            color: GameColors.uiText),
                          overflow: TextOverflow.ellipsis)),
                        Text('${game.betAmount}g', style: TextStyle(fontFamily: 'monospace',
                          fontSize: 9, color: game.won ? GameColors.uiSuccess : GameColors.uiDanger)),
                      ]),
                    );
                  },
                ),
        ),
      ]),
    );
  }

  // ── Style helpers ──
  TextStyle _labelStyle() => const TextStyle(fontFamily: 'monospace', fontSize: 10,
    color: Color(0xFFc0a040), fontWeight: FontWeight.w600);
  TextStyle _headerStyle() => const TextStyle(fontFamily: 'monospace', fontSize: 13,
    color: Color(0xFFc0a040), fontWeight: FontWeight.bold);
  TextStyle _colHeaderStyle() => const TextStyle(fontFamily: 'monospace', fontSize: 9,
    color: Color(0xFFc0a040), fontWeight: FontWeight.w600);
  TextStyle _valueStyle({Color color = GameColors.uiText}) =>
    TextStyle(fontFamily: 'monospace', fontSize: 10, color: color);

  Widget _statLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(children: [
        Expanded(child: Text(label, style: _valueStyle(color: const Color(0xFF8a7a60)))),
        Text(value, style: _valueStyle(color: GameColors.uiText)),
      ]),
    );
  }
}

class _ProfilePortraitPainter extends CustomPainter {
  final Color color;
  _ProfilePortraitPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint();
    // Body
    p.color = color;
    canvas.drawRect(Rect.fromLTWH(size.width * 0.2, size.height * 0.4,
        size.width * 0.6, size.height * 0.55), p);
    // Head
    p.color = const Color(0xFFdbb888);
    canvas.drawRect(Rect.fromLTWH(size.width * 0.25, size.height * 0.08,
        size.width * 0.5, size.height * 0.38), p);
    // Hair
    p.color = const Color(0xFF5a3a1a);
    canvas.drawRect(Rect.fromLTWH(size.width * 0.23, size.height * 0.05,
        size.width * 0.54, size.height * 0.14), p);
    // Eyes
    p.color = const Color(0xFF2a2a2a);
    canvas.drawRect(Rect.fromLTWH(size.width * 0.33, size.height * 0.22, 4, 4), p);
    canvas.drawRect(Rect.fromLTWH(size.width * 0.57, size.height * 0.22, 4, 4), p);
  }

  @override
  bool shouldRepaint(covariant _ProfilePortraitPainter old) => old.color != color;
}
