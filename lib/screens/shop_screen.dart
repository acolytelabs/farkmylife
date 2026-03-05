import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fark_my_life/core/constants.dart';
import 'package:fark_my_life/core/enums.dart';
import 'package:fark_my_life/models/models.dart';
import 'package:fark_my_life/models/dice_tiers.dart';
import 'package:fark_my_life/entities/dice_renderer.dart';
import 'package:fark_my_life/screens/dice_detail_panel.dart';

/// Shop stock item (a die for sale).
class ShopItem {
  final DiceItem die;
  final int price;
  bool sold;

  ShopItem({required this.die, required this.price, this.sold = false});

  Map<String, dynamic> toJson() => {
    'mat': die.material.index,
    'ench': die.enchantment?.index,
    'price': price,
    'sold': sold,
  };

  factory ShopItem.fromJson(Map<String, dynamic> j) {
    final mat = DiceMaterial.values[j['mat'] ?? 1];
    Enchantment? ench;
    if (j['ench'] != null) ench = Enchantment.values[j['ench']];
    return ShopItem(
      die: DiceItem(material: mat, enchantment: ench),
      price: j['price'] ?? 10,
      sold: j['sold'] ?? false,
    );
  }
}

/// Manages shop stock generation and restocking.
class ShopManager {
  static const int restockEveryNGames = 5;
  int gamesSinceRestock = 0;
  List<ShopItem> stock = [];

  ShopManager() {
    if (stock.isEmpty) generateStock();
  }

  void generateStock() {
    final rng = Random();
    stock = [];

    // Generate 7-8 items with a good spread
    final totalSlots = 7 + rng.nextInt(2);

    for (int i = 0; i < totalSlots; i++) {
      // Tier distribution: weighted but anything can appear
      final tierRoll = rng.nextDouble();
      DiceTier tier;
      if (tierRoll < 0.20)       tier = DiceTier.common;
      else if (tierRoll < 0.40)  tier = DiceTier.uncommon;
      else if (tierRoll < 0.65)  tier = DiceTier.rare;
      else if (tierRoll < 0.85)  tier = DiceTier.epic;
      else                       tier = DiceTier.legendary;
      stock.add(_randomItem(rng, tier));
    }

    // GUARANTEE: at least 2 enchanted items in stock
    int enchantedCount = stock.where((s) => s.die.enchantment != null).length;
    int attempts = 0;
    while (enchantedCount < 2 && attempts < 10) {
      // Pick a random non-enchanted slot (prefer higher tier for enchantment)
      final candidates = <int>[];
      for (int i = 0; i < stock.length; i++) {
        if (stock[i].die.enchantment == null && stock[i].die.tier != DiceTier.common) {
          candidates.add(i);
        }
      }
      if (candidates.isEmpty) {
        // Add a new enchanted item
        final tier = rng.nextDouble() < 0.5 ? DiceTier.rare : DiceTier.epic;
        stock.add(_randomItem(rng, tier, forceEnchant: true));
      } else {
        final idx = candidates[rng.nextInt(candidates.length)];
        stock[idx] = _randomItem(rng, stock[idx].die.tier, forceEnchant: true);
      }
      enchantedCount = stock.where((s) => s.die.enchantment != null).length;
      attempts++;
    }
  }

  ShopItem _randomItem(Random rng, DiceTier tier, {bool forceEnchant = false}) {
    final materials = DiceMaterial.values
        .where((m) => DiceTiers.tierOf(m) == tier).toList();
    final mat = materials[rng.nextInt(materials.length)];
    final basePrice = DiceTiers.basePrice(mat);

    // Enchantment: 30% base chance on T2+, 10% on T1; forced if requested
    Enchantment? ench;
    final enchChance = tier == DiceTier.common ? 0.0 : 0.30; // T1 can't have enchants per spec
    if (forceEnchant || (tier != DiceTier.common && rng.nextDouble() < enchChance)) {
      final tierIdx = DiceTiers.tierIndex(tier);
      final eligible = Enchantment.values.where((e) {
        return DiceTiers.tierIndex(DiceTiers.enchantmentMinTier(e)) <= tierIdx;
      }).toList();
      if (eligible.isNotEmpty) ench = eligible[rng.nextInt(eligible.length)];
    }

    // Price: base * enchantment multiplier
    int price = basePrice;
    if (ench != null) {
      price = (basePrice * (DiceTiers.isActiveEnchantment(ench) ? 2.0 : 1.5)).round();
    }

    return ShopItem(die: DiceItem(material: mat, enchantment: ench), price: price);
  }

  void onGameCompleted() {
    gamesSinceRestock++;
    if (gamesSinceRestock >= restockEveryNGames) {
      generateStock();
      gamesSinceRestock = 0;
    }
  }

