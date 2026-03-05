import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fark_my_life/core/constants.dart';
import 'package:fark_my_life/core/enums.dart';
import 'package:fark_my_life/models/models.dart';
import 'package:fark_my_life/models/dice_tiers.dart';

// ═══════════════════════════════════════════════════════════════════════
// MATERIAL DIE WIDGET
// ═══════════════════════════════════════════════════════════════════════

/// A 60×60 die widget that renders based on DiceMaterial + Enchantment.
/// Replaces the old _BirchDie for all material types.
class MaterialDie extends StatelessWidget {
  final FarkleDie die;
  final bool rolling;
  final VoidCallback? onTap;
  final bool isInactive;
  final double gameTime;
  final bool isCursorTarget;

  const MaterialDie({
    super.key,
    required this.die,
    required this.rolling,
    this.onTap,
    this.isInactive = false,
    this.gameTime = 0,
    this.isCursorTarget = false,
  });

  @override
  Widget build(BuildContext context) {
    final isScored = die.held || die.locked;
    final isSelected = die.selected;
    const size = 60.0;
    final mat = die.item.material;
    final tier = die.item.tier;
    final ench = die.item.enchantment;

    // Border color priority: cursor > selected > material default
    Color borderColor = _borderColorFor(mat, isScored, false);
    final cornerRadius = _cornerRadiusFor(tier);
    double borderWidth = 2.0;

    if (isSelected && !isScored && !isInactive) {
      borderColor = const Color(0xFF44dd44); // green = "held/kept"
      borderWidth = 3.0;
    }
    if (isCursorTarget && !isScored && !isInactive) {
      borderColor = const Color(0xFF60e0ff); // cyan = "cursor here"
      borderWidth = 3.0;
    }

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: size,
            height: size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(cornerRadius),
              border: Border.all(color: borderColor, width: borderWidth),
              boxShadow: [
                if (!isScored && !isInactive) BoxShadow(
                  color: isSelected
                      ? const Color(0xFF44dd44).withOpacity(0.5)
                      : isCursorTarget
                          ? const Color(0xFF60e0ff).withOpacity(0.4)
                          : Colors.black.withOpacity(0.5),
                  blurRadius: (isSelected || isCursorTarget) ? 8 : 4,
                  offset: const Offset(1, 2),
                ),
                // Enchantment glow
                if (ench != null && !isScored && !isInactive)
                  BoxShadow(
                    color: EnchantmentColors.forEnchantment(ench)
                        .withOpacity(0.2 + 0.1 * sin(gameTime * 2.5)),
                    blurRadius: 6,
                  ),
                // Tier IV/V ambient glow
                if (DiceTiers.tierIndex(tier) >= 4 && !isScored && !isInactive)
                  BoxShadow(
                    color: TierColors.forTier(tier).withOpacity(0.15),
                    blurRadius: 8,
                  ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(cornerRadius - 2),
              child: Stack(
                children: [
                  SizedBox(
                    width: size,
                    height: size,
                    child: CustomPaint(
                      painter: MaterialDiePainter(
                        value: die.value,
                        material: mat,
                        enchantment: ench,
                        isScored: isScored,
                        isInactive: isInactive,
                        gameTime: gameTime,
                      ),
                    ),
                  ),
                  // Green tint overlay when selected (held for keeping)
                  if (isSelected && !isScored && !isInactive)
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF44dd44).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(cornerRadius - 2),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // "HOLD" badge on selected dice
          if (isSelected && !isScored && !isInactive)
            Positioned(
              bottom: 1, left: 0, right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFF44dd44),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: const Text('HOLD', style: TextStyle(
                    fontFamily: 'monospace', fontSize: 7,
                    fontWeight: FontWeight.w900, color: Color(0xFF0a2a0a),
                    height: 1.0,
                  )),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _borderColorFor(DiceMaterial mat, bool scored, bool selected) {
    if (selected) return GameColors.uiHighlight;
    if (scored) return const Color(0xFF5a5040);
    switch (DiceTiers.tierOf(mat)) {
      case DiceTier.common:    return const Color(0xFFC4A87A);
      case DiceTier.uncommon:  return const Color(0xFFb8a890);
      case DiceTier.rare:      return const Color(0xFF404850);
      case DiceTier.epic:      return const Color(0xFF8a6a10);
      case DiceTier.legendary: return const Color(0xFF80b0e0);
    }
  }

  double _cornerRadiusFor(DiceTier tier) {
    switch (tier) {
      case DiceTier.common:    return 6.0;
      case DiceTier.uncommon:  return 5.0;
      case DiceTier.rare:      return 4.0;
      case DiceTier.epic:      return 5.0;
      case DiceTier.legendary: return 6.0;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════
// MATERIAL DIE PAINTER
// ═══════════════════════════════════════════════════════════════════════

class MaterialDiePainter extends CustomPainter {
  final int value;
  final DiceMaterial material;
  final Enchantment? enchantment;
  final bool isScored;
  final bool isInactive;
  final double gameTime;

  MaterialDiePainter({
    required this.value,
    required this.material,
    this.enchantment,
    this.isScored = false,
    this.isInactive = false,
    this.gameTime = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (isScored || isInactive) {
      _paintScored(canvas, size);
      return;
    }

    // 1. Material body + surface effects
    switch (DiceTiers.tierOf(material)) {
      case DiceTier.common:    _paintWood(canvas, size); break;
      case DiceTier.uncommon:  _paintBoneStone(canvas, size); break;
      case DiceTier.rare:      _paintMetal(canvas, size); break;
      case DiceTier.epic:      _paintPrecious(canvas, size); break;
      case DiceTier.legendary: _paintLegendary(canvas, size); break;
    }

    // 2. Enchantment shimmer overlay (before pips)
    if (enchantment != null) {
      _paintShimmer(canvas, size);
    }

    // 3. Pips (on top of everything)
    _paintPips(canvas, size);

    // 4. Enchantment corner badge
    if (enchantment != null) {
      _paintEnchantmentBadge(canvas, size);
    }
  }

  // ── TIER I: WOOD ───────────────────────────────────────────────────

  void _paintWood(Canvas canvas, Size size) {
    final p = Paint();
    Color base, grainColor, pipColor;

    switch (material) {
      case DiceMaterial.birch:
        base = const Color(0xFFd4c4a0);
        grainColor = const Color(0xFFc0b088);
        pipColor = const Color(0xFF3a2008);
        break;
      case DiceMaterial.oak:
        base = const Color(0xFFa08050);
        grainColor = const Color(0xFF8a6a3a);
        pipColor = const Color(0xFF2a1a08);
        break;
      case DiceMaterial.mahogany:
        base = const Color(0xFF6a3a22);
        grainColor = const Color(0xFF501a0a);
        pipColor = const Color(0xFFd4a870);
        break;
      default:
        base = const Color(0xFFa08050);
        grainColor = const Color(0xFF8a6a3a);
        pipColor = const Color(0xFF2a1a08);
    }

    // Fill
    p.color = base;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), p);

    // Grain lines
    p..color = grainColor ..strokeWidth = material == DiceMaterial.mahogany ? 1.2 : 0.7
      ..style = PaintingStyle.stroke;
    final spacing = material == DiceMaterial.mahogany ? 6.5 : 5.5;
    for (double y = 3; y < size.height; y += spacing) {
      final path = Path()..moveTo(0, y);
      for (double x = 0; x < size.width; x += 6) {
        path.lineTo(x + 3, y + sin(x * 0.3 + y) * 0.8);
        path.lineTo(x + 6, y + sin(x * 0.3 + y + 1) * 0.5);
      }
      canvas.drawPath(path, p);
    }

    // Mahogany polish sheen
    if (material == DiceMaterial.mahogany) {
      p..color = Colors.white.withOpacity(0.08) ..style = PaintingStyle.fill;
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width * 0.6, size.height * 0.5), p);
    }
  }

  // ── TIER II: BONE / STONE ──────────────────────────────────────────

  void _paintBoneStone(Canvas canvas, Size size) {
    final p = Paint()..style = PaintingStyle.fill;
    final isBone = material == DiceMaterial.bone;

    // Base
    p.color = isBone ? const Color(0xFFe8dcc8) : const Color(0xFF8a8a88);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), p);

    // Speckle noise
    final rng = Random(material.index * 31 + value * 7);
    final speckleCount = isBone ? 18 : 25;
    for (int i = 0; i < speckleCount; i++) {
      final sx = rng.nextDouble() * size.width;
      final sy = rng.nextDouble() * size.height;
      final sr = 0.5 + rng.nextDouble() * 1.0;
      p.color = isBone
          ? Color.lerp(const Color(0xFFd0c4b0), const Color(0xFFc8b898), rng.nextDouble())!
          : Color.lerp(const Color(0xFF707068), const Color(0xFF9a9a98), rng.nextDouble())!;
      canvas.drawCircle(Offset(sx, sy), sr, p);
    }

    // Stone cracks
    if (!isBone) {
      p..color = const Color(0xFF606058).withOpacity(0.6) ..strokeWidth = 0.5
        ..style = PaintingStyle.stroke;
      for (int i = 0; i < 2; i++) {
        final cx = rng.nextDouble() * size.width;
        final cy = rng.nextDouble() * size.height;
        final angle = rng.nextDouble() * pi;
        final len = 6.0 + rng.nextDouble() * 8.0;
        canvas.drawLine(
          Offset(cx, cy),
          Offset(cx + cos(angle) * len, cy + sin(angle) * len),
          p,
        );
      }
      p.style = PaintingStyle.fill;
    }
  }

  // ── TIER III: IRON / BRONZE ────────────────────────────────────────

  void _paintMetal(Canvas canvas, Size size) {
    final isIron = material == DiceMaterial.iron;
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    // Metallic gradient
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: isIron
          ? [const Color(0xFF909aa0), const Color(0xFF586068)]
          : [const Color(0xFFd8a848), const Color(0xFF8a6828)],
    );
    canvas.drawRect(rect, Paint()..shader = gradient.createShader(rect));

    // Specular highlight band (slow drift)
    final bandY = size.height * (0.25 + 0.05 * sin(gameTime * 0.1));
    final highlightColor = isIron
        ? const Color(0xFFa0a8b0).withOpacity(0.3)
        : const Color(0xFFe8c868).withOpacity(0.35);
    final bandWidth = isIron ? 4.0 : 6.0;
    canvas.drawRect(
      Rect.fromLTWH(0, bandY, size.width, bandWidth),
      Paint()..color = highlightColor ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );

    // Scratches (iron only)
    if (isIron) {
      final rng = Random(value * 17);
      final p = Paint()..color = const Color(0xFF9098a0).withOpacity(0.25) ..strokeWidth = 0.5;
      for (int i = 0; i < 2; i++) {
        final sx = rng.nextDouble() * size.width;
        final sy = rng.nextDouble() * size.height;
        canvas.drawLine(Offset(sx, sy), Offset(sx + 6, sy + 3), p);
      }
    }
  }

  // ── TIER IV: GOLD / JADE ───────────────────────────────────────────

  void _paintPrecious(Canvas canvas, Size size) {
    final isGold = material == DiceMaterial.gold;
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Radial gradient with slowly oscillating center
    final centerDx = 2.0 * sin(gameTime * 0.4);
    final centerDy = 2.0 * cos(gameTime * 0.35);
    final center = Alignment(centerDx / size.width, centerDy / size.height);

    final gradient = RadialGradient(
      center: center,
      radius: 0.8,
      colors: isGold
          ? [const Color(0xFFfff0a0), const Color(0xFFd4a020)]
          : [const Color(0xFF60c878), const Color(0xFF2a7a38)],
    );
    canvas.drawRect(rect, Paint()..shader = gradient.createShader(rect));

    if (isGold) {
      // Sparkle points
      final rng = Random(value * 13);
      final sparkleP = Paint()..color = Colors.white.withOpacity(0.5);
      for (int i = 0; i < 3; i++) {
        final phase = gameTime * 0.8 + i * 2.1;
        final opacity = (0.3 + 0.3 * sin(phase)).clamp(0.0, 1.0);
        sparkleP.color = Colors.white.withOpacity(opacity);
        canvas.drawCircle(
          Offset(8.0 + rng.nextDouble() * (size.width - 16),
                 8.0 + rng.nextDouble() * (size.height - 16)),
          0.8, sparkleP,
        );
      }
    } else {
      // Jade cloud noise
      final rng = Random(value * 23);
      final cloudP = Paint()..color = const Color(0xFF40a858).withOpacity(0.15);
      for (int i = 0; i < 8; i++) {
        canvas.drawCircle(
          Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height),
          2.0 + rng.nextDouble() * 3.0, cloudP,
        );
      }
      // Drifting highlight
      final hlx = cx + 8 * cos(gameTime * 0.2);
      final hly = cy + 8 * sin(gameTime * 0.2);
      canvas.drawCircle(
        Offset(hlx, hly), 5,
        Paint()..color = const Color(0xFF80e8a0).withOpacity(0.18)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }
  }

  // ── TIER V: CRYSTAL / OBSIDIAN ─────────────────────────────────────

  void _paintLegendary(Canvas canvas, Size size) {
    final isCrystal = material == DiceMaterial.crystal;
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Semi-transparent base (felt shows through)
    final baseOpacity = isCrystal ? 0.7 : 0.85;
    final gradient = RadialGradient(
      center: Alignment.center,
      radius: 0.9,
      colors: isCrystal
          ? [Color.fromRGBO(208, 232, 255, baseOpacity), Color.fromRGBO(128, 176, 224, baseOpacity)]
          : [Color.fromRGBO(42, 24, 48, baseOpacity), Color.fromRGBO(10, 8, 16, baseOpacity)],
    );
    canvas.drawRect(rect, Paint()..shader = gradient.createShader(rect));

    // Inner glow (pulsating)
    final glowOpacity = isCrystal
        ? 0.25 + 0.1 * sin(gameTime * 1.5)
        : 0.15 + 0.08 * sin(gameTime * 1.0);
    final glowColor = isCrystal
        ? Color.fromRGBO(255, 255, 255, glowOpacity)
        : Color.fromRGBO(96, 48, 160, glowOpacity);
    final glowGradient = RadialGradient(
      center: Alignment.center,
      radius: 0.6,
      colors: [glowColor, Colors.transparent],
    );
    canvas.drawRect(rect, Paint()..shader = glowGradient.createShader(rect));

    // Refraction lines (crystal) / flow streaks (obsidian)
    final rng = Random(value * 37);
    final lineP = Paint()
      ..color = isCrystal
          ? Colors.white.withOpacity(0.12)
          : const Color(0xFF3a2040).withOpacity(0.08)
      ..strokeWidth = 0.8;
    for (int i = 0; i < 3; i++) {
      final sx = rng.nextDouble() * size.width;
      final sy = rng.nextDouble() * size.height;
      final angle = isCrystal ? pi * 0.25 + rng.nextDouble() * 0.3 : rng.nextDouble() * pi;
      final len = 10.0 + rng.nextDouble() * 15.0;
      canvas.drawLine(
        Offset(sx, sy),
        Offset(sx + cos(angle) * len, sy + sin(angle) * len),
        lineP,
      );
    }
  }

  // ── ENCHANTMENT SHIMMER ────────────────────────────────────────────

  void _paintShimmer(Canvas canvas, Size size) {
    if (enchantment == null) return;
    final ench = enchantment!;
    final enchColor = EnchantmentColors.forEnchantment(ench);
    final isActive = DiceTiers.isActiveEnchantment(ench);
    final tier = DiceTiers.tierOf(material);

    // Shimmer speed and intensity
    final speed = isActive ? 0.7 : 0.4;
    final maxOpacity = isActive ? 0.35 : 0.22;

    // Tier V uses radial pulse instead of diagonal sweep
    if (tier == DiceTier.legendary) {
      _paintRadialPulse(canvas, size, enchColor, maxOpacity);
      return;
    }

    // Diagonal sweep shimmer (Minecraft-style)
    final phase = (gameTime * speed) % 1.0;
    final bandCenter = -0.3 + phase * 1.6; // sweep from -0.3 to 1.3
    final bandWidth = tier == DiceTier.epic ? 0.35 : 0.25;

    // Tier III: perpendicular angle (135° instead of 45°)
    final usePerpendicular = tier == DiceTier.rare;

    // Build shimmer as gradient rect
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    for (double step = 0; step < 1.0; step += 0.02) {
      double nx, ny;
      if (usePerpendicular) {
        nx = step;
        ny = 1.0 - step;
      } else {
        nx = step;
        ny = step;
      }
      final diagPos = (nx + ny) / 2.0;
      final dist = (diagPos - bandCenter).abs();
      if (dist > bandWidth) continue;
      final alpha = (1.0 - dist / bandWidth) * maxOpacity;
      if (alpha < 0.01) continue;

      final stripW = size.width * 0.02;
      final stripX = step * size.width;
      canvas.drawRect(
        Rect.fromLTWH(stripX, 0, stripW, size.height),
        Paint()
          ..color = enchColor.withOpacity(alpha)
          ..blendMode = BlendMode.screen,
      );
    }
  }

  void _paintRadialPulse(Canvas canvas, Size size, Color enchColor, double maxOpacity) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final maxR = size.width * 0.7;
    final phase = (gameTime * 0.4) % 1.0;
    final r = maxR * phase;
    final opacity = maxOpacity * (1.0 - phase);
    if (opacity < 0.01) return;

    canvas.drawCircle(
      Offset(cx, cy), r,
      Paint()
        ..color = enchColor.withOpacity(opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
  }

  // ── PIPS ───────────────────────────────────────────────────────────

  void _paintPips(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.075;
    final off = size.width * 0.25;
    final tier = DiceTiers.tierOf(material);

    final positions = _pipPositions(cx, cy, off);

    switch (tier) {
      case DiceTier.common:    _drawBurnedPips(canvas, positions, r); break;
      case DiceTier.uncommon:  _drawCarvedPips(canvas, positions, r); break;
      case DiceTier.rare:      _drawRivetPips(canvas, positions, r); break;
      case DiceTier.epic:      _drawInlaidPips(canvas, positions, r); break;
      case DiceTier.legendary: _drawGlowingPips(canvas, positions, r); break;
    }
  }

  List<Offset> _pipPositions(double cx, double cy, double off) {
    switch (value) {
      case 1: return [Offset(cx, cy)];
      case 2: return [Offset(cx - off, cy - off), Offset(cx + off, cy + off)];
      case 3: return [Offset(cx - off, cy - off), Offset(cx, cy), Offset(cx + off, cy + off)];
      case 4: return [Offset(cx - off, cy - off), Offset(cx + off, cy - off),
                       Offset(cx - off, cy + off), Offset(cx + off, cy + off)];
      case 5: return [Offset(cx - off, cy - off), Offset(cx + off, cy - off), Offset(cx, cy),
                       Offset(cx - off, cy + off), Offset(cx + off, cy + off)];
      case 6: return [Offset(cx - off, cy - off), Offset(cx + off, cy - off),
                       Offset(cx - off, cy), Offset(cx + off, cy),
                       Offset(cx - off, cy + off), Offset(cx + off, cy + off)];
      default: return [Offset(cx, cy)];
    }
  }

  // Tier I: Burned brand marks with char halo
  void _drawBurnedPips(Canvas canvas, List<Offset> positions, double r) {
    final isDark = material == DiceMaterial.mahogany;
    final pipColor = isDark ? const Color(0xFFd4a870) : const Color(0xFF3a2008);
    final haloColor = isDark
        ? const Color(0xFFb08850).withOpacity(0.5)
        : const Color(0xFF5a3a10).withOpacity(0.5);

    final haloP = Paint()..color = haloColor ..style = PaintingStyle.stroke ..strokeWidth = 1.5;
    final pipP = Paint()..color = pipColor;

    for (final p in positions) {
      canvas.drawCircle(p, r + 1.5, haloP);
      canvas.drawCircle(p, r, pipP);
    }
  }

  // Tier II: Carved with inner shadow
  void _drawCarvedPips(Canvas canvas, List<Offset> positions, double r) {
    final isBone = material == DiceMaterial.bone;
    final pipColor = isBone ? const Color(0xFF4a3a28) : const Color(0xFF3a3a38);
    final shadowColor = isBone ? const Color(0xFF2a1a08) : const Color(0xFF1a1a18);
    final highlightColor = isBone ? Colors.transparent : const Color(0xFFa0a098).withOpacity(0.6);

    for (final p in positions) {
      // Shadow (offset down-right)
      canvas.drawCircle(Offset(p.dx + 0.5, p.dy + 0.5), r,
        Paint()..color = shadowColor);
      // Main pip
      canvas.drawCircle(p, r, Paint()..color = pipColor);
      // Highlight (top-left, stone only)
      if (!isBone) {
        canvas.drawCircle(Offset(p.dx - 0.5, p.dy - 0.5), r * 0.4,
          Paint()..color = highlightColor);
      }
    }
  }

  // Tier III: Stamped rivets with specular dot
  void _drawRivetPips(Canvas canvas, List<Offset> positions, double r) {
    final isIron = material == DiceMaterial.iron;
    final outerColor = isIron ? const Color(0xFF404850) : const Color(0xFF6a4818);
    final innerColor = isIron ? const Color(0xFF6a7078) : const Color(0xFF9a7838);
    final specColor = isIron ? const Color(0xFFc0c8d0) : const Color(0xFFe8d088);

    for (final p in positions) {
      canvas.drawCircle(p, r + 0.5, Paint()..color = outerColor);
      canvas.drawCircle(p, r, Paint()..color = innerColor);
      canvas.drawCircle(Offset(p.dx - r * 0.3, p.dy - r * 0.3), r * 0.25,
        Paint()..color = specColor);
    }
  }

  // Tier IV: Inlaid contrasting metal
  void _drawInlaidPips(Canvas canvas, List<Offset> positions, double r) {
    final isGold = material == DiceMaterial.gold;
    final pipColor = isGold ? const Color(0xFFc0c8d0) : const Color(0xFFd4a830);
    final outlineColor = isGold ? const Color(0xFF8a7020) : const Color(0xFF1a5a28);
    final specColor = Colors.white;

    for (final p in positions) {
      canvas.drawCircle(p, r + 0.5,
        Paint()..color = outlineColor ..style = PaintingStyle.stroke ..strokeWidth = 0.5);
      canvas.drawCircle(p, r, Paint()..color = pipColor);
      canvas.drawCircle(Offset(p.dx - r * 0.25, p.dy - r * 0.25), r * 0.2,
        Paint()..color = specColor.withOpacity(0.6));
    }
  }

  // Tier V: Glowing bloom pips
  void _drawGlowingPips(Canvas canvas, List<Offset> positions, double r) {
    final isCrystal = material == DiceMaterial.crystal;
    final glowColor = isCrystal ? const Color(0xFFffffff) : const Color(0xFFa060e0);
    final centerColor = isCrystal ? const Color(0xFFd0e8ff) : const Color(0xFFd0a0ff);

    for (final p in positions) {
      // Bloom glow
      canvas.drawCircle(p, r + 2,
        Paint()..color = glowColor.withOpacity(0.5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
      // Sharp center
      canvas.drawCircle(p, r * 0.6, Paint()..color = centerColor);
    }
  }

  // ── SCORED/INACTIVE STATE ──────────────────────────────────────────

  void _paintScored(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF9A8668));

    // Faded grain lines
    final grainP = Paint()
      ..color = const Color(0xFF7A6848) ..strokeWidth = 0.5 ..style = PaintingStyle.stroke;
    for (double y = 4; y < size.height; y += 6) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grainP);
    }

    // Dim pips
    final cx = size.width / 2, cy = size.height / 2;
    final r = size.width * 0.075, off = size.width * 0.25;
    final positions = _pipPositions(cx, cy, off);
    final pipP = Paint()..color = const Color(0xFF5A4030);
    for (final p in positions) {
      canvas.drawCircle(p, r, pipP);
    }
  }

