# Do or Die: independent audit (iteration 3)

Audit date: 2026-11-08. Build under audit: git `15d0e9c` (main, clean), version 0.9.2+15, release artefacts `dist/DoOrDie-0.9.2.aab` and `dist/DoOrDie-0.9.2-device.apk`.

Method: I read the repository and ran the gates and probe tests. I fetched official Google Play and Android pages. No earlier audit, memory or `.claude/` content was read, except the auditor role file. Probe tests ran on a scratch copy. The repository was not modified, apart from these two files and the gitignored Gradle `build/` output from the requested JVM test run.

Evidence labels: **[VERIFIED-RUN]** reproduced by running code or inspecting a built artefact. **[VERIFIED-CODE]** read at file:line. **[INFERENCE]** reasoned, not reproduced. **[UNVERIFIED RISK]** needs a device or a pen test. I did no device test, pen test or user research.

---

## 1. Executive Summary

Do or Die is a Flutter Android habit app styled as a game "System". The user picks a System (Focus, Fitness or Personality) and a placement test sets a starting rank (E to C). Each day the System issues a fixed quest. If the user fails it, the apps they chose are locked for 4 hours the next day, from a time they chose. Focus and Personality also owe a small penalty (a phone-free block, or pages plus a written plan). Around this core sit XP, levels, stats, Gates (21 of 30 days cleared), three-day Dungeons, Rank Trials, a reduction valve, near misses, contests, releases, an emergency exit, a 3-day dry run and a 30-day report.

**Engineering is well above the usual standard for a solo project.**
- All the rules are pure Dart in `lib/domain/`, with one config file.
- Every game change runs through one serialised queue, and the trial log is append-only.
- Time comes from a trusted clock: network time, then an elapsed-clock anchor.
- The blocker uses a usage-stats watcher, a block activity and exact-alarm wake-ups. It does not use an accessibility service.
- No INTERNET permission is requested. Backup is off.
- Gates are clean: format 0 changed, analyze 0 issues, 260/260 Dart tests, 19/19 Kotlin JVM tests, 82.8% line coverage.
- The full Dart suite also passes under 9 other time zones, including zones with DST at midnight and Lord Howe's 30-minute DST.
- The release artefacts match HEAD, target SDK 36, are 16 KB-aligned, and pass the project's own release check.

**What is wrong.**
- **Travel west (P1).** Crossing time zones westward still causes a wrongful early verdict. The day is judged hours before local midnight, and the user then cannot log progress for the rest of that local day. [VERIFIED-RUN]
- **Day with no quest (P2).** The first day of a game without a dry run has no quest. It is logged as "cleared", raises the 30-day clear rate, and triggers a "QUEST CLEARED" notice. [VERIFIED-RUN]
- **No outside evidence.** The product has no real-user data. The only evidence is the owner's own run, which the project's own notes describe as weak.
- **Scope has outgrown the question.** The trial's one question is whether a real penalty changes behaviour. That question is now buried under a full RPG progression layer.
- **Platform delivery is unproven on devices.** This covers specialUse FGS review, Android 15 limits on background FGS and activity starts, and the closed test of 12 testers for 14 days.

**Verdict.**
- **Go** for Play internal testing once P1-1 is fixed.
- **No-Go** for a public production release until a closed test produces retention evidence and the scope is narrowed.

| Dimension | Score |
|---|---|
| Business Potential | 3 |
| Product-Market Fit Potential | 3 |
| Technical Quality | 7 |
| UI/UX Quality | 6 |
| Security and Privacy | 8 |
| Behavioural Design | 6 |
| Retention Potential | 4 |
| Publication Readiness | 5 |

---

## 2. Product Viability (Founder)

**Problem.** People who want to change a habit, and who respond to stakes, lack a commitment device that bites. Pure trackers are easy to ignore. Commitment devices with money attached, such as stickK or Beeminder, have real friction.

**Audience.** Young adults, especially in India (the never-lock list includes UPI and Indian banking apps; `lib/domain/block_list.dart:21-34`), who like the anime "System / leveling" aesthetic and lose time to short-video apps and games.

**Differentiation.** The lock is real. Unlike a reskinned task list, failing the day locks the user's chosen apps. That is the only material differentiator. "Level up your life" habit RPGs are common, and the anime-System sub-genre is crowded [INFERENCE].

**Monetisation.** None is designed. There is no paywall, subscription or IAP, and the app has no network access. A future subscription (extra Systems, custom quests, accountability partners) is plausible but untested.

**Business risks.**
1. A punishment-centred product tends to see high early churn: users who fail early uninstall to escape the lock [INFERENCE].
2. Play may question a specialUse foreground service plus usage access plus overlay (section 8).
3. The look is derivative of an existing anime franchise (section 8, IP).
4. The only evidence is the owner. `progress.md:27` reports day 8 of 30 with "2 of 21 days toward the Gate". If accurate, that is a low clear rate in the live period [INFERENCE; self-reported, unverified].

**Recommendation: narrow.** Continue only as a Focus-only, single-progression product, and only through a closed test that measures day-7 and day-30 retention and the clear rate. Do not build more RPG content until that data exists.

---

## 3. Audience and Problem-Solution Fit

- **Fit with the stated goal.** PROJECT.md sets one trial question: does a real penalty make habits more reliable without making the user quit? The code answers it well. It has a dry run, an append-only log, the 30-day report (`lib/app/report.dart`), emergency-exit and outage counts, and honour-confirmation counts.
- **Misfit 1: scope.** PROJECT.md section 3 lists Gates as "deliberately cut for now". They are built anyway, together with Dungeons, Rank Trials, titles, a placement test, three Systems with six ranks each (`lib/domain/system_catalogue.dart`), stats, levels and XP. Two progressions run in parallel: level from XP, and System rank from Dungeons. That adds cognitive load for no trial value.
- **Misfit 2: Focus E, the default core path.** Its only quest item is "No phone after waking (minutes) 20", measured by an in-app timer (`system_catalogue.dart:166-170`). The user must pick up the phone to prove they did not pick up the phone. Only the chosen apps are blocked while the timer runs; nothing detects other phone use. The item is honour-based and self-contradictory [VERIFIED-CODE].
- **Evidence of fit.** None from anyone other than the owner. No interviews, retention data or tester feedback are in the repository.

