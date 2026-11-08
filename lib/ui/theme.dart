import 'package:flutter/material.dart';

import '../domain/progression.dart';

/// Look of one mode of the app. A2 for normal use, P3 for the Penalty Zone.
/// See design/DESIGN.md.
class HudPalette {
  const HudPalette({
    required this.sys,
    required this.hi,
    required this.voidColor,
    required this.top,
    required this.panel,
    required this.text,
    required this.dim,
    required this.glow,
    required this.glowAlpha,
    required this.gridAlpha,
    required this.scanAlpha,
    required this.lineAlpha,
    this.glitch = false,
  });

  final Color sys;
  final Color hi;
  final Color voidColor;
  final Color top;
  final Color panel;
  final Color text;
  final Color dim;

  /// Blur radius of glows, in logical pixels.
  final double glow;
  final double glowAlpha;
  final double gridAlpha;
  final double scanAlpha;
  final double lineAlpha;

  /// Periodic glitch on window titles.
  final bool glitch;

  Color get line => sys.withValues(alpha: lineAlpha);
  Color get glowColor => sys.withValues(alpha: glowAlpha);

  List<Shadow> textGlow([double scale = 1]) => [
    Shadow(color: glowColor, blurRadius: glow * scale),
  ];

  /// A2: Electric Blue, Balanced.
  static const system = HudPalette(
    sys: Color(0xFF4FB3FF),
    hi: Color(0xFFA9DCFF),
    voidColor: Color(0xFF05070D),
    top: Color(0xFF0B1730),
    panel: Color(0xB80A1222),
    text: Color(0xFFDBE7FF),
    dim: Color(0xFF7D8BA8),
    glow: 10,
    glowAlpha: .45,
    gridAlpha: .05,
    scanAlpha: .018,
    lineAlpha: .35,
  );

  /// P3: Penalty red, Intense, with glitch.
  static const penalty = HudPalette(
    sys: Color(0xFFFF3B4A),
    hi: Color(0xFFFFB3B9),
    voidColor: Color(0xFF090204),
    top: Color(0xFF2A070C),
    panel: Color(0xB81E060A),
    text: Color(0xFFFFE3E5),
    dim: Color(0xFFB87C84),
    glow: 20,
    glowAlpha: .85,
    gridAlpha: .10,
    scanAlpha: .04,
    lineAlpha: .6,
    glitch: true,
  );

  /// Dungeon Penalty: darker crimson with gold, so it never feels like an
  /// ordinary failed day.
  static const dungeon = HudPalette(
    sys: Color(0xFFD7263D),
    hi: Color(0xFFF5C96A),
    voidColor: Color(0xFF060102),
    top: Color(0xFF22040A),
    panel: Color(0xC0180308),
    text: Color(0xFFFFEBD9),
    dim: Color(0xFFAE7B70),
    glow: 22,
    glowAlpha: .9,
    gridAlpha: .08,
    scanAlpha: .05,
    lineAlpha: .65,
    glitch: true,
  );
}

class Hud {
  /// Badge colour for each rank, E to S.
  static Color rankColor(Rank r) => switch (r) {
    Rank.e => const Color(0xFF9AA4B8),
    Rank.d => const Color(0xFF5BD69A),
    Rank.c => const Color(0xFF4FB3FF),
    Rank.b => const Color(0xFFB07CFF),
    Rank.a => const Color(0xFFFF9F45),
    Rank.s => gold,
  };

  static const gold = Color(0xFFF5C96A);
  static const warn = Color(0xFFFF8A93);

  static const headFont = 'ChakraPetch';
  static const monoFont = 'JetBrainsMono';

  /// The smallest text the HUD draws, in logical pixels. Smaller sizes asked
  /// for by a style are raised to this (legibility; audit iteration 1).
  static const minText = 12.0;

  static TextStyle head(double size, Color color, {double spacing = .26}) =>
      TextStyle(
        fontFamily: headFont,
        fontWeight: FontWeight.w700,
        fontSize: size < minText ? minText : size,
        letterSpacing: size * spacing,
        color: color,
      );

  static TextStyle mono(
    double size,
    Color color, {
    FontWeight weight = FontWeight.w400,
    double spacing = .04,
  }) => TextStyle(
    fontFamily: monoFont,
    fontSize: size < minText ? minText : size,
    fontWeight: weight,
    letterSpacing: size * spacing,
    color: color,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  /// For fixed-size images (the share card): exactly [size], no floor,
  /// because the image is drawn at a scale of its own.
  static TextStyle headExact(
    double size,
    Color color, {
    double spacing = .26,
  }) => head(size, color, spacing: spacing).copyWith(fontSize: size);

  static TextStyle monoExact(
    double size,
    Color color, {
    FontWeight weight = FontWeight.w400,
    double spacing = .04,
  }) => mono(
    size,
    color,
    weight: weight,
    spacing: spacing,
  ).copyWith(fontSize: size);

  static ThemeData theme(HudPalette p) => ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    scaffoldBackgroundColor: p.voidColor,
    fontFamily: monoFont,
    colorScheme: ColorScheme.dark(
      primary: p.sys,
      onPrimary: p.voidColor,
      surface: p.voidColor,
      onSurface: p.text,
      error: Hud.warn,
    ),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
  );
}

/// Makes the current palette available to every HUD widget below it.
class HudScope extends InheritedWidget {
  const HudScope({super.key, required this.palette, required super.child});

  final HudPalette palette;

  static HudPalette of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<HudScope>()?.palette ??
      HudPalette.system;

  @override
  bool updateShouldNotify(HudScope old) => old.palette != palette;
}
