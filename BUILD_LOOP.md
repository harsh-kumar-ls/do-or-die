# Do or Die — Build Loop (Harness Plan)

How this app gets built: a repeatable loop in which one agent (the **harness**) plans a milestone, builds it, runs the tests, reads the failures, fixes, and only moves on when the gates pass. The specs are [PROJECT.md](PROJECT.md) (what to build for the 30-day trial) and [PRD.md](PRD.md) (the later launch scope). Where they differ, PROJECT.md wins.

> **Assumption:** "loop engineering" is read here as plan, build, test, fix, repeat with hard gates. If you meant a different loop or process, say so and I'll rework this file.

---

## 1. The loop (every milestone)

1. **Read:** the milestone's spec section and its acceptance checks.
2. **Test first:** write the failing tests for the acceptance checks.
3. **Build:** the smallest change that passes them.
4. **Run the gates** (section 3) in order. Stop at the first failure.
5. **Diagnose:** read the real error output; fix the cause, not the symptom. After 3 failed attempts on the same failure, stop and report instead of guessing.
6. **Record:** update the milestone checklist and note any spec change.
7. **Report:** what passed, what was only checked by hand, what's still open. Never report "done" with a failing or skipped gate unmentioned.

**Rules for the harness**
- One milestone at a time; no work from later milestones.
- No new dependencies without saying why.
- Penalty rules live in one config file and one pure-Dart module, never scattered through UI code.
- Anything that can lock the phone must have a tested escape (emergency exit, protected apps) **before** the lock itself is enabled.

---

## 2. Architecture that makes the loop testable

```
lib/
  domain/        pure Dart: quest engine, penalty rules, XP/level, clock abstraction
  data/          local storage, trial log
  platform/      interfaces for blocking, notifications, boot; Android impl + web stub
  ui/            screens and theme tokens
android/         native: accessibility service, foreground service, boot receiver
test/            unit + widget tests
integration_test/  on-device flows
```

- **`domain/` has no Flutter or Android imports.** Quest results, penalty amounts, level math and deadline handling are all testable in milliseconds.
- **A `Clock` interface** replaces `DateTime.now()` everywhere, so tests can jump to "Monday 23:59" and "Tuesday 00:00".
- **`platform/` uses interfaces with a fake and a web stub**, so everything above it runs in tests and in a browser.

---

## 3. Test tiers and gates

| Tier | Tool | What it proves | Runs where |
|---|---|---|---|
| **T1 Unit** | `flutter test` | Penalty math, deadlines, carry-over, XP, level scaling, clock-change safety | Mac, every change |
| **T2 Widget** | `flutter test` | Screens render and react (quest list, timer, counter, penalty screen) | Mac, every change |
| **T3 Integration** | `flutter test integration_test` | Full flows on the real app | iQOO phone or emulator |
| **T4 TestSprite** | `testsprite` CLI | End-to-end UI flows against the **Flutter web build** with platform stubs | Web build |
| **T5 Manual device checklist** | Me, on the phone | App blocking, notifications, reboot survival, battery-killer survival | iQOO Neo 7 |