  /// Sell price = 40% of estimated buy price.
  static int sellPrice(DiceItem die) {
    final base = DiceTiers.basePrice(die.material);
    int price = base;
    if (die.enchantment != null) {
      price = (base * (DiceTiers.isActiveEnchantment(die.enchantment!) ? 2.0 : 1.5)).round();
    }
    return (price * 0.4).floor();
  }
}

/// Full-screen shop UI.
class ShopScreen extends StatefulWidget {
  final PlayerData player;
  final ShopManager shop;
  final VoidCallback onClose;
  final VoidCallback onSave;

  const ShopScreen({
    super.key,
    required this.player,
    required this.shop,
    required this.onClose,
    required this.onSave,
  });

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  int? _selectedIndex = 0;
  bool _sellMode = false;
  int? _selectedSellIndex = 0;

  @override
  Widget build(BuildContext context) {
    final items = _sellMode
        ? widget.player.dice
        : widget.shop.stock.where((s) => !s.sold).toList();
    final currentIdx = _sellMode ? _selectedSellIndex : _selectedIndex;
    final itemCount = items.length;

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final key = event.logicalKey;

        if (key == LogicalKeyboardKey.escape) {
          widget.onClose();
          return KeyEventResult.handled;
        }

        // Tab: switch buy/sell modes
        if (key == LogicalKeyboardKey.tab) {
          setState(() {
            _sellMode = !_sellMode;
            _selectedIndex = null;
            _selectedSellIndex = null;
          });
          return KeyEventResult.handled;
        }

        // Arrow navigation through grid (4 columns)
        const cols = 4;
        if (key == LogicalKeyboardKey.arrowRight) {
          setState(() {
            final idx = (currentIdx ?? -1) + 1;
            if (_sellMode) _selectedSellIndex = idx.clamp(0, itemCount - 1);
            else _selectedIndex = idx.clamp(0, itemCount - 1);
          });
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowLeft) {
          setState(() {
            final idx = (currentIdx ?? 1) - 1;
            if (_sellMode) _selectedSellIndex = idx.clamp(0, itemCount - 1);
            else _selectedIndex = idx.clamp(0, itemCount - 1);
          });
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowDown) {
          setState(() {
            final idx = (currentIdx ?? -cols) + cols;
            if (_sellMode) _selectedSellIndex = idx.clamp(0, itemCount - 1);
            else _selectedIndex = idx.clamp(0, itemCount - 1);
          });
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowUp) {
          setState(() {
            final idx = (currentIdx ?? cols) - cols;
            if (_sellMode) _selectedSellIndex = idx.clamp(0, itemCount - 1);
            else _selectedIndex = idx.clamp(0, itemCount - 1);
          });
          return KeyEventResult.handled;
        }

        // E/Space/Enter: buy or sell selected item
        if (key == LogicalKeyboardKey.keyE ||
            key == LogicalKeyboardKey.space ||
            key == LogicalKeyboardKey.enter) {
          if (_sellMode && _selectedSellIndex != null && _selectedSellIndex! < itemCount) {
            _sellItem(_selectedSellIndex!);
          } else if (!_sellMode && _selectedIndex != null) {
            final available = widget.shop.stock.where((s) => !s.sold).toList();
            if (_selectedIndex! < available.length) {
              final item = available[_selectedIndex!];
              if (widget.player.gold >= item.price) {
                _buyItem(item);
              }
            }
          }
          return KeyEventResult.handled;
        }

        return KeyEventResult.ignored;
      },
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Color(0xFF0a0a10), Color(0xFF14101a)],
          ),
        ),
        child: SafeArea(child: Column(children: [
          _buildHeader(),
          Expanded(child: Row(children: [
            // Left: grid
            Expanded(flex: 3, child: _sellMode ? _buildSellView() : _buildBuyView()),
            // Right: detail panel
            Container(width: 2, color: const Color(0xFF3a2a18)),
            Expanded(flex: 2, child: _buildShopDetailPanel()),
          ])),
          _buildFooter(),
        ])),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: GameColors.uiBorder, width: 2)),
      ),
      child: Row(children: [
        const Text("VEX'S DICE EMPORIUM", style: TextStyle(
          fontFamily: 'serif', fontSize: 14, fontWeight: FontWeight.bold,
          color: GameColors.uiHighlight, letterSpacing: 2)),
        const Spacer(),
        Text('${widget.player.gold}g', style: const TextStyle(
          fontFamily: 'monospace', fontSize: 13, fontWeight: FontWeight.bold,
          color: GameColors.uiHighlight)),
      ]),
    );
  }

  Widget _buildBuyView() {
    final available = widget.shop.stock.where((s) => !s.sold).toList();
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        child: Row(children: [
          _tabButton('BUY', !_sellMode, () => setState(() { _sellMode = false; _selectedIndex = null; })),
          const SizedBox(width: 6),
          _tabButton('SELL', _sellMode, () => setState(() { _sellMode = true; _selectedSellIndex = null; })),
        ]),
      ),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4, childAspectRatio: 1.8,
              crossAxisSpacing: 3, mainAxisSpacing: 3,
            ),
            itemCount: available.length,
            itemBuilder: (ctx, i) {
              final item = available[i];
              final canAfford = widget.player.gold >= item.price;
              final isSelected = _selectedIndex == i;
              final hasEnch = item.die.enchantment != null;
              return GestureDetector(
                onTap: () => setState(() => _selectedIndex = i),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isSelected ? item.die.tierColor.withOpacity(0.08) : Colors.transparent,
                    border: Border.all(
                      color: isSelected ? item.die.tierColor
                          : hasEnch ? EnchantmentColors.forEnchantment(item.die.enchantment!).withOpacity(0.3)
                          : const Color(0xFF2a2a2a),
                      width: isSelected ? 2 : 1),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Row(children: [
                    SizedBox(width: 32, height: 32, child: CustomPaint(
                      painter: MiniMaterialDiePainter(
                        value: (i % 6) + 1, material: item.die.material,
                        enchantment: item.die.enchantment),
                    )),
                    const SizedBox(width: 4),
                    Expanded(child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.die.name, style: TextStyle(
                          fontFamily: hasEnch ? 'serif' : 'monospace', fontSize: 8,
                          fontWeight: FontWeight.bold, color: item.die.tierColor,
                          fontStyle: hasEnch ? FontStyle.italic : FontStyle.normal),
                          overflow: TextOverflow.ellipsis, maxLines: 1),
                        Text('${item.price}g', style: TextStyle(fontFamily: 'monospace', fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: canAfford ? GameColors.uiHighlight : GameColors.uiDanger)),
                      ],
                    )),
                  ]),
                ),
              );
            },
          ),
        ),
      ),
      // Detail moved to side panel
    ]);
  }

  Widget _buildBuyDetail(ShopItem item) {
    final canAfford = widget.player.gold >= item.price;
    final matStat = DiceTiers.materialStatDesc(item.die.material);
    return Container(
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF0a0a14),
        border: Border.all(color: item.die.enchantment != null
            ? EnchantmentColors.forEnchantment(item.die.enchantment!).withOpacity(0.6)
            : item.die.tierColor.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item.die.name, style: TextStyle(fontFamily: 'monospace', fontSize: 12,
            fontWeight: FontWeight.bold, color: item.die.tierColor)),
          const SizedBox(height: 2),
          Text('Tier ${DiceTiers.tierLabel(item.die.tier)}: $matStat',
            style: TextStyle(fontFamily: 'monospace', fontSize: 9,
              color: item.die.tierColor.withOpacity(0.7))),
          if (item.die.enchantment != null) ...[
            const SizedBox(height: 2),
            Text('${DiceTiers.enchantmentName(item.die.enchantment!)}: ${DiceTiers.enchantmentDesc(item.die.enchantment!)}',
              style: TextStyle(fontFamily: 'monospace', fontSize: 9,
                color: EnchantmentColors.forEnchantment(item.die.enchantment!),
                fontWeight: FontWeight.bold)),
          ],
        ])),
        GestureDetector(
          onTap: canAfford ? () => _buyItem(item) : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: canAfford ? const Color(0xFF1a3a1a) : const Color(0xFF2a2a2a),
              border: Border.all(color: canAfford ? GameColors.uiSuccess : GameColors.uiMuted),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text('BUY ${item.price}g', style: TextStyle(fontFamily: 'monospace',
              fontSize: 12, fontWeight: FontWeight.bold,
              color: canAfford ? GameColors.uiSuccess : GameColors.uiMuted)),
          ),
        ),
      ]),
    );
  }

  void _buyItem(ShopItem item) {
    if (widget.player.gold < item.price) return;
    setState(() {
      widget.player.gold -= item.price;
      widget.player.dice.add(item.die);
      widget.player.rebuildDefaultLoadout();
      item.sold = true;
      _selectedIndex = null;
    });
    widget.onSave();
  }

  Widget _buildSellView() {
    final dice = widget.player.dice;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Row(children: [
          _tabButton('BUY', !_sellMode, () => setState(() { _sellMode = false; _selectedIndex = null; })),
          const SizedBox(width: 8),
          _tabButton('SELL', _sellMode, () => setState(() { _sellMode = true; _selectedSellIndex = null; })),
        ]),
      ),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 6, childAspectRatio: 0.8,
              crossAxisSpacing: 4, mainAxisSpacing: 4,
            ),
            itemCount: dice.length,
            itemBuilder: (ctx, i) {
              final die = dice[i];
              final price = ShopManager.sellPrice(die);
              final isSelected = _selectedSellIndex == i;
              return GestureDetector(
                onTap: () => setState(() => _selectedSellIndex = isSelected ? null : i),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected ? die.tierColor.withOpacity(0.1) : const Color(0xFF141018),
                    border: Border.all(
                      color: isSelected ? die.tierColor : const Color(0xFF2a2a2a), width: 1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    SizedBox(width: 28, height: 28, child: CustomPaint(
                      painter: MiniMaterialDiePainter(
                        value: (i % 6) + 1, material: die.material,
                        enchantment: die.enchantment),
                    )),
                    Text('${price}g', style: TextStyle(fontFamily: 'monospace', fontSize: 8,
                      color: price > 0 ? GameColors.uiHighlight : GameColors.uiMuted)),
                  ]),
                ),
              );
            },
          ),
        ),
      ),
      // Detail moved to side panel
    ]);
  }

  Widget _buildSellDetail(DiceItem die, int index) {
    final price = ShopManager.sellPrice(die);
    return Container(
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF0a0a14),
        border: Border.all(color: die.tierColor.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(die.name, style: TextStyle(fontFamily: 'monospace', fontSize: 12,
            fontWeight: FontWeight.bold, color: die.tierColor)),
          Text('Sell for ${price}g (40% value)',
            style: const TextStyle(fontFamily: 'monospace', fontSize: 9, color: GameColors.uiText)),
        ])),
        GestureDetector(
          onTap: price > 0 ? () => _sellItem(index) : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF3a1a1a),
              border: Border.all(color: GameColors.uiDanger.withOpacity(0.7)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text('SELL ${price}g', style: const TextStyle(fontFamily: 'monospace',
              fontSize: 12, fontWeight: FontWeight.bold, color: GameColors.uiDanger)),
          ),
        ),
      ]),
    );
  }

  void _sellItem(int index) {
    if (widget.player.dice.length <= 6) return; // can't sell below 6
    final die = widget.player.dice[index];
    final price = ShopManager.sellPrice(die);
    setState(() {
      widget.player.gold += price;
      widget.player.dice.removeAt(index);
      widget.player.rebuildDefaultLoadout();
      _selectedSellIndex = null;
    });
    widget.onSave();
  }

  Widget _tabButton(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? GameColors.uiHighlight.withOpacity(0.15) : Colors.transparent,
          border: Border.all(color: active ? GameColors.uiHighlight : GameColors.uiMuted),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(label, style: TextStyle(fontFamily: 'monospace', fontSize: 11,
          fontWeight: FontWeight.bold,
          color: active ? GameColors.uiHighlight : GameColors.uiMuted)),
      ),
    );
  }

  Widget _buildShopDetailPanel() {
    DiceItem? die;
    int? price;
    bool isBuyMode = !_sellMode;

    if (isBuyMode) {
      final available = widget.shop.stock.where((s) => !s.sold).toList();
      if (_selectedIndex != null && _selectedIndex! < available.length) {
        die = available[_selectedIndex!].die;
        price = available[_selectedIndex!].price;
      }
    } else {
      if (_selectedSellIndex != null && _selectedSellIndex! < widget.player.dice.length) {
        die = widget.player.dice[_selectedSellIndex!];
        price = ShopManager.sellPrice(die);
      }
    }

    if (die == null) {
      return const Center(child: Text('Select a die\nto view details',
        textAlign: TextAlign.center,
        style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: GameColors.uiMuted)));
    }

    return Align(
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(8),
        child: DiceDetailPanel(
          die: die,
          price: price,
          showBuyButton: true,
          canAfford: isBuyMode
              ? widget.player.gold >= (price ?? 0)
              : widget.player.dice.length > 6,
          onBuy: isBuyMode
              ? () {
                  final available = widget.shop.stock.where((s) => !s.sold).toList();
                  if (_selectedIndex! < available.length) _buyItem(available[_selectedIndex!]);
                }
              : () { if (_selectedSellIndex != null) _sellItem(_selectedSellIndex!); },
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: GameColors.uiBorder, width: 2)),
      ),
      child: Row(children: [
        const Text('← → ↑ ↓ Browse   E Buy/Sell   TAB Mode   ESC Close',
          style: TextStyle(fontFamily: 'monospace', fontSize: 9, color: GameColors.uiMuted)),
        const Spacer(),
        GestureDetector(
          onTap: widget.onClose,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(color: GameColors.uiBorder, width: 2),
              borderRadius: BorderRadius.circular(2),
              color: const Color(0xFF2a1a00),
            ),
            child: const Text('CLOSE', style: TextStyle(fontFamily: 'monospace',
              fontSize: 13, fontWeight: FontWeight.bold, color: GameColors.uiHighlight)),
          ),
        ),
      ]),
    );
  }
}
