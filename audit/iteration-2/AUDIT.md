# Do or Die: independent audit (iteration 2)

Date: 2026-11-08. Version audited: 0.9.1 (versionCode 14), git `b4cbae9`, plus the release artefacts in `dist/`.
Method: I read the repository, ran the QA gates, wrote probe tests in a scratch copy, inspected the APK and AAB, and fetched the current official Google and Android pages cited in section 8. I did no device testing, no penetration testing and no user research. Every finding has one evidence label: **[VERIFIED-RUN]** (reproduced by running code or inspecting an artefact), **[VERIFIED-CODE]** (read at file:line), **[INFERENCE]** (reasoned, not reproduced) or **[UNVERIFIED RISK]** (needs a device).

---

## 1. Executive Summary

Do or Die is a single-player Android habit app (Flutter, with Kotlin for blocking). The user picks a "System" (Focus, Fitness or Personality), and a placement test sets a rank from E to C. The System then issues a fixed daily quest. A failed day triggers the "Penalty Zone" the next day:
- the apps the user chose are locked for 4 hours from a time the user set (18:00 by default);
- Personality adds a reading penalty and Focus adds a phone-free-block penalty.

Clearing 21 of 30 days opens a Gate, which leads to a three-day Dungeon and then a rank-up.

**The engineering is better than typical for a solo project:**
- The rules engine is pure Dart and well tested. The suite has 253 Dart tests (all pass) and 17 JVM tests (all pass), with 82.8% line coverage of loaded files.
- Penalty safety rules are sensible. Exercise is never used as punishment, nothing carries over, and a near miss counts at 80% done. Each lock has two releases, an emergency exit that always works, and a contest path.
- Privacy is genuinely strong. There is no INTERNET permission, backup is off, and no exported component can be abused.

**What blocks a public release:**
1. **P0, wrongful penalty [VERIFIED-RUN].** On the night daylight saving time ends, the day is judged about an hour early, at 23:00 local time. Any user in the EU or US who finishes after 23:00 that night is failed and locked the next day. I reproduced this with `TZ=Europe/Berlin` and `TZ=America/New_York`. India (no DST) is unaffected.
2. **P1, wrongful penalty [VERIFIED-RUN].** After a restart without a dry run, the first quest is due the same day, so a 23:40 restart produces an enforced lock the next day.
3. **P1, inaccurate store listing.** The listing says "the Dungeon Penalty doubles the lock". The code never doubles the lock.
4. **P1, Play declarations and closed test not done (needs the owner).** The special-use foreground service declaration and video, the Health apps declaration, and the 12-tester, 14-day closed test have not been done.
5. **Business viability is unproven.** The only real-user evidence in the repo is the owner's own run: day 8, "2 of 21 days toward the Gate, streak 1 (best 2)" (`progress.md:27`). That is roughly a 50% clear rate over the live days, below the project's own 70% pass bar (`PROJECT.md` §6).

**Verdict:** continue as a personal trial, and ship to internal testing after fixing the P0. A public production release is No-Go until the P0 and P1 items close and the closed test produces retention data.

---

## 2. Product Viability (Founder view)

- **Problem.** People who know what to do but don't do it, especially with phone overuse. This problem is real and widely felt.
- **Audience.** Young adults (18+) attracted by "System / rank-up" game fiction. The theme narrows reach but gives a distinctive hook.
- **Differentiation.** The combination is unusual: an enforced app lock, System-written quests, Dungeon rank trials, and honest logging. Each part on its own is crowded:
  - screen-time blockers: one sec, Opal, ScreenZen, Digital Wellbeing;
  - gamified habit apps: Habitica, SelfQuest, RankUp, Level Up (these are listed in `SYSTEMS_PRD.md` §1.1).
- **Monetisation.** None is designed. The listing says "Free", with no ads and no internet. A paid tier or a one-off purchase would need Play Billing, and that conflicts with the "no internet" privacy position only lightly. **This is a product decision for the owner.**
- **Business risks:**
  - Play policy scrutiny of app-locking and special-use foreground services.
  - Theme and IP proximity to a well-known anime. The shipped app is clean, but the public repo docs name the source work, for example `PROJECT.md` §2.1.
  - A penalty-led product invites uninstall as the escape.
  - n=1 evidence.
- **Recommendation: Narrow.** Keep Focus as the core, which the code already treats as the default, and treat Fitness and Personality as optional. Prove day-30 retention with 12 or more closed testers before any further feature work.

## 3. Audience and Problem-Solution Fit

