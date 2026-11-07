# Do or Die: Independent Product, Engineering, UX, Security and Business Audit

**Date:** 7 November 2026 · **Version audited:** 0.9.0 (build 13), commit `593529c` on `main`
**Scope:** everything in this repository. No source code was modified. Probe tests were run in a scratch copy outside the repo.
**Sources used:** only the files in this folder, commands run during this audit, and official Google/Android documentation fetched during this audit. No memory from other conversations was used.

## How to read the evidence labels

| Label | Meaning |
|---|---|
| **[VERIFIED-RUN]** | Reproduced by running code during this audit (test suite, probe test, build artefact inspection). |
| **[VERIFIED-CODE]** | Read directly in the source at the cited line; behaviour follows from language/platform semantics, not executed. |
| **[INFERENCE]** | Reasonable conclusion from code or docs, not reproduced. |
| **[UNVERIFIED RISK]** | Plausible, needs a device test or penetration test. Nothing was tested on a physical device in this audit. |

No penetration test, no device test, no network test and no user research were performed.

---

## 1. Executive Summary

Do or Die is a well-engineered **personal experiment** that is being pushed toward **public publication before its own validation question has been answered.** The repository's own plan (PROJECT.md §2, §6) says the app exists to answer one question over 30 days — *does the real penalty make me do my habits more reliably without making me quit?* — and only then decide whether to launch. The app is on **trial day 8**, and the status screen in `release/screenshots/2_status.png` and `progress.md` shows **2 cleared days toward the Gate with a streak of 1 (best 2)**. With days 1–3 being a dry run, that is roughly **2 of 4 live days cleared — at the "fail signal" boundary (< 50%) the project set for itself.** One person, one week, is not evidence either way; but it is certainly not evidence for launching.

**What is genuinely good:**
- The rules engine (`lib/domain/`) is pure, deterministic, readable and well tested (205 tests pass, analyzer clean, 80% line coverage). Fairness rules (edits apply tomorrow, frozen daily quests, dry run, never-lock list for phone/SMS/banking, ranks never drop, 21-of-30 Gate) show real thought about wrongful penalties.
- No internet permission, no accounts, no SDKs that phone home: the privacy attack surface is very small.
- The blocker avoids Accessibility Service, a deliberate and correct trade-off for Indian UPI/banking apps and for Play policy.

**What is wrong, in order of severity:**
1. **The physical penalty is unsafe as designed.** Unpaid push-ups double every day with no ceiling: **50 → 150 → 350 → 750 → 1,550 → 3,150 → 6,350 in seven days** [VERIFIED-RUN, probe P1]. A rank-E user whose daily quest is *10 knee push-ups* owes *50 full push-ups* on the first failure, and the placement test accepts users who can do **0** push-ups. There is **no medical disclaimer or stop rule anywhere in the app** [VERIFIED-CODE: no match for medical/doctor/injury in `lib/`], although SYSTEMS_PRD.md §6.6 and the Play listing draft both promise one.
2. **The enforcement is simultaneously too harsh and too porous.** Every quest counter, checkbox and penalty rep is self-reported — one call pays a 10,000-rep debt [VERIFIED-RUN, P3]; the 15-minute release is free and unlimited (16 releases cover a 4-hour lock entirely) [VERIFIED-RUN, P2]; force-stop or "Clear storage" in Settings (which can never be locked) ends enforcement. So the system punishes **honest** users exponentially and lets **dishonest** users through for free. That is the opposite of what a behaviour-change product should do.
3. **A concurrency defect can erase a completed objective, which can cause a wrongful penalty** — the defect class the project itself ranks highest. A screen-time measurement running in the 30-second poll overwrites a checkbox the user confirmed during the measurement [VERIFIED-RUN, P5].
4. **The product tries to be three products** (fitness coach, personality coach, phone-addiction tool) wrapped in a fourth (an anime RPG), with roughly 15 named concepts (System, rank, level, XP, stats, attribute points, Gate, Dungeon, floors, Rank Trial, Penalty Zone, Dungeon Penalty, release, reduction valve, report). Only one of the three Systems — Focus — has any automatic verification.
5. **Commercial viability is weak.** The audience is a niche of a niche (anime fans who want punishment), several "System" apps already exist on Play (COMPETITOR_ANALYSIS.md lists SelfQuest at 500K+ installs), and the core mechanic (punishment + app lock) is the kind users tolerate for days, not months.

**Overall verdict:** **No-Go for public (production) release. Conditional Go for continuing the personal trial and a small closed test after the P0 fixes.** If you invest further, **narrow to the Focus/phone-addiction use case**, drop exercise as punishment, and replace exponential debt with bounded, pre-committed, recoverable consequences.

### Scores (out of 10)

| Dimension | Score | One-line reason |
|---|---|---|
| Business Potential | **3** | Niche audience, crowded "System app" sub-genre, no monetisation, fad-dependent theme. |
| Product-Market Fit Potential | **3** | Real problem (phone overuse, consistency), but the solution's core loop is punishment and the trial is not yet showing a win for its own author. |
| Technical Quality | **6** | Clean domain layer and tests; but a confirmed lost-update race, timezone-unsafe persistence, whole-document storage that grows forever, and zero native/integration tests. |
| UI/UX Quality | **5** | Distinctive and coherent visual identity; heavy jargon, a 7-step onboarding with a scroll-gated terms wall, ~100 uses of 9–11 px monospace text, a permanently alarming red Penalty tab, attributes that do nothing. |
| Security and Privacy | **7** | Minimal attack surface (no network). Deductions: privacy policy states data is deleted on uninstall while Auto Backup is left on by default; diagnostics screen shipped in release; local data is plaintext (acceptable for this threat model). |
| Behavioural Design | **3** | Good fairness instincts (dry run, valve, no rank loss) undermined by compounding punishment, unpredictable lock timing, unsafe exercise penalties and perverse incentives toward dishonesty. |
| Retention Potential | **3** | Novelty theme + punishment loop = strong day-1, weak day-30; no pause/sick mode, no dispute path, no positive reason to return besides avoiding a penalty. |
| Publication Readiness | **3** | Internal testing: feasible. Production: blocked by safety, disclosure, declaration and IP-proximity issues listed in §8 and §15. |

---

## 2. Product Viability Assessment (Entrepreneur / Founder)

**Is the problem real?** Yes, partly. "I don't do what I planned" and "I lose hours to short-video apps" are real, frequent, and painful. They are also the most crowded problems in consumer apps (Habitica, Streaks, Fabulous, Opal, one sec, Forest, Digital Wellbeing built into Android).

**Is it painful enough for daily use of an app?** For phone overuse: yes — people already install blockers. For "personality development": no — the pain is vague and the app can't verify any of it (every Personality item is a checkbox, counter or timer you set yourself: `lib/domain/system_catalogue.dart:101-164`).

**Who is the actual customer?** The repo's own personas (SYSTEMS_PRD.md §2) are hypotheses with no interviews. From the design, the real early adopter is: *an 18–25-year-old male anime fan in India who already knows Solo Leveling, has tried habit apps, and wants to be forced.* That is a real segment but small, fashion-driven and low willingness to pay.

