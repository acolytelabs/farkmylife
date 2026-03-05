import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:fark_my_life/core/constants.dart';
import 'package:fark_my_life/core/enums.dart';

/// Draws a single tile at pixel-art scale.
class TileRenderer {
  TileRenderer._();

  static const double _ts = GameConstants.scaledTile;
  static final _rng = Random(42); // deterministic for consistent decoration

  /// Draw a tile at screen position (sx, sy).
  static void drawTile(
    Canvas canvas,
    TileType type,
    double sx,
    double sy, {
    int tileX = 0,
    int tileY = 0,
    double time = 0,
  }) {
    final rect = Rect.fromLTWH(sx, sy, _ts, _ts);
    final paint = Paint()..style = PaintingStyle.fill;

    switch (type) {
      case TileType.grass:
        _drawGrass(canvas, rect, paint, tileX, tileY, false);
        break;
      case TileType.grassAlt:
        _drawGrass(canvas, rect, paint, tileX, tileY, true);
        break;
      case TileType.path:
        _drawPath(canvas, rect, paint, false);
        break;
      case TileType.pathAlt:
        _drawPath(canvas, rect, paint, true);
        break;
      case TileType.stone:
        _drawStone(canvas, rect, paint, false);
        break;
      case TileType.stoneAlt:
        _drawStone(canvas, rect, paint, true);
        break;
      case TileType.water:
        _drawWater(canvas, rect, paint, time);
        break;
      case TileType.wallNorth:
      case TileType.wallSouth:
      case TileType.wallEast:
      case TileType.wallWest:
        _drawWall(canvas, rect, paint, type);
        break;
      case TileType.wallCornerNE:
      case TileType.wallCornerNW:
      case TileType.wallCornerSE:
      case TileType.wallCornerSW:
        _drawWall(canvas, rect, paint, type);
        break;
      case TileType.roofRed:
        _drawRoof(canvas, rect, paint, GameColors.roofRed);
        break;
      case TileType.roofBrown:
        _drawRoof(canvas, rect, paint, GameColors.roofBrown);
        break;
      case TileType.door:
        _drawDoor(canvas, rect, paint);
        break;
      case TileType.window:
        _drawWindow(canvas, rect, paint);
        break;
      case TileType.tree:
        _drawTree(canvas, rect, paint, tileX, tileY);
        break;
      case TileType.bush:
        _drawBush(canvas, rect, paint);
        break;
      case TileType.flower:
        _drawFlower(canvas, rect, paint);
        break;
      case TileType.fence:
      case TileType.fencePost:
        _drawFence(canvas, rect, paint);
        break;
      case TileType.barrel:
        _drawBarrel(canvas, rect, paint);
        break;
      case TileType.crate:
        _drawCrate(canvas, rect, paint);
        break;
      case TileType.anvil:
        _drawAnvil(canvas, rect, paint);
        break;
      case TileType.well:
        _drawWell(canvas, rect, paint);
        break;
      case TileType.fountain:
        _drawFountain(canvas, rect, paint, time);
        break;
      case TileType.stall:
        _drawStall(canvas, rect, paint);
        break;
      case TileType.diceTable:
        _drawDiceTable(canvas, rect, paint);
        break;
      case TileType.chair:
        _drawChair(canvas, rect, paint);
        break;
      case TileType.counter:
        _drawCounter(canvas, rect, paint);
        break;
      case TileType.bed:
        _drawBed(canvas, rect, paint);
        break;
      case TileType.bookshelf:
        _drawBookshelf(canvas, rect, paint);
        break;
      case TileType.tournamentBoard:
        _drawTournamentBoard(canvas, rect, paint, time);
        break;
      case TileType.empty:
        paint.color = Colors.black;
        canvas.drawRect(rect, paint);
        break;
    }
  }

  // ── Terrain ──────────────────────────────────────────────────────

  static void _drawGrass(Canvas c, Rect r, Paint p, int tx, int ty, bool alt) {
    p.color = alt ? const Color(0xFF4a8a30) : GameColors.grassDark;
    c.drawRect(r, p);

    // Procedural grass tufts
    final seed = tx * 31 + ty * 17;
    if (seed % 5 == 0) {
      p.color = GameColors.grassLight;
      final px = r.left + (seed % 7) * _ts / 8;
      final py = r.top + ((seed ~/ 3) % 5) * _ts / 6;
      c.drawRect(Rect.fromLTWH(px, py, 3, 3), p);
    }
    if (alt) {
      // Crop rows
      p.color = const Color(0xFF6aaa40);
      for (int i = 0; i < 3; i++) {
        final cy = r.top + 6 + i * 14;
        c.drawRect(Rect.fromLTWH(r.left + 4, cy, _ts - 8, 4), p);
      }
    }
  }

