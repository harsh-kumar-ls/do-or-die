# Do or Die

A daily-habit app run by a cold, game-style **System**. You write your own daily quest. Clear it and you earn XP, stat points and rank. Fail it and you enter the **Penalty Zone**: the apps you chose are locked at an unannounced time the next day, and you owe push-ups (with squats past the cap). Unpaid reps double.

Inspired by the *vibe* of a "System" from game-style fiction. All art, names, sound and copy here are original.

**Status:** personal 30-day trial build. Android first (Flutter); web and iOS later.

## Docs

| File | What it is |
|---|---|
| [PROJECT.md](PROJECT.md) | What is being built for the trial, and the penalty rules |
| [BUILD_LOOP.md](BUILD_LOOP.md) | How it is built and tested, milestone by milestone, with current status |
| [PRD.md](PRD.md) | The longer-term product spec, if the trial succeeds |
| [COMPETITOR_ANALYSIS.md](COMPETITOR_ANALYSIS.md) | Research on similar apps |
| [design/DESIGN.md](design/DESIGN.md) | The approved visual direction (A2 + P3) and mockups |

## Layout

```
lib/domain/    rules engine: quests, penalties, levels, lock scheduling (pure Dart)
lib/data/      saved game and the append-only trial log
lib/app/       GameService, penalty enforcer, notification planner, trusted clock
lib/platform/  Android bridges: app blocker, notifications, network time
lib/ui/        screens, theme, sound and haptics
android/       accessibility-service blocker, block screen, trusted time
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

The app blocker is an Android accessibility service. After installing, turn on **Do or Die Penalty Zone** in Accessibility settings (the Penalty tab warns while it is off), allow notifications, and allow **Alarms & reminders** for on-time warnings.

## End-to-end tests (TestSprite)

```bash
flutter build web --release --dart-define=DOD_TEST_MODE=true
python3 -I tools/serve_web.py 8080
```

Then run tests with `testsprite test run <id> --local 8080` (ids in `testsprite-plans/test-ids.json`). `DOD_TEST_MODE` lets hold buttons accept a click, because the test agent can't hold; real builds never set it.
