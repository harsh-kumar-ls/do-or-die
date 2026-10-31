import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/report.dart';
import '../../domain/day.dart';
import '../../domain/progression.dart';
import '../../domain/system_catalogue.dart';
import '../theme.dart';
import 'awakening_art.dart';

/// The 30-day report as a 1080 x 1350 image (design/claude-design/
/// report-share-card.png). Laid out at 360 x 450 and captured at 3x.
class ShareCard extends StatelessWidget {
  const ShareCard({super.key, required this.r, this.honesty = true});

  static const size = Size(360, 450);

  final TrialReport r;

  /// Whether the honesty figures are on the card. The user may drop them
  /// before sharing.
  final bool honesty;

  static const _mon = [
    'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', //
    'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
  ];
  static String _d(DayKey d) => '${d.day} ${_mon[d.month - 1]}';

  static const _sys = Color(0xFF4FB3FF);
  static const _hi = Color(0xFFA9DCFF);
  static const _text = Color(0xFFDBE7FF);
  static const _dim = Color(0xFF7D8BA8);
  static const _red = Color(0xFFE5394A);
  static const _dry = Color(0xFF2A5A8A);

  @override
  Widget build(BuildContext context) {
    final range = r.calendar.isEmpty
        ? 'NO JUDGED DAYS'
        : '${_d(r.calendar.first.$1)} – ${_d(r.calendar.last.$1)}';
    final sysName = r.system == null
        ? ''
        : systemCatalogue[r.system]!.name.toUpperCase();
    final start = r.startRank ?? Rank.e;
    final now = r.rank ?? start;
    final dry = r.calendar.where((c) => c.$2 == DayMark.dryRun).length;
    final judged = r.cleared + r.failed;
    final word = judged == 0
        ? 0
        : min(100, (r.honourConfirmations * 100 / judged).round());
    return SizedBox.fromSize(
      size: size,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -1.1),
            radius: 1.3,
            colors: [Color(0xFF0B1730), Color(0xFF05070D)],
          ),
        ),
        child: CustomPaint(
          painter: const _FramePainter(),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(32, 30, 32, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text('DO OR DIE', style: Hud.head(10, _hi, spacing: .5)),
                    const Spacer(),
                    Text(range, style: Hud.mono(7.5, _dim, spacing: .2)),
                  ],
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '[ 30-DAY REPORT ]',
                    style: Hud.head(22, _hi, spacing: .22).copyWith(
                      shadows: const [Shadow(color: _sys, blurRadius: 10)],
                    ),
                  ),
                ),
                Text(sysName, style: Hud.mono(7.5, _dim, spacing: .3)),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(44, 47),
                      painter: RankHexPainter(start),
                    ),
                    const SizedBox(width: 12),
                    for (var i = 0; i < max(1, r.dungeonsCleared); i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Transform.rotate(
                          angle: pi / 4,
                          child: Container(
                            width: 8,
                            height: 8,
                            color: r.dungeonsCleared == 0
                                ? _dim.withValues(alpha: .3)
                                : Hud.gold,
                          ),
                        ),
                      ),
                    const SizedBox(width: 12),
                    CustomPaint(
                      size: const Size(58, 62),
                      painter: RankHexPainter(now),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 84,
                      height: 84,
                      child: CustomPaint(
                        painter: _DialPainter(r.clearRate / 100),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${r.clearRate}%',
                                style: Hud.head(20, Colors.white, spacing: 0),
                              ),
                              Text(
                                'CLEAR RATE',
                                style: Hud.mono(5.5, _dim, spacing: .25),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'THEN → NOW',
                            style: Hud.mono(6, _dim, spacing: .3),
                          ),
                          for (final t in r.targets.take(3))
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: _sys.withValues(alpha: .15),
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      t.label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Hud.mono(8.5, _text),
                                    ),
                                  ),
                                  Text(
                                    '${t.before} ',
                                    style: Hud.mono(7, _dim),
                                  ),
                                  Text(
                                    '${t.after}${t.unit.isEmpty ? '' : ' ${t.unit}'}',
                                    style: Hud.mono(
                                      8.5,
                                      Colors.white,
                                      weight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _Calendar(marks: [for (final c in r.calendar) c.$2]),
                const SizedBox(height: 5),
                Row(
                  children: [
                    _legend(Hud.gold, 'CLEARED ${r.cleared}'),
                    _legend(_red, 'FAILED ${r.failed}'),
                    if (dry > 0) _legend(_dry, 'DRY RUN $dry'),
                  ],
                ),
                const SizedBox(height: 8),
                if (honesty)
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: _red.withValues(alpha: .4)),
                    ),
                    child: Row(
                      children: [
                        _tile(
                          '${r.penaltyZones + r.dungeonPenalties}',
                          'PENALTY ZONES',
                        ),
                        _tile('${r.releases}', 'RELEASES'),
                        _tile('${r.reducedDays}', 'REDUCED DAYS'),
                        _tile('$word%', 'ON MY WORD', last: true),
                      ],
                    ),
                  ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.symmetric(
                      horizontal: BorderSide(
                        color: _sys.withValues(alpha: .25),
                      ),
                    ),
                  ),
                  child: Text(
                    r.headline,
                    textAlign: TextAlign.center,
                    style: Hud.head(
                      10.5,
                      _text,
                      spacing: .03,
                    ).copyWith(height: 1.4),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      'ISSUED BY THE SYSTEM',
                      style: Hud.mono(6, _dim, spacing: .3),
                    ),
                    const Spacer(),
                    Text(
                      start == now
                          ? 'RANK ${now.name.toUpperCase()}'
                          : 'RANK ${start.name.toUpperCase()} → ${now.name.toUpperCase()}',
                      style: Hud.mono(6, _dim, spacing: .3),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _legend(Color c, String label) => Padding(
    padding: const EdgeInsets.only(right: 12),
    child: Row(
      children: [
        Container(width: 5, height: 5, color: c),
        const SizedBox(width: 4),
        Text(label, style: Hud.mono(6, _dim, spacing: .25)),
      ],
    ),
  );

  static Widget _tile(String value, String label, {bool last = false}) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            border: last
                ? null
                : Border(right: BorderSide(color: _red.withValues(alpha: .4))),
          ),
          child: Column(
            children: [
              Text(value, style: Hud.head(13, Colors.white, spacing: 0)),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(label, style: Hud.mono(5, _dim, spacing: .25)),
              ),
            ],
          ),
        ),
      );
}

