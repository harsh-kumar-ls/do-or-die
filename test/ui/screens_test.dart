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
          child: AppShell(model: model, blocker: NoopAppBlocker()),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    return model;
  }

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
