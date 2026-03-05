import 'dart:math';
import 'package:fark_my_life/core/enums.dart';
import 'package:fark_my_life/models/models.dart';

/// Dialogue banks per NPC type.
class NpcDialogues {
  NpcDialogues._();

  static const merchant = NpcDialogue(
    greetings: [
      "Fine goods and fine dice — care to wager?",
      "Gold flows to those who roll wisely, friend.",
      "Ah, a customer! Or perhaps... a challenger?",
    ],
    taunts: [
      "I've traded fortunes larger than your purse!",
      "Every roll is a negotiation, and I always close.",
      "Your luck is a poor investment.",
    ],
    onWin: [
      "Another profitable exchange!",
      "The market favors the prepared.",
      "Your coin spends just as well as anyone's.",
    ],
    onLose: [
      "A... temporary downturn in my portfolio.",
      "Consider it... an investment in goodwill.",
      "Hmph. The dice were clearly counterfeit.",
    ],
    observing: [
      "Watching the odds, calculating my cut...",
    ],
    busy: [
      "Can't chat now — goods to move, gold to count.",
    ],
  );

  static const guard = NpcDialogue(
    greetings: [
      "On break. Fancy a quick game, citizen?",
      "Keep it civil, and keep it quick.",
      "Don't tell the captain I'm here.",
    ],
    taunts: [
      "I've detained men with better luck than you.",
      "Roll like that again and I'll cite you for it.",
      "Discipline beats luck. Every time.",
    ],
    onWin: [
      "Order is restored.",
      "Justice prevails — and pays well.",
      "That'll cover my tavern tab nicely.",
    ],
    onLose: [
      "...I'll pretend this never happened.",
      "Back to patrol. This didn't occur.",
      "You saw nothing. Understood?",
    ],
    observing: [
      "Just making sure nobody cheats...",
    ],
    busy: [
      "Move along, citizen. I'm on duty.",
    ],
  );

  static const villager = NpcDialogue(
    greetings: [
      "Oh! Fancy a game of Farkle?",
      "Not much else to do 'round here. Shall we roll?",
      "I've been practicing — watch out!",
    ],
    taunts: [
      "Ha! My nan rolls better than that!",
      "I learned Farkle before I could walk!",
      "Ooh, bold move! Bold and foolish!",
    ],
    onWin: [
      "Haha! Can't believe that worked!",
      "Wait — I actually won? Brilliant!",
      "I'm buying everyone a round!",
    ],
    onLose: [
      "Aw nuts. There goes my dinner money.",
      "Best two out of three? ...No? Alright.",
      "My nan's gonna kill me.",
    ],
    observing: [
      "Ooh, this is exciting!",
    ],
    busy: [
      "Sorry, gotta finish my chores first!",
    ],
  );

  static const noble = NpcDialogue(
    greetings: [
      "You dare approach my table? ...Intriguing.",
      "If you can afford my stakes, sit.",
      "Amuse me, commoner. Roll.",
    ],
    taunts: [
      "Is that the best the peasantry can muster?",
      "I've seen better rolls from my chamber pot.",
      "How delightfully... mediocre.",
    ],
    onWin: [
      "As expected. Breeding tells.",
      "Add it to the pile, Reginald.",
      "A gentleman's victory.",
    ],
    onLose: [
      "Impossible! These dice must be weighted!",
      "I... I demand a recount!",
      "You'll regret this slight, mark my words.",
    ],
    observing: [
      "Hmm. Neither of them roll with any refinement.",
    ],
    busy: [
      "Do I look like I have time for commoners?",
    ],
  );

  static const blacksmith = NpcDialogue(
    greetings: [
      "Hands are steady from the forge. Ready to roll.",
      "Need a break from the anvil. Game?",
      "Iron dice? Hah, I MADE those.",
    ],
    taunts: [
      "I hammer steel all day — your luck won't hold.",
      "Forged in fire, these hands don't miss.",
      "Soft hands make soft rolls.",
    ],
    onWin: [
      "Strong as steel!",
      "That's how we do it at the forge!",
      "Another victory, hot off the anvil.",
    ],
    onLose: [
      "Bah! Even the best blades chip sometimes.",
      "Back to the forge. I'll reforge my luck.",
      "Steel yourself. I'll be back.",
    ],
    observing: [
      "Watching technique. It's like smithing — all wrist.",
    ],
    busy: [
      "Forge is hot, can't leave it. Come back later.",
    ],
  );

  static const farmer = NpcDialogue(
    greetings: [
      "Crops are in. Let's roll some bones!",
      "Not much to lose, but I'll try my luck!",
      "Better odds than the harvest, eh?",
    ],
    taunts: [
      "I've seen scarecrows with more luck!",
      "You plant those dice like bad seeds!",
      "Even my goat rolls better!",
    ],
    onWin: [
      "Well I'll be! That's a season's luck!",
      "The harvest gods smile on me today!",
      "Hoo-wee! Drinks are on the farm!",
    ],
    onLose: [
      "Same as a bad harvest... you move on.",
      "Well, least I still got my turnips.",
      "There's always next season...",
    ],
    observing: [
      "Better entertainment than watching corn grow!",
    ],
    busy: [
      "Fields won't plow themselves. Maybe later.",
    ],
  );