---

## 4. Technical Architecture (Senior Android engineer)

**Structure.**

| Layer | Path | Notes |
|---|---|---|
| Domain (pure Dart) | `lib/domain/` | `engine.dart` (day closing, penalties, lock scheduling), `penalty.dart`, `systems.dart`, `dungeon.dart`, `config.dart` (all numbers). 97-100% covered. |
| App services | `lib/app/` | `game_service.dart` (1,476 lines; single entry point, serialised `_serial` queue at `:1460-1470`), `penalty_enforcer.dart` (pushes decisions to native), `trusted_clock.dart`, `report.dart`, `notification_planner.dart` |
| Data | `lib/data/` | One JSON document in SharedPreferences (`game_store.dart:32-104`), archives under separate keys, append-only log |
| Platform bridges | `lib/platform/` | MethodChannel `doordie/blocker`; Noop stand-ins for web and tests |
| UI | `lib/ui/` | 9 screens; `onboarding_screen.dart` is 2,608 lines and `penalty_screen.dart` 1,221 |
| Native | `android/.../blocker/` | `WatcherService` (FGS specialUse), `BlockActivity`, `BlockerState` (prefs), `UsageLogic` (pure, JVM-tested), `WakeScheduler` (exact alarms on the elapsed clock), `BootReceiver`, `TimeChangeReceiver`, `TrustedTime` |

**Quest engine.**
- **Day closing.** Days close forward only, oldest first (`engine.dart:174-214`; `game_service.dart:358-484`). Each day is judged against the quest snapshot taken when it was issued (`dungeon.dart:249-267`), so an update cannot change a past quest. This is good.
- **Missed days.** Several days with no app use close in one pass without stacking. Each penalty expires at the end of its own day, and only the last lock is scheduled. Probe F shows 4 failed days, 3 expired penalties, 3 missed locks and 1 lock [VERIFIED-RUN].
- **Debts.** Debts expire and never double (`engine.dart:278-290`; `penalty.dart:93-100`) [VERIFIED-CODE].
- **Settings.** Changes to lock time and rest period take effect after 2 days (`game_service.dart:1093-1099`). Removing an app from the list takes effect after 7 days, and at least one app must stay. This blocks "soften after failing" exploits [VERIFIED-CODE].
- **Clock tampering.**
  - Network time is used when present, otherwise an elapsed-clock anchor (`TrustedTime.kt:38-58`).
  - Dart applies the offset (`trusted_clock.dart:21-41`).
  - Alarms run on `ELAPSED_REALTIME_WAKEUP` (`WakeScheduler.kt`).
  - Setting the clock back cannot reopen a day (`engine.dart:162-163`).
  - Residual risk: on Android 12 and below after a reboot without network, trusted time falls back to `max(device, lastAnchor)` [VERIFIED-CODE].
- **DST.** The full suite passes under America/Santiago and Asia/Beirut (DST at midnight), Australia/Lord_Howe (30-minute DST), America/Havana, Pacific/Kiritimati, America/St_Johns, Europe/Berlin, America/New_York and Asia/Kolkata [VERIFIED-RUN]. A Dart probe confirms that a midnight which does not exist resolves forward to 01:00, so `DayKey.at(0)` stays on the right day [VERIFIED-RUN].
- **Travel west (P1-1).** `_dayOf` pins the open day to the zone it was issued in when the IANA zone id changes (`game_service.dart:58-77`).
  - Probe A (TZ=America/Los_Angeles, game issued in Asia/Kolkata): the 19 Oct quest was judged failed at **11:31 local on 19 Oct**, and a lock was scheduled for 20 Oct 18:00-22:00.
  - After that verdict the local date is 19 Oct but `nextDayToClose` is 20 Oct. `setProgress` and `startTimer` are refused, so the user faces a 12.5-hour dead zone with nothing loggable (probe A2) [VERIFIED-RUN].
  - Nothing in the UI mentions a zone change: `zone_changed` appears only in the log (grep of `lib/ui` finds nothing) [VERIFIED-CODE].
  - The rule "deadline is end of day" is broken for every westward traveller. India to Europe gives a verdict about 4.5 hours early, India to the US about 12.5 hours early.
- **Abandon before 18:00 (P3).** `abandon()` is refused only from 18:00 on a live unfinished day (`game_service.dart:290-322`). At 17:59 it succeeds, and the replacement game starts tomorrow, so that day is never judged (probe B) [VERIFIED-RUN]. The cost is the whole game (rank, XP, log archived), so this is a weak exploit. It is acceptable if documented.
- **Day with no quest counted as cleared (P2-1).** A game started without a dry run issues its first quest tomorrow (`main.dart:188-190`), but the engine still judges the start day. With an empty quest it records `quest_cleared` with 0 XP (`engine.dart:238-271`). The report counts it: probe B2 gives `cleared=1 failed=0 clearRate=100` [VERIFIED-RUN]. The UI queues a "[ QUEST CLEARED ] Reward granted" notice for it (`game_model.dart:674-686`) [VERIFIED-CODE].
- **Screen-time caps.**
  - Caps are measured from usage stats (`UsageLogic.foregroundMillis`, JVM-tested).
  - With no measurement all day and no honour confirmation, the Focus D cap fails the day and issues a 60-minute phone-free penalty plus a lock (probe E) [VERIFIED-RUN]. This matches the rule that an unknown is not a clear.
  - However, usage access withdrawn by the user or an OEM leads to a failure that no notification warns about [INFERENCE].
  - A reading from 20:00 onward stands if the meter fails at judging. An earlier one is excused rather than failed (`game_service.dart:486-575`). That design is fair.