**Too many problems?** Yes. Fitness, social/intellectual growth and phone addiction need different content, verification, safety rules and marketing. Three Systems triples content and tuning work with one developer.

**Differentiation.** The claimed differentiator is "real consequences + app lock + rank trials". Of these, only the **app lock tied to measured screen time** is both differentiated and verifiable. The RPG framing is shared by at least four existing Play apps (COMPETITOR_ANALYSIS.md §2-B2). The physical penalty is a differentiator mainly because competitors avoid it — for liability reasons.

**Is the Solo Leveling vibe durable?** It is an acquisition hook, not a moat. It ties the brand to a franchise's popularity cycle and creates IP proximity (§8). Users who come for the theme churn when the theme stops being fresh; users who need a phone-discipline tool may be put off by it.

**Monetisation.** None exists. PRD.md discusses it for later. Realistic options: one-time unlock or a modest subscription for the Focus tooling (scheduling, stricter modes, widgets, reports). "Pay for harsher punishment" has precedent (Beeminder, stickK) but money-stakes are a different, regulated product.

**Would users pay?** A minority would pay for an effective phone-discipline tool (Opal and one sec prove it). Few would pay for honour-system checkboxes with an anime skin.

**Biggest business risks:** (1) safety/legal exposure from the exercise penalty; (2) Play policy friction on FGS/usage access; (3) IP proximity; (4) retention collapse after the novelty period; (5) single-developer content burden across three Systems.

**Recommendation: Option 2 — Narrow.** Build "a phone-discipline app where you pre-commit to consequences you choose", using the System voice as optional flavour. Keep the measured screen-time cap and the lock as the core loop; make fitness and reading *positive* quests (not punishments) or cut them for v1. Do not pivot market and do not abandon: the narrowed version is cheap to test and the engine already supports it.

---

## 3. Target Audience and Problem-Solution Fit

| Question | Finding |
|---|---|
| Clear initial segment? | **No.** Docs describe three personas with no validation. The trial user (the developer) is the only data point. |
| Activation moment | Implicitly "first cleared day" (XP + notice). No defined metric. For a blocker product the real activation is "first time the lock stopped me opening an app and I was glad". |
| Core loop | Quest issued → do it → hold-to-confirm → midnight verdict → XP or Penalty Zone. The loop's *emotional driver* is fear of the penalty, not progress. |
| Problem-solution fit by System | **Focus:** good fit (measured caps, lock, phone-free block). **Fitness:** weak (honour counters, punishment by exercise, competes with dedicated fitness apps with real tracking). **Personality:** weakest (vague tasks, entirely unverifiable, "say hello to someone" is not a daily habit for most users). |

---

## 4. Technical Architecture Audit (Senior Android Engineer)

### 4.1 What exists

| Layer | Files | Notes |
|---|---|---|
| Domain (pure Dart) | `lib/domain/*.dart` (~1,600 lines) | Engine, penalties, sleep window, random lock scheduler, Systems, catalogue, Gates/Dungeons, placement, block list. No Flutter imports. Good. |
| App services | `lib/app/game_service.dart` (1,038 lines), `penalty_enforcer.dart`, `notification_planner.dart`, `trusted_clock.dart`, `report.dart` | `GameService` is the single façade the UI uses. It has grown into a god object (timers, caps, penalties, Gates, export, releases). |
| Data | `lib/data/` | Whole game + append-only log serialised as **one JSON string** under one key in `SharedPreferencesAsync` (`game_store.dart:23-36`). |
| Platform bridge | `lib/platform/*.dart` ↔ `MainActivity.kt` MethodChannel `doordie/blocker` | |
| Native | `WatcherService.kt` (FGS, specialUse), `BlockActivity.kt`, `BlockerState.kt` (SharedPreferences), `BootReceiver.kt`, `UsageMeter.kt`, `TrustedTime.kt` | Usage-access polling, not Accessibility. |
| UI | `lib/ui/` (~12,000 lines; onboarding alone 2,492) | `ChangeNotifier` `GameModel` with a 30-second poll timer. |
| Build | Flutter, minSdk **24**, targetSdk **36** [VERIFIED-RUN: `apkanalyzer` on `dist/DoOrDie-0.9.0-device.apk`], R8 off, release APK **72 MB** (all ABIs, `classes.dex` 9 MB) | AAB splits will shrink Play downloads; R8 is off because of a past JNI breakage (`android/app/build.gradle.kts:62-67`). |

Dependencies (`pubspec.yaml`) are few and mainstream: `flutter_local_notifications`, `shared_preferences`, `timezone`, `flutter_timezone`, `share_plus`, `flutter_soloud`, `flutter_animate`. `flutter pub get` reports 20 packages with newer incompatible versions — normal, not a vulnerability by itself. No backend, no auth, no network code.

### 4.2 Quest engine

| Question | Finding |
|---|---|
| How quests are generated | From a static catalogue per System × rank (`system_catalogue.dart`), reduced by the valve (`systems.dart:44-50`) or boosted on Dungeon floors (`systems.dart:54-60`). The day's quest is **snapshotted when first issued** (`dungeon.dart:229-247`) so updates can't change a live quest. Good. |
| Is completion verified? | **Only screen-time caps are measured** (usage access). Timers measure wall-clock time between start and stop, not activity. Counters, distance and checkboxes are **pure self-report** via `+1/+5` and hold buttons (`game_service.dart:586-619`; `quest_screen.dart:626,680`). [VERIFIED-RUN P4: every Fitness item completed by value entry.] |
| Can users manipulate completion? | Yes, trivially, by tapping. Acceptable for a single-player honour app; fatal for any future leaderboard/PvP. The report's honesty section ("Most of it rests on your word") is a thoughtful mitigation. |
| Daily reset | Days are judged lazily by `GameService.tick()` on start, resume and every 30 s while the UI is alive (`game_model.dart:136`). If the app is closed, the native watcher redirects the user into the app when they open a locked app after midnight (`WatcherService.kt:94-100`, `BlockerState.kt:136-146`). Clever, but judgement still depends on the app/process running; a user who force-stops and never opens a locked app is never judged. |
| Time zones / clock | `TrustedClock` corrects with network time; **on Android 12 and below (API < 33) there is no network time at all** (`TrustedTime.kt:15`), so changing the device clock can end a running lock on those devices [VERIFIED-CODE]. The Dart offset is held in memory only and starts at zero each launch (`trusted_clock.dart:14`). **All instants are persisted as local ISO strings without offset** (`codec.dart:114-131`, `saved_game.dart:24`, `log_entry.dart`); after a timezone change a stored lock window, running timer or Gate time is re-interpreted in the new zone [VERIFIED-CODE: Dart `DateTime.parse` without offset yields local time]. Days are always local-midnight; no configurable day-end for night-shift users. |
| Missed quests | Multiple unopened days are judged one by one in order (`game_service.dart:284-348`); a lock for a day that is already over becomes `LockMissed`. Correct. |
| Can progress become inconsistent? | **Yes — confirmed race.** `GameService` has no mutual exclusion. Each method reads `_game`, awaits platform calls, then writes a copy derived from the stale read (`_commit`, `game_service.dart:1034-1037`). Probe P5: a checkbox confirmed while `measureCaps()` (the 30 s poll) awaits the usage meter is **lost** — progress goes from 1 back to null [VERIFIED-RUN]. The same pattern exists in `tick()` at day close. Consequence: a cleared objective can be judged failed → wrongful penalty. |
| Exploitable progression? | XP is only from cleared days; with honour inputs, everything is exploitable by the owner of the phone. No other users are affected (no network). |

