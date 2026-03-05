import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fark_my_life/core/constants.dart';
import 'package:fark_my_life/core/enums.dart';
import 'package:fark_my_life/models/models.dart';
import 'package:fark_my_life/models/npc_definitions.dart';

/// Compact bottom-of-screen dialogue overlay for NPC conversations.
class DialogueScreen extends StatefulWidget {
  final NpcData npc;
  final PlayerData player;
  final List<DiceTableData> diceTables;
  final VoidCallback onClose;
  final void Function(NpcData npc, int betAmount) onChallenge;
  final void Function(DiceTableData table) onObserve;

  const DialogueScreen({
    super.key,
    required this.npc,
    required this.player,
    required this.diceTables,
    required this.onClose,
    required this.onChallenge,
    required this.onObserve,
  });

  @override
  State<DialogueScreen> createState() => _DialogueScreenState();
}


class _DialogueScreenState extends State<DialogueScreen> {
  final _rng = Random();
  late bool _isChallenge;
  late int _betAmount;
  String _chatText = '';
  List<int> get _betPresets {
    final max = _maxBet;
    final p = <int>[];
    for (final v in [5, 10, 15, 25, 50]) { if (v <= max) p.add(v); }
    if (max > 50 && (p.isEmpty || p.last != max)) p.add(max);
    return p;
  }
  int get _maxBet {
    final a = widget.player.gold, b = widget.npc.gold;
    return a < b ? a : b;
  }
  @override
  void initState() {
    super.initState();
    _isChallenge = widget.npc.state == NpcState.seated &&
        widget.npc.gold >= GameConstants.minBet &&
        widget.player.gold >= GameConstants.minBet;
    _betAmount = GameConstants.minBet;
    if (!_isChallenge) {
      _chatText = NpcDialogues.forType(widget.npc.type).randomBusy(_rng);
    }
  }
  @override
  Widget build(BuildContext context) {
    return FocusScope(
      autofocus: true,
      child: Focus(autofocus: true, onKeyEvent: (node, event) {
      if (event is KeyDownEvent) {
        if (event.logicalKey == LogicalKeyboardKey.escape) {
          widget.onClose(); return KeyEventResult.handled; }
        if (_isChallenge) {
          // Space/Enter: start game
          if (event.logicalKey == LogicalKeyboardKey.space ||
              event.logicalKey == LogicalKeyboardKey.enter) {
            widget.onChallenge(widget.npc, _betAmount);
            return KeyEventResult.handled; }

          // Arrow left/right: cycle through bet presets
          final presets = _betPresets;
          if (presets.isNotEmpty) {
            if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
                event.logicalKey == LogicalKeyboardKey.arrowDown) {
              final idx = presets.indexOf(_betAmount);
              final next = (idx + 1) % presets.length;
              setState(() => _betAmount = presets[next]);
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
                event.logicalKey == LogicalKeyboardKey.arrowUp) {
              final idx = presets.indexOf(_betAmount);
              final prev = (idx - 1 + presets.length) % presets.length;
              setState(() => _betAmount = presets[prev]);
              return KeyEventResult.handled;
            }
          }

          // Number keys: direct bet selection
          final label = event.logicalKey.keyLabel;
          if (label.length == 1) {
            final code = label.codeUnitAt(0);
            if (code >= 49 && code <= 57) {
              final idx = code - 49;
              if (idx < presets.length) {
                setState(() => _betAmount = presets[idx]);
                return KeyEventResult.handled; } } }
        } else { widget.onClose(); return KeyEventResult.handled; }
      }
      return KeyEventResult.ignored;
    }, child: GestureDetector(
      onTap: _isChallenge ? null : widget.onClose,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Color(0xF01a1008), Color(0xF0120c06)]),
          border: const Border(top: BorderSide(color: Color(0xFF5a4020), width: 2)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.7), blurRadius: 24, offset: const Offset(0, -8))]),
        child: _isChallenge ? _buildChallenge() : _buildChat(),
      ),
    )),
    );
  }
  Widget _buildChallenge() {
    final npc = widget.npc;
    final presets = _betPresets;
    return Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Container(width: 48, height: 48,
            decoration: BoxDecoration(
              border: Border.all(color: npc.primaryColor, width: 2),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [BoxShadow(color: npc.primaryColor.withOpacity(0.3), blurRadius: 8)]),
            child: ClipRRect(borderRadius: BorderRadius.circular(6),
              child: CustomPaint(painter: _InlinePortraitPainter(color: npc.primaryColor)))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(npc.name, style: TextStyle(color: npc.primaryColor, fontSize: 16,
              fontFamily: 'monospace', fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Row(children: [
              Text(npc.type.name.toUpperCase(), style: const TextStyle(color: Color(0xFF6a5a40),
                fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.w600, letterSpacing: 1)),
              Container(width: 3, height: 3, margin: const EdgeInsets.symmetric(horizontal: 6),
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF4a3a28))),
              Text('${npc.gold}g', style: const TextStyle(color: Color(0xFFb89868),
                fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.w600)),
            ]),
          ])),
          GestureDetector(onTap: () => widget.onChallenge(npc, _betAmount),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Color(0xFF2a5a2a), Color(0xFF1a3a1a)]),
                border: Border.all(color: const Color(0xFF44aa44), width: 2),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [BoxShadow(color: const Color(0xFF44aa44).withOpacity(0.3), blurRadius: 12)]),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('PLAY', style: TextStyle(color: Color(0xFF66dd66), fontSize: 16,
                  fontFamily: 'monospace', fontWeight: FontWeight.w900, letterSpacing: 2)),
                Text('${_betAmount}g', style: const TextStyle(color: Color(0xFF88cc88),
                  fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.w600)),
              ]))),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          const Text('WAGER', style: TextStyle(color: Color(0xFF6a5a40), fontSize: 10,
            fontFamily: 'monospace', fontWeight: FontWeight.w700, letterSpacing: 1.5)),
          const SizedBox(width: 10),
          Expanded(child: Wrap(spacing: 6, runSpacing: 4,
            children: List.generate(presets.length, (i) {
              final amt = presets[i];
              final sel = amt == _betAmount;
              final allIn = amt == _maxBet && amt > 50;
              return GestureDetector(onTap: () => setState(() => _betAmount = amt),
                child: AnimatedContainer(duration: const Duration(milliseconds: 120),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: sel ? const Color(0xFF2a1a08) : const Color(0xFF0a0804),
                    border: Border.all(color: sel ? const Color(0xFFd4b040) : const Color(0xFF3a2a18), width: sel ? 2 : 1),
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: sel ? [BoxShadow(color: const Color(0xFFd4b040).withOpacity(0.2), blurRadius: 8)] : null),
                  child: Text(allIn ? 'ALL IN (${amt}g)' : '${amt}g',
                    style: TextStyle(color: sel ? const Color(0xFFf0d860) : const Color(0xFF8a7a58),
                      fontSize: 12, fontFamily: 'monospace', fontWeight: sel ? FontWeight.w800 : FontWeight.w500))));
            }))),
          const SizedBox(width: 8),
          GestureDetector(onTap: widget.onClose,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: const Color(0xFF0a0804),
                border: Border.all(color: const Color(0xFF3a2a18), width: 1),
                borderRadius: BorderRadius.circular(6)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Text('BACK', style: TextStyle(color: Color(0xFF6a5a40), fontSize: 10,
                  fontFamily: 'monospace', fontWeight: FontWeight.w600)),
                SizedBox(width: 4),
                Text('ESC', style: TextStyle(color: Color(0xFF4a3a28), fontSize: 9,
                  fontFamily: 'monospace', fontWeight: FontWeight.w500)),
              ]))),
        ]),
        // Keyboard hints
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text('← → Bet   SPC Play   ESC Back',
            style: TextStyle(fontFamily: 'monospace', fontSize: 9,
              color: const Color(0xFF4a3a28))),
        ),
      ]));
  }
  Widget _buildChat() {
    final npc = widget.npc;
    return Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Container(width: 40, height: 40,
          decoration: BoxDecoration(border: Border.all(color: npc.primaryColor, width: 1.5),
            borderRadius: BorderRadius.circular(6)),
          child: ClipRRect(borderRadius: BorderRadius.circular(4.5),
            child: CustomPaint(painter: _InlinePortraitPainter(color: npc.primaryColor)))),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(npc.name, style: TextStyle(color: npc.primaryColor, fontSize: 13,
            fontFamily: 'monospace', fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(_chatText, style: const TextStyle(color: Color(0xFFb8a880), fontSize: 12,
            fontFamily: 'monospace', fontStyle: FontStyle.italic, height: 1.3)),
        ])),
        const SizedBox(width: 8),
        const Text('tap to close', style: TextStyle(color: Color(0xFF4a3a28), fontSize: 9, fontFamily: 'monospace')),
      ]));
  }
}

