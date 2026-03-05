/// All tile types used in the world map.
enum TileType {
  grass,
  grassAlt,
  path,
  pathAlt,
  stone,
  stoneAlt,
  water,
  wallNorth,
  wallSouth,
  wallEast,
  wallWest,
  wallCornerNE,
  wallCornerNW,
  wallCornerSE,
  wallCornerSW,
  roofRed,
  roofBrown,
  door,
  window,
  tree,
  bush,
  flower,
  fence,
  fencePost,
  barrel,
  crate,
  anvil,
  well,
  fountain,
  stall,
  diceTable,
  chair,
  counter,
  bed,
  bookshelf,
  tournamentBoard,
  empty, // void / impassable
}

/// Whether a tile blocks movement.
extension TileTypeProperties on TileType {
  bool get isPassable {
    switch (this) {
      case TileType.grass:
      case TileType.grassAlt:
      case TileType.path:
      case TileType.pathAlt:
      case TileType.stone:
      case TileType.stoneAlt:
      case TileType.door:
      case TileType.flower:
      case TileType.chair:
        return true;
      default:
        return false;
    }
  }

  bool get isInteractable {
    switch (this) {
      case TileType.diceTable:
      case TileType.door:
      case TileType.well:
      case TileType.fountain:
      case TileType.barrel:
      case TileType.stall:
      case TileType.tournamentBoard:
        return true;
      default:
        return false;
    }
  }
}

/// Cardinal + idle directions.
enum Direction { up, down, left, right, idle }

/// NPC archetypes that define stats, dialogue, and appearance.
enum NpcType {
  merchant,
  guard,
  villager,
  noble,
  blacksmith,
  farmer,
  barmaid,
}

/// What the NPC is currently doing.
enum NpcState {
  idle,
  wandering,
  walkingToTable,
  seated,
  playingDice,
  working, // carrying items, hammering, etc.
  returning, // going back to home position
}

/// Personality affects Farkle risk tolerance.
enum Personality { cautious, normal, bold }

/// Overall game screen / mode.
enum GameScreen {
  title,
  overworld,
  dialogue,
  farkle,
  inventory,
  lootReveal,
  observing, // watching NPC vs NPC game
  tournament,
  profile,
  shop,
}

/// Dice rarity tiers.
enum DiceRarity {
  common,
  uncommon,
  rare,
  epic,
  legendary,
}

/// Named dice types with unique bonuses.
enum DiceType {
  wooden,
  iron,
  bone,
  jade,
  golden,
  crystal,
  shadow,
  royal,
  dragon,
}

/// Farkle turn phases.
enum FarklePhase {
  rolling,
  selecting,
  npcTurn,
  turnResult,
  gameOver,
}