  static void _drawPath(Canvas c, Rect r, Paint p, bool alt) {
    p.color = alt ? GameColors.pathDark : GameColors.pathLight;
    c.drawRect(r, p);
    // Subtle pebble detail
    p.color = alt ? GameColors.pathLight : GameColors.pathDark;
    c.drawRect(Rect.fromLTWH(r.left + 8, r.top + 6, 4, 4), p);
    c.drawRect(Rect.fromLTWH(r.left + 28, r.top + 24, 5, 4), p);
    c.drawRect(Rect.fromLTWH(r.left + 16, r.top + 34, 4, 3), p);
  }

  static void _drawStone(Canvas c, Rect r, Paint p, bool alt) {
    p.color = alt ? GameColors.stoneLight : GameColors.stoneDark;
    c.drawRect(r, p);
    // Grid lines
    p.color = const Color(0xFF505050);
    c.drawRect(Rect.fromLTWH(r.left, r.top + _ts / 2 - 1, _ts, 1), p);
    c.drawRect(Rect.fromLTWH(r.left + _ts / 2 - 1, r.top, 1, _ts), p);
  }

  static void _drawWater(Canvas c, Rect r, Paint p, double time) {
    p.color = GameColors.water;
    c.drawRect(r, p);
    // Animated ripple
    p.color = GameColors.waterHighlight;
    final wave = sin(time * 2 + r.left * 0.1) * 4;
    c.drawRect(
      Rect.fromLTWH(r.left + 8 + wave, r.top + 12, 16, 3),
      p,
    );
    c.drawRect(
      Rect.fromLTWH(r.left + 20 - wave, r.top + 28, 12, 3),
      p,
    );
  }

  // ── Structures ───────────────────────────────────────────────────

  static void _drawWall(Canvas c, Rect r, Paint p, TileType wallType) {
    p.color = GameColors.wallDark;
    c.drawRect(r, p);
    // Brick lines
    p.color = GameColors.wallLight;
    for (int i = 0; i < 3; i++) {
      final ly = r.top + 6 + i * 16;
      c.drawRect(Rect.fromLTWH(r.left, ly, _ts, 1), p);
    }
    // Vertical mortar offset per row
    c.drawRect(Rect.fromLTWH(r.left + 12, r.top, 1, 16), p);
    c.drawRect(Rect.fromLTWH(r.left + 30, r.top + 16, 1, 16), p);
    c.drawRect(Rect.fromLTWH(r.left + 18, r.top + 32, 1, 16), p);
  }

  static void _drawRoof(Canvas c, Rect r, Paint p, Color baseColor) {
    p.color = baseColor;
    c.drawRect(r, p);
    // Shingle lines
    p.color = baseColor.withOpacity(0.6);
    for (int i = 0; i < 4; i++) {
      c.drawRect(
        Rect.fromLTWH(r.left, r.top + i * 12, _ts, 2),
        p,
      );
    }
  }

  static void _drawDoor(Canvas c, Rect r, Paint p) {
    // Stone threshold
    p.color = GameColors.stoneDark;
    c.drawRect(r, p);
    // Door itself
    p.color = GameColors.doorColor;
    c.drawRect(
      Rect.fromLTWH(r.left + 8, r.top + 4, _ts - 16, _ts - 8),
      p,
    );
    // Handle
    p.color = GameColors.uiHighlight;
    c.drawRect(Rect.fromLTWH(r.left + 30, r.top + 22, 4, 4), p);
  }

  static void _drawWindow(Canvas c, Rect r, Paint p) {
    // Wall background
    _drawWall(c, r, p, TileType.wallNorth);
    // Window opening
    p.color = const Color(0xFF203060);
    c.drawRect(
      Rect.fromLTWH(r.left + 10, r.top + 8, _ts - 20, _ts - 16),
      p,
    );
    // Window frame
    p.color = GameColors.woodLight;
    c.drawRect(Rect.fromLTWH(r.left + 10, r.top + _ts / 2 - 1, _ts - 20, 2), p);
    c.drawRect(Rect.fromLTWH(r.left + _ts / 2 - 1, r.top + 8, 2, _ts - 16), p);
  }

  // ── Nature ───────────────────────────────────────────────────────

