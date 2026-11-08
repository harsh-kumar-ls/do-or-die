import 'dart:math';

import 'package:do_or_die/app/game_service.dart';
import 'package:do_or_die/data/game_store.dart';
import 'package:do_or_die/domain/clock.dart';
import 'package:do_or_die/domain/day.dart';
import 'package:do_or_die/domain/progression.dart';
import 'package:do_or_die/domain/systems.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// The real store (SharedPreferences), on the in-memory test backend: what
/// the phone writes is what it reads back, archives are kept apart, and an
/// unreadable save is set aside rather than lost.
void main() {
  late PrefsGameStore store;
  late SharedPreferencesAsync prefs;
  final day1 = DayKey(2026, 10, 19);

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    prefs = SharedPreferencesAsync();
    store = PrefsGameStore(prefs);
  });

  Future<GameService> play() async {
    final clock = FixedClock(day1.at(9 * 60));
    final g = await GameService.awaken(
      store: store,
      system: SystemKind.focus,
      placement: Rank.e,
      blockedPackages: const {'com.instagram.android'},
      dryRunDays: 0,
      clock: clock,
      random: Random(1),
    );
    clock.set(day1.addDays(1).at(9 * 60)); // day 1 failed: a lock today
    await g.tick();
    return g;
  }

  test('a saved game reads back exactly, lock and log included', () async {
    final g = await play();
    final again = (await store.load())!;
    expect(again.toJson(), g.game.toJson());
    expect(again.state.lock!.start, g.state.lock!.start);
    expect(again.log.length, g.game.log.length);
  });

  test('archives are kept apart, counted and deletable', () async {
    final g = await play();
    await store.archive(g.game);
    expect(await store.archiveCount(), 1);
    expect(await store.load(), isNotNull, reason: 'the game is untouched');
    await store.deleteArchives();
    expect(await store.archiveCount(), 0);
    expect(await store.dryRunUsed(), isTrue);
  });

  test('an unreadable save is set aside, never deleted', () async {
    await prefs.setString('doordie.save.v1', '{not json');
    await expectLater(store.load(), throwsA(anything));
    expect(await store.raw(), '{not json');
    await store.setAsideUnreadable();
    expect(await store.load(), isNull);
    final keys = await prefs.getKeys();
    expect(
      keys.where((k) => k.startsWith('doordie.unreadable.')),
      hasLength(1),
    );
    expect(await store.archiveCount(), 1);
  });

  test('the dry-run flag survives a cleared game', () async {
    expect(await store.dryRunUsed(), isFalse);
    await store.markDryRunUsed();
    await store.clear();
    expect(await store.dryRunUsed(), isTrue);
  });
}
