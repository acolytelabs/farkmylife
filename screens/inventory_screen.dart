import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fark_my_life/core/constants.dart';
import 'package:fark_my_life/core/enums.dart';
import 'package:fark_my_life/models/models.dart';
import 'package:fark_my_life/models/dice_tiers.dart';
import 'package:fark_my_life/entities/dice_renderer.dart';

/// Inventory screen showing player stats and dice collection.
class InventoryScreen extends StatefulWidget {
  final PlayerData player;
  final VoidCallback onClose;

  const InventoryScreen({
    super.key,
    required this.player,
    required this.onClose,
  });

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen>
    with TickerProviderStateMixin {
  int? _selectedDieIndex;
  late AnimationController _shimmerController;
  int _tabIndex = 0; // 0 = Collection, 1 = Loadouts
  int _editingLoadoutIndex = -1;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  Color _rarityColor(DiceRarity rarity) {
    switch (rarity) {
      case DiceRarity.common:    return GameColors.tierCommon;
      case DiceRarity.uncommon:  return GameColors.tierUncommon;
      case DiceRarity.rare:      return GameColors.tierRare;
      case DiceRarity.epic:      return GameColors.tierEpic;
      case DiceRarity.legendary: return GameColors.tierLegendary;
    }
  }

  String _rarityLabel(DiceRarity rarity) {
    switch (rarity) {
      case DiceRarity.common:    return 'COMMON';
      case DiceRarity.uncommon:  return 'UNCOMMON';
      case DiceRarity.rare:      return 'RARE';
      case DiceRarity.epic:      return 'EPIC';
      case DiceRarity.legendary: return 'LEGENDARY';
    }
  }

  Color _diceBodyColor(DiceItem die) {
    switch (die.material) {
      case DiceMaterial.birch:    return const Color(0xFFd4c4a0);
      case DiceMaterial.oak:      return const Color(0xFFa08050);
      case DiceMaterial.mahogany: return const Color(0xFF6a3a22);
      case DiceMaterial.bone:     return const Color(0xFFe8dcc8);
      case DiceMaterial.stone:    return const Color(0xFF8a8a88);
      case DiceMaterial.iron:     return const Color(0xFF808890);
      case DiceMaterial.bronze:   return const Color(0xFFc89848);
      case DiceMaterial.gold:     return const Color(0xFFffd700);
      case DiceMaterial.jade:     return const Color(0xFF40b860);
      case DiceMaterial.crystal:  return const Color(0xFFb0e0ff);
      case DiceMaterial.obsidian: return const Color(0xFF2a1830);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final player = widget.player;

    // Group dice by type for display
    final diceGroups = <DiceType, int>{};
    for (final die in player.dice) {
      diceGroups[die.type] = (diceGroups[die.type] ?? 0) + 1;
    }

    return Container(
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
            // ── Header bar ──────────────────────────────────────────
            _buildHeader(player),
            const SizedBox(height: 8),

            // ── Stats row ───────────────────────────────────────────
            _buildStatsRow(player),
            const SizedBox(height: 8),

            // ── Tab row ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                _tabBtn('COLLECTION', _tabIndex == 0, () => setState(() => _tabIndex = 0)),
                const SizedBox(width: 8),
                _tabBtn('LOADOUTS', _tabIndex == 1, () => setState(() => _tabIndex = 1)),
              ]),
            ),
            const SizedBox(height: 8),

            // ── Content based on tab ─────────────────────────────────
            Expanded(
              child: _tabIndex == 0
                  ? Row(
                      children: [
                        Expanded(flex: 3, child: _buildDiceGrid(player)),
                        Expanded(flex: 2, child: _buildDetailPanel(player)),
                      ],
                    )
                  : _buildLoadoutTab(player),
            ),

            // ── Footer with close button ────────────────────────────
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(PlayerData player) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: GameColors.uiBorder, width: 2),
        ),
      ),
      child: Row(
        children: [
          const Text(
            '🎒  INVENTORY',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: GameColors.uiHighlight,
              letterSpacing: 4,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0x40FFD700),
              border: Border.all(color: GameColors.uiBorder),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '💰 ${player.gold}g',
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: GameColors.uiHighlight,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(PlayerData player) {
    final totalDice = player.dice.length;
    final specialDice =
        player.dice.where((d) => d.tier != DiceTier.common).length;
    final winRate = player.wins + player.losses > 0
        ? (player.wins / (player.wins + player.losses) * 100).toStringAsFixed(0)
        : '--';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _statBox('WINS', '${player.wins}', GameColors.uiSuccess),
          const SizedBox(width: 8),
          _statBox('LOSSES', '${player.losses}', GameColors.uiDanger),
          const SizedBox(width: 8),
          _statBox('WIN%', '$winRate%', GameColors.uiText),
          const SizedBox(width: 8),
          _statBox('DICE', '$totalDice', GameColors.uiText),
          const SizedBox(width: 8),
          _statBox('SPECIAL', '$specialDice', const Color(0xFFA040D0)),
        ],
      ),
    );
  }

  Widget _statBox(String label, String value, Color valueColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: GameColors.uiBg,
          border: Border.all(color: const Color(0x60C0A060)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 9,
                color: GameColors.uiMuted,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: valueColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiceGrid(PlayerData player) {
    return Container(
      margin: const EdgeInsets.only(left: 16, right: 8, bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0x30201818),
        border: Border.all(color: const Color(0x40C0A060)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'DICE COLLECTION',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              color: GameColors.uiMuted,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
                childAspectRatio: 1.0,
              ),
              itemCount: player.dice.length,
              itemBuilder: (context, index) =>
                  _buildDiceTile(player.dice[index], index),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiceTile(DiceItem die, int index) {
    final isSelected = _selectedDieIndex == index;
    final rColor = _rarityColor(die.rarity);
    final bodyColor = _diceBodyColor(die);

    return GestureDetector(
      onTap: () => setState(() => _selectedDieIndex = index),
      child: AnimatedBuilder(
        animation: _shimmerController,
        builder: (context, child) {
          final shimmer = die.rarity == DiceRarity.legendary ||
                  die.rarity == DiceRarity.epic
              ? (0.3 + 0.2 * sin(_shimmerController.value * 2 * pi + index))
              : 0.0;

          return Container(
            decoration: BoxDecoration(
              color: isSelected
                  ? rColor.withValues(alpha: 0.3)
                  : const Color(0xFF1a1420),
              border: Border.all(
                color: isSelected ? rColor : rColor.withValues(alpha: 0.5),
                width: isSelected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                if (isSelected || shimmer > 0)
                  BoxShadow(
                    color: rColor.withValues(
                        alpha: isSelected ? 0.5 : shimmer),
                    blurRadius: isSelected ? 8 : 6,
                  ),
              ],
            ),
            child: CustomPaint(
              painter: MiniMaterialDiePainter(
                material: die.material,
                enchantment: die.enchantment,
                value: (index % 6) + 1,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailPanel(PlayerData player) {
    final die = _selectedDieIndex != null &&
            _selectedDieIndex! < player.dice.length
        ? player.dice[_selectedDieIndex!]
        : null;

    return Container(
      margin: const EdgeInsets.only(right: 16, bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0x30201818),
        border: Border.all(color: const Color(0x40C0A060)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: die == null
          ? const Center(
              child: Text(
                'Select a die\nto view details',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  color: GameColors.uiMuted,
                ),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Large die preview
                SizedBox(
                  width: 64,
                  height: 64,
                  child: CustomPaint(
                    painter: MiniMaterialDiePainter(
                      material: die.material,
                      enchantment: die.enchantment,
                      value: 6,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Name
                Text(
                  die.name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: _rarityColor(die.rarity),
                  ),
                ),
                const SizedBox(height: 4),
                // Rarity badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _rarityColor(die.rarity).withValues(alpha: 0.2),
                    border: Border.all(
                        color:
                            _rarityColor(die.rarity).withValues(alpha: 0.6)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _rarityLabel(die.rarity),
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: _rarityColor(die.rarity),
                      letterSpacing: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Description
                Text(
                  die.description,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: GameColors.uiText,
                    height: 1.5,
                  ),
                ),
                const Spacer(),
                // Count owned
                Text(
                  'Owned: ${widget.player.dice.where((d) => d.type == die.type).length}',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: GameColors.uiMuted,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: GameColors.uiBorder, width: 2),
        ),
      ),
      child: Row(
        children: [
          const Text(
            'Click a die to inspect  •  Press I or ESC to close',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 10,
              color: GameColors.uiMuted,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: widget.onClose,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(color: GameColors.uiBorder, width: 2),
                borderRadius: BorderRadius.circular(2),
                color: const Color(0xFF2a1a00),
              ),
              child: const Text(
                'CLOSE',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: GameColors.uiHighlight,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabBtn(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: active ? GameColors.uiHighlight.withOpacity(0.15) : Colors.transparent,
          border: Border.all(color: active ? GameColors.uiHighlight : GameColors.uiMuted),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(label, style: TextStyle(fontFamily: 'monospace', fontSize: 10,
          fontWeight: FontWeight.bold,
          color: active ? GameColors.uiHighlight : GameColors.uiMuted)),
      ),
    );
  }

  Widget _buildLoadoutTab(PlayerData player) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text('Your Loadouts', style: TextStyle(fontFamily: 'monospace',
              fontSize: 13, fontWeight: FontWeight.bold, color: GameColors.uiText)),
            const Spacer(),
            if (player.loadouts.length < 5)
              GestureDetector(
                onTap: () {
                  setState(() {
                    final indices = List.generate(min(6, player.dice.length), (i) => i);
                    player.loadouts.add(DiceLoadout(
                      name: 'Loadout ${player.loadouts.length + 1}',
                      diceIndices: indices,
                    ));
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    border: Border.all(color: GameColors.uiSuccess),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('+ NEW', style: TextStyle(fontFamily: 'monospace',
                    fontSize: 9, fontWeight: FontWeight.bold, color: GameColors.uiSuccess)),
                ),
              ),
          ]),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: player.loadouts.length,
              itemBuilder: (ctx, loadoutIdx) {
                final loadout = player.loadouts[loadoutIdx];
                final isActive = loadoutIdx == player.activeLoadoutIndex;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isActive
                        ? GameColors.uiHighlight.withOpacity(0.08)
                        : const Color(0xFF141018),
                    border: Border.all(
                      color: isActive ? GameColors.uiHighlight : const Color(0xFF3a3a3a),
                      width: isActive ? 2 : 1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        if (isActive)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: GameColors.uiHighlight.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: const Text('ACTIVE', style: TextStyle(fontFamily: 'monospace',
                              fontSize: 7, fontWeight: FontWeight.bold, color: GameColors.uiHighlight)),
                          ),
                        Text(loadout.name, style: const TextStyle(fontFamily: 'monospace',
                          fontSize: 12, fontWeight: FontWeight.bold, color: GameColors.uiText)),
                        const Spacer(),
                        if (!isActive)
                          GestureDetector(
                            onTap: () => setState(() => player.activeLoadoutIndex = loadoutIdx),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                border: Border.all(color: GameColors.uiHighlight.withOpacity(0.5)),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: const Text('SET ACTIVE', style: TextStyle(fontFamily: 'monospace',
                                fontSize: 8, color: GameColors.uiHighlight)),
                            ),
                          ),
                        if (!isActive && loadoutIdx > 0)
                          GestureDetector(
                            onTap: () => setState(() {
                              player.loadouts.removeAt(loadoutIdx);
                              if (player.activeLoadoutIndex >= player.loadouts.length) {
                                player.activeLoadoutIndex = 0;
                              }
                            }),
                            child: const Padding(
                              padding: EdgeInsets.only(left: 8),
                              child: Text('DEL', style: TextStyle(fontFamily: 'monospace',
                                fontSize: 8, color: GameColors.uiDanger)),
                            ),
                          ),
                      ]),
                      const SizedBox(height: 6),
                      // 6 dice slots
                      Row(
                        children: List.generate(6, (slotIdx) {
                          final dieIdx = slotIdx < loadout.diceIndices.length
                              ? loadout.diceIndices[slotIdx] : -1;
                          final die = dieIdx >= 0 && dieIdx < player.dice.length
                              ? player.dice[dieIdx] : null;
                          return Expanded(child: Container(
                            height: 36, margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0a0804),
                              border: Border.all(
                                color: die != null
                                    ? TierColors.forTier(die.tier).withOpacity(0.4)
                                    : const Color(0xFF2a2a2a)),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: die != null
                                ? CustomPaint(painter: MiniMaterialDiePainter(
                                    value: (slotIdx % 6) + 1,
                                    material: die.material,
                                    enchantment: die.enchantment))
                                : const Center(child: Text('-', style: TextStyle(
                                    color: GameColors.uiMuted, fontSize: 10))),
                          ));
                        }),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const Text('Press Q/Tab in overworld to cycle loadouts',
            style: TextStyle(fontFamily: 'monospace', fontSize: 9, color: GameColors.uiMuted)),
        ],
      ),
    );
  }
}

/// Paints a simple die icon with face value dots.
class _DiceIconPainter extends CustomPainter {
  final Color bodyColor;
  final Color dotColor;
  final int value;

  _DiceIconPainter({
    required this.bodyColor,
    required this.dotColor,
    required this.value,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final rect = Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2), width: s * 0.8, height: s * 0.8);

    // Body
    final bodyPaint = Paint()..color = bodyColor;
    canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(s * 0.12)), bodyPaint);

    // Border
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(s * 0.12)), borderPaint);

    // Dots
    final dotPaint = Paint()..color = dotColor;
    final dr = s * 0.07; // dot radius
    final cx = rect.center.dx;
    final cy = rect.center.dy;
    final off = s * 0.2;

    // Dot positions for each value
    if (value == 1 || value == 3 || value == 5) {
      canvas.drawCircle(Offset(cx, cy), dr, dotPaint); // center
    }
    if (value >= 2) {
      canvas.drawCircle(Offset(cx - off, cy - off), dr, dotPaint); // top-left
      canvas.drawCircle(Offset(cx + off, cy + off), dr, dotPaint); // bot-right
    }
    if (value >= 4) {
      canvas.drawCircle(Offset(cx + off, cy - off), dr, dotPaint); // top-right
      canvas.drawCircle(Offset(cx - off, cy + off), dr, dotPaint); // bot-left
    }
    if (value == 6) {
      canvas.drawCircle(Offset(cx - off, cy), dr, dotPaint); // mid-left
      canvas.drawCircle(Offset(cx + off, cy), dr, dotPaint); // mid-right
    }
  }

  @override
  bool shouldRepaint(covariant _DiceIconPainter old) =>
      old.value != value || old.bodyColor != bodyColor;
}
