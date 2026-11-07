# Do or Die: independent audit, iteration 1 (baseline)

Date: 2026-11-07. Repository state: `main` at `3b1e422` (version 0.9.0+13). The auditor started with no prior knowledge. Evidence comes only from the repository, from commands run in a scratch copy, and from official Google pages fetched on the day. Project docs were read for intent only.

Evidence labels: **[VERIFIED-RUN]** reproduced by running code; **[VERIFIED-CODE]** read at the cited line; **[INFERENCE]** reasoned, not reproduced; **[UNVERIFIED RISK]** needs a device or pen test. No device test, penetration test or user research was done.

---

## 1. Executive Summary

Do or Die is a Flutter Android app. It issues a daily quest from one of three "Systems" (Fitness, Personality, Focus). A failed day locks apps the user chose, starting at an undisclosed time the next day, and adds a System-specific penalty (reps, reading plus a reflection, or a phone-free block). Clearing 21 of 30 days opens a three-day "Dungeon" that ranks the user up.

The Dart engineering is strong. Rules live as pure Dart in `lib/domain`, all writes are serialised, format and analyze are clean, 211 of 211 tests pass, and line coverage of loaded files is 80.3%. Recent safety fixes hold up in the code: exercise never doubles, carry-over and the stop rule are gone, there is an 18+ gate and a 3-day dry run.

The weak points are the native enforcement layer and the edges around it:

- **P0:** abandoning a game, or a save that cannot be read, leaves the phone's blocker armed. From the next day, every launch of a chosen app is redirected to Do or Die with no game running.
- A lock that starts while a locked app is already open is not enforced until the user leaves that app.
- On Android 7 to 12 (minSdk 24), the "trusted" clock is just the device clock. A time-zone change moves the day boundary on every version.
- Releases are unlimited. A user can release away an entire lock.
- The watcher foreground service runs 24/7, which contradicts the privacy policy and is a Play foreground-service policy risk.
- There is no in-app privacy policy link.
- There are no native or integration tests at all.

No real-user evidence exists beyond the owner's own trial.

**Verdict:** No-Go for public production. Conditional Go for internal or closed testing once P0-1 and the P1 enforcement defects are fixed. Continue, but narrowed (section 16).

## 2. Product Viability

- **Problem:** people know what to do daily but do not do it, and phone apps eat the time. The app combines a commitment device (self-imposed stakes) with game progression.
- **Differentiation:** real app locks as the stake, an unannounced lock start, System-specific penalties and a fixed rank ladder. Competitors in `COMPETITOR_ANALYSIS.md` (research, not verified here) include gamified habit apps and app blockers. Combining a lock with a quest is unusual. The theme is an anime-inspired "System" aesthetic.
- **Monetisation:** none designed. There is no account or backend, so subscriptions, pledges or sync would each need new infrastructure. [VERIFIED-CODE: no INTERNET permission in the merged release manifest]
- **Business risks:**
  1. Play policy exposure for app-interfering behaviour and the specialUse foreground service.
  2. IP proximity to an existing anime (section 8).
  3. Punitive products have high abandonment [INFERENCE].
  4. A single-founder build has no tester pipeline yet. The 12-tester, 14-day closed test is still ahead.
- **Founder recommendation: Narrow.** Focus on the Focus System, where the lock is the habit (phone use) rather than an unrelated punishment, and prove retention with 12 to 20 testers before adding more.

## 3. Audience and Problem-Solution Fit

- **Implied audience:** adults 18 to 30 who like game-style self-improvement fiction, feel they use their phones too much, and want external pressure.
- **Fit:**
  - **Focus System:** strong. Locking social apps directly serves "take your attention back".
  - **Fitness and Personality:** the lock is an arbitrary punishment unrelated to the habit. Their honour-system logging means the stake only works for users who do not cheat themselves, and those users may not need the stake.
- **Evidence:** the only usage evidence is the owner's own trial. The screenshots show "DAY 8 / 30 · PERSONALITY". There is no retention, interview or payment data, so PMF is capped at 6 by rubric, and this audit scores lower.

## 4. Technical Architecture

**How it works**

- `lib/domain/` is pure Dart: the engine judges each closed day.
  - Penalty amounts: `penalty.dart`.
  - Lock scheduling inside waking hours: `LockScheduler`.
  - Systems catalogue: `system_catalogue.dart`.
  - Gates and Dungeons: `dungeon.dart`.
  - Reduction valve: `systems.dart`.
  - Tunables: `config.dart`.
- `lib/app/game_service.dart` is the single mutation entry point. All operations go through `_serial` (game_service.dart:1112), which prevents lost writes.
- `PenaltyEnforcer` pushes state to native through a MethodChannel: blocked packages, the lock window, the focus window, and the first unjudged day.
- Native side (Kotlin):
  - `WatcherService` is a specialUse foreground service. It polls `UsageStatsManager` events every 700 ms while busy and every 5 s while idle.
  - It launches `BlockActivity` over a locked app, or launches `MainActivity` when a day is unjudged (the "judge redirect").
  - `BlockerState` persists everything in SharedPreferences, so it survives process death and reboot (`BootReceiver`).
  - `TrustedTime` uses `SystemClock.currentNetworkTimeClock()` on API 33+.