### 4.3 App-blocking mechanism under real Android constraints

The watcher is a `specialUse` foreground service that polls `UsageStatsManager.queryEvents` every 700 ms while a lock or judgement is due and every 5 s otherwise, and starts `BlockActivity` over a chosen app (`WatcherService.kt:37-113`).

| Threat to reliability | Effect | Evidence |
|---|---|---|
| Force stop (Settings is never lockable) | Watcher dies; nothing enforces until the user opens Do or Die. Outage is logged only on next app open. | [VERIFIED-CODE] `MainActivity.kt:30`, `game_model.dart:162-189`; docs admit it (README). |
| "Clear storage" / uninstall | Whole game, debt, log and lock disappear without trace. | [VERIFIED-CODE] single prefs key; no device admin (deliberately). |
| Revoke Usage access or overlay | Watcher refuses to start; Focus caps fall back to **honour confirmation** (`game_service.dart:456-465`). | [VERIFIED-CODE] |
| Reboot | `BootReceiver` restarts the watcher (permissions permitting). Android-version restrictions on starting FGS from boot: see §8. | [VERIFIED-CODE] |
| OEM battery killers | README and System Check tell the user to exempt the app manually; cannot be guaranteed. | [UNVERIFIED RISK] device-dependent. |
| Doze / deep sleep | `Handler.postDelayed` stalls in deep sleep, but the screen is on whenever an app is used, so impact is limited. | [INFERENCE] |
| Split-screen, picture-in-picture, freeform | Watcher tracks the *last* `ACTIVITY_RESUMED` package; a locked app in split-screen or a YouTube PiP window may keep running. | [UNVERIFIED RISK] |
| Browsers, web versions, app clones / work profile | Blocking is per package; m.youtube.com in Chrome or a cloned Instagram in a second profile is not covered. | [INFERENCE] |
| Diagnostics screen in release | `BlockerSpikeScreen` can `stopLock()` natively. Entry is refused only if a penalty is in effect *at the moment of opening* (`app_shell.dart:157-179`); if it is already open when midnight judges a failure, "Stop" clears the native lock, and `PenaltyEnforcer` **does not re-send** an unchanged window (`penalty_enforcer.dart:45-55`) [VERIFIED-RUN P6 for the enforcer half]. | Remove from release builds. |
| Unlimited releases | 15 min each, free, unlimited; 16 releases cover a 240-min lock entirely. | [VERIFIED-RUN P2] |

**Conclusion:** for a motivated user who *wants* the lock, it is reasonably reliable. Against a user who wants out, it is a speed bump — which is the honest ceiling for any non-invasive blocker. Do not try to close these holes with device admin or other invasive controls; instead **design the product so the user does not want out** (bounded, pre-chosen, fair consequences) and **make bypasses visible** (already partly done via the log).

### 4.4 Storage, performance, battery, lifecycle

- **Whole-document writes:** every tap re-encodes and rewrites the entire game *including the unbounded log* (`game_store.dart:35-36`). Archives are additional full copies, never deleted (`game_store.dart:43-46`). Log lookups (`_honoured`, `reportDue`) scan the whole log (`game_service.dart:436-442, 556-560`). This is fine at day 8 and degrades linearly; after months it means main-isolate JSON encoding on every tap. [INFERENCE] Move to SQLite/Drift (or at least split log from state and cap archives).
- **Schema migration:** `schemaVersion = 1` is written but never read (`saved_game.dart:63`). Any parse failure lands on `StartupErrorApp` with no export or recovery option (`main.dart:87-93`): safe against wiping, but a dead end for the user.
- **Battery:** the FGS wakes every 5 s forever when idle and every 700 ms during locks. Probably modest, but it is an always-on FGS with a permanent notification for a product whose locks occur only on failure days. [UNVERIFIED RISK] measure with Battery Historian.
- **Startup:** `main()` awaits a platform trusted-time call and notification init before `runApp` (`main.dart:62-71`) → blank launch screen for that duration. Measure.
- **Error handling:** platform sync failures are caught and logged (`game_model.dart:418-438`) — good; but they're only `debugPrint`ed, invisible in release.

---

## 5. UI/UX Audit (Senior UI/UX Designer)

Evidence: the four store screenshots in `release/screenshots/`, the design docs, and the screen source. Not tested interactively on a device in this audit.

**Strengths**
- A coherent, distinctive visual system (dark navy, glow, cut corners, Chakra Petch + JetBrains Mono). Clear tab structure (Quest / Status / Penalty).
- The Quest screen (`1_quest.png`) is focused: three objectives, progress, time remaining, one status line from "the System".
- Hold-to-confirm prevents accidental completion; undo exists for counters.
- System Check (`4_system_check.png`) explains each permission plainly. Reduced-motion is respected in several widgets (`decode_text.dart:52`, `system_window.dart:65`).

**Problems**

