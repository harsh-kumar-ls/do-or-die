import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/progression.dart';
import '../fx.dart';
import '../game_model.dart';
import '../theme.dart';
import 'awakening_art.dart';
import 'hud_controls.dart';
import 'system_frame.dart';

/// System notices, built from design/claude-design/notices.html. Each kind
/// has its own colour theme, entrance and illustration; ACKNOWLEDGE arms
/// only once the entrance has played, so a reflex tap can't dismiss an
/// unseen notice.
class NoticeOverlay extends StatelessWidget {
  const NoticeOverlay({
    super.key,
    required this.notice,
    required this.onDismiss,
    this.counter = '',
  });

  final SystemNotice notice;
  final VoidCallback onDismiss;

  /// "NOTICE 1 / 3" when several are queued.
  final String counter;

  @override
  Widget build(BuildContext context) => _Notice(
    key: ObjectKey(notice),
    notice: notice,
    onDismiss: onDismiss,
    counter: counter,
  );
}

enum _Theme { blue, gold, red, crimson }

_Theme _themeOf(NoticeKind k) => switch (k) {
  NoticeKind.cleared || NoticeKind.complete => _Theme.gold,
  NoticeKind.warning => _Theme.red,
  NoticeKind.dungeonFailed => _Theme.crimson,
  _ => _Theme.blue,
};

HudPalette _paletteOf(_Theme t) => switch (t) {
  _Theme.blue => HudPalette.system,
  _Theme.red => HudPalette.penalty,
  _Theme.crimson => HudPalette.dungeon,
  _Theme.gold => const HudPalette(
    sys: Hud.gold,
    hi: Hud.gold,
    voidColor: Color(0xFF0B0A07),
    top: Color(0xFF17140C),
    panel: Color(0xB817140C),
    text: Color(0xFFDBE7FF),
    dim: Color(0xFF8A8676),
    glow: 12,
    glowAlpha: .55,
    gridAlpha: 0,
    scanAlpha: 0,
    lineAlpha: .55,
  ),
};

Color _scrimOf(_Theme t) => switch (t) {
  _Theme.blue => const Color(0xCC03050A),
  _Theme.gold => const Color(0xCC050402),
  _Theme.red => const Color(0xD6090204),
  _Theme.crimson => const Color(0xEB060102),
};

class _Notice extends StatefulWidget {
  const _Notice({
    super.key,
    required this.notice,
    required this.onDismiss,
    required this.counter,
  });

  final SystemNotice notice;
  final VoidCallback onDismiss;
  final String counter;

  @override
  State<_Notice> createState() => _NoticeState();
}

