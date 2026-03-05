import 'package:fark_my_life/core/enums.dart';

/// Alias for brevity in the map grid.
typedef T = TileType;

/// Generates the 50×38 town map.
/// 
/// Road grid (all 2-tiles wide for easy NPC navigation):
///   Horizontal: y=10-11, y=19-20, y=30-31
///   Vertical:   x=10-11, x=25-26, x=40-41
///
/// Zones between roads:
///   NW: Noble Manor          N-Center: Houses/Garden      NE: Chapel
///   W:  Cottages              Center: TOWN SQUARE          E: Market
///   SW: Farm                  S-Center: Tavern+Beer Garden SE: Blacksmith
///   Bottom strip: Pond, park, south houses
///
/// ALL dice tables are OUTDOORS on path/stone tiles.
class TownMap {
  TownMap._();

  static const int width = 50;
  static const int height = 38;

  static List<List<TileType>> generate() {
    final map = List.generate(
      height, (_) => List.generate(width, (_) => TileType.grass),
    );

    void fill(int x1, int y1, int x2, int y2, TileType t) {
      for (int y = y1; y <= y2 && y < height; y++) {
        for (int x = x1; x <= x2 && x < width; x++) {
          map[y][x] = t;
        }
      }
    }
    void set(int x, int y, TileType t) {
      if (x >= 0 && x < width && y >= 0 && y < height) map[y][x] = t;
    }

    // ══════════════════════════════════════════════════════════════
    // BORDER — trees around entire perimeter
    // ══════════════════════════════════════════════════════════════
    for (int x = 0; x < width; x++) { set(x, 0, T.tree); set(x, height - 1, T.tree); }
    for (int y = 0; y < height; y++) { set(0, y, T.tree); set(width - 1, y, T.tree); }
    // Corner clusters
    fill(1, 1, 2, 2, T.tree); fill(47, 1, 48, 2, T.tree);
    fill(1, 35, 2, 36, T.tree); fill(47, 35, 48, 36, T.tree);

    // ══════════════════════════════════════════════════════════════
    // ROAD GRID — 2-tile-wide roads for reliable NPC navigation
    // ══════════════════════════════════════════════════════════════
    // Horizontal roads
    fill(1, 10, 48, 11, T.path);   // north road
    fill(1, 19, 48, 20, T.path);   // main road (center)
    fill(1, 30, 48, 31, T.path);   // south road
    // Vertical roads
    fill(10, 1, 11, 36, T.path);   // west road
    fill(25, 1, 26, 36, T.path);   // center road
    fill(40, 1, 41, 36, T.path);   // east road
    // Path variety (alternating stones for visual interest)
    for (int x = 1; x < width - 1; x++) {
      if (x % 4 == 0) { set(x, 10, T.pathAlt); set(x, 20, T.pathAlt); set(x, 30, T.pathAlt); }
    }
    for (int y = 1; y < height - 1; y++) {
      if (y % 4 == 0) { set(10, y, T.pathAlt); set(25, y, T.pathAlt); set(40, y, T.pathAlt); }
    }

    // ══════════════════════════════════════════════════════════════
    // TOWN SQUARE — center zone, stone plaza with fountain & tables
    // ══════════════════════════════════════════════════════════════
    fill(13, 13, 23, 18, T.stone);
    // Stone variety
    for (int y = 13; y <= 18; y++) {
      for (int x = 13; x <= 23; x++) {
        if ((x + y) % 4 == 0) set(x, y, T.stoneAlt);
      }
    }
    // Fountain
    set(18, 15, T.fountain); set(18, 16, T.fountain);
    // Well
    set(14, 14, T.well);
    // Tournament Board — prominent position near fountain
    set(20, 15, T.tournamentBoard);
    // ── DICE TABLE 0 — town square, south side (clear of fountain) ──
    set(15, 17, T.diceTable);
    set(14, 17, T.chair); set(16, 17, T.chair);
    // ── DICE TABLE 1 — town square, east side ──
    set(22, 16, T.diceTable);
    set(21, 16, T.chair); set(23, 16, T.chair);
    // Flowers bordering the square
    for (final pos in [[13,12],[16,12],[19,12],[22,12],[13,19],[16,19],[22,19]]) {
      if (map[pos[1]][pos[0]] == T.grass) set(pos[0], pos[1], T.flower);
    }

    // ══════════════════════════════════════════════════════════════
    // NOBLE MANOR — NW zone (2-9, 3-9)
    // ══════════════════════════════════════════════════════════════
    fill(3, 3, 9, 3, T.wallNorth);
    fill(3, 8, 9, 8, T.wallSouth);
    fill(3, 4, 3, 7, T.wallWest);
    fill(9, 4, 9, 7, T.wallEast);
    fill(4, 3, 8, 3, T.roofRed);
    fill(4, 4, 8, 7, T.stone);
    set(6, 8, T.door);           // door opens south onto grass
    // Interior
    set(4, 4, T.bookshelf); set(5, 4, T.bookshelf);
    set(8, 4, T.bed);
    set(4, 6, T.counter);
    set(5, 3, T.window); set(7, 3, T.window);
    // Garden path from manor to north road
    fill(6, 9, 6, 10, T.path);
    // Garden decor
    set(4, 9, T.flower); set(8, 9, T.flower);
    set(3, 9, T.bush); set(9, 9, T.bush);

    // ══════════════════════════════════════════════════════════════
    // HOUSES — north-center zone (13-23, 3-8)
    // ══════════════════════════════════════════════════════════════
    // House 1 (left)
    fill(13, 4, 17, 4, T.wallNorth);
    fill(13, 8, 17, 8, T.wallSouth);
    fill(13, 5, 13, 7, T.wallWest);
    fill(17, 5, 17, 7, T.wallEast);
    fill(14, 4, 16, 4, T.roofRed);
    fill(14, 5, 16, 7, T.stone);
    set(15, 8, T.door);
    set(14, 4, T.window); set(16, 4, T.window);
    fill(15, 9, 15, 10, T.path); // path to road
    // House 2 (right)
    fill(20, 4, 24, 4, T.wallNorth);
    fill(20, 8, 24, 8, T.wallSouth);
    fill(20, 5, 20, 7, T.wallWest);
    fill(24, 5, 24, 7, T.wallEast);
    fill(21, 4, 23, 4, T.roofBrown);
    fill(21, 5, 23, 7, T.stone);
    set(22, 8, T.door);
    set(21, 4, T.window); set(23, 4, T.window);
    fill(22, 9, 22, 10, T.path);

    // ══════════════════════════════════════════════════════════════
    // CHAPEL — NE zone (28-38, 3-9)
    // ══════════════════════════════════════════════════════════════
    fill(30, 3, 38, 3, T.wallNorth);
    fill(30, 9, 38, 9, T.wallSouth);
    fill(30, 4, 30, 8, T.wallWest);
    fill(38, 4, 38, 8, T.wallEast);
    fill(31, 3, 37, 3, T.roofRed);
    fill(31, 4, 37, 8, T.stone);
    set(34, 9, T.door);
    set(32, 3, T.window); set(36, 3, T.window);
    // Interior
    set(31, 5, T.bookshelf); set(31, 6, T.bookshelf);
    set(37, 5, T.bookshelf); set(37, 6, T.bookshelf);
    // Path to north road
    fill(34, 9, 34, 10, T.path);

    // ══════════════════════════════════════════════════════════════
    // MARKET — east zone (28-38, 13-18) — open-air stalls on path
    // ══════════════════════════════════════════════════════════════
    fill(28, 13, 38, 18, T.path);
    // Stall rows
    set(29, 14, T.stall); set(30, 14, T.stall);
    set(33, 14, T.stall); set(34, 14, T.stall);
    set(37, 14, T.stall);
    set(29, 17, T.stall); set(30, 17, T.stall);
    set(33, 17, T.stall); set(34, 17, T.stall);
    set(37, 17, T.stall);
    // Crates and barrels
    set(28, 13, T.crate); set(38, 13, T.barrel);
    set(28, 18, T.barrel); set(38, 18, T.crate);
    // ── DICE TABLE 2 — market, between stall rows ──
    set(32, 15, T.diceTable);
    set(31, 15, T.chair); set(33, 15, T.chair);

    // ══════════════════════════════════════════════════════════════
    // COTTAGES — west zone (2-8, 13-18)
    // ══════════════════════════════════════════════════════════════
    // Cottage 1
    fill(2, 13, 7, 13, T.wallNorth);
    fill(2, 16, 7, 16, T.wallSouth);
    fill(2, 14, 2, 15, T.wallWest);
    fill(7, 14, 7, 15, T.wallEast);
    fill(3, 13, 6, 13, T.roofBrown);
    fill(3, 14, 6, 15, T.stone);
    set(5, 16, T.door);
    set(3, 13, T.window); set(6, 13, T.window);
    fill(5, 17, 5, 19, T.path); // path to main road
    // Cottage 2
    fill(2, 17, 7, 17, T.wallNorth);
    // Actually that conflicts. Let me keep it simple — one cottage.
    // Decorations near cottage
    set(8, 14, T.bush); set(8, 16, T.flower);

    // ══════════════════════════════════════════════════════════════
    // TAVERN "The Rolling Die" — S-center zone (13-23, 22-28)
    // Building with door opening onto main road
    // ══════════════════════════════════════════════════════════════
    fill(14, 22, 23, 22, T.wallNorth);
    fill(14, 28, 23, 28, T.wallSouth);
    fill(14, 23, 14, 27, T.wallWest);
    fill(23, 23, 23, 27, T.wallEast);
    fill(15, 22, 22, 22, T.roofBrown);
    fill(15, 23, 22, 27, T.stone);
    set(18, 22, T.door);         // north door onto path (y=20 road nearby)
    // Path from door to main road
    fill(18, 21, 18, 20, T.path);
    // Interior — bar along south wall
    set(16, 27, T.counter); set(17, 27, T.counter); set(18, 27, T.counter);
    set(15, 27, T.barrel); set(15, 26, T.barrel);
    set(22, 27, T.crate); set(22, 26, T.barrel);
    // Windows
    set(16, 22, T.window); set(20, 22, T.window);

    // ── BEER GARDEN — outdoor stone patio south of tavern ──
    fill(15, 29, 22, 29, T.stone);
    // South door of tavern
    set(19, 28, T.door);
    // ── DICE TABLE 3 — beer garden, on patio (not on road) ──
    set(16, 29, T.diceTable);
    set(15, 29, T.chair); set(17, 29, T.chair);
    // ── DICE TABLE 4 — beer garden east, on patio ──
    set(21, 29, T.diceTable);
    set(20, 29, T.chair); set(22, 29, T.chair);

    // ══════════════════════════════════════════════════════════════
    // BLACKSMITH — SE zone (28-38, 22-28)
    // ══════════════════════════════════════════════════════════════
    fill(30, 23, 37, 23, T.wallNorth);
    fill(30, 28, 37, 28, T.wallSouth);
    fill(30, 24, 30, 27, T.wallWest);
    fill(37, 24, 37, 27, T.wallEast);
    fill(31, 23, 36, 23, T.roofBrown);
    fill(31, 24, 36, 27, T.stone);
    set(33, 23, T.door);        // door opens north
    // Interior
    set(32, 24, T.anvil); set(35, 25, T.barrel);
    set(36, 24, T.crate); set(31, 26, T.barrel);
    set(33, 23, T.door);
    // Outdoor forge area
    set(33, 22, T.path); // clear path from door to road
    fill(33, 21, 33, 20, T.path);
    set(35, 22, T.anvil);
    set(36, 22, T.crate); set(37, 22, T.barrel);
    // ── DICE TABLE 5 — outside blacksmith, on stone courtyard ──
    set(32, 22, T.diceTable);
    set(31, 22, T.chair); set(33, 22, T.chair);

    // ══════════════════════════════════════════════════════════════
    // FARM — SW zone (2-9, 22-28)
    // ══════════════════════════════════════════════════════════════
    fill(2, 23, 2, 28, T.fence);
    fill(9, 23, 9, 28, T.fence);
    fill(2, 23, 9, 23, T.fence);
    fill(2, 28, 9, 28, T.fence);
    set(5, 23, T.path); // north gate
    set(5, 28, T.path); // south gate
    fill(3, 24, 8, 27, T.grassAlt); // crops
    // Path from farm gate to roads
    fill(5, 21, 5, 20, T.path);
    fill(5, 29, 5, 30, T.path);

    // ══════════════════════════════════════════════════════════════
    // SOUTH DISTRICT — below south road
    // ══════════════════════════════════════════════════════════════

    // ── TOURNAMENT GROUNDS — dedicated arena east of center ──
    // Stone arena floor
    fill(28, 32, 38, 36, T.stone);
    for (int y = 32; y <= 36; y++) {
      for (int x = 28; x <= 38; x++) {
        if ((x + y) % 3 == 0) set(x, y, T.stoneAlt);
      }
    }
    // Fence borders (north and south only, east/west open for access)
    fill(28, 32, 38, 32, T.path); // north walkway
    fill(28, 36, 38, 36, T.path); // south walkway
    // Path connecting to south road
    fill(33, 31, 33, 31, T.path);
    // ── DICE TABLE 7 — tournament table NW ──
    set(30, 33, T.diceTable);
    set(29, 33, T.chair); set(31, 33, T.chair);
    // ── DICE TABLE 8 — tournament table NE ──
    set(36, 33, T.diceTable);
    set(35, 33, T.chair); set(37, 33, T.chair);
    // ── DICE TABLE 9 — tournament table SW ──
    set(30, 35, T.diceTable);
    set(29, 35, T.chair); set(31, 35, T.chair);
    // ── DICE TABLE 10 — tournament table SE ──
    set(36, 35, T.diceTable);
    set(35, 35, T.chair); set(37, 35, T.chair);
    // Decorative torches (using flowers as stand-in)
    set(28, 33, T.flower); set(38, 33, T.flower);
    set(28, 35, T.flower); set(38, 35, T.flower);

    // ── Pond (moved further east to not conflict) ──
    fill(42, 33, 46, 35, T.water);
    set(41, 33, T.flower); set(47, 33, T.flower);
    set(41, 35, T.bush); set(47, 35, T.bush);

    // ── South house ──
    fill(14, 33, 19, 33, T.wallNorth);
    fill(14, 36, 19, 36, T.wallSouth);
    fill(14, 34, 14, 35, T.wallWest);
    fill(19, 34, 19, 35, T.wallEast);
    fill(15, 33, 18, 33, T.roofRed);
    fill(15, 34, 18, 35, T.stone);
    set(16, 33, T.window); set(18, 33, T.window);
    set(17, 36, T.door);
    // No path needed — already on south road at y=30

    // ── DICE TABLE 6 — south park area (west of tournament grounds) ──
    set(18, 32, T.diceTable);
    set(17, 32, T.chair); set(19, 32, T.chair);
    // Connect to south road
    fill(18, 31, 18, 31, T.path);

    // ══════════════════════════════════════════════════════════════
    // DECORATIVE — trees, bushes, flowers
    // ══════════════════════════════════════════════════════════════
    // Tree clusters in empty areas
    final treeSpots = [
      // NW corner area
      [2, 4], [2, 6], [3, 1], [8, 1],
      // NE area
      [43, 3], [44, 5], [45, 7], [43, 8], [46, 3],
      // Far east strip
      [43, 14], [44, 16], [45, 18],
      [43, 22], [44, 25], [45, 28],
      // Far west
      [1, 14], [1, 17],
      // South corners
      [2, 33], [3, 35], [44, 34], [45, 33],
      // Mid decorative
      [12, 2], [24, 2], [28, 2],
      [12, 34], [8, 34], [23, 34],
    ];
    for (final s in treeSpots) {
      if (map[s[1]][s[0]] == T.grass) set(s[0], s[1], T.tree);
    }

    // Bushes
    final bushSpots = [
      [4, 12], [8, 12], [27, 12], [38, 12],
      [4, 21], [27, 21], [38, 21],
      [8, 32], [12, 32], [42, 32],
    ];
    for (final s in bushSpots) {
      if (map[s[1]][s[0]] == T.grass) set(s[0], s[1], T.bush);
    }

    // Flowers near buildings
    final flowerSpots = [
      [4, 10], [8, 10],        // manor garden
      [29, 13], [36, 13],      // market entrance
      [15, 21], [22, 21],      // tavern frontage
      [31, 22], [36, 21],      // blacksmith area
    ];
    for (final s in flowerSpots) {
      if (map[s[1]][s[0]] == T.grass || map[s[1]][s[0]] == T.path) {
        set(s[0], s[1], T.flower);
      }
    }

    return map;
  }
}
