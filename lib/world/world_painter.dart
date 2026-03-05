import 'package:flutter/material.dart';
import 'package:fark_my_life/core/constants.dart';
import 'package:fark_my_life/core/enums.dart';
import 'package:fark_my_life/world/tile_renderer.dart';

/// Renders the visible portion of the world map.
class WorldPainter extends CustomPainter {
  final List<List<TileType>> map;
  final double cameraX; // in tiles
  final double cameraY;
  final double time; // for animations
  final Size viewportSize;

  WorldPainter({
    required this.map,
    required this.cameraX,
    required this.cameraY,
    required this.time,
    required this.viewportSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final ts = GameConstants.scaledTile;

    // Calculate visible tile range
    final startTileX = cameraX.floor() - 1;
    final startTileY = cameraY.floor() - 1;
    final endTileX = startTileX + (viewportSize.width / ts).ceil() + 2;
    final endTileY = startTileY + (viewportSize.height / ts).ceil() + 2;

    // Pixel offset for smooth scrolling
    final offsetX = -(cameraX - cameraX.floor()) * ts;
    final offsetY = -(cameraY - cameraY.floor()) * ts;

    for (int ty = startTileY; ty <= endTileY; ty++) {
      for (int tx = startTileX; tx <= endTileX; tx++) {
        // Bounds check
        if (tx < 0 || tx >= map[0].length || ty < 0 || ty >= map.length) {
          // Out-of-bounds: draw black
          final sx = (tx - startTileX) * ts + offsetX;
          final sy = (ty - startTileY) * ts + offsetY;
          canvas.drawRect(
            Rect.fromLTWH(sx, sy, ts, ts),
            Paint()..color = Colors.black,
          );
          continue;
        }

        final tile = map[ty][tx];
        final sx = (tx - startTileX) * ts + offsetX;
        final sy = (ty - startTileY) * ts + offsetY;

        TileRenderer.drawTile(
          canvas,
          tile,
          sx,
          sy,
          tileX: tx,
          tileY: ty,
          time: time,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant WorldPainter oldDelegate) {
    return oldDelegate.cameraX != cameraX ||
        oldDelegate.cameraY != cameraY ||
        oldDelegate.time != time;
  }
}
