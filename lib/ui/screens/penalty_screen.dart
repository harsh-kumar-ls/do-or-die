import 'dart:async';

import 'package:flutter/material.dart';

import '../../platform/blocker.dart';
import '../game_model.dart';
import '../theme.dart';
import '../widgets/fill_column.dart';
import '../widgets/hud_controls.dart';
import '../widgets/system_window.dart';

/// Shown in the P3 palette. Exercise owed, the lock state, the locked apps,
/// and the emergency exit.
class PenaltyScreen extends StatelessWidget {
  const PenaltyScreen({
    super.key,
    required this.model,
    required this.blocker,
    required this.onEditApps,
  });

  final GameModel model;
  final AppBlocker blocker;
  final VoidCallback onEditApps;

  @override
  Widget build(BuildContext context) {
    final p = HudScope.of(context);
    return Ticker1s(
      builder: (context) {
        final debt = model.state.debt;
        final owesToday = debt != null && debt.dueDay == model.service.today;
        final lock = model.state.lock;
        final now = model.now;

        final String lockLine;
        final String lockValue;
        if (model.lockActive) {
          lockLine = 'UNTIL ACCESS IS RESTORED';
          lockValue = hms(lock!.end.difference(now));
        } else if (model.lockReleased) {
          lockLine = 'RELEASED · THE LOCK RETURNS IN';
          lockValue = hms(model.releaseEndsAt!.difference(now));
        } else if (model.lockPending) {
          lockLine = 'THE LOCK WILL BEGIN WITHOUT WARNING';
          lockValue = '--:--:--';
        } else {
          lockLine = 'NO LOCK TODAY';
          lockValue = '00:00:00';
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (blocker.canBlock) _EnforcementStatus(blocker: blocker),
              Expanded(
                child: SystemWindow(
                  expand: true,
                  title: '[ PENALTY ZONE ]',
                  subtitle: model.inPenalty
                      ? "Yesterday's quest was not completed."
                      : 'No penalty is in effect.',
                  child: FillColumn(
                    children: [
                      Text(
                        lockValue,
                        textAlign: TextAlign.center,
                        style: Hud.head(52, Colors.white, spacing: .08)
                            .copyWith(
                              shadows: p.textGlow(1),
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                      ),
                      Text(
                        lockLine,
                        textAlign: TextAlign.center,
                        style: Hud.mono(11, p.dim, spacing: .06),
                      ),
                      _LockedApps(model: model, blocker: blocker),
                      HudButton('EDIT LOCKED APPS', onPressed: onEditApps),
                      if (model.lockActive)
                        HoldButton(
                          key: ValueKey('release-${model.releasesUsed}'),
                          label: 'HOLD 3S · RELEASE 15 MIN',
                          doneLabel: 'RELEASED',
                          holdFor: const Duration(seconds: 3),
                          onConfirmed: () async {
                            final released = await model.releaseLock();
                            if (released && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Released for 15 minutes. '
                                    'Release ${model.releasesUsed} today, '
                                    'and it has been logged.',
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                      if (model.releasesUsed > 0)
                        Text(
                          'RELEASES USED TODAY: ${model.releasesUsed} · '
                          '${model.releasesUsed * 15} MIN',
                          textAlign: TextAlign.center,
                          style: Hud.head(13, Hud.warn, spacing: .14),
                        ),
                    ],
                  ),
                ),
              ),
              if (owesToday) ...[
                const SizedBox(height: 14),
                _ExerciseWindow(
                  title: 'PUSH-UPS OWED',
                  done: debt.pushupsDone,
                  owed: debt.pushupsOwed,
                  onAdd: (n) => model.recordExercise(pushups: n),
                ),
                if (debt.squatsOwed > 0) ...[
                  const SizedBox(height: 14),
                  _ExerciseWindow(
                    title: 'SQUATS OWED',
                    done: debt.squatsDone,
                    owed: debt.squatsOwed,
                    onAdd: (n) => model.recordExercise(squats: n),
                  ),
                ],
              ],
              const SizedBox(height: 14),
              Text(
                'Releases last 15 minutes · every one is counted',
                textAlign: TextAlign.center,
                style: Hud.mono(11, p.dim.withValues(alpha: .7)),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Chips for today's locked apps, labelled with each app's real name.
class _LockedApps extends StatefulWidget {
  const _LockedApps({required this.model, required this.blocker});
  final GameModel model;
  final AppBlocker blocker;

  @override
  State<_LockedApps> createState() => _LockedAppsState();
}

class _LockedAppsState extends State<_LockedApps> {
  Map<String, String> _labels = const {};

  @override
  void initState() {
    super.initState();
    widget.blocker.installedApps().then((apps) {
      if (mounted) {
        setState(() => _labels = {for (final a in apps) a.package: a.label});
      }
    });
  }

  String _name(String pkg) =>
      (_labels[pkg] ?? _fallbackNames[pkg] ?? pkg.split('.').last)
          .toUpperCase();

  static const _fallbackNames = {
    'com.instagram.android': 'Instagram',
    'com.google.android.youtube': 'YouTube',
    'com.pubg.imobile': 'BGMI',
  };

  @override
  Widget build(BuildContext context) {
    final p = HudScope.of(context);
    final packages = widget.model.service.blockedToday.toList()
      ..sort((a, b) => _name(a).compareTo(_name(b)));
    if (packages.isEmpty) {
      return Text(
        'No apps chosen. A failed day locks nothing until you choose some.',
        textAlign: TextAlign.center,
        style: Hud.mono(11, Hud.warn),
      );
    }
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final pkg in packages)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(border: Border.all(color: p.line)),
            child: Text(_name(pkg), style: Hud.mono(10, p.hi, spacing: .1)),
          ),
      ],
    );
  }
}

/// Warns when the Android blocker service is off, so locks can't be enforced.
class _EnforcementStatus extends StatefulWidget {
  const _EnforcementStatus({required this.blocker});
  final AppBlocker blocker;

  @override
  State<_EnforcementStatus> createState() => _EnforcementStatusState();
}

class _EnforcementStatusState extends State<_EnforcementStatus> {
  bool? _enabled;
  late final Timer _poll;

  @override
  void initState() {
    super.initState();
    _check();
    _poll = Timer.periodic(const Duration(seconds: 5), (_) => _check());
  }

  Future<void> _check() async {
    try {
      final s = await widget.blocker.status();
      if (mounted) setState(() => _enabled = s.serviceEnabled);
    } catch (_) {
      if (mounted) setState(() => _enabled = false);
    }
  }

  @override
  void dispose() {
    _poll.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_enabled != false) return const SizedBox.shrink();
    final p = HudScope.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: p.panel,
          border: Border.all(color: p.sys),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('ENFORCEMENT OFFLINE', style: Hud.head(12, p.hi, spacing: .2)),
            const SizedBox(height: 6),
            Text(
              'The Penalty Zone service is off, so locks cannot be enforced.',
              style: Hud.mono(11, p.text),
            ),
            const SizedBox(height: 10),
            HudButton(
              'TURN ON IN ACCESSIBILITY SETTINGS',
              onPressed: widget.blocker.openAccessibilitySettings,
            ),
          ],
        ),
      ),
    );
  }
}

class _ExerciseWindow extends StatelessWidget {
  const _ExerciseWindow({
    required this.title,
    required this.done,
    required this.owed,
    required this.onAdd,
  });

  final String title;
  final int done;
  final int owed;
  final ValueChanged<int> onAdd;

  @override
  Widget build(BuildContext context) {
    final p = HudScope.of(context);
    final paid = done >= owed;
    return SystemWindow(
      title: title,
      delay: const Duration(milliseconds: 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '$done / $owed',
            textAlign: TextAlign.center,
            style: Hud.head(
              40,
              paid ? Hud.gold : p.hi,
              spacing: .02,
            ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
          ),
          const SizedBox(height: 10),
          HudBar(value: done / owed, done: paid),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: HudButton(
                  '+1 REP',
                  onPressed: paid ? null : () => onAdd(1),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: HudButton(
                  '+10 REPS',
                  onPressed: paid ? null : () => onAdd(10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            paid ? 'Penalty paid.' : 'Unpaid reps double at midnight.',
            textAlign: TextAlign.center,
            style: Hud.mono(11, paid ? Hud.gold : Hud.warn),
          ),
        ],
      ),
    );
  }
}
