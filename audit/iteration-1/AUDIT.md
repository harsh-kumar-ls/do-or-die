# Do or Die: independent audit (iteration 1)

Date: 2026-11-07. Commit audited: `600f5c0` (main, clean tree). Auditor had no prior involvement and read no earlier audit, memory or `.claude/` content other than the role file.

Evidence labels: **[VERIFIED-RUN]** reproduced by running code or inspecting a build artefact; **[VERIFIED-CODE]** read at the cited line; **[INFERENCE]** reasoned, not reproduced; **[UNVERIFIED RISK]** needs a device or pen test. No device test, penetration test or user research was done for this audit.

---

## 1. Executive Summary

Do or Die is a Flutter Android app in which a game-style "System" issues a daily quest (Focus, Fitness or Personality track, ranks E to S). A failed day leads to a next-day "Penalty Zone": the apps the user chose are covered by a block screen for 4 hours from a user-chosen time, plus a System-specific penalty (phone-free block or reading and reflection; Fitness has none). Clearing 21 of 30 days opens a 3-day "Dungeon" that ends in a Rank Trial. Everything is local; the app has no INTERNET permission.

**What is good.** The rules engine is pure Dart, deterministic and well tested. Days close forward only. Writes are serialised. The clock is network-corrected. Quests are snapshotted when issued. The earlier unsafe penalty rules (exercise that doubled and carried over) have been removed from the code. An emergency exit, two releases, a contest path and a 3-day dry run exist. Format, analyze and all 235 Flutter tests pass, as do 16 JVM tests. Line coverage is 81.9%.

**What blocks it.**
1. **P0. The release artefacts in `dist/` are not the audited code.** `DoOrDie-0.9.0.aab` and `-device.apk` were built before the safety fixes but carry the same version code (13) as the current code. Their compiled Dart contains the old carry-over penalty (`carried_over`). It lacks the expiry rule, the 18+ gate and the health notice. Their manifest has no `allowBackup="false"`. Yet `release/PLAY_RELEASE.md` tells the owner to upload that AAB, and the Data safety answers it gives would then be untrue. [VERIFIED-RUN]
2. **The commitment can be softened after failing without that showing in the report.** Changing the rest period on a failing evening shrinks the next day's 4-hour lock to 30 minutes (probe 1). Switching System on a failing evening deletes that day's System penalty (probe 2). Abandoning the game at 23:55 escapes the verdict, and the next game starts with a fresh 3-day dry run (probes 3, 8). [VERIFIED-RUN]
3. **A wrongful-penalty path.** A screen-time cap measured as kept during the day becomes a failure, with a lock and a 60-minute debt, if the meter returns nothing at judging (probe 4). [VERIFIED-RUN]
4. **Enforcement on current Android is unproven.** The watcher depends on background foreground-service (FGS) starts from exact alarms. On Android 15 and later, the SYSTEM_ALERT_WINDOW exemption needs a visible overlay window, which this app never has. Failures are swallowed. No device or integration test covers blocking. [UNVERIFIED RISK]
5. **No evidence of demand.** There are no users, retention data or interviews beyond the owner's own trial.

**Verdict.** Internal testing: **No-Go until P0-1 is fixed.** After that it is a Go for a small internal test. Production: **No-Go.** The P1 fixes, Play declarations and the closed-test requirement come first. As a business: **narrow**, to a Focus-only, evening-doomscroll commitment device, and validate with 5 to 8 real users before building more.

---

## 2. Product Viability

- **Problem:** people lose evenings to short-video and social apps, and they want structure for habits. The problem is real and frequent; the market is crowded.
- **Mechanism:** loss aversion (locks) plus game progression (XP, ranks, Gates). For people who opt in, commitment devices with real stakes are a credible lever [INFERENCE]. The stake is soft here, though. The emergency exit is unlimited and always available ([VERIFIED-CODE] `lib/app/game_service.dart:1061-1080`), so the lock binds through self-honesty and the log, not through force. That is the right safety choice, and it means the product's value is the ritual and the honest record. "Do or Die" overstates the stakes.
- **Monetisation:** none designed. Possible routes: a one-time unlock of the Fitness and Personality packs, or a small subscription for multiple Systems and report history. Both are untested. Without an internet connection there is no server cost, but also no account, sync or analytics.
- **Business risks:**
  - Play policy around app-blocking FGS and usage access (section 8).
  - Trademark and brand closeness to a popular anime ("System", "Player", "Daily Quest", "Penalty Zone", "Gate", "Dungeon", E–S ranks, bracketed window titles) [INFERENCE].
  - A generic name, "Do or Die".
  - Competition from Opal, one sec, ScreenZen, Digital Wellbeing (free, built in), Forest, Habitica and anime-themed habit apps (SelfQuest, RankUp, Level Up, per `COMPETITOR_ANALYSIS.md`, which is unverified).
- **Founder recommendation: narrow.** Keep the Focus System as the product. Freeze the Fitness and Personality packs: they are mostly honour-system checkboxes, and they carry health and embarrassment risk. Prove the owner's 30-day trial and a 5 to 8 person test before any further scope.

## 3. Audience and Problem-Solution Fit

