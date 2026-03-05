import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fark_my_life/core/constants.dart';
import 'package:fark_my_life/core/enums.dart';

/// Draws 16×16 scaled pixel-art character sprites.
class SpriteRenderer {
  SpriteRenderer._();

  static const double _ts = GameConstants.scaledTile;
  static const double _px = GameConstants.scaleFactor; // pixel scale

  /// Draw a character sprite at screen position (sx, sy).
  /// [bodyColor] and [accentColor] define the character's outfit.
  /// [skinColor] for face/hands.
  /// [facing] determines which direction sprite faces.
  /// [animFrame] 0 or 1 for walk cycle.
  /// [isPlayer] adds a subtle indicator.
  static void drawCharacter(
    Canvas canvas,
    double sx,
    double sy, {
    required Color bodyColor,
    required Color accentColor,
    Color skinColor = const Color(0xFFe0b080),
    Color hairColor = const Color(0xFF503020),
    Direction facing = Direction.down,
    int animFrame = 0,
    bool isPlayer = false,
    bool isSeated = false,
    String? nameTag,
  }) {
    final p = Paint()..style = PaintingStyle.fill;

    // No bob when seated
    final bob = (!isSeated && animFrame == 1) ? -_px : 0.0;
    final armSwing = (!isSeated && animFrame == 1) ? 2 * _px : 0.0;

    // When seated, shift up slightly to look like sitting on chair
    final seatOffset = isSeated ? 3 * _px : 0.0;

    // Shadow (smaller when seated)
    p.color = const Color(0x40000000);
    if (!isSeated) {
      canvas.drawOval(
        Rect.fromLTWH(sx + 4 * _px, sy + 14 * _px, 8 * _px, 3 * _px),
        p,
      );
    }

    final drawFrame = isSeated ? 0 : animFrame;
    final drawArmSwing = isSeated ? 0.0 : armSwing;

    switch (facing) {
      case Direction.down:
      case Direction.idle:
        _drawFacingDown(canvas, sx, sy + bob + seatOffset, p, bodyColor, accentColor,
            skinColor, hairColor, drawFrame, drawArmSwing);
        break;
      case Direction.up:
        _drawFacingUp(canvas, sx, sy + bob + seatOffset, p, bodyColor, accentColor,
            skinColor, hairColor, drawFrame, drawArmSwing);
        break;
      case Direction.left:
        _drawFacingSide(canvas, sx, sy + bob + seatOffset, p, bodyColor, accentColor,
            skinColor, hairColor, drawFrame, true);
        break;
      case Direction.right:
        _drawFacingSide(canvas, sx, sy + bob + seatOffset, p, bodyColor, accentColor,
            skinColor, hairColor, drawFrame, false);
        break;
    }

    // Player indicator (small arrow above head)
    if (isPlayer) {
      p.color = GameColors.uiHighlight;
      canvas.drawRect(
        Rect.fromLTWH(sx + 7 * _px, sy - 4 * _px + bob, 2 * _px, 3 * _px),
        p,
      );
      canvas.drawRect(
        Rect.fromLTWH(sx + 6 * _px, sy - 2 * _px + bob, 4 * _px, _px),
        p,
      );
    }

    // Name tag
    if (nameTag != null) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: nameTag,
          style: TextStyle(
            color: GameColors.uiText,
            fontSize: 9,
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
            shadows: const [
              Shadow(offset: Offset(1, 1), color: Colors.black),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(
          sx + (_ts - textPainter.width) / 2,
          sy - 10 * _px + bob,
        ),
      );
    }
  }

  static void _drawFacingDown(Canvas c, double sx, double sy, Paint p,
      Color body, Color accent, Color skin, Color hair, int frame, double arm) {
    // Hair / hat
    p.color = hair;
    c.drawRect(Rect.fromLTWH(sx + 4 * _px, sy, 8 * _px, 4 * _px), p);

    // Face
    p.color = skin;
    c.drawRect(
        Rect.fromLTWH(sx + 4 * _px, sy + 3 * _px, 8 * _px, 4 * _px), p);

    // Eyes
    p.color = const Color(0xFF202020);
    c.drawRect(
        Rect.fromLTWH(sx + 5 * _px, sy + 4 * _px, 2 * _px, 2 * _px), p);
    c.drawRect(
        Rect.fromLTWH(sx + 9 * _px, sy + 4 * _px, 2 * _px, 2 * _px), p);

    // Body (tunic/shirt)
    p.color = body;
    c.drawRect(
        Rect.fromLTWH(sx + 3 * _px, sy + 7 * _px, 10 * _px, 5 * _px), p);

    // Belt / accent
    p.color = accent;
    c.drawRect(
        Rect.fromLTWH(sx + 3 * _px, sy + 10 * _px, 10 * _px, 2 * _px), p);

    // Arms
    p.color = body;
    c.drawRect(Rect.fromLTWH(
        sx + 1 * _px, sy + (7 + arm / _px) * _px, 2 * _px, 4 * _px), p);
    c.drawRect(Rect.fromLTWH(
        sx + 13 * _px, sy + (7 - arm / _px) * _px, 2 * _px, 4 * _px), p);

    // Hands
    p.color = skin;
    c.drawRect(Rect.fromLTWH(
        sx + 1 * _px, sy + (11 + arm / _px) * _px, 2 * _px, 2 * _px), p);
    c.drawRect(Rect.fromLTWH(
        sx + 13 * _px, sy + (11 - arm / _px) * _px, 2 * _px, 2 * _px), p);

    // Legs
    p.color = accent;
    final legOffset = frame == 1 ? _px : 0.0;
    c.drawRect(Rect.fromLTWH(
        sx + 4 * _px, sy + 12 * _px, 3 * _px, 3 * _px + legOffset), p);
    c.drawRect(Rect.fromLTWH(
        sx + 9 * _px, sy + 12 * _px, 3 * _px, 3 * _px - legOffset + _px), p);

    // Boots
    p.color = const Color(0xFF403020);
    c.drawRect(
        Rect.fromLTWH(sx + 4 * _px, sy + 14 * _px + legOffset, 3 * _px, 2 * _px),
        p);
    c.drawRect(
        Rect.fromLTWH(sx + 9 * _px, sy + 14 * _px - legOffset + _px, 3 * _px, 2 * _px),
        p);
  }