**App blocking reliability.**
- **Mechanism.** The watcher polls `UsageStatsManager.queryEvents` every 700 ms during a lock, every 2 s while a verdict is due, and every 5 s otherwise (`WatcherService.kt:43-67`). It launches `BlockActivity` over a chosen app. There is a gap of up to about 0.7-1.5 s before the block appears, and the debounce is 1.5 s [VERIFIED-CODE].
- **Bypasses the user controls by design.** Settings are never locked, so revoking usage access or overlay, force-stopping or uninstalling ends enforcement. Revocations and force-stops are detected and logged on the next app open (`game_model.dart:157-191`). This is honest and safe: the lock is a speed bump plus accountability, not a cage. Browsers are not covered, as the terms state.
- **Reboot.** `BootReceiver` and `WakeReceiver` call `WatcherService.sync` [VERIFIED-CODE]. On Android 15 the BOOT_COMPLETED FGS ban does not include specialUse (official page). Background FGS starts still need an exemption: an exact alarm "to complete an action that the user requests", a battery-optimisation exemption, or SAW **plus a visible overlay window** (Android 15). The watcher holds SAW but shows no overlay window. Whether starts from the alarm or boot path succeed on Android 15/16 without the battery exemption is **[UNVERIFIED RISK]**. The code does catch the failure, show a notice and log it (`WatcherService.kt:196-211`).
- **OEM killers.** On aggressive skins the watcher can be killed despite the FGS. Outages are measured with a heartbeat and logged [VERIFIED-CODE]. Real behaviour is an [UNVERIFIED RISK].
- **Split-screen and PiP.** The last RESUMED event wins. A chosen app in the second split pane may stay visible [UNVERIFIED RISK].
- **Battery.** A 700 ms usage-events query for up to 4 hours a day costs something, but the watcher stops when idle and relies on exact alarms [INFERENCE].

**Storage and scale.**
- The whole game, including an unbounded log, is re-encoded as one JSON string in SharedPreferences on every change.
- `_honoured` and `_capsExcused` scan the whole log (`game_service.dart:582-597`).
- This is fine for 30 days and degrades over months (P3) [INFERENCE].
- An unreadable save is never silently wiped: there is a startup error screen with export (`main.dart:104-126`) [VERIFIED-CODE].

**Concurrency.** Every mutation goes through `_serial`, and there is a dedicated concurrency test [VERIFIED-RUN].

**Code quality.**
- The domain is clean and small. Comments explain intent.
- Screens are very large: onboarding is 2,608 lines and the notice overlay 1,183.
- `lib/spike/` diagnostics are reachable only in `kDebugMode` (`app_shell.dart:196`). The release binary has no `DOD_TEST_MODE` string, so the click-confirm test hook is compiled out [VERIFIED-RUN].
- Code shrinking is disabled (`android/app/build.gradle.kts`). The APK is 72 MB with three ABIs. The AAB will split per ABI on Play.

---

## 5. UI/UX (Senior UI/UX designer)

**Strengths** (from code and the 4 release screenshots):
- Strong, consistent visual identity: blue System panels, a red Penalty Zone, and monospace terse copy.
- Clear daily-quest hierarchy, with the countdown to judgement and the XP bar on one screen (`release/screenshots/1_quest.png`).
- Reduced motion is respected in 5 places (`disableAnimations`).
- Large-text widget tests exist (`test/ui/large_text_test.dart`).
- Hold targets are 48 dp.

**Problems** (each with a reason):
1. **Cognitive load at first use.** The onboarding runs seven steps: contact, system, placement, quest, apps, rest, terms. The terms list 16 statements, and each must be scrolled 70% into view before "HOLD TO ACCEPT" (`onboarding_screen.dart:2221-2300`). *Usability:* a wall of rules before any value raises first-session abandonment. *Business:* activation is the biggest lever on day-1 retention. Cut the terms to the 5 that change behaviour (lock, time, exits, contest, dry run). Put the rest behind "All rules".
2. **The Penalty tab always shows a large red `00:00:00`**, even with "No penalty is in effect" (`3_penalty.png`; `penalty_screen.dart:77,379`). *Usability:* red alarm styling for a safe state teaches users to ignore red. Show a calm state ("No lock today") without the alarm clock.
3. **Hold-to-confirm has no accessibility action in release builds.** The `Semantics.onTap` exists only when `DOD_TEST_MODE` is set (`hud_kit.dart:259-266`; the same pattern is at `system_frame.dart:322` and `hud_controls.dart:154`) [VERIFIED-CODE]. *Usability:* switch-access and TalkBack users have no semantic action to confirm a quest item. Add a semantic `onLongPress` or a confirm dialog under accessibility.
4. **The block screen has no route to the emergency exit.** It says "Emergency release is in Do or Die · Penalty", but its only button is LEAVE, which goes home (`BlockActivity.kt:140-157`). *Usability:* in a real emergency, the user is stopped at the moment of need. Add "OPEN DO OR DIE" next to LEAVE.
5. **Edge-to-edge on Android 16 (targetSdk 36).** `BlockActivity` sets `statusBarColor` and `navigationBarColor` (no effect when edge-to-edge is enforced) and uses fixed 44/40 dp padding instead of window insets. With 3-button navigation, LEAVE may sit under the navigation bar [UNVERIFIED RISK].
6. **No feedback after a zone change** (section 4). The quest appears frozen for hours with no explanation.
7. **Two progressions shown together** (level/XP and System rank E-S). The rank badge and the XP bar compete. *Business:* unclear progress weakens the reward loop.
8. **Store screenshots** show a personal status bar (notifications, network), third-party app names (Battlegrounds India, YouTube), and a Personality System while the listing says Focus is the core (`release/screenshots/`). Replace them with clean, Focus-first captures.

**Notifications.** Deadline warnings fire 3 h and 1 h before judgement, only while objectives remain, and a Gate warning fires 6 h before expiry (`notification_planner.dart:69-102`) [VERIFIED-CODE]. Exact timing depends on the user granting "Alarms & reminders".

---

## 6. Security and Privacy

