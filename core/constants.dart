import 'dart:ui';

/// Core game constants for Fark My Life.
class GameConstants {
  GameConstants._();

  // ── Tile & Rendering ──────────────────────────────────────────────
  static const int tileSize = 16;
  static const double scaleFactor = 3.0;
  static const double scaledTile = tileSize * scaleFactor;

  // ── Map Dimensions ────────────────────────────────────────────────
  static const int mapWidth = 50;
  static const int mapHeight = 38;

  // ── Viewport (tiles visible on screen) ────────────────────────────
  static const int viewportTilesX = 15;
  static const int viewportTilesY = 11;

  // ── Player ────────────────────────────────────────────────────────
  static const double playerSpeed = 2.0; // tiles per second
  static const int startingGold = 50;
  static const int startingDiceCount = 6;
  static const double interactionRange = 1.5; // tiles

  // ── NPC ───────────────────────────────────────────────────────────
  static const double npcSpeed = 0.8; // tiles per second
  static const double npcWanderRadius = 6.0;
  static const double npcDiceCheckInterval = 6.0; // seconds
  static const double npcTurnDelay = 1.2; // seconds for AI turns

  // ── Farkle ────────────────────────────────────────────────────────
  static const int farkleWinScore = 4000;
  static const int minBet = 5;
  static const double suggestedBetRatio = 0.3;
  static const double lootDropChance = 0.25;

  // ── Animation ─────────────────────────────────────────────────────
  static const double walkAnimSpeed = 0.15; // seconds per frame
  static const double diceRollDuration = 1.1;
  static const double diceBounceDuration = 0.4;
}

/// Color palette inspired by Game Boy / NES aesthetics.
class GameColors {
  GameColors._();

  // ── Environment ───────────────────────────────────────────────────
  static const Color grassDark = Color(0xFF2d5a1e);
  static const Color grassLight = Color(0xFF3e7a2a);
  static const Color pathLight = Color(0xFFc8b478);
  static const Color pathDark = Color(0xFFa89060);
  static const Color stoneDark = Color(0xFF606060);
  static const Color stoneLight = Color(0xFF808080);
  static const Color water = Color(0xFF2060c0);
  static const Color waterHighlight = Color(0xFF4080e0);
  static const Color woodDark = Color(0xFF6b4226);
  static const Color woodLight = Color(0xFF8b6236);
  static const Color wallDark = Color(0xFF5a4a3a);
  static const Color wallLight = Color(0xFF7a6a5a);
  static const Color roofRed = Color(0xFFa03020);
  static const Color roofBrown = Color(0xFF705030);
  static const Color doorColor = Color(0xFF4a3520);

  // ── UI ────────────────────────────────────────────────────────────
  static const Color uiBg = Color(0xE0201818);
  static const Color uiBorder = Color(0xFFC0A060);
  static const Color uiText = Color(0xFFF0E8D0);
  static const Color uiHighlight = Color(0xFFFFD700);
  static const Color uiDanger = Color(0xFFD04040);
  static const Color uiSuccess = Color(0xFF40B040);
  static const Color uiMuted = Color(0xFF808080);

  // ── Item Tier Quality (WoW-style) ────────────────────────────────
  static const Color tierCommon    = Color(0xFF9d9d9d); // gray
  static const Color tierUncommon  = Color(0xFF1eff00); // green
  static const Color tierRare      = Color(0xFF0070dd); // blue
  static const Color tierEpic      = Color(0xFFa335ee); // purple
  static const Color tierLegendary = Color(0xFFff8000); // orange

  // Legacy aliases (referenced by old code paths)
  static const Color rarityCommon = tierCommon;
  static const Color rarityUncommon = tierUncommon;
  static const Color rarityRare = tierRare;
  static const Color rarityEpic = tierEpic;
  static const Color rarityLegendary = tierLegendary;

  // ── NPC Types ─────────────────────────────────────────────────────
  static const Color merchantPrimary = Color(0xFFB8860B);
  static const Color merchantSecondary = Color(0xFF8B6914);
  static const Color guardPrimary = Color(0xFF708090);
  static const Color guardSecondary = Color(0xFF506070);
  static const Color villagerPrimary = Color(0xFF8B7355);
  static const Color villagerSecondary = Color(0xFF556B2F);
  static const Color noblePrimary = Color(0xFF6A0DAD);
  static const Color nobleSecondary = Color(0xFFDAA520);
  static const Color blacksmithPrimary = Color(0xFFA52A2A);
  static const Color blacksmithSecondary = Color(0xFF696969);
  static const Color farmerPrimary = Color(0xFF556B2F);
  static const Color farmerSecondary = Color(0xFF8B7355);
  static const Color barmaidPrimary = Color(0xFFCC5577);
  static const Color barmaidSecondary = Color(0xFF8B4513);
}
