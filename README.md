# Fark My Life 🎲💀

A 2D top-down dice RPG built in Flutter, inspired by early Zelda/Pokémon aesthetics. Explore a medieval city, challenge NPCs to Farkle, collect rare dice, and build your fortune.

## How to Run

```bash
flutter create fark_my_life
# Copy the lib/ folder and pubspec.yaml into the new project
cd fark_my_life
flutter pub get
flutter run -d chrome
```

**Requirements:** Flutter 3.x+, Dart 3.x+

## Controls

| Key | Action |
|-----|--------|
| WASD / Arrows | Move |
| E | Interact with NPC / Table |
| I | Open Inventory |

## Game Flow

1. **Explore** the town — walk around the medieval city with paths, a tavern, market, manor, and farm
2. **Find NPCs** — 11 characters wander the city and periodically sit at dice tables
3. **Challenge** — approach a seated NPC, set your wager, and start a Farkle match
4. **Play Farkle** — roll 6 dice, select scoring combinations, bank points or push your luck
5. **Win loot** — victories have a chance to drop special dice with unique bonuses
6. **Collect** — build your dice collection in the inventory screen

## Farkle Rules

- **Goal:** First to 4,000 points wins
- **Turn:** Roll all 6 dice → select scoring dice → Bank (keep points) or Keep & Roll (risk for more)
- **Farkle:** If no dice score, you lose your turn's points
- **Hot Dice:** If all 6 dice score, roll all 6 again with a bonus

### Scoring
| Combo | Points |
|-------|--------|
| Single 1 | 100 |
| Single 5 | 50 |
| Three of a kind | Face × 100 (1s = 1,000) |
| Four/Five/Six of a kind | ×2/×4/×8 |
| Straight (1-2-3-4-5-6) | 1,500 |
| Three pairs | 1,500 |

## Special Dice

| Die | Rarity | Bonus |
|-----|--------|-------|
| Wooden | Common | None |
| Iron | Uncommon | 1s score 150 |
| Bone | Uncommon | 5s score 75 |
| Jade | Rare | Three-of-a-kind +100 |
| Golden | Rare | Banking +50 |
| Crystal | Epic | Free re-roll on Farkle |
| Shadow | Epic | Triples use ×150 multiplier |
| Royal | Legendary | Each 6 rolled +25 |
| Dragon | Legendary | Hot dice +500 |

## Project Structure

```
lib/
├── main.dart                    # App entry, state management, screen routing
├── core/
│   ├── constants.dart           # Tile sizes, colors, game constants
│   └── enums.dart               # All game enumerations
├── entities/
│   └── sprite_renderer.dart     # 16×16 pixel character sprites
├── models/
│   ├── models.dart              # Data classes (Player, NPC, Dice, etc.)
│   └── npc_definitions.dart     # NPC factory, dialogue lines
├── screens/
│   ├── overworld_screen.dart    # Main game world with movement & NPC AI
│   ├── dialogue_screen.dart     # NPC conversation & betting UI
│   ├── farkle_screen.dart       # Full Farkle dice game UI
│   └── inventory_screen.dart    # Dice collection viewer
├── systems/
│   ├── farkle_engine.dart       # Scoring logic, NPC AI decisions
│   └── loot_system.dart         # Weighted dice drop tables
└── world/
    ├── town_map.dart            # Procedural 40×30 town generation
    ├── tile_renderer.dart       # CustomPaint tile drawing
    └── world_painter.dart       # Viewport camera & rendering
```

## 5,650+ lines of Dart • 15 source files • 0 external assets
All graphics rendered via CustomPaint — no sprite sheets needed.