| Segment | Fit | Evidence |
|---|---|---|
| Young adults (18–30) who doomscroll in the evening and like game aesthetics | Strongest fit: user-chosen lock time defaults to 18:00, caps measured from usage access, phone-free blocks | Persona "Maya" in SYSTEMS_PRD, hypothesis only |
| Fitness beginners | Weak: quests are honour checkboxes and counters; no sensor verification; Fitness failures cost only a lock on unrelated apps | `lib/domain/system_catalogue.dart:30-95` |
| "Quiet achievers" (Personality) | Weak and risky: social tasks ("greet someone new", "lead a meeting") cannot be verified, and failing them leads to a punishment | `system_catalogue.dart:107-160` |

There is no real-user evidence in the repository: no retention data, no interviews, no paying users. The screenshots show the owner on "DAY 8 / 30". Per the rubric, Business and PMF are capped at 6. They are scored lower (section 16).

## 4. Technical Architecture

**Layout.**
- `lib/domain/`: pure rules: engine, penalty, scheduler, Systems, Dungeon, catalogue, placement, config.
- `lib/data/`: one JSON document in SharedPreferencesAsync, plus append-only archives.
- `lib/app/`: GameService (the single mutation entry point, serialised by a future queue), PenaltyEnforcer, notification planner, trusted clock, report.
- `lib/platform/`: method-channel bridges.
- `lib/ui/`: screens and the GameModel ChangeNotifier.
- Android native (Kotlin): WatcherService (specialUse FGS polling UsageEvents every 0.7 s while busy, 5 s while idle); BlockActivity (a full-screen activity launched over a locked app); BlockerState (SharedPreferences); WakeScheduler (exact alarms at 00:00:10 and one minute before a lock); BootReceiver; TrustedTime (network clock, or a monotonic anchor).

**How a day works.**
1. `GameService._tick` (`game_service.dart:303-415`) runs at start, on resume and every 30 s while the app is open. It closes each unjudged day oldest-first through `QuestEngine.closeDaysBefore` (`lib/domain/engine.dart:166-331`).
2. A failed day schedules the next day's lock with `LockScheduler._scheduleAt` (`lib/domain/penalty.dart:257-285`), creates a debt that expires at the end of the next day, and logs everything.
3. `PenaltyEnforcer.sync` (`lib/app/penalty_enforcer.dart:40-106`) pushes the package list, the lock window, the focus window and the first unjudged day to native code.
4. The verdict only happens in Dart. If the app is not opened, the native side marks the day as needing judgement, and the first time a locked app is opened it redirects to Do or Die instead (`WatcherService.kt:117-123`).

**Strengths** [VERIFIED-CODE]:
- Forward-only day closing (`engine.dart:184`).
- Quest snapshots on issue (`dungeon.dart:229-247`), so a day's quest never changes after it starts.
- Serial queue against lost writes (`game_service.dart:1275-1286`).
- A late verdict shortens a lock but never extends it (`penalty.dart:278-283`).
- A timer is credited only up to midnight or the floor deadline.
- A time-zone pin stops westward travel from extending a deadline (`game_service.dart:55-62`).
- An unreadable save is never overwritten silently (`lib/main.dart:93-115`).
- Native pure logic is unit tested.

**Defects and risks.**
- **Stale release artefacts.** P0-1, section 15. [VERIFIED-RUN]
- **Softening edits after failing.** Rest-period edits apply immediately to the next scheduled lock, and the UI allows a 30-minute waking window (`lib/ui/screens/settings_screen.dart:62-80`; `penalty.dart:264-277` clamps the lock to the waking window). [VERIFIED-RUN, probe 1]
- **Penalty kind taken from the System active at judging, not the day's System.** `game_service.dart:345` uses `penaltyKindFor(sys?.active)`, and `chooseSystem` changes `active` immediately (`dungeon.dart:190-197`). [VERIFIED-RUN, probe 2]
- **Unmeasurable cap equals failure.** `game_service.dart:441-458` deletes the day's reading when the final measurement is null, unless the user confirmed it on the honour system. That confirmation is only possible while the meter is unavailable during the day. [VERIFIED-RUN, probe 4]
- **Background FGS starts.**
  - `WatcherService.startIfAllowed` (`WatcherService.kt:192-201`) catches the exception and returns false. When that happens from an alarm, nothing is shown to the user or logged until the app is next opened. It is logged then by `GameModel._watchBlocker` (`lib/ui/game_model.dart:168-199`).
  - The relevant exemptions are: an exact alarm "to complete an action that the user requests", BOOT_COMPLETED and MY_PACKAGE_REPLACED receivers, and SYSTEM_ALERT_WINDOW plus a visible overlay window on Android 15.
  - The midnight alarm is not obviously user-requested. [UNVERIFIED RISK]