  // ── ENCHANTMENT BADGE ──────────────────────────────────────────────

  void _paintEnchantmentBadge(Canvas canvas, Size size) {
    if (enchantment == null) return;
    final color = EnchantmentColors.forEnchantment(enchantment!);
    final isActive = DiceTiers.isActiveEnchantment(enchantment!);

    final bx = size.width - 7;
    final by = 5.0;

    // Outline
    canvas.drawCircle(Offset(bx, by), 4,
      Paint()..color = const Color(0xFF0a0804) ..style = PaintingStyle.stroke ..strokeWidth = 1.5);
    // Fill
    canvas.drawCircle(Offset(bx, by), 3, Paint()..color = color.withOpacity(0.85));

    // Active: tiny lightning bolt shape
    if (isActive) {
      final bp = Paint()..color = Colors.white ..strokeWidth = 0.8 ..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(bx - 1, by - 2), Offset(bx + 0.5, by), bp);
      canvas.drawLine(Offset(bx + 0.5, by), Offset(bx - 0.5, by), bp);
      canvas.drawLine(Offset(bx - 0.5, by), Offset(bx + 1, by + 2), bp);
    }
  }

  @override
  bool shouldRepaint(covariant MaterialDiePainter old) =>
    old.value != value || old.material != material || old.enchantment != enchantment ||
    old.isScored != isScored || old.isInactive != isInactive ||
    (old.gameTime - gameTime).abs() > 0.05; // repaint ~20fps for animations
}

