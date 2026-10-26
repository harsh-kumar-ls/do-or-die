import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../domain/dungeon.dart';
import '../../domain/progression.dart';
import '../game_model.dart';
import '../theme.dart';
import '../widgets/hud_controls.dart';
import '../widgets/system_window.dart';

class StatusScreen extends StatelessWidget {
  const StatusScreen({
    super.key,
    required this.model,
    this.onOpenDiagnostics,
    this.onRestartTrial,
    this.onOpenSystemCheck,
    this.onChooseSystem,
    this.onOpenReport,
  });

  /// Opens the System Check screen.
  final VoidCallback? onOpenSystemCheck;

  /// Archives this game and returns to the Awakening.
  final Future<void> Function()? onRestartTrial;

  /// Opens the next-System choice (only once the current one is complete).
  final VoidCallback? onChooseSystem;

  /// Opens the 30-day report.
  final VoidCallback? onOpenReport;

  final GameModel model;
  final VoidCallback? onOpenDiagnostics;

  /// Where the user stands on the way to the next Gate.
  static String gateLine(GameModel m) {
    final sys = m.systems;
    if (sys == null || sys.active == null) return '—';
    if (sys.progress.completed.contains(sys.active)) return 'SYSTEM COMPLETE';
    if (m.rank == Rank.s) {
      return 'HOLD S · ${sys.sHold} / ${SystemsState.catalogueHoldDays}';
    }
    final floor = m.floorToday;
    if (floor > 0) {
      return floor == 3 ? 'RANK TRIAL TODAY' : 'FLOOR $floor TODAY';
    }
    if (sys.dungeon != null) return 'DUNGEON FROM TOMORROW';
    if (m.gate != null) return 'OPEN · ENTER ON QUEST';
    if (m.gateBlockedDays > 0) return 'SHUT · ${m.gateBlockedDays} DAYS';
    return '${m.clearedInWindow} / ${DungeonRules.clearedNeeded} CLEARED';
  }

  @override
  Widget build(BuildContext context) {
    final p = HudScope.of(context);
    final s = model.state;
    final spec = model.systemSpec;
    final sys = model.systems;
    final rankColor = Hud.rankColor(model.rank);

    final rank = Column(
      children: [
        Text(
          model.rank.name.toUpperCase(),
          textAlign: TextAlign.center,
          style: Hud.head(76, sys == null ? p.hi : rankColor, spacing: 0)
              .copyWith(
                height: 1,
                shadows: [
                  Shadow(
                    color: (sys == null ? p.sys : rankColor).withValues(
                      alpha: .7,
                    ),
                    blurRadius: p.glow * 2.4,
                  ),
                ],
              ),
        ),
        const SizedBox(height: 4),
        Text(
          spec == null ? 'RANK' : '${spec.name.toUpperCase()} · RANK',
          textAlign: TextAlign.center,
          style: Hud.mono(12, p.dim, spacing: .2),
        ),
        if (sys != null && sys.titles.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            sys.titles.last,
            textAlign: TextAlign.center,
            style: Hud.mono(11, Hud.gold, spacing: .08),
          ),
        ],
      ],
    );

    final rows = Column(
      children: [
        _kv(p, 'LEVEL', '${s.level}'),
        _kv(p, 'EXPERIENCE', '${s.xp} / ${model.xpToNext}'),
        if (sys != null) _kv(p, 'NEXT GATE', gateLine(model)),
        _kv(p, 'CURRENT STREAK', '${_streak(model)} days'),
        _kv(p, 'TRIAL DAY', '${model.service.trialDay} / 30'),
        _kv(p, 'PENALTIES', model.trialMode),
        if (sys != null && sys.active != null && !model.canChooseSystem)
          _ReductionRow(model: model),
      ],
    );