- **The verdict depends on the Flutter UI running.** There is no headless judging. If the user opens neither Do or Die nor a locked app, nothing is judged. That is acceptable. But each midnight the watcher starts with its persistent notification and polls every 0.7 s until the app is opened, even on days with no penalty (`UsageLogic.kt:82-94`, `BlockerState.kt:140-144`). Battery and UX cost. [VERIFIED-CODE]
- **Storage growth.** The whole game, including an unbounded log, is re-serialised on every change (`lib/data/game_store.dart:34-36`). The report, contest and exit counters scan the whole log. Fine for 30 days; it degrades over months. [INFERENCE]
- **Trusted time on Android 12 and below, or without a network fix:** after a reboot, `max(device, anchor)` trusts a forward-moved device clock (`TrustedTime.kt:38-42`). The user can then move the clock forward to end a lock. Low impact. [VERIFIED-CODE]
- **Scheduler edge.** A lock time chosen after midnight but inside a night owl's waking hours moves to the morning (probe 6). [VERIFIED-RUN]
- **Protected-app lists differ between native and Dart.** Google Maps is listed in the picker (native `protectedPackages`, `MainActivity.kt:211-223`, omits it) but is silently dropped by the Dart `neverBlockPackages` (`lib/domain/block_list.dart:5-17`). [VERIFIED-CODE]
- **Release size.** No code shrinking (`android/app/build.gradle.kts`, documented reason); the APK is 72 MB with three ABIs. The AAB delivery split mitigates this on Play. [VERIFIED-RUN]
- **Known blocking gaps.** These are inherent to a usage-access blocker:
  - Picture-in-picture video keeps playing after the block screen sends the user home. [UNVERIFIED RISK]
  - Browsers reach the same services; this is disclosed in the terms.
  - Split screen: the block shows only when the locked app's activity resumes. [UNVERIFIED RISK]
  - A force stop kills the watcher until the app is reopened; this is logged.
  - Revoking usage access or overlay in Settings disables the lock; this is logged on the next open.
  - Uninstalling ends everything. No device-admin is used, which is correct.

## 5. UI/UX

Evidence: `release/screenshots/*.png` (read), widget code, palette contrast computed. No device session.

- **Visual identity:** strong and consistent. A dark HUD with System blue, Penalty red and Dungeon crimson and gold, terse copy, original sigils and sounds. Quest rows are clear: counters (+1/+5 with undo) and hold-to-confirm checkboxes.
- **Penalty tab with no penalty** (screenshot 3) shows a large `00:00:00` and "NO LOCK TODAY" over two-thirds of an empty screen. A zero countdown reads as "something is running". Show the next possible lock time and the rules instead.
- **Small type.** There are 100+ uses of 9–11 px monospace with wide letter-spacing (e.g. `Hud.mono(9`: 19 places; `Hud.mono(10`: 39; `Hud.mono(11`: 41). The native block screen badge uses 9 sp. No test covers 200% text scale. Penalty-palette dim text on the void background has a contrast ratio of 4.49:1, just under WCAG AA for small text. [VERIFIED-CODE plus computation] Reduced motion is respected in the animated widgets (`disableAnimations` checks in `system_window.dart`, `decode_text.dart`, `notice_overlay.dart`).
- **Onboarding** is long: contact, System, placement, quest preview, apps and permissions, rest period, terms with forced reading, 18+, hold to accept, registered. That is good for informed consent, but the time to first value is long, and the lock time cannot be chosen during onboarding (it defaults to 18:00 and is changed in Settings).
- **Daily friction.** Every day, the first time a locked app is opened after midnight it bounces to Do or Die, even when nothing is owed. The "Penalty Zone watcher" notification appears every night (sections 4 and 11). Users will read this as the app malfunctioning.
- **Copy:** consistent System voice with no exclamation marks. "The System does not negotiate" and "Partial completion is failure" are on-brand but punitive (section 7).
- **Store screenshots** are outdated: they show the Personality System while the listing calls Focus the core. They also show a real status bar with personal notification icons and third-party app names (YouTube, Battlegrounds India).

## 6. Security and Privacy

- **Data minimisation is excellent** [VERIFIED-RUN, `aapt2 dump permissions`]: no INTERNET permission, no accounts, no analytics. Components are non-exported except the launcher activity and the AndroidX ProfileInstallReceiver, which is the standard permission-guarded one. Package visibility uses `<queries>` for launcher and home intents, not QUERY_ALL_PACKAGES.
- **Backups.** Current code sets `allowBackup="false"` and has `data_extraction_rules.xml`. The **shipped artefacts do not** (P0-1). The privacy policy (`docs/privacy-policy.html`, in-app `PrivacyScreen`) says the data is excluded from backups. That claim is false for the build that the release kit says to upload.
- **Sensitive content.** Reflections ("why I failed") and emergency-exit reasons are stored in plain text and exported in full to the share sheet in JSON or CSV. This is acceptable for local data, but the export screen should warn that the file contains personal reflections.
- **Secrets:** `android/key.properties` is git-ignored [VERIFIED-RUN `git check-ignore`]. The keystore is outside the repo.
- **Abuse against another person.** Locking someone else's phone needs physical access, granting two special permissions in Settings, and the 18+ terms. The holder of the phone can always use the emergency exit and Settings. Calls, SMS, launcher, Settings and some Indian banking apps can never be locked. The coercion potential is low. Bank, authenticator and ride-hailing apps from other countries can be locked; the banking list is India-only (`block_list.dart:21-34`). [VERIFIED-CODE]
- **Threat model (self-tamper).** These are all logged and are acceptable for a self-binding tool: clock changes (mitigated), force stop (logged), permission revocation (logged), uninstall (not mitigated, correctly). Softening edits (probes 1–3, 8) are not visible in the report: the report does not read `sleep_changed`, `lock_start_changed`, `system_switched`, `reduction_set`, `block_app_removed`, `cap_unmeasured` or `penalty_expired` (`lib/app/report.dart` event set). [VERIFIED-CODE]

