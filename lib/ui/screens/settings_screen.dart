import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/build_flags.dart';
import '../../domain/penalty.dart';
import '../../platform/share_file.dart';
import '../game_model.dart';
import '../theme.dart';
import '../widgets/hud_background.dart';
import '../widgets/system_frame.dart';
import '../widgets/system_window.dart';

/// Settings that change how the System treats you, plus your data: the rest
/// period, when a lock starts, switching System, exporting the log and the
/// privacy policy. Easier settings apply to locks scheduled after the change,
/// never to one already scheduled.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.model,
    this.onSwitchSystem,
    this.onOpenDiagnostics,
    this.share = shareTextFile,
  });

  final GameModel model;
  final VoidCallback? onSwitchSystem;

  /// Debug builds only.
  final VoidCallback? onOpenDiagnostics;

  /// Opens the share sheet with a file (replaced in tests).
  final Future<void> Function(String, {required String name, String mimeType})
  share;

  @override
  Widget build(BuildContext context) => HudScope(
    palette: HudPalette.system,
    child: Scaffold(
      body: HudBackground(
        child: SafeArea(
          child: ListenableBuilder(
            listenable: model,
            builder: (context, _) => _body(context),
          ),
        ),
      ),
    ),
  );

  /// The rest period must leave at least 12 waking hours.
  Future<void> _setSleep(BuildContext context, SleepWindow next) async {
    if (next.startMinute == next.endMinute) return;
    final ok = await model.setSleepWindow(next);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The rest period must leave at least 12 waking hours.'),
        ),
      );
    }
  }

  Widget _body(BuildContext context) {
    final p = HudScope.of(context);
    final g = model.service;
    final sleep = g.plannedSleep;
    final from = g.pendingSettingsFrom;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
      children: [
        SystemWindow(
          title: '[ SETTINGS ]',
          subtitle:
              'Changes take effect in two days, so they never soften a lock '
              'that is already coming.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TimeRow(
                label: 'REST PERIOD STARTS',
                minute: sleep.startMinute,
                onChanged: (m) => _setSleep(
                  context,
                  SleepWindow(startMinute: m, endMinute: sleep.endMinute),
                ),
              ),
              _TimeRow(
                label: 'REST PERIOD ENDS',
                minute: sleep.endMinute,
                onChanged: (m) => _setSleep(
                  context,
                  SleepWindow(startMinute: sleep.startMinute, endMinute: m),
                ),
              ),
              _TimeRow(
                label: 'LOCK STARTS',
                minute: g.plannedLockStart,
                onChanged: model.setLockStart,
              ),
              if (from != null) ...[
                const SizedBox(height: 6),
                Text(
                  'These settings take effect on ${from.day}/${from.month}. '
                  'Until then the current ones apply.',
                  style: Hud.mono(12, Hud.gold).copyWith(height: 1.5),
                ),
              ],
              const SizedBox(height: 6),
              Text(
                'A lock lasts 4 hours from this time, moved inside your '
                'waking hours if needed. Locks never begin during the rest '
                'period.',
                style: Hud.mono(12, p.dim).copyWith(height: 1.5),
              ),
            ],
          ),
        ),
        if (!BuildFlags.focusOnly) ...[
          const SizedBox(height: 14),
          SystemWindow(
            title: 'SYSTEM',
            delay: const Duration(milliseconds: 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  g.dungeonInProgress
                      ? 'Switching is unavailable during a Dungeon.'
                      : 'Switch to another System. It starts tomorrow; every '
                            'rank you earned is kept. An open Gate closes and '
                            'the 21-of-30 count starts again.',
                  style: Hud.mono(12, p.dim).copyWith(height: 1.5),
                ),
                const SizedBox(height: 10),
                CutButton(
                  'SWITCH SYSTEM',
                  onPressed: g.dungeonInProgress ? null : onSwitchSystem,
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        SystemWindow(
          title: 'YOUR DATA',
          delay: const Duration(milliseconds: 200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Everything stays on this phone. Export the full log of '
                'verdicts, penalties, releases and exits as a file you '
                'choose where to send.',
                style: Hud.mono(12, p.dim).copyWith(height: 1.5),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: CutButton(
                      'EXPORT JSON',
                      onPressed: () => share(
                        g.exportLogJson(),
                        name: 'do-or-die-log.json',
                        mimeType: 'application/json',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: CutButton(
                      'EXPORT CSV',
                      onPressed: () => share(
                        g.exportLogCsv(),
                        name: 'do-or-die-log.csv',
                        mimeType: 'text/csv',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              CutButton(
                'PRIVACY POLICY',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PrivacyScreen()),
                ),
              ),
              if (kDebugMode && onOpenDiagnostics != null) ...[
                const SizedBox(height: 8),
                CutButton('DIAGNOSTICS', onPressed: onOpenDiagnostics),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// A time of day with half-hour steps.
class _TimeRow extends StatelessWidget {
  const _TimeRow({
    required this.label,
    required this.minute,
    required this.onChanged,
  });

  final String label;
  final int minute;
  final ValueChanged<int> onChanged;

  static String hm(int m) =>
      '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final p = HudScope.of(context);
    int step(int d) => (minute + d) % (24 * 60);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: Hud.head(12, p.hi, spacing: .16))),
          IconButton(
            tooltip: '$label 30 minutes earlier',
            onPressed: () => onChanged(step(-30)),
            icon: Icon(Icons.remove, color: p.sys),
          ),
          Text(
            hm(minute),
            style: Hud.mono(16, p.text, weight: FontWeight.w700),
          ),
          IconButton(
            tooltip: '$label 30 minutes later',
            onPressed: () => onChanged(step(30)),
            icon: Icon(Icons.add, color: p.sys),
          ),
        ],
      ),
    );
  }
}

/// The privacy policy, in the app (the same text as the published page).
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  static const sections = <(String, String)>[
    (
      'SUMMARY',
      'Do or Die does not collect, transmit, sell or share any personal data. '
          'Everything it records stays on your phone. It has no internet '
          'access, no accounts, no analytics, no advertising and no '
          'third-party code that sends data.',
    ),
    (
      'WHAT IS STORED ON YOUR PHONE',
      'Your System, rank, level, XP and daily quest progress; a log of '
          'verdicts, penalties, releases, emergency exits, contested '
          'verdicts and blocker outages, used for the report; written '
          'reflections; the apps you chose to lock; your rest period and '
          'lock time. It is excluded from Android backups and device '
          'transfer, and deleted when you uninstall the app or clear its '
          'data.',
    ),
    (
      'USAGE ACCESS',
      'Used to see which app is in front, so a locked app can be covered '
          'during a lock, and to measure screen-time limits on the apps you '
          'chose. Read on the phone only, never stored outside the app, never '
          'sent anywhere.',
    ),
    (
      'INSTALLED APPS',
      'The list of launchable apps is read on the phone only, so you can '
          'choose which to lock. Phone, messages, maps, settings, banking and '
          'payment apps can never be locked.',
    ),
    (
      'DISPLAY OVER OTHER APPS',
      'Shows the lock screen over an app you chose to lock.',
    ),
    (
      'FOREGROUND SERVICE',
      'The lock watcher runs only while a lock, a phone-free block or a '
          'verdict is pending, with a visible notification. Exact alarms '
          'wake it at midnight and just before a lock.',
    ),
    (
      'NOTIFICATIONS AND ALARMS',
      'Deadline warnings, verdicts and lock notices, scheduled on the phone.',
    ),
    (
      'AGE',
      'Do or Die is for adults 18 and over; the app asks you to confirm this '
          'before it starts.',
    ),
    (
      'CONTACT',
      'Questions: open an issue at github.com/harsh-kumar-ls/do-or-die/issues.',
    ),
  ];

  @override
  Widget build(BuildContext context) => HudScope(
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
                    title: '[ PRIVACY POLICY ]',
                    subtitle: 'Effective 7 November 2026.',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final (title, body) in sections) ...[
                          const SizedBox(height: 10),
                          Text(title, style: Hud.head(12, p.hi, spacing: .16)),
                          const SizedBox(height: 4),
                          Text(
                            body,
                            style: Hud.mono(13, p.text).copyWith(height: 1.5),
                          ),
                        ],
                        const SizedBox(height: 16),
                        CutButton(
                          'BACK',
                          onPressed: () => Navigator.of(context).pop(),
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