| Area | Finding | Label |
|---|---|---|
| Network | No `android.permission.INTERNET` in the merged release manifest (aapt2 dump of the 0.9.2 APK). Data cannot leave the device except through user-initiated share | VERIFIED-RUN |
| Backup | `allowBackup=false` plus data-extraction rules excluding every domain | VERIFIED-RUN (artefact) / VERIFIED-CODE `data_extraction_rules.xml` |
| Components | `WatcherService`, `BlockActivity` and every receiver are `exported=false`. Only the launcher `MainActivity` is exported. No PendingIntent mutability issue (`FLAG_IMMUTABLE`) | VERIFIED-RUN (manifest dump) |
| Secrets | `key.properties` and keystores are gitignored. No passwords or keys in the last 50 commits' trees (git grep). The keystore lives outside the repository | VERIFIED-RUN |
| Signing | AAB signed by "CN=Do or Die" (upload key). The device APK is signed with the Android Debug key and documented as "do not upload" | VERIFIED-RUN |
| Storage | Plain JSON in app-private SharedPreferences. It holds free text (emergency reasons, contest reasons, plans for tomorrow), which is acceptable for on-device data. The export includes this text and goes through the share sheet only on request | VERIFIED-CODE `game_service.dart:1405-1426` |
| Disclosure | A prominent usage-access disclosure with ACCEPT / NOT NOW, non-dismissible, comes before the Settings intent (`usage_disclosure.dart`; `onboarding_screen.dart:1826-1836`) | VERIFIED-CODE |
| Privacy policy | Live at the GitHub Pages URL (fetched 2026-11-08), HTML, effective 7 Nov 2026. It matches the code (data kinds, no internet, deletion, contact) | VERIFIED-RUN (fetch) |
| Abuse against another person | Someone could install it on a partner's or child's phone and lock their apps. Mitigations: the locked person can always use the emergency exit (`game_service.dart:1214-1239`; probe G), Settings and phone, SMS, maps and banking are never locked, the FGS notification is visible, and uninstalling works. Residual risk is low. The 18+ gate is self-attested | VERIFIED-RUN / INFERENCE |
| Input validation | MethodChannel arguments are read defensively with null defaults. Package names pushed to native are filtered against the never-lock list in Dart (`block_list.dart:66-67`) and Kotlin (`MainActivity.kt:218-230`). The two lists differ: Kotlin does not exclude Maps, Contacts or Messaging by package, but Dart drops them, so they are never locked | VERIFIED-CODE |
| Threat model | The main adversary is the user, trying to escape their own lock. All escapes are deliberately available (Settings, uninstall), and the cheaper ones are logged. No remote attack surface (no network) | INFERENCE |

---

## 7. Behavioural Psychology

**What is sound.**
- Commitment device with a precommitted lock time.
- No exercise used as punishment: Fitness penalty is `none` (`penalty_kind.dart`).
- Physical penalties never scale or double.
- Debts expire and never carry over.
- Locks never fall in the sleep window.
- The dry run reduces early wrongful-penalty trauma.
- A near miss at 80% removes all-or-nothing cliff effects.
- The reduction valve (up to 20%, capped at 6 days in 30) helps recovery after illness.
- Contests and the emergency exit preserve autonomy.
- Ranks never go down.
- The Personality penalty is framed as a "plan for tomorrow" (`penalty_screen.dart:1017-1063`), which works as an implementation intention.

**What is risky.**
1. **Punishment is the centre of gravity.** Loss-framed, next-day locks create aversive associations with the app itself. The likely failure mode is "I failed, so I uninstall to avoid tomorrow's lock". PROJECT.md section 6 states this as a fail signal [INFERENCE]. Put the reward side forward: progress visualisation, streak repair, identity copy.
2. **Shaming copy in the report** (`report.dart:255-267`): "escaped more locks than you served", "That was not an accident", "Most of it rests on your word". Other copy: "The System does not negotiate" (terms). Self-criticism after lapses predicts worse recovery than self-compassion [INFERENCE from the habit-relapse literature; not tested here]. Keep the terse voice but drop moral judgement.
3. **The near-miss copy contradicts the streak logic.** The notice says "The streak resets" (`game_model.dart:696`). But the streak counts only `quest_cleared` and `quest_failed` days, so a near miss is skipped and the streak carries on (`status_screen.dart:62-80`; `report.dart:91-100`) [VERIFIED-CODE]. Users are told one rule and shown another, which undermines trust in the System's verdicts. Keep the streak-neutral behaviour, which is the better one, and fix the copy.
4. **Gate at 21 of 30 days.** The first meaningful milestone is about 3 weeks away. Users who fail in week 1 see no reachable goal.
5. **Honour-system inflation.** Most items are self-reported (checkbox, counter, timer). The report shows honour confirmations, which is good. The Focus E item asks for phone use to prove no phone use (section 3).
6. **Safety.** No dangerous exertion, sleep loss or food restriction is used. The exercise penalty is bounded by the day's own quest. The health notice and stop rule are shown. The 5-line written plan is mild. **The penalty system is safe.** It is fair except for the travel-west verdict (P1-1) and the unwarned unmeasured cap (P2-3).

**Disagreement.** The engineer would keep strict penalties as the product's identity. The psychologist would soften them. **Resolution:** keep the lock, because it is the differentiator. Remove shaming copy, make the near-miss copy match the streak-neutral logic, and add one reward that arrives within days 3-7 (for example a first rank badge at 5 cleared days).

---

## 8. Google Play Compliance (not legal advice)

Pages fetched 2026-11-08:

| Requirement | Status | Source |
|---|---|---|
| Target API 36 for new apps and updates from 31 Aug 2026 | Met: targetSdk 36 in both artefacts [VERIFIED-RUN] | https://support.google.com/googleplay/android-developer/answer/11926878 |
| specialUse FGS: manifest type plus `PROPERTY_SPECIAL_USE_FGS_SUBTYPE`, Play Console description, impact, and a **video**. specialUse is for "limited scenarios" and is reviewed | Manifest correct [VERIFIED-RUN]. Console form and video not yet submitted (needs owner). Text drafted in `release/PLAY_RELEASE.md` §5 | https://support.google.com/googleplay/android-developer/answer/13392821 ; https://developer.android.com/develop/background-work/services/fgs/service-types |
| Background FGS start exemptions; Android 15 SAW needs a visible overlay window; BOOT_COMPLETED ban covers dataSync, camera and media types, not specialUse | Code relies on exact-alarm, boot and battery exemptions [UNVERIFIED RISK on Android 15/16] | https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start ; https://developer.android.com/about/versions/15/behavior-changes-15 |
| Exact alarms: SCHEDULE_EXACT_ALARM is denied by default for new installs; USE_EXACT_ALARM is restricted to alarm and calendar apps | Uses SCHEDULE_EXACT_ALARM, checks `canScheduleExactAlarms()`, falls back to always-on watcher [VERIFIED-CODE `WakeScheduler.kt`, `UsageLogic.kt:107-119`]. The release kit says the alarms are for "deadline warnings", but their main use is waking the watcher. Align the wording | https://developer.android.com/about/versions/14/changes/schedule-exact-alarms ; https://support.google.com/googleplay/android-developer/answer/9888170 |
| User Data: usage data and the app inventory are sensitive. The prominent disclosure must be in-app, immediately before consent, with an explicit choice | Met for usage access [VERIFIED-CODE]. Installed apps are listed via `<queries>` LAUNCHER intent, not QUERY_ALL_PACKAGES [VERIFIED-RUN] | https://support.google.com/googleplay/android-developer/answer/10144311 ; https://support.google.com/googleplay/android-developer/answer/11150561 |
| Data safety form required even when nothing is collected; on-device-only processing need not be disclosed; privacy policy required | Answers drafted ("No data collected"), consistent with no INTERNET permission. Policy live [VERIFIED-RUN]. The form still has to be submitted | https://support.google.com/googleplay/android-developer/answer/10787469 |
| Health apps declaration required for every app; Activity and Fitness covers workout apps | Drafted (Activity and Fitness). Not yet submitted | https://support.google.com/googleplay/android-developer/answer/14738291 |
| Personal accounts created after 13 Nov 2023 need a closed test with 12 or more testers opted in for 14 continuous days before production | Not started (`progress.md:209`) | https://support.google.com/googleplay/android-developer/answer/14151465 |
| IP: no "inspired by" exemption; artwork and confusingly similar marks are not allowed | No franchise names, characters or logos found (grep of `lib`, `android`, `docs`, `release`, `web`). Art is original. **Risk [INFERENCE]:** the combination "Penalty Zone", "Daily Quest" with push-ups and squats, blue System windows, Gates and Dungeons, E-S ranks and "Player" closely evokes one franchise. Genre terms are mostly free to use, but "Penalty Zone" is distinctive. Consider renaming it and keeping all franchise references out of marketing | https://support.google.com/googleplay/android-developer/answer/9888072 |
| Android 16 (targetSdk 36): edge-to-edge enforced; predictive back on by default | `BlockActivity` registers `OnBackInvokedCallback` (API 33+) [VERIFIED-CODE]. Inset handling is an [UNVERIFIED RISK] | https://developer.android.com/about/versions/16/behavior-changes-16 |
| 16 KB page size | All arm64 `.so` files have LOAD alignment of 16 KB or more, and zipalign `-P 16` passes [VERIFIED-RUN] | same page |

---

## 9. QA and Testing

**Gates** (run on a scratch copy of `lib`, `test`, `assets`, `pubspec.*`, `analysis_options.yaml`; Flutter 3.47.7, Dart 3.13.5):

| Gate | Result |
|---|---|
| `dart format --output=none --set-exit-if-changed lib test` | Pass: 74 files, 0 changed |
| `flutter analyze` | Pass: "No issues found" |
| `flutter test --coverage` | **260 passed, 0 failed** |
| Line coverage | **82.8%** (7,037 / 8,496) |
| `./gradlew :app:testDebugUnitTest --rerun` | **19 passed, 0 failed** (TrustedTimeTest 6, UsageLogicTest 13) |
| Full Dart suite under TZ=America/Santiago, Asia/Beirut, Australia/Lord_Howe, America/Havana, Pacific/Kiritimati, America/St_Johns; app and domain suites under Europe/Berlin, America/New_York, Asia/Kolkata | All pass |
| `tools/check_release.py` on both 0.9.2 artefacts | OK: versionCode 15, targetSdk 36, allowBackup false |
| Release binary vs HEAD | Strings added in HEAD ("Three near misses in a row", "DELETE OLD TRIALS") are present in the AAB `libapp.so`; `DOD_TEST_MODE` is absent |

**Coverage of important files.**

| File | Coverage |
|---|---|
| `domain/engine.dart` | 100% |
| `domain/penalty.dart` | 99.1% |
| `domain/systems.dart` | 96.8% |
| `domain/dungeon.dart` | 97.0% |
| `app/game_service.dart` | 96.6% |
| `app/penalty_enforcer.dart` | 100% |
| `data/codec.dart` | 96.5% |
| `app/notification_planner.dart` | 76.5% |
| `data/game_store.dart` | 35.8% (the real `PrefsGameStore` is barely tested) |
| `platform/blocker.dart` | 30.5% |
| `platform/notifier.dart` | 0% |
| `platform/usage_meter.dart` | 11.1% |
| `ui/game_model.dart` | 57.9% |
| `ui/widgets/notice_overlay.dart` | 40.4% |
| `domain/placement.dart` | 46.7% |
| `main.dart` | not loaded by any test |

**Not tested at all:** native Android behaviour on a device (blocking, notifications, reboot, OEM kill, Android 15/16 background starts). There are no integration tests in the repository. TestSprite plans exist for the web build only and were not run in this audit.

**Probe tests** (`test/probe/audit_probe_test.dart`, run in the scratch copy only):

| # | Steps | Expected (per stated rules) | Actual | Label |
|---|---|---|---|---|
| A | Focus E game issued in Asia/Kolkata. Load at 19 Oct 11:31 local under TZ=America/Los_Angeles with zone id America/Los_Angeles | 19 Oct judged at local midnight, or an unfair early verdict excused | 19 Oct judged **failed at 11:31 local**; lock scheduled 20 Oct 18:00-22:00 | VERIFIED-RUN |
| A2 | Continue A: `setProgress` on today's item | Progress recordable for the rest of the local day | Refused: `isOpen(today)=false`, `nextDayToClose=20 Oct`; a 12.5 h dead zone | VERIFIED-RUN |
| B | No-dry-run game, live day 2, nothing done, `abandon()` at 17:59 | Refused (restart must not escape a verdict) or documented | Accepted. A new game starts tomorrow and day 2 is never judged | VERIFIED-RUN |
| B2 | New game without dry run; next morning build `TrialReport` | The day with no quest is not a verdict | Logged `quest_cleared`; report `cleared=1, clearRate=100` | VERIFIED-RUN |
| E | Focus D (cap) with no usage access all day, no honour confirmation | Day fails (stated rule), with a warning before midnight | Fails: `quest_failed`, 60 phone-free minutes owed, lock scheduled. No warning mechanism found | VERIFIED-RUN / VERIFIED-CODE |
| F | Personality game, app unopened for 4 days | One lock, no stacking, penalties expire | 4 failed, 3 expired, 3 missed locks, 1 lock; debt 20 pages and 1 plan, due today | VERIFIED-RUN (pass) |
| G | Fitness fail; lock running; 3 releases; then emergency exit with an empty reason | 2 releases allowed; exit always ends the lock | Releases true, true, false; exit true; lock inactive afterwards | VERIFIED-RUN (pass) |
| H | Dart `DateTime` midnight in midnight-DST zones (Santiago 6 Sep, Beirut 29 Mar) | Resolves forward | Resolves to 01:00 of the right day | VERIFIED-RUN (pass) |