## 7. Behavioural Psychology

- **Safety of penalties (current code)** [VERIFIED-CODE]:
  - Exercise is never used as a punishment in Fitness (`lib/domain/penalty_kind.dart:10-15`).
  - The legacy exercise penalty is bounded by the day's own quest (`penalty.dart:43-45`).
  - Unpaid work expires (`engine.dart:254-266`).
  - Locks never run in the rest period.
  - A health notice, a stop rule and an 18+ gate are shown before acceptance.
  - None of this is in the shipped AAB (P0-1).
- **Fairness:**
  - The dry run, the contest (1 per 14 days), two releases, the emergency exit and the reduction valve (−20%, at most 6 days in 30) are good relapse and recovery tools.
  - "Partial completion is failure" plus a binary verdict means a 9/10-pages day is punished like a zero day. That is the main frustration driver [INFERENCE]. Consider "minimum viable day" credit, for example 80% avoids the lock but earns no XP.
- **Reinforcement balance:**
  - Cleared days earn XP, but the stats do nothing in V1; the UI dims them and makes no promise.
  - Gates need 21/30 cleared days. That is a good, forgiving streak design (not "never break the chain"), and ranks never drop.
  - The punitive side is heavier: the copy and colour shift, the double lock on a failed Dungeon floor (8 h), and doubled reading or phone-free penalties.
- **Risky quests:**
  - Personality social tasks paired with punishment can increase social anxiety for exactly the target persona [INFERENCE].
  - Fitness rank A and S quests (5–8 km, 60 push-ups) are fine as voluntary goals but should never be gated by a penalty.
  - The reflection penalty ("why did you fail", 5 lines) can become rumination. Reframe it as "what will you change tomorrow".
- **Disagreement (PM vs psychologist):** the PM wants harder stakes for credibility; the psychologist wants softer. **Resolution:** keep the soft exit (safety and Play), and make the stakes informational instead of forceful. The report should honestly show exits, releases and softening edits, and the user should pre-commit to a weekly review.

## 8. Google Play Compliance (with URLs)

Not legal advice. Pages fetched 2026-11-07.

| Area | Requirement (official page) | Status in repo |
|---|---|---|
| FGS declaration | Apps targeting 14+ must declare each FGS type in App content: describe the function, the user impact if deferred, and give a video link; specialUse is for "limited scenarios"; all types are reviewed. https://support.google.com/googleplay/android-developer/answer/13392821 ; manifest property reviewed in Console: https://developer.android.com/develop/background-work/services/fgs/service-types | Manifest correct (`AndroidManifest.xml:40-47`). Declaration text drafted in `release/PLAY_RELEASE.md` §5. Video not made. **needs_user** |
| Background FGS start | Exemptions: exact alarm for a user-requested action; BOOT_COMPLETED / MY_PACKAGE_REPLACED; SYSTEM_ALERT_WINDOW **and a visible overlay window** on Android 15. https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start | The app has no overlay window, only an Activity. The midnight wake is not clearly user-requested. **Risk (P1-4)** |
| Background activity start | Allowed when the user granted SYSTEM_ALERT_WINDOW. https://developer.android.com/guide/components/activities/background-starts | OK (the block screen relies on this) |
| Prominent disclosure | In-app, shown in normal use, immediately before the consent request, affirmative consent, not only in the privacy policy; app inventory is personal and sensitive data. https://support.google.com/googleplay/android-developer/answer/10144311 | Present before the Usage-access settings page in onboarding and System Check (`lib/ui/widgets/usage_disclosure.dart`). Mentions the installed-app list. OK |
| Sensitive permissions | Must serve core functionality as promoted in the listing; direct users to system settings for special permissions; app inventory never sold or shared. https://support.google.com/googleplay/android-developer/answer/9888170 | OK. The listing promotes locking. Usage access and overlay are requested via Settings intents |
| Exact alarms | Policy article not retrieved (the URL tried returned the Policy Deadlines page). The summary of 9888170 indicates USE_EXACT_ALARM is restricted to alarm, timer and calendar apps, and SCHEDULE_EXACT_ALARM is user-granted. | Uses SCHEDULE_EXACT_ALARM (user-granted), which fits that. Verify in the Console. Unverified |
| Health apps declaration | Every app must complete it, including testing tracks; "Activity and Fitness" category exists. https://support.google.com/googleplay/android-developer/answer/14738291 | Drafted. **needs_user** |
| Data safety | Required even with no data; "collect" means transmitting off device; on-device processing is not disclosed. https://support.google.com/googleplay/android-developer/answer/10787469 | "No data collected" is correct for the current code. The backup statement is untrue for the shipped AAB (P0-1) |
| Target API | New apps and updates must target API 36+ from 31 Aug 2026. https://developer.android.com/google/play/requirements/target-sdk | targetSdk 36 [VERIFIED-RUN aapt2]. OK |
| New personal accounts | Closed test with at least 12 testers opted in continuously for 14 days before production. https://support.google.com/googleplay/android-developer/answer/14151465 | Noted in the kit. Not started. **needs_user** |
| Target audience, privacy policy | Declare the target age group; a privacy policy link is required in the listing and in the app; content rating required. https://support.google.com/googleplay/android-developer/answer/9859455 | 18+ planned; the privacy policy is in the app. The public URL's availability was not checked. **needs_user** |
| IP | Infringement covers confusingly similar marks and artwork from comics and TV, including modified copies; use original content. https://support.google.com/googleplay/android-developer/answer/9888072 | Art, sound and fonts appear original (fonts are OFL). No anime names in code. Vocabulary ("Penalty Zone", "System", "Player", "Gate", "Dungeon", E–S ranks) closely echoes one franchise [INFERENCE]: low legal risk for generic words, moderate review and brand risk. Screenshots show third-party marks |