- **Fit is strongest for Focus.** The lock is a real consequence tied directly to the problem (phone overuse), and screen time is measured automatically through usage access.
- **Personality and Fitness are weaker.** Most items are honour checkboxes or counters, such as "Say hello to someone…", "Finish a short book" or push-ups. The penalty is unrelated to the failed behaviour (app lock plus pages). That makes the System feel arbitrary for these packs. [VERIFIED-CODE `lib/domain/system_catalogue.dart:24-164`]
- **Focus E's "No phone after waking (minutes)" is not measured as stated.** It is a phone-free timer that locks only the chosen apps; the user can start it any time and use any other app while it runs. [VERIFIED-CODE `system_catalogue.dart:173`, `game_service.dart:742-760`]
- **Focus S's "Chosen apps stay locked all day" is an honour checkbox**, even though the app could enforce it. [VERIFIED-CODE `system_catalogue.dart:214`]
- **Evidence of fit:** none beyond the owner's own run, which is below target (section 1).

## 4. Technical Architecture (Senior Android engineer)

### How it works
| Layer | Contents | Assessment |
|---|---|---|
| `lib/domain/` | Pure-Dart rules: `engine.dart` (day closing), `penalty.dart` (amounts, lock scheduling), `dungeon.dart`, `systems.dart`, `system_catalogue.dart`, `block_list.dart`, `config.dart` (every tunable) | Clean, immutable, deterministic; respects the "no penalty logic in UI" rule [VERIFIED-CODE] |
| `lib/app/game_service.dart` | Single entry point; every mutation goes through `_serial` (a FIFO future queue), is logged and saved | Serialisation is good and tested (`test/app/concurrency_test.dart`) |
| `lib/data/` | One JSON document in `SharedPreferencesAsync`; append-only log; archives under timestamped keys | Simple and robust, but grows without bound (below) |
| `lib/app/penalty_enforcer.dart` | Pushes diffs to native: packages, lock window, focus window, first unjudged day, "quest done" | 100% covered |
| Android (`android/app/src/main/kotlin`) | `WatcherService` (special-use foreground service, polls UsageEvents every 700 ms while busy), `BlockActivity` (native lock screen), `WakeScheduler` (exact alarms at midnight and 60 s before a lock), `BootReceiver`, `TrustedTime` (network clock with an elapsed-time anchor), `BlockerState` (SharedPreferences) | Sensible design: uses no accessibility service, which keeps banking apps working |

### Quest engine correctness
- **Days close strictly forward.** The quest is snapshotted when it is issued (`dungeon.dart:249-267`), so an update can't change a live quest. Settings changes are delayed 2 days. Removing an app from the lock list is delayed 7 days. Restart is refused after 18:00 on an unfinished live day. [VERIFIED-CODE; tests pass]
- **DST defect (P0-1) [VERIFIED-RUN].** `dayIn` (`game_service.dart:55-61`) uses whichever date is later: the local date or the date in the stored offset. The stored offset only updates when a day closes (`game_service.dart:416-428`). On a fall-back day (offset +120 to +60) the stored +120 makes "today" become tomorrow at 23:00 local, so the open day is judged an hour early. After that tick the offset updates, `today` reverts to the closed day, and every progress write is refused until midnight. Probe results:
  - `TZ=Europe/Berlin` on 2026-10-25 23:10: `lastClosedDay` was 2026-10-25, expected 2026-10-24.
  - `TZ=America/New_York` on 2026-11-01: same failure.
  - `TZ=Asia/Kolkata`: passes.
- **Same-day first quest after a restart (P1-1) [VERIFIED-RUN].** `awaken` starts the System on the onboarding day (`game_service.dart:170-172`). A second Awakening gets no dry run (`main.dart:169,177`). An Awakening at 23:40 issued three Personality items due at 23:59, and the next morning gave `quest_failed` plus an enforced lock from 18:00 to 22:00 and 20 pages owed. `chooseSystem` deliberately starts tomorrow "so it is never judged on a day the user had no chance to do it" (`game_service.dart:598-600`), but `awaken` does not apply the same rule.