class _InlinePortraitPainter extends CustomPainter {
  final Color color;
  _InlinePortraitPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = const Color(0xFF0a0804));

    final headR = size.width * 0.3;
    final headY = cy - size.height * 0.05;

    // Body
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - headR * 1.3, headY + headR * 0.8,
            headR * 2.6, size.height),
        const Radius.circular(6)),
      Paint()..color = color,
    );

    // Head
    canvas.drawCircle(Offset(cx, headY), headR, Paint()..color = const Color(0xFFE8C498));

    // Hair
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, headY - 2), radius: headR),
      3.14, 3.14, true,
      Paint()..color = Color.lerp(color, Colors.brown, 0.5)!,
    );

    // Eyes
    final ep = Paint()..color = Colors.black;
    final es = headR * 0.35;
    final ey = headY - headR * 0.1;
    canvas.drawCircle(Offset(cx - es, ey), headR * 0.1, ep);
    canvas.drawCircle(Offset(cx + es, ey), headR * 0.1, ep);

    // Mouth
    ep.style = PaintingStyle.stroke;
    ep.strokeWidth = 1.2;
    canvas.drawArc(
      Rect.fromCenter(center: Offset(cx, headY + headR * 0.3),
          width: headR * 0.8, height: headR * 0.5),
      0, 3.14, false, ep,
    );
  }

  @override
  bool shouldRepaint(covariant _InlinePortraitPainter old) => old.color != color;
}