  static void _drawTree(Canvas c, Rect r, Paint p, int tx, int ty) {
    // Grass base
    p.color = GameColors.grassDark;
    c.drawRect(r, p);
    // Trunk
    p.color = GameColors.woodDark;
    c.drawRect(Rect.fromLTWH(r.left + 18, r.top + 28, 12, 16), p);
    // Canopy (rounded-ish via overlapping rects)
    p.color = const Color(0xFF1a5a10);
    c.drawRect(Rect.fromLTWH(r.left + 6, r.top + 4, 36, 28), p);
    p.color = const Color(0xFF2a7a20);
    c.drawRect(Rect.fromLTWH(r.left + 10, r.top + 2, 28, 24), p);
    // Highlight
    p.color = const Color(0xFF3a9a30);
    c.drawRect(Rect.fromLTWH(r.left + 14, r.top + 6, 12, 8), p);
  }

  static void _drawBush(Canvas c, Rect r, Paint p) {
    p.color = GameColors.grassDark;
    c.drawRect(r, p);
    p.color = const Color(0xFF2a6a18);
    c.drawRect(Rect.fromLTWH(r.left + 6, r.top + 14, 36, 24), p);
    p.color = const Color(0xFF3a8a28);
    c.drawRect(Rect.fromLTWH(r.left + 10, r.top + 16, 28, 18), p);
    // Berry
    p.color = const Color(0xFFc03030);
    c.drawRect(Rect.fromLTWH(r.left + 18, r.top + 22, 4, 4), p);
  }

  static void _drawFlower(Canvas c, Rect r, Paint p) {
    // Grass base first
    _drawGrass(c, r, p, 0, 0, false);
    // Stem
    p.color = const Color(0xFF2a6a18);
    c.drawRect(Rect.fromLTWH(r.left + 22, r.top + 24, 3, 16), p);
    // Petals
    p.color = const Color(0xFFe06060);
    c.drawRect(Rect.fromLTWH(r.left + 18, r.top + 18, 12, 10), p);
    // Center
    p.color = GameColors.uiHighlight;
    c.drawRect(Rect.fromLTWH(r.left + 21, r.top + 21, 6, 5), p);
  }

  // ── Objects ──────────────────────────────────────────────────────

  static void _drawFence(Canvas c, Rect r, Paint p) {
    p.color = GameColors.grassDark;
    c.drawRect(r, p);
    p.color = GameColors.woodLight;
    // Posts
    c.drawRect(Rect.fromLTWH(r.left + 4, r.top + 10, 6, 30), p);
    c.drawRect(Rect.fromLTWH(r.left + 38, r.top + 10, 6, 30), p);
    // Rails
    p.color = GameColors.woodDark;
    c.drawRect(Rect.fromLTWH(r.left + 4, r.top + 16, 40, 4), p);
    c.drawRect(Rect.fromLTWH(r.left + 4, r.top + 30, 40, 4), p);
  }

  static void _drawBarrel(Canvas c, Rect r, Paint p) {
    p.color = GameColors.stoneDark;
    c.drawRect(r, p);
    // Barrel body
    p.color = GameColors.woodDark;
    c.drawRect(Rect.fromLTWH(r.left + 10, r.top + 6, 28, 36), p);
    p.color = GameColors.woodLight;
    c.drawRect(Rect.fromLTWH(r.left + 12, r.top + 8, 24, 32), p);
    // Metal bands
    p.color = const Color(0xFF808080);
    c.drawRect(Rect.fromLTWH(r.left + 10, r.top + 14, 28, 3), p);
    c.drawRect(Rect.fromLTWH(r.left + 10, r.top + 32, 28, 3), p);
  }

  static void _drawCrate(Canvas c, Rect r, Paint p) {
    p.color = GameColors.stoneDark;
    c.drawRect(r, p);
    p.color = GameColors.woodDark;
    c.drawRect(Rect.fromLTWH(r.left + 8, r.top + 8, 32, 32), p);
    p.color = GameColors.woodLight;
    // Cross boards
    c.drawRect(Rect.fromLTWH(r.left + 8, r.top + 22, 32, 4), p);
    c.drawRect(Rect.fromLTWH(r.left + 22, r.top + 8, 4, 32), p);
  }

  static void _drawAnvil(Canvas c, Rect r, Paint p) {
    p.color = GameColors.grassDark;
    c.drawRect(r, p);
    // Base
    p.color = const Color(0xFF505050);
    c.drawRect(Rect.fromLTWH(r.left + 12, r.top + 30, 24, 10), p);
    // Body
    p.color = const Color(0xFF606060);
    c.drawRect(Rect.fromLTWH(r.left + 16, r.top + 18, 16, 14), p);
    // Top (wider)
    p.color = const Color(0xFF707070);
    c.drawRect(Rect.fromLTWH(r.left + 8, r.top + 14, 32, 6), p);
    // Horn
    c.drawRect(Rect.fromLTWH(r.left + 6, r.top + 16, 6, 3), p);
  }