  static const barmaid = NpcDialogue(
    greetings: [
      "Slow night. Deal me in!",
      "I've seen every trick at this table. Bring it.",
      "One round? I'll wager my tips!",
    ],
    taunts: [
      "I pour drinks and pour on the pressure!",
      "Seen better rolls spilled from a tankard!",
      "Honey, that roll won't even cover a pint.",
    ],
    onWin: [
      "Tips AND winnings? Best shift ever!",
      "That's going straight in the tip jar!",
      "Drinks on you, love!",
    ],
    onLose: [
      "Ugh, back to pouring pints...",
      "You got lucky. Rematch when my shift ends.",
      "Don't spend it all in one tavern!",
    ],
    observing: ["Who needs another round? ...Oh, nice roll!"],
    busy: ["Can't leave the bar unattended, sorry!"],
  );

  static NpcDialogue forType(NpcType type) {
    switch (type) {
      case NpcType.merchant: return merchant;
      case NpcType.guard:    return guard;
      case NpcType.villager: return villager;
      case NpcType.noble:    return noble;
      case NpcType.blacksmith: return blacksmith;
      case NpcType.farmer:   return farmer;
      case NpcType.barmaid:  return barmaid;
    }
  }
}

/// Factory for creating the town's NPC population.
class NpcFactory {
  NpcFactory._();

  static List<NpcData> createTownNpcs() {
    final rng = Random();
    // ALL NPC homes are on the 2-wide road grid for guaranteed pathability:
    //   Horizontal roads: y=10-11, y=19-20, y=30-31
    //   Vertical roads:   x=10-11, x=25-26, x=40-41
    return [
      // ── Merchants (north road near market) ─────────────────────
      NpcData(
        id: 'merchant_01', name: 'Torvin',
        type: NpcType.merchant, personality: Personality.normal,
        x: 30, y: 11, gold: 120 + rng.nextInt(80), maxGold: 200,
        diceChance: 0.4,
      ),
      NpcData(
        id: 'merchant_02', name: 'Silka',
        type: NpcType.merchant, personality: Personality.bold,
        x: 35, y: 11, gold: 80 + rng.nextInt(60), maxGold: 160,
        diceChance: 0.35,
      ),

      // ── Guards (main road patrol) ──────────────────────────────
      NpcData(
        id: 'guard_01', name: 'Aldric',
        type: NpcType.guard, personality: Personality.cautious,
        x: 18, y: 20, gold: 40 + rng.nextInt(30), maxGold: 80,
        diceChance: 0.2,
      ),
      NpcData(
        id: 'guard_02', name: 'Brynn',
        type: NpcType.guard, personality: Personality.normal,
        x: 35, y: 20, gold: 35 + rng.nextInt(35), maxGold: 80,
        diceChance: 0.25,
      ),

      // ── Villagers (various roads) ──────────────────────────────
      NpcData(
        id: 'villager_01', name: 'Petal',
        type: NpcType.villager, personality: Personality.bold,
        x: 20, y: 20, gold: 15 + rng.nextInt(20), maxGold: 40,
        diceChance: 0.6,
      ),
      NpcData(
        id: 'villager_02', name: 'Midge',
        type: NpcType.villager, personality: Personality.normal,
        x: 16, y: 11, gold: 10 + rng.nextInt(25), maxGold: 40,
        diceChance: 0.55,
      ),
      NpcData(
        id: 'villager_03', name: 'Joss',
        type: NpcType.villager, personality: Personality.cautious,
        x: 26, y: 30, gold: 12 + rng.nextInt(18), maxGold: 35,
        diceChance: 0.5,
      ),

      // ── Noble (north road near manor) ──────────────────────────
      NpcData(
        id: 'noble_01', name: 'Lord Ashworth',
        type: NpcType.noble, personality: Personality.bold,
        x: 6, y: 11, gold: 200 + rng.nextInt(300), maxGold: 500,
        diceChance: 0.5,
      ),

      // ── Blacksmith (main road near forge) ──────────────────────
      NpcData(
        id: 'smith_01', name: 'Grenda',
        type: NpcType.blacksmith, personality: Personality.normal,
        x: 35, y: 19, gold: 60 + rng.nextInt(50), maxGold: 120,
        diceChance: 0.3,
      ),

      // ── Farmers (main road near farm gate) ─────────────────────
      NpcData(
        id: 'farmer_01', name: 'Old Barnaby',
        type: NpcType.farmer, personality: Personality.bold,
        x: 5, y: 20, gold: 20 + rng.nextInt(20), maxGold: 50,
        diceChance: 0.5,
      ),
      NpcData(
        id: 'farmer_02', name: 'Rosie',
        type: NpcType.farmer, personality: Personality.cautious,
        x: 11, y: 30, gold: 15 + rng.nextInt(15), maxGold: 40,
        diceChance: 0.45,
      ),

      // ── Barmaids (main road near tavern) ───────────────────────
      NpcData(
        id: 'barmaid_01', name: 'Lila',
        type: NpcType.barmaid, personality: Personality.bold,
        x: 18, y: 19, gold: 30 + rng.nextInt(30), maxGold: 80,
        diceChance: 0.55,
      ),
      NpcData(
        id: 'barmaid_02', name: 'Mae',
        type: NpcType.barmaid, personality: Personality.normal,
        x: 11, y: 19, gold: 25 + rng.nextInt(20), maxGold: 60,
        diceChance: 0.5,
      ),
      // Dice Merchant — sells dice, doesn't gamble
      NpcData(
        id: 'merchant_vex', name: 'Vex',
        type: NpcType.merchant, personality: Personality.normal,
        x: 30, y: 12, gold: 999, maxGold: 999,
        diceChance: 0.0, // never seeks dice tables
      ),
    ];
  }
}
