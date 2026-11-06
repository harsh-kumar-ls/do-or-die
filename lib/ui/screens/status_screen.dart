import 'dart:math';

import 'package:flutter/material.dart';

import '../../domain/dungeon.dart';
import '../../domain/progression.dart';
import '../../domain/systems.dart' show maxReducedDays, reductionWindowDays;
import '../game_model.dart';
import '../theme.dart';
import '../widgets/hud_kit.dart';
import '../widgets/player_avatar.dart';
import '../widgets/system_frame.dart';

/// Status, built from design/claude-design/status.html: rank hero, core
/// rows and the Gate ring, the reduction valve, report and system check,
/// and attributes with pending points confirmed in one go.
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

  final GameModel model;

  /// Opened by seven quick taps (hidden diagnostics).
  final VoidCallback? onOpenDiagnostics;

  /// Kept for the System Check screen, which now holds the restart.
  final Future<void> Function()? onRestartTrial;
  final VoidCallback? onOpenSystemCheck;
  final VoidCallback? onChooseSystem;
  final VoidCallback? onOpenReport;

  /// Where the user stands on the way to the next Gate (ring label).
  static String gateLine(GameModel m) {
    final sys = m.systems;
    if (sys == null || sys.active == null) return '—';
    if (sys.progress.completed.contains(sys.active)) return 'SYSTEM COMPLETE';
    if (m.rank == Rank.s) {
      return 'HOLD S · ${sys.sHold} / ${SystemsState.catalogueHoldDays}';
    }
    final floor = m.floorToday;
    if (floor > 0) {
      return floor == 3 ? 'RANK TRIAL TODAY' : 'DUNGEON · FLOOR $floor';
    }
    if (sys.dungeon != null) return 'DUNGEON FROM TOMORROW';
    if (m.gate != null) return 'GATE OPEN · ENTER ON QUEST';
    if (m.gateBlockedDays > 0) return 'GATE SHUT · ${m.gateBlockedDays} DAYS';
    return 'NEXT GATE · ${m.clearedInWindow} / ${DungeonRules.clearedNeeded}';
  }

  /// (current, best) streaks of cleared days, from the log.
  static (int, int) streaks(GameModel m) {
    final judged = <String, bool>{};
    for (final e in m.service.game.log) {
      if (e.type == 'quest_cleared') judged[e.data['day'] as String] = true;
      if (e.type == 'quest_failed') judged[e.data['day'] as String] = false;
    }
    final days = judged.keys.toList()..sort();
    var best = 0, run = 0;
    for (final d in days) {
      run = judged[d]! ? run + 1 : 0;
      best = max(best, run);
    }
    var cur = 0;
    for (final d in days.reversed) {
      if (judged[d] != true) break;
      cur++;
    }
    return (cur, best);
  }

  @override
  Widget build(BuildContext context) {
    final p = HudScope.of(context);
    final s = model.state;
    final spec = model.systemSpec;
    final sys = model.systems;
    final (streak, best) = streaks(model);
    final dry = model.service.isDryRunToday;
    final trainedStats = spec?.stats.toSet() ?? Stat.values.toSet();

    final look = playerLook(model);
    final hero = SizedBox(
      height: 150,
      child: Row(
        children: [
          SizedBox(
            width: 124,
            child: Stack(
              fit: StackFit.expand,
              children: [
                PlayerAvatar(look: look),
                Positioned(
                  right: 0,
                  bottom: 4,
                  child: IgnorePointer(
                    child: RankHexSmall(rank: model.rank, width: 40),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Kicker('Rank ${model.rank.name.toUpperCase()} · Player'),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    spec?.name.toUpperCase() ?? 'NO SYSTEM',
                    maxLines: 1,
                    style: Hud.head(17, p.text, spacing: .2),
                  ),
                ),
                const SizedBox(height: 8),
                Text('LATEST TITLE', style: Hud.mono(9, p.dim, spacing: .2)),
                const SizedBox(height: 2),
                Text(
                  sys == null || sys.titles.isEmpty ? '—' : sys.titles.last,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Hud.head(14, Hud.gold, spacing: .08).copyWith(
                    shadows: [
                      Shadow(
                        color: Hud.gold.withValues(alpha: .45),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    Widget row(String k, Widget v) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(k, style: Hud.mono(9, p.dim, spacing: .2)),
        const SizedBox(height: 1),
        v,
      ],
    );
    TextSpan big(String a, [String? small]) => TextSpan(
      text: a,
      style: Hud.mono(15, Colors.white, weight: FontWeight.w700),
      children: [
        if (small != null)
          TextSpan(text: ' $small', style: Hud.mono(11, p.dim)),
      ],
    );

    final core = Panel(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                row('LEVEL', Text.rich(big('${s.level}'))),
                const SizedBox(height: 9),
                row(
                  'EXPERIENCE',
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text.rich(big('${s.xp}', '/ ${model.xpToNext}')),
                      const SizedBox(height: 4),
                      XpBar(xp: s.xp, max: model.xpToNext, height: 4),
                    ],
                  ),
                ),
                const SizedBox(height: 9),
                row(
                  'CURRENT STREAK',
                  Text.rich(big('$streak', 'days · best $best')),
                ),
                const SizedBox(height: 9),
                row(
                  'TRIAL DAY',
                  Text.rich(
                    dry
                        ? big(
                            '${model.service.trialDay}',
                            '· dry run, no penalties',
                          )
                        : TextSpan(
                            text: 'LIVE',
                            style: Hud.mono(
                              15,
                              Hud.rankColor(Rank.d),
                              weight: FontWeight.w700,
                            ),
                            children: [
                              TextSpan(
                                text: ' · day ${model.service.trialDay}',
                                style: Hud.mono(11, p.dim),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 124,
            child: Column(
              children: [
                _GateRing(
                  cleared: model.clearedInWindow,
                  of: DungeonRules.clearedNeeded,
                ),
                const SizedBox(height: 2),
                Text(
                  gateLine(model),
                  textAlign: TextAlign.center,
                  style: Hud.mono(9, p.dim, spacing: .14),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return _SevenTaps(
      onTriggered: onOpenDiagnostics,
      child: LayoutBuilder(
        builder: (context, c) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: c.maxHeight - 20),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '[ STATUS ]',
                    textAlign: TextAlign.center,
                    style: Hud.head(
                      12,
                      p.hi,
                      spacing: .3,
                    ).copyWith(shadows: p.textGlow(.8)),
                  ),
                  const SizedBox(height: 8),
                  hero,
                  const SizedBox(height: 8),
                  core,
                  const SizedBox(height: 10),
                  if (model.canChooseSystem && onChooseSystem != null) ...[
                    CutButton('CHOOSE NEXT SYSTEM', onPressed: onChooseSystem),
                    const SizedBox(height: 10),
                  ] else if (sys != null && sys.active != null) ...[
                    _Reduction(model: model),
                    const SizedBox(height: 10),
                  ],
                  Row(
                    children: [
                      if (onOpenReport != null)
                        Expanded(
                          child: CutButton('REPORT', onPressed: onOpenReport),
                        ),
                      if (onOpenReport != null && onOpenSystemCheck != null)
                        const SizedBox(width: 8),
                      if (onOpenSystemCheck != null)
                        Expanded(
                          child: CutButton(
                            model.systemIssues == 0
                                ? 'SYSTEM CHECK'
                                : 'CHECK · ${model.systemIssues}',
                            danger: model.systemIssues > 0,
                            onPressed: onOpenSystemCheck,
                          ),
                        ),
                    ],
                  ),
                  const Spacer(),
                  const SizedBox(height: 10),
                  _Attributes(model: model, trained: trainedStats),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The rank letter's glow breathes 8 to 22 px over 3.2 s.
class _Breathing extends StatefulWidget {
  const _Breathing({required this.color, required this.child});
  final Color color;
  final Widget child;

  @override
  State<_Breathing> createState() => _BreathingState();
}

class _BreathingState extends State<_Breathing>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (context, child) => DefaultTextStyle.merge(
      style: TextStyle(
        shadows: [
          Shadow(color: widget.color, blurRadius: 8 + 6 * _c.value),
          Shadow(
            color: widget.color.withValues(alpha: .5 + .1 * _c.value),
            blurRadius: 22 + 18 * _c.value,
          ),
        ],
      ),
      child: child!,
    ),
    child: widget.child,
  );
}

/// 21 segments; cleared ones light gold in order on entry.
class _GateRing extends StatefulWidget {
  const _GateRing({required this.cleared, required this.of});
  final int cleared;
  final int of;

  @override
  State<_GateRing> createState() => _GateRingState();
}

class _GateRingState extends State<_GateRing>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: 120 + widget.of * 25 + 150),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = HudScope.of(context);
    return SizedBox(
      width: 124,
      height: 124,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
          painter: _RingSegments(
            cleared: widget.cleared,
            of: widget.of,
            lit: ((_c.value * _c.duration!.inMilliseconds - 120) / 25)
                .floor()
                .clamp(0, widget.of),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text.rich(
                  TextSpan(
                    text: '${widget.cleared}',
                    style: Hud.mono(22, Colors.white, weight: FontWeight.w700),
                    children: [
                      TextSpan(
                        text: ' / ${widget.of}',
                        style: Hud.mono(13, p.dim, weight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                Text('CLEARED', style: Hud.mono(8, p.dim, spacing: .18)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RingSegments extends CustomPainter {
  _RingSegments({required this.cleared, required this.of, required this.lit});
  final int cleared;
  final int of;
  final int lit;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width * 52 / 124;
    final step = 2 * pi / of;
    final gap = 2 * pi / 180;
    for (var i = 0; i < of; i++) {
      final on = i < cleared && i < lit;
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        -pi / 2 + i * step + gap,
        step - 2 * gap,
        false,
        Paint()
          ..color = on ? Hud.gold : const Color(0x387D8BA8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9
          ..maskFilter = on ? const MaskFilter.blur(BlurStyle.solid, 2) : null,
      );
    }
    final inner = Paint()
      ..color = const Color(0x384FB3FF)
      ..style = PaintingStyle.stroke;
    final innerR = size.width * 40 / 124;
    for (var a = 0.0; a < 2 * pi; a += 6 / innerR) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: innerR),
        a,
        2 / innerR,
        false,
        inner,
      );
    }
  }

  @override
  bool shouldRepaint(_RingSegments old) =>
      old.cleared != cleared || old.lit != lit || old.of != of;
}

/// Quest reduction: 0, 10 or 20 percent from tomorrow, at half XP. Locked
/// during a Dungeon (floors ignore it anyway).
class _Reduction extends StatelessWidget {
  const _Reduction({required this.model});
  final GameModel model;

  @override
  Widget build(BuildContext context) {
    final p = HudScope.of(context);
    final tomorrow = model.reductionTomorrow;
    final locked = model.service.dungeonInProgress;
    final caption = locked
        ? 'Locked during the Dungeon. Floors use the full quest.'
        : model.reductionLimitedTomorrow
        ? 'Limit reached · $maxReducedDays reduced days in $reductionWindowDays. Full quest tomorrow.'
        : tomorrow == 0
        ? (model.reductionToday == 0
              ? 'Full quest · full XP.'
              : 'Today ${model.reductionToday}% · back to the full quest tomorrow.')
        : '−$tomorrow% targets · applies tomorrow · half XP · ${model.reducedDaysLeft} of $maxReducedDays days left';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Kicker('Quest reduction'),
        const SizedBox(height: 4),
        Row(
          children: [
            for (final (i, pct) in const [0, 10, 20].indexed) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: _SegButton(
                  label: '$pct%',
                  selected: tomorrow == pct,
                  cut: pct > 0,
                  semantic: 'Reduce quest by $pct percent from tomorrow',
                  onTap: locked ? null : () => model.setReduction(pct),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Text(
          caption,
          style: Hud.mono(
            10,
            tomorrow > 0 || model.reductionLimitedTomorrow ? Hud.warn : p.dim,
            spacing: .1,
          ),
        ),
      ],
    );
  }
}

class _SegButton extends StatelessWidget {
  const _SegButton({
    required this.label,
    required this.selected,
    required this.cut,
    required this.semantic,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool cut;
  final String semantic;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = HudScope.of(context);
    final c = !selected
        ? p.dim
        : cut
        ? Hud.warn
        : p.hi;
    final edge = !selected
        ? p.sys.withValues(alpha: .18)
        : cut
        ? Hud.warn
        : p.sys;
    return Semantics(
      button: true,
      selected: selected,
      label: semantic,
      child: GestureDetector(
        onTap: onTap,
        child: Opacity(
          opacity: onTap == null ? .4 : 1,
          child: ClipPath(
            clipper: const ChamferClipper(
              6,
              corners: [true, false, true, false],
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? edge.withValues(alpha: .07) : Colors.black26,
                border: Border.all(color: edge),
              ),
              child: ExcludeSemantics(
                child: Text(label, style: Hud.head(15, c, spacing: .12)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Five attributes as vertical bars. Points are held as pending until
/// CONFIRM; RESET drops them. Stats the System doesn't train are dimmed.
class _Attributes extends StatefulWidget {
  const _Attributes({required this.model, required this.trained});
  final GameModel model;
  final Set<Stat> trained;

  @override
  State<_Attributes> createState() => _AttributesState();
}

class _AttributesState extends State<_Attributes> {
  final _pending = <Stat, int>{};
  static const _max = 30;
  static const _order = [
    Stat.strength,
    Stat.vitality,
    Stat.intellect,
    Stat.charisma,
    Stat.discipline,
  ];
  static const _short = {
    Stat.strength: 'STR',
    Stat.intellect: 'INT',
    Stat.discipline: 'DIS',
    Stat.vitality: 'VIT',
    Stat.charisma: 'CHA',
  };

  int get _pendingTotal => _pending.values.fold(0, (a, b) => a + b);

  Future<void> _confirm() async {
    final all = {..._pending};
    setState(_pending.clear);
    for (final e in all.entries) {
      for (var i = 0; i < e.value; i++) {
        await widget.model.allocateStat(e.key);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = HudScope.of(context);
    final s = widget.model.state;
    final points = s.unspentStatPoints;
    final left = points - _pendingTotal;
    final has = _pendingTotal > 0;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 32,
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    'ATTRIBUTES',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Hud.head(11, p.hi, spacing: .24),
                  ),
                ),
                const Spacer(),
                if (has) ...[
                  _Small('RESET', onTap: () => setState(_pending.clear)),
                  const SizedBox(width: 6),
                  _Small('CONFIRM', gold: true, onTap: _confirm),
                ] else
                  Text(
                    points == 0
                        ? 'NO POINTS'
                        : '$points POINT${points == 1 ? '' : 'S'}',
                    style: Hud.mono(
                      10,
                      points == 0 ? p.dim : Hud.gold,
                      spacing: .16,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final stat in _order)
                Expanded(
                  child: _StatColumn(
                    label: _short[stat]!,
                    value: s.stats[stat] ?? 0,
                    pending: _pending[stat] ?? 0,
                    max: _max,
                    trained: widget.trained.contains(stat),
                    canAdd: left > 0,
                    onAdd: () => setState(
                      () => _pending[stat] = (_pending[stat] ?? 0) + 1,
                    ),
                    semantic: 'Add a point to ${stat.name}',
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Small extends StatelessWidget {
  const _Small(this.label, {required this.onTap, this.gold = false});
  final String label;
  final VoidCallback onTap;
  final bool gold;

  @override
  Widget build(BuildContext context) {
    final p = HudScope.of(context);
    final c = gold ? Hud.gold : p.dim;
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(
                color: gold ? Hud.gold : p.sys.withValues(alpha: .18),
              ),
            ),
            child: ExcludeSemantics(
              child: Text(label, style: Hud.head(10, c, spacing: .16)),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({
    required this.label,
    required this.value,
    required this.pending,
    required this.max,
    required this.trained,
    required this.canAdd,
    required this.onAdd,
    required this.semantic,
  });

  final String label;
  final int value;
  final int pending;
  final int max;
  final bool trained;
  final bool canAdd;
  final VoidCallback onAdd;
  final String semantic;

  @override
  Widget build(BuildContext context) {
    final p = HudScope.of(context);
    final base = (value / max).clamp(0.0, 1.0);
    final extra = (pending / max).clamp(0.0, 1.0 - base);
    return Column(
      children: [
        Text(label, style: Hud.head(12, trained ? p.hi : p.dim, spacing: .14)),
        const SizedBox(height: 4),
        SizedBox(
          height: 18,
          child: Text.rich(
            TextSpan(
              text: '$value',
              style: Hud.mono(15, Colors.white, weight: FontWeight.w700),
              children: [
                if (pending > 0)
                  TextSpan(text: '+$pending', style: Hud.mono(11, Hud.gold)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 10,
          height: 50,
          child: Stack(
            children: [
              const Positioned.fill(
                child: ColoredBox(color: Color(0x2E7D8BA8)),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 50 * base,
                child: ColoredBox(
                  color: trained ? p.sys : const Color(0xFF4A5670),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 50 * base,
                height: 50 * extra,
                child: const ColoredBox(color: Hud.gold),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 48,
          child: StepButton(
            '+',
            semanticLabel: semantic,
            onPressed: canAdd ? onAdd : null,
          ),
        ),
      ],
    );
  }
}

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