---

## 10. Feature Audit

| Feature | Current Implementation | Problem | User Impact | Recommendation | Priority |
|---|---|---|---|---|---|
| Daily quest (System-issued) | Snapshot per day; 3 Systems × 6 ranks (`system_catalogue.dart`) | Focus E item is self-contradictory and honour-only | The core path feels arbitrary | **Improve**: Focus E becomes a measured cap or a scheduled phone-free block locked by the watcher | P2 |
| Judgement and penalty | Pure engine; next-day 4 h lock; expiring debts | Travel west gives an early verdict and a dead zone; a day with no quest counts as cleared | Wrongful penalty; inflated report | **Improve** (P1-1, P2-1) | P1 |
| App lock (watcher + block screen) | Usage-stats polling FGS, exact alarms, never-lock list | Android 15/16 background starts unverified; no route to the app from the block screen | Lock may silently not start; emergency friction | **Improve** + device matrix | P1 |
| Releases (2 × 15 min) | `releaseLock` | none found | — | **Keep** | — |
| Emergency exit | Always available, logged | Reachable only in-app | Friction in emergencies | **Keep**, add a block-screen link | P2 |
| Contest (1 in 14 days) | `contestVerdict` | Unavailable during the travel dead zone (needs `today = judged+1`) | Wrongly judged traveller must wait | **Keep**; auto-excuse zone-change days | P1 (with P1-1) |
| Near miss (80%) | Engine; streak skips near-miss days | The notice says "The streak resets", but the streak does not reset | Users are told one rule and see another | **Improve**: fix the copy and keep it streak-neutral | P2 |
| Reduction valve | 0-20%, 6 days in 30, half XP | — | — | **Keep** | — |
| Dry run (3 days, once per install) | `liveFrom` | Without it, the start day is logged as cleared | Report inflation | **Keep**, fix P2-1 | P2 |
| XP, levels, stats | `progression.dart` | Duplicates System rank; stats have no effect on anything | Noise, cognitive load | **Remove** levels and stats, or merge into rank | P2 |
| Gates, Dungeons, Rank Trials, titles | `dungeon.dart` | Cut by PROJECT.md for the trial; first Gate after 21 cleared days | Complexity before value; distant reward | **Replace** with a near-term milestone (e.g. 5 cleared days to the first badge); keep Dungeons for a later phase | P1 (product decision) |
| Three Systems | Fitness and Personality optional; a `DOD_FOCUS_ONLY` build flag exists | Triples content and test surface | Dilutes the Focus value proposition | **Narrow** to Focus for the closed test (use the existing flag) | P1 |
| Placement test | 1-2 questions per System | Low coverage (46.7%); thin signal | Minor | **Keep** | P3 |
| Screen-time cap measurement | Usage events, honour fallback | Unmeasured all day means failure without a warning | Avoidable failures | **Improve**: notify at 21:00 when a cap is unmeasured and usage access is missing | P2 |
| 30-day report and share card | `report.dart`, `share_card.dart` | Shaming copy; counts the day with no quest | Discouraging; misleading metric | **Improve** | P2 |
| System Check | Permission and health dashboard | — | Good | **Keep** | — |
| Trial log export (JSON/CSV) | Share sheet | — | Good for the trial | **Keep** | — |
| Settings (lock time, rest, apps; delayed effect) | 2-day and 7-day delays | Lock time not choosable in onboarding (default 18:00) | First lock time is imposed | **Improve**: ask in onboarding | P3 |
| Sound and haptics | `fx.dart`, original SFX | — | Adds polish | **Keep** | — |

---

## 11. Growth and Retention

- **Acquisition.** The likely channel is anime and self-improvement communities (Reddit, YouTube Shorts). The share card helps. IP-adjacent marketing is a risk (section 8).
- **First five minutes.**
  - The user does placement, picks apps, grants two special permissions in Settings, reads 16 rules and accepts by holding.
  - There is no quest until tomorrow without a dry run, or a dry-run quest today.
  - There is no early win. Recommended: show today's quest as a "trial run" with a reward for completing it.
- **Day-1 return.** Driven by the 3 h and 1 h deadline warnings (needs notification and exact-alarm grants). Without "Alarms & reminders", notices may arrive up to an hour late.
- **Likely uninstall reasons [INFERENCE].** An early failure leading to fear of a lock; permission friction; the watcher notification; a wrongful verdict (travel); "too much going on".
- **Meaningful engagement.** The real outcome is habit performance off the phone, not time in the app. The app should stay short-session. It mostly does: the quest screen is a single view.
- **Privacy-respecting event plan.** The app has no network, so do not add an SDK.
  1. For the closed test, ask testers to send their in-app log export on days 7, 14 and 30. The data already exists in the log.
  2. Compute D1, D7 and D30 retention from `awakened` plus the daily `progress` and `tick` entries.
  3. Track clear rate, near-miss rate, locks served, releases and exits per lock, contests, blocker outages, abandon events and honour share.
  4. North-star: **live-period clear rate in weeks 3-4 among users still active**, alongside **D30 retention**. Both are needed: retention without a clear rate is time-in-app, and a clear rate without retention is survivor bias.
  5. Add a 3-question exit survey shown in-app on `abandon()`.

---

## 12. Prioritised Roadmap

No P0 is open. The disagreement on P1-1 is recorded under P1-1 below.

### P1