/// Thirty squares in two rows of fifteen, oldest first.
class _Calendar extends StatelessWidget {
  const _Calendar({required this.marks});
  final List<DayMark> marks;

  @override
  Widget build(BuildContext context) {
    final cells = [
      ...marks.length > 30 ? marks.sublist(marks.length - 30) : marks,
      for (var i = marks.length; i < 30; i++) DayMark.none,
    ];
    Color colour(DayMark m) => switch (m) {
      DayMark.cleared => Hud.gold,
      DayMark.failed => ShareCard._red,
      DayMark.dryRun => ShareCard._dry,
      DayMark.none => const Color(0x1A4FB3FF),
    };
    return Column(
      children: [
        for (var row = 0; row < 2; row++)
          Padding(
            padding: EdgeInsets.only(bottom: row == 0 ? 3 : 0),
            child: Row(
              children: [
                for (var i = 0; i < 15; i++) ...[
                  if (i > 0) const SizedBox(width: 3),
                  Expanded(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: ColoredBox(color: colour(cells[row * 15 + i])),
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _DialPainter extends CustomPainter {
  const _DialPainter(this.value);
  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..color = const Color(0xFF1A2236);
    canvas.drawArc(rect.deflate(4), 0, 2 * pi, false, track);
    canvas.drawArc(
      rect.deflate(4),
      -pi / 2,
      2 * pi * value.clamp(0, 1),
      false,
      track..color = Hud.gold,
    );
  }

  @override
  bool shouldRepaint(_DialPainter old) => old.value != value;
}

/// Outer rule and corner brackets.
class _FramePainter extends CustomPainter {
  const _FramePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .7
      ..color = const Color(0x554FB3FF);
    canvas.drawRect(
      Rect.fromLTRB(15, 15, size.width - 15, size.height - 15),
      line,
    );
    final b = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = ShareCard._hi;
    const k = 14.0;
    for (final (x, y, dx, dy) in [
      (11.0, 11.0, 1.0, 1.0),
      (size.width - 11, 11.0, -1.0, 1.0),
      (11.0, size.height - 11, 1.0, -1.0),
      (size.width - 11, size.height - 11, -1.0, -1.0),
    ]) {
      canvas.drawPath(
        Path()
          ..moveTo(x, y + dy * k)
          ..lineTo(x, y)
          ..lineTo(x + dx * k, y),
        b,
      );
    }
  }

  @override
  bool shouldRepaint(_FramePainter old) => false;
}

/// Renders the card behind [key] to PNG at 1080 x 1350 and opens the
/// share sheet.
Future<void> shareCardImage(GlobalKey key) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 1080 / ShareCard.size.width);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  if (data == null) return;
  await SharePlus.instance.share(
    ShareParams(
      files: [
        XFile.fromData(
          data.buffer.asUint8List(),
          mimeType: 'image/png',
          name: 'do-or-die-report.png',
        ),
      ],
      fileNameOverrides: const ['do-or-die-report.png'],
    ),
  );
}
