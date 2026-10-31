import 'dart:math';

import 'package:do_or_die/app/game_service.dart';
import 'package:do_or_die/data/game_store.dart';
import 'package:do_or_die/domain/clock.dart';
import 'package:do_or_die/domain/progression.dart';
import 'package:do_or_die/domain/systems.dart';
import 'package:do_or_die/platform/blocker.dart';
import 'package:do_or_die/ui/app_shell.dart';
import 'package:do_or_die/ui/game_model.dart';
import 'package:do_or_die/ui/screens/onboarding_screen.dart';
import 'package:do_or_die/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<GameModel> pumpShell(
    WidgetTester tester, {
    Clock? clock,
    VoidCallback? onAbandoned,
    SystemKind system = SystemKind.fitness,
    Future<void> Function(GameService)? prepare,
  }) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final service = await GameService.awaken(
      store: MemoryGameStore(),
      system: system,
      placement: Rank.e,
      dryRunDays: 0,
      blockedPackages: const {'com.instagram.android'},
      clock: clock ?? const SystemClock(),
      random: Random(1),
    );
    if (prepare != null) await prepare(service);
    final model = GameModel(service, pollEvery: null);
    addTearDown(model.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: Hud.theme(HudPalette.system),
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: AppShell(
            model: model,
            blocker: NoopAppBlocker(),
            onAbandoned: onAbandoned ?? () {},
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    return model;
  }

  /// True if [finder]'s widget is fully on screen and its centre is the
  /// widget actually hit by a tap there (not hidden in a scroll area).
  bool reallyVisible(WidgetTester tester, Finder finder) {
    final rect = tester.getRect(finder);
    final screen =
        Offset.zero & tester.view.physicalSize / tester.view.devicePixelRatio;
    if (!screen.contains(rect.topLeft) || !screen.contains(rect.bottomRight)) {
      return false;
    }
    final hits = tester.hitTestOnBinding(rect.center).path.map((e) => e.target);
    final box = tester.renderObject(finder);
    return hits.contains(box);
  }

  testWidgets(
    'with no penalty, RESTART TRIAL is visible on Status without scrolling',
    (tester) async {
      await pumpShell(tester);
      await tester.tap(find.text('STATUS'));
      await tester.pump(const Duration(milliseconds: 600));
      final button = find.text('HOLD 3S · RESTART TRIAL');
      expect(button, findsOneWidget);
      expect(reallyVisible(tester, button), isTrue);
      await tester.pump(const Duration(seconds: 1)); // let title animations end
    },
  );

  testWidgets(
    'while push-ups are owed, Status says exactly what blocks the restart',
    (tester) async {
      final clock = FixedClock(DateTime(2026, 10, 19, 10));
      final model = await pumpShell(tester, clock: clock);
      clock.set(
        DateTime(2026, 10, 20, 6, 30),
      ); // Monday failed, before any lock
      await model.tick();
      await tester.pump(const Duration(milliseconds: 600));
      // The failed day's [ WARNING ] notice covers the screen until acknowledged.
      await tester.tap(find.text('ACKNOWLEDGE'));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tap(find.text('STATUS'));
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('HOLD 3S · RESTART TRIAL'), findsNothing);
      final reason = find.text(
        "Finish today's 50 push-ups and wait for today's lock to end to unlock restart.",
      );
      expect(reason, findsOneWidget);
      expect(reallyVisible(tester, reason), isTrue);
      // The message must not give away when the scheduled lock starts.
      final start = model.state.lock!.start;
      final startHm =
          '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';
      expect(find.textContaining(startHm), findsNothing);
      await tester.pump(const Duration(seconds: 1)); // let title animations end
    },
  );

  Future<void> openStatus(WidgetTester tester) async {
    await tester.tap(find.text('STATUS'));
    await tester.pump(const Duration(milliseconds: 600));
  }

  const diagnosticsTitle = 'Blocking spike (M5)';

  testWidgets('holding RESTART TRIAL restarts, and never opens diagnostics', (
    tester,
  ) async {
    var restarted = false;
    await pumpShell(tester, onAbandoned: () => restarted = true);
    await openStatus(tester);

    final hold = await tester.startGesture(
      tester.getCenter(find.text('HOLD 3S · RESTART TRIAL')),
    );
    for (var i = 0; i < 35; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await hold.up();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text(diagnosticsTitle), findsNothing);
    expect(restarted, isTrue);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('holding the rank letter opens nothing', (tester) async {
    await pumpShell(tester);
    await openStatus(tester);
    final hold = await tester.startGesture(
      tester.getCenter(find.text('E').first),
    );
    await tester.pump(const Duration(seconds: 2));
    await hold.up();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text(diagnosticsTitle), findsNothing);
  });

  testWidgets('seven quick taps on the Status window open diagnostics', (
    tester,
  ) async {
    await pumpShell(tester);
    await openStatus(tester);
    final spot = tester.getCenter(find.text('LEVEL'));
    for (var i = 0; i < 7; i++) {
      await tester.tapAt(spot);
      await tester.pump(const Duration(milliseconds: 120));
    }
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text(diagnosticsTitle), findsOneWidget);
  });

  testWidgets('diagnostics is refused while a penalty is in effect', (
    tester,
  ) async {
    final clock = FixedClock(DateTime(2026, 10, 19, 10));
    final model = await pumpShell(tester, clock: clock);
    clock.set(DateTime(2026, 10, 20, 6, 30)); // Monday failed: push-ups owed
    await model.tick();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.text('ACKNOWLEDGE'));
    await tester.pump(const Duration(milliseconds: 600));
    await openStatus(tester);

    final spot = tester.getCenter(find.text('LEVEL'));
    for (var i = 0; i < 7; i++) {
      await tester.tapAt(spot);
      await tester.pump(const Duration(milliseconds: 120));
    }
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text(diagnosticsTitle), findsNothing);
    expect(
      find.text('Diagnostics is unavailable while a penalty is in effect.'),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 5)); // let the snackbar go
  });

  testWidgets(
    'on a short screen every Status row is on screen, and restart is reachable by page scroll',
    (tester) async {
      await pumpShell(tester);
      // A short, wide browser window, like the TestSprite one.
      tester.view.physicalSize = const Size(1280, 640);
      tester.view.devicePixelRatio = 1;
      await tester.pump(const Duration(milliseconds: 300));
      await openStatus(tester);

      for (final row in [
        'LEVEL',
        'EXPERIENCE',
        'NEXT GATE',
        'CURRENT STREAK',
      ]) {
        expect(reallyVisible(tester, find.text(row)), isTrue, reason: row);
      }
      // Lower content is reached by scrolling the page itself, which is visible
      // and expected, not by a hidden scroll inside a window.
      final restart = find.text('HOLD 3S · RESTART TRIAL');
      await tester.ensureVisible(restart);
      await tester.pump();
      expect(reallyVisible(tester, restart), isTrue);
      await tester.pump(const Duration(seconds: 1));
    },
  );

  testWidgets('the walk clock ticks on its own, with no taps', (tester) async {
    final clock = FixedClock(DateTime(2026, 10, 20, 15, 0, 0));
    final model = await pumpShell(tester, clock: clock);
    await model.toggleTimer(model.tasks.first);
    await tester.pump();
    expect(find.text('00:00:00'), findsOneWidget);

    // Only time passes; nothing is tapped.
    for (var s = 1; s <= 5; s++) {
      clock.advance(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
    }
    expect(find.text('00:00:05'), findsOneWidget);
    expect(find.text('RUNNING'), findsOneWidget);
  });

  testWidgets('quest screen shows the quest the System issued', (tester) async {
    await pumpShell(tester);
    expect(find.text('[ DAILY QUEST ]'), findsOneWidget);
    expect(find.text('Walk'), findsOneWidget);
    expect(find.text('Push-ups (knees allowed)'), findsOneWidget);
    expect(find.text('Squats'), findsOneWidget);
    expect(find.text('0 / 10'), findsOneWidget);
    expect(find.text('0 / 15'), findsOneWidget);
  });

  testWidgets('counter buttons add push-ups', (tester) async {
    await pumpShell(tester);
    await tester.ensureVisible(find.text('+5').first);
    await tester.pump();
    await tester.tap(find.text('+5').first);
    await tester.pump();
    await tester.tap(find.text('+1').first);
    await tester.pump();
    expect(find.text('6 / 10'), findsOneWidget);
  });

  testWidgets('a quick tap does not confirm the journal line; holding does', (
    tester,
  ) async {
    final model = await pumpShell(tester, system: SystemKind.personality);
    final journal = model.tasks.firstWhere((t) => t.id == 'journal');
    await tester.ensureVisible(find.text('HOLD TO CONFIRM').first);
    await tester.tap(find.text('HOLD TO CONFIRM').first);
    await tester.pump(const Duration(milliseconds: 200));
    expect(model.isDone(journal), isFalse);

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('HOLD TO CONFIRM').first),
    );
    // The press registers after ~100ms; then the fill needs ~900ms of frames.
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 1000));
    await gesture.up();
    await tester.pump();
    expect(model.isDone(journal), isTrue);
    expect(find.text('CONFIRMED'), findsOneWidget);
  });

  testWidgets('completing every task shows the System notice', (tester) async {
    final model = await pumpShell(tester);
    for (final t in model.tasks) {
      await model.setProgress(t, t.goal);
    }
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('[ NOTIFICATION ]'), findsOneWidget);
    expect(find.text('The daily quest has been completed.'), findsOneWidget);
    await tester.tap(find.text('ACKNOWLEDGE'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('[ NOTIFICATION ]'), findsNothing);
  });

  testWidgets('status and penalty tabs open', (tester) async {
    await pumpShell(tester);
    await tester.tap(find.text('STATUS'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('[ STATUS ]'), findsOneWidget);
    expect(find.text('ATTRIBUTES'), findsOneWidget);

    await tester.tap(find.text('PENALTY').last);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('[ PENALTY ZONE ]'), findsOneWidget);
    expect(find.text('No penalty is in effect.'), findsOneWidget);
    expect(find.text('INSTAGRAM'), findsOneWidget);
  });

  Future<void> pumpOnboarding(
    WidgetTester tester,
    ValueChanged<OnboardingResult> onDone, {
    bool nextSystemOnly = false,
    Set<SystemKind> completed = const {},
  }) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: Hud.theme(HudPalette.system),
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: OnboardingScreen(
              blocker: NoopAppBlocker(),
              onDone: onDone,
              nextSystemOnly: nextSystemOnly,
              completed: completed,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text));
    await tester.tap(find.text(text));
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> pumpFor(WidgetTester tester, int ms) async {
    for (var t = 0; t < ms; t += 100) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> holdText(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text));
    await tester.pump();
    final g = await tester.startGesture(tester.getCenter(find.text(text)));
    await pumpFor(tester, 1300);
    await g.up();
    await pumpFor(tester, 500);
  }

  /// From the black screen to the System choice.
  Future<void> makeContact(WidgetTester tester) async {
    await tester.tap(find.text('TOUCH TO ESTABLISH CONTACT'));
    await pumpFor(tester, 4000); // particles, emblem, window, typing
    await holdText(tester, 'ACCEPT');
  }

  testWidgets('the Awakening refuses to continue without a System', (
    tester,
  ) async {
    OnboardingResult? result;
    await pumpOnboarding(tester, (r) => result = r);
    await makeContact(tester);
    expect(find.text('CHOOSE YOUR SYSTEM'), findsOneWidget);
    await tester.tap(find.text('BIND SYSTEM'));
    await pumpFor(tester, 500);
    expect(find.text('CHOOSE YOUR SYSTEM'), findsOneWidget);
    expect(find.text('PLACEMENT TEST'), findsNothing);
    expect(result, isNull);
  });

  testWidgets('the Awakening places a strong candidate at C, never higher', (
    tester,
  ) async {
    OnboardingResult? result;
    await pumpOnboarding(tester, (r) => result = r);
    await makeContact(tester);
    await tapText(tester, 'FITNESS');
    await tapText(tester, 'BIND FITNESS');
    await pumpFor(tester, 500);
    expect(find.text('PLACEMENT TEST'), findsOneWidget);
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '80');
    await tester.enterText(fields.at(1), '4');
    await tester.pump();
    await tapText(tester, 'SUBMIT');
    await pumpFor(tester, 2500); // rank stamp, quest cards deal in
    expect(find.text('RANK C'), findsOneWidget);
    expect(find.text('Jog'), findsOneWidget);
    await tapText(tester, 'CONTINUE');
    await pumpFor(tester, 500);
    await tapText(tester, 'CONFIRM TARGETS');
    await pumpFor(tester, 500);
    await tapText(tester, 'SET REST PERIOD');
    await pumpFor(tester, 500);
    expect(find.text('PENALTY TERMS'), findsOneWidget);
    // Accepting is refused until every term has been read.
    expect(find.textContaining('SCROLL TO READ ALL TERMS'), findsOneWidget);
    await tester.drag(
      find.textContaining('Clear every objective'),
      const Offset(0, -3000),
    );
    await pumpFor(tester, 500);
    expect(find.text('ALL TERMS READ'), findsOneWidget);
    await holdText(tester, 'HOLD TO ACCEPT');
    expect(find.text('[ PLAYER REGISTERED ]'), findsOneWidget);
    await tapText(tester, 'ENTER');
    expect(result, isNotNull);
    expect(result!.system, SystemKind.fitness);
    expect(result!.placement, Rank.c);
    expect(result!.answers, {'pushups': 80, 'km_minutes': 4});
    expect(result!.sleep.startMinute, 23 * 60);
  });

  testWidgets('choosing the next System hides completed ones', (tester) async {
    await pumpOnboarding(
      tester,
      (_) {},
      nextSystemOnly: true,
      completed: const {SystemKind.fitness},
    );
    expect(find.text('FITNESS'), findsNothing);
    expect(find.text('FOCUS'), findsOneWidget);
    expect(find.text('PERSONALITY'), findsOneWidget);
    // Choosing one explains it, including its own penalty.
    await tapText(tester, 'PERSONALITY');
    expect(find.text('BIND PERSONALITY'), findsOneWidget);
    expect(
      find.textContaining('20 pages and a written reflection'),
      findsOneWidget,
    );
    expect(find.textContaining('push-ups'), findsNothing);
  });

  /// Clears [n] days in a row on [clock], ending at 09:00 the day after.
  Future<void> clearDays(GameService g, FixedClock clock, int n) async {
    for (var i = 0; i < n; i++) {
      for (final t in g.todaysTasks) {
        await g.setProgress(t.id, t.goal);
      }
      clock.set(g.today.addDays(1).at(9 * 60));
      await g.tick();
    }
    g.takeSystemEvents();
  }

  testWidgets('an open Gate is shown with a hold to enter', (tester) async {
    final clock = FixedClock(DateTime(2026, 10, 19, 9));
    final model = await pumpShell(
      tester,
      clock: clock,
      prepare: (g) => clearDays(g, clock, 21),
    );
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('RANK E GATE OPEN'), findsOneWidget);
    final hold = find.text('HOLD TO ENTER THE GATE');
    await tester.ensureVisible(hold);
    await tester.pump();
    final gesture = await tester.startGesture(tester.getCenter(hold));
    await tester.pump(const Duration(milliseconds: 150));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 600));
    expect(model.systems!.dungeon, isNotNull);
    expect(find.text('You have entered the Dungeon.'), findsOneWidget);
    await tester.tap(find.text('ACKNOWLEDGE'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('DUNGEON AHEAD'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a Dungeon floor is titled as such, with the 18:00 deadline', (
    tester,
  ) async {
    final clock = FixedClock(DateTime(2026, 10, 19, 9));
    await pumpShell(
      tester,
      clock: clock,
      prepare: (g) async {
        await clearDays(g, clock, 21);
        await g.enterGate();
        await clearDays(g, clock, 2);
        g.takeSystemEvents();
      },
    );
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('[ DUNGEON · FLOOR 2 ]'), findsOneWidget);
    expect(find.text('UNTIL 18:00'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('the day after a failed floor, the Penalty tab is the Dungeon '
      'Penalty', (tester) async {
    final clock = FixedClock(DateTime(2026, 10, 19, 9));
    await pumpShell(
      tester,
      clock: clock,
      prepare: (g) async {
        await clearDays(g, clock, 21);
        await g.enterGate();
        await clearDays(g, clock, 1);
        clock.set(g.today.addDays(1).at(9 * 60));
        await g.tick(); // floor 1 failed
        g.takeSystemEvents();
      },
    );
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('DUNGEON PENALTY ACTIVE'), findsOneWidget);
    await tester.tap(find.text('PENALTY').last);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('[ DUNGEON PENALTY ]'), findsOneWidget);
    expect(find.text('DUNGEON PENALTY'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('the report opens from Status', (tester) async {
    final clock = FixedClock(DateTime(2026, 10, 19, 9));
    await pumpShell(
      tester,
      clock: clock,
      prepare: (g) => clearDays(g, clock, 3),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await openStatus(tester);
    await tester.tap(find.text('REPORT'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(find.text('[ REPORT ]'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('HONESTY'), 200);
    expect(find.text('HONESTY'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('Status shows the Gate progress and the reduction valve', (
    tester,
  ) async {
    final clock = FixedClock(DateTime(2026, 10, 19, 9));
    final model = await pumpShell(
      tester,
      clock: clock,
      prepare: (g) => clearDays(g, clock, 4),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await openStatus(tester);
    expect(find.text('4 / 21 CLEARED'), findsOneWidget);
    await tester.tap(find.text('20%'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(model.reductionTomorrow, 20);
    expect(find.text('Tomorrow 20% · half XP'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
  });
}