**P1-1: Travel west gives an early verdict and a dead zone.**
- *Problem:* `game_service.dart:58-77` pins the open day to the old zone's midnight when the zone id changes. Probes A and A2 show a verdict 12.5 h early, then progress refused until local midnight. No UI explains it.
- *Severity disagreement:*
  - The engineer argues for P0: the project treats a wrongful penalty as the highest-severity defect, and this one is deterministic.
  - The product manager argues for P1: it affects only westward travellers, and the emergency exit and contest can undo it.
  - *Resolution:* P1, and it blocks the closed test (testers travel).
- *Solution:* when the zone changes during the open day, judge at the **later** of old-zone and new-zone midnight, capped at +X hours (for example 6) to stop manual zone abuse. Or auto-excuse the day: no penalty, no XP, logged `zone_excused`. Show a notice: "Time zone changed. Today's deadline is HH:MM."
- *Impact:* removes a wrongful penalty. *Complexity:* low. *Effort:* 0.5-1 day with tests.
- *Dependencies:* none.
- *Acceptance criteria:* probe A run under TZ=America/Los_Angeles with a Kolkata-issued game yields no `quest_failed` before local midnight (or a logged excusal), and progress is recordable all local day. Existing DST tests still pass.

**P1-2: Run the Play closed test and get real-user evidence (needs owner).**
- *Problem:* there is no external evidence, and the personal account needs 12 testers for 14 days.
- *Solution:* recruit 15-20 testers. Ship the Focus-only build (`DOD_FOCUS_ONLY`). Use the export-based metric plan in section 11.
- *Impact:* unlocks production; gives PMF signal. *Complexity:* medium (people). *Effort:* 3-4 weeks elapsed.
- *Dependencies:* P1-1, P1-3.
- *Acceptance criteria:* 12 or more testers opted in for 14 or more continuous days; D7 and D30 retention and clear rate computed from exports.

**P1-3: Device verification of the blocker on Android 13, 14, 15 and 16, plus the specialUse declaration (partly owner).**
- *Problem:*
  - The watcher's background starts from exact alarms and boot are unverified under Android 15 rules (SAW needs a visible overlay; alarm exemption is "user-requested action").
  - The block-screen insets under Android 16 edge-to-edge are unverified.
  - The specialUse form and video have not been submitted.
- *Solution:* run a device matrix: Pixel on Android 15 and 16 plus one aggressive OEM, each with and without the battery exemption, through reboot, midnight wake, lock start and force stop. If starts fail without the exemption, make the battery exemption mandatory in System Check. Then record the declaration video.
- *Impact:* the core mechanic actually works for the public. *Complexity:* medium. *Effort:* 2-3 days.
- *Acceptance criteria:* a checklist with pass/fail per device. The lock appears within 2 s of opening a chosen app at lock start after reboot. The FGS declaration is submitted.

**P1-4: Narrow scope for the trial and the closed test (product decision, owner).**
- *Problem:* Gates, Dungeons, levels, stats and three Systems bury the one question and add cognitive load, against PROJECT.md section 3.
- *Solution:* ship Focus-only. Hide levels and stats. Replace Gates with an early milestone (first badge at 5 cleared days). Keep the code behind flags.
- *Impact:* activation and clarity. *Complexity:* low (flags exist). *Effort:* 1-2 days.
- *Acceptance criteria:* the onboarding has 5 or fewer steps and the terms 6 or fewer lines. The quest screen shows a single progression.

### P2

| ID | Problem | Solution | Impact | Complexity / Effort | Acceptance |
|---|---|---|---|---|---|
| P2-1 | The start day with no quest is logged as `quest_cleared`, counted in the report and announced (probe B2) | In `_closeDay`, an empty task list yields a `QuestNotIssued` event (no verdict); the report skips it | Honest trial metric | Low / 2 h | Probe B2: `cleared=0`, no notice |
| P2-2 | Hold buttons have no semantic action in release (`hud_kit.dart:259`) | Add `onLongPress` semantics, or a confirm dialog when `accessibleNavigation` is on | Accessibility | Low / 2 h | TalkBack test confirms an item |
| P2-3 | An unmeasured cap fails the day with no warning (probe E) | 21:00 notification when a cap is unmeasured and usage access is missing; System Check badge | Fewer avoidable failures | Low / 0.5 d | Planner test schedules the warning |
| P2-4 | Shaming report copy (`report.dart:255-267`) | Neutral, terse facts plus one next action | Retention after lapses | Low / 1 h | Copy review |
| P2-5 | The near-miss notice says "The streak resets" (`game_model.dart:696`), but the streak skips near-miss days (`status_screen.dart:62-80`) | Change the copy to "The streak holds"; add a test that pins the streak behaviour | Trust in the rules | Low / 1 h | Widget test: near-miss notice text matches the streak after a near miss |
| P2-6 | No link from the block screen to the app (`BlockActivity.kt:150-157`); inset risk | "OPEN DO OR DIE" button; apply `WindowInsets` padding | Emergency access; Android 16 layout | Low / 2 h | Device screenshot with 3-button navigation |
| P2-7 | Focus E quest asks for phone use to prove no phone use | Replace with a watcher-locked scheduled block or a measured cap | Credibility of the core System | Medium / 1 d | Catalogue test |
| P2-8 | Store screenshots: personal status bar, third-party marks, Personality not Focus | Retake clean, Focus-first screenshots | Listing quality and policy hygiene | Low / 1 h (owner) | 4 new screenshots |
| P2-9 | IP proximity ("Penalty Zone" and the franchise-style bundle) | Rename "Penalty Zone"; never reference the franchise in marketing (owner decision) | Takedown risk | Low | Name changed in UI and listing |
| P2-10 | Platform layer untested (`notifier` 0%, `game_store` real class 36%, `main.dart` none) | Add MethodChannel-mock tests and a `PrefsGameStore` round-trip test | Regression safety | Medium / 1 d | Coverage of these files at or above 70% |
| P2-11 | Release kit says exact alarms are for "deadline warnings" (`release/PLAY_RELEASE.md` §5) | State both uses: waking the lock watcher, and warnings | Review consistency | Low | Text updated |
| P2-12 | Penalty tab shows an alarm-red `00:00:00` when nothing is pending | Calm empty state | Clarity | Low / 1 h | Widget test |