  static void _drawWell(Canvas c, Rect r, Paint p) {
    p.color = GameColors.grassDark;
    c.drawRect(r, p);
    // Stone base
    p.color = GameColors.stoneLight;
    c.drawRect(Rect.fromLTWH(r.left + 8, r.top + 14, 32, 24), p);
    p.color = GameColors.stoneDark;
    c.drawRect(Rect.fromLTWH(r.left + 12, r.top + 18, 24, 16), p);
    // Water inside
    p.color = GameColors.water;
    c.drawRect(Rect.fromLTWH(r.left + 14, r.top + 20, 20, 12), p);
    // Roof posts
    p.color = GameColors.woodDark;
    c.drawRect(Rect.fromLTWH(r.left + 10, r.top + 4, 4, 16), p);
    c.drawRect(Rect.fromLTWH(r.left + 34, r.top + 4, 4, 16), p);
    // Roof
    p.color = GameColors.roofBrown;
    c.drawRect(Rect.fromLTWH(r.left + 6, r.top + 2, 36, 6), p);
  }

  static void _drawFountain(Canvas c, Rect r, Paint p, double time) {
    p.color = GameColors.stoneDark;
    c.drawRect(r, p);
    // Basin
    p.color = GameColors.stoneLight;
    c.drawRect(Rect.fromLTWH(r.left + 4, r.top + 12, 40, 28), p);
    // Water
    p.color = GameColors.water;
    c.drawRect(Rect.fromLTWH(r.left + 8, r.top + 16, 32, 20), p);
    // Spout center
    p.color = GameColors.stoneLight;
    c.drawRect(Rect.fromLTWH(r.left + 20, r.top + 6, 8, 18), p);
    // Water splash (animated)
    p.color = GameColors.waterHighlight;
    final splash = sin(time * 4) * 3;
    c.drawRect(
      Rect.fromLTWH(r.left + 16 + splash, r.top + 4, 4, 4),
      p,
    );
    c.drawRect(
      Rect.fromLTWH(r.left + 28 - splash, r.top + 6, 4, 4),
      p,
    );
  }

  static void _drawStall(Canvas c, Rect r, Paint p) {
    p.color = GameColors.pathLight;
    c.drawRect(r, p);
    // Counter
    p.color = GameColors.woodDark;
    c.drawRect(Rect.fromLTWH(r.left + 2, r.top + 16, 44, 20), p);
    p.color = GameColors.woodLight;
    c.drawRect(Rect.fromLTWH(r.left + 4, r.top + 18, 40, 16), p);
    // Awning
    p.color = const Color(0xFFC04040);
    c.drawRect(Rect.fromLTWH(r.left, r.top + 2, _ts, 14), p);
    p.color = const Color(0xFFE0E0C0);
    c.drawRect(Rect.fromLTWH(r.left + 8, r.top + 2, 8, 14), p);
    c.drawRect(Rect.fromLTWH(r.left + 24, r.top + 2, 8, 14), p);
  }

  static void _drawDiceTable(Canvas c, Rect r, Paint p) {
    // Floor
    p.color = GameColors.stoneDark;
    c.drawRect(r, p);
    // Table surface
    p.color = const Color(0xFF5a4020);
    c.drawRect(Rect.fromLTWH(r.left + 4, r.top + 8, 40, 32), p);
    p.color = const Color(0xFF7a5a30);
    c.drawRect(Rect.fromLTWH(r.left + 6, r.top + 10, 36, 28), p);
    // Felt center
    p.color = const Color(0xFF206030);
    c.drawRect(Rect.fromLTWH(r.left + 10, r.top + 14, 28, 20), p);
    // Tiny dice on table
    p.color = const Color(0xFFf0f0e0);
    c.drawRect(Rect.fromLTWH(r.left + 16, r.top + 20, 5, 5), p);
    c.drawRect(Rect.fromLTWH(r.left + 26, r.top + 22, 5, 5), p);
  }

  static void _drawChair(Canvas c, Rect r, Paint p) {
    p.color = GameColors.stoneDark;
    c.drawRect(r, p);
    // Seat
    p.color = GameColors.woodDark;
    c.drawRect(Rect.fromLTWH(r.left + 12, r.top + 18, 24, 18), p);
    // Back
    p.color = GameColors.woodLight;
    c.drawRect(Rect.fromLTWH(r.left + 14, r.top + 10, 20, 10), p);
  }

