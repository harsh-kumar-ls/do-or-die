import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/game_service.dart';
import '../platform/blocker.dart';
import '../spike/blocker_spike_screen.dart';
import 'fx.dart';
import 'game_model.dart';
import 'screens/app_picker_screen.dart';
import 'screens/penalty_screen.dart';
import 'screens/quest_screen.dart';
import 'screens/status_screen.dart';
import 'theme.dart';
import 'widgets/hud_background.dart';
import 'widgets/notice_overlay.dart';

enum _Tab { quest, status, penalty }

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.model,
    required this.blocker,
    this.onRestarted,
  });

  final GameModel model;
  final AppBlocker blocker;

  /// Receives the fresh game after the trial is restarted.
  final ValueChanged<GameService>? onRestarted;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  _Tab _tab = _Tab.quest;

  void _go(_Tab t) {
    if (t == _tab) return;
    Fx.instance.play(t == _Tab.penalty ? Cue.penalty : Cue.window);
    setState(() => _tab = t);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.model,
      builder: (context, _) {
        final m = widget.model;
        final palette = _tab == _Tab.penalty
            ? HudPalette.penalty
            : HudPalette.system;
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
                          _TopBar(model: m, penalty: _tab == _Tab.penalty),
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
                                    onRestartTrial: widget.onRestarted == null
                                        ? null
                                        : () async {
                                            final next = await m.service
                                                .restartTrial();
                                            if (next != null) {
                                              widget.onRestarted!(next);
                                            }
                                          },
                                    onOpenDiagnostics: () {
                                      // Diagnostics can start and stop locks,
                                      // so it must never be a way out of a
                                      // real penalty.
                                      if (m.service.penaltyInEffect) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Diagnostics is unavailable while a penalty is in effect.',
                                                ),
                                              ),
                                            );
                                        return;
                                      }
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => BlockerSpikeScreen(
                                            blocker: widget.blocker,
                                          ),
                                        ),
                                      );
                                    },
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
                          _NavBar(
                            current: _tab,
                            penaltyAlert: m.inPenalty,
                            onTap: _go,
                          ),
                        ],
                      ),
                      if (notice != null)
                        Positioned.fill(
                          child: NoticeOverlay(
                            notice: notice,
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

class _TopBar extends StatelessWidget {
  const _TopBar({required this.model, required this.penalty});
  final GameModel model;
  final bool penalty;

  static const _days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
  static const _months = [
    'JAN',
    'FEB',
    'MAR',
    'APR',
    'MAY',
    'JUN',
    'JUL',
    'AUG',
    'SEP',
    'OCT',
    'NOV',
    'DEC',
  ];

  @override
  Widget build(BuildContext context) {
    final p = HudScope.of(context);
    final now = model.now;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                '${_days[now.weekday - 1]} ${now.day} ${_months[now.month - 1]}',
                style: Hud.mono(11, p.dim, spacing: .12),
              ),
              const SizedBox(width: 10),
              ValueListenableBuilder<bool>(
                valueListenable: Fx.instance.muted,
                builder: (context, muted, _) => Semantics(
                  container: true,
                  button: true,
                  label: muted ? 'Turn sound on' : 'Mute sound',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      Fx.instance.setMuted(!muted);
                      if (muted) Fx.instance.play(Cue.tap);
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        muted
                            ? Icons.volume_off_outlined
                            : Icons.volume_up_outlined,
                        size: 16,
                        color: muted ? p.dim : p.hi,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              border: Border.all(
                color: p.sys.withValues(alpha: p.lineAlpha + .2),
              ),
            ),
            child: Text(
              penalty ? 'PENALTY' : 'RANK ${model.rank.name.toUpperCase()}',
              style: Hud.head(11, p.hi, spacing: .15),
            ),
          ),
        ],
      ),
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
    Widget item(_Tab t, String label, {bool alert = false}) {
      final on = t == current;
      final color = alert ? HudPalette.penalty.hi : (on ? p.hi : p.dim);
      return Expanded(
        child: Semantics(
          container: true,
          button: true,
          selected: on,
          label: label,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onTap(t),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    height: 2,
                    width: on ? 28 : 0,
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: alert ? HudPalette.penalty.sys : p.sys,
                      boxShadow: [
                        BoxShadow(color: p.glowColor, blurRadius: p.glow * .8),
                      ],
                    ),
                  ),
                  ExcludeSemantics(
                    child: Text(
                      label,
                      style: Hud.head(11, color, spacing: .22),
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
          item(_Tab.quest, 'QUEST'),
          item(_Tab.status, 'STATUS'),
          item(_Tab.penalty, 'PENALTY', alert: penaltyAlert),
        ],
      ),
    );
  }
}