    final footer = <Widget>[
      if (model.canChooseSystem && onChooseSystem != null) ...[
        const SizedBox(height: 8),
        HudButton('CHOOSE NEXT SYSTEM', onPressed: onChooseSystem),
      ],
      if (onOpenReport != null || onOpenSystemCheck != null) ...[
        const SizedBox(height: 8),
        Row(
          children: [
            if (onOpenReport != null)
              Expanded(
                child: HudButton(
                  'REPORT',
                  dense: true,
                  onPressed: onOpenReport,
                ),
              ),
            if (onOpenReport != null && onOpenSystemCheck != null)
              const SizedBox(width: 8),
            if (onOpenSystemCheck != null)
              Expanded(
                child: HudButton(
                  model.systemIssues == 0
                      ? 'SYSTEM CHECK'
                      : 'CHECK · ${model.systemIssues} TO FIX',
                  dense: true,
                  onPressed: onOpenSystemCheck,
                ),
              ),
          ],
        ),
      ],
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
    ];

    Widget tile(Stat stat) => Expanded(
      child: SizedBox(
        height: 56,
        child: _StatTile(
          stat: stat,
          value: s.stats[stat] ?? 0,
          canSpend: s.unspentStatPoints > 0,
          onSpend: () => model.allocateStat(stat),
        ),
      ),
    );

    final attributes = SystemWindow(
      title: 'ATTRIBUTES',
      delay: const Duration(milliseconds: 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              tile(Stat.strength),
              const SizedBox(width: 8),
              tile(Stat.vitality),
              const SizedBox(width: 8),
              tile(Stat.intellect),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              tile(Stat.charisma),
              const SizedBox(width: 8),
              tile(Stat.discipline),
              const SizedBox(width: 8),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${s.unspentStatPoints}',
                        style: Hud.head(
                          22,
                          s.unspentStatPoints > 0 ? Hud.gold : p.dim,
                          spacing: 0,
                        ),
                      ),
                      Text('POINTS', style: Hud.mono(10, p.dim, spacing: .14)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, c) => _SevenTaps(
        onTriggered: onOpenDiagnostics,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 16),
          child: ConstrainedBox(
            // At least the screen's height, so the Status window can stretch
            // to fill spare space; taller content makes the page scroll.
            constraints: BoxConstraints(minHeight: c.maxHeight - 20),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: SystemWindow(
                      expand: true,
                      title: '[ STATUS ]',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          rank,
                          const Spacer(),
                          const SizedBox(height: 10),
                          rows,
                          const Spacer(),
                          ...footer,
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  attributes,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Widget _kv(HudPalette p, String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Text(k, style: Hud.mono(12, p.dim, spacing: .06)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            v,
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Hud.mono(12, p.text, weight: FontWeight.w500),
          ),
        ),
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
    Stat.charisma: 'CHA',
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

/// The reduction valve: lower tomorrow's quest by 0, 10 or 20 percent for an
/// injury or illness. Those days earn half XP.
class _ReductionRow extends StatelessWidget {
  const _ReductionRow({required this.model});

  final GameModel model;

  @override
  Widget build(BuildContext context) {
    final p = HudScope.of(context);
    final tomorrow = model.reductionTomorrow;
    final today = model.reductionToday;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'QUEST REDUCTION',
                  style: Hud.mono(13, p.dim, spacing: .06),
                ),
                Text(
                  today == tomorrow
                      ? (today == 0 ? 'Full quest' : 'Today $today% · half XP')
                      : 'Tomorrow $tomorrow%${tomorrow > 0 ? ' · half XP' : ''}',
                  style: Hud.mono(10, tomorrow > 0 ? Hud.warn : p.dim),
                ),
              ],
            ),
          ),
          for (final pct in const [0, 10, 20]) ...[
            const SizedBox(width: 6),
            Semantics(
              button: true,
              selected: tomorrow == pct,
              label: 'Reduce quest by $pct percent from tomorrow',
              child: GestureDetector(
                onTap: () => model.setReduction(pct),
                child: Container(
                  width: 42,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: tomorrow == pct
                        ? p.sys.withValues(alpha: .18)
                        : Colors.transparent,
                    border: Border.all(color: tomorrow == pct ? p.sys : p.line),
                  ),
                  child: Text(
                    '$pct%',
                    style: Hud.mono(11, tomorrow == pct ? p.hi : p.dim),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
