import 'dart:math';

import 'package:do_or_die/app/game_service.dart';
import 'package:do_or_die/data/game_store.dart';
import 'package:do_or_die/domain/clock.dart';
import 'package:do_or_die/domain/progression.dart';
import 'package:do_or_die/domain/systems.dart';
import 'package:do_or_die/platform/blocker.dart';
import 'package:do_or_die/ui/app_shell.dart';
import 'package:do_or_die/ui/game_model.dart';
import 'package:do_or_die/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every main screen at twice the default text size: no overflow, no clipped
/// layout errors. A phone set to its largest font must still work.
void main() {
  Future<void> pumpFor(WidgetTester tester, int ms) async {
    for (var t = 0; t < ms; t += 100) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  for (final system in SystemKind.values) {
    testWidgets('${system.name}: every tab works at 200% text size', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final clock = FixedClock(DateTime(2026, 10, 19, 10));
      final g = await GameService.awaken(
        store: MemoryGameStore(),
        system: system,
        placement: Rank.e,
        dryRunDays: 0,
        blockedPackages: const {'com.instagram.android'},
        clock: clock,
        random: Random(1),
      );
      clock.set(DateTime(2026, 10, 20, 19)); // day 1 failed: a lock now
      final m = GameModel(g, pollEvery: null);
      addTearDown(m.dispose);
      await m.tick();
      await tester.pumpWidget(
        MaterialApp(
          theme: Hud.theme(HudPalette.system),
          home: MediaQuery(
            data: const MediaQueryData(
              disableAnimations: true,
              textScaler: TextScaler.linear(2),
            ),
            child: AppShell(model: m, blocker: NoopAppBlocker()),
          ),
        ),
      );
      await pumpFor(tester, 600);
      for (
        var i = 0;
        i < 6 && find.text('ACKNOWLEDGE').evaluate().isNotEmpty;
        i++
      ) {
        await pumpFor(tester, 2000);
        await tester.tap(find.text('ACKNOWLEDGE'), warnIfMissed: false);
        await pumpFor(tester, 400);
      }
      for (final tab in ['STATUS', 'PENALTY', 'QUEST']) {
        await tester.tap(find.text(tab).last, warnIfMissed: false);
        await pumpFor(tester, 600);
        final e = tester.takeException();
        if (e is FlutterError) debugPrint(e.toStringDeep());
        expect(e, isNull, reason: tab);
      }
    });
  }
}