class _NoticeState extends State<_Notice> with TickerProviderStateMixin {
  late final _enter = AnimationController(vsync: this, duration: _enterTime);
  late final _art = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2000),
  );
  late final _loop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat();
  final _fx = FlashController();
  bool _armed = false;
  final _timers = <Timer>[];

  SystemNotice get n => widget.notice;
  _Theme get theme => _themeOf(n.kind);

  /// Window entrance delay (after the illustration plays).
  Duration get _windowDelay => switch (n.kind) {
    NoticeKind.gate => const Duration(milliseconds: 550),
    NoticeKind.rankUp => const Duration(milliseconds: 1300),
    NoticeKind.complete => const Duration(milliseconds: 650),
    NoticeKind.dungeonFailed => const Duration(milliseconds: 150),
    _ => Duration.zero,
  };

  Duration get _enterTime => switch (n.kind) {
    NoticeKind.levelUp => const Duration(milliseconds: 500),
    NoticeKind.warning => const Duration(milliseconds: 300),
    NoticeKind.dungeonFailed => const Duration(milliseconds: 280),
    NoticeKind.gate ||
    NoticeKind.rankUp ||
    NoticeKind.complete => const Duration(milliseconds: 350),
    _ => const Duration(milliseconds: 400),
  };

  /// When ACKNOWLEDGE becomes active.
  Duration get _armAfter => switch (n.kind) {
    NoticeKind.rankUp => const Duration(milliseconds: 1900),
    NoticeKind.warning ||
    NoticeKind.dungeonFailed ||
    NoticeKind.levelUp => const Duration(milliseconds: 1300),
    NoticeKind.gate => const Duration(milliseconds: 1000),
    _ => const Duration(milliseconds: 900),
  };

  void _at(int ms, VoidCallback f) => _timers.add(
    Timer(Duration(milliseconds: ms), () {
      if (mounted) f();
    }),
  );

  @override
  void initState() {
    super.initState();
    Fx.instance.play(n.sound);
    _art.forward();
    _at(_windowDelay.inMilliseconds, () => _enter.forward());
    _at(_armAfter.inMilliseconds, () => setState(() => _armed = true));
    switch (n.kind) {
      case NoticeKind.cleared:
        _at(0, _fx.flash);
        HapticFeedback.mediumImpact();
      case NoticeKind.warning:
        _at(300, () {
          _fx
            ..flash()
            ..shake();
          HapticFeedback.heavyImpact();
        });
      case NoticeKind.dungeonFailed:
        _at(430, () {
          _fx
            ..flash()
            ..shake();
          HapticFeedback.vibrate();
        });
      case NoticeKind.levelUp:
        _at(1050, _fx.flash);
      case NoticeKind.gate:
        _at(200, _fx.flash);
      case NoticeKind.rankUp:
        _at(450, () {
          _fx.flash();
          HapticFeedback.heavyImpact();
        });
        _at(1350, () {
          _fx
            ..flash()
            ..shake();
        });
      case NoticeKind.complete:
        _at(800, _fx.flash);
      case NoticeKind.dryRun:
      case NoticeKind.info:
        break;
    }
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    _enter.dispose();
    _art.dispose();
    _loop.dispose();
    _fx.dispose();
    super.dispose();
  }

  Widget _entrance(Widget child) {
    final reduce = MediaQuery.of(context).disableAnimations;
    return AnimatedBuilder(
      animation: _enter,
      builder: (context, c) {
        final t = _enter.value;
        if (reduce) return Opacity(opacity: t, child: c);
        switch (n.kind) {
          case NoticeKind.levelUp:
            // A line grows across, then opens vertically.
            final x = Curves.easeInOut.transform((t * 2).clamp(0, 1));
            final y = t < .5
                ? .012
                : .012 + .988 * Curves.easeInOut.transform((t - .5) * 2);
            return Opacity(
              opacity: t == 0 ? 0 : 1,
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.diagonal3Values(x, y, 1),
                child: c,
              ),
            );
          case NoticeKind.warning:
            // Glitch: jitter and slices, then settle.
            final dx = t >= 1
                ? 0.0
                : [-8.0, 6.0, -4.0, 3.0, -1.0][(t * 5).floor().clamp(0, 4)];
            return Opacity(
              opacity: t == 0 ? 0 : 1,
              child: Transform.translate(offset: Offset(dx, 0), child: c),
            );
          case NoticeKind.dungeonFailed:
            // Slam: falls in from 1.18, no ease-out.
            final s = 1.18 - .18 * Curves.easeInQuint.transform(t);
            return Opacity(
              opacity: t == 0 ? 0 : 1,
              child: Transform.scale(scale: s, child: c),
            );
          case NoticeKind.gate:
          case NoticeKind.rankUp:
          case NoticeKind.complete:
            final e = Curves.easeOutCubic.transform(t);
            return Opacity(
              opacity: e,
              child: Transform.translate(
                offset: Offset(0, 18 * (1 - e)),
                child: c,
              ),
            );
          case NoticeKind.cleared:
          case NoticeKind.dryRun:
          case NoticeKind.info:
            // Power on: scaleY from 0.04.
            final y = .04 + .96 * Curves.easeOutExpo.transform(t);
            return Opacity(
              opacity: (t * 3).clamp(0, 1),
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.diagonal3Values(1, y, 1),
                child: c,
              ),
            );
        }
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pal = _paletteOf(theme);
    final art = _artwork();
    return HudScope(
      palette: pal,
      child: FlashLayer(
        controller: _fx,
        child: ColoredBox(
          color: _scrimOf(theme),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, c) => Stack(
                children: [
                  if (n.kind == NoticeKind.gate)
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 30,
                      height: min(420, c.maxHeight * .6),
                      child: AnimatedBuilder(
                        animation: Listenable.merge([_art, _loop]),
                        builder: (context, _) => CustomPaint(
                          painter: _RiftPainter(
                            Hud.rankColor(n.rankFrom ?? Rank.e),
                            _art.value,
                            _loop.value,
                          ),
                        ),
                      ),
                    ),
                  Align(
                    alignment: n.kind == NoticeKind.gate
                        ? Alignment.bottomCenter
                        : Alignment.center,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(22, 24, 22, 40),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (art != null) ...[
                            Center(child: art),
                            const SizedBox(height: 18),
                          ],
                          _entrance(_window(pal)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget? _artwork() {
    switch (n.kind) {
      case NoticeKind.rankUp:
        return AnimatedBuilder(
          animation: _art,
          builder: (context, _) => CustomPaint(
            size: const Size(150, 160),
            painter: _ShatterPainter(
              n.rankFrom ?? Rank.e,
              n.rankTo ?? Rank.d,
              _art.value * 2000,
            ),
          ),
        );
      case NoticeKind.complete:
        return AnimatedBuilder(
          animation: Listenable.merge([_art, _loop]),
          builder: (context, _) {
            final bloom = Curves.easeOutCubic.transform(
              ((_art.value * 2000 - 200) / 600).clamp(0, 1),
            );
            return SizedBox(
              width: 220,
              height: 200,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Opacity(
                    opacity: bloom,
                    child: CustomPaint(
                      size: const Size(220, 200),
                      painter: _RaysPainter(_loop.value),
                    ),
                  ),
                  Opacity(
                    opacity: bloom,
                    child: Transform.scale(
                      scale: .7 + .3 * bloom,
                      child: const CustomPaint(
                        size: Size(150, 160),
                        painter: RankHexPainter(Rank.s),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      default:
        return null;
    }
  }

  Widget _window(HudPalette pal) {
    final kids = <Widget>[
      Row(
        children: [
          Text(widget.counter, style: Hud.mono(9, pal.hi, spacing: .22)),
          const Spacer(),
          Text(
            n.kicker.toUpperCase(),
            style: Hud.mono(9, pal.dim, spacing: .22),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Text(
        n.title,
        textAlign: TextAlign.center,
        style: Hud.head(
          17,
          pal.hi,
          spacing: .26,
        ).copyWith(shadows: pal.textGlow(1)),
      ),
      Container(
        height: 1,
        margin: const EdgeInsets.only(top: 12, bottom: 14),
        color: pal.sys.withValues(alpha: .22),
      ),
      ..._body(pal),
      if (n.rows.isNotEmpty) ...[
        const SizedBox(height: 14),
        _DashedRule(color: pal.sys.withValues(alpha: .25)),
        const SizedBox(height: 12),
        for (final r in n.rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Text(r.label, style: Hud.mono(12, pal.dim))),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    r.value,
                    textAlign: TextAlign.right,
                    style: Hud.mono(12, switch (r.tone) {
                      RowTone.ok => const Color(0xFF5BD69A),
                      RowTone.bad => const Color(0xFFFF3B4A),
                      RowTone.gold => Hud.gold,
                      RowTone.plain => pal.text,
                    }),
                  ),
                ),
              ],
            ),
          ),
      ],
      if (n.note != null) ...[
        const SizedBox(height: 8),
        Text(
          n.note!,
          textAlign: TextAlign.center,
          style: Hud.mono(11, pal.dim).copyWith(height: 1.5),
        ),
      ],
      const SizedBox(height: 18),
      AnimatedOpacity(
        opacity: _armed ? 1 : .25,
        duration: const Duration(milliseconds: 200),
        child: CutButton(
          'ACKNOWLEDGE',
          danger: theme == _Theme.red,
          onPressed: _armed ? widget.onDismiss : null,
        ),
      ),
    ];
    return HudFrame(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Semantics(
        container: true,
        label: n.title,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: kids,
        ),
      ),
    );
  }

  List<Widget> _body(HudPalette pal) {
    Text lead(String t, [Color? c, FontWeight w = FontWeight.w400]) => Text(
      t,
      textAlign: TextAlign.center,
      style: Hud.mono(14, c ?? pal.text, weight: w).copyWith(height: 1.55),
    );
    switch (n.kind) {
      case NoticeKind.cleared:
        final xp = n.xp ?? 0;
        return [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CustomPaint(size: Size(56, 56), painter: _CheckDiamond()),
              const SizedBox(width: 14),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: xp.toDouble()),
                    duration: const Duration(milliseconds: 1000),
                    curve: Curves.easeOutCubic,
                    builder: (context, v, _) => Text(
                      '+${v.round()} XP',
                      style: Hud.mono(40, Hud.gold, weight: FontWeight.w700)
                          .copyWith(
                            shadows: [
                              Shadow(
                                color: Hud.gold.withValues(alpha: .6),
                                blurRadius: 14,
                              ),
                            ],
                          ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (n.xpMax != null) ...[
            const SizedBox(height: 14),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 1000),
              builder: (context, k, _) {
                final from = n.xpFrom ?? 0;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _XpFill(from: from, add: xp, max: n.xpMax!, k: k),
                    const SizedBox(height: 6),
                    Text(
                      '${from + (xp * k).round()} / ${n.xpMax}',
                      textAlign: TextAlign.right,
                      style: Hud.mono(10, pal.dim, spacing: .14),
                    ),
                  ],
                );
              },
            ),
          ],
        ];
      case NoticeKind.levelUp:
        return [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text('LV', style: Hud.head(22, pal.dim, spacing: .2)),
              ),
              const SizedBox(width: 10),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 1, end: (n.level ?? 1).toDouble()),
                duration: const Duration(milliseconds: 1050),
                curve: Curves.easeOutCubic,
                builder: (context, v, _) => Text(
                  '${v.round()}',
                  style: Hud.mono(58, Colors.white, weight: FontWeight.w700)
                      .copyWith(
                        shadows: [Shadow(color: pal.sys, blurRadius: 16)],
                        height: 1.1,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '+${n.points ?? 0} STAT POINTS',
            textAlign: TextAlign.center,
            style: Hud.head(14, Hud.gold, spacing: .2),
          ),
          if (n.stats.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final s in n.stats)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: pal.sys.withValues(alpha: .2),
                      border: Border.all(color: pal.sys.withValues(alpha: .55)),
                    ),
                    child: Text(s, style: Hud.head(12, pal.hi, spacing: .2)),
                  ),
              ],
            ),
          ],
        ];
      case NoticeKind.warning:
        return [
          Center(
            child: AnimatedBuilder(
              animation: _loop,
              builder: (context, _) => Opacity(
                opacity: .7 + .3 * cos(_loop.value * 2 * pi),
                child: const CustomPaint(
                  size: Size(52, 52),
                  painter: _WarnPainter(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          lead(n.lines.first),
          if (n.lines.length > 1) lead(n.lines[1], const Color(0xFFFF6A75)),
        ];
      case NoticeKind.dungeonFailed:
        return [
          Center(
            child: AnimatedBuilder(
              animation: _loop,
              builder: (context, _) => CustomPaint(
                size: const Size(52, 52),
                painter: _SealPaint(_loop.value / 16),
              ),
            ),
          ),
          const SizedBox(height: 10),
          for (final l in n.lines) lead(l),
          lead('Your rank is kept.', Hud.gold),
        ];
      case NoticeKind.gate:
        final rc = Hud.rankColor(n.rankFrom ?? Rank.e);
        return [
          lead(n.lines.first),
          if (n.lines.length > 1) lead(n.lines[1], rc, FontWeight.w700),
          if (n.lines.length > 2) lead(n.lines[2]),
          if (n.closesAt != null) ...[
            const SizedBox(height: 12),
            Ticker1s(
              builder: (context) => Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text('CLOSES IN', style: Hud.mono(10, pal.dim, spacing: .22)),
                  const SizedBox(width: 10),
                  Text(
                    hms(n.closesAt!.difference(DateTime.now())),
                    style: Hud.mono(
                      22,
                      Colors.white,
                      weight: FontWeight.w700,
                    ).copyWith(shadows: pal.textGlow(.8)),
                  ),
                ],
              ),
            ),
          ],
        ];
      case NoticeKind.rankUp:
        final f = n.rankFrom ?? Rank.e, t = n.rankTo ?? Rank.d;
        return [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                f.name.toUpperCase(),
                style: Hud.head(28, Hud.rankColor(f), spacing: .2),
              ),
              const SizedBox(width: 14),
              Icon(Icons.arrow_right_alt, color: pal.dim),
              const SizedBox(width: 14),
              Text(
                t.name.toUpperCase(),
                style: Hud.head(28, Hud.rankColor(t), spacing: .2).copyWith(
                  shadows: [Shadow(color: Hud.rankColor(t), blurRadius: 12)],
                ),
              ),
            ],
          ),
          if (n.rankTitle != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Hud.gold.withValues(alpha: .06),
                border: Border.all(color: Hud.gold.withValues(alpha: .4)),
              ),
              child: Column(
                children: [
                  Text(
                    'TITLE EARNED',
                    style: Hud.mono(10, pal.dim, spacing: .22),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    n.rankTitle!,
                    textAlign: TextAlign.center,
                    style: Hud.head(15, Hud.gold, spacing: .14),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            '+${n.points ?? 0} STAT POINTS',
            textAlign: TextAlign.center,
            style: Hud.head(14, Hud.gold, spacing: .2),
          ),
        ];
      case NoticeKind.complete:
        return [
          if (n.lines.isNotEmpty) lead(n.lines.first),
          if (n.lines.length > 1) lead(n.lines[1], Hud.gold),
        ];
      case NoticeKind.dryRun:
      case NoticeKind.info:
        return [for (final l in n.lines) lead(l)];
    }
  }
}

class _DashedRule extends StatelessWidget {
  const _DashedRule({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) => Row(
      children: [
        for (var i = 0; i < (c.maxWidth / 7).floor(); i++)
          Container(
            width: 4,
            height: 1,
            margin: const EdgeInsets.only(right: 3),
            color: color,
          ),
      ],
    ),
  );
}

class _XpFill extends StatelessWidget {
  const _XpFill({
    required this.from,
    required this.add,
    required this.max,
    required this.k,
  });
  final int from;
  final int add;
  final int max;
  final double k;

  @override
  Widget build(BuildContext context) {
    final cur = ((from + add * k) / max).clamp(0.0, 1.0);
    final pend = ((add * (1 - k)) / max).clamp(0.0, 1.0 - cur);
    return SizedBox(
      height: 6,
      child: LayoutBuilder(
        builder: (context, c) => Stack(
          children: [
            const Positioned.fill(child: ColoredBox(color: Color(0x337D8BA8))),
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: c.maxWidth * cur,
              child: const ColoredBox(color: Color(0xFF4FB3FF)),
            ),
            Positioned(
              left: c.maxWidth * cur,
              top: 0,
              bottom: 0,
              width: c.maxWidth * pend,
              child: ColoredBox(color: Hud.gold.withValues(alpha: .7)),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckDiamond extends CustomPainter {
  const _CheckDiamond();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 64);
    final p = Paint()
      ..color = Hud.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 3);
    canvas.drawPath(
      Path()
        ..moveTo(32, 3)
        ..lineTo(61, 32)
        ..lineTo(32, 61)
        ..lineTo(3, 32)
        ..close(),
      p,
    );
    canvas.drawPath(
      Path()
        ..moveTo(19, 33)
        ..lineTo(28, 42)
        ..lineTo(45, 22),
      p..strokeWidth = 4,
    );
  }

  @override
  bool shouldRepaint(_CheckDiamond old) => false;
}

class _WarnPainter extends CustomPainter {
  const _WarnPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFFFF3B4A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4);
    canvas.drawPath(
      Path()
        ..moveTo(26, 4)
        ..lineTo(49, 46)
        ..lineTo(3, 46)
        ..close(),
      p,
    );
    canvas
      ..drawLine(const Offset(26, 19), const Offset(26, 32), p)
      ..drawLine(const Offset(26, 37), const Offset(26, 40), p);
  }

  @override
  bool shouldRepaint(_WarnPainter old) => false;
}

class _SealPaint extends CustomPainter {
  _SealPaint(this.turn);
  final double turn;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 52);
    final gold = Paint()
      ..color = Hud.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.save();
    canvas.translate(26, 26);
    canvas.rotate(turn * 2 * pi);
    for (var a = 0.0; a < 2 * pi; a += 6 / 24) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset.zero, radius: 24),
        a,
        3 / 24,
        false,
        gold,
      );
    }
    canvas.restore();
    canvas.drawPath(
      Path()
        ..moveTo(26, 6)
        ..lineTo(44, 26)
        ..lineTo(26, 46)
        ..lineTo(8, 26)
        ..close(),
      Paint()
        ..color = const Color(0xFFD7263D)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    final x = Paint()
      ..color = Hud.gold
      ..strokeWidth = 2;
    canvas
      ..drawLine(const Offset(18, 18), const Offset(34, 34), x)
      ..drawLine(const Offset(34, 18), const Offset(18, 34), x);
  }

  @override
  bool shouldRepaint(_SealPaint old) => old.turn != turn;
}