- The saved game is one JSON document in SharedPreferences, holding the state and an append-only log (`data/game_store.dart`).

**Strengths**

- Clear layering. Domain coverage is 94 to 100%, and `game_service.dart` is at 98.6%.
- Serialised writes, issued-quest snapshots (a quest cannot change after issue), and judged days that never reopen.
- Defensive startup: it never silently wipes a save (`main.dart:87-92`).
- No exported components except the launcher activity [VERIFIED-CODE AndroidManifest.xml].

**Defects and risks**

- **Stale native state after the game ends (P0-1).** `abandon()` archives and clears the save (`game_service.dart:237-248`), but nothing resets `BlockerState`. `penalty_enforcer.dart` has no clear-all path. `main.dart:158` only disposes the model, and onboarding never syncs.
  - `needsJudgement` (`BlockerState.kt:140-146`) becomes true the next day.
  - The watcher then redirects every launch of a chosen app to Do or Die (`WatcherService.kt:94-100`).
  - The same happens when the save cannot be read (`main.dart:87-92` shows `StartupErrorApp` forever).
  - [VERIFIED-RUN probe 1 for the Dart side; native consequence VERIFIED-CODE]
- **First lock in a watcher lifetime misses an app already open (P1-1).** `check()` reads events only from `lastEventQueryAt`, which is set only inside `check()`. It is 0 on a fresh service, so only the last 10 s are read (`WatcherService.kt:76-87`). The idle loop never calls `check()`.
  - If Instagram was opened before the lock starts and stays in front, no ACTIVITY_RESUMED event falls in the window, so no block appears until the user switches app.
  - After a reboot, an update or a force-stop restart, every lock starts in this state.
  - [VERIFIED-CODE]
- **Clock trust (P1-2).**
  - `TrustedTime.networkMillis()` returns null below API 33 (`TrustedTime.kt:15`), so native uses `System.currentTimeMillis()`.
  - `TrustedClock` starts at offset zero and keeps it when there is no network reading (`trusted_clock.dart:14-40`).
  - With minSdk 24, users on Android 7 to 12 can set the clock back before the first open of a day and log yesterday's quest. [VERIFIED-RUN probe 3, 3b]
  - Moving the clock forward past `lockEndsAt` ends a lock natively. [VERIFIED-CODE BlockerState.kt:56-60]
- **Time zone (P1-3).** Day keys come from local `DateTime` (`trusted_clock.dart:22`, `day.dart:5`, `BlockerState.kt:144`). Network time corrects the instant but not the zone.
  - Switching to a western time zone near midnight adds hours to "today" (cheat).
  - Travelling east shortens a day (possible wrongful failure).
  - System Check reads only `AUTO_TIME`, not `AUTO_TIME_ZONE` (`TrustedTime.kt:26-27`).
  - [VERIFIED-CODE]
- **Foreground service runs permanently (P1-4).** It is started on every app open (`MainActivity.kt:30`) and at boot, and never stopped (no `stopSelf`). The idle loop runs every 5 s and writes a heartbeat to prefs every 10 s, forever (`WatcherService.kt:37-50`). [VERIFIED-CODE] Battery cost is [INFERENCE].
- **Enforcer cache.** `PenaltyEnforcer` only resends on change. If native state is altered elsewhere (diagnostics `stopLock` with the screen left open across midnight), the lock is not re-pushed until it changes. Diagnostics is gated only when opened (`app_shell.dart:156-176`). [VERIFIED-CODE, P3]
- **Storage growth.** One year at 10 taps a day gives 5,106 log entries and a 611 KB document, re-encoded in full on each of 4,016 saves. Encoding takes about 5 ms and decoding 27 ms on the dev machine. Acceptable now, but unbounded. [VERIFIED-RUN probe 7]
- **Release build ships the diagnostics spike screen** (`lib/spike/`) with start/stop-lock controls. [VERIFIED-CODE]
- **Dead code:** `recordEmergencyStop()` is never called; `exportLogJson/Csv` are unreachable from the UI. [VERIFIED-CODE]
- **R8 disabled** (`build.gradle.kts`), so the APK is larger and the build is not obfuscated. This is a deliberate workaround for a past crash. [VERIFIED-CODE, P3]

**Blocking reliability matrix** (all native, none tested in the repository)

