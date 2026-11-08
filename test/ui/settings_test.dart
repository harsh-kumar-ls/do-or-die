import 'dart:convert';
import 'dart:math';

import 'package:do_or_die/app/game_service.dart';
import 'package:do_or_die/app/penalty_enforcer.dart';
import 'package:do_or_die/data/game_store.dart';
import 'package:do_or_die/domain/clock.dart';
import 'package:do_or_die/domain/progression.dart';
import 'package:do_or_die/domain/systems.dart';
import 'package:do_or_die/platform/blocker.dart';
import 'package:do_or_die/ui/app_shell.dart';
import 'package:do_or_die/ui/game_model.dart';
import 'package:do_or_die/ui/screens/app_picker_screen.dart';
import 'package:do_or_die/ui/screens/settings_screen.dart';
import 'package:do_or_die/ui/screens/system_check_screen.dart';
import 'package:do_or_die/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A blocker that records permission requests.
class _RecordingBlocker extends NoopAppBlocker {
  final requests = <String>[];

  @override
  bool get canBlock => true;

  @override
  Future<SystemStatus> systemStatus() async => const SystemStatus();

  @override
  Future<void> requestUsageAccess() async => requests.add('usage');
}

void main() {
  Future<void> pumpFor(WidgetTester tester, int ms) async {
    for (var t = 0; t < ms; t += 100) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<GameModel> model(FixedClock clock, {SystemKind? system}) async {
    final g = await GameService.awaken(
      store: MemoryGameStore(),
      system: system ?? SystemKind.focus,
      placement: Rank.e,
      dryRunDays: 0,
      blockedPackages: const {'com.instagram.android'},
      clock: clock,
      random: Random(1),
    );
    final m = GameModel(g, pollEvery: null);
    addTearDown(m.dispose);
    return m;
  }

  Future<void> tapIt(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await pumpFor(tester, 300);
  }

  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: Hud.theme(HudPalette.system),
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: child,
        ),
      ),
    );
    await pumpFor(tester, 500);
  }

  testWidgets('settings: export shares the full log as JSON and CSV', (
    tester,
  ) async {
    final m = await model(FixedClock(DateTime(2026, 10, 19, 9)));
    final shared = <(String, String)>[];
    await pump(
      tester,
      SettingsScreen(
        model: m,
        share: (content, {required name, mimeType = ''}) async =>
            shared.add((name, content)),
      ),
    );
    await tapIt(tester, find.text('EXPORT JSON'));
    await tapIt(tester, find.text('EXPORT CSV'));
    await pumpFor(tester, 200);
    expect(shared.map((s) => s.$1), [
      'do-or-die-log.json',
      'do-or-die-log.csv',
    ]);
    final entries = jsonDecode(shared.first.$2) as List;
    expect(entries, hasLength(m.service.game.log.length));
  });

  testWidgets('settings: rest period and lock time can be changed and are '
      'logged', (tester) async {
    final m = await model(FixedClock(DateTime(2026, 10, 19, 9)));
    await pump(tester, SettingsScreen(model: m));
    expect(find.text('18:00'), findsOneWidget);
    await tester.tap(find.byTooltip('LOCK STARTS 30 minutes later'));
    await pumpFor(tester, 200);
    expect(m.service.plannedLockStart, 18 * 60 + 30);
    expect(m.service.lockStartMinute, 18 * 60, reason: 'from in two days');
    expect(find.text('18:30'), findsOneWidget);
    await tester.tap(find.byTooltip('REST PERIOD STARTS 30 minutes earlier'));
    await pumpFor(tester, 200);
    expect(m.service.plannedSleep.startMinute, 22 * 60 + 30);
    expect(find.textContaining('take effect on'), findsOneWidget);
    final types = m.service.game.log.map((e) => e.type);
    expect(types, containsAll(['lock_start_changed', 'sleep_changed']));
  });

  testWidgets('the privacy policy is reachable from Status', (tester) async {
    final m = await model(FixedClock(DateTime(2026, 10, 19, 9)));
    await pump(tester, AppShell(model: m, blocker: NoopAppBlocker()));
    await tester.tap(find.text('STATUS').last);
    await pumpFor(tester, 600);
    await tester.tap(find.bySemanticsLabel('Settings'));
    await pumpFor(tester, 800);
    expect(find.text('[ SETTINGS ]'), findsOneWidget);
    await tapIt(tester, find.text('PRIVACY POLICY'));
    await pumpFor(tester, 800);
    expect(find.text('[ PRIVACY POLICY ]'), findsOneWidget);
    expect(find.text('USAGE ACCESS'), findsOneWidget);
  });

  testWidgets('usage access is requested only after the disclosure is '
      'accepted', (tester) async {
    final clock = FixedClock(DateTime(2026, 10, 19, 9));
    final blocker = _RecordingBlocker();
    final g = await GameService.awaken(
      store: MemoryGameStore(),
      system: SystemKind.focus,
      placement: Rank.e,
      blockedPackages: const {'com.instagram.android'},
      clock: clock,
    );
    // With an enforcer, the System Check reads the (missing) permissions.
    final m = GameModel(
      g,
      pollEvery: null,
      enforcer: PenaltyEnforcer(blocker, clock: clock),
    );
    addTearDown(m.dispose);
    await pump(tester, SystemCheckScreen(model: m, blocker: blocker));
    await tapIt(tester, find.text('ALLOW').first);
    await pumpFor(tester, 400);
    expect(find.text('Usage access: what the System reads'), findsOneWidget);
    await tapIt(tester, find.text('NOT NOW'));
    await pumpFor(tester, 400);
    expect(blocker.requests, isEmpty, reason: 'declined: nothing requested');
    await tapIt(tester, find.text('ALLOW').first);
    await pumpFor(tester, 400);
    await tapIt(tester, find.text('ACCEPT'));
    await pumpFor(tester, 400);
    expect(blocker.requests, ['usage']);
  });

  testWidgets('the Penalty tab offers the emergency exit and the contest', (
    tester,
  ) async {
    final clock = FixedClock(DateTime(2026, 10, 19, 9));
    final m = await model(clock);
    clock.set(DateTime(2026, 10, 20, 9)); // day 1 failed: lock at 18:00
    await m.tick();
    await pump(tester, AppShell(model: m, blocker: NoopAppBlocker()));
    for (
      var i = 0;
      i < 6 && find.text('ACKNOWLEDGE').evaluate().isNotEmpty;
      i++
    ) {
      await pumpFor(tester, 2000);
      await tester.tap(find.text('ACKNOWLEDGE'));
      await pumpFor(tester, 400);
    }
    await tester.tap(find.text('PENALTY').last);
    await pumpFor(tester, 600);
    expect(find.text('EMERGENCY EXIT'), findsOneWidget);
    await tapIt(tester, find.text('CONTEST THIS VERDICT'));
    await pumpFor(tester, 400);
    await tester.enterText(
      find.byKey(const ValueKey('reason')),
      'The phone died before 21:00',
    );
    await pumpFor(tester, 200);
    await tester.tap(find.text('CONTEST'));
    await pumpFor(tester, 600);
    expect(m.service.contestsUsed, 1);
    expect(m.service.penaltyInEffect, isFalse);
  });

  testWidgets('the app picker never lists an app that can never be locked', (
    tester,
  ) async {
    await pump(
      tester,
      Scaffold(
        body: AppPickerList(
          blocker: _AppsBlocker(),
          selected: const {},
          pending: const {},
          onChanged: (_, _) {},
        ),
      ),
    );
    expect(find.text('Instagram'), findsOneWidget);
    expect(find.text('Maps'), findsNothing);
  });
}

class _AppsBlocker extends NoopAppBlocker {
  @override
  Future<List<InstalledApp>> installedApps() async => const [
    InstalledApp('com.instagram.android', 'Instagram', null),
    InstalledApp('com.google.android.apps.maps', 'Maps', null),
  ];
}
