import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../domain/progression.dart';
import '../game_model.dart';
import '../theme.dart';
import '../widgets/fill_column.dart';
import '../widgets/hud_controls.dart';
import '../widgets/system_window.dart';

class StatusScreen extends StatelessWidget {
  const StatusScreen({
    super.key,
    required this.model,
    this.onOpenDiagnostics,
    this.onRestartTrial,
  });

  /// Archives this game and starts a fresh trial (with a dry run).
  final Future<void> Function()? onRestartTrial;

  final GameModel model;
  final VoidCallback? onOpenDiagnostics;

  @override
  Widget build(BuildContext context) {
    final p = HudScope.of(context);
    final s = model.state;
    final log = model.service.game.log;
    final cleared = log.where((e) => e.type == 'quest_cleared').length;
    final penalties = log.where((e) => e.type == 'penalty_issued').length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _SevenTaps(
              onTriggered: onOpenDiagnostics,
              child: SystemWindow(
                expand: true,
                title: '[ STATUS ]',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: FillColumn(
                        children: [
                          Column(
                            children: [
                              Text(
                                model.rank.name.toUpperCase(),
                                textAlign: TextAlign.center,
                                style: Hud.head(
                                  84,
                                  p.hi,
                                  spacing: 0,
                                ).copyWith(height: 1, shadows: p.textGlow(2.4)),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'RANK',
                                textAlign: TextAlign.center,
                                style: Hud.mono(12, p.dim, spacing: .2),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              _kv(p, 'LEVEL', '${s.level}'),
                              _kv(
                                p,
                                'EXPERIENCE',
                                '${s.xp} / ${model.xpToNext}',
                              ),
                              _kv(p, 'QUESTS CLEARED', '$cleared'),
                              _kv(
                                p,
                                'CURRENT STREAK',
                                '${_streak(model)} days',
                              ),
                              _kv(p, 'PENALTIES SERVED', '$penalties'),
                              _kv(
                                p,
                                'TRIAL DAY',
                                '${model.service.trialDay} / 30',
                              ),
                              _kv(p, 'PENALTIES', model.trialMode),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Pinned below the scrollable rows so it's never hidden.
                    if (onRestartTrial != null) ...[
                      Container(
                        height: 1,
                        margin: const EdgeInsets.only(top: 8, bottom: 10),
                        color: p.sys.withValues(alpha: p.lineAlpha * .6),
                      ),
                      if (model.restartBlockedReason case final reason?)
                        Text(
                          reason,
                          textAlign: TextAlign.center,
                          style: Hud.mono(11, Hud.warn),
                        )
                      else
                        HoldButton(
                          label: 'HOLD 3S · RESTART TRIAL',
                          doneLabel: 'RESTARTING',
                          holdFor: const Duration(seconds: 3),
                          onConfirmed: onRestartTrial!,
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SystemWindow(
            title: 'ATTRIBUTES',
            delay: const Duration(milliseconds: 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 2.2,
                  children: [
                    for (final stat in Stat.values)
                      _StatTile(
                        stat: stat,
                        value: s.stats[stat] ?? 0,
                        canSpend: s.unspentStatPoints > 0,
                        onSpend: () => model.allocateStat(stat),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                _kv(p, 'AVAILABLE POINTS', '${s.unspentStatPoints}'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _kv(HudPalette p, String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(k, style: Hud.mono(13, p.dim, spacing: .06)),
        Text(v, style: Hud.mono(13, p.text, weight: FontWeight.w500)),
      ],
    ),
  );

  /// Consecutive cleared days ending with the most recent judged day.
  static int _streak(GameModel m) {
    final judged = <String, bool>{};
    for (final e in m.service.game.log) {
      if (e.type == 'quest_cleared') judged[e.data['day'] as String] = true;
      if (e.type == 'quest_failed') judged[e.data['day'] as String] = false;
    }
    final days = judged.keys.toList()..sort();
    var streak = 0;
    for (final d in days.reversed) {
      if (judged[d] != true) break;
      streak++;
    }
    return streak;
  }
}

/// Fires [onTriggered] after 7 quick taps within 4 seconds, like Android's
/// hidden developer options. Holds never count, so a 3-second hold on a
/// button inside can't open anything by accident. Uses raw pointer events,
/// so it never competes with the buttons it wraps.
class _SevenTaps extends StatefulWidget {
  const _SevenTaps({required this.child, this.onTriggered});

  final Widget child;
  final VoidCallback? onTriggered;

  @override
  State<_SevenTaps> createState() => _SevenTapsState();
}

class _SevenTapsState extends State<_SevenTaps> {
  static const _needed = 7;
  static const _within = Duration(seconds: 4);
  static const _quickTap = Duration(milliseconds: 300);

  final _taps = <DateTime>[];
  DateTime? _downAt;

  void _up() {
    final down = _downAt;
    _downAt = null;
    if (down == null || widget.onTriggered == null) return;
    final now = DateTime.now();
    if (now.difference(down) > _quickTap) return; // a hold, not a tap
    _taps
      ..add(now)
      ..removeWhere((t) => now.difference(t) > _within);
    if (_taps.length >= _needed) {
      _taps.clear();
      widget.onTriggered!();
    }
  }

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: (_) => _downAt = DateTime.now(),
    onPointerUp: (_) => _up(),
    onPointerCancel: (_) => _downAt = null,
    child: widget.child,
  );
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.stat,
    required this.value,
    required this.canSpend,
    required this.onSpend,
  });

  final Stat stat;
  final int value;
  final bool canSpend;
  final VoidCallback onSpend;

  static const _short = {
    Stat.strength: 'STR',
    Stat.intellect: 'INT',
    Stat.discipline: 'DIS',
    Stat.vitality: 'VIT',
  };

  @override
  Widget build(BuildContext context) {
    final p = HudScope.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        border: Border.all(color: p.sys.withValues(alpha: .22)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_short[stat]!, style: Hud.mono(11, p.dim, spacing: .14)),
                Text('$value', style: Hud.head(22, p.text, spacing: 0))
                    .animate(key: ValueKey(value))
                    .tint(
                      color: p.hi,
                      begin: value == 0 ? 0 : .8,
                      end: 0,
                      duration: 600.ms,
                    ),
              ],
            ),
          ),
          Semantics(
            container: true,
            button: true,
            label: 'Add a point to ${stat.name}',
            child: GestureDetector(
              onTap: canSpend ? onSpend : null,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: canSpend ? 1 : .25,
                child: Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(border: Border.all(color: p.sys)),
                  child: Text('+', style: Hud.mono(14, p.hi)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