  static void _drawCounter(Canvas c, Rect r, Paint p) {
    p.color = GameColors.stoneDark;
    c.drawRect(r, p);
    p.color = GameColors.woodDark;
    c.drawRect(Rect.fromLTWH(r.left + 2, r.top + 12, 44, 24), p);
    p.color = GameColors.woodLight;
    c.drawRect(Rect.fromLTWH(r.left + 4, r.top + 14, 40, 4), p);
  }

  static void _drawBed(Canvas c, Rect r, Paint p) {
    p.color = GameColors.stoneDark;
    c.drawRect(r, p);
    // Frame
    p.color = GameColors.woodDark;
    c.drawRect(Rect.fromLTWH(r.left + 4, r.top + 8, 40, 32), p);
    // Mattress
    p.color = const Color(0xFFb0a080);
    c.drawRect(Rect.fromLTWH(r.left + 6, r.top + 10, 36, 28), p);
    // Pillow
    p.color = const Color(0xFFe0d8c0);
    c.drawRect(Rect.fromLTWH(r.left + 8, r.top + 12, 14, 10), p);
    // Blanket
    p.color = const Color(0xFF4060a0);
    c.drawRect(Rect.fromLTWH(r.left + 6, r.top + 26, 36, 12), p);
  }

  static void _drawBookshelf(Canvas c, Rect r, Paint p) {
    p.color = GameColors.stoneDark;
    c.drawRect(r, p);
    // Shelf frame
    p.color = GameColors.woodDark;
    c.drawRect(Rect.fromLTWH(r.left + 4, r.top + 4, 40, 38), p);
    // Shelves
    p.color = GameColors.woodLight;
    c.drawRect(Rect.fromLTWH(r.left + 6, r.top + 16, 36, 3), p);
    c.drawRect(Rect.fromLTWH(r.left + 6, r.top + 30, 36, 3), p);
    // Books (colored spines)
    final bookColors = [
      const Color(0xFFa03030),
      const Color(0xFF3050a0),
      const Color(0xFF308030),
      const Color(0xFF806020),
    ];
    for (int i = 0; i < 4; i++) {
      p.color = bookColors[i];
      c.drawRect(Rect.fromLTWH(r.left + 8 + i * 8, r.top + 6, 6, 10), p);
      c.drawRect(Rect.fromLTWH(r.left + 10 + i * 8, r.top + 20, 6, 10), p);
    }
  }

  static void _drawTournamentBoard(Canvas c, Rect r, Paint p, double time) {
    // Stone base
    p.color = GameColors.stoneDark;
    c.drawRect(r, p);
    // Wooden post (left side)
    p.color = GameColors.woodDark;
    c.drawRect(Rect.fromLTWH(r.left + 6, r.top + 20, 6, 24), p);
    c.drawRect(Rect.fromLTWH(r.left + 36, r.top + 20, 6, 24), p);
    // Board background
    p.color = const Color(0xFF5a4020);
    c.drawRect(Rect.fromLTWH(r.left + 4, r.top + 2, 40, 24), p);
    // Parchment
    p.color = const Color(0xFFe8d8b0);
    c.drawRect(Rect.fromLTWH(r.left + 7, r.top + 5, 34, 18), p);
    // Text lines (simulated)
    p.color = const Color(0xFF4a3a20);
    c.drawRect(Rect.fromLTWH(r.left + 10, r.top + 8, 28, 2), p);
    c.drawRect(Rect.fromLTWH(r.left + 10, r.top + 13, 22, 2), p);
    c.drawRect(Rect.fromLTWH(r.left + 10, r.top + 18, 26, 2), p);
    // Crown/trophy icon at top
    p.color = GameColors.uiHighlight;
    c.drawRect(Rect.fromLTWH(r.left + 20, r.top + 3, 8, 3), p);
    c.drawRect(Rect.fromLTWH(r.left + 18, r.top + 2, 2, 2), p);
    c.drawRect(Rect.fromLTWH(r.left + 28, r.top + 2, 2, 2), p);
    // Subtle pulsing gold border when active (time-based)
    final pulse = (0.3 + 0.2 * sin(time * 2.5)).clamp(0.0, 1.0);
    p.color = GameColors.uiHighlight.withOpacity(pulse * 0.5);
    p.style = PaintingStyle.stroke;
    p.strokeWidth = 1.5;
    c.drawRect(Rect.fromLTWH(r.left + 3, r.top + 1, 42, 26), p);
    p.style = PaintingStyle.fill;
  }
}
