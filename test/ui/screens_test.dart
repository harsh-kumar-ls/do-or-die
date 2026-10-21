import 'dart:math';

import 'package:do_or_die/app/game_service.dart';
import 'package:do_or_die/data/game_store.dart';
import 'package:do_or_die/domain/clock.dart';
import 'package:do_or_die/domain/tasks.dart';
import 'package:do_or_die/platform/blocker.dart';
import 'package:do_or_die/ui/app_shell.dart';
import 'package:do_or_die/ui/game_model.dart';
import 'package:do_or_die/ui/screens/onboarding_screen.dart';
import 'package:do_or_die/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const tasks = [
  TaskDefinition(
    id: 'breakfast',
    name: 'Have breakfast',
    type: TaskType.checkbox,
    target: 1,
  ),
  TaskDefinition(id: 'study', name: 'Study', type: TaskType.timer, target: 120),
  TaskDefinition(id: 'read', name: 'Read', type: TaskType.counter, target: 30),
];

void main() {
  Future<GameModel> pumpShell(WidgetTester tester, {Clock? clock}) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final service = await GameService.start(
      store: MemoryGameStore(),
      tasks: tasks,
      blockedPackages: const {'com.instagram.android'},
      clock: clock ?? const SystemClock(),
      random: Random(1),
    );
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
            onRestarted: (_) {},
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

  testWidgets('the study clock ticks on its own, with no taps', (tester) async {
    final clock = FixedClock(DateTime(2026, 10, 20, 15, 0, 0));
    final model = await pumpShell(tester, clock: clock);
    await model.toggleTimer(tasks[1]);
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

  testWidgets('quest screen shows every task the user wrote', (tester) async {
    await pumpShell(tester);
    expect(find.text('[ DAILY QUEST ]'), findsOneWidget);
    expect(find.text('Have breakfast'), findsOneWidget);
    expect(find.text('Study'), findsOneWidget);
    expect(find.text('Read'), findsOneWidget);
    expect(find.text('0 / 30'), findsOneWidget);
  });

  testWidgets('counter buttons add pages', (tester) async {
    await pumpShell(tester);
    await tester.ensureVisible(find.text('+5'));
    await tester.pump();
    await tester.tap(find.text('+5'));
    await tester.pump();
    await tester.tap(find.text('+10'));
    await tester.pump();
    expect(find.text('15 / 30'), findsOneWidget);
  });

  testWidgets('a quick tap does not confirm breakfast; holding does', (
    tester,
  ) async {
    final model = await pumpShell(tester);
    await tester.tap(find.text('HOLD TO CONFIRM'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(model.isDone(tasks[0]), isFalse);

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('HOLD TO CONFIRM')),
    );
    // The press registers after ~100ms; then the fill needs ~900ms of frames.
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 1000));
    await gesture.up();
    await tester.pump();
    expect(model.isDone(tasks[0]), isTrue);
    expect(find.text('CONFIRMED'), findsOneWidget);
  });

  testWidgets('completing every task shows the System notice', (tester) async {
    final model = await pumpShell(tester);
    await model.setProgress(tasks[0], 1);
    await model.setProgress(tasks[1], 7200);
    await model.setProgress(tasks[2], 30);
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

  testWidgets('onboarding refuses an empty task name', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    OnboardingResult? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: Hud.theme(HudPalette.system),
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: OnboardingScreen(
              blocker: NoopAppBlocker(),
              onDone: (r) => result = r,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('BEGIN REGISTRATION'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('+ ADD OBJECTIVE'));
    await tester.pump();
    await tester.tap(find.text('CONFIRM OBJECTIVES'));
    await tester.pump();
    expect(find.text('Every task needs a name.'), findsOneWidget);
    expect(result, isNull);
  });
}
