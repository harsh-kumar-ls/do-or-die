import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../game_model.dart';
import '../theme.dart';
import 'hud_controls.dart';
import 'system_window.dart';

/// Dims the screen and shows the next queued System notice.
class NoticeOverlay extends StatelessWidget {
  const NoticeOverlay({
    super.key,
    required this.notice,
    required this.onDismiss,
  });

  final SystemNotice notice;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final palette = notice.danger ? HudPalette.penalty : HudPalette.system;
    return HudScope(
      palette: palette,
      child: ColoredBox(
        color: const Color(0xCC02040A),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: SystemWindow(
              key: ValueKey(notice),
              title: notice.title,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (i, line) in notice.lines.indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child:
                          Text(
                                line,
                                textAlign: TextAlign.center,
                                style: Hud.mono(
                                  13,
                                  line.startsWith('Reward')
                                      ? Hud.gold
                                      : palette.text,
                                ).copyWith(height: 1.5),
                              )
                              .animate(delay: (350 + i * 90).ms)
                              .fadeIn(duration: 200.ms),
                    ),
                  if (notice.levelUp != null) ...[
                    Text(
                          'LEVEL UP',
                          textAlign: TextAlign.center,
                          style: Hud.head(
                            30,
                            palette.hi,
                            spacing: .2,
                          ).copyWith(shadows: palette.textGlow(1.8)),
                        )
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .scaleXY(
                          begin: 1,
                          end: 1.06,
                          duration: 700.ms,
                          curve: Curves.easeInOut,
                        ),
                    const SizedBox(height: 6),
                    Text(
                      'Level ${notice.levelUp} reached. Stat points are available.',
                      textAlign: TextAlign.center,
                      style: Hud.mono(12, palette.dim),
                    ),
                    const SizedBox(height: 12),
                  ],
                  HudButton('ACKNOWLEDGE', onPressed: onDismiss),
                ],
              ),
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 180.ms);
  }
}
