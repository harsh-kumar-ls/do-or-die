import 'package:flutter/material.dart';

import '../../app/report.dart';
import '../../domain/progression.dart';
import '../../domain/system_catalogue.dart';
import '../game_model.dart';
import '../theme.dart';
import '../widgets/hud_background.dart';
import '../widgets/hud_controls.dart';
import '../widgets/system_window.dart';
import 'onboarding_screen.dart' show RankBadge;

/// The 30-day report: rank journey, then and now, attributes, consistency,
/// honesty, and the System's verdict. Built only from the trial log.
class ReportScreen extends StatelessWidget {
  const ReportScreen({super.key, required this.model});

  final GameModel model;

  @override
  Widget build(BuildContext context) {
    final r = TrialReport.from(
      model.service.game,
      model.service.today,
      systemCatalogue,
    );
    return HudScope(
      palette: HudPalette.system,
      child: Scaffold(
        body: HudBackground(
          child: SafeArea(
            child: Builder(
              builder: (context) {
                final p = HudScope.of(context);
                return ListView(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
                  children: [
                    SystemWindow(
                      title: '[ REPORT ]',
                      subtitle: r.days == 0
                          ? 'No day has been judged yet.'
                          : 'The last ${r.days} judged day${r.days == 1 ? '' : 's'}.',
                      child: Column(
                        children: [
                          Text(
                            '${r.clearRate}%',
                            style: Hud.head(
                              56,
                              p.hi,
                              spacing: 0,
                            ).copyWith(height: 1, shadows: p.textGlow(2)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'CLEARED',
                            style: Hud.mono(11, p.dim, spacing: .2),
                          ),
                          const SizedBox(height: 12),
                          _kv(p, 'DAYS CLEARED', '${r.cleared}'),
                          _kv(p, 'DAYS FAILED', '${r.failed}'),
                          _kv(p, 'LONGEST STREAK', '${r.longestStreak} days'),
                          _kv(p, 'CURRENT STREAK', '${r.currentStreak} days'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SystemWindow(
                      title: 'RANK JOURNEY',
                      delay: const Duration(milliseconds: 80),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (r.startRank != null && r.rank != null)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                RankBadge(rank: r.startRank!, size: 44),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                  ),
                                  child: Text(
                                    '›',
                                    style: Hud.head(22, p.dim, spacing: 0),
                                  ),
                                ),
                                RankBadge(rank: r.rank!, size: 44),
                              ],
                            ),
                          if (r.system != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              systemCatalogue[r.system]!.name.toUpperCase(),
                              textAlign: TextAlign.center,
                              style: Hud.mono(11, p.dim, spacing: .14),
                            ),
                          ],
                          const SizedBox(height: 8),
                          _kv(p, 'GATES OPENED', '${r.gatesOpened}'),
                          _kv(p, 'DUNGEONS CLEARED', '${r.dungeonsCleared}'),
                          _kv(p, 'DUNGEONS FAILED', '${r.dungeonsFailed}'),
                          for (final t in r.titles)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                t,
                                textAlign: TextAlign.center,
                                style: Hud.mono(11, Hud.gold),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (r.targets.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      SystemWindow(
                        title: 'THEN AND NOW',
                        subtitle: 'Daily quest at the starting rank and today.',
                        delay: const Duration(milliseconds: 120),
                        child: Column(
                          children: [
                            for (final t in r.targets)
                              _kv(
                                p,
                                t.label.toUpperCase(),
                                '${t.before}${t.unit} › ${t.after}${t.unit}',
                              ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    SystemWindow(
                      title: 'ATTRIBUTES',
                      delay: const Duration(milliseconds: 160),
                      child: Column(
                        children: [
                          _kv(p, 'LEVEL', '${r.level}'),
                          for (final s in Stat.values)
                            _kv(p, _short[s]!, '${r.stats[s] ?? 0}'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SystemWindow(
                      title: 'CONSISTENCY',
                      delay: const Duration(milliseconds: 200),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _Calendar(calendar: r.calendar),
                          const SizedBox(height: 10),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 14,
                            runSpacing: 6,
                            children: [
                              _legend(p, Hud.gold, 'CLEARED'),
                              _legend(p, Hud.warn, 'FAILED'),
                              _legend(
                                p,
                                p.sys.withValues(alpha: .4),
                                'DRY RUN',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SystemWindow(
                      title: 'HONESTY',
                      subtitle: 'Every escape is counted.',
                      delay: const Duration(milliseconds: 240),
                      child: Column(
                        children: [
                          _kv(p, 'PENALTY ZONES', '${r.penaltyZones}'),
                          _kv(p, 'DUNGEON PENALTIES', '${r.dungeonPenalties}'),
                          _kv(p, 'RELEASES TAKEN', '${r.releases}'),
                          _kv(p, 'BLOCKER OUTAGES', '${r.watcherOutages}'),
                          _kv(
                            p,
                            'HONOUR CONFIRMATIONS',
                            '${r.honourConfirmations}',
                          ),
                          _kv(p, 'REDUCED DAYS', '${r.reducedDays}'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SystemWindow(
                      title: '[ VERDICT ]',
                      delay: const Duration(milliseconds: 280),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final line in r.verdict)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                line,
                                textAlign: TextAlign.center,
                                style: Hud.mono(
                                  13,
                                  p.text,
                                ).copyWith(height: 1.5),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    HudButton(
                      'CLOSE',
                      onPressed: () => Navigator.of(context).pop(),
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

  static const _short = {
    Stat.strength: 'STR',
    Stat.intellect: 'INT',
    Stat.discipline: 'DIS',
    Stat.vitality: 'VIT',
    Stat.charisma: 'CHA',
  };

  static Widget _legend(HudPalette p, Color c, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 10, height: 10, color: c),
      const SizedBox(width: 6),
      Text(label, style: Hud.mono(10, p.dim, spacing: .1)),
    ],
  );

  static Widget _kv(HudPalette p, String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(
          child: Text(
            k,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Hud.mono(12, p.dim, spacing: .06),
          ),
        ),
        const SizedBox(width: 10),
        Text(v, style: Hud.mono(12, p.text, weight: FontWeight.w500)),
      ],
    ),
  );
}

/// Up to 30 squares, ten to a row, oldest first.
class _Calendar extends StatelessWidget {
  const _Calendar({required this.calendar});

  final List<(dynamic, DayMark)> calendar;

  @override
  Widget build(BuildContext context) {
    final p = HudScope.of(context);
    if (calendar.isEmpty) {
      return Text(
        'Nothing to show yet.',
        textAlign: TextAlign.center,
        style: Hud.mono(11, p.dim),
      );
    }
    return LayoutBuilder(
      builder: (context, c) {
        const gap = 5.0;
        final size = (c.maxWidth - gap * 9) / 10;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final (_, mark) in calendar)
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: switch (mark) {
                    DayMark.cleared => Hud.gold.withValues(alpha: .85),
                    DayMark.failed => Hud.warn.withValues(alpha: .85),
                    DayMark.dryRun => p.sys.withValues(alpha: .4),
                    DayMark.none => Colors.transparent,
                  },
                  border: Border.all(color: p.line),
                ),
              ),
          ],
        );
      },
    );
  }
}
