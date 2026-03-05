import 'dart:math';
import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter
import 'dart:js_interop';
import 'package:web/web.dart' as web;

/// Procedural sound effects using Web Audio API.
/// All sounds are synthesized — no external files needed.
class GameAudio {
  GameAudio._();

  static web.AudioContext? _ctx;
  static bool _enabled = true;
  static final _rng = Random();

  static void init() {
    try {
      _ctx = web.AudioContext();
    } catch (_) {
      _enabled = false;
    }
  }

  static void toggle() => _enabled = !_enabled;
  static bool get enabled => _enabled;

  // ═══════════════════════════════════════════════════════════════════
  // 1. DICE ROLL — rattling bones on wood
  // ═══════════════════════════════════════════════════════════════════
  static void diceRoll() {
    if (!_enabled || _ctx == null) return;
    final ctx = _ctx!;
    final now = ctx.currentTime;
    // Multiple short noise bursts simulating dice bouncing
    for (int i = 0; i < 6; i++) {
      final t = now + i * 0.06 + _rng.nextDouble() * 0.02;
      _playNoise(ctx, t, 0.04 + _rng.nextDouble() * 0.02,
          0.08 - i * 0.01, 800 + _rng.nextInt(400).toDouble());
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // 2. DICE SELECT — soft click
  // ═══════════════════════════════════════════════════════════════════
  static void diceSelect() {
    if (!_enabled || _ctx == null) return;
    final ctx = _ctx!;
    _playTone(ctx, ctx.currentTime, 0.05, 600, 0.08, 'sine');
    _playTone(ctx, ctx.currentTime + 0.02, 0.03, 900, 0.05, 'sine');
  }

  // ═══════════════════════════════════════════════════════════════════
  // 3. CHAIR SCOOT — scraping wood
  // ═══════════════════════════════════════════════════════════════════
  static void chairScoot() {
    if (!_enabled || _ctx == null) return;
    final ctx = _ctx!;
    final now = ctx.currentTime;
    _playNoise(ctx, now, 0.15, 0.06, 300);
    _playTone(ctx, now, 0.12, 120, 0.04, 'sawtooth');
  }

  // ═══════════════════════════════════════════════════════════════════
  // 4. BUST — low thud + descending tone
  // ═══════════════════════════════════════════════════════════════════
  static void bust() {
    if (!_enabled || _ctx == null) return;
    final ctx = _ctx!;
    final now = ctx.currentTime;
    _playTone(ctx, now, 0.3, 150, 0.12, 'sine');
    _playTone(ctx, now + 0.05, 0.25, 100, 0.08, 'sine');
    _playNoise(ctx, now, 0.1, 0.06, 200);
  }

  // ═══════════════════════════════════════════════════════════════════
  // 5. SCORE/BANK — satisfying cha-ching
  // ═══════════════════════════════════════════════════════════════════
  static void score() {
    if (!_enabled || _ctx == null) return;
    final ctx = _ctx!;
    final now = ctx.currentTime;
    _playTone(ctx, now, 0.08, 800, 0.07, 'sine');
    _playTone(ctx, now + 0.08, 0.08, 1000, 0.06, 'sine');
    _playTone(ctx, now + 0.16, 0.12, 1200, 0.05, 'sine');
  }

  // ═══════════════════════════════════════════════════════════════════
  // 6. VICTORY — triumphant ascending fanfare
  // ═══════════════════════════════════════════════════════════════════
  static void victory() {
    if (!_enabled || _ctx == null) return;
    final ctx = _ctx!;
    final now = ctx.currentTime;
    final notes = [523.0, 659.0, 784.0, 1047.0]; // C5 E5 G5 C6
    for (int i = 0; i < notes.length; i++) {
      _playTone(ctx, now + i * 0.12, 0.2, notes[i], 0.08, 'sine');
      _playTone(ctx, now + i * 0.12, 0.15, notes[i] * 1.5, 0.03, 'sine');
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // 7. DEFEAT — descending minor tones
  // ═══════════════════════════════════════════════════════════════════
  static void defeat() {
    if (!_enabled || _ctx == null) return;
    final ctx = _ctx!;
    final now = ctx.currentTime;
    final notes = [440.0, 392.0, 349.0, 330.0]; // A4 G4 F4 E4
    for (int i = 0; i < notes.length; i++) {
      _playTone(ctx, now + i * 0.15, 0.25, notes[i], 0.06, 'sine');
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // 8. GOLD CLINK — coins
  // ═══════════════════════════════════════════════════════════════════
  static void goldClink() {
    if (!_enabled || _ctx == null) return;
    final ctx = _ctx!;
    final now = ctx.currentTime;
    _playTone(ctx, now, 0.06, 2400, 0.04, 'sine');
    _playTone(ctx, now + 0.07, 0.05, 2800, 0.03, 'sine');
    _playTone(ctx, now + 0.13, 0.04, 3200, 0.02, 'sine');
  }

  // ═══════════════════════════════════════════════════════════════════
  // 9. ROYAL FANFARE — regal trumpet announcement (lists opening)
  // ═══════════════════════════════════════════════════════════════════
  static void tournamentHorn() {
    if (!_enabled || _ctx == null) return;
    final ctx = _ctx!;
    final now = ctx.currentTime;
    // Three-part royal trumpet fanfare
    // First call: attention
    _playTone(ctx, now, 0.25, 349, 0.07, 'sawtooth');         // F4
    _playTone(ctx, now, 0.25, 349 * 1.5, 0.03, 'sawtooth');   // harmony
    // Second call: rising
    _playTone(ctx, now + 0.28, 0.15, 440, 0.07, 'sawtooth');  // A4
    _playTone(ctx, now + 0.28, 0.15, 440 * 1.5, 0.03, 'sawtooth');
    // Third call: triumphant hold
    _playTone(ctx, now + 0.45, 0.5, 523, 0.08, 'sawtooth');   // C5
    _playTone(ctx, now + 0.45, 0.45, 659, 0.04, 'sawtooth');  // E5 harmony
    _playTone(ctx, now + 0.45, 0.4, 784, 0.03, 'sawtooth');   // G5 top
    // Reverb tail: quiet echo
    _playTone(ctx, now + 0.95, 0.3, 523, 0.02, 'sine');
    _playTone(ctx, now + 0.95, 0.25, 659, 0.015, 'sine');
  }

  // ═══════════════════════════════════════════════════════════════════
  // 9b. TOURNAMENT MATCH START — short herald
  // ═══════════════════════════════════════════════════════════════════
  static void matchStart() {
    if (!_enabled || _ctx == null) return;
    final ctx = _ctx!;
    final now = ctx.currentTime;
    _playTone(ctx, now, 0.12, 523, 0.06, 'sawtooth');       // C5
    _playTone(ctx, now + 0.12, 0.12, 659, 0.06, 'sawtooth'); // E5
    _playTone(ctx, now + 0.24, 0.2, 784, 0.07, 'sawtooth');  // G5
  }

  // ═══════════════════════════════════════════════════════════════════
  // 9c. TOURNAMENT CHAMPION — grand coronation fanfare
  // ═══════════════════════════════════════════════════════════════════
  static void tournamentChampion() {
    if (!_enabled || _ctx == null) return;
    final ctx = _ctx!;
    final now = ctx.currentTime;
    // Majestic brass chord progression
    _playTone(ctx, now, 0.3, 262, 0.06, 'sawtooth');          // C4
    _playTone(ctx, now, 0.3, 330, 0.05, 'sawtooth');          // E4
    _playTone(ctx, now, 0.3, 392, 0.04, 'sawtooth');          // G4
    // Step up
    _playTone(ctx, now + 0.35, 0.3, 349, 0.06, 'sawtooth');   // F4
    _playTone(ctx, now + 0.35, 0.3, 440, 0.05, 'sawtooth');   // A4
    _playTone(ctx, now + 0.35, 0.3, 523, 0.04, 'sawtooth');   // C5
    // Final grand chord
    _playTone(ctx, now + 0.7, 0.6, 523, 0.08, 'sawtooth');    // C5
    _playTone(ctx, now + 0.7, 0.6, 659, 0.06, 'sawtooth');    // E5
    _playTone(ctx, now + 0.7, 0.6, 784, 0.05, 'sawtooth');    // G5
    _playTone(ctx, now + 0.7, 0.55, 1047, 0.03, 'sawtooth');  // C6
    // Shimmering overtone
    _playTone(ctx, now + 0.7, 0.4, 1568, 0.015, 'sine');      // G6
  }

  // ═══════════════════════════════════════════════════════════════════
  // 9d. ENTRANT JOINS — short heraldic note
  // ═══════════════════════════════════════════════════════════════════
  static void entrantJoin() {
    if (!_enabled || _ctx == null) return;
    final ctx = _ctx!;
    _playTone(ctx, ctx.currentTime, 0.1, 523, 0.04, 'sawtooth');
    _playTone(ctx, ctx.currentTime + 0.08, 0.08, 659, 0.03, 'sine');
  }

  // ═══════════════════════════════════════════════════════════════════
  // 9e. TOURNAMENT ELIMINATED — somber horn
  // ═══════════════════════════════════════════════════════════════════
  static void tournamentEliminated() {
    if (!_enabled || _ctx == null) return;
    final ctx = _ctx!;
    final now = ctx.currentTime;
    _playTone(ctx, now, 0.3, 330, 0.05, 'sawtooth');       // E4
    _playTone(ctx, now + 0.3, 0.25, 294, 0.04, 'sawtooth'); // D4
    _playTone(ctx, now + 0.55, 0.4, 262, 0.05, 'sawtooth'); // C4 (low resolve)
  }

  // ═══════════════════════════════════════════════════════════════════
  // 10. HOT DICE — exciting sizzle
  // ═══════════════════════════════════════════════════════════════════
  static void hotDice() {
    if (!_enabled || _ctx == null) return;
    final ctx = _ctx!;
    final now = ctx.currentTime;
    for (int i = 0; i < 8; i++) {
      _playTone(ctx, now + i * 0.04, 0.06, 1000 + i * 200.0, 0.04, 'sine');
    }
    _playNoise(ctx, now, 0.2, 0.03, 4000);
  }

  // ═══════════════════════════════════════════════════════════════════
  // 11. LOOT DROP — magical shimmer
  // ═══════════════════════════════════════════════════════════════════
  static void lootDrop() {
    if (!_enabled || _ctx == null) return;
    final ctx = _ctx!;
    final now = ctx.currentTime;
    final notes = [880.0, 1109.0, 1319.0, 1568.0, 1760.0];
    for (int i = 0; i < notes.length; i++) {
      _playTone(ctx, now + i * 0.08, 0.15, notes[i], 0.04, 'sine');
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // 12. UI CLICK — menu navigation
  // ═══════════════════════════════════════════════════════════════════
  static void uiClick() {
    if (!_enabled || _ctx == null) return;
    _playTone(_ctx!, _ctx!.currentTime, 0.03, 1000, 0.04, 'square');
  }

  // ═══════════════════════════════════════════════════════════════════
  // SYNTHESIS HELPERS
  // ═══════════════════════════════════════════════════════════════════

  static void _playTone(web.AudioContext ctx, double startTime, double duration,
      double freq, double volume, String waveType) {
    final osc = ctx.createOscillator();
    final gain = ctx.createGain();
    osc.type = waveType;
    osc.frequency.setValueAtTime(freq, startTime);
    gain.gain.setValueAtTime(volume, startTime);
    gain.gain.exponentialRampToValueAtTime(0.001, startTime + duration);
    osc.connect(gain);
    gain.connect(ctx.destination);
    osc.start(startTime);
    osc.stop(startTime + duration + 0.01);
  }

  static void _playNoise(web.AudioContext ctx, double startTime, double duration,
      double volume, double filterFreq) {
    final sampleRate = ctx.sampleRate.toInt();
    final frameCount = (duration * sampleRate).toInt();
    final buffer = ctx.createBuffer(1, frameCount, sampleRate.toDouble());
    final data = buffer.getChannelData(0);
    // Fill with white noise using toDart for Float32List access
    final rng = Random();
    for (int i = 0; i < frameCount; i++) {
      data.toDart[i] = (rng.nextDouble() * 2 - 1) * volume;
    }
    final source = ctx.createBufferSource();
    source.buffer = buffer;
    // Low-pass filter for texture
    final filter = ctx.createBiquadFilter();
    filter.type = 'lowpass';
    filter.frequency.setValueAtTime(filterFreq, startTime);
    source.connect(filter);
    filter.connect(ctx.destination);
    source.start(startTime);
  }
}