## 9. QA and Testing

**Gates.** Run on a byte-identical scratch copy of `lib/`, `test/`, `assets/` and the pubspec files. The JVM tests ran in `android/`; the tree stayed clean.

| Gate | Result |
|---|---|
| `dart format --output=none --set-exit-if-changed lib test` | Pass: 72 files, 0 changed |
| `flutter analyze` | Pass: no issues |
| `flutter test --coverage` | **235 passed, 0 failed** |
| Line coverage (lcov) | **81.9%** (6731/8216 lines) |
| `./gradlew :app:testDebugUnitTest` (forced rerun) | **16 passed, 0 failed** (TrustedTimeTest 6, UsageLogicTest 10) |

**Coverage of important files:**

| File | Coverage |
|---|---|
| `domain/engine.dart` | 100% |
| `domain/penalty.dart` | 99.1% |
| `app/game_service.dart` | 98.6% |
| `domain/systems.dart` | 96.8% |
| `domain/dungeon.dart` | 96.7% |
| `domain/block_list.dart` | 94.1% |
| `app/penalty_enforcer.dart` | 100% |
| `app/notification_planner.dart` | 76.5% |
| `ui/game_model.dart` | 58.4% |
| `ui/widgets/notice_overlay.dart` | 40.4% |
| `domain/placement.dart` | 46.7% |
| `ui/screens/penalty_screen.dart` | 71.6% |
| `platform/blocker.dart` | 31.0% |
| `platform/notifier.dart` | 0% |
| `ui/screens/app_picker_screen.dart` | 0% |
| `main.dart` | not loaded by any test |

**Not covered by any automated test:** native blocking on a device, reboot, force stop, Doze, OEM battery killers, background FGS start on Android 14/15/16, notifications, PiP and split screen. TestSprite tests the web build only, which has no blocking. These need the device checklist and an instrumented test.

**Probe tests.** The file is `test/audit/probe_test.dart` in the scratch copy; the repository was not modified. Run: 2 passed, 7 failed. Each failure is a finding.

| # | Steps | Expected | Actual | Finding |
|---|---|---|---|---|
| 1 | Focus E, live. Day 1 quest undone. At 22:00 set rest period 07:30–07:00. Next day 06:00 tick | Lock 240 min, as the terms promise; an edit can't soften a penalty after failing | **Lock 30 min, clamped=true** | P1-1 |
| 2 | Focus E, day 1 undone. At 22:00 `chooseSystem(fitness)`. Next day tick | Day 1's Focus penalty (60 phone-free min) owed | **No debt** (Fitness owes none) | P2-1 |
| 3 | Focus E, day 1 undone. At 23:55 `abandon()` | Refused, or the day judged first | **Accepted**; no verdict ever issued | P2-2 |
| 4 | Focus D (cap 60). 21:00 meter reads 10 min, kept. Meter returns null at judging | Not failed (an unknown is not a failure) | **Failed; lock 240 min; 60-min debt** | P1-2 |
| 5 | Scheduler: 480-min Dungeon lock, start 18:00, rest 23:00–07:00 | Inside waking hours | 15:00–23:00, pass | none |
| 6 | Scheduler: rest 01:00–09:00, lock time 00:30 (awake) | Starts 00:30 | **Moved to 09:00 next morning** | P3-1 |
| 7 | `reflectionAccepted("a a a a\n…x5")` | Rejected | **Accepted** | P3-2 |
| 8 | New game, 2 days, abandon, Awaken again | No second dry run | **Fresh 3-day dry run** (liveFrom = +3 days) | P2-2 |
| 9 | Focus E, app not opened for a full day | Missed lock logged, no retroactive lock | QuestFailed, LockMissed; next lock at 18:00; pass | none |

**Artefact inspection** [VERIFIED-RUN]:
- `aapt2 dump` of `dist/DoOrDie-0.9.0-device.apk`: versionCode 13, target 36, min 24, no INTERNET, no `allowBackup` attribute (so backup defaults to on).
- `base/lib/arm64-v8a/libapp.so` from the AAB contains `carried` (the `carried_over` log type of the old doubling rule). It contains none of `penalty_expired`, `I AM 18 OR OLDER`, `not a medical device` or `LOCK STARTS`.

## 10. Feature Audit

