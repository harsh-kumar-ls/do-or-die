# Do or Die

A phone-discipline app run by a cold, game-style **System**. The default build is the simple game: the Focus System only (screen-time limits, phone-free blocks and a lock you schedule), ranks earned by milestones, short rules. The full game below (three Systems, Gates, Dungeons) is built with `--dart-define=DOD_FULL=true`.

In the full game: You choose a System (Focus is the core; Fitness and Personality are optional packs, and you can switch), take a short placement test (rank E to C), and the System writes your daily quest for your rank. Clear it and you earn XP and stat points. Fail it and you enter the **Lockdown**: the apps you chose are locked for 4 hours the next day, from a time you picked, with two releases and an always-available emergency exit; Personality adds pages and a short plan for tomorrow, Focus a phone-free block, Fitness nothing (exercise is never a punishment). A day at least 80% done is a near miss: no penalty, no XP. One verdict in any 14 days can be contested. Anything unpaid expires at midnight and is logged; nothing carries over.

Clear 21 of 30 days and a **Gate** opens. Enter it within 48 hours for a three-day **Dungeon**: floor 1 is the quest +25%, floor 2 is +50% and ends at 18:00, floor 3 is the Rank Trial. Clear it to rank up; fail a floor and the **Dungeon Penalty** follows (the normal lock, any reading or phone-free penalty doubled, Gate shut 7 days). Ranks never go down. You can switch System at any time outside a Dungeon (it starts the next day; ranks are kept). A 30-day report shows what happened, including every release taken. See [SYSTEMS_PRD.md](SYSTEMS_PRD.md).

Inspired by the *vibe* of a "System" from game-style fiction. All art, names, sound and copy here are original.

**Status:** 0.9.0, Google Play internal-testing candidate. Android first (Flutter); web and iOS later. Where things stand: [progress.md](progress.md). Privacy policy: [harsh-kumar-ls.github.io/do-or-die/privacy-policy.html](https://harsh-kumar-ls.github.io/do-or-die/privacy-policy.html).

## Docs

| File | What it is |
|---|---|
| [progress.md](progress.md) | Where the project stands: what is built, decided and next |
| [release/PLAY_RELEASE.md](release/PLAY_RELEASE.md) | Google Play internal-testing release kit |
| [PROJECT.md](PROJECT.md) | What is being built for the trial, and the penalty rules |
| [BUILD_LOOP.md](BUILD_LOOP.md) | How it is built and tested, milestone by milestone, with current status |
| [SYSTEMS_PRD.md](SYSTEMS_PRD.md) | Systems, ranks, Gates and Dungeons (phase 2) |
| [PRD.md](PRD.md) | The longer-term product spec, if the trial succeeds |
| [COMPETITOR_ANALYSIS.md](COMPETITOR_ANALYSIS.md) | Research on similar apps |
| [design/DESIGN.md](design/DESIGN.md) | The approved visual direction (A2 + P3) and mockups |

## Layout

```
lib/domain/    rules engine: quests, penalties, levels, lock scheduling, Systems,
               quest catalogue, Gates and Dungeons, placement (pure Dart)
lib/data/      saved game and the append-only trial log
lib/app/       GameService, penalty enforcer, notification planner, trusted clock,
               30-day report
lib/platform/  Android bridges: app blocker, notifications, network time, usage meter
lib/ui/        screens, theme, sound and haptics
android/       usage-access watcher, block screen, usage meter, trusted time
test/          unit and widget tests
tools/         sound generator, TestSprite plan generator, local web server
testsprite-plans/  end-to-end web tests (TestSprite)
```

## Run

```bash
flutter pub get
flutter test
flutter run            # on a connected Android phone
```

The app blocker is a small background watcher, not an accessibility service: Indian UPI and banking apps refuse to run while any accessibility service is on. After installing, open **Status → SYSTEM CHECK** and fix anything marked ✕: allow **Usage access** and **Display over other apps**, allow notifications and **Alarms & reminders**, and exempt the app from battery optimisation. The watcher runs only while a lock, a phone-free block or a verdict is pending (with a "Lockdown watcher" notification); exact alarms wake it at midnight and before a lock. Without "Alarms & reminders" it has to run all the time.

Native logic has JVM unit tests: `cd android && ./gradlew :app:testDebugUnitTest`.

A force stop stops the watcher; opening Do or Die starts it again, and every outage is recorded in the trial log. Install updates with a plain `adb install -r` (no force-stop).

## End-to-end tests (TestSprite)

```bash
flutter build web --release --dart-define=DOD_TEST_MODE=true
python3 -I tools/serve_web.py 8080
```

Then run tests with `testsprite test run <id> --local 8080` (ids in `testsprite-plans/test-ids.json`). `DOD_TEST_MODE` lets hold buttons accept a click, because the test agent can't hold; real builds never set it.
