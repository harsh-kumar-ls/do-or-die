import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Every moment that gets a sound, each paired with a haptic.
enum Cue {
  tap('tap'),
  window('window'),
  confirm('confirm'),
  timerStart('timer_start'),
  timerStop('timer_stop'),
  rep('rep'),
  notice('notice'),
  levelUp('level_up'),
  penalty('penalty'),
  gateOpen('gate_open'),
  rankUp('rank_up'),
  dungeonPenalty('dungeon_penalty');

  const Cue(this.file);
  final String file;
}

/// Sound and haptic feedback. Silent until [init] succeeds, so tests and
/// platforms without audio simply get no sound.
class Fx {
  Fx._();
  static final Fx instance = Fx._();

  static const _muteKey = 'doordie.sound.muted';

  final _sources = <Cue, AudioSource>{};
  final _muted = ValueNotifier(false);
  SharedPreferencesAsync? _prefs;
  bool _ready = false;

  /// Whether sound is muted. Haptics still play.
  ValueListenable<bool> get muted => _muted;

  Future<void> init(SharedPreferencesAsync prefs) async {
    _prefs = prefs;
    _muted.value = await prefs.getBool(_muteKey) ?? false;
    try {
      await SoLoud.instance.init();
      for (final cue in Cue.values) {
        _sources[cue] = await SoLoud.instance.loadAsset(
          'assets/sfx/${cue.file}.wav',
        );
      }
      _ready = true;
    } catch (e) {
      debugPrint('Sound unavailable: $e');
    }
  }

  Future<void> setMuted(bool value) async {
    _muted.value = value;
    await _prefs?.setBool(_muteKey, value);
  }

  void play(Cue cue) {
    _haptic(cue);
    if (!_ready || _muted.value) return;
    final source = _sources[cue];
    if (source == null) return;
    SoLoud.instance.play(source, volume: _volume(cue));
  }

  static double _volume(Cue cue) => switch (cue) {
    Cue.tap => .45,
    Cue.window => .7,
    Cue.penalty || Cue.dungeonPenalty => 1.0,
    Cue.gateOpen || Cue.rankUp => .95,
    Cue.levelUp => .9,
    _ => .7,
  };

  static void _haptic(Cue cue) {
    switch (cue) {
      case Cue.tap:
      case Cue.window:
        HapticFeedback.selectionClick();
      case Cue.timerStart:
      case Cue.timerStop:
      case Cue.rep:
        HapticFeedback.lightImpact();
      case Cue.confirm:
      case Cue.notice:
        HapticFeedback.mediumImpact();
      case Cue.levelUp:
      case Cue.rankUp:
      case Cue.gateOpen:
        HapticFeedback.heavyImpact();
        Future.delayed(
          const Duration(milliseconds: 160),
          HapticFeedback.heavyImpact,
        );
      case Cue.penalty:
        HapticFeedback.vibrate();
      case Cue.dungeonPenalty:
        HapticFeedback.vibrate();
        Future.delayed(
          const Duration(milliseconds: 320),
          HapticFeedback.vibrate,
        );
    }
  }
}