| Feature | Current Implementation | Problem | User Impact | Recommendation | Priority |
|---|---|---|---|---|---|
| Awakening onboarding | 8+ steps, forced-read terms, 18+, hold to accept | Long; no lock-time choice | Drop-off before first value | Improve: shorten, ask lock time in the terms step | P2 |
| Systems (Focus/Fitness/Personality) | Catalogue of quests per rank; switching allowed | Fitness and Personality are honour checkboxes; README and PRD disagree on switching | Scope and support cost; weak verification | Replace: Focus core only; packs later | P2 |
| Placement test | 1–2 self-report questions | Focus can prefill from usage data, otherwise self-report | Mis-placement | Keep | P3 |
| Daily quest + snapshot | Issued once per day, fixed | Binary verdict | Near-miss days punished fully | Improve: partial-credit threshold | P2 |
| Screen-time caps | Usage events, measured on device | Unknown at judging means failure (probe 4) | Wrongful penalty | Improve (P1-2) | P1 |
| Phone-free block | In-app timer that locks chosen apps | Focus E label "after waking" is not enforced | Mild confusion | Improve label | P3 |
| Verdict and lock | 4 h from the chosen time; releases; emergency exit | Rest-period edit shrinks it (probe 1); FGS start risk | Mechanic integrity | Improve (P1-1, P1-4) | P1 |
| System penalty (pages, reflection, focus block) | Honour taps and 5-line reflection | Junk accepted; rumination framing | Low value | Improve: reframe as a plan for tomorrow | P3 |
| Contest | 1 per 14 days with a reason | Good | Trust | Keep | none |
| Dry run | 3 days per game | Repeats after abandon (probe 8) | Loophole | Improve: once per install | P2 |
| Gates and Dungeons | 21/30 opens a Gate; 3 floors; double lock on failure | Doubled 8 h lock is harsh | Possible quit after a failed trial | Improve: cap the Dungeon lock at the normal lock | P2 |
| XP, levels, stats | XP on clear; stat points with no effect | Points do nothing | "Fake" progress | Remove stat points or make them matter | P3 |
| 30-day report and share card | Calendar, honesty section, 1080x1350 image | Omits softening edits and expired penalties | Dishonest self-assessment | Improve (P1-1 acceptance) | P1 |
| Notifications | 21:00 and 23:00 warnings, morning, lock engaged | Fire inside the rest period if bedtime is early | Sleep disturbance | Improve: respect the rest period | P3 |
| System Check | Permissions, battery, auto time, watcher | Good | Reliability | Keep | none |
| Daily verdict redirect | Watcher runs from midnight; first locked-app open bounces | Runs even with no penalty | Battery and annoyance | Improve (P2-3) | P2 |
| Export (JSON/CSV) | Share sheet | Includes reflections without a warning | Privacy surprise | Improve: warning | P3 |
| Sounds and haptics | Original SFX | none | none | Keep | none |

## 11. Growth and Retention

- **Acquisition:** anime-aesthetic communities and "dopamine detox" audiences on TikTok, Reddit and YouTube. The share card is the only built-in loop. The name is not searchable.
- **First five minutes:** a dramatic Awakening, then permissions, then 3 dry-run days. The "aha" (the first lock) arrives on day 4 at the earliest. Show a 30-second simulated lock during onboarding so users trust it.
- **Day-1 return:** the morning notification plus the verdict redirect. The redirect works, but it is coercive when nothing is owed.
- **Likely uninstall reasons** [INFERENCE]:
  - The first real lock after a near-miss day.
  - A nightly persistent notification.
  - Locks that fail to engage on aggressive OEM skins.
  - Too many steps.
- **Meaningful vs artificial engagement:** time in the app should be low. The real outcome metrics are minutes on locked apps, phone-free minutes and days cleared. The report already measures the right things; keep XP from rewarding app opens.
- **Privacy-respecting event plan:** there is no network, so measure locally and let testers export voluntarily.
  - Metrics: `day_closed{cleared, items_done/total}`, `lock_started/ended{minutes, release_count, exit}`, `cap_minutes_daily`, `edit_softening{type}`, `blocker_offline{minutes}`, `onboarding_step_reached`.
  - KPIs: D1/D7/D30 active days, the clear rate, median locked-app minutes in week 4 vs week 1, emergency exits per live week, and uninstall survey answers collected by hand from testers.

## 12. Prioritised Roadmap

**P0-1. Release artefacts are stale and contradict the docs.**
- **Problem:** `dist/DoOrDie-0.9.0.aab` and `-device.apk` (versionCode 13) were built before `3b1e422` and `600f5c0`. Their compiled Dart contains the old doubling carry-over penalty. They lack the 18+ gate and health notice, and their manifest does not disable backup. `release/PLAY_RELEASE.md` says to upload this AAB and answers Data safety as if backup were off.
- **Solution:** delete or rename the stale artefacts, bump to 0.9.1+14, rebuild both from HEAD, and add a release check script that runs `aapt2` and greps `libapp.so`.
- **Impact:** prevents shipping the unsafe penalty and a false privacy statement. **Complexity:** low. **Effort:** under 1 hour. **Dependencies:** none.
- **Acceptance:** `aapt2 dump xmltree` shows `allowBackup=false`; `libapp.so` contains `penalty_expired` and `I AM 18 OR OLDER` and no `carried_over`; versionCode is above 13; the release kit names the new file; the owner's test phone runs the new build.