**Honest limits of TestSprite here.** TestSprite drives web frontends and HTTP APIs. It cannot drive the native Android app, and cannot test app blocking, the accessibility service, notifications or reboot behaviour. Those belong to T3 and T5. T4 covers the quest, timer, XP and penalty **UI logic** through the web build. One thing to verify early: Flutter web draws to a canvas, which can be hard for browser-based test agents to read. The first TestSprite step is a **spike**: build the web skeleton, run one simple test, and see whether it works before building a test plan around it. Credentials are already set up; `testsprite doctor` passes (one warning: the agent verification skill isn't installed yet).

**Gates, in order:** `dart format --set-exit-if-changed` → `flutter analyze` → T1 → T2 → (milestone-specific) T3 / T4 / T5.

---

## 4. Milestones, prompts and acceptance checks

Each prompt is what I'd run for that iteration of the loop.

### M0: Environment
**Prompt:** Install Flutter and the Android command-line tools; create the Flutter project in this folder; confirm `flutter doctor` is clean for Android and web; confirm the iQOO is visible to adb.
**Done when:** `flutter doctor` passes, a blank app runs on the phone and in Chrome.
**Needs from the user:** permission for multi-GB installs; USB debugging enabled on the phone.

### M1: Domain core (pure Dart)
**Prompt:** Implement `domain/` per PROJECT.md section 2.1: tasks (checkbox, timer, counter), daily quest, end-of-day failure evaluation, penalty debt for D+1 (50 base × failed tasks, scaled by level, capped), carry-over, XP, level, rank, a `Clock` interface. Tests first.
**Done when (T1):**
- fail 1 task Monday gives 50 owed Tuesday; fail 3 gives 150 (or the cap)
- clearing all tasks owes nothing
- penalty starts the **next** day and covers the whole day
- unpaid push-ups carry over
- changing the clock backwards or forwards cannot cancel a failure
- easing a task or penalty applies only from the next day

### M2: Storage and trial log
**Prompt:** Local database for tasks, daily results, penalty debt, XP/level, and an append-only log of every clear, fail, penalty, emergency exit and edit, exportable as JSON/CSV.
**Done when (T1/T2):** state survives restart; export contains every event; no event can be edited.

### M3: Quest UI and theme
**Prompt:** Theme tokens (near-black, System-blue, Penalty-red), System-voice copy, home screen with today's three tasks, study timer, page counter, breakfast checkbox with hold-to-confirm, XP/level/rank display, stat allocation.
**Done when (T2, T4):** the quest can be completed in the UI; a TestSprite test on the web build completes a quest and sees the XP change (if the spike works).

### M4: Notifications and deadline handling (Android)
**Prompt:** Quest-issued, pre-deadline warning, and failure notifications; exact end-of-day evaluation that works after reboot and when the app is closed.
**Done when (T3, T5):** notifications arrive with the app killed and after a reboot on the iQOO.

### M5: BLOCKING SPIKE (do right after M0 in practice)
**Prompt:** Minimal Android accessibility service plus foreground service that detects Instagram, YouTube and BGMI in the foreground and shows a block screen. Nothing else. Test survival against the iQOO's background-killing.
**Done when (T5 only):** the block holds after the app is swiped away, after the screen locks for 30+ minutes, and after a reboot. **If this fails, stop and replan before M6.**

### M6: Penalty Zone
**Prompt:** Connect M1's penalty debt to M5's blocking: whole-day lock on D+1, protected apps never blocked, emergency exit (deliberate gesture, logged), 50-push-up counter with sets, carry-over display.
**Done when:** a simulated failed day (dry-run clock) produces the correct lock and debt on the phone; emergency exit works and is logged; calls and messages are never blocked.

### M7: Dry-run mode and trial readiness
**Prompt:** A mode where penalties are computed and logged but not applied; a dry-run clock for fast-forwarding; the trial checklist from PROJECT.md section 5.
**Done when:** days 1–3 can run in dry-run, then switch to live.

### M8: Hardening
**Prompt:** Permission and battery-optimization setup guide screens for the iQOO; regression pass on T1–T5.
**Done when:** a fresh install can be set up by following the in-app steps alone.

---

## 5. Definition of done (any milestone)
- All gates for that milestone pass, with output shown.
- Anything verified only by hand is listed as such.
- Spec changes are written into PROJECT.md in the same step.
- No known wrongful-penalty bug is open. This outranks every other defect.

---

## 6. Current status
- [x] **M0 Environment (2026-10-20).** Flutter 3.47.7 / Dart 3.13.5, Android SDK 36, JDK 17, adb. iQOO Neo 7 (I2214, Android 16, OriginOS 6) authorized over USB. `flutter doctor` passes for Android and web (Xcode warning is expected; iOS is v3). Fix applied: cleared the macOS quarantine flag on the Homebrew Flutter SDK and re-downloaded its Dart SDK cache, because the analyzer was blocked. Not yet done: a blank app run on the phone and in Chrome.
- [x] **M1 Domain core (2026-10-20).** `lib/domain/`: day keys, clock, config, tasks and plan versions, penalty calculator, debt, sleep window, random lock scheduler, progression, quest engine. Gates: format clean, analyze clean, 30/30 unit tests pass.
  - XP and rank thresholds are placeholders (`config.dart`, `progression.dart`).
  - Known gap: a clock moved **forward** fails the skipped days. Trusted-time checking is M4.
- [x] **M5 blocking spike: PASSED (2026-10-20).** Accessibility-service approach works on the iQOO Neo 7 / OriginOS 6. No replan needed.
  - [x] Accessibility service enabled on the iQOO without needing "restricted settings" (adb install).
  - [x] Basic block: Instagram, YouTube and BGMI all blocked with the Penalty Zone screen (user-confirmed + logs).
  - Bug found and fixed: pressing Home before opening the block screen raced the launcher animation, so only BGMI showed the screen. Now the screen opens directly over the app; Back and Leave go home; a 1.2s fallback presses Home if the screen fails to appear.
  - [x] Survives app swiped from recents (user-confirmed)
  - [x] Survives screen locked 30+ minutes (user-confirmed; logs from that period were lost to the reboot, so no log proof that the service never dropped and reconnected)
  - [x] Survives reboot: service reconnected on its own and blocked YouTube 11s later (logs); countdown correct (user-confirmed)
  - [x] Escape works and is counted (emergency stops = 1)
  - Known limits carried forward: lock timing uses the phone clock (trusted time is M4); blocked apps are hard-coded in two places (`BlockerState.kt`, `blocker_service.xml`); the 30-day trial is the real long-run reliability test.
- [x] **M2 Storage and trial log (2026-10-20).** One saved document (state, plan, progress, block list, sleep window, log) written in a single save, via `shared_preferences` (Android and web). Append-only log with JSON and CSV export. `GameService` (`lib/app/`) is the only API the UI uses. User-chosen block list added (`lib/domain/block_list.dart`): adding an app applies now, removing applies tomorrow, protected apps can never be added. Gates: format clean, analyze clean, 51/51 tests pass.
  - Not yet covered: the Android blocker still reads its own hard-coded list; wiring the user's list into the service is M6.
- [ ] **M3 quest UI (in progress, 2026-10-20).** Design A2 + P3 approved. Built: onboarding, Quest, Status, Penalty, System notices, HUD shell; fonts bundled (OFL). Timer progress now stored in seconds; live HH:MM:SS clock. 63/63 tests pass; format and analyze clean.
  - User feedback fixed: screens now fill the height (FillColumn + expanding windows); study clock was not live (lazy `late final` timer never started) — fixed with a regression test proven to fail on the old code.
  - Sound and haptics added (2026-10-20): 9 original synthesized cues (`tools/gen_sfx.py` → `assets/sfx/`), played via `flutter_soloud`, each paired with a haptic (`lib/ui/fx.dart`); mute toggle in the top bar, persisted. Native build OK on Android; no audio errors in logcat on the iQOO. Audible check is user-only.
  - Still to do: particles/shaders (web audio needs flutter_soloud's web script setup; currently silent on web by design).
- **TestSprite (T4) set up (2026-10-20).** Project `d37f7ffc-2ffc-4da9-88ea-8ee0106eba69` (local origin, tunnel to `http://127.0.0.1:8080`).
  - Web build for TestSprite: `flutter build web --release --dart-define=DOD_TEST_MODE=true`, served with `python3 -I -m http.server 8080 --bind 127.0.0.1 --directory build/web`. Test mode lets hold buttons accept a click (TestSprite's agent can't hold); real builds never set it, verified both ways.
  - Semantics enabled on web; fixed merged button nodes and unnamed fields (also improves Android screen-reader support).
  - 10 plans in `testsprite-plans/` (ids in `test-ids.json`), generated by `tools/gen_testsprite_plans.py`. One older test kept, renamed "[SUPERSEDED …]" (blocked on the real hold).
  - Results (pre-M6 web build): all 10 PASSED — 01 6/6, 02 9/9, 03 8/8, 04 9/9, 05 14/14, 06 and 07 passed (no per-step breakdown), 08 5/5, 09 8/8, 10 8/8.
  - After M6, onboarding gained a Lock Targets step and the web build lists no apps: plans updated and pushed to all 10 tests; 01 and 07 rerun against the M6 build.
  - Lesson: serve with `python3 -I tools/serve_web.py 8080` (gzip, threaded). The plain http.server was too slow through the tunnel when 3 runs loaded the 2.6 MB bundle at once (all 3 blank). Run tests one at a time.
- [ ] **M6 Penalty Zone wiring (built 2026-10-20; device check pending).**
  - Native: the blocker watches only the user's chosen apps (set at runtime; never reads content); the lock is a start/end window; opening a locked app while a day is unjudged opens Do or Die first; installed-app list with icons; protected apps (default dialer, SMS, launcher, Settings, this app) are never listed.
  - Dart: `PenaltyEnforcer` pushes the list, the window and the first unjudged day (only when they change); `GameService.emergencyStop()` ends the running lock, logs minutes remaining, and leaves exercise owed; app picker (onboarding step and Penalty tab); Penalty tab warns when the service is off; 3-second-hold emergency exit.
  - Gates: format and analyze clean, 70/70 tests (7 new enforcer and exit tests). On the phone: the pushed state was read back from the blocker's prefs (3 apps, no window, judge-due = today).
  - Found on device: reinstalling with a changed accessibility config switched the service off; the new warning is the remedy. Still to confirm with the user: the warning, the picker, a test lock.
  - Known gap until M4: a day is only judged while the app runs. Mitigated (locked apps redirect to Do or Die when a day is unjudged), but there is no background judging or notification yet.
  - **Confirmed by the user on the phone (2026-10-20):** the service-off warning, the app picker, and a test lock. M6 done.
- [ ] **M4 Notifications and trusted time (built 2026-10-20; device setup pending).**
  - `NotificationPlanner` (pure; 10 tests): warnings at 21:00 and 23:00 while objectives remain (cancelled once done); a wake-up notice ("issued", or "judgement pending" when the day ended incomplete); an exercise reminder at 20:00 when reps are owed; "lock engaged" exactly at lock start (never earlier).
  - `LocalNotifier` schedules them with the OS (fires with the app closed, survives reboot). It uses exact timing once "Alarms & reminders" is allowed, otherwise inexact. On the device, inexact had a **1-hour delivery window**, which is why exact timing and the LATE NOTICES banner were added.
  - `TrustedClock` (5 tests): the device clock corrected by Android's network-synced clock; the game, the screens and the native blocker (`TrustedTime.kt`) all read it, so changing the phone's clock can't reopen a judged day or shorten a lock. Banners for a manual clock, blocked notices, and late notices.
  - Decision: no background judging at midnight (risk of two engines writing the save at once). Covered by the scheduled notices, the "judgement pending" wake-up notice, and the M6 redirect. Revisit if the trial shows a gap.
  - Gates: format and analyze clean, 85/85 tests; desugaring build OK; installed.
  - Device finding: OriginOS turned the accessibility service off after each of the last two updates, so it must be re-enabled after every update (the warning flags it).
  - **Confirmed on the phone (2026-10-20):** notifications allowed, "Alarms & reminders" allowed, and the 09:00 notice scheduled exact (delivery window 0, previously 1 hour). Delivery with the app closed is confirmed by tomorrow's 09:00 notice.
- [x] **M7 Dry-run mode (built 2026-10-20).**
  - Engine: `isEnforced(failedDay)`. A dry-run day still works out the real penalty and the real random lock window, emits them with `enforced: false`, and logs them, but adds no debt, no lock and no carry-over.
  - `SavedGame.liveFrom`: new games start with a 3-day dry run (live from day 4). Saves without the field are always enforced, so tonight's first real failure is unchanged.
  - [ DRY RUN ] notice shows the would-be push-ups and lock window, and the go-live date.
  - Status: trial day N / 30, penalty mode, and RESTART TRIAL (3-second hold). Restart archives the old game to its own key and starts fresh with the same objectives, apps and sleep window. It is **refused while a penalty is owed, scheduled or running**, so it can't be used to escape one.
  - Gates: format and analyze clean, 91/91 tests (6 new dry-run tests). Installed; service needed re-enabling again after the update.
  - The "fast-forward clock" idea from the plan was dropped: the engine tests already move a test clock through days, which covers it without shipping a time-travel control in the real app.
- **After M7 (2026-10-21), from the user's first live penalty day:** the 09:00 notice arrived on time; the lock engaged at its random time. Changes made on request:
  - The full emergency exit was replaced by a repeatable **15-minute release** that spends lock time (the end never moves), is counted on the Penalty tab and the block screen, is logged, and sends "Lock re-engaged" when it ends. Verified on the phone by the user.
  - Penalty sound made louder for phone speakers (overtones at 100–160 Hz, harder compression): loudness 0.32 → 0.47, phone-audible 0.17 → 0.29. Tab pop unchanged. Candidates were auditioned in a temporary Sound Lab, since removed.
  - Bugs fixed: RESTART TRIAL was hidden below the fold of the Status window (now a pinned footer with the exact blocking reason); a long-press anywhere on Status opened diagnostics and beat the 3 s restart hold (diagnostics now needs 7 quick taps, and is refused during a penalty because its stop button could end a real lock).
  - The user restarted the trial: the real 30-day trial began 2026-10-21 (dry run days 1–3, live from day 4).
- [x] **M8 Hardening (done 2026-10-21).**
  - **Root cause of "the service turns off after every update": a force stop, not the update.** Android disables an app's accessibility service when the app is force-stopped, and every install command used here ended with `am force-stop`. A plain `adb install -r` keeps it on (verified). **Never force-stop the app when installing.**
  - The same mechanism is a real-world escape (Settings → Force stop, or an aggressive memory cleaner). Mitigations: the watchdog checks the service on every sync and **logs one `blocker_offline` incident per outage** (with `duringPenalty` and `repaired`), the count shows on the System Check, and Quest shows a BLOCKER OFFLINE banner. Optional **auto-repair**: if the user grants `WRITE_SECURE_SETTINGS` once via adb (their choice; it changes a security setting), the app turns its own service back on when it opens.
  - **System Check** screen (from Status): service, notifications, on-time alerts, battery exemption (new request), automatic time, auto-repair, plus OriginOS hand-checks (Autostart, lock in Recents) and the outage count.
  - `AppBlocker.canBlock` replaces type checks against the web stand-in (a test exposed that the type check also skipped test doubles).
  - Gates: format and analyze clean, **106/106 tests**.
  - **Regression pass:** TestSprite full run (10 tests) found one real regression: 06 Status hid LEVEL and QUESTS CLEARED in the Status window's inner scroll on a short browser window (caused by the pinned footer). A height cut-off did not fix it; the final fix removes the inner scroll entirely (the window stretches on tall screens, the page scrolls on short ones). After the fix: **all 10 TestSprite tests passed** (01 7/7, 02 10/10 on rerun after a one-off blank load, 03 9/9, 04 10/10, 05 15/15, 06 10/10, 07 10/10, 08 5/5, 09 9/9, 10 9/9).
  - **On the phone:** a plain `adb install -r` kept the blocker service on, twice (no force-stop); battery exemption granted; the user confirmed the Status layout fits. Auto-repair not granted (optional, user's choice).
  - TestSprite credits used this month: 14.5 of 150.

**All milestones (M0–M8) complete. The 30-day trial is running: day 1 was 2026-10-21; dry run days 1–3; penalties live from day 4 (2026-10-24).**
  - Covers the web UI only; Android blocking, notifications and reboot behaviour stay in T3/T5.
