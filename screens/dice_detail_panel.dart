import 'package:flutter/material.dart';
import 'package:fark_my_life/core/constants.dart';
import 'package:fark_my_life/models/models.dart';
import 'package:fark_my_life/models/dice_tiers.dart';
import 'package:fark_my_life/entities/dice_renderer.dart';

/// Rich dice detail panel showing name, face thumbnails with odds, and stats.
class DiceDetailPanel extends StatelessWidget {
  final DiceItem die;
  final int? price; // if in shop context
  final bool showBuyButton;
  final bool canAfford;
  final VoidCallback? onBuy;

  const DiceDetailPanel({
    super.key,
    required this.die,
    this.price,
    this.showBuyButton = false,
    this.canAfford = true,
    this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    final odds = DiceTiers.faceOdds(die.material);
    final tier = die.tier;
    final ench = die.enchantment;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0c0a14),
        border: Border.all(color: die.tierColor.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Name + tier badge ──
          Row(children: [
            Expanded(child: Text(die.name, style: TextStyle(
              fontFamily: 'monospace', fontSize: 14,
              fontWeight: FontWeight.bold, color: die.tierColor))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: die.tierColor.withOpacity(0.15),
                border: Border.all(color: die.tierColor.withOpacity(0.4)),
                borderRadius: BorderRadius.circular(3)),
              child: Text(DiceTiers.tierLabel(tier).toUpperCase(),
                style: TextStyle(fontFamily: 'monospace', fontSize: 8,
                  fontWeight: FontWeight.bold, color: die.tierColor)),
            ),
          ]),
          const SizedBox(height: 4),
          // Material subtitle
          Text('${DiceTiers.materialName(die.material)} · Tier ${DiceTiers.tierLabel(tier)}',
            style: const TextStyle(fontFamily: 'monospace', fontSize: 9,
              color: Color(0xFF8a7a60))),

          const SizedBox(height: 10),
          // ── Large die preview ──
          Center(child: SizedBox(
            width: 56, height: 56,
            child: CustomPaint(painter: MiniMaterialDiePainter(
              value: 6, material: die.material, enchantment: ench)),
          )),

          const SizedBox(height: 10),
          // ── Face odds grid: 6 mini dice with % ──
          Text('FACE ODDS', style: TextStyle(fontFamily: 'monospace', fontSize: 9,
            fontWeight: FontWeight.bold, color: const Color(0xFFc0a040))),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(6, (i) {
              final faceValue = i + 1;
              final pct = odds[i];
              final isWeighted = (pct - 16.667).abs() > 0.1;
              return Column(mainAxisSize: MainAxisSize.min, children: [
                // Mini die showing this face
                Container(
                  width: 24, height: 24,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isWeighted
                          ? (pct > 16.667 ? GameColors.uiSuccess : GameColors.uiDanger)
                          : const Color(0xFF3a3a3a),
                      width: isWeighted ? 1.5 : 0.5),
                    borderRadius: BorderRadius.circular(2)),
                  child: CustomPaint(painter: MiniMaterialDiePainter(
                    value: faceValue, material: die.material)),
                ),
                const SizedBox(height: 2),
                Text('${pct.toStringAsFixed(1)}%', style: TextStyle(
                  fontFamily: 'monospace', fontSize: 7,
                  fontWeight: isWeighted ? FontWeight.bold : FontWeight.normal,
                  color: isWeighted
                      ? (pct > 16.667 ? GameColors.uiSuccess : const Color(0xFF8a7a60))
                      : const Color(0xFF6a5a40))),
              ]);
            }),
          ),

          const SizedBox(height: 10),
          // ── Material stat ──
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF141010),
              borderRadius: BorderRadius.circular(4)),
            child: Text(DiceTiers.materialStatDesc(die.material),
              style: TextStyle(fontFamily: 'monospace', fontSize: 9,
                color: die.tierColor.withOpacity(0.8))),
          ),

          // ── Enchantment ──
          if (ench != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: EnchantmentColors.forEnchantment(ench).withOpacity(0.08),
                border: Border.all(color: EnchantmentColors.forEnchantment(ench).withOpacity(0.3)),
                borderRadius: BorderRadius.circular(4)),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(DiceTiers.isActiveEnchantment(ench) ? '⚡' : '✦ ',
                  style: const TextStyle(fontSize: 10)),
                const SizedBox(width: 4),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(DiceTiers.enchantmentName(ench),
                      style: TextStyle(fontFamily: 'monospace', fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: EnchantmentColors.forEnchantment(ench))),
                    Text(DiceTiers.enchantmentDesc(ench),
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 8,
                        color: Color(0xFFa09080))),
                  ],
                )),
              ]),
            ),
          ],

          // ── Score modifiers (if any) ──
          if (tier == DiceTier.epic) ...[
            const SizedBox(height: 6),
            _scoreMod('Single 1', '110 pts', '(+10)'),
            _scoreMod('Single 5', '55 pts', '(+5)'),
          ],
          if (tier == DiceTier.legendary) ...[
            const SizedBox(height: 6),
            _scoreMod('Triples', '+25 bonus', ''),
          ],

          // ── Buy button (shop context) ──
          if (showBuyButton && price != null) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: canAfford ? onBuy : null,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: canAfford ? const Color(0xFF1a3a1a) : const Color(0xFF1a1a1a),
                  border: Border.all(
                    color: canAfford ? GameColors.uiSuccess : const Color(0xFF3a3a3a)),
                  borderRadius: BorderRadius.circular(4)),
                child: Center(child: Text(
                  canAfford ? 'BUY ${price}g' : 'NOT ENOUGH GOLD (${price}g)',
                  style: TextStyle(fontFamily: 'monospace', fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: canAfford ? GameColors.uiSuccess : GameColors.uiMuted))),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _scoreMod(String label, String value, String bonus) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(children: [
        Text(label, style: const TextStyle(fontFamily: 'monospace', fontSize: 8,
          color: Color(0xFF8a7a60))),
        const Spacer(),
        Text(value, style: TextStyle(fontFamily: 'monospace', fontSize: 8,
          color: die.tierColor)),
        if (bonus.isNotEmpty)
          Text(' $bonus', style: const TextStyle(fontFamily: 'monospace', fontSize: 7,
            color: Color(0xFF6a5a40))),
      ]),
    );
  }
}