### Blocking reliability
- **Start paths.** The watcher starts from the app being opened, from exact alarms, and from BOOT_COMPLETED or MY_PACKAGE_REPLACED. All of these are documented exemptions to the background foreground-service start limits (source in section 8). Failures are recorded and surfaced through a notification. [VERIFIED-CODE `WatcherService.kt:178-194`, `StartFailureNotice.kt`]
- **Alarms use the device clock (P2-1).** The alarms are `RTC_WAKEUP` on the device wall clock, but "now" and the lock start are trusted (network) time (`WakeScheduler.kt:42-55`). Nothing handles `ACTION_TIME_CHANGED`. With automatic time off and the clock set back by N hours, the lock wake-up fires N hours late and the watcher stays idle. Because the watcher is legitimately stopped, this is not logged as an outage. The lock is enforced again only when Do or Die is opened. [INFERENCE]
- **Battery cost (P2).** While a verdict is due (every day after midnight until the app is opened, unless the quest was settled) and during a lock, `UsageStatsManager.queryEvents` runs every 700 ms (`WatcherService.kt:46,62,170`). [INFERENCE: battery cost not measured]
- **Other escapes are by design.** Force stop, revoking usage access or overlay, and uninstalling all end enforcement. Outages are logged when the app is next opened (`game_model.dart` `_watchBlocker`). Starting the block activity from a foreground service depends on the overlay-permission exemption to background activity launches; vendor skins may differ. [UNVERIFIED RISK: device test needed on Android 15/16 and the owner's vendor skin]
- **Lock list mismatch (P3).** The native app picker hides protected packages, but `setBlockedPackages` accepts any list (`MainActivity.kt:41-45`); filtering relies on Dart's `neverBlockPackages`. The Kotlin and Dart lists are mirrored by hand (`MainActivity.kt:176`, `block_list.dart:21`), and Kotlin lacks `com.google.android.apps.maps` and contacts. That is harmless today because Dart filters, but it is fragile. [VERIFIED-CODE]

### Storage and performance
- **Whole-document saves (P3) [VERIFIED-RUN].** The whole game, including the full log, is re-encoded and written on every tap. After a simulated year of normal use the log had 4,907 entries and the save was 557 KB, rewritten roughly 13 times a day. That took 5.7 ms per tap on desktop; on a phone with DataStore it will be slower [INFERENCE].
- **Archives are never deleted** (`game_store.dart:76-81`).

### Code quality
- `dart format` is clean and `flutter analyze` reports no issues.
- `isMinifyEnabled=false`, with a documented reason (R8 broke JNI plugins). The APK is 72 MB and the AAB 66 MB, partly because of the three ABIs and the `flutter_soloud` codecs.
- **Coverage is low on platform bridges:**

  | File | Coverage |
  |---|---|
  | `blocker.dart` | 30.5% |
  | `notifier.dart` | 0% |
  | `usage_meter.dart` | 11% |
  | `game_store.dart` (PrefsGameStore) | 35% |
  | `main.dart` | not loaded |

- **No integration test** runs the native blocker. The JVM tests cover only `UsageLogic` and `TrustedTime`.

## 5. UI/UX (Senior UI/UX designer)

I judged from the code and the four store screenshots (`release/screenshots/*.png`, 1080x2400). I did not run the app on a device.

**Strengths:**
- The visual system is coherent: blue System windows and a red Penalty Zone, with clear hierarchy on the Quest screen (quest, time remaining, XP).
- Reduced motion is respected in six widgets (`disableAnimations`).
- Hold controls expose `Semantics(onLongPress:)`, so screen-reader users can confirm.
- Large text is tested (`test/ui/large_text_test.dart`).
- The terms are scroll-gated, and an 18+ confirmation is required.

**Issues (each with its reason):**
1. **The copy contradicts the rules (P2) [VERIFIED-CODE].** The terms say "Partial completion is failure" (`onboarding_screen.dart:2223`), and the Quest screen says "Failure to complete will result in a penalty" (`quest_screen.dart:372`). The engine gives no penalty at 80% or more (`engine.dart:252-253`).
   - Users can't predict outcomes. Over-warning also teaches users to ignore warnings.
2. **The terms say locks start "from 18:00" (P3).** When the rest period ends before 22:00, the lock is moved earlier (`penalty.dart:278-281`), so the stated time is wrong for some users. Wrong predictions erode trust in a punishment system.
3. **Hold controls are 36 dp high (P2) [VERIFIED-CODE `hud_controls.dart:178`].** This is below the 48 dp touch-target guidance, and these are the most frequent actions.
4. **Emergency exit discoverability (P3).** It is a dim text button (`penalty_screen.dart:697`). It must be findable under stress; it is the safety valve.
5. **Onboarding length.** The Awakening runs about 2,600 lines of UI: System choice, placement, rank reveal, lock targets, rest ring, and 16 terms to read before acceptance. That is heavy for the first five minutes, though it is defensible for a consent-heavy product. Measure drop-off per step.
6. **Penalty-first framing.** The quest screen's standing footer is a red warning, and nothing celebrates partial progress. See section 7.
7. **Store screenshots (P2).** They show the owner's status bar and third-party app names ("Battlegrounds India", "YouTube"). They also show the Personality System while the listing says Focus is the core. Use a clean demo state.

## 6. Security and Privacy

**What's done well:**
- There is no `INTERNET` permission in the release manifest [VERIFIED-RUN `aapt2 dump badging`].
- `allowBackup=false` and data-extraction rules exclude everything [VERIFIED-RUN, VERIFIED-CODE].
- Only `MainActivity` (launcher) and the androidx `ProfileInstallReceiver` (guarded by `DUMP`) are exported [VERIFIED-RUN].
- The keystore lives outside the repo, and `key.properties` is git-ignored [VERIFIED-CODE `.gitignore`].
- A usage-access prominent disclosure with ACCEPT / NOT NOW comes before the Settings intent (`usage_disclosure.dart`).

**Gaps:**
1. **The privacy policy omits free-text content (P2) [VERIFIED-CODE].** The policy covers progress and logs, but not the written reflections (`game_service.dart:953-960`), the emergency-exit and contest reasons, or the placement answers. These are personal free text that is kept and exported.
2. **No in-app deletion (P2).** Old trials, including their reflections, can only be removed by clearing app data or uninstalling.
3. **The policy says exact alarms are only for notices.** They also wake the watcher (`WakeScheduler.kt`). This is a minor inaccuracy.
4. **The device APK is debug-signed** (`CN=Android Debug`) [VERIFIED-RUN]. That is intended for the owner's phone only and labelled as such in `PLAY_RELEASE.md`, but it must never be distributed.

**Abuse against another person.** Someone with physical access could configure locks on another adult's phone. This is mitigated:
- the phone's user always has the emergency exit, uninstall and force stop;
- the watcher notification is visible;
- calls, SMS, maps, settings and banking apps are never locked (`block_list.dart:5-34`).

Residual risk is low. A coercive partner gains little control, because escape is always available to the phone's user. [INFERENCE]

**Threat model.** This is a commitment device, not a security boundary. The user can always bypass it (force stop, revoke a permission, uninstall, change the clock as in P2-1). The design is right to log outages rather than to harden the lock with device admin. The clock bypass is the only one that goes unlogged.

## 7. Behavioural Psychology

**Good:**
- Exercise is never used as punishment.
- No debt carries over or doubles.
- The near miss at 80% or more removes the all-or-nothing cliff.
- A contest path and an emergency exit exist.
- The reduction valve is limited to 6 of every 30 days.
- A health notice, a stop rule and an 18+ gate are shown.
- Ranks are never lost.

These directly address the main harms of punishment-based apps.

**Concerns:**
1. **Loss framing dominates.** The name, the red warnings and the "Penalty Zone" make avoidance the main motivator. Avoidance motivation sustains short-term compliance but predicts disengagement and uninstall once the threat is removed (the uninstall escape). Add positive reinforcement for partial progress, and show "days kept" more prominently than "failures".
2. **Near misses have no limit and no feedback [VERIFIED-RUN].** A Fitness D user who did everything except 80% of the plank got 30 near misses in 30 days, with no lock and no XP. That is safe and fair, but it silently stalls progress (no Gate). Tell the user explicitly, for example: "Near miss 5 days running: consider the reduction valve."
3. **The S rank needs 30 consecutive clears, and the hold resets to zero on any miss** (`dungeon.dart:365`). Perfection requirements are fragile and punish a single lapse. Consider "30 of 33" days.
4. **Emergency exits have no limit [VERIFIED-RUN: 10/10 accepted].** This is correct for safety, and it is logged. The report should reflect patterns without shaming.
5. **Personality social tasks every day** ("Say hello to someone…", "Greet someone new") can be anxiety-provoking for the persona described (Noor), and there are no alternatives. Offer swaps.
6. **The reflection penalty** (five lines, four or more words each, a "plan for tomorrow") is reasonable. It is implementation-intention style and not humiliating.

No dangerous exertion, sleep loss, food restriction or humiliation is present. Locks never run during the rest period, and the rest period must leave 12 waking hours (`config.dart:19`).

## 8. Google Play Compliance (with URLs)

| Area | Status | Source |
|---|---|---|
| Target SDK | targetSdk 36 [VERIFIED-RUN]. Required for new apps and updates from 31 Aug 2026 | https://developer.android.com/google/play/requirements/target-sdk |
| Foreground service, special use | Declared in the manifest with `PROPERTY_SPECIAL_USE_FGS_SUBTYPE` [VERIFIED-RUN]. Play Console App content needs a description, the user impact if deferred, a video link and a use case; "All foreground service types are subject to review". Not yet submitted; **needs the owner** | https://support.google.com/googleplay/android-developer/answer/13392821 |
| Starting the foreground service from the background | Exact alarm, BOOT_COMPLETED and MY_PACKAGE_REPLACED are exemptions. The SYSTEM_ALERT_WINDOW exemption on Android 15+ requires a visible overlay window, which the app does not rely on [VERIFIED-CODE] | https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start |
| Usage access and installed-apps inventory | The User Data policy needs an in-app disclosure immediately before the request, with affirmative consent. The installed-app inventory is "personal and sensitive". The app's dialog complies [VERIFIED-CODE `usage_disclosure.dart`]. The app list is read via the `<queries>` launcher intent, not QUERY_ALL_PACKAGES | https://support.google.com/googleplay/android-developer/answer/10144311 |
| Health apps declaration | Required for closed, open and production tracks; "Activity and Fitness" fits. The kit plans this; **needs the owner** | https://support.google.com/googleplay/android-developer/answer/14738291 |
| New personal account testing | 12 or more testers, 14 continuous days, before production. Not started; **needs the owner** | https://support.google.com/googleplay/android-developer/answer/14151465 |
| Developer verification | Protections began 30 Sep 2026 in Brazil, Indonesia, Singapore and Thailand; global from 2027. This affects future sideloaded distribution of the device APK outside Play | https://developer.android.com/developer-verification |
| Exact alarms | `SCHEDULE_EXACT_ALARM` is user-granted. The app degrades by keeping the watcher running when exact alarms are refused (`UsageLogic.watcherNeeded`) | (Android behaviour; see the restrictions page above) |
| Store listing accuracy | **P1.** "Fail it, and the Dungeon Penalty doubles the lock" (`release/PLAY_RELEASE.md:72`) is false; the lock is never doubled (`engine.dart:298-318`; the terms at `onboarding_screen.dart` say "the normal lock"). The listing's "at a time you picked" also holds only after a Settings change. Inaccurate metadata is a policy risk | (Metadata / misrepresentation; not fetched; [INFERENCE]) |
| Data safety | "No data collected" is consistent with no INTERNET permission and backup off [VERIFIED-RUN] | answer/10144311 above |
| Privacy policy | Hosted and in-app; omits free-text content (section 6) | |
| IP and branding | No source-work names in shipped code, assets or listing [VERIFIED-RUN grep]. The public repo docs name the source work (`PROJECT.md`, `PRD.md`, `design/DESIGN.md`) | [INFERENCE] low risk |

This is not legal advice.

## 9. QA and Testing

### Gates (all run by me on 2026-11-08)
| Gate | Result |
|---|---|
| `dart format --output=none --set-exit-if-changed lib test` | 74 files, 0 changed, exit 0 |
| `flutter analyze` | No issues found |
| `flutter test --coverage` (scratch copy) | **253 passed, 0 failed** |
| `./gradlew :app:testDebugUnitTest` | BUILD SUCCESSFUL; UsageLogicTest 11/11, TrustedTimeTest 6/6 |
| Line coverage (lcov, loaded files) | **82.8%** (6,982 of 8,430); `main.dart`, `build_flags.dart` and `fill_column.dart` are not loaded by any test |
| `tools/check_release.py` on `dist/` | Both artefacts OK (versionCode 14, targetSdk 36, allowBackup false) |
| Artefact inspection | AAB signed by `CN=Do or Die` (upload key); device APK debug-signed; no INTERNET permission; exported components reviewed |

### Coverage of important files
| File | Line coverage |
|---|---|
| `domain/engine.dart` | 100% |
| `domain/penalty.dart` | 99.1% |
| `domain/dungeon.dart` | 96.9% |
| `domain/systems.dart` | 96.8% |
| `app/game_service.dart` | 96.7% |
| `app/penalty_enforcer.dart` | 100% |
| `app/notification_planner.dart` | 76.5% |
| `data/game_store.dart` | 35.0% |
| `platform/blocker.dart` | 30.5% |
| `platform/notifier.dart` | 0% |
| `ui/game_model.dart` | 58.0% |
| `ui/widgets/notice_overlay.dart` | 40.4% |
| `ui/screens/penalty_screen.dart` | 71.7% |

### Probe tests (scratch copy, `test/probe/`)
| # | Steps | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | `TZ=Europe/Berlin`: awaken Sat 24 Oct 2026 10:00 (live); open Sun 00:05; open Sun 25 Oct 23:10 (DST ended 03:00) | Sunday still open until local midnight | `lastClosedDay` = 2026-10-25: Sunday judged at 23:00 local; progress then refused until midnight | **FAIL (P0-1)** |
| 2 | Same as 1 with `TZ=America/New_York` on 31 Oct and 1 Nov 2026 | Sunday open | Sunday judged early | **FAIL (P0-1)** |
| 3 | Same as 1 with `TZ=Asia/Kolkata` | Sunday open | Sunday open | Pass |
| 4 | Awaken Personality E with no dry run at 23:40; open next day 08:00 | Not judged on a day with 19 minutes available (as `chooseSystem` does) | `quest_failed`; lock 18:00 to 22:00 enforced; 20 pages owed | **FAIL (P1-1)** |
| 5 | Fitness D, 30 days, everything done except the plank (6/30 s) | Documented behaviour | 30 near misses, 0 locks, 0 XP | Works as designed; feedback gap (P2) |
| 6 | Fail 10 days; take an emergency exit each day | Exit always available | 10/10 accepted | Pass (safety) |
| 7 | One year of normal use (about 13 logged actions a day) | Save stays small | 4,907 log entries, 557 KB rewritten on every tap, 5.7 ms per tap on desktop | Pass; growth risk (P3) |

### Not covered by any test
- The native lock under force stop, reboot, battery optimisation and vendor killers.
- Split-screen and picture-in-picture over a locked app.
- Notification delivery.

These need the manual device checklist. TestSprite covers the web build only. [UNVERIFIED RISK]

## 10. Feature Audit

| Feature | Current Implementation | Problem | User Impact | Recommendation | Priority |
|---|---|---|---|---|---|
| Day judging and time zones | Zone-pinned day (`dayIn`) | Fall-back DST judges an hour early [VERIFIED-RUN] | Wrongful lock once a year for DST users | Fix: Improve | P0 |
| First quest after Awakening | Starts the same day | No dry run on later Awakenings, so a late-night start is failed [VERIFIED-RUN] | Wrongful lock | Improve: start tomorrow after 18:00, or always when there is no dry run | P1 |
| Store listing | `PLAY_RELEASE.md` §4 | Says the lock doubles | Misleading metadata | Replace the sentence | P1 |
| App lock (watcher plus block screen) | Usage events polled every 700 ms, native screen | RTC alarms on device clock; unlogged bypass | Silent bypass; battery | Improve: elapsed-time alarms plus a TIME_SET receiver; slower polling | P2 |
| Emergency exit, releases, contest | Always available, logged | Dim placement | Hard to find under stress | Keep; make the exit more visible | P3 |
| Near miss (80%) | No penalty, no XP | No limit or feedback | Silent stall | Improve: notice after 3 in a row | P2 |
| Focus System | Caps measured, phone-free timer | "After waking" not measured; S rank is an honour checkbox | Weak signal | Improve | P2 |
| Personality System | Mostly honour checkboxes | Social tasks daily, no swap | Anxiety, honour fatigue | Improve: swaps | P2 |
| Fitness System | Counters, timers; no penalty but the lock | Honour only; Health Connect deferred | Low credibility | Keep as optional; Health Connect later | P3 |
| Gates and Dungeons | 21/30, 48 h, 3 floors | Solid; S hold needs 30 straight days | Fragile at the top | Keep; soften the S hold | P3 |
| Stats (STR, INT, …) | Allocate points; no effect (`SYSTEMS_PRD` §5.7) | Fake progress | Loses meaning in a week | Remove or show trained stats only | P2 |
| Reduction valve | ≤20%, 6 per 30 days, half XP | Fine | Fine | Keep | — |
| 30-day report and share card | Built live from the log | Fine; honesty section | Good reflection tool | Keep | — |
| Trial log export (JSON/CSV) | Share sheet | Contains free-text reflections | Privacy | Keep; disclose in the policy | P2 |
| Settings (rest period, lock time) | 2-day delay | Lock time isn't chosen in onboarding | User is told 18:00 | Add to onboarding | P3 |
| Notifications | 3 h and 1 h warnings, floor, gate | 0% coverage of the notifier | Unknown on device | Test on device | P2 |
| Spike screen (`lib/spike/`) | Diagnostics, reachable only when `kDebugMode` (`app_shell.dart:196`, `settings_screen.dart:190`) [VERIFIED-CODE] | Still compiled into the release | None for users | Keep as is | — |

## 11. Growth and Retention

- **Acquisition.** The theme and the "System" fandom are a strong organic hook (short-video content about "the System locked my apps"). The Play listing is honest apart from the P1 sentence.
- **First five minutes.** The Awakening is long and consent-heavy: two Settings permission trips, app picking and 16 terms. Expect drop-off at the usage-access and overlay steps.
- **Day-1 return.** This depends on the 21:00 and 23:00 warnings and on the curiosity of the first verdict. The dry run reduces early risk.
- **Likely uninstall reasons:** a lock at a bad moment, a wrongful verdict, honour-system fatigue, and the hassle of permissions or vendor battery killers.
- **Meaningful versus artificial engagement.** Success is days kept, minutes of social media avoided and pages read, not time spent in the app. The report already measures the real-life outcomes. Keep in-app time low.
- **Privacy-respecting metrics.** There is no internet, so use an opt-in "tester export":
  - a weekly anonymised summary file the tester chooses to share;
  - counts only: days judged, cleared, near miss, failed, locks served, releases, exits, contests, outages, and day-N still active;
  - a single day-30 survey (would you miss it?).

  Define activation as completing the Awakening, with both permissions granted, and judging one live day. Define retention as an open in week 4 plus at least one live day judged in the last 7.
- **The owner's own data is the only signal: 2 cleared of about 4 live days.** Treat the next 22 days as the go/no-go evidence that `PROJECT.md` §6 asks for.

## 12. Prioritised Roadmap

### P0
**P0-1. DST fall-back judges the day an hour early.**
- **Problem:** `dayIn` with a stale stored offset (`game_service.dart:55-61, 416-428`) judges the day at 23:00 local on the night DST ends.
- **Solution:** distinguish a time-zone move from a DST transition. Store the IANA zone id (available via `flutter_timezone`, already a dependency). If the zone id is unchanged, use the local date. Alternatively, refresh `zoneOffsetMinutes` whenever the offset changes while the zone id stays the same.
- **Impact:** removes a wrongful penalty that recurs every year.
- **Complexity:** low. **Effort:** 0.5 day. **Dependencies:** none.
- **Acceptance:** the probe tests for `TZ=Europe/Berlin` (2026-10-25) and `TZ=America/New_York` (2026-11-01) pass, spring-forward is covered, and the existing west/east zone tests still pass.

### P1
**P1-1. Same-day enforced first quest after a restart.**
- **Solution:** in `awaken`, start the System tomorrow when there is no dry run (or always after 18:00). Today becomes a free day; show "FIRST QUEST: tomorrow".
- **Effort:** 0.5 day.
- **Acceptance:** probe 4 passes, with no `quest_failed` for the Awakening day.

**P1-2. Store listing claims the Dungeon Penalty doubles the lock.**
- **Solution:** edit `PLAY_RELEASE.md` §4 and `README.md:5` to say "the normal lock; reading and phone-free penalties double".
- **Effort:** 10 min.
- **Acceptance:** no occurrence of "double lock" or "doubles the lock" in the listing or README.

**P1-3. Play declarations and closed test (needs the owner).**
- **Tasks:** the special-use foreground service declaration and video, the Health apps declaration, and a closed test with 12 or more testers for 14 days.
- **Acceptance:** Console App content complete; closed test running; tester export collected.

**P1-4. Device verification of enforcement (needs the owner).**
- **Tasks:** on Android 15/16 and the owner's vendor skin, verify reboot, force stop, update, and a lock starting while a locked app is already open.
- **Acceptance:** the manual checklist is recorded in `BUILD_LOOP.md` with dates and results.

### P2
- **P2-1. Unlogged clock-change bypass.** Use `ELAPSED_REALTIME_WAKEUP` alarms computed from the trusted delta, plus a receiver for `TIME_SET` and `TIMEZONE_CHANGED` that calls `WatcherService.sync`. Effort 0.5 day. Acceptance: a JVM test for the alarm computation; a device test with the clock moved back keeps the lock wake-up on time.
- **P2-2. Copy contradicts the near-miss rule.** Fix `onboarding_screen.dart:2223` and `quest_screen.dart:372`. Effort 15 min.
- **P2-3. Privacy policy omits free text.** Add reflections, reasons and placement answers to the policy (web and in-app). Add "Delete old trials" in Settings. Effort 0.5 day.
- **P2-4. Near-miss feedback.** Add a System notice after 3 near misses in a row, pointing to the reduction valve. Effort 0.5 day.
- **P2-5. Touch targets.** Make hold controls at least 48 dp. Effort 1 hour. Acceptance: a widget test checks the size.
- **P2-6. Stats with no effect.** Remove stat points, or show only the trained stats (a product decision, needs the owner).
- **P2-7. Watcher polling cost.** Poll at 700 ms only while locked. While only a verdict is due, poll every 3–5 s, or react to app-open events less often. Measure battery on the device.
- **P2-8. Store screenshots.** Use a clean demo state, the Focus System and no third-party brand names.
- **P2-9. Personality swaps.** Add an alternative for each social task.

### P3
- Storage growth (split the log into its own key, or compact old progress entries).
- Native protected list parity with Dart.
- Lock-time choice in onboarding.
- Soften the S hold to "30 of 33".
- Make the emergency exit more visible.
- Fix docs drift: `progress.md` says 205 tests and 0.9.0 on the phone; README says both "switch any time" and "only once complete".

## 13. Recommended New Features

1. **Tester export** (an opt-in weekly summary file). This is the only way to get retention evidence without network access.
2. **Health Connect steps** for Fitness, which replaces honour counting where possible.
3. **Enforced Focus S** ("apps locked all day" applied by the watcher instead of an honour checkbox).
4. **Positive progress feedback:** a kept-days calendar on the Quest screen, and a "partial credit" view.

Nothing else. Don't add social features, leaderboards or AI until retention is proven.

## 14. Remove or Replace

- **Remove** stat allocation (or show trained stats only); it has no effect in play.
- **Replace** the "Partial completion is failure" copy.
- **Replace** "No phone after waking" (Focus E) with a phone-free block of N minutes before a user-chosen time, or measure the first unlock after the rest period ends using usage events.
- **Remove** source-work names from the public repo docs before any marketing push.

## 15. Play Publication Readiness

| Item | State |
|---|---|
| AAB signed with the upload key, versionCode 14, targetSdk 36, no INTERNET permission, backup off | Ready [VERIFIED-RUN] |
| Privacy policy URL, in-app policy, usage disclosure | Present; policy incomplete (P2-3) |
| Data safety answers | Consistent |
| Special-use foreground service declaration and video | Not done (owner) |
| Health apps declaration | Not done (owner) |
| Store listing | One false claim (P1-2); screenshots need cleanup |
| Closed test with 12 testers for 14 days | Not started (owner) |
| Open P0 | P0-1 (DST) |

**Internal testing:** feasible after P0-1 and P1-2. **Production:** not ready.

## 16. Go / No-Go

**Internal testing: Go after P0-1 and P1-2. Production: No-Go.**

| Dimension | Score | Reason |
|---|---|---|
| Business Potential | 4 | Real problem and a distinctive hook. No monetisation design, a crowded market, Play-policy and IP-adjacency risk, and no evidence beyond n=1 (the cap is 6 without evidence) |
| Product-Market Fit Potential | 3 | The only evidence is the owner's run: about 50% clear rate over the live days, below the project's own 70% bar. Personality and Fitness are mostly honour-system |
| Technical Quality | 6 | Clean pure-Dart rules, serialised writes, 253 and 17 tests passing, 83% coverage. But a reproduced wrongful-penalty bug (DST), a same-day restart penalty, alarms on the device clock, and low platform-layer coverage |
| UI/UX Quality | 6 | Coherent, polished theme with reduced motion, semantics and a large-text test. Copy contradicts the rules, touch targets are small, onboarding is heavy, and the framing is penalty-led. Not device-tested by me |
| Security and Privacy | 7 | No network access, no backup, minimal exported surface, proper disclosure. The policy omits free-text data, there is no in-app deletion, and one unlogged bypass |
| Behavioural Design | 6 | Major safety fixes are in (no exercise punishment, no carry-over, near miss, exit, contest). Still loss-framed, near misses get no feedback, the S hold is fragile, and social tasks run daily |
| Retention Potential | 4 | A threat-based loop with uninstall as the escape, honour fatigue, a heavy first session, no social pull, and weak n=1 data |
| Publication Readiness | 5 | The artefact is technically compliant, but there is an open P0, a misleading listing line, and the special-use foreground service and Health declarations and the closed test are not done (the cap is 7 while any of these is open) |

### Where the roles disagree
- **Founder versus behavioural psychologist on punishment.** The founder sees the lock as the differentiator; the psychologist sees loss framing as a retention risk.
  - **Resolution:** keep the lock, because it is the product, but make positive progress the primary visual signal, and measure uninstall-after-first-lock in the closed test.
- **Engineer versus product manager on the unlimited emergency exit.** It weakens enforcement, but it is the required safety escape.
  - **Resolution:** keep it unlimited and keep reporting it honestly.

### If I were investing my own money, reputation and six months
I would continue, but narrowly: Focus only, and personal plus closed-test only, until the data says otherwise.

What I'd change first, in order:
1. Fix the DST verdict bug and the same-day restart penalty this week.
2. Correct the listing and copy.
3. Ship to internal testing.
4. Recruit 12 to 20 phone-overuse testers.
5. Add an opt-in weekly summary export so retention and clear rate can actually be measured.
6. Freeze Fitness and Personality feature work.

If week-4 activity and clear rate among testers aren't at least comparable to the owner's 70% target, pivot to a lighter "commitment lock" utility, or stop. That would be a cheap and honest result.