| Scenario | Behaviour from code | Label |
|---|---|---|
| Permission (usage access or overlay) revoked in Settings | Watcher sees nothing; outage logged when the app is next opened | VERIFIED-CODE / UNVERIFIED RISK |
| Force-stop | Watcher dead until app opened; logged with duration | VERIFIED-CODE |
| Reboot | BootReceiver restarts it (specialUse is allowed from BOOT_COMPLETED on Android 15) | VERIFIED-CODE + doc |
| Uninstall | Total escape (by design) | VERIFIED-CODE |
| OEM battery killers | Mitigated by exemption prompt; not verified | UNVERIFIED RISK |
| Split-screen or PiP (YouTube) | Block screen launched, but a PiP window or background audio may keep playing | UNVERIFIED RISK |
| Browser (instagram.com in Chrome) | Not blocked unless the browser itself is chosen | VERIFIED-CODE |
| Android 15/16 background activity start | Relies on the SYSTEM_ALERT_WINDOW exemption; needs device check per version | UNVERIFIED RISK |

## 5. UI/UX

Evidence: code and the four store screenshots. No device session was run.

**Strengths**

- Distinctive, coherent HUD theme with a strong hierarchy on the quest screen.
- Hold-to-confirm on checkboxes adds honest friction.
- Countdown to judgement, dedicated loading, empty and error states, and terse System copy.
- `disableAnimations` respected in 7 places; 53 `Semantics` wrappers.
- Terms must be scrolled through, with an explicit 18+ confirmation.

**Issues**

1. **Small type.** About 110 text styles are 9 to 11 logical px (`Hud.mono(9|10|11…)`), letter-spaced and monospaced. That is hard to read, especially dim grey on near-black. Reason: legibility and accessibility complaints, and a 1-star risk. [VERIFIED-CODE]
2. **Onboarding is 7 steps** (contact, system, placement, quest, apps, rest, terms), with permission trips to Settings and an Android "restricted settings" workaround. Time-to-first-quest is long for a cold install. Reason: activation drop-off. [INFERENCE]
3. **The hidden lock start** ("THE LOCK WILL BEGIN WITHOUT WARNING", scrambled digits) is a deliberate anxiety device. It works as theatre, but users cannot plan around it (work calls, navigation). Banking and maps are protected, but other work apps are not. [VERIFIED-CODE penalty_screen.dart:356-361]
4. **Store screenshots** carry the developer's personal status bar (carrier, notification icons) and a near-empty Penalty screen ("NO LOCK TODAY"). Weak store conversion. [VERIFIED-RUN: viewed `release/screenshots/1_quest.png`, `3_penalty.png`]
5. **The rest period cannot be changed after onboarding.** `setSleepWindow` has no UI caller. A schedule change means abandoning the game. [VERIFIED-CODE]
6. **The 23:00 "1 hour remains" notice** is fixed and can land inside a user's rest window (`notification_planner.dart:46-47`). [VERIFIED-CODE]
7. **Text scaling is not clamped.** Overflow at large font scales is untested. [UNVERIFIED RISK]

## 6. Security and Privacy

- **Storage:** app-private SharedPreferences. Backup and device transfer are off (`allowBackup=false`, `data_extraction_rules.xml`). There is no INTERNET permission and no third-party data SDKs. [VERIFIED-CODE]
- **Secrets:** `key.properties` and the keystore are git-ignored. No secrets are tracked (`git grep`). [VERIFIED-RUN]
- **Components:** only `MainActivity` is exported. The service, receivers and `BlockActivity` are `exported=false`. MethodChannel calls are in-process only. [VERIFIED-CODE]
- **Input validation:** native `setBlockedPackages` trusts Dart. The protected list is enforced in Dart (`block_list.dart:66-67`) and in the native picker (`MainActivity.kt:190-203`). Banking coverage is an India-only hard-coded list. Banks elsewhere (and wallets, 2FA apps, ride-hailing, health apps) are lockable. [VERIFIED-CODE, P2]
- **Privacy-policy accuracy:**
  - It says the foreground service runs "while a lock or phone-free block is active". The code runs it permanently. [VERIFIED-CODE, P1-4]
  - It says the log can be exported. There is no UI for that. [VERIFIED-CODE, P2]
