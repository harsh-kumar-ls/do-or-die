import 'dart:async';

import 'package:flutter/material.dart';

import '../../platform/blocker.dart';
import '../game_model.dart';
import '../theme.dart';
import '../widgets/hud_background.dart';
import '../widgets/hud_controls.dart';
import '../widgets/system_window.dart';

/// Everything the trial depends on, each with its state and a way to fix it.
class SystemCheckScreen extends StatefulWidget {
  const SystemCheckScreen({
    super.key,
    required this.model,
    required this.blocker,
    this.onRestartTrial,
  });

  final GameModel model;
  final AppBlocker blocker;

  /// Archives this game and returns to the Awakening; refused while a
  /// penalty or a Dungeon is in effect.
  final Future<void> Function()? onRestartTrial;

  @override
  State<SystemCheckScreen> createState() => _SystemCheckScreenState();
}

class _SystemCheckScreenState extends State<SystemCheckScreen>
    with WidgetsBindingObserver {
  late final Timer _poll;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.model.refreshSystem();
    // Settings changed elsewhere show up within a few seconds.
    _poll = Timer.periodic(
      const Duration(seconds: 3),
      (_) => widget.model.refreshSystem(),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) widget.model.refreshSystem();
  }

  @override
  void dispose() {
    _poll.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HudScope(
      palette: HudPalette.system,
      child: Scaffold(
        body: HudBackground(
          child: SafeArea(
            child: ListenableBuilder(
              listenable: widget.model,
              builder: (context, _) => _body(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final p = HudScope.of(context);
    final m = widget.model;
    final s = m.system;
    final android = widget.blocker.canBlock;
    final incidents = m.service.blockerOfflineIncidents;

    final checks = <_Check>[
      _Check(
        'USAGE ACCESS',
        'Lets the watcher see when a locked app opens. '
            'No accessibility service is used, so payment apps keep working. '
            'If Android says "Access denied" (app installed from a file): '
            'open App info for Do or Die, tap the menu at the top right, '
            'choose "Allow restricted settings", then allow this again.',
        s?.usageAccess,
        'ALLOW',
        widget.blocker.requestUsageAccess,
      ),
      _Check(
        'DISPLAY OVER APPS',
        'Lets the Penalty Zone appear over a locked app. '
            'If refused, allow restricted settings as above first.',
        s?.overlay,
        'ALLOW',
        widget.blocker.requestOverlay,
      ),
      _Check(
        'WATCHER RUNNING',
        'A force stop stops it; opening Do or Die starts it again.',
        s?.watcherRunning,
        'START',
        () async {
          await widget.blocker.startWatcher();
          await widget.model.refreshSystem();
        },
      ),
      _Check(
        'NOTIFICATIONS',
        'Deadline warnings, verdicts and lock alerts.',
        android ? !m.notificationsBlocked : null,
        'ALLOW',
        m.requestNotifications,
      ),
      _Check(
        'ON-TIME ALERTS',
        '"Alarms & reminders". Without it, notices can be an hour late.',
        android ? !m.lateNotices && !m.notificationsBlocked : null,
        'ALLOW',
        m.requestExactTiming,
      ),
      _Check(
        'BATTERY EXEMPTION',
        'Stops the phone from putting the blocker and alarms to sleep.',
        s?.batteryExempt,
        'EXEMPT',
        widget.blocker.requestBatteryExemption,
      ),
      _Check(
        'AUTOMATIC TIME',
        "The System can't trust a clock you set by hand.",
        s?.autoTime,
        'FIX',
        m.openDateSettings,
      ),
    ];
    final ok = checks.where((c) => c.ok == true).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
      children: [
        SystemWindow(
          title: '[ SYSTEM CHECK ]',
          subtitle: android
              ? '$ok of ${checks.length} requirements met.'
              : 'Phone checks run on Android only.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [for (final c in checks) _CheckRow(check: c)],
          ),
        ),
        const SizedBox(height: 14),
        SystemWindow(
          title: 'ORIGINOS (CHECK BY HAND)',
          delay: const Duration(milliseconds: 200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final line in const [
                'Autostart: allow Do or Die (App info > Autostart or Background).',
                'Recent apps: pull down on the Do or Die card and lock it, so cleaning memory never stops it.',
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('›  ', style: Hud.mono(12, p.sys)),
                      Expanded(
                        child: Text(
                          line,
                          style: Hud.mono(11, p.text).copyWith(height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
              HudButton(
                'OPEN APP INFO',
                onPressed: widget.blocker.openAppSettings,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          incidents == 0
              ? 'The blocker has not been found switched off.'
              : 'The blocker has been found switched off $incidents '
                    'time${incidents == 1 ? '' : 's'}. Each one is in your trial log.',
          textAlign: TextAlign.center,
          style: Hud.mono(11, incidents == 0 ? p.dim : Hud.warn),
        ),
        const SizedBox(height: 14),
        HudButton('DONE', onPressed: () => Navigator.of(context).pop()),
        if (widget.onRestartTrial != null) ...[
          const SizedBox(height: 28),
          SystemWindow(
            title: 'RESTART TRIAL',
            subtitle: 'Archives this game with its full log and starts a new Awakening.',
            child: m.restartBlockedReason != null
                ? Text(
                    m.restartBlockedReason!,
                    textAlign: TextAlign.center,
                    style: Hud.mono(11, Hud.warn),
                  )
                : HoldButton(
                    label: 'HOLD 3S · RESTART TRIAL',
                    doneLabel: 'RESTARTING',
                    holdFor: const Duration(seconds: 3),
                    onConfirmed: () async {
                      Navigator.of(context).pop();
                      await widget.onRestartTrial!();
                    },
                  ),
          ),
        ],
      ],
    );
  }
}

class _Check {
  const _Check(this.title, this.body, this.ok, this.action, this.onFix);

  final String title;
  final String body;

  /// True: met. False: not met. Null: unknown or not applicable.
  final bool? ok;
  final String? action;
  final VoidCallback? onFix;
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.check});
  final _Check check;

  @override
  Widget build(BuildContext context) {
    final p = HudScope.of(context);
    final ok = check.ok;
    final (mark, color) = switch (ok) {
      true => ('✓', Hud.gold),
      false => ('✕', Hud.warn),
      null => ('–', p.dim),
    };
    return Semantics(
      container: true,
      label:
          '${check.title}: ${ok == null
              ? 'unknown'
              : ok
              ? 'met'
              : 'not met'}',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: SizedBox(
                width: 22,
                child: Text(mark, style: Hud.head(15, color, spacing: 0)),
              ),
            ),
            Expanded(
              child: ExcludeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      check.title,
                      style: Hud.head(
                        12,
                        ok == false ? Hud.warn : p.hi,
                        spacing: .16,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      check.body,
                      style: Hud.mono(11, p.dim).copyWith(height: 1.45),
                    ),
                  ],
                ),
              ),
            ),
            if (ok == false && check.onFix != null) ...[
              const SizedBox(width: 10),
              SizedBox(
                width: 84,
                child: HudButton(
                  check.action!,
                  dense: true,
                  onPressed: check.onFix,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