/// The Gate rift: a crack grows, the portal tears open sideways, dashed
/// rings flow and the core pulses ([open] 0..1 over 2 s, [loop] 0..1).
class _RiftPainter extends CustomPainter {
  _RiftPainter(this.c, this.open, this.loop);
  final Color c;
  final double open;
  final double loop;

  @override
  void paint(Canvas canvas, Size size) {
    final k = min(size.width / 300, size.height / 420);
    canvas.translate(size.width / 2 - 150 * k, 0);
    canvas.scale(k);
    final ms = open * 2000;
    final crack = (ms / 200).clamp(0.0, 1.0);
    final crackFade = 1 - ((ms - 450) / 250).clamp(0.0, 1.0);
    if (crackFade > 0) {
      final path = Path()
        ..moveTo(150, 16)
        ..lineTo(143, 78)
        ..lineTo(157, 132)
        ..lineTo(145, 204)
        ..lineTo(156, 262)
        ..lineTo(146, 332)
        ..lineTo(150, 404);
      canvas.save();
      canvas.translate(0, 210);
      canvas.scale(1, crack);
      canvas.translate(0, -210);
      canvas.drawPath(
        path,
        Paint()
          ..color = c.withValues(alpha: crackFade)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4),
      );
      canvas.restore();
    }
    final o = Curves.easeOutExpo.transform(((ms - 200) / 450).clamp(0.0, 1.0));
    if (o <= 0) return;
    canvas.save();
    canvas.translate(150, 210);
    canvas.scale(.04 + .96 * o, 1);
    canvas.translate(-150, -210);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(150, 210), width: 300, height: 430),
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                Colors.white.withValues(alpha: .5),
                c.withValues(alpha: .4),
                c.withValues(alpha: .08),
                c.withValues(alpha: 0),
              ],
              stops: const [0, .22, .7, 1],
            ).createShader(
              Rect.fromCenter(
                center: const Offset(150, 210),
                width: 300,
                height: 430,
              ),
            ),
    );
    final rim = Path();
    for (var i = 0; i <= 72; i++) {
      final a = i / 72 * 2 * pi;
      final j =
          1 + .045 * sin(i * 1.7) + .03 * cos(i * 4.1) + .025 * sin(i * 9.3);
      final pt = Offset(150 + sin(a) * 112 * j, 210 - cos(a) * 192 * j);
      i == 0 ? rim.moveTo(pt.dx, pt.dy) : rim.lineTo(pt.dx, pt.dy);
    }
    canvas.drawPath(rim, Paint()..color = const Color(0x8C05070D));
    canvas.drawPath(
      rim,
      Paint()
        ..color = c
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4),
    );
    void dashedOval(
      double rx,
      double ry,
      double dash,
      double gap,
      double phase,
      double w,
      double a,
    ) {
      final oval = Path()
        ..addOval(
          Rect.fromCenter(
            center: const Offset(150, 210),
            width: rx * 2,
            height: ry * 2,
          ),
        );
      final paint = Paint()
        ..color = c.withValues(alpha: a)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w;
      for (final m in oval.computeMetrics()) {
        for (var d = -phase; d < m.length; d += dash + gap) {
          canvas.drawPath(m.extractPath(max(0, d), max(0, d + dash)), paint);
        }
      }
    }

    dashedOval(90, 160, 6, 10, loop * 64, 1.5, .8);
    dashedOval(58, 112, 40, 24, (1 - loop) * 64, 1.2, .7);
    final pulse = 1 + .25 * sin(loop * 2 * pi);
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(150, 210),
        width: 52 * pulse,
        height: 144 * pulse,
      ),
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                Colors.white.withValues(alpha: .9),
                c.withValues(alpha: .8),
                c.withValues(alpha: 0),
              ],
              stops: const [0, .3, 1],
            ).createShader(
              Rect.fromCenter(
                center: const Offset(150, 210),
                width: 52,
                height: 144,
              ),
            ),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RiftPainter old) => old.open != open || old.loop != loop;
}

