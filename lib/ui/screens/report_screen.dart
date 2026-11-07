import 'dart:math';

import 'package:flutter/material.dart';

import '../../app/report.dart';
import '../../domain/day.dart';
import '../../domain/progression.dart';
import '../../domain/system_catalogue.dart';
import '../game_model.dart';
import '../theme.dart';
import '../widgets/awakening_art.dart';
import '../widgets/hud_background.dart';
import '../widgets/hud_kit.dart';
import '../widgets/share_card.dart';
import '../widgets/system_frame.dart';

/// The 30-day report, built from design/claude-design/status.html: clear
/// rate dial, rank journey, then and now, a tappable consistency calendar,
/// honesty figures and the verdict. Built only from the trial log.
class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key, required this.model});
  final GameModel model;

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  int? _selected;

  static const _mon = [
    'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', //
    'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
  ];
  static String _d(DayKey d) => '${d.day} ${_mon[d.month - 1]}';

  @override
  Widget build(BuildContext context) {
    final m = widget.model;
    final r = TrialReport.from(
      m.service.game,
      m.service.today,
      systemCatalogue,
    );
    final sys = m.systems;
    final range = r.calendar.isEmpty
        ? 'NO JUDGED DAYS YET'
        : '${_d(r.calendar.first.$1)} – ${_d(r.calendar.last.$1)}';
    final sysName = r.system == null
        ? ''
        : '${systemCatalogue[r.system]!.name.split(' ').first.toUpperCase()} · ';
    return HudScope(
      palette: HudPalette.system,
      child: Scaffold(
        body: HudBackground(
          child: SafeArea(
            child: Builder(
              builder: (context) {
                final p = HudScope.of(context);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SizedBox(
                        height: 56,
                        child: Row(
                          children: [
                            Semantics(
                              button: true,
                              label: 'Back',
                              child: GestureDetector(
                                onTap: () => Navigator.of(context).pop(),
                                child: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: p.sys.withValues(alpha: .18),
                                    ),
                                  ),
                                  child: Icon(Icons.chevron_left, color: p.hi),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(right: 48),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        '[ 30-DAY REPORT ]',
                                        style: Hud.head(
                                          14,
                                          p.hi,
                                          spacing: .26,
                                        ).copyWith(shadows: p.textGlow(.8)),
                                      ),
                                      Text(
                                        '$sysName$range',
                                        style: Hud.mono(
                                          10,
                                          p.dim,
                                          spacing: .14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
                        children: [
                          Panel(child: _DialRow(r: r)),
                          const SizedBox(height: 14),
                          const Kicker('Rank journey'),
                          const SizedBox(height: 8),
                          _Journey(r: r),
                          if (r.targets.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            const Kicker('Then and now'),
                            const SizedBox(height: 8),
                            _ThenNow(r: r),
                          ],
                          const SizedBox(height: 14),
                          const Kicker('Consistency'),
                          const SizedBox(height: 8),
                          _Calendar(
                            r: r,
                            reduced: (d) =>
                                (sys?.progress.reductionOn(d) ?? 0) > 0,
                            selected: _selected,
                            onTap: (i) => setState(() => _selected = i),
                          ),
                          const SizedBox(height: 14),
                          const Kicker('Honesty'),
                          const SizedBox(height: 8),
                          _Honesty(r: r),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.black38,
                              border: Border.all(
                                color: p.sys.withValues(alpha: .55),
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'VERDICT',
                                  style: Hud.mono(9, p.dim, spacing: .24),
                                ),
                                const SizedBox(height: 6),
                                for (final line in r.verdict)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Text(
                                      line,
                                      textAlign: TextAlign.center,
                                      style: Hud.head(
                                        line == r.headline ? 15 : 12,
                                        line == r.headline ? p.text : p.dim,
                                        spacing: .04,
                                      ).copyWith(height: 1.45),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                      decoration: BoxDecoration(
                        color: const Color(0xE605070D),
                        border: Border(
                          top: BorderSide(color: p.sys.withValues(alpha: .18)),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: CutButton(
                              'SHARE',
                              onPressed: r.days == 0
                                  ? null
                                  : () => showModalBottomSheet<void>(
                                      context: context,
                                      isScrollControlled: true,
                                      backgroundColor: const Color(0xF205070D),
                                      builder: (_) => _ShareSheet(r: r),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: CutButton(
                              'CLOSE',
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _DialRow extends StatelessWidget {
  const _DialRow({required this.r});
  final TrialReport r;

  @override
  Widget build(BuildContext context) {
    final p = HudScope.of(context);
    final dry = r.calendar.where((c) => c.$2 == DayMark.dryRun).length;
    Widget row(Color? c, String k, String v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          if (c != null) ...[
            Container(width: 9, height: 9, color: c),
            const SizedBox(width: 6),
          ],
          Expanded(child: Text(k, style: Hud.mono(12, p.dim))),
          Text(v, style: Hud.mono(12, p.text, weight: FontWeight.w700)),
        ],
      ),
    );
    return Row(
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: r.clearRate / 100),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
          builder: (context, k, _) => SizedBox(
            width: 140,
            height: 140,
            child: CustomPaint(
              painter: _Dial(k),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${(k * 100).round()}%',
                      style: Hud.mono(34, Colors.white, weight: FontWeight.w700)
                          .copyWith(
                            shadows: [
                              Shadow(
                                color: Hud.gold.withValues(alpha: .5),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                    ),
                    Text('CLEAR RATE', style: Hud.mono(9, p.dim, spacing: .2)),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            children: [
              row(Hud.gold, 'Cleared', '${r.cleared}'),
              row(const Color(0xFFFF3B4A), 'Failed', '${r.failed}'),
              row(p.sys.withValues(alpha: .6), 'Dry run', '$dry'),
              row(null, 'Counted days', '${r.cleared + r.failed}'),
              row(null, 'Best streak', '${r.longestStreak}'),
            ],
          ),
        ),
      ],
    );
  }
}

class _Dial extends CustomPainter {
  _Dial(this.k);
  final double k;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width * 58 / 140;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = const Color(0x2E7D8BA8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10,
    );
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -pi / 2,
      2 * pi * k,
      false,
      Paint()
        ..color = Hud.gold
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4),
    );
  }

  @override
  bool shouldRepaint(_Dial old) => old.k != k;
}

class _Journey extends StatelessWidget {
  const _Journey({required this.r});
  final TrialReport r;

  @override
  Widget build(BuildContext context) {
    final p = HudScope.of(context);
    if (r.startRank == null || r.rank == null) {
      return Text('No System yet.', style: Hud.mono(11, p.dim));
    }
    final cleared = r.dungeonsCleared;
    Widget badge(Rank rk, String label) => SizedBox(
      width: 72,
      child: Column(
        children: [
          CustomPaint(size: const Size(64, 68), painter: RankHexPainter(rk)),
          const SizedBox(height: 2),
          Text(label, style: Hud.mono(9, p.dim, spacing: .14)),
        ],
      ),
    );
    return Row(
      children: [
        badge(r.startRank!, 'START'),
        Expanded(
          child: SizedBox(
            height: 68,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 1,
                    color: p.sys.withValues(alpha: .55),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    for (var i = 0; i < max(1, cleared * 3); i++)
                      Transform.rotate(
                        angle: pi / 4,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: cleared > 0
                                ? Hud.gold
                                : const Color(0xFF05070D),
                            border: Border.all(color: Hud.gold),
                          ),
                        ),
                      ),
                  ],
                ),
                Positioned(
                  bottom: 2,
                  child: Text(
                    cleared == 0
                        ? 'NO DUNGEON CLEARED YET'
                        : '$cleared DUNGEON${cleared == 1 ? '' : 'S'} · ${cleared * 3} FLOORS CLEARED',
                    style: Hud.mono(9, p.dim, spacing: .12),
                  ),
                ),
              ],
            ),
          ),
        ),
        badge(r.rank!, 'NOW'),
      ],
    );
  }
}

class _ThenNow extends StatelessWidget {
  const _ThenNow({required this.r});
  final TrialReport r;

  @override
  Widget build(BuildContext context) {
    final p = HudScope.of(context);
    String v(int x, String unit) => unit == 'm'
        ? '${(x / 1000).toStringAsFixed(1)} km'
        : unit.isEmpty
        ? '$x'
        : '$x $unit';
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(),
        1: IntrinsicColumnWidth(),
        2: FixedColumnWidth(26),
        3: IntrinsicColumnWidth(),
        4: IntrinsicColumnWidth(),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          children: [
            for (final h in const ['TARGET', 'THEN', '', 'NOW', 'CHANGE'])
              Padding(
                padding: const EdgeInsets.only(bottom: 6, left: 6),
                child: Text(
                  h,
                  textAlign: TextAlign.right,
                  style: Hud.mono(9, p.dim, spacing: .18),
                ),
              ),
          ],
        ),
        for (final t in r.targets)
          TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(t.label, style: Hud.mono(12, p.text)),
              ),
              Text(
                v(t.before, t.unit),
                textAlign: TextAlign.right,
                style: Hud.mono(12, p.dim),
              ),
              Icon(Icons.arrow_right_alt, size: 14, color: p.dim),
              Text(
                v(t.after, t.unit),
                textAlign: TextAlign.right,
                style: Hud.mono(12, Colors.white, weight: FontWeight.w700),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  t.before == 0
                      ? 'new'
                      : '${t.after >= t.before ? '+' : ''}${((t.after - t.before) * 100 / t.before).round()}%',
                  textAlign: TextAlign.right,
                  style: Hud.mono(11, const Color(0xFF5BD69A)),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _Calendar extends StatelessWidget {
  const _Calendar({
    required this.r,
    required this.reduced,
    required this.selected,
    required this.onTap,
  });

  final TrialReport r;
  final bool Function(DayKey) reduced;
  final int? selected;
  final ValueChanged<int> onTap;

  static const _days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
  static const _mon = [
    'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', //
    'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
  ];

  @override
  Widget build(BuildContext context) {
    final p = HudScope.of(context);
    if (r.calendar.isEmpty) {
      return Text('Nothing to show yet.', style: Hud.mono(11, p.dim));
    }
    Color fill(DayMark m) => switch (m) {
      DayMark.cleared => Hud.gold.withValues(alpha: .85),
      DayMark.failed => const Color(0xCCFF3B4A),
      DayMark.dryRun => p.sys.withValues(alpha: .45),
      DayMark.none => Colors.transparent,
    };
    String detail(int i) {
      final (d, m) = r.calendar[i];
      final dt = DateTime(d.year, d.month, d.day);
      final st = switch (m) {
        DayMark.cleared => 'CLEARED',
        DayMark.failed => 'FAILED · PENALTY ZONE',
        DayMark.dryRun => 'DRY RUN · NO PENALTY',
        DayMark.none => 'NOT JUDGED',
      };
      return 'DAY ${i + 1} · ${_days[dt.weekday - 1]} ${d.day} ${_mon[d.month - 1]} · $st${reduced(d) ? ' · REDUCED' : ''}';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, c) {
            const gap = 5.0;
            final size = (c.maxWidth - gap * 9) / 10;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final (i, (d, mark)) in r.calendar.indexed)
                  Semantics(
                    button: true,
                    label: detail(i),
                    child: GestureDetector(
                      onTap: () => onTap(i),
                      child: AnimatedScale(
                        scale: selected == i ? 1.12 : 1,
                        duration: const Duration(milliseconds: 100),
                        child: Container(
                          width: size,
                          height: size,
                          decoration: BoxDecoration(
                            color: fill(mark),
                            border: Border.all(
                              color: selected == i
                                  ? Colors.white
                                  : p.sys.withValues(alpha: .18),
                            ),
                          ),
                          child: reduced(d)
                              ? Align(
                                  alignment: Alignment.topRight,
                                  child: Padding(
                                    padding: const EdgeInsets.all(2),
                                    child: Transform.rotate(
                                      angle: pi / 4,
                                      child: Container(
                                        width: 5,
                                        height: 5,
                                        color: const Color(0xFF05070D),
                                      ),
                                    ),
                                  ),
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 6,
          children: [
            for (final (c, l) in [
              (Hud.gold, 'CLEARED'),
              (const Color(0xFFFF3B4A), 'FAILED'),
              (p.sys.withValues(alpha: .5), 'DRY RUN'),
            ])
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 9, height: 9, color: c),
                  const SizedBox(width: 5),
                  Text(l, style: Hud.mono(9, p.dim, spacing: .12)),
                ],
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          selected == null ? 'Tap a day.' : detail(selected!),
          style: Hud.mono(11, p.text, spacing: .04),
        ),
      ],
    );
  }
}

class _Honesty extends StatelessWidget {
  const _Honesty({required this.r});
  final TrialReport r;

  @override
  Widget build(BuildContext context) {
    final p = HudScope.of(context);
    final counted = r.cleared + r.failed;
    final tiles = [
      ('PENALTY ZONES', '${r.penaltyZones}', 'of $counted counted days', false),
      (
        'DUNGEON PENALTIES',
        '${r.dungeonPenalties}',
        r.dungeonsCleared > 0 ? 'Rank Trial cleared' : '—',
        false,
      ),
      (
        'RELEASES TAKEN',
        '${r.releases}',
        r.penaltyZones + r.dungeonPenalties == 0
            ? 'no lock served yet'
            : '${(r.releases / (r.penaltyZones + r.dungeonPenalties)).toStringAsFixed(1)} per penalty',
        r.releases > 0,
      ),
      (
        'EMERGENCY EXITS',
        '${r.emergencyExits}',
        'locks ended early',
        r.emergencyExits > 0,
      ),
      (
        'CONTESTED VERDICTS',
        '${r.contests}',
        'one allowed per 14 days',
        r.contests > 0,
      ),
      (
        'BLOCKER OUTAGES',
        '${r.watcherOutages}',
        'the lock was down',
        r.watcherOutages > 0,
      ),
      (
        'HONOUR CONFIRMATIONS',
        '${r.honourConfirmations}',
        'caps confirmed on your word',
        r.honourConfirmations > 0,
      ),
      ('REDUCED DAYS', '${r.reducedDays}', 'quest lowered, half XP', false),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 6,
      crossAxisSpacing: 6,
      childAspectRatio: 1.8,
      children: [
        for (final (label, v, sub, warn) in tiles)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.black26,
              border: Border.all(
                color: warn
                    ? Hud.warn.withValues(alpha: .4)
                    : p.sys.withValues(alpha: .18),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  v,
                  style: Hud.mono(
                    20,
                    warn ? Hud.warn : Colors.white,
                    weight: FontWeight.w700,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Hud.mono(9, p.dim, spacing: .14),
                ),
                const SizedBox(height: 2),
                Text(
                  sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Hud.mono(10, p.dim),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Preview of the share card, a switch to drop the honesty figures, and the
/// share action.
class _ShareSheet extends StatefulWidget {
  const _ShareSheet({required this.r});
  final TrialReport r;

  @override
  State<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<_ShareSheet> {
  final _card = GlobalKey();
  bool _honesty = true;
  bool _busy = false;

  Future<void> _share() async {
    setState(() => _busy = true);
    try {
      await shareCardImage(_card);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(content: Text('The image could not be shared.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return HudScope(
      palette: HudPalette.system,
      child: Builder(
        builder: (context) {
          final p = HudScope.of(context);
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '[ SHARE REPORT ]',
                    textAlign: TextAlign.center,
                    style: Hud.head(14, p.hi),
                  ),
                  const SizedBox(height: 10),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(context).height * .55,
                    ),
                    child: FittedBox(
                      child: RepaintBoundary(
                        key: _card,
                        child: ShareCard(r: widget.r, honesty: _honesty),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Semantics(
                    container: true,
                    checked: _honesty,
                    label: 'Include honesty figures',
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _honesty = !_honesty),
                      child: SizedBox(
                        height: 48,
                        child: ExcludeSemantics(
                          child: Row(
                            children: [
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: _honesty
                                      ? p.sys.withValues(alpha: .25)
                                      : Colors.transparent,
                                  border: Border.all(color: p.sys),
                                ),
                                child: _honesty
                                    ? Icon(Icons.check, size: 14, color: p.hi)
                                    : null,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'INCLUDE HONESTY FIGURES',
                                  style: Hud.mono(11, p.text, spacing: .16),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  CutButton(
                    _busy ? 'PREPARING' : 'SHARE AS IMAGE',
                    onPressed: _busy ? null : _share,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