- **Abuse against another person:** someone with physical access could install the app on another adult's phone and pick their apps. Mitigations: visible persistent notification, unlimited releases, Settings and uninstall never blocked, 18+ gate. Coercive-control risk is low but not zero. [INFERENCE]
- **Self-abuse:** the escape always exists (release, revoke permission, uninstall). There is no device-admin, which is correct.
- **Threat model** (the user's own impulses are the adversary): clock and zone tampering (P1-2, P1-3), revoking permissions (logged, not prevented), emptying the lock list (P1-8), honour logging (probe 9), and unlimited releases (P1-6). Each is a self-cheat, not a security breach. Together they set the product's real strength at "a speed bump that is logged".

## 7. Behavioural Psychology

**Good**

- Self-chosen stakes (commitment device).
- 21-of-30 rather than a brittle streak for Gates.
- Ranks never drop.
- Dry run before stakes.
- A reduction valve for illness at half XP, limited to 6 days in 30.
- The unpaid penalty expires instead of compounding. The 6,350-rep doubling was removed [VERIFIED-CODE engine.dart:251-263].
- Exercise is capped at the day's own quest volume. A stop rule and health notice are in the terms.

**Concerns**

1. **Punishment grows with success.** The lock is 240 + 20 × (level − 1) minutes with no cap: 420 min at level 10, 1,020 min at level 40, which clamps to the whole waking day. Long-term achievers face the harshest response to one slip. That is a classic driver of abandonment after a lapse (the "what-the-hell" effect). [VERIFIED-RUN probe 11]
2. **Variable, unannounced punishment** maximises anxiety, not learning. Contingency research favours predictable, proportionate consequences. [INFERENCE]
3. **The S rank needs 30 consecutive cleared days.** One miss resets it to 0 (`dungeon.dart:345`): a brittle streak at the very end. [VERIFIED-CODE]
4. **Unlimited releases** (probe 2) make the lock optional. That protects autonomy, but it can also teach "the System is bluffing", which erodes the commitment effect. [VERIFIED-RUN]
5. **The penalty debt is symbolic.** Unpaid work expires, and it only blocks "restart" until midnight. That is safe, but the logged-shame framing ("The System does not negotiate") is the only lever left. [VERIFIED-CODE]
6. **Personality "reflection on why the quest failed"** (5 lines of at least 4 words) is acceptable. Keep it framed as planning, not self-blame.
7. **Rank A fitness:** a failed day owes 60 push-ups on top of the next day's 60. Rank C (probe 5) is 30 + 30. This is within "never more than the daily quest", but the next day's total is double. It is acceptable with the stop rule. [VERIFIED-RUN]

**Is the penalty system safe and fair?** Safe, yes: there is no harmful exertion, sleep loss is prevented by the rest window, there is no food restriction and no humiliation, and an exit always exists. It is not yet fair in two places:

- No dispute path exists for a wrongful verdict (a phone that died, a bug, an unmeasured cap that fails). `PROJECT.md` section 7 promised one; `grep dispute|appeal|grace` finds nothing.
- Level scaling punishes success.

## 8. Google Play Compliance

Official pages fetched 2026-11-07 (summaries, not legal advice):

| Area | Requirement (source) | App status |
|---|---|---|
| Target API | New apps must target API 36 from 31 Aug 2026 ([11926878](https://support.google.com/googleplay/android-developer/answer/11926878)) | targetSdk 36, minSdk 24 [VERIFIED-RUN merged manifest]. OK |
| FGS specialUse | Play Console declaration per FGS type: description, user impact, video; all types reviewed ([13392821](https://support.google.com/googleplay/android-developer/answer/13392821)). The FGS must be user-initiated or perceptible, stoppable, and run "only for as long as necessary" ([16559646](https://support.google.com/googleplay/android-developer/answer/16559646)); subtype reviewed ([developer.android.com](https://developer.android.com/develop/background-work/services/fgs/service-types)) | Declaration not yet made (owner). The service runs 24/7, not only during locks. **Risk (P1-4)** |
| Exact alarms | SCHEDULE_EXACT_ALARM denied by default for new installs targeting 33+ on Android 14+ ([schedule-exact-alarms](https://developer.android.com/about/versions/14/changes/schedule-exact-alarms)) | Optional and user-granted; the System Check prompts. Whether a Play declaration is needed was not verified (the policy page did not load). P3 |
| User Data / prominent disclosure | In-app disclosure plus affirmative consent where access is not reasonably expected; the installed-app inventory is personal and sensitive; a privacy policy is required and must be available in the app ([10144311](https://support.google.com/googleplay/android-developer/answer/10144311)) | Disclosure is one line ("The System needs usage access to lock apps"); the installed-app list is not described. **No in-app privacy policy** [VERIFIED-CODE `grep privacy lib/` = 0]. P1-5 |
| Package visibility | Use targeted `<queries>`, not QUERY_ALL_PACKAGES ([16558241](https://support.google.com/googleplay/android-developer/answer/16558241)) | Uses launcher `<queries>`. OK |
| SYSTEM_ALERT_WINDOW | Send users to the Settings page; Android 15 FGS-start exemption needs a visible overlay ([behavior-changes-15](https://developer.android.com/about/versions/15/behavior-changes-15)) | Settings intent used. The FGS is started from the foreground activity or BOOT_COMPLETED, so OK. Device check advised |
| BOOT_COMPLETED and FGS (Android 15) | dataSync, camera, mediaPlayback, phoneCall, mediaProjection and microphone are barred; specialUse is not (same page) | OK |
| Device and network abuse | No apps that "interfere with … other apps on the device" ([16559646](https://support.google.com/googleplay/android-developer/answer/16559646)) | User-chosen and user-controlled with an always-available release: defensible, but review risk. Keep the exit prominent |
| Health apps declaration | Required for all published apps, testing tracks included ([14738291](https://support.google.com/googleplay/android-developer/answer/14738291)) | Release kit plans "Activity and Fitness". Owner task |
| Data safety | Required even with no data collected ([10787469](https://support.google.com/googleplay/android-developer/answer/10787469)) | Planned "No data collected", which is consistent with the code. Owner task |
| New personal account | Closed test with 12 or more testers opted in for 14 continuous days before production ([14151465](https://support.google.com/googleplay/android-developer/answer/14151465)) | Not started. Owner task |
| IP | No infringement; "the safest approach is to create something that's original" ([9888072](https://support.google.com/googleplay/android-developer/answer/9888072)) | No names or assets from the source work were found in `lib/`, `android/` or the listing. The concept vocabulary is close ("You have met the conditions to become a Player", "Penalty Zone", "Daily Quest", Gates/Dungeons, E–S ranks, bracketed blue system windows; `onboarding_screen.dart:383`). Trade-dress and complaint risk [INFERENCE]. P2, owner and legal |

## 9. QA and Testing

**Gates** (run in a scratch copy with Flutter 3.47.7):

| Gate | Result |
|---|---|
| `dart format --output=none --set-exit-if-changed lib test` | 0 changed, exit 0 |
| `flutter analyze` | No issues, exit 0 |
| `flutter test --coverage` | **211 passed, 0 failed** |
| Line coverage (lcov, 49 loaded files) | **80.3%** (6,287 / 7,827). `main.dart` and `fill_column.dart` are not loaded by any test |

**Per-file coverage of important files:**

| File | Coverage |
|---|---|
| `domain/engine.dart` | 100% |
| `domain/penalty.dart` | 93.9% |
| `domain/systems.dart` | 95.6% |
| `domain/dungeon.dart` | 96.7% |
| `domain/block_list.dart` | 94.1% |
| `app/game_service.dart` | 98.6% |
| `app/penalty_enforcer.dart` | 100% |
| `app/notification_planner.dart` | 76.1% |
| `data/codec.dart` | 96.8% |
| `data/game_store.dart` | 50.0% |
| `ui/game_model.dart` | 57.8% |
| `ui/screens/penalty_screen.dart` | 58.8% |
| `ui/widgets/notice_overlay.dart` | 40.4% |
| `platform/blocker.dart` | 31.9% |
| `platform/notifier.dart` | 0% |
| `ui/screens/app_picker_screen.dart` | 0% |
| Kotlin (about 1,000 lines) | **0%, no tests** |

**Test gaps**

- `integration_test/` does not exist, although `CLAUDE.md` says native behaviour is verified by integration tests. [VERIFIED-RUN `ls`]
- The only stored TestSprite artefact (`.testsprite/runs/74ec5fb0…`) is a failed run of an unrelated "contact screen" test. The auditor did not re-run TestSprite (outward-facing), so the claimed 14/14 is unverified. TestSprite covers web builds only and cannot cover blocking.

**Probe tests** (`test/probe/audit_probe_test.dart` in the scratch copy: 13 probes, 12 passed as written; probe 2's assertion was stricter than reality and the measured result is reported. Probe 12, a near-zero rest window, found no issue and is omitted):

| # | Steps | Expected (safe or fair) | Actual |
|---|---|---|---|
| 1 | Awaken (dry run), sync enforcer, next day tick and sync, `abandon()` | Blocker packages and judge day cleared | No blocker call after abandon. Packages `{instagram}` and judge day stay set, so from the next day natively `due < today` redirects every launch. **FAIL (P0-1)** |
| 2 | Fail day 1; on day 2 at lock start, take a release whenever the lock is active; step 1 min | Lock enforces most of its 240 min, or releases are bounded | 16 releases accepted; locked only in the 1-minute gaps between releases (15 of 240 min). **Unlimited (P1-6)** |
| 3 | `TrustedClock` with no network fix and the device 10 h behind | Device skew corrected or flagged | `now()` equals the device clock; `isNetworkBacked=false`. **Not corrected** |
| 3b | Game on day 1; on day 2 before first open, set the clock to day 1 22:00, open, complete the quest, restore the clock, tick | Day 1 judged failed | Day 1 `QuestCleared`, no lock. **Cheat works without network time (P1-2)** |
| 4 | Focus rank D, 90 min/day on Instagram; remove Instagram from the lock list on day 1 | Cap still measured against social apps | Day 2 meter asked with `{}`, so 0 min and `QuestCleared`; nothing left to lock. **(P1-8)** |
| 5 | Fitness placed at C, fail day 1 | Penalty no more than the quest volume | 30 push-ups owed plus today's quest of 30. Matches the rule (the next day's total doubles) |
| 6 | Fail day 1; first open on day 2 at 22:00 (rest 23:00) | Lock fits waking hours | 60-minute lock (nominal 240), clamped. Acceptable; avoiding locked apps all day is the cost |
| 7 | 365 days, 10 progress taps per day | Bounded storage | 5,106 log entries, 611 KB, 4,016 full rewrites; encode 5 ms, decode 27 ms. P3 |
| 8 | `SavedGame.fromJson` on a damaged document | Recoverable | Throws, so the app shows `StartupErrorApp` with no reset or export (and with P0-1, the redirect loop) |
| 9 | Fail; `recordPenalty(999, 999)` | Some check | Debt paid instantly. Honour system by design (P3) |
| 10 | Start the walk timer and leave it 13 min | Some check | Walk complete. Honour system by design (P3) |
| 11 | `lockMinutesForLevel` at L1, L10, L30, L40 | Capped | 240, 420, 820, 1,020 min: uncapped (P2) |

## 10. Feature Audit

| Feature | Current Implementation | Problem | User Impact | Recommendation | Priority |
|---|---|---|---|---|---|
| Awakening onboarding | 7 steps, animated, placement test, 18+ and terms scroll | Long; permission detours | Activation drop-off | Improve: defer rest and terms detail; show the quest first | P2 |
| Systems (Fitness, Personality, Focus) | Fixed catalogue E–S | The lock is unrelated to Fitness and Personality habits | Weak causal link | Keep; lead with Focus | P2 |
| Daily quest items | checkbox (hold), counter, timer, distance, screen cap, phone-free | Honour-based except caps | Self-cheating is trivial | Keep; add an optional "evidence note" | P3 |
| Screen-time caps | Usage events of the lock list | Lock list can be emptied (P1-8); no reading means fail | Exploit, or a surprise fail | Improve | P1 |
| Dry run (3 days) | Judged, never enforced | None | Trust building | Keep | – |
| Judging and judge redirect | Native redirect when a day is unjudged | Survives abandon or a bad save (P0-1) | Wrongful harassment | Fix | P0 |
| Penalty Zone lock | Random start in waking hours; 4 h + 20 min/level | Misses an app already open (P1-1); uncapped scaling | Lock not felt; harsh later | Fix and cap | P1/P2 |
| 15-minute release | Unlimited, counted | Nullifies the lock | Core value undermined | Replace: limited free releases, then costly ones | P1 |
| Penalty debt | Reps, pages plus reflection, or a phone-free block; expires at midnight | Symbolic | Low | Keep (safe) | – |
| Gates and Dungeons | 21/30 opens a Gate; 3 floors | Complex; long until first reward (≥ day 21) | Mid-term retention hook arrives late | Keep; surface progress | P2 |
| Reduction valve | Up to 20%, 6 days per 30, half XP | Good | Relapse support | Keep | – |
| XP, levels, stats | Stat points allocated, no effect | Stats are cosmetic | Low meaning | Improve or remove stat allocation | P3 |
| Notifications | 21:00, 23:00, morning, lock engaged, Gate | 23:00 may fall in the rest window | Sleep disturbance | Tie to the rest window | P3 |
| System Check | Permissions, battery, auto time | No auto time-zone check | Zone cheat unseen | Improve | P1 |
| 30-day report and share card | In-app report; image share | No raw log export in the UI | Owner cannot audit the trial; policy mismatch | Add export | P2 |
| Rest period | Set once | Cannot be edited | Shift workers stuck | Add edit, effective tomorrow | P2 |
| Diagnostics (spike) | Start or stop locks, shipped in release | Escape hatch edge case; dev surface in prod | Small | Remove from release builds | P2 |
| Dispute or grace | Absent | Wrongful verdicts have no remedy | Trust loss after the first false fail | Add | P1 |

## 11. Growth and Retention

- **Acquisition:** anime and self-improvement communities (Reddit, TikTok "System" edits). There is strong aesthetic pull, but IP-adjacent marketing is risky. The share card is a built-in loop.
- **First five minutes:** a long Awakening; two Settings permission trips; then a quest that cannot be cleared meaningfully until the evening. Show the first quest within 60 seconds and ask for permissions only when the first lock target is chosen.
- **Day-1 return:** the morning "quest issued" notification plus curiosity about the dry run. Good.
- **Likely uninstall reasons** [INFERENCE]: a lock at a bad time (work), a false failure with no dispute, permission and battery friction, the persistent notification, and the punishment escalating with level.
- **Meaningful vs artificial engagement:** the app is designed to be used briefly and then put down (locks, phone-free blocks). That is good. Measure real-life outcomes (clear rate, social-app minutes for Focus), not time in app.
- **Event plan** (privacy-respecting: on-device counters, an opt-in export, no network):
  - activation: onboarding completed, time to first clear
  - D1, D7 and D30 opens
  - clear rate per week
  - releases per lock
  - blocker outages
  - valve use
  - Gate reached, Dungeon outcome
  - Focus: social minutes per day against the baseline from placement
  - abandon reason (one tap)

  Testers export this file to the owner. Retention cannot be measured today because no analytics exist and no export UI exists.

## 12. Prioritised Roadmap

**P0-1: Disarm the native blocker when no game is running.**
- Problem: after `abandon()`, a migration, or an unreadable save, `BlockerState` keeps packages and the judge day, so every chosen-app launch is redirected forever (probe 1; `BlockerState.kt:140`, `WatcherService.kt:94`).
- Solution: add `AppBlocker.reset()` (clear packages, lock, focus and judge day; stop the service). Call it from `abandon` success, from `_abandoned()` and on the startup-error path. Natively, ignore the judge redirect when no game exists (a flag set by Dart). Give `StartupErrorApp` an "export save and reset" action.
- Impact: removes a wrongful-enforcement trap. Complexity: low. Effort: 0.5–1 day. Dependencies: none.
- Acceptance: a Dart test shows abandon calls reset; a Kotlin or instrumentation test shows no redirect with an empty state; a manual device check confirms.

**P1-1: Lock misses an app already in front at lock start.**
- Solution: on each busy check, determine the current foreground app from the last 30–60 min of events (or `queryUsageStats` last-used), not only events since the last query; seed `lastEventQueryAt` on the first busy tick.
- Effort: 0.5 day. Acceptance: an instrumentation test (or manual check) where the app is open across lock start is blocked within 2 s.

**P1-2: Clock trust below API 33 and without a fix.**
- Solution: persist a monotonic anchor (`elapsedRealtime` plus wall time at the last trusted reading). Never let "today" go behind the last judged or seen day; refuse progress for a day earlier than the latest seen day. Natively, compute lock state against the anchor. Alternatively raise minSdk to 33 (product decision).
- Effort: 1–2 days. Acceptance: probe 3b fails to clear day 1; moving the clock forward does not end a native lock.

**P1-3: Time-zone shifts.**
- Solution: store the zone offset with each issued day; treat a zone change within a day as a logged event that does not extend the day; add AUTO_TIME_ZONE to System Check.
- Effort: 1 day. Acceptance: a test with TZ changed mid-day shows the deadline does not move later.

**P1-4: Foreground service only while needed.**
- Solution: start the watcher only while a lock, focus block or pending judgement exists (or from N minutes before a scheduled lock, via an exact alarm or WorkManager), and stop it otherwise. Align the privacy policy and Play declaration text.
- Effort: 1–2 days. Dependency: P1-1. Acceptance: no FGS notification on a day with no penalty; lock still enforced on a device after reboot.

**P1-5: Privacy policy in the app and a prominent disclosure.**
- Solution: a dedicated disclosure screen before GRANT naming usage data and the installed-app list, its purpose, and that it stays on the device, with explicit Accept or Decline. Add a "Privacy" entry in Status that shows the policy text (no internet needed).
- Effort: 0.5 day. Acceptance: a widget test finds the disclosure before `requestUsageAccess`, and the policy is reachable from Status.

**P1-6: Release policy** (needs_user: product decision).
- Solution, for example: 2 free releases per lock; after that a 30 s hold plus a typed reason, and each extra release cancels that day's XP or Gate credit. The emergency exit always stays available.
- Acceptance: a probe-2 variant shows at least 75% of the lock enforced without the costly path.

**P1-7: Native tests.**
- Solution: Robolectric unit tests for `BlockerState`, `UsageMeter` and the `WatcherService.check` logic; one `integration_test` covering the lock flow on an emulator.
- Effort: 2–3 days. Acceptance: these run in CI; the P0-1 and P1-1 regressions are covered.

**P1-8: Cap integrity.**
- Solution: require at least one lock target while the System uses caps; measure caps against a fixed social-app category plus the user's list; removing apps follows a 7-day cooldown.
- Effort: 0.5 day. Acceptance: probe 4 fails to clear.

**P1-9: Dispute path for wrongful verdicts.**
- Solution: one "contest verdict" per 14 days within 2 hours of judgement, with a logged reason. It cancels the lock and debt (not the fail record).
- Effort: 1 day. Acceptance: a service test plus a report line.

**P1-10: Play Console prerequisites** (needs_user).
- FGS declaration and video, Health apps declaration, Data safety, clean store screenshots, and a closed test with 12+ testers for 14 days.

**P2**
- Cap the lock length (for example max(240, …) ≤ 360 min) and stop level scaling. Effort 0.25 day. Acceptance: probe 11 shows the cap.
- Log export UI (JSON and CSV through the share sheet). Effort 0.5 day.
- Editable rest period, effective tomorrow. Effort 0.5 day.
- Remove the diagnostics spike from release builds. Effort 0.25 day.
- Minimum 12–13 sp body text; review 9–11 px labels. Effort 1 day.
- Global banking and 2FA protection by category (or let users mark "never lock" apps). Effort 0.5 day.
- IP review of copy (owner or legal).
- Let S rank tolerate 1 miss in 30.

**P3:** rest-aware notifications; bound or rotate the log; R8 with keep rules; exact-alarm declaration check.

## 13. Recommended New Features

1. **Pre-lock window disclosure** ("Your lock will start between 10:00 and 18:00"). It keeps the twist and removes the planning anxiety. Reason: fewer bad-time locks and fewer uninstalls.
2. **Focus baseline and outcome chart:** social-app minutes per day against the placement baseline. It shows real-life improvement, which is the app's real value proposition.
3. **Contest verdict** (P1-9). It builds trust after the first false fail.
4. **Tester export bundle** (log plus metrics). It is the only way to get retention evidence without a backend.
5. **"Never lock" user list** for critical apps outside the India banking list.

## 14. Remove or Replace

- **Replace** unlimited releases with a bounded, escalating release (P1-6).
- **Replace** uncapped level-scaled locks with a fixed or capped length.
- **Remove** the diagnostics spike screen from release builds.
- **Remove or give meaning to** stat allocation (stats have no gameplay effect).
- **Remove** dead code (`recordEmergencyStop`), or wire it to the release flow.
- **Reconsider** Fitness and Personality locks as the stake. An outcome-linked consequence (for example a Focus-style phone-free block) is more coherent.

## 15. Play Publication Readiness

| Item | Status |
|---|---|
| Signed AAB, targetSdk 36 | Present (`dist/DoOrDie-0.9.0.aab`, git-ignored) |
| Privacy policy URL | Drafted (`docs/privacy-policy.html`); inaccurate on FGS lifetime and export; **no in-app access** |
| Prominent disclosure for usage data and the installed-app list | Insufficient |
| FGS specialUse declaration and video | Not done (owner); FGS lifetime is a policy risk |
| Health apps declaration, Data safety, content rating | Not done (owner); answers drafted in `release/PLAY_RELEASE.md` |
| Closed test, 12 testers, 14 days | Not started |
| Store assets | Screenshots show a personal status bar and an empty Penalty screen |
| P0 open | Yes (P0-1) |

Internal testing is feasible after P0-1. Production is not.

## 16. Go / No-Go

**No-Go for production. Go for internal testing after P0-1. Closed testing after P1-1 to P1-5 and P1-8.**

| Dimension | Score | Reason |
|---|---|---|
| Business Potential | 4 | Niche, IP-adjacent audience; no monetisation path designed; Play policy exposure; no user evidence (cap 6) |
| Product-Market Fit Potential | 3 | Only the owner's own trial; the core stake is optional (unlimited releases); fit is plausible only for Focus |
| Technical Quality | 6 | Excellent Dart domain, tests and serialisation; but the native layer is untested and has a P0 trap, a first-lock miss, clock and zone trust gaps, and a 24/7 FGS |
| UI/UX Quality | 6 | Distinctive, coherent theme, reduced-motion support, hold-to-confirm; small type, long onboarding, uneditable rest period, anxiety-first lock UX |
| Security and Privacy | 7 | On-device, no internet, backups off, nothing exported, no secrets; the policy text is inaccurate and protected apps are India-centric |
| Behavioural Design | 6 | Safe after the recent fixes, forgiving Gate rule, valve, dry run; punishment escalates with level, unannounced timing, no dispute path, a brittle S streak, releases undermine the commitment |
| Retention Potential | 4 | Punitive core with late rewards (Gate at day 21 or later), no social or real-outcome feedback, nothing measured |
| Publication Readiness | 3 | P0 open; no in-app policy or disclosure; FGS lifetime against policy; declarations and closed test outstanding |

**Role disagreements, resolved**

- **Founder vs behavioural psychologist on releases.** The founder wants stakes; the psychologist wants an always-available exit. Resolution: keep the exit but make extra releases costly (P1-6). Safety is preserved and the commitment is restored.
- **PM vs UX on the hidden lock start.** The PM sees the "twist" as differentiation; UX sees anxiety and bad-time locks. Resolution: announce the window range, keep the exact start hidden.
- **Engineer vs PM on clock hardening below API 33.** Resolution: implement the monotonic anchor rather than drop users, unless the owner chooses minSdk 33.

**If I were investing my own money, reputation and six months:** yes, continue, but narrowed to the Focus System as the flagship. There, "lose your apps if you over-use your apps" is coherent, measurable (usage access) and honest about outcomes.

What I would change first, in order:

1. Fix P0-1 and P1-1 so enforcement is correct and never wrongful.
2. Decide the release policy and cap lock scaling, so the stake is real but fair.
3. Move the FGS to run only while needed, add the in-app privacy and disclosure screens, and fix the clock and zone trust.
4. Ship to 12–20 closed testers with an on-device metrics export, and judge on D7/D30 retention and a measured drop in social minutes, not on feature count.

No new Systems, Dungeons or art until those numbers exist.
