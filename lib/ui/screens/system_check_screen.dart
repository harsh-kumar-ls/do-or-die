import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  });

  final GameModel model;
  final AppBlocker blocker;

  static const grantCommand =
      'adb shell pm grant com.doordie.do_or_die android.permission.WRITE_SECURE_SETTINGS';

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
        'PENALTY ZONE SERVICE',
        'Locks your chosen apps. A force stop switches it off.',
        s?.serviceEnabled,
        'TURN ON',
        widget.blocker.openAccessibilitySettings,
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
          title: 'AUTO-REPAIR (OPTIONAL)',
          delay: const Duration(milliseconds: 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _CheckRow(
                check: _Check(
                  s?.canSelfRepair == true ? 'ON' : 'OFF',
                  'When on, Do or Die turns the Penalty Zone service back on '
                  'by itself whenever it opens. It needs a developer '
                  'permission that you grant once, from your Mac:',
                  s?.canSelfRepair,
                  null,
                  null,
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () async {
                  await Clipboard.setData(
                    const ClipboardData(text: SystemCheckScreen.grantCommand),
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Command copied.')),
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(border: Border.all(color: p.line)),
                  child: Text(
                    SystemCheckScreen.grantCommand,
                    style: Hud.mono(10, p.hi),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Tap to copy. This changes a security setting on your phone, '
                'so it is your choice to run it.',
                style: Hud.mono(10, p.dim),
              ),
            ],
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