  static void _drawFacingUp(Canvas c, double sx, double sy, Paint p,
      Color body, Color accent, Color skin, Color hair, int frame, double arm) {
    // Hair (back of head)
    p.color = hair;
    c.drawRect(
        Rect.fromLTWH(sx + 4 * _px, sy, 8 * _px, 6 * _px), p);

    // Body
    p.color = body;
    c.drawRect(
        Rect.fromLTWH(sx + 3 * _px, sy + 7 * _px, 10 * _px, 5 * _px), p);

    // Belt
    p.color = accent;
    c.drawRect(
        Rect.fromLTWH(sx + 3 * _px, sy + 10 * _px, 10 * _px, 2 * _px), p);

    // Arms
    p.color = body;
    c.drawRect(Rect.fromLTWH(
        sx + 1 * _px, sy + (7 - arm / _px) * _px, 2 * _px, 4 * _px), p);
    c.drawRect(Rect.fromLTWH(
        sx + 13 * _px, sy + (7 + arm / _px) * _px, 2 * _px, 4 * _px), p);

    // Legs
    p.color = accent;
    final legOffset = frame == 1 ? _px : 0.0;
    c.drawRect(Rect.fromLTWH(
        sx + 4 * _px, sy + 12 * _px, 3 * _px, 3 * _px - legOffset + _px), p);
    c.drawRect(Rect.fromLTWH(
        sx + 9 * _px, sy + 12 * _px, 3 * _px, 3 * _px + legOffset), p);

    // Boots
    p.color = const Color(0xFF403020);
    c.drawRect(
        Rect.fromLTWH(sx + 4 * _px, sy + 14 * _px - legOffset + _px, 3 * _px, 2 * _px),
        p);
    c.drawRect(
        Rect.fromLTWH(sx + 9 * _px, sy + 14 * _px + legOffset, 3 * _px, 2 * _px),
        p);
  }

  static void _drawFacingSide(Canvas c, double sx, double sy, Paint p,
      Color body, Color accent, Color skin, Color hair, int frame, bool left) {
    final flip = left ? 0.0 : 0.0; // positioning handled by offset
    final baseX = left ? sx : sx;

    // Hair
    p.color = hair;
    c.drawRect(Rect.fromLTWH(baseX + 4 * _px, sy, 8 * _px, 4 * _px), p);

    // Face (side view - narrower)
    p.color = skin;
    c.drawRect(
        Rect.fromLTWH(baseX + (left ? 4 : 6) * _px, sy + 3 * _px, 6 * _px, 4 * _px),
        p);

    // Eye (single, on visible side)
    p.color = const Color(0xFF202020);
    c.drawRect(
        Rect.fromLTWH(
            baseX + (left ? 5 : 9) * _px, sy + 4 * _px, 2 * _px, 2 * _px),
        p);

    // Body
    p.color = body;
    c.drawRect(
        Rect.fromLTWH(baseX + 4 * _px, sy + 7 * _px, 8 * _px, 5 * _px), p);

    // Belt
    p.color = accent;
    c.drawRect(
        Rect.fromLTWH(baseX + 4 * _px, sy + 10 * _px, 8 * _px, 2 * _px), p);

    // Arm (visible one with swing)
    final armOff = frame == 1 ? 2 * _px : 0.0;
    p.color = body;
    c.drawRect(Rect.fromLTWH(
        baseX + (left ? 2 : 10) * _px, sy + 7 * _px + armOff, 2 * _px, 5 * _px),
        p);
    p.color = skin;
    c.drawRect(Rect.fromLTWH(
        baseX + (left ? 2 : 10) * _px, sy + 11 * _px + armOff, 2 * _px, 2 * _px),
        p);

    // Legs (walking animation)
    p.color = accent;
    final legF = frame == 1 ? _px : 0.0;
    c.drawRect(Rect.fromLTWH(
        baseX + 5 * _px, sy + 12 * _px, 3 * _px, 3 * _px + legF), p);
    c.drawRect(Rect.fromLTWH(
        baseX + 8 * _px, sy + 12 * _px, 3 * _px, 3 * _px - legF + _px), p);

    // Boots
    p.color = const Color(0xFF403020);
    c.drawRect(
        Rect.fromLTWH(baseX + 5 * _px, sy + 14 * _px + legF, 3 * _px, 2 * _px), p);
    c.drawRect(
        Rect.fromLTWH(baseX + 8 * _px, sy + 14 * _px - legF + _px, 3 * _px, 2 * _px),
        p);
  }
}
