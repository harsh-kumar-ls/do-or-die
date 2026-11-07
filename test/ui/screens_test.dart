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
import 'package:do_or_die/ui/screens/system_check_screen.dart';
import 'package:do_or_die/ui/theme.dart';
import 'package:do_or_die/ui/widgets/hud_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A widget test with semantics on (for finders by label), released before
/// the end-of-test checks.
void testUi(String description, Future<void> Function(WidgetTester) body) =>
    testWidgets(description, (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await body(tester);
      } finally {
        semantics.dispose();
      }
    });

void main() {
  Future<void> pumpFor(WidgetTester tester, int ms) async {
    for (var t = 0; t < ms; t += 100) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

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

  Future<void> openTab(WidgetTester tester, String tab) async {
    await tester.tap(find.text(tab).last);
    await pumpFor(tester, 600);
  }

  Future<void> holdText(WidgetTester tester, Finder f, {int ms = 1300}) async {
    await tester.ensureVisible(f);
    await tester.pump();
    final g = await tester.startGesture(tester.getCenter(f));
    await pumpFor(tester, ms);
    await g.up();
    await pumpFor(tester, 500);
  }

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

  Future<void> acknowledgeAll(WidgetTester tester) async {
    for (
      var i = 0;
      i < 6 && find.text('ACKNOWLEDGE').evaluate().isNotEmpty;
      i++
    ) {
      await pumpFor(tester, 2000);
      await tester.tap(find.text('ACKNOWLEDGE'));
      await pumpFor(tester, 400);
    }
  }

  const diagnosticsTitle = 'Blocking spike (M5)';

  // -------------------------------------------------------------------------
  // Status

  testUi('Status fits a phone screen: rank, rows, buttons, attributes', (
    tester,
  ) async {
    await pumpShell(tester);
    await openTab(tester, 'STATUS');
    for (final f in [
      find.text('[ STATUS ]'),
      find.text('LEVEL'),
      find.text('CURRENT STREAK'),
      find.text('REPORT'),
      find.text('SYSTEM CHECK'),
      find.text('ATTRIBUTES'),
      find.text('CHA'),
    ]) {
      expect(reallyVisible(tester, f), isTrue, reason: f.toString());
    }
    expect(find.text('FITNESS SYSTEM'), findsOneWidget);
  });

  testUi('Status shows Gate progress and the reduction valve', (tester) async {
    final clock = FixedClock(DateTime(2026, 10, 19, 9));
    final model = await pumpShell(
      tester,
      clock: clock,
      prepare: (g) => clearDays(g, clock, 4),
    );
    await acknowledgeAll(tester);
    await openTab(tester, 'STATUS');
    expect(find.text('4 / 21', findRichText: true), findsOneWidget);
    await tester.tap(find.text('20%'));
    await pumpFor(tester, 300);
    expect(model.reductionTomorrow, 20);
    expect(
      find.text('−20% targets · applies tomorrow · half XP · 6 of 6 days left'),
      findsOneWidget,
    );
  });

  testUi('attribute points are pending until CONFIRM', (tester) async {
    final clock = FixedClock(DateTime(2026, 10, 19, 9));
    final model = await pumpShell(
      tester,
      clock: clock,
      prepare: (g) => clearDays(g, clock, 3), // level 2: 3 points
    );
    await acknowledgeAll(tester);
    await openTab(tester, 'STATUS');
    expect(find.text('3 POINTS'), findsOneWidget);
    final plus = find.bySemanticsLabel('Add a point to strength');
    await tester.ensureVisible(plus);
    await tester.pump();
    await tester.tap(plus);
    await pumpFor(tester, 200);
    expect(model.state.stats[Stat.strength] ?? 0, 0, reason: 'still pending');
    await tester.tap(find.text('CONFIRM'));
    await pumpFor(tester, 300);
    expect(model.state.stats[Stat.strength], 1);
    expect(model.state.unspentStatPoints, 2);
  });

  testUi('seven quick taps on Status open diagnostics', (tester) async {
    await pumpShell(tester);
    await openTab(tester, 'STATUS');
    final spot = tester.getCenter(find.text('LEVEL'));
    for (var i = 0; i < 7; i++) {
      await tester.tapAt(spot);
      await tester.pump(const Duration(milliseconds: 120));
    }
    await pumpFor(tester, 600);
    expect(find.text(diagnosticsTitle), findsOneWidget);
  });

  testUi('diagnostics is refused while a penalty is in effect', (tester) async {
    final clock = FixedClock(DateTime(2026, 10, 19, 10));
    final model = await pumpShell(tester, clock: clock);
    clock.set(DateTime(2026, 10, 20, 6, 30));
    await model.tick();
    await acknowledgeAll(tester);
    await openTab(tester, 'STATUS');
    final spot = tester.getCenter(find.text('LEVEL'));
    for (var i = 0; i < 7; i++) {
      await tester.tapAt(spot);
      await tester.pump(const Duration(milliseconds: 120));
    }
    await pumpFor(tester, 600);
    expect(find.text(diagnosticsTitle), findsNothing);
    await pumpFor(tester, 5000); // let the snackbar go
  });

  testUi('restart lives in System Check and returns to the Awakening', (
    tester,
  ) async {
    var restarted = false;
    await pumpShell(tester, onAbandoned: () => restarted = true);
    await openTab(tester, 'STATUS');
    await tester.tap(find.text('SYSTEM CHECK'));
    await pumpFor(tester, 800);
    await tester.scrollUntilVisible(
      find.text('HOLD 3S · RESTART TRIAL'),
      300,
      scrollable: find
          .descendant(
            of: find.byType(SystemCheckScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await holdText(tester, find.text('HOLD 3S · RESTART TRIAL'), ms: 3500);
    expect(restarted, isTrue);
  });

  testUi('while a penalty is owed, restart says what blocks it', (
    tester,
  ) async {
    final clock = FixedClock(DateTime(2026, 10, 19, 10));
    final model = await pumpShell(
      tester,
      clock: clock,
      system: SystemKind.personality,
    );
    clock.set(DateTime(2026, 10, 20, 6, 30));
    await model.tick();
    await acknowledgeAll(tester);
    expect(find.text('ACKNOWLEDGE'), findsNothing);
    await openTab(tester, 'STATUS');
    await acknowledgeAll(tester);
    await tester.ensureVisible(find.text('SYSTEM CHECK'));
    await pumpFor(tester, 300);
    await tester.tap(find.text('SYSTEM CHECK'));
    await pumpFor(tester, 800);
    expect(find.text('[ SYSTEM CHECK ]'), findsOneWidget);
    final reason = find.textContaining('Finish today');
    await tester.scrollUntilVisible(
      reason,
      300,
      scrollable: find
          .descendant(
            of: find.byType(SystemCheckScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(reason, findsOneWidget);
    expect(find.text('HOLD 3S · RESTART TRIAL'), findsNothing);
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await pumpFor(tester, 3000);
  });

  // -------------------------------------------------------------------------
  // Quest

  testUi('the quest shows what the System issued, with undo', (tester) async {
    final model = await pumpShell(tester);
    expect(find.text('[ DAILY QUEST ]'), findsOneWidget);
    expect(find.text('Walk'), findsOneWidget);
    expect(find.text('Push-ups (knees allowed)'), findsOneWidget);
    expect(find.text('0 / 3 CLEARED'), findsOneWidget);
    final pushups = model.tasks.firstWhere((t) => t.id == 'pushups');
    await tester.tap(find.text('+5').first);
    await tester.pump();
    await tester.tap(find.text('+1').first);
    await tester.pump();
    expect(find.text('6 / 10'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Undo Push-ups (knees allowed)'));
    await tester.pump();
    expect(model.progress(pushups), 5);
  });

  testUi('the walk clock ticks on its own, with no taps', (tester) async {
    final clock = FixedClock(DateTime(2026, 10, 20, 15, 0, 0));
    final model = await pumpShell(tester, clock: clock);
    await model.toggleTimer(model.tasks.first);
    await tester.pump();
    expect(find.text('12:00'), findsOneWidget);
    for (var s = 1; s <= 5; s++) {
      clock.advance(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
    }
    expect(find.text('11:55'), findsOneWidget);
    expect(find.text('RUNNING'), findsOneWidget);
  });

  testUi('a quick tap does not confirm the journal line; holding does', (
    tester,
  ) async {
    final model = await pumpShell(tester, system: SystemKind.personality);
    final journal = model.tasks.firstWhere((t) => t.id == 'journal');
    // Personality E: pages, then the journal line's hold square first.
    final square = find.byType(HoldSquare).first;
    await tester.tap(square);
    await tester.pump(const Duration(milliseconds: 200));
    expect(model.isDone(journal), isFalse);
    await holdText(tester, square, ms: 1100);
    expect(model.isDone(journal), isTrue);
  });

  testUi('completing the quest shows QUEST CLEARED, armed after a beat', (
    tester,
  ) async {
    final model = await pumpShell(tester);
    for (final t in model.tasks) {
      await model.setProgress(t, t.goal);
    }
    await pumpFor(tester, 300);
    expect(find.text('[ QUEST CLEARED ]'), findsOneWidget);
    expect(find.text('All objectives complete.'), findsOneWidget);
    // A reflex tap does nothing before the entrance ends.
    await tester.tap(find.text('ACKNOWLEDGE'));
    await pumpFor(tester, 200);
    expect(find.text('[ QUEST CLEARED ]'), findsOneWidget);
    await pumpFor(tester, 1000);
    await tester.tap(find.text('ACKNOWLEDGE'));
    await pumpFor(tester, 400);
    expect(find.text('[ QUEST CLEARED ]'), findsNothing);
  });

  testUi('a served lock is reported only on the day it ran', (tester) async {
    final clock = FixedClock(DateTime(2026, 10, 19, 9));
    final model = await pumpShell(
      tester,
      clock: clock,
      prepare: (g) async {
        // Fail day 1; day 2 is a Penalty Zone with a lock.
        clock.set(g.today.addDays(1).at(9 * 60));
        await g.tick();
        // Fitness owes no exercise: the lock is the whole penalty.
        expect(g.state.debt, isNull);
        clock.set(g.state.lock!.end.add(const Duration(minutes: 1)));
        await g.tick();
      },
    );
    await acknowledgeAll(tester);
    await openTab(tester, 'PENALTY');
    expect(find.text('LOCK SERVED · ACCESS RESTORED'), findsOneWidget);
    // Day 3: the old lock is still on record, but it is not today's.
    for (final t in model.service.todaysTasks) {
      await model.service.setProgress(t.id, t.goal);
    }
    clock.set(model.service.today.addDays(1).at(9 * 60));
    await model.tick();
    await acknowledgeAll(tester);
    await openTab(tester, 'PENALTY');
    expect(find.text('LOCK SERVED · ACCESS RESTORED'), findsNothing);
    expect(find.text('NO LOCK TODAY'), findsOneWidget);
  });

  testUi('status and penalty tabs open', (tester) async {
    await pumpShell(tester);
    await openTab(tester, 'STATUS');
    expect(find.text('[ STATUS ]'), findsOneWidget);
    await openTab(tester, 'PENALTY');
    expect(find.text('[ PENALTY ZONE ]'), findsOneWidget);
    expect(find.text('No penalty is in effect.'), findsOneWidget);
    expect(find.text('NO LOCK TODAY'), findsOneWidget);
    expect(find.text('Instagram'), findsOneWidget); // fallback name
  });

  // -------------------------------------------------------------------------
  // Gates and Dungeons

  testUi('an open Gate is shown with a hold to enter', (tester) async {
    final clock = FixedClock(DateTime(2026, 10, 19, 9));
    final model = await pumpShell(
      tester,
      clock: clock,
      prepare: (g) => clearDays(g, clock, 21),
    );
    await acknowledgeAll(tester);
    expect(find.text('[ GATE OPEN ]'), findsOneWidget);
    await holdText(tester, find.text('HOLD TO ENTER'), ms: 1800);
    expect(model.systems!.dungeon, isNotNull);
    expect(find.text('[ DUNGEON ]'), findsOneWidget);
  });

  testUi('a Dungeon floor is titled as such, with the 18:00 deadline', (
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
      },
    );
    await acknowledgeAll(tester);
    expect(find.text('[ DUNGEON · FLOOR 2 ]'), findsOneWidget);
    expect(find.text('FLOOR CLOSES 18:00 IN'), findsOneWidget);
    expect(find.text('+50%'), findsOneWidget);
  });

  testUi('the day after a failed floor, the Penalty tab is the Dungeon '
      'Penalty', (tester) async {
    final clock = FixedClock(DateTime(2026, 10, 19, 9));
    await pumpShell(
      tester,
      clock: clock,
      // Personality owes reading, so the doubled debt panel shows.
      system: SystemKind.personality,
      prepare: (g) async {
        await clearDays(g, clock, 21);
        await g.enterGate();
        await clearDays(g, clock, 1);
        clock.set(g.today.addDays(1).at(9 * 60));
        await g.tick(); // floor 1 failed
        g.takeSystemEvents();
      },
    );
    await acknowledgeAll(tester);
    expect(find.text('DUNGEON PENALTY ACTIVE'), findsOneWidget);
    await openTab(tester, 'PENALTY');
    expect(find.text('[ DUNGEON PENALTY ]'), findsOneWidget);
    // Below the lock panel, the emergency exit and the contest option.
    await tester.dragUntilVisible(
      find.text('[ DUNGEON DEBT · ×2 ]'),
      find.text('[ DUNGEON PENALTY ]'),
      const Offset(0, -200),
    );
    expect(find.text('[ DUNGEON DEBT · ×2 ]'), findsOneWidget);
  });

  testUi('the report opens from Status', (tester) async {
    final clock = FixedClock(DateTime(2026, 10, 19, 9));
    await pumpShell(
      tester,
      clock: clock,
      prepare: (g) => clearDays(g, clock, 3),
    );
    await acknowledgeAll(tester);
    await openTab(tester, 'STATUS');
    await tester.tap(find.text('REPORT'));
    await pumpFor(tester, 1500);
    expect(find.text('[ 30-DAY REPORT ]'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('VERDICT'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Cleared 100%. Nothing to add.'), findsOneWidget);
  });

  testUi('tapping the System sigil asks the System for the next line', (
    tester,
  ) async {
    final clock = FixedClock(DateTime(2026, 10, 19, 9));
    await pumpShell(tester, clock: clock);
    await acknowledgeAll(tester);
    expect(find.textContaining('objectives remain'), findsOneWidget);
    await tester.tap(
      find.bySemanticsLabel('System sigil. Tap for the next System line'),
    );
    await pumpFor(tester, 500);
    expect(find.text('No streak. Begin one today.'), findsOneWidget);
  });

  testUi('the report share card can drop the honesty figures', (tester) async {
    final clock = FixedClock(DateTime(2026, 10, 19, 9));
    await pumpShell(
      tester,
      clock: clock,
      prepare: (g) => clearDays(g, clock, 3),
    );
    await acknowledgeAll(tester);
    await openTab(tester, 'STATUS');
    await tester.tap(find.text('REPORT'));
    await pumpFor(tester, 1500);
    await tester.tap(find.text('SHARE'));
    await pumpFor(tester, 800);
    expect(find.text('[ SHARE REPORT ]'), findsOneWidget);
    expect(find.text('ON MY WORD'), findsOneWidget);
    expect(find.text('RANK E'), findsOneWidget);
    await tester.tap(find.text('INCLUDE HONESTY FIGURES'));
    await pumpFor(tester, 300);
    expect(find.text('ON MY WORD'), findsNothing);
    expect(find.text('SHARE AS IMAGE'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // Awakening

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
    await pumpFor(tester, 400);
  }

  Future<void> makeContact(WidgetTester tester) async {
    await tester.tap(find.text('TOUCH TO ESTABLISH CONTACT'));
    await pumpFor(tester, 4000);
    await holdText(tester, find.text('ACCEPT'));
  }

  testUi('the System carousel: centred card is the choice; flip shows '
      'the brief', (tester) async {
    await pumpOnboarding(tester, (_) {});
    await makeContact(tester);
    expect(find.text('CHOOSE YOUR SYSTEM'), findsOneWidget);
    // Focus is the core System, so it comes first.
    expect(find.text('CHOOSE FOCUS SYSTEM'), findsOneWidget);
    await tester.tap(find.text('TAP TO INSPECT').first);
    await pumpFor(tester, 600);
    expect(find.text('[ FOCUS · BRIEF ]'), findsOneWidget);
    expect(find.text('WHERE YOU START'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Show the Fitness System'));
    await pumpFor(tester, 600);
    expect(find.text('CHOOSE FITNESS SYSTEM'), findsOneWidget);
  });

  testUi('the Awakening places a strong candidate at C, never higher', (
    tester,
  ) async {
    OnboardingResult? result;
    await pumpOnboarding(tester, (r) => result = r);
    await makeContact(tester);
    await tester.tap(find.bySemanticsLabel('Show the Fitness System'));
    await pumpFor(tester, 600);
    await tapText(tester, 'CHOOSE FITNESS SYSTEM');
    // The System entry plays, then the placement test follows.
    await pumpFor(tester, 1500);
    expect(find.text('[ FITNESS SYSTEM ]'), findsOneWidget);
    await pumpFor(tester, 1800);
    expect(find.text('PLACEMENT TEST'), findsOneWidget);
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '80');
    await tester.enterText(fields.at(1), '4');
    await tester.pump();
    await tapText(tester, 'SUBMIT');
    await pumpFor(tester, 2500);
    expect(find.text('RANK C'), findsOneWidget);
    expect(find.text('Jog'), findsOneWidget);
    await tapText(tester, 'CONTINUE');
    await tapText(tester, 'CONFIRM TARGETS');
    await tapText(tester, 'SET REST PERIOD');
    expect(find.text('PENALTY TERMS'), findsOneWidget);
    await tester.drag(
      find.textContaining('Clear every objective'),
      const Offset(0, -3000),
    );
    await pumpFor(tester, 500);
    expect(find.text('ALL TERMS READ'), findsOneWidget);
    expect(
      find.textContaining('not a medical device'),
      findsOneWidget,
      reason: 'the health notice is part of the terms',
    );
    expect(find.textContaining('Stop at once'), findsOneWidget);
    expect(find.textContaining('unpaid doubles'), findsNothing);
    // Without the age confirmation the terms can't be accepted.
    await holdText(tester, find.text('HOLD TO ACCEPT'));
    expect(find.text('ENTER'), findsNothing);
    await tapText(tester, 'I AM 18 OR OLDER');
    await holdText(tester, find.text('HOLD TO ACCEPT'));
    await tapText(tester, 'ENTER');
    expect(result!.system, SystemKind.fitness);
    expect(result!.placement, Rank.c);
    expect(result!.answers, {'pushups': 80, 'km_minutes': 4});
  });

  testUi('choosing the next System hides completed ones', (tester) async {
    await pumpOnboarding(
      tester,
      (_) {},
      nextSystemOnly: true,
      completed: const {SystemKind.fitness},
    );
    await pumpFor(tester, 300);
    expect(find.text('FITNESS'), findsNothing);
    expect(find.text('CHOOSE FOCUS SYSTEM'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Show the Personality System'),
      findsOneWidget,
    );
  });
}