// ═══════════════════════════════════════════════════════════════════════
// MINI DIE (28px) for inventory / action bar
// ═══════════════════════════════════════════════════════════════════════

class MiniMaterialDiePainter extends CustomPainter {
  final int value;
  final DiceMaterial material;
  final Enchantment? enchantment;
  final double gameTime;

  MiniMaterialDiePainter({
    required this.value,
    required this.material,
    this.enchantment,
    this.gameTime = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final tier = DiceTiers.tierOf(material);
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final p = Paint();

    // Simplified body color per material
    p.color = _bodyColor();
    canvas.drawRect(rect, p);

    // Tier V: slight transparency
    if (tier == DiceTier.legendary) {
      p.color = _bodyColor().withOpacity(0.8);
      canvas.drawRect(rect, p);
    }

    // Simple shimmer for enchanted (stepping, every 4th frame)
    if (enchantment != null) {
      final phase = ((gameTime * 0.4).floor() % 20) / 20.0;
      final bandCenter = -0.3 + phase * 1.6;
      final enchColor = EnchantmentColors.forEnchantment(enchantment!);
      for (double step = 0; step < 1.0; step += 0.05) {
        final diagPos = step;
        final dist = (diagPos - bandCenter).abs();
        if (dist > 0.4) continue;
        final alpha = (1.0 - dist / 0.4) * 0.25;
        canvas.drawRect(
          Rect.fromLTWH(step * size.width, 0, size.width * 0.05, size.height),
          Paint()..color = enchColor.withOpacity(alpha) ..blendMode = BlendMode.screen,
        );
      }
    }

    // Mini pips
    final cx = size.width / 2, cy = size.height / 2;
    final r = size.width * 0.08;
    final off = size.width * 0.23;
    final pipP = Paint()..color = _pipColor();

    final positions = <Offset>[];
    switch (value) {
      case 1: positions.add(Offset(cx, cy)); break;
      case 2: positions.addAll([Offset(cx - off, cy - off), Offset(cx + off, cy + off)]); break;
      case 3: positions.addAll([Offset(cx - off, cy - off), Offset(cx, cy), Offset(cx + off, cy + off)]); break;
      case 4: positions.addAll([Offset(cx - off, cy - off), Offset(cx + off, cy - off),
                                Offset(cx - off, cy + off), Offset(cx + off, cy + off)]); break;
      case 5: positions.addAll([Offset(cx - off, cy - off), Offset(cx + off, cy - off), Offset(cx, cy),
                                Offset(cx - off, cy + off), Offset(cx + off, cy + off)]); break;
      case 6: positions.addAll([Offset(cx - off, cy - off), Offset(cx + off, cy - off),
                                Offset(cx - off, cy), Offset(cx + off, cy),
                                Offset(cx - off, cy + off), Offset(cx + off, cy + off)]); break;
    }
    for (final pos in positions) {
      if (tier == DiceTier.legendary) {
        canvas.drawCircle(pos, r + 1, Paint()..color = pipP.color.withOpacity(0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5));
      }
      canvas.drawCircle(pos, r, pipP);
    }

    // Enchantment badge (3px)
    if (enchantment != null) {
      final enchColor = EnchantmentColors.forEnchantment(enchantment!);
      canvas.drawCircle(Offset(size.width - 4, 3), 2.5,
        Paint()..color = const Color(0xFF0a0804));
      canvas.drawCircle(Offset(size.width - 4, 3), 1.8,
        Paint()..color = enchColor.withOpacity(0.85));
    }

    // Tier color border
    final borderP = Paint()
      ..color = TierColors.forTier(tier).withOpacity(0.5)
      ..style = PaintingStyle.stroke ..strokeWidth = 1;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(0.5), const Radius.circular(3)),
      borderP,
    );
  }

  Color _bodyColor() {
    switch (material) {
      case DiceMaterial.birch:    return const Color(0xFFd4c4a0);
      case DiceMaterial.oak:      return const Color(0xFFa08050);
      case DiceMaterial.mahogany: return const Color(0xFF6a3a22);
      case DiceMaterial.bone:     return const Color(0xFFe8dcc8);
      case DiceMaterial.stone:    return const Color(0xFF8a8a88);
      case DiceMaterial.iron:     return const Color(0xFF808890);
      case DiceMaterial.bronze:   return const Color(0xFFc89848);
      case DiceMaterial.gold:     return const Color(0xFFe8c040);
      case DiceMaterial.jade:     return const Color(0xFF40a858);
      case DiceMaterial.crystal:  return const Color(0xFFb0d8f0);
      case DiceMaterial.obsidian: return const Color(0xFF2a1830);
    }
  }

  Color _pipColor() {
    switch (material) {
      case DiceMaterial.birch:
      case DiceMaterial.oak:      return const Color(0xFF2a1808);
      case DiceMaterial.mahogany: return const Color(0xFFd4a870);
      case DiceMaterial.bone:
      case DiceMaterial.gold:
      case DiceMaterial.crystal:  return Colors.black;
      case DiceMaterial.stone:
      case DiceMaterial.iron:
      case DiceMaterial.bronze:
      case DiceMaterial.jade:     return Colors.white;
      case DiceMaterial.obsidian: return const Color(0xFFa060e0);
    }
  }

  @override
  bool shouldRepaint(covariant MiniMaterialDiePainter old) =>
    old.value != value || old.material != material || old.enchantment != enchantment ||
    (old.gameTime - gameTime).abs() > 0.2;
}