| Area | Problem | Impact | Recommendation |
|---|---|---|---|
| First-time experience | 7 onboarding steps (`onboarding_screen.dart:71`: contact, system, placement, quest, apps, rest, terms) plus a terms wall that must be scrolled line-by-line ("SCROLL TO READ ALL TERMS"). Permissions (usage access, overlay, restricted settings on sideload) come mid-flow. | Drop-off before the first quest; terms read as a threat ("The System does not negotiate"). | Get the user to a first quest in under 2 minutes; ask for blocker permissions only when they first opt into a lock. |
| Jargon load | ~15 named concepts; the Status screen alone shows Rank, Level, XP, streak, trial day, Gate dial, reduction valve, Report, System Check, attributes. | Cognitive overload; users can't tell what matters. | One primary number per screen. Hide Gates/Dungeons until the first Gate is near. |
| Attributes | STR/VIT/INT/CHA/DIS with spendable points that **do nothing** (SYSTEMS_PRD.md §5.7, `2_status.png`). | Feels fake within a week (the project's own design review said so). | Remove until they have an effect. |
| Penalty tab | When no penalty exists, it still shows a full-red screen with a giant `00:00:00` and "NO LOCK TODAY" (`3_penalty.png`). Locked-app chips are green. | Constant low-level threat; colour semantics inverted (green = locked). | Neutral idle state; show the lock list and a calm "No penalty" message. |
| Readability | ~100 uses of 9–11 px monospace text with wide letter-spacing (`grep Hud.mono(9|10|11`); dim text contrast is 5.9:1 (passes AA). | Hard to read outdoors and for low-vision users; letter-spaced mono wraps awkwardly ("Write one journal / line"). | Minimum 12 sp body, test with 200% font scale. |
| Feedback on honest effort | Quests are binary: "Partial completion is failure" (terms). 9 of 10 pages = full Penalty Zone. | Feels unfair; encourages lying with `+5`. | Partial credit, or a "minimum viable day" floor. |
| Notifications | Warnings fire at a fixed 21:00 and 23:00 regardless of the user's sleep window (`notification_planner.dart:46-48, 70-84`). | Pings a user who sleeps at 22:00. | Derive from the rest period. |
| Block screen | Clear and calm (`BlockActivity.kt`), shows releases used. Good. | — | Keep. |
| Empty / error states | Startup error screen tells the user to "report the text below" with no way to export data. | Dead end. | Add export + reset with confirmation. |
| Store screenshots | Real phone status bar with personal notifications visible. | Looks unpolished on the listing. | Clean status bar (demo mode). |

**Engagement vs retention:** the UI makes the first days exciting (reveals, sounds, notices). After that, the only reason to open the app is to log and to avoid punishment. There is no positive reason to return (insight, visible improvement, encouragement) until the 30-day report.

---

## 6. Security and Privacy Audit

**Threat model.** Single-user, offline app. No server, no accounts, no network permission in release (verified: release manifest permissions are `SCHEDULE_EXACT_ALARM, PACKAGE_USAGE_STATS, FOREGROUND_SERVICE, VIBRATE, SYSTEM_ALERT_WINDOW, FOREGROUND_SERVICE_SPECIAL_USE, POST_NOTIFICATIONS, RECEIVE_BOOT_COMPLETED` plus the AndroidX dynamic-receiver permission) [VERIFIED-RUN]. The realistic adversary is (a) the user cheating themselves, or (b) someone with physical access to an unlocked phone.

| # | Question | Answer |
|---|---|---|
| 1 | What could an attacker access? | With the phone unlocked: quest history, reflections (free text about why the user failed — potentially sensitive), chosen apps, sleep window. Stored in app-private storage, plaintext. Another app cannot read it without root. [VERIFIED-CODE] |
| 2 | What could an attacker manipulate? | Only via physical access or root/backup tampering. All exported components are `exported="false"` except the launcher activity (`AndroidManifest.xml`). MethodChannel is internal. [VERIFIED-CODE] |
| 3 | Account compromise | No accounts. N/A. |
| 4 | Can users manipulate XP, rewards, quests? | Yes, by design (honour inputs; see §4.2). Not a vulnerability while single-player; becomes one with any leaderboard. |
| 5 | Backend exploitation | No backend. |
| 6 | Exposure of other users' data | None possible in the current architecture. |

**Verified issues**
- **Privacy policy inaccuracy.** `docs/privacy-policy.html` says data "is deleted when you uninstall the app". The manifest does not set `android:allowBackup`, so Android Auto Backup is **on by default** and app data (including reflections) can be backed up to the user's Google account and restored on reinstall [VERIFIED-CODE; backup behaviour per Android docs]. Either set `allowBackup="false"` / data-extraction rules, or correct the policy. (This also means reinstalling may *restore* a debt — arguably desirable — but must be disclosed accurately.)
- **Diagnostics screen in release** (`lib/spike/blocker_spike_screen.dart`, reachable in release builds through a hidden seven-tap gesture on the Status screen, `status_screen.dart:232-233`) can start and stop locks natively. Not a security hole for other users, but an integrity bypass of the product's own rules (§4.3).
- **Age inconsistency:** privacy policy says "not directed at children under 13"; Play kit says 18+. There is **no age gate** in onboarding. With physical penalties, the in-app experience should state 18+ explicitly.
- **Secrets:** the upload keystore lives outside the repo; `android/key.properties` exists locally with passwords but is git-ignored and **not tracked** [VERIFIED-RUN: `git ls-files`]. The repository is public on GitHub; keep it that way and back up the key.

**Potential risks (not verified)**
- Abuse of the blocking mechanism *against another person* (a partner or parent installing it on someone else's phone). Mitigations already in place: the user must grant usage access and overlay themselves, Settings is never locked, release always exists, foreground notification is visible. This is the right posture; keep it and never add stealth features.
- Dependency vulnerabilities: no CVE scan was run. Run `osv-scanner` on `pubspec.lock` before release.

**Privacy implications.** Usage-access data (which apps, when, how long) is sensitive behavioural data. Today it never leaves the device — this is a genuine strength and a marketing asset. Any future analytics must be opt-in, aggregated and must not include package-level usage.

---

## 7. Behavioural Psychology Assessment

**What the design gets right**
- **Commitment device with self-chosen targets** (which apps, rest period) — consistent with pre-commitment research.
- **Forgiving progression:** 21 of 30 days opens a Gate (not a streak), ranks never drop. This avoids the "what-the-hell effect" where one broken streak ends the habit.
- **Dry run, frozen quests, next-day edits:** protect perceived fairness, which is central to whether people accept a consequence.
- **Honesty section in the report** turns cheating into something visible rather than something punished.

**What is unsound**

| Mechanic | Problem | Evidence |
|---|---|---|
| Exponential carry-over ("100% interest") | Debt becomes impossible within days (6,350 reps on day 8). Impossible demands produce learned helplessness and abandonment, not discipline. It also only bites people who report honestly. | Probe P1; `engine.dart:249-261`; `config.dart:18` |
| Exercise as punishment | Pairs exercise with aversion — the opposite of building an exercise habit for the Fitness System. 50 push-ups for a user placed at "10 knee push-ups" is a 5× overload; doubled debt quickly becomes physically dangerous (rhabdomyolysis risk from extreme unaccustomed volume is a documented harm). **This must not ship.** | `penalty.dart:26-29`; `placement.dart:33-37`; catalogue rank E |
| Unannounced random lock time | Unpredictable aversive events increase stress and reduce perceived control; control is what self-regulation needs. It also makes the penalty feel like being ambushed rather than a consequence. | `penalty.dart:193-229`; terms copy |
| "Partial completion is failure" | All-or-nothing goals increase drop-off and reporting dishonesty. | Terms step |
| Punishment-dominant loop | The daily emotional driver is fear of the Penalty Zone. Extrinsic, aversive motivation tends to fade or produce resentment and app deletion once the user habituates or the stakes feel unfair. | Overall design |
| Free unlimited release | Undercuts the lock entirely; with no cost, the "count" is the only friction. Fine as a safety valve, wrong as a design centrepiece. | Probe P2 |
| No pause / sick / travel day | Illness or travel guarantees failures and penalties. The 20% valve is not enough and applies only from tomorrow. | grep: no vacation/sick/pause feature |
| No dispute path | PROJECT.md §7 lists "a grace and dispute path for false failures" as a mitigation; it does not exist. | grep: no dispute/appeal |
| Personality reflection penalty | Writing *why* you failed is one of the better ideas here (reflective, non-harmful) — but 5 lines × 4 words is easily gamed. Keep and soften. | `penalty.dart:237-254` |

**Dependence on external punishment.** Yes, the current design trains compliance to the System, not self-control. The healthier pattern is **scaffold then fade**: strong external structure early, then progressively more user autonomy (user sets consequences, longer intervals, fewer reminders).

**Recommended system (safe and sustainable)**
1. **Consequences are chosen in advance, bounded, and non-physical by default:** e.g. "if I miss, my chosen apps lock for N hours tomorrow" with N fixed at setup, never compounding. Optional "restorative task" (a 10-minute walk, 10 pages, a written reflection) that *shortens* the lock — making the penalty point toward the habit instead of away from it.
2. **No compounding debt.** Unpaid restorative tasks simply expire and are logged.
3. **Predictable lock window** ("tomorrow 18:00–22:00", user-chosen), not ambush timing.
4. **Minimum viable day:** a floor version of each quest that counts as "kept the chain", plus partial credit.
5. **Planned rest days** (e.g. 2 per week, declared in advance) and a sick/travel pause that suspends judging.
6. **Positive reinforcement that matters:** show measured change (minutes of social media saved per week) prominently; the System voice acknowledges effort, not just failure.
7. **Never** use exercise volume, sleep loss, food restriction, humiliation or money loss as automatic punishments.

---

## 8. Google Play Compliance Assessment

Checked against official Google Play Console Help and developer.android.com pages fetched on 7 Nov 2026 (URLs below). This is a product compliance assessment, not legal advice.

| Area | Current rule (source) | App status | Risk |
|---|---|---|---|
| Target API | New apps and updates must target **API 36** since 31 Aug 2026; the extension ended 1 Nov 2026. ([answer/11926878](https://support.google.com/googleplay/android-developer/answer/11926878)) | targetSdk 36 [VERIFIED-RUN]. | **Compliant.** Android 16 behaviour: predictive back on by default, `onBackPressed` not delivered. `BlockActivity` already registers an `OnBackInvokedCallback` on API 33+ (`BlockActivity.kt:190-194`), so Back still goes Home. Test it on an Android 16 device. ([behaviour changes 16](https://developer.android.com/about/versions/16/behavior-changes-16)) |
| Foreground service `specialUse` | Allowed only in limited cases not covered by other types. Each declared type needs a Play Console declaration: description, impact if deferred, a **video** of the user triggering it, and the use case. App blocking is **not** on the accepted-use-case list. FGS must be user-initiated or user-visible, and stoppable by the user. ([answer/13392821](https://support.google.com/googleplay/android-developer/answer/13392821), [FGS types](https://developer.android.com/develop/background-work/services/fgs/service-types), [Device & Network Abuse answer/9888379](https://support.google.com/googleplay/android-developer/answer/9888379)) | Declared with a subtype property; runs **24/7**, not only during locks. | **High review risk.** An always-on FGS is harder to justify than one that runs only during a lock or block. Recommendation: run it only while a lock, phone-free block or overdue judgement exists, and show the emergency exit in the video. |
| FGS from boot | Android 15+ blocks dataSync, camera, mediaPlayback, phoneCall, mediaProjection and microphone from `BOOT_COMPLETED`. `specialUse` is not blocked. `BOOT_COMPLETED` and `MY_PACKAGE_REPLACED` remain background-start exemptions. ([Android 15 changes](https://developer.android.com/about/versions/15/behavior-changes-15#fgs-boot-completed), [bg-start restrictions](https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start)) | `BootReceiver` starts a `specialUse` FGS. | **Compliant**, platform-wise. |
| Usage access (`PACKAGE_USAGE_STATS`) | No Console declaration found. The User Data policy treats the "inventory of other apps" and usage data as personal and sensitive. It requires an **in-app prominent disclosure immediately before the request**, shown in normal use and accepted with an affirmative tap. The privacy policy alone does not count. ([answer/10144311](https://support.google.com/googleplay/android-developer/answer/10144311)) | The apps step says only "The System needs … to lock apps." The README and the Play kit say the Awakening "explains why". | **Likely gap [INFERENCE].** Add a dedicated disclosure before the request. It must say what is read (which apps you open and for how long), why, that the data stays on the device, and offer Accept / Not now. The app list uses `<queries>` (launcher and home intents), not `QUERY_ALL_PACKAGES`, so no extra declaration is needed [VERIFIED-CODE]. |
| `SYSTEM_ALERT_WINDOW` and launching the block screen | No declaration form. The app must send the user to Settings to grant it. Holding SAW is still a listed exemption for background activity launches. On Android 15+, SAW lets an app start an FGS from the background only while an overlay is visible; this app's boot path uses the boot exemption instead. ([answer/9888170](https://support.google.com/googleplay/android-developer/answer/9888170), [background starts](https://developer.android.com/guide/components/activities/background-starts)) | Correct usage. | Low. |
| Exact alarms | `USE_EXACT_ALARM` is restricted to alarm, timer and calendar apps. Other apps use `SCHEDULE_EXACT_ALARM`, which is denied by default on Android 14+, and must fall back to inexact alarms. ([answer/9888170](https://support.google.com/googleplay/android-developer/answer/9888170), [Android 14 exact alarms](https://developer.android.com/about/versions/14/changes/schedule-exact-alarms)) | Uses `SCHEDULE_EXACT_ALARM` with an inexact fallback (`notifier.dart:120-127`) [VERIFIED-CODE]. | **Compliant.** Do not add `USE_EXACT_ALARM`. |
| Health apps | **Every** app, including closed and open testing tracks, must complete the Health apps declaration. "Activity and Fitness" is one of the options. Health apps that are not medical devices must say in the **description** that the app "is not a medical device and does not diagnose, treat, cure, or prevent any medical condition", and must remind users to consult a healthcare professional. ([answer/14738291](https://support.google.com/googleplay/android-developer/answer/14738291), [answer/16679511](https://support.google.com/googleplay/android-developer/answer/16679511)) | The listing draft says "not medical advice… ask a doctor first". **There is no health notice in the app** [VERIFIED-CODE]. `release/PLAY_RELEASE.md` does not mention the Health apps declaration. | **Gap.** Use the required wording, fill in the declaration, and add the notice in the app (P0-4). An exercise-as-punishment mechanic in a Health & Fitness app invites reviewer scrutiny. |
| Blocking other apps | Device & Network Abuse bans interfering with other apps "in an unauthorized manner". No explicit exemption for wellbeing apps was found. Stalkerware is defined as sending data to a third party to monitor someone else. ([answer/9888379](https://support.google.com/googleplay/android-developer/answer/9888379), [answer/9888380](https://support.google.com/googleplay/android-developer/answer/9888380)) | Only apps the user picks are locked; there is no network and no Accessibility Service. | **Low to medium [INFERENCE].** The user authorises the block, but reviewers judge case by case. Keep the user's control explicit in the listing and in the app. |
| Data safety | "Collection" means sending data off the device. Data processed only on the device need not be disclosed, but the form and privacy-policy link are still required. ([answer/10787469](https://support.google.com/googleplay/android-developer/answer/10787469)) | Answering "no data collected" is consistent with no INTERNET permission. | Whether Auto Backup counts was **not resolved** from official text. Setting `allowBackup="false"` avoids the question, and the privacy policy wording must be fixed either way (P0-5). |
| Closed test (personal account) | 12+ testers opted in continuously for 14 days before applying for production. ([answer/14151465](https://support.google.com/googleplay/android-developer/answer/14151465)) | Planned in `progress.md`. | Process requirement. |
| Intellectual property | The IP policy prohibits artwork from comics and cartoons, fan art "indistinguishable from the original", and trademark use likely to cause confusion. The Impersonation policy bars implying affiliation with a famous show. ([answer/9888072](https://support.google.com/googleplay/android-developer/answer/9888072); the Impersonation page answer/9888374 was seen only in search results, not opened) | Art, sound and fonts are original or OFL. The copy uses genre-generic terms (Daily Quest, Player, Gate, Dungeon, E–S ranks). The onboarding line **"You have met the conditions to become a Player."** (`onboarding_screen.dart:383`) closely echoes a well-known line from the source. "Penalty Zone" plus "System" plus a blue-window aesthetic together come close to the franchise's trade dress. | **Medium [INFERENCE].** Rewrite near-quotes. Keep "Solo Leveling", character names and look-alike art out of the listing, keywords and ads. The brand should stand on its own without the franchise. |

**Permissions:** none are unnecessary for the current design. The always-on foreground service is the most likely review problem, and the missing prominent disclosure for usage access is the most likely policy gap.

---

## 9. QA and Testing Report

**Executed during this audit**

| Gate | Result |
|---|---|
| `flutter analyze` | No issues [VERIFIED-RUN] |
| `dart format --set-exit-if-changed lib test` | 0 files changed [VERIFIED-RUN] |
| `flutter test --coverage` | **205/205 passed** [VERIFIED-RUN] |
| Line coverage | **80.0%** overall. Domain 95–100% except `placement.dart` 46.7%. Platform bridges: `notifier.dart` 0%, `time_source.dart` 6.7%, `usage_meter.dart` 11.1%, `blocker.dart` 31.9%. UI: `app_picker_screen.dart` 0%, `notice_overlay.dart` 40%, `game_model.dart` 58%, `penalty_screen.dart` 57%. [VERIFIED-RUN] |
| Kotlin unit tests | **None exist.** |
| Integration tests | **None exist.** BUILD_LOOP.md defines a T3 `integration_test/` tier; the directory does not exist. |
| Device checks | Not run in this audit. `progress.md §6.2` lists still-open device checks (Focus block lock/unlock, caps reading, penalty screens, Gate/Dungeon/rank-up on device). |
| TestSprite | Not re-run. Per project docs it covers the **web** build only; it cannot cover blocking, notifications, reboot or battery. |

**Audit probes (scratch copy, outside the repo)**

| Probe | Steps | Expected | Actual |
|---|---|---|---|
| P1 Debt growth | Fitness rank E, live, fail daily, pay nothing, judge 7 days | Bounded, safe penalty | **50, 150, 350, 750, 1,550, 3,150, 6,350 reps owed** |
| P2 Release | Fail day; at lock start take a release every 15 min | Lock enforces for a meaningful time | **16 releases granted; lock fully bypassed** |
| P3 Penalty payment | `recordPenalty(primary: 10000)` | Some verification or rate limit | **Debt paid instantly** |
| P4 Quest completion | `setProgress(goal)` for each Fitness item at 09:00 | — (honour by design) | All complete; via UI, `+5` taps achieve the same for counters |
| P5 Race | Focus rank C; `measureCaps()` in flight; user confirms the "No phone at meals" checkbox; meter returns | Checkbox stays complete | **Progress was 1 right after the tap, `null` after the measurement committed** → objective would be judged failed |
| P6 Native clear | Lock synced; native lock cleared (diagnostics `stopLock`); `enforcer.sync()` again | Window re-sent | **No call sent; lock stays cleared** |

**Critical test cases to add (priority order)**
1. Concurrent mutation: any two of {poll tick, measureCaps, setProgress, timer stop, release} interleaved at every await → no lost writes. (Fails today.)
2. Timezone change mid-day with a running timer and a scheduled lock → instants preserved.
3. API ≤ 32 device with manual clock moved past lock end → lock still enforced (or the gap logged).
4. Reboot during a lock on Android 13/14/15/16 → watcher back within N seconds; block screen reappears.
5. Force-stop during lock → outage logged with correct `duringLock`.
6. Split-screen and PiP with a locked app → blocked or logged.
7. Storage at 1 year of synthetic log (~20k entries) → tap-to-save latency < 50 ms.
8. Corrupt save → user can export raw data and reset.
9. DST transition day (for non-IST users) → lock scheduler never places a lock in sleep window.
10. Upgrade from 0.9.0 save → loads with no change in debt/lock.

---

## 10. Product Feature Audit

| Feature | Current Implementation | Problem Identified | User Impact | Recommendation | Priority |
|---|---|---|---|---|---|
| Awakening onboarding | 7 steps, typed intro, terms wall (`onboarding_screen.dart`) | Long; permissions mid-flow; threatening tone; no age gate; no medical notice | Drop-off; safety exposure | **Improve**: ≤ 3 steps to first quest; age + health notice; permissions on demand | P1 |
| Three Systems | Fitness, Personality, Focus; one at a time, no switching until S held 30 days | Triples content; only Focus is verifiable; switching ban traps users in a wrong choice for months | Users locked into a path they dislike → uninstall | **Replace**: Focus as v1 core; others become optional quest packs; allow switching | P1 |
| Placement test | 1–2 self-reported questions → E/D/C | Thin; accepts 0 push-ups then applies 50-rep penalty | Unsafe mismatch | **Improve** or remove with Fitness | P0 (with penalty fix) |
| Daily quest (catalogue) | Static per rank, frozen when issued | Good integrity; content is generic | Fine | **Keep** | — |
| Hold-to-confirm / counters | Honour inputs | Unverifiable | Low trust in results | **Keep**, add partial credit | P2 |
| Timers / phone-free block | Wall-clock start/stop; phone-free locks chosen apps | Measures elapsed time, not activity; "phone-free" means "chosen apps closed" | Misleading name | **Improve** naming; keep | P2 |
| Screen-time caps | Measured via usage events (`UsageMeter.kt`) | Best feature; honour fallback when access revoked | Core value | **Keep**, make it the centre | — |
| Midnight judging | Lazy tick + native redirect | Depends on process; fixed midnight | Night-shift users misjudged | **Improve**: configurable day-end | P2 |
| XP / level | 100 XP per clear; thresholds placeholder | Level only scales the penalty upward — progress makes punishment worse | Perverse | **Replace** level→penalty scaling | P1 |
| Rank / Gates / Dungeons | 21/30 → 48 h Gate → 3 floors → Rank Trial | Strong idea for milestones; complex; Dungeon Penalty doubles everything | Engaging for the core fan; confusing for others | **Improve**: keep milestone, drop doubled penalty | P2 |
| Attributes & points | Earned and assignable, no effect | Fake progress | Erodes trust | **Remove** | P2 |
| Penalty: app lock | Random-time 4 h + 20 min/level | Ambush timing; grows with level | Stress, resentment | **Improve**: user-chosen, fixed-length window | P1 |
| Penalty: exercise | 50 push-ups +5/level, cap 150 then squats; doubled carry-over | Unsafe; aversive pairing | Injury risk; abandonment | **Remove** as punishment | **P0** |
| Penalty: reading + reflection | 20 pages + 5-line reflection | Reasonable; carry-over still doubles | OK | **Keep**, no compounding | P1 |
| Penalty: Focus block | 60 min +5/level phone-free | Reasonable | OK | **Keep**, no compounding | P1 |
| Carry-over (×2) | Unbounded compounding | See P1 probe | Impossible debt | **Remove** | **P0** |
| Release (15 min) | Free, unlimited, counted | Nullifies lock | Lock meaningless | **Improve**: limited count per lock, or each release extends tomorrow's window slightly; keep an always-available true emergency exit | P1 |
| Never-lock list | Phone, SMS, maps, settings, launcher, 12 Indian banking/UPI apps | Hard-coded banking list misses many banks/regions | Safety gap outside India | **Improve**: category-based or user-confirmable | P2 |
| Reduction valve | ≤ 20%, next day, 6 days/30, half XP | Good concept, too weak for illness | — | **Keep** + add pause | P1 |
| Pause / sick / travel | Missing | Guaranteed penalties during illness | Churn, harm | **Add** | P1 |
| Dispute false failure | Missing (promised in PROJECT.md §7) | No recourse after a bug | Trust loss | **Add** | P1 |
| 30-day report + share card | Live-built, honesty section, optional figures | Good; only every 30 days | Late feedback | **Keep**; add weekly summary | P2 |
| Trial log + JSON/CSV export | Append-only | Unbounded growth | Performance over time | **Keep**, move to DB | P2 |
| System Check | 7 checks + manual OEM steps | Useful | Good | **Keep** | — |
| Diagnostics screen | Debug spike in release | Bypass path | Integrity | **Remove** from release | P1 |
| Watchdog / outage logging | Restarts watcher on app open; logs gaps | Only when app opens | Partial | **Keep** | — |
| Sounds / haptics / mute | Original SFX | Fine | — | **Keep** | — |
| Restart / abandon | Refused during penalty/Dungeon | Clear-storage bypass exists anyway | — | **Keep** | — |

---

## 11. Growth and Retention Strategy

**Why someone downloads:** the anime "System" fantasy (store art, "Penalty Zone"). This acquires curious fans cheaply but attracts the users least likely to tolerate real punishment for long.

**First five minutes should achieve:** pick one goal (e.g. "under 60 min of Instagram/YouTube a day"), see today's measured minutes immediately (usage access gives a real number — a strong "aha"), choose a consequence, done. Today the first five minutes are spent on narrative, placement and terms.

**Why return tomorrow:** to see the measured number and the verdict. Make the measured improvement the hero, not XP.

**Why uninstall:** (1) first real penalty feels unfair or arrives at a bad time; (2) debt becomes impossible; (3) permanent FGS notification and battery suspicion; (4) novelty fades; (5) illness/travel with no pause; (6) a lock blocked something needed (a work app on Instagram/YouTube).

**Meaningful vs artificial engagement:** meaningful = reduced measured screen time, quests actually done, voluntary continuation after day 30. Artificial = notices, XP animations, attribute points, rank badges, time spent inside the app.

**Metrics to define** (local-first; anything sent off-device requires INTERNET, a Data safety change and opt-in consent)

| Metric | Definition |
|---|---|
| Onboarding completion | Reached first issued quest / installs |
| Activation | First live day cleared **and** usage access granted (Focus) |
| Time to first quest completion | Install → first objective confirmed |
| D1 / D7 / D30 retention | Opened on day N |
| Quest clear rate | Cleared live days / judged live days |
| Outcome metric (north star) | **Change in measured daily minutes on chosen apps vs. the user's first-week baseline** |
| Penalty health | Penalties per user-week; releases per lock; outages per lock |
| Churn after penalty | Uninstall/abandon within 48 h of a lock |
| Voluntary continuation | Users starting a second 30-day cycle |
| Conversion (if paid) | Paid / activated |

**Event architecture (minimal, no personal content):** `app_open`, `onboarding_step_completed{step}`, `quest_issued{system,rank,items}`, `objective_completed{type}`, `day_judged{cleared,reduced,dry_run}`, `penalty_issued{kind}`, `lock_started`, `lock_released{n}`, `blocker_outage{minutes}`, `pause_started/ended`, `report_viewed`, `screen_minutes_daily{bucketed}`. Never send package names, reflection text, or exact timestamps; bucket durations. Keep everything on-device for the trial; for a closed test, an opt-in "export my anonymous summary" button is enough.

---

## 12. Prioritised Improvement Roadmap

### P0 — Critical (safety, wrongful penalty, publication-blocking)

| # | Problem | Proposed solution | User impact | Complexity | Effort | Dependencies | Acceptance criteria |
|---|---|---|---|---|---|---|---|
| P0-1 | Unbounded ×2 carry-over (`engine.dart:249-261`) | Remove compounding: unpaid work expires and is logged; or cap total owed at the day's base amount | Removes impossible/unsafe debt | Low | 0.5 day | Config + tests | Probe P1 shows total owed never exceeds the base amount on any day |
| P0-2 | Exercise used as automatic punishment, mis-scaled to fitness level, no health notice | Remove exercise penalties; if any physical task remains, make it user-chosen, capped at the user's own daily quest volume, optional, with an explicit health notice and stop rule | Removes injury risk | Low–Med | 1–2 days | P0-1, onboarding copy | No code path can owe more physical reps than the user's current daily quest; health notice shown before first quest; tests |
| P0-3 | Lost-update race in `GameService` (P5) | Serialise all mutations (single async queue/mutex); re-read `_game` after every await before deriving the next state | Prevents wrongful penalties | Med | 1–2 days | — | Probe P5 and new interleaving tests pass; no write derived from a stale snapshot |
| P0-4 | Missing age gate / health disclaimer vs Play listing claims | Add 18+ confirmation and health notice in onboarding; align privacy policy and listing | Compliance and honesty | Low | 0.5 day | P0-2 | Onboarding cannot complete without both; texts match listing |
| P0-5 | Privacy policy says data deleted on uninstall; Auto Backup on | Decide: `allowBackup="false"` (+ `dataExtractionRules`) or disclose backup | Accurate declarations | Low | 0.5 day | — | Manifest and policy agree; Data safety answers re-checked |

### P1 — High

| # | Problem | Solution | Effort | Acceptance criteria |
|---|---|---|---|---|
| P1-1 | Diagnostics screen in release can clear locks (P6) | Compile it out of release (`kReleaseMode`); enforcer re-reads native status each sync and re-sends if different | 0.5 day | No diagnostics route in release; P6 re-sends window |
| P1-2 | Timezone-unsafe persistence | Store all instants as UTC epoch ms; re-init `tz.local` on resume | 1 day | Timezone-change test keeps lock/timer instants identical |
| P1-3 | No pause/sick/travel mode; no dispute | Declared rest days; pause that suspends judging (logged); "contest this verdict" that cancels the penalty and logs it | 2–3 days | Paused days are not judged; disputes visible in report |
| P1-4 | Level makes punishment harsher | Decouple penalty size from level; fixed, user-chosen consequence | 1 day | Penalty independent of level |
| P1-5 | Ambush lock timing, unlimited free release | User-chosen fixed lock window; limited releases per lock plus a separate, always-available emergency exit (logged) | 1–2 days | Lock window shown in advance; release count enforced; emergency exit always works |
| P1-6 | Android ≤ 12 has no trusted time | Use elapsed-realtime anchors for running locks (lock end = boot-relative deadline persisted with boot count), log clock jumps | 1–2 days | Changing device clock during a lock on API 30 does not end it, or the jump is logged |
| P1-7 | Zero native / integration tests | `integration_test/` for onboarding→fail→lock; Robolectric tests for `BlockerState`, `UsageMeter` | 3–5 days | CI runs both; covers reboot, force-stop log, caps |
| P1-8 | Onboarding length, permission timing | ≤ 3 steps to first quest; blocker permissions on first lock opt-in; prominent disclosure screen before usage access | 2–3 days | Median time-to-first-quest < 2 min in a 5-person test |
| P1-9 | Scope: three Systems | Ship Focus as the core; Fitness/Personality as optional positive packs; allow switching | 3–5 days | — |

### P2 — Medium
Storage to SQLite/Drift with capped archives; startup-error export/reset; notification times derived from sleep window; configurable day-end; remove attributes; neutral idle Penalty tab; ≥ 12 sp text; partial credit / minimum viable day; weekly summary; category-based never-lock list; measure battery and cold start; FGS only while needed (start from an exact alarm at lock start where policy allows).

### P3 — Low
Re-enable R8 with keep rules for plugin JNI classes; compress SFX; clean store screenshots; rename "phone-free" to "app-free"; polish share card; dependency upgrades with `osv-scanner`.

### Realistic sequence (one developer)

| Phase | Weeks | Content |
|---|---|---|
| 1. Fix critical | 1 | P0-1…P0-5 |
| 2. Stabilise core | 2–3 | P1-1, P1-2, P1-6, P1-7 |
| 3. UX | 4–5 | P1-8, P2 UX items |
| 4. Retention mechanics | 6–7 | P1-3, P1-4, P1-5, weekly summary, outcome metric front and centre |
| 5. Validate | 8–11 | Finish own 30-day trial on the new rules; 12+ person closed test for 14+ days; interviews |
| 6. Prepare Play production | 12+ | Declarations, listing, IP review, only if phase 5 meets pre-set thresholds |

---

## 13. Recommended New Features (only where they solve a real problem)

1. **Pause / planned rest days** — illness and travel are certain; without this, the app punishes life.
2. **Contest a verdict** — the project's own risk plan requires it; protects trust after the inevitable bug.
3. **Baseline-vs-now screen-time chart** — the one outcome the app can measure honestly; the strongest retention driver available.
4. **Pre-chosen, fixed lock window** — makes the consequence a commitment rather than an ambush.
5. **Restorative task that shortens tomorrow's lock** — points the penalty toward the habit.
6. **Data export from the error screen** — prevents a corrupted save becoming a dead end.

Not recommended now: leaderboards, PvP, AI-generated quests, camera rep counting, Health Connect, money stakes, iOS/web. None helps validate the core question.

## 14. Features to Remove or Replace

| Remove | Why |
|---|---|
| Exercise as punishment (push-ups/squats penalty) | Safety; aversive pairing |
| ×2 carry-over / "100% interest" | Impossible debt; punishes honesty |
| Level-scaled penalties | Progress should not make punishment worse |
| Attribute points | No effect; fake progress |
| Dungeon Penalty doubling | Same issues as carry-over, at the most emotionally loaded moment |
| Diagnostics screen in release | Bypass path |
| "No switching" rule | Traps users in a wrong choice for months |

| Replace | With |
|---|---|
| Random, unannounced lock start | User-chosen window |
| Unlimited free release | Limited releases + logged emergency exit |
| All-or-nothing day | Minimum viable day + partial credit |
| Three co-equal Systems | Focus core + optional packs |

---

## 15. Google Play Publication Readiness

| Track | Readiness | Blocking items |
|---|---|---|
| Internal testing | **Feasible now** for trusted testers, *after* P0-1 and P0-2 (do not hand an exponential exercise debt to friends). | P0-1, P0-2 |
| Closed testing (personal account requirement) | Feasible after all P0 + P1-1, P1-3, P1-8 | Declarations in §8 |
| Production | **Not ready.** | All P0, most P1, policy items in §8, IP review, evidence from the trial and closed test |

## 16. Final Go / No-Go Recommendation

**No-Go for production. No-Go for internal testing until the exercise penalty and compounding debt are removed. Go for continuing development in a narrowed direction.**

### If I were investing my own money, reputation and six months

I would **not** continue in the current direction. I would continue in a **narrowed** one, because the engineering foundation is better than most solo projects and the one verifiable mechanic — measured screen time plus a self-imposed lock — addresses a problem people demonstrably pay to solve.

Before investing further I would change exactly this:
1. **Remove exercise as punishment and all compounding debt** (this week).
2. **Fix the lost-update race and timezone persistence** — a wrongful penalty is the fastest way to lose a user's trust permanently.
3. **Re-scope to one problem:** "keep my chosen apps under my own limit". Fitness and Personality become optional positive quest packs or are cut from v1.
4. **Turn the penalty into a commitment:** pre-chosen, fixed, bounded, predictable, recoverable, with pause and dispute.
5. **Make measured improvement the hero** of the UI; demote XP/ranks/Gates to flavour; delete attributes.
6. **Shed IP proximity:** keep the cold "System" voice, but rename terms and lines that echo the source (see §8), so the brand survives the franchise's popularity cycle.
7. **Finish the 30-day trial on the new rules and run a 12+ person, 14+ day closed test** with pre-registered success thresholds (e.g. ≥ 30% reduction in measured minutes for ≥ half of testers, ≥ 40% D30 retention among activated users, zero wrongful penalties). Only invest in production polish if those thresholds are met.

If the narrowed version cannot beat those thresholds with 12–20 real users, stop: that is a cheap, valid result, exactly as PROJECT.md §6 anticipated.
