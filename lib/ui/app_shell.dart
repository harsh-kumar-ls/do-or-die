import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../platform/blocker.dart';
import '../spike/blocker_spike_screen.dart';
import 'fx.dart';
import 'game_model.dart';
import 'screens/app_picker_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/penalty_screen.dart';
import 'screens/quest_screen.dart';
import 'screens/report_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/status_screen.dart';
import 'screens/system_check_screen.dart';
import 'theme.dart';
import 'widgets/hud_background.dart';
import 'widgets/hud_kit.dart';
import 'widgets/notice_overlay.dart';

enum _Tab { quest, status, penalty }

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.model,
    required this.blocker,
    this.onAbandoned,
  });

  final GameModel model;
  final AppBlocker blocker;

  /// Called after the game is archived for a restart; the app returns to
  /// the Awakening.
  final VoidCallback? onAbandoned;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  _Tab _tab = _Tab.quest;

  void _go(_Tab t) {
    if (t == _tab) return;
    Fx.instance.play(
      t != _Tab.penalty
          ? Cue.window
          : widget.model.dungeonPenalty
          ? Cue.dungeonPenalty
          : Cue.penalty,
    );
    setState(() => _tab = t);
  }

  /// The System choice: the next System once one is complete, or a switch
  /// (the active and completed Systems are hidden).
  void _chooseSystem(BuildContext context, GameModel m) {
    final progress = m.systems!.progress;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => HudScope(
          palette: HudPalette.system,
          child: Scaffold(
            body: HudBackground(
              child: OnboardingScreen(
                blocker: widget.blocker,
                nextSystemOnly: true,
                completed: {
                  ...progress.completed,
                  if (progress.active != null) progress.active!,
                },
                onDone: (r) async {
                  await m.chooseSystem(r.system, r.placement, r.answers);
                  if (ctx.mounted) Navigator.of(ctx).pop();
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Diagnostics can start and stop locks, so it is never a way out of a
  /// real penalty; the enforcer re-sends everything afterwards.
  void _openDiagnostics(BuildContext context, GameModel m) {
    if (m.service.penaltyInEffect) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Diagnostics is unavailable while a penalty is in effect.',
          ),
        ),
      );
      return;
    }
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => BlockerSpikeScreen(blocker: widget.blocker),
          ),
        )
        .then((_) => m.resyncBlocker());
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.model,
      builder: (context, _) {
        final m = widget.model;
        final palette = switch (_tab) {
          // Calm when nothing is owed: red only while a penalty is real.
          _Tab.penalty when !m.inPenalty => HudPalette.system,
          _Tab.penalty =>
            m.dungeonPenalty ? HudPalette.dungeon : HudPalette.penalty,
          _Tab.quest when m.floorToday > 0 => HudPalette.dungeon,
          _ => HudPalette.system,
        };
        final notice = m.notice;
        return HudScope(
          palette: palette,
          child: AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle.light.copyWith(
              statusBarColor: Colors.transparent,
              systemNavigationBarColor: palette.voidColor,
            ),
            child: Scaffold(
              body: HudBackground(
                child: SafeArea(
                  child: Stack(
                    children: [
                      Column(
                        children: [
                          Expanded(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 220),
                              child: KeyedSubtree(
                                key: ValueKey(_tab),
                                child: switch (_tab) {
                                  _Tab.quest => QuestScreen(
                                    model: m,
                                    onOpenPenalty: () => _go(_Tab.penalty),
                                  ),
                                  _Tab.status => StatusScreen(
                                    model: m,
                                    onOpenSystemCheck: () =>
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => SystemCheckScreen(
                                              model: m,
                                              blocker: widget.blocker,
                                              onRestartTrial:
                                                  widget.onAbandoned == null
                                                  ? null
                                                  : () async {
                                                      if (await m.service
                                                          .abandon()) {
                                                        widget.onAbandoned!();
                                                      }
                                                    },
                                            ),
                                          ),
                                        ),
                                    onRestartTrial: widget.onAbandoned == null
                                        ? null
                                        : () async {
                                            if (await m.service.abandon()) {
                                              widget.onAbandoned!();
                                            }
                                          },
                                    onOpenReport: () => Navigator.of(context)
                                        .push(
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                ReportScreen(model: m),
                                          ),
                                        ),
                                    onChooseSystem: () =>
                                        _chooseSystem(context, m),
                                    onOpenSettings: () =>
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (ctx) => SettingsScreen(
                                              model: m,
                                              onSwitchSystem: () =>
                                                  _chooseSystem(ctx, m),
                                              onOpenDiagnostics: () =>
                                                  _openDiagnostics(ctx, m),
                                            ),
                                          ),
                                        ),
                                    // Debug builds only: diagnostics can
                                    // start and stop locks.
                                    onOpenDiagnostics: kDebugMode
                                        ? () => _openDiagnostics(context, m)
                                        : null,
                                  ),
                                  _Tab.penalty => PenaltyScreen(
                                    model: m,
                                    blocker: widget.blocker,
                                    onEditApps: () =>
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => AppPickerScreen(
                                              model: m,
                                              blocker: widget.blocker,
                                            ),
                                          ),
                                        ),
                                  ),
                                },
                              ),
                            ),
                          ),
                          // Fixed-height chrome: labels grow only to 115%.
                          MediaQuery.withClampedTextScaling(
                            maxScaleFactor: 1.15,
                            child: _NavBar(
                              current: _tab,
                              penaltyAlert: m.inPenalty,
                              onTap: _go,
                            ),
                          ),
                        ],
                      ),
                      if (notice != null)
                        Positioned.fill(
                          child: NoticeOverlay(
                            notice: notice,
                            counter: m.noticeCounter,
                            onDismiss: m.dismissNotice,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar({
    required this.current,
    required this.penaltyAlert,
    required this.onTap,
  });

  final _Tab current;
  final bool penaltyAlert;
  final ValueChanged<_Tab> onTap;

  @override
  Widget build(BuildContext context) {
    final p = HudScope.of(context);
    Widget item(_Tab t, String label, int icon, {bool alert = false}) {
      final on = t == current;
      final color = on ? p.hi : p.dim;
      return Expanded(
        child: Semantics(
          container: true,
          button: true,
          selected: on,
          label: label,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onTap(t),
            child: SizedBox(
              height: 64,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    top: 0,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      height: 2,
                      width: on ? 44 : 0,
                      decoration: BoxDecoration(
                        color: p.sys,
                        boxShadow: [
                          BoxShadow(color: p.glowColor, blurRadius: 8),
                        ],
                      ),
                    ),
                  ),
                  ExcludeSemantics(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        NavIcon(icon, color: color),
                        const SizedBox(height: 4),
                        Text(
                          label,
                          style: Hud.head(
                            11,
                            color,
                            spacing: .2,
                          ).copyWith(shadows: on ? p.textGlow(.6) : null),
                        ),
                      ],
                    ),
                  ),
                  if (alert)
                    Positioned(
                      top: 12,
                      right: 0,
                      left: 36,
                      child: Center(
                        child: Transform.rotate(
                          angle: .785,
                          child: Container(
                            width: 7,
                            height: 7,
                            color: Hud.warn,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: p.sys.withValues(alpha: .18))),
        color: p.voidColor.withValues(alpha: .85),
      ),
      child: Row(
        children: [
          item(_Tab.quest, 'QUEST', 0),
          item(_Tab.status, 'STATUS', 1),
          item(_Tab.penalty, 'PENALTY', 2, alert: penaltyAlert),
        ],
      ),
    );
  }
}