**P1-1. Softening edits after failing.**
- **Problem:** a rest-period change on a failing day shrinks the next lock to 30 min (probe 1). Softening edits are not shown in the report.
- **Solution:** rest-period and lock-time changes take effect only for locks on days after tomorrow, in line with PROJECT.md's edit rule. Enforce a minimum waking window (for example 12 h). Add every softening event (`sleep_changed`, `lock_start_changed`, `system_switched`, `reduction_set`, `block_app_removed`, `cap_unmeasured`, `penalty_expired`) to the report's honesty section.
- **Impact:** keeps the core mechanic credible. **Complexity:** low. **Effort:** half a day. **Dependencies:** none.
- **Acceptance:** probe 1 passes (240 min); a unit test refuses a waking window under 12 h; a report test lists each softening event.

**P1-2. Wrongful penalty when a cap is unmeasurable at judging.**
- **Problem:** see probe 4.
- **Solution:** if the final measurement is null, judge the cap from the last in-app reading taken after 20:00 when one exists. Otherwise mark the item "unmeasured": no lock and no debt, with a `cap_unmeasured` entry shown in the report.
- **Impact:** removes a wrongful-penalty path, which CLAUDE.md classes as the highest-severity defect type. **Complexity:** low. **Effort:** half a day. **Dependencies:** none.
- **Acceptance:** probe 4 passes; existing cap tests still pass.

**P1-3. No device evidence for enforcement.**
- **Problem:** blocking, reboot, Doze, force stop and OEM killers have no automated test, and FGS-start failures are silent (see P1-4).
- **Solution:** an instrumented (androidx.test) test for WatcherService start, BlockActivity launch and the alarm path, plus a written device checklist run on Android 13, 14, 15 and 16, including one aggressive OEM skin, with results committed.
- **Impact:** confidence in the core promise. **Complexity:** medium. **Effort:** 2–3 days. **Dependencies:** devices or emulators. **needs_user:** partly (physical phones).
- **Acceptance:** the checklist is in the repo with per-version pass/fail; the instrumented test runs in CI or locally.

**P1-4. Background FGS start on Android 15+ may fail silently.**
- **Problem:** the SYSTEM_ALERT_WINDOW exemption needs a visible overlay window, and the exact-alarm exemption covers user-requested actions only. `startIfAllowed` swallows the failure.
- **Solution:** on failure, post a high-priority notification ("Lock starts at 18:00: open Do or Die to arm it") and record the failure in BlockerState so the app logs it. Consider a user-visible "arm lock" notification action, which is an explicit user action and an exemption. Verify on Android 15 and 16.
- **Impact:** locks actually engage. **Complexity:** medium. **Effort:** 1–2 days. **Dependencies:** P1-3.
- **Acceptance:** on an Android 15 device with the app swiped away, the lock engages at the chosen time, or the user gets a notification and the outage is logged.

**P1-5. Play declarations and closed test.**
- **Problem:** the FGS specialUse declaration and video, Health apps, Data safety, target audience and content rating are not submitted. The 12-tester, 14-day closed test has not started.
- **Solution:** the owner completes them in Play Console. Record the video on the rebuilt build.
- **Impact:** publication. **Complexity:** low. **Effort:** 1 day plus 14 days of calendar time. **Dependencies:** P0-1. **needs_user:** true.
- **Acceptance:** Console shows App content complete; the closed test has 12+ testers opted in for 14 days.

**P2-1. Penalty kind follows the System active at judging, not the day's** (probe 2).
- **Solution:** store the System with the issued snapshot and take the penalty kind from it.
- **Acceptance:** probe 2 passes. **Effort:** 2 h.

**P2-2. Abandon escapes the verdict, and the dry run repeats** (probes 3, 8).
- **Solution:** when today's quest is incomplete after 18:00, judge the day before archiving (or refuse until the verdict). Allow one dry run per install, with a flag kept outside the save.
- **Acceptance:** probes 3 and 8 pass. **Effort:** half a day.

**P2-3. Nightly watcher and redirect when nothing is owed.**
- **Solution:** native code knows from the last sync whether today's quest was already complete. Only redirect, and keep the FGS running, when the last-known state is "incomplete". Otherwise, judge on the next open.
- **Acceptance:** with a cleared day, no watcher notification appears after midnight, and opening a locked app is not redirected. **Effort:** 1 day.

**P2-4. Accessibility.**
- **Solution:** raise the minimum text to 12 sp (14 for body), test at 200% text scale, and keep dim text at 4.5:1 or above.
- **Acceptance:** a golden or widget test at a 2.0 text scaler shows no overflow; a contrast check passes. **Effort:** 1–2 days.

**P2-5. Narrow the scope.**
- **Solution:** make Focus the only System for testers and hide the packs behind a flag. **needs_user:** product decision.
- **Acceptance:** the Awakening offers Focus only in the tester build.

**P2-6. Binary failure and the Dungeon double lock.**
- **Solution:** partial-credit threshold; cap the Dungeon lock at the normal 4 h, with the Gate cooldown as the cost.
- **Acceptance:** engine tests for an 80%-done day and for the Dungeon lock length.

**P2-7. Storage scalability.**
- **Solution:** split the log into an append-only store (or a file per month); save state separately.
- **Acceptance:** saving after 5,000 log entries takes under 50 ms in a benchmark test.

**P2-8. Store assets.**
- **Solution:** new screenshots from the Focus build with a clean demo status bar and no third-party app names; check that the privacy policy URL is live. **needs_user:** partly.