### P3

| ID | Item |
|---|---|
| P3-1 | Abandon before 18:00 skips that day's verdict (probe B). Document it, or refuse abandon on any live unfinished day after a chosen hour |
| P3-2 | Whole-save JSON with an unbounded log; linear log scans. Move to SQLite or cap and rotate the log after 90 days |
| P3-3 | Ask for the lock time during onboarding (it is imposed as 18:00 until Settings, with a 2-day delay) |
| P3-4 | Split the 2,608-line onboarding and 1,221-line penalty screen into widgets |
| P3-5 | Check Play for existing apps named "Do or Die" (owner) |

---

## 13. Recommended New Features

1. **Zone-change handling with a visible deadline** (P1-1). It is essential.
2. **Early milestone.** A first badge at 5 cleared days and a "week 1 complete" notice. *Reason:* the reward loop is otherwise 21 or more days away.
3. **Accountability partner, opt-in and offline.** Share a weekly summary image through the share sheet. *Reason:* social commitment raises adherence without adding punishment, and needs no server.
4. **"Plan the lock" weekly review.** Once a week, a 30-second prompt to adjust quest difficulty within the valve rules. *Reason:* PROJECT.md asks for weekly adjustment; this makes it a feature.
5. **Exit survey on abandon.** Three taps, stored locally, included in the export. *Reason:* uninstall reasons are otherwise invisible.

Not recommended: more Systems, more ranks, AI quests, leaderboards or cloud sync before closed-test data exists.

---

## 14. Remove or Replace

| Item | Action | Reason |
|---|---|---|
| Level, XP and stat allocation | Remove or merge into rank | A second progression; stats do nothing |
| Gates and Dungeons in the trial build | Hide behind a flag; replace with an early milestone | Cut by PROJECT.md; distant reward; complexity |
| Fitness and Personality in the closed test | Hide (`DOD_FOCUS_ONLY`) | Focus is the stated core; triple test surface |
| Focus E "No phone after waking" timer | Replace | Self-contradictory, honour-only |
| Report moral verdict lines | Replace | Shaming harms recovery after lapses |
| "Penalty Zone" name | Consider replacing | IP proximity |

---

## 15. Play Publication Readiness

| Item | State |
|---|---|
| AAB built, upload-key signed, versionCode 15, targetSdk 36, 16 KB aligned, allowBackup false | Ready [VERIFIED-RUN] |
| Privacy policy live and accurate | Ready [VERIFIED-RUN] |
| Prominent disclosure for usage access | Ready [VERIFIED-CODE] |
| Data safety form | Drafted, not submitted (owner) |
| Health apps declaration | Drafted, not submitted (owner) |
| FGS specialUse declaration plus video | Drafted text; video not made (owner) |
| Content rating, target audience 18+ | Drafted (owner) |
| Store listing text | Drafted; consistent with code (Dungeon does not double the lock: `engine.dart:298-323`) |
| Screenshots | Need replacing (P2-8) |
| Closed test, 12 testers × 14 days | Not started (owner) |
| Device verification of the blocker | Not done (P1-3) |
| Wrongful-verdict defect | Open (P1-1) |

**Internal testing:** ready after P1-1. **Production:** not ready.

---

## 16. Go / No-Go

**Internal testing: Go** (after P1-1). **Public production: No-Go.**

| Dimension | Score | Reason |
|---|---|---|
| Business Potential | 3 | No monetisation design. Crowded "level up your life" and anime-System niche; the only differentiator is the lock. No user evidence. The owner's own run reports a low clear rate. Capped at 6 without evidence regardless |
| Product-Market Fit Potential | 3 | No one but the owner has used it. Scope exceeds the problem. Focus E core quest is self-contradictory. The lock answers a real need for a stakes-seeking minority |
| Technical Quality | 7 | Clean pure-Dart rules, serialised writes, trusted time, DST-proof across 9 extra zones, 260/260 + 19/19 tests, 82.8% coverage, release artefacts verified. Held back by: travel-west wrongful verdict (P1), a day with no quest counted as cleared, an untested platform layer, Android 15/16 background start unverified, very large UI files |
| UI/UX Quality | 6 | Distinctive, coherent visual system; reduced motion and large text handled. Heavy onboarding (7 steps, 16 rule lines), alarm styling in a safe state, inaccessible hold actions, block screen without an app link, two competing progressions |
| Security and Privacy | 8 | No INTERNET, no backup, nothing exported beyond the launcher, secrets out of git, accurate live policy, proper disclosure. Abuse against another person is mitigated by the always-available exit. Minor: plain-text reflections in the export (user-initiated) |
| Behavioural Design | 6 | Safe penalties (no exercise punishment, nothing doubles, sleep protected, dry run, near miss, valve, contest, exit). Undercut by punishment-centred framing, shaming report copy, near-miss copy that contradicts the streak rule, a first milestone 21 or more days away, and the travel wrongful verdict |
| Retention Potential | 4 | Loss-based loop with no early reward. Permission friction. The likely response to an early failure is uninstalling to avoid the lock. No retention data |
| Publication Readiness | 5 | Artefacts, policy and disclosure ready. Declarations, video and screenshots are not submitted or ready. The closed-test requirement is unmet. Device behaviour on Android 15/16 is unverified. A wrongful-verdict P1 is open |

**"If you were investing your own money, reputation and six months, would you continue in this direction, and what exactly would you change first?"**

I would continue, but not in this direction as it stands. The engineering is trustworthy enough to test the hypothesis. The product has drifted from "does a real penalty change behaviour?" into a content-heavy RPG with no evidence that anyone but its author wants it.

Changes, in order:
1. Fix the travel-west verdict (P1-1) and the day with no quest (P2-1), so the trial data is honest.
2. Ship the Focus-only build with levels, stats, Gates and Dungeons hidden, a 5-line terms screen, and an early milestone.
3. Verify the blocker on Android 15 and 16 devices, then run the 12-tester, 14-day closed test, collecting log exports.
4. Decide at day 30 of the closed test. If fewer than 30% of testers are still active at D30, or the week 3-4 clear rate is below 60%, stop or pivot to a gentler commitment product (accountability partner, no lock).