/// Rank up: the old badge cracks (300 ms), shatters into 12 shards (450 ms),
/// the new outline draws (650 ms) and the letter stamps in (1100 ms).
class _ShatterPainter extends CustomPainter {
  _ShatterPainter(this.from, this.to, this.ms);
  final Rank from;
  final Rank to;
  final double ms;

  static const _v = [
    Offset(58, 6), Offset(108, 34), Offset(108, 90), //
    Offset(58, 118), Offset(8, 90), Offset(8, 34),
  ];
  static const _c = Offset(58, 62);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 116);
    final fromC = Hud.rankColor(from), toC = Hud.rankColor(to);
    // Old badge: whole until 450 ms, cracks from 300 ms, then shards fly.
    if (ms < 450) {
      RankHexPainter(from).paint(canvas, const Size(116, 124));
      final crack = ((ms - 300) / 150).clamp(0.0, 1.0);
      if (crack > 0) {
        final line = Paint()
          ..color = Colors.white
          ..strokeWidth = 1.2;
        for (final v in _v) {
          canvas.drawLine(_c, Offset.lerp(_c, v, crack)!, line);
        }
      }
    } else if (ms < 970) {
      final t = Curves.easeOutCubic.transform((ms - 450) / 520);
      for (var i = 0; i < 6; i++) {
        final a = _v[i], b = _v[(i + 1) % 6];
        final mid = Offset.lerp(a, b, .5)!;
        for (final tri in [
          [_c, a, mid],
          [_c, mid, b],
        ]) {
          final cen = (tri[0] + tri[1] + tri[2]) / 3;
          final k = 2 + (i * 37 % 10) / 10;
          canvas.save();
          canvas.translate((cen.dx - 58) * k * t, (cen.dy - 62) * k * t);
          canvas.translate(cen.dx, cen.dy);
          canvas.rotate(((i * 53 % 120) - 60) * pi / 180 * t);
          canvas.translate(-cen.dx, -cen.dy);
          canvas.drawPath(
            Path()..addPolygon(tri, true),
            Paint()..color = fromC.withValues(alpha: .7 * (1 - t)),
          );
          canvas.restore();
        }
      }
    }
    // New badge.
    if (ms >= 650) {
      final draw = Curves.easeOutCubic.transform(
        ((ms - 650) / 450).clamp(0.0, 1.0),
      );
      final hex = Path()..addPolygon(_v, true);
      final outline = Paint()
        ..color = toC
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4);
      for (final m in hex.computeMetrics()) {
        canvas.drawPath(m.extractPath(0, m.length * draw), outline);
      }
      if (ms >= 1100) {
        final s = Curves.easeInQuad.transform(
          ((ms - 1100) / 250).clamp(0.0, 1.0),
        );
        canvas.drawPath(hex, Paint()..color = const Color(0xEB0A1222));
        canvas.drawPath(hex, outline);
        final tp = TextPainter(
          text: TextSpan(
            text: to.name.toUpperCase(),
            style: Hud.head(
              52,
              toC,
              spacing: 0,
            ).copyWith(shadows: [Shadow(color: toC, blurRadius: 12)]),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        canvas.save();
        canvas.translate(58, 62);
        canvas.scale(1.6 - .6 * s);
        tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
        canvas.restore();
        final ring = ((ms - 1350) / 450).clamp(0.0, 1.0);
        if (ring > 0 && ring < 1) {
          canvas.save();
          canvas.translate(58, 62);
          canvas.scale(1 + .7 * ring);
          canvas.translate(-58, -62);
          canvas.drawPath(
            hex,
            Paint()
              ..color = toC.withValues(alpha: .9 * (1 - ring))
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2,
          );
          canvas.restore();
        }
      }
    }
  }

  @override
  bool shouldRepaint(_ShatterPainter old) => old.ms != ms;
}

/// Gold rays behind the S badge, one turn every 60 s.
class _RaysPainter extends CustomPainter {
  _RaysPainter(this.loop);
  final double loop;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    canvas.drawCircle(
      c,
      100,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Hud.gold.withValues(alpha: .45),
            Hud.gold.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: 100)),
    );
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(loop * 2 * pi / 25);
    for (var i = 0; i < 28; i++) {
      canvas.save();
      canvas.rotate(i * 2 * pi / 28);
      canvas.drawPath(
        Path()
          ..moveTo(-3, -60)
          ..lineTo(0, -(100.0 + (i % 3) * 12))
          ..lineTo(3, -60)
          ..close(),
        Paint()..color = Hud.gold.withValues(alpha: i.isOdd ? .18 : .32),
      );
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RaysPainter old) => old.loop != loop;
}