**P3 items:**
- Night-owl lock time (probe 6).
- Reflection quality (probe 7): reframe instead of policing.
- Native and Dart protected lists: derive the picker from the Dart list.
- Notifications inside the rest period.
- Focus E label.
- An export warning about reflections.
- TrustedTime after a reboot without a network fix.
- README vs PRD on switching.
- APK size: enable split-per-ABI for sideload builds.

## 13. Recommended New Features

Each item has a usability or business reason.

1. **Lock preview during onboarding.** Trigger a 20-second demo lock over a chosen app. It builds trust and confirms permissions work before the stakes are real.
2. **Lock time chosen during onboarding.** The core "chosen time" promise should be an explicit choice, not a default.
3. **Partial-credit day ("held the line").** For example, 80% or more avoids the lock but earns no XP. This reduces the near-miss rage-quit risk.
4. **Weekly review screen.** It shows minutes on locked apps vs week 1, exits, releases and softening edits. This implements PROJECT.md's weekly review and makes honesty the stake.
5. **Tester feedback export.** One tap shares an anonymised metrics JSON. This is the only way to get retention evidence with no network.

## 14. Remove or Replace

- **Remove stat points** (or make them change play). They do nothing in V1, which undermines trust in progress.
- **Replace the "why you failed" reflection penalty** with a "plan for tomorrow" prompt. It is less ruminative, and honour-based anyway.
- **Freeze the Personality social quests and Rank Trials** for public users. They cannot be verified, and punishing a socially anxious target persona is a risk.
- **Remove the 8-hour Dungeon double lock.** The Gate cooldown is already a cost.
- **Drop the stale `dist/` APKs (0.4.0–0.9.0)** from any distribution path.

## 15. Play Publication Readiness

| Item | Ready? |
|---|---|
| Correct, current signed AAB | **No** (P0-1) |
| targetSdk 36 | Yes |
| FGS specialUse declaration and video | No (needs_user) |
| Usage-access prominent disclosure | Yes (in code) |
| Data safety ("no data collected") | Answer correct for HEAD; false for the shipped AAB's backup claim |
| Health apps declaration | Drafted, not submitted |
| Privacy policy in app and at a public URL | In app yes; URL not verified |
| Target audience 18+, content rating | Drafted |
| Closed test, 12 testers for 14 days (personal account) | Not started |
| Store listing and screenshots | Draft; screenshots outdated |
| Device verification of locks on Android 14/15/16 | No |
| IP review | Assets original; vocabulary close to one franchise; keep the listing free of references |

**Internal testing:** possible as soon as P0-1 is fixed and the FGS declaration is filled. **Production:** not ready.

## 16. Go / No-Go

| Dimension | Score | Reason |
|---|---|---|
| Business Potential | 4 | Crowded screen-time and habit market with free built-in alternatives; no monetisation; generic name; anime-adjacent brand risk; no user evidence (cap 6) |
| Product-Market Fit Potential | 4 | Plausible fit for evening doomscrollers (Focus); weak for the Fitness and Personality packs; single-user trial only, no retention data |
| Technical Quality | 6 | Clean, pure, well-tested rules engine (235 + 16 tests, 81.9% coverage, gates clean). But: stale release artefacts, a wrongful-penalty path, rule-softening loopholes, unproven native enforcement on Android 15+, silent FGS-start failures, no device tests |
| UI/UX Quality | 6 | Distinctive, coherent HUD and copy; reduced motion respected. Many 9–11 px labels, no large-text testing, long onboarding, a confusing empty penalty state, a nightly notification and a daily redirect |
| Security and Privacy | 7 | No network, minimal permissions, non-exported components, local-only data, prominent disclosure. Shipped build contradicts the backup claim; reflections exported without a warning |
| Behavioural Design | 6 | Penalties are now bounded, expire, and have exits, a contest and a dry run (in code, not in the shipped build). Binary verdict, punitive framing, a doubled Dungeon lock and unverifiable social tasks risk frustration and quitting |
| Retention Potential | 4 | A strong daily ritual for the committed; a punishment-led loop with near-miss failures and nightly friction suggests high early churn; no data |
| Publication Readiness | 3 | A P0 is open (the artefact to upload is the unsafe pre-fix build). FGS, Health, Data safety and audience declarations are not submitted. The closed-test requirement has not started. Device behaviour is unverified (cap 7) |

**Go / No-Go.** No-Go for Play upload today, because of P0-1. Go for a sideloaded or internal test once P0-1, P1-1 and P1-2 are fixed. No-Go for production until P1-3 to P1-5 are done.

**"If you were investing your own money, reputation and six months, would you continue in this direction, and what exactly would you change first?"**

Yes, but narrower and only conditionally. I would not fund a three-System RPG. I would fund six months of a **Focus-only evening commitment device**, with the game skin as differentiation, gated on evidence.

First, in this order:
1. Rebuild and replace the release artefact (P0-1), and put the owner's phone on it, so the trial measures the safe rules.
2. Close the softening loopholes and the unmeasurable-cap wrongful penalty (P1-1, P1-2), and surface every softening edit in the report.
3. Prove on Android 14, 15 and 16 devices that locks engage with the app closed (P1-3, P1-4).
4. Put 8–12 real users on a Focus-only build for 30 days, as the closed test, with a voluntary metrics export.

Continue only if week-4 locked-app minutes fall by 30% or more for most testers and at least half are still active in week 4. Otherwise, pivot the mechanic into a lighter screen-time feature, or stop.
